import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Config
import qs.Common
import qs.Services

/*
 * Emoji picker: a 5 x 6 grid, category tabs along the bottom, and the same
 * hidden search strip the launcher and the font picker use.
 *
 *   qs -c bw77-shell ipc call emoji toggle
 *
 * Keys: arrows move, Enter pastes, Tab / Shift+Tab change category, typing
 * searches every category by name and keyword, Escape clears the search and
 * then closes.
 *
 * --- the data
 *
 * Assets/emoji.json is built from Unicode's emoji-test.txt and the CLDR English
 * annotations. The annotations are what make "sad" find the pensive face and
 * "middle finger" find the hand: the Unicode names alone do not contain those
 * words. It stops at the emoji version the installed Noto Color Emoji covers,
 * so nothing in the grid draws as an empty box, and it leaves out the skin
 * tone variants, which would otherwise be five of every hand.
 *
 * It is read when the picker opens and dropped with it, rather than held by a
 * singleton for the life of the shell - the picker is open for seconds at a
 * time, and two thousand entries are not worth keeping resident for that.
 *
 * --- pasting
 *
 * Enter copies the emoji with wl-copy, so it stays on the clipboard, and then
 * puts it into the window that had focus: typed with wtype in a terminal,
 * pasted with Ctrl+V everywhere else. pick() has the reason for the split -
 * browsers drop wtype's typed characters, and terminals do not paste on
 * Ctrl+V. Settings.emoji.pasteMethod overrides the choice.
 *
 * For wtype to reach that window this surface has to let go of the keyboard
 * first, so keyboard focus is tied to the open flag rather than to the
 * surface's lifetime. The surface stays alive through its close animation, and
 * with focus held until then the keystrokes would have gone to the picker as
 * it faded out.
 */
PanelWindow {
    id: root

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "bw77-emoji"
    WlrLayershell.keyboardFocus: Shell.emojiOpen
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    readonly property int columns: 5
    readonly property int rows: 6
    readonly property int cell: 58

    // How many recent picks to keep - one page of the grid.
    readonly property int recentLimit: columns * rows

    property var groups: []
    property string activeGroup: ""
    property string query: ""
    property int selectedIndex: 0

    // Whichever device moved last owns the selection. See the launcher, which
    // this follows exactly: without it, arrowing through a grid under a
    // resting cursor fights the hover.
    property bool keyboardMode: false
    property real lastCursorX: -1
    property real lastCursorY: -1

    readonly property var recent: Settings.emoji.recent || []

    // The window the emoji is going into, taken as the picker opens - see
    // pick() for why the kind of window decides how it is pasted.
    property string targetAppId: ""
    Component.onCompleted: root.targetAppId = Compositor.activeAppId || ""

    function isTerminal(appId) {
        const id = String(appId).toLowerCase();
        return /(kitty|foot|alacritty|wezterm|ghostty|konsole|term|console|kgx|urxvt|tilix|ptyxis|blackbox|contour|warp|^st(-|$)|^rio$)/.test(id);
    }

    FileView {
        path: `${Quickshell.shellDir}/Assets/emoji.json`
        onLoaded: {
            try {
                root.groups = JSON.parse(text()).groups || [];
            } catch (e) {
                console.log("bw77: could not read Assets/emoji.json: " + e);
                root.groups = [];
            }
            if (root.activeGroup === "")
                root.activeGroup = root.recent.length > 0 ? "Recent"
                    : (root.groups.length > 0 ? root.groups[0].name : "");
        }
    }

    // Recent first, and only once there is something in it.
    readonly property var tabs: {
        const out = [];
        if (root.recent.length > 0) out.push({ key: "Recent", icon: "🕘" });
        for (let i = 0; i < root.groups.length; i++)
            out.push({ key: root.groups[i].name, icon: root.groups[i].icon });
        return out;
    }

    readonly property bool searching: query.trim() !== ""

    /*
     * A search covers every category, not just the one on screen - you know
     * the word, not which of nine tabs the emoji was filed under.
     *
     * Every word typed has to appear somewhere in the name or the keywords, so
     * "red heart" narrows rather than widens. Names that start with the query
     * come first, then names that contain it, then keyword-only matches: "cat"
     * should put the cat face above the things merely tagged with it.
     */
    readonly property var results: {
        if (root.searching) {
            const q = root.query.trim().toLowerCase();
            const words = q.split(/\s+/);
            const scored = [];

            for (let g = 0; g < root.groups.length; g++) {
                const items = root.groups[g].items;
                for (let i = 0; i < items.length; i++) {
                    const it = items[i];
                    const hay = it[1] + " | " + it[2];
                    let all = true;
                    for (let w = 0; w < words.length; w++) {
                        if (hay.indexOf(words[w]) === -1) { all = false; break; }
                    }
                    if (!all) continue;
                    const score = it[1].startsWith(q) ? 0 : (it[1].indexOf(q) !== -1 ? 1 : 2);
                    scored.push({ it: it, score: score, order: scored.length });
                }
            }

            scored.sort((a, b) => a.score - b.score || a.order - b.order);
            return scored.map(s => s.it);
        }

        if (root.activeGroup === "Recent") return root.recent;

        for (let g = 0; g < root.groups.length; g++)
            if (root.groups[g].name === root.activeGroup) return root.groups[g].items;
        return [];
    }

    readonly property var selected: results[selectedIndex] || null

    onQueryChanged: selectedIndex = 0
    onActiveGroupChanged: selectedIndex = 0
    onSelectedIndexChanged: grid.positionViewAtIndex(selectedIndex, GridView.Contain)

    function selectByKey(index) {
        keyboardMode = true;
        lastCursorX = -1;
        lastCursorY = -1;
        if (results.length === 0) return;
        selectedIndex = Math.max(0, Math.min(results.length - 1, index));
    }

    // True only when the cursor actually travelled, not when the grid
    // scrolled underneath a resting one.
    function cursorMoved(item, x, y) {
        // Scene coordinates: the window is not an Item to map into.
        const p = item.mapToItem(null, x, y);
        if (lastCursorX < 0 && lastCursorY < 0) {
            lastCursorX = p.x;
            lastCursorY = p.y;
            return false;
        }
        const moved = Math.abs(p.x - lastCursorX) > 2 || Math.abs(p.y - lastCursorY) > 2;
        lastCursorX = p.x;
        lastCursorY = p.y;
        return moved;
    }

    // Tab leaves a search: the tabs are a way of browsing, and landing on one
    // with a filter still applied would show a category that looks empty.
    function cycleTab(delta) {
        const list = root.tabs;
        if (list.length === 0) return;
        let i = -1;
        for (let k = 0; k < list.length; k++) if (list[k].key === root.activeGroup) i = k;
        root.activeGroup = list[(i + delta + list.length) % list.length].key;
        input.text = "";
    }

    function setTab(key) {
        root.activeGroup = key;
        input.text = "";
        input.forceActiveFocus();
    }

    // Emoji and name only. The keywords are only ever searched, and a search
    // runs over the full list, so storing them here was dead weight in the
    // settings file - and in memory for as long as the shell runs.
    function remember(item) {
        const next = [[item[0], item[1], ""]].concat(
            root.recent.filter(r => r[0] !== item[0]).map(r => [r[0], r[1], ""]));
        Settings.emoji.recent = next.slice(0, root.recentLimit);
    }

    function pick(index) {
        const item = results[index];
        if (!item) return;
        const glyph = item[0];

        root.remember(item);

        // Closing drops keyboard focus at once (see the header), which hands
        // it back to the window the picker was opened over.
        Shell.emojiOpen = false;

        /*
         * --- how it gets into the window
         *
         * wtype does not press keys on your layout. It hands the focused
         * window a keymap of its own containing exactly the characters it
         * needs, then presses keys on that. Terminals and most toolkits take
         * the new keymap straight away. Browsers do not: Chromium and Firefox
         * react to the keymap arriving - that is the flash in the text box -
         * and drop the keypress that follows it, so nothing is typed.
         *
         * So in "auto" a terminal is typed into, which is the one place Ctrl+V
         * is not paste, and everything else - browsers included - is pasted
         * from the clipboard with Ctrl+V, which they handle like any other
         * shortcut. Both wait 120ms after the keymap goes over before the
         * first key (-s), which is the part the browsers were missing.
         *
         * The copy happens first and finishes before the paste is sent - one
         * script, in order - so Ctrl+V cannot race wl-copy to the clipboard.
         * The emoji is passed as an argument rather than spliced into the
         * script, so nothing in it can be read as shell syntax.
         */
        let method = Settings.emoji.pasteMethod || "auto";
        if (method === "auto")
            method = root.isTerminal(root.targetAppId) ? "type" : "paste";

        const have = "command -v wtype >/dev/null 2>&1 || exit 0; ";
        let script = "printf '%s' \"$1\" | wl-copy; ";

        if (method === "type")
            script += "sleep 0.15; " + have + "exec wtype -s 120 -- \"$1\"";
        else if (method === "paste")
            script += "sleep 0.15; " + have + "exec wtype -s 120 -M ctrl -k v -m ctrl";

        Quickshell.execDetached(["sh", "-c", script, "sh", glyph]);
    }

    // Anywhere outside the card dismisses.
    MouseArea {
        anchors.fill: parent
        onClicked: Shell.emojiOpen = false
    }

    // The picker keeps no query across a close: the surface is alive for its
    // close animation and would otherwise reopen onto the last search.
    Connections {
        target: Shell
        function onEmojiOpenChanged() {
            if (Shell.emojiOpen) input.forceActiveFocus();
            else input.text = "";
        }
    }

    GlitchBox {
        id: surfaceAnim
        category: "launcher"
        anchors.fill: parent
        shown: Shell.emojiOpen

        // Clicks on the card's own empty space are the card's, not a dismissal.
        MouseArea {
            x: card.x; y: card.y
            width: card.width; height: card.height
        }

        Panel {
            id: card

            fillColor: Theme.bgBase
            fillOpacity: 0.96
            serialSeed: "emoji"
            padding: Theme.space4

            x: Math.round((parent.width - width) / 2)
            y: Math.round((parent.height - height) / 2)

            width: grid.width + padding * 2
            // The extra 16 is room for the serial along the bottom edge.
            height: body.implicitHeight + padding * 2 + 16

            Column {
                id: body
                width: grid.width
                spacing: Theme.space3

                SectionHeader {
                    width: parent.width
                    title: Settings.t("Emoji")
                    subtitle: root.searching
                        ? `${root.results.length} / ${root.query.trim()}`
                        : Settings.t(root.activeGroup)
                    accentColor: Theme.danger
                }

                /*
                 * --- search: absent until there is a query to show
                 *
                 * The launcher's strip, for the launcher's reasons: it rolls
                 * open on the first keystroke and shut when the query empties.
                 * It collapses by height and opacity, never `visible`, because
                 * the TextInput has to keep Qt focus while it is off screen -
                 * that is what lets typing land in a real field from the start.
                 */
                Item {
                    id: searchBox
                    width: parent.width

                    readonly property bool active: input.text !== ""

                    height: active ? 38 : 0
                    opacity: active ? 1 : 0
                    clip: true

                    Behavior on height {
                        enabled: !Theme.reducedMotion && Settings.animations.surfaceOpen
                        NumberAnimation { duration: Theme.durFast; easing.type: Theme.easeSnap }
                    }
                    Behavior on opacity {
                        enabled: !Theme.reducedMotion && Settings.animations.surfaceOpen
                        NumberAnimation { duration: Theme.durFast }
                    }

                    NotchRect {
                        anchors.fill: parent
                        fillColor: Theme.alpha(Theme.bgDeep, 0.9)
                        strokeColor: input.activeFocus ? Theme.accent : Theme.border
                        notch: Theme.notchSmall
                        notchTopLeft: false
                        notchTopRight: false
                        notchBottomRight: true
                        notchBottomLeft: false
                    }

                    CyberText {
                        id: promptGlyph
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.space3
                        anchors.verticalCenter: parent.verticalCenter
                        text: ">"
                        role: "mono"
                        color: Theme.danger
                    }

                    TextInput {
                        id: input
                        anchors.left: promptGlyph.right
                        anchors.leftMargin: Theme.space2
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.space3
                        anchors.verticalCenter: parent.verticalCenter

                        focus: true
                        color: Theme.text
                        font.family: Theme.fontBody
                        font.pixelSize: Theme.fontBase
                        font.letterSpacing: Theme.trackingWide
                        selectionColor: Theme.accent
                        selectedTextColor: Theme.textOnAccent
                        clip: true

                        onTextChanged: {
                            root.query = text;
                            root.keyboardMode = true;
                        }

                        // Steady, like the launcher's.
                        cursorDelegate: Rectangle {
                            width: 8
                            height: 2
                            y: parent.height - 4
                            color: Theme.accent
                        }

                        // The field has focus, so every navigation key is taken
                        // here. Left and Right move through the grid rather than
                        // along the query - a picker is browsed far more often
                        // than a search term is edited mid-word.
                        Keys.onEscapePressed: {
                            if (input.text !== "") input.text = "";
                            else Shell.emojiOpen = false;
                        }
                        Keys.onLeftPressed: root.selectByKey(root.selectedIndex - 1)
                        Keys.onRightPressed: root.selectByKey(root.selectedIndex + 1)
                        Keys.onUpPressed: root.selectByKey(root.selectedIndex - root.columns)
                        Keys.onDownPressed: root.selectByKey(root.selectedIndex + root.columns)
                        Keys.onPressed: (event) => {
                            if (event.key === Qt.Key_PageDown) {
                                root.selectByKey(root.selectedIndex + root.columns * root.rows);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_PageUp) {
                                root.selectByKey(root.selectedIndex - root.columns * root.rows);
                                event.accepted = true;
                            }
                        }
                        Keys.onReturnPressed: root.pick(root.selectedIndex)
                        Keys.onEnterPressed: root.pick(root.selectedIndex)
                        Keys.onTabPressed: root.cycleTab(1)
                        // Shift+Tab arrives as Backtab, not as Tab with a modifier.
                        Keys.onBacktabPressed: root.cycleTab(-1)
                    }
                }

                // --- the grid
                GridView {
                    id: grid
                    width: root.columns * root.cell
                    height: root.rows * root.cell
                    cellWidth: root.cell
                    cellHeight: root.cell
                    clip: true
                    model: root.results
                    currentIndex: root.selectedIndex
                    boundsBehavior: Flickable.StopAtBounds

                    /*
                     * Only the rows on screen, and tiles reused as they scroll.
                     *
                     * Every emoji drawn is a colour bitmap Qt decodes and keeps
                     * for the life of the font - about 68KB each, since Noto's
                     * one bitmap size is 136x128 whatever size it is shown at.
                     * The default cache buffer draws rows above and below the
                     * visible six, so scrolling a category paid for glyphs that
                     * were never on screen.
                     */
                    cacheBuffer: 0
                    reuseItems: true

                    delegate: Item {
                        id: tile
                        required property var modelData
                        required property int index
                        readonly property bool current: index === root.selectedIndex

                        width: root.cell
                        height: root.cell

                        NotchRect {
                            anchors.fill: parent
                            anchors.margins: 2
                            fillColor: tile.current ? Theme.alpha(Theme.accent, 0.16)
                                : (tileMouse.containsMouse ? Theme.alpha(Theme.accent, 0.07) : "transparent")
                            strokeColor: tile.current ? Theme.accent : "transparent"
                            notch: Theme.notchSmall
                            notchTopLeft: false
                            notchTopRight: false
                            notchBottomRight: true
                            notchBottomLeft: false

                            Behavior on fillColor { ColorAnimation { duration: Theme.durFast } }
                            Behavior on strokeColor { ColorAnimation { duration: Theme.durFast } }
                        }

                        // Native rendering: colour emoji are bitmaps, which the
                        // distance-field text path cannot draw.
                        Text {
                            anchors.centerIn: parent
                            text: tile.modelData[0]
                            font.family: "Noto Color Emoji"
                            font.pixelSize: Math.round(root.cell * 0.5)
                            renderType: Text.NativeRendering
                        }

                        MouseArea {
                            id: tileMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onEntered: if (!root.keyboardMode) root.selectedIndex = tile.index
                            onPositionChanged: (mouse) => {
                                if (!root.cursorMoved(tileMouse, mouse.x, mouse.y)) return;
                                root.keyboardMode = false;
                                root.selectedIndex = tile.index;
                            }
                            onClicked: {
                                root.keyboardMode = false;
                                root.pick(tile.index);
                            }
                        }
                    }

                    // Faded rather than switched, like the launcher's.
                    Column {
                        anchors.centerIn: parent
                        width: parent.width - Theme.space4 * 2
                        opacity: root.results.length === 0 && root.groups.length > 0 ? 1 : 0
                        visible: opacity > 0.01
                        spacing: Theme.space2

                        Behavior on opacity { NumberAnimation { duration: Theme.durFast } }

                        CyberText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Settings.t("No matches")
                            role: "title"
                            color: Theme.danger
                        }
                        CyberText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: Settings.t("Try a shorter search, or press Tab to change category")
                            role: "micro"
                            caps: false
                            wrapMode: Text.Wrap
                            color: Theme.textMuted
                        }
                    }
                }

                // The selected emoji's name. It is what the search matched
                // against, so it is also how to find this one again by typing.
                CyberText {
                    width: parent.width
                    text: root.selected ? root.selected[1] : Settings.t("Type to search by name")
                    role: "label"
                    caps: false
                    elide: Text.ElideRight
                    color: root.selected ? Theme.text : Theme.textMuted
                }

                // --- category tabs, along the bottom
                Row {
                    id: tabRow
                    width: parent.width

                    Repeater {
                        model: root.tabs

                        Item {
                            id: tab
                            required property var modelData
                            readonly property bool current:
                                !root.searching && root.activeGroup === modelData.key

                            width: tabRow.width / Math.max(1, root.tabs.length)
                            height: 34

                            NotchRect {
                                anchors.fill: parent
                                anchors.margins: 1
                                fillColor: tab.current ? Theme.alpha(Theme.danger, 0.18)
                                    : (tabMouse.containsMouse ? Theme.alpha(Theme.accent, 0.08) : "transparent")
                                strokeColor: tab.current ? Theme.danger : "transparent"
                                notch: 5
                                notchTopLeft: false
                                notchTopRight: false
                                notchBottomRight: true
                                notchBottomLeft: false

                                Behavior on fillColor { ColorAnimation { duration: Theme.durFast } }
                                Behavior on strokeColor { ColorAnimation { duration: Theme.durFast } }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: tab.modelData.icon
                                font.family: "Noto Color Emoji"
                                // Drawn at the grid's size and scaled down. Qt
                                // keeps a separate copy of every emoji bitmap
                                // per font size, so a 17px tab row cached the
                                // same nine emoji a second time.
                                font.pixelSize: Math.round(root.cell * 0.5)
                                scale: 17 / Math.round(root.cell * 0.5)
                                renderType: Text.NativeRendering
                                opacity: tab.current || tabMouse.containsMouse ? 1 : 0.5

                                Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
                            }

                            MouseArea {
                                id: tabMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.setTab(tab.modelData.key)
                            }
                        }
                    }
                }

                Row {
                    anchors.right: parent.right
                    spacing: Theme.space3

                    Row {
                        spacing: Theme.space1
                        KeyChip { text: "TAB" }
                        CyberText { text: Settings.t("Category"); role: "micro"; color: Theme.textMuted
                                    anchors.verticalCenter: parent.verticalCenter }
                    }
                    Row {
                        spacing: Theme.space1
                        KeyChip { text: "↵" }
                        CyberText { text: Settings.t("Paste"); role: "micro"; color: Theme.textMuted
                                    anchors.verticalCenter: parent.verticalCenter }
                    }
                }
            }
        }
    }
}
