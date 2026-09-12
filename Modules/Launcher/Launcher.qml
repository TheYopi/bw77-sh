import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Config
import qs.Common
import qs.Services

/*
 * Application launcher: search field on top, category rail on the left, results
 * grid on the right. Categories come from each entry's freedesktop categories,
 * collapsed into the readable set defined in settings.
 */
PanelWindow {
    id: root

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "bw77-launcher"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    // Without this the compositor shrinks the surface out of the bar's reserved
    // zone, so a click over the bar or the dock would miss it and the surface
    // would not dismiss.
    exclusionMode: ExclusionMode.Ignore

    property string query: ""
    property string activeCategory: "All"
    property int selectedIndex: 0

    /*
     * Whichever device moved last owns the selection.
     *
     * Arrowing down a list with the cursor resting over it used to fight
     * itself: the keyboard moved the selection, the list scrolled under the
     * stationary cursor, and the resulting hover event dragged it straight
     * back. Hover is ignored until the mouse actually moves again.
     */
    property bool keyboardMode: false

    /*
     * Last known cursor position, in this window's coordinates.
     *
     * onPositionChanged alone is not enough to detect a real mouse move: when
     * the list scrolls under a stationary cursor the item beneath it changes,
     * its local coordinates change with it, and Qt delivers a positionChanged
     * for a mouse that never moved. Comparing against a window-level position
     * is what tells an actual movement from the list sliding past.
     */
    property real lastCursorX: -1
    property real lastCursorY: -1

    function selectByKey(index) {
        keyboardMode = true;
        // Freeze the reference point: any later report differing from this is a
        // genuine move.
        lastCursorX = -1;
        lastCursorY = -1;
        selectedIndex = Math.max(0, Math.min(results.length - 1, index));
    }

    // Returns true only when the cursor has actually travelled.
    function cursorMoved(item, x, y) {
        const p = item.mapToItem(root, x, y);

        if (lastCursorX < 0 && lastCursorY < 0) {
            lastCursorX = p.x;
            lastCursorY = p.y;
            return false;               // first report after a key press
        }

        const dx = Math.abs(p.x - lastCursorX);
        const dy = Math.abs(p.y - lastCursorY);
        lastCursorX = p.x;
        lastCursorY = p.y;

        // A couple of pixels of slack absorbs sub-pixel jitter.
        return dx > 2 || dy > 2;
    }

    // freedesktop categories are too granular to show raw; fold them into the
    // buckets people actually think in.
    readonly property var categoryMap: ({
        "WebBrowser": "Web Browser", "Network": "Network", "Email": "Messaging",
        "InstantMessaging": "Messaging", "Chat": "Messaging", "IRCClient": "Messaging",
        "Audio": "Audio & Video", "Video": "Audio & Video", "AudioVideo": "Audio & Video",
        "Player": "Audio & Video", "Music": "Audio & Video",
        "Graphics": "Graphics", "Photography": "Graphics", "2DGraphics": "Graphics",
        "3DGraphics": "Graphics", "RasterGraphics": "Graphics", "VectorGraphics": "Graphics",
        "Development": "Development", "IDE": "Development", "TextEditor": "Development",
        "Office": "Office", "WordProcessor": "Office", "Spreadsheet": "Office",
        "Presentation": "Office", "Finance": "Office",
        "Education": "Education", "Science": "Education",
        "Game": "Games", "ActionGame": "Games", "Emulator": "Games",
        "System": "System", "Settings": "System", "TerminalEmulator": "System",
        "FileManager": "System", "Utility": "System", "Monitor": "System"
    })

    // Nerd Font glyphs for the horizontal strip, where a label alone would make
    // the row too wide to scan.
    readonly property var categoryGlyphs: ({
        "All": "\uf00a", "Web Browser": "\uf268", "Messaging": "\uf075",
        "Audio & Video": "\uf001", "Graphics": "\uf1fc", "Development": "\uf121",
        "Office": "\uf0f6", "Education": "\uf19d", "Games": "\uf11b",
        "Network": "\uf0ac", "System": "\uf085", "Other": "\uf141"
    })

    function categoryGlyph(name) {
        return categoryGlyphs[name] !== undefined ? categoryGlyphs[name] : "\uf141";
    }

    function bucketFor(entry) {
        const cats = entry.categories || [];
        for (let i = 0; i < cats.length; i++) {
            if (categoryMap[cats[i]]) return categoryMap[cats[i]];
        }
        return "Other";
    }

    readonly property var allEntries: {
        const out = [];
        const values = DesktopEntries.applications.values;
        for (let i = 0; i < values.length; i++) {
            const e = values[i];
            if (e.noDisplay) continue;
            out.push({ entry: e, bucket: bucketFor(e) });
        }
        return out.sort((a, b) => a.entry.name.localeCompare(b.entry.name));
    }

    readonly property var categories: {
        const seen = {};
        for (let i = 0; i < allEntries.length; i++) seen[allEntries[i].bucket] = true;
        const ordered = Settings.launcher.categoryOrder.filter(c => seen[c]);
        return ["All"].concat(ordered);
    }

    readonly property var results: {
        const q = query.trim().toLowerCase();
        let list = allEntries;

        if (activeCategory !== "All")
            list = list.filter(x => x.bucket === activeCategory);

        if (q !== "") {
            list = list.filter(x => {
                const e = x.entry;
                return e.name.toLowerCase().indexOf(q) !== -1
                    || (e.genericName && e.genericName.toLowerCase().indexOf(q) !== -1)
                    || (e.comment && e.comment.toLowerCase().indexOf(q) !== -1)
                    || (e.id && e.id.toLowerCase().indexOf(q) !== -1);
            });
            // Prefix matches first: typing "fi" should surface Firefox above Nautilus.
            list = list.slice().sort((a, b) => {
                const ap = a.entry.name.toLowerCase().startsWith(q) ? 0 : 1;
                const bp = b.entry.name.toLowerCase().startsWith(q) ? 0 : 1;
                return ap - bp;
            });
        }

        return list.slice(0, Settings.launcher.maxResults);
    }

    function cycleCategory(delta) {
        const list = root.categories;
        if (list.length === 0) return;
        const i = list.indexOf(root.activeCategory);
        const next = (i + delta + list.length) % list.length;
        root.activeCategory = list[next];
    }

    function launch(index) {
        const item = results[index];
        if (!item) return;
        Shell.launcherOpen = false;
        item.entry.execute();
    }

    onQueryChanged: selectedIndex = 0
    onActiveCategoryChanged: selectedIndex = 0

    /*
     * A click target, not a scrim.
     *
     * This used to be a translucent fill over the whole screen. The surface
     * still covers the screen - it has to, so that clicking anywhere outside
     * dismisses - but it no longer paints anything, so what is behind stays
     * exactly as bright as it was.
     *
     * The launcher is opaque and bordered and does not need the desktop knocked
     * back to be legible; that was what the dimming was for, and it was
     * costing a full-screen composite on every open as well.
     */
    MouseArea {
        anchors.fill: parent
        onClicked: Shell.launcherOpen = false
    }

    /*
     * A closed launcher forgets what was typed into it.
     *
     * The surface is kept alive across a close so it has something to animate
     * out, which means the field would otherwise still be holding the last
     * query when it came back - reopening onto somebody else's search, with the
     * strip already unrolled.
     */
    Connections {
        target: Shell
        function onLauncherOpenChanged() {
            if (Shell.launcherOpen) input.forceActiveFocus();
            else input.text = "";
        }
    }

    GlitchBox {
        category: "launcher"
        id: surfaceAnim
        anchors.fill: parent
        shown: Shell.launcherOpen

        Panel {
            id: card

            // Matches the quick settings panel: these are surfaces in their own
            // right, not cards resting on one, so they take the base background
            // rather than the raised tone.
            fillColor: Theme.bgBase
            fillOpacity: 0.96
            anchors.horizontalCenter: parent.horizontalCenter
            // Plain y instead of conditional anchors: an anchor assigned undefined
            // is not cleared, so switching position would pin the card to both.
            y: Settings.launcher.position === "top"
                ? 90
                : Math.round((parent.height - height) / 2)

            width: Settings.launcher.width
            height: Settings.launcher.height
            serialSeed: "launcher"
            padding: Theme.space4

            SectionHeader {
                id: header
                anchors.left: parent.left
                anchors.right: parent.right
                title: Settings.t("Applications")
                subtitle: `${root.results.length} of ${root.allEntries.length} entries`
                accentColor: Theme.danger
            }

            /*
             * --- search: absent until there is a query to show
             *
             * The field used to sit there permanently with a placeholder in it,
             * which on a surface that already has the keyboard is 38px spent
             * saying "you may type" to someone who is about to type anyway. It
             * also invited a click into a field that never needed one.
             *
             * So it does what the font picker does: the strip is nothing at all
             * until the first keystroke, rolls open under the header, and rolls
             * shut again the moment the query is emptied - by backspace or by
             * the first Escape. The list gets the height back either way.
             *
             * The TextInput itself never goes away, and this is why the strip
             * collapses by height and opacity rather than by `visible`: an
             * invisible item cannot hold Qt focus, and the field holding focus
             * while it is not on screen is the entire trick. Keystrokes land in
             * a real text field the whole time - which keeps selection, paste
             * and input methods working, none of which a hand-rolled key
             * handler would have given us.
             */
            Item {
                id: searchBox
                anchors.top: header.bottom
                anchors.topMargin: active ? Theme.space3 : 0
                anchors.left: parent.left
                anchors.right: parent.right

                readonly property bool active: input.text !== ""

                height: active ? 38 : 0
                opacity: active ? 1 : 0
                clip: true

                Behavior on height {
                    enabled: !Theme.reducedMotion && Settings.animations.surfaceOpen
                    NumberAnimation {
                        duration: Theme.durFast
                        easing.type: Theme.easeSnap
                    }
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

                    Behavior on strokeColor { ColorAnimation { duration: Theme.durFast } }
                }

                CyberText {
                    id: prompt
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.space3
                    anchors.verticalCenter: parent.verticalCenter
                    text: ">"
                    role: "mono"
                    color: Theme.danger
                }

                TextInput {
                    id: input
                    anchors.left: prompt.right
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

                    // Steady, not blinking. A caret pulsing away in the corner
                    // of a surface that is only ever open for a couple of
                    // seconds is motion that carries no information - the field
                    // is not asking whether you meant to type, it is showing
                    // you what you already typed.
                    cursorDelegate: Rectangle {
                        width: 8
                        height: 2
                        y: parent.height - 4
                        color: Theme.accent
                    }

                    // First press empties the field, which rolls the strip shut;
                    // the second closes the launcher. Escaping straight out of a
                    // narrowed list means reopening and retyping to fix one
                    // character of it - the same reasoning as the font picker.
                    Keys.onEscapePressed: {
                        if (input.text !== "") input.text = "";
                        else Shell.launcherOpen = false;
                    }
                    Keys.onDownPressed: root.selectByKey(root.selectedIndex + 1)
                    Keys.onUpPressed: root.selectByKey(root.selectedIndex - 1)
                    Keys.onReturnPressed: root.launch(root.selectedIndex)
                    Keys.onTabPressed: root.cycleCategory(1)
                    // Shift+Tab arrives as Backtab, not as Tab with a modifier.
                    Keys.onBacktabPressed: root.cycleCategory(-1)
                }
            }

            readonly property bool horizontalCats:
                Settings.launcher.categoryLayout === "horizontal"

            // --- horizontal category strip, icon-led, used instead of the rail
            Flow {
                id: catStrip
                visible: Settings.launcher.showCategories && card.horizontalCats
                anchors.top: searchBox.bottom
                anchors.topMargin: Theme.space3
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: Theme.space1

                Repeater {
                    model: root.categories

                    CyberButton {
                        required property string modelData
                        text: modelData
                        iconText: root.categoryGlyph(modelData)
                        hPadding: Theme.space2
                        active: root.activeCategory === modelData
                        onClicked: root.activeCategory = modelData
                    }
                }
            }

            // --- category rail
            Column {
                id: rail
                visible: Settings.launcher.showCategories && !card.horizontalCats
                anchors.top: searchBox.bottom
                anchors.topMargin: Theme.space3
                anchors.left: parent.left
                anchors.bottom: footer.top
                anchors.bottomMargin: Theme.space2
                width: Settings.launcher.categoryWidth
                spacing: 2

                Repeater {
                    model: root.categories

                    Item {
                        id: catItem
                        required property string modelData
                        readonly property bool current: root.activeCategory === modelData

                        width: rail.width
                        height: 26

                        NotchRect {
                            anchors.fill: parent
                            fillColor: catItem.current
                                ? Theme.alpha(Theme.danger, 0.18)
                                : (catMouse.containsMouse ? Theme.alpha(Theme.accent, 0.08) : "transparent")
                            strokeColor: catItem.current ? Theme.danger : "transparent"
                            notch: 5
                            notchTopLeft: false
                            notchTopRight: false
                            notchBottomRight: true
                            notchBottomLeft: false

                            // Both, not just the fill: the outline appearing on
                            // the same frame the wash starts fading in is what
                            // made picking a category feel like a hard cut.
                            Behavior on fillColor { ColorAnimation { duration: Theme.durFast } }
                            Behavior on strokeColor { ColorAnimation { duration: Theme.durFast } }
                        }

                        CyberText {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.space3
                            anchors.verticalCenter: parent.verticalCenter
                            text: catItem.modelData
                            role: "label"
                            color: catItem.current ? Theme.danger
                                : (catMouse.containsMouse ? Theme.accent : Theme.textDim)

                            Behavior on color { ColorAnimation { duration: Theme.durFast } }
                        }

                        MouseArea {
                            id: catMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.activeCategory = catItem.modelData
                        }
                    }
                }
            }

            // --- results
            ListView {
                id: list
                anchors.top: (Settings.launcher.showCategories && card.horizontalCats)
                    ? catStrip.bottom : searchBox.bottom
                anchors.topMargin: Theme.space3
                anchors.left: (Settings.launcher.showCategories && !card.horizontalCats)
                    ? rail.right : parent.left
                anchors.leftMargin: (Settings.launcher.showCategories && !card.horizontalCats)
                    ? Theme.space3 : 0
                anchors.right: parent.right
                anchors.bottom: footer.top
                anchors.bottomMargin: Theme.space2

                clip: true
                model: root.results
                currentIndex: root.selectedIndex
                highlightMoveDuration: Theme.durFast
                spacing: 2

                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool current: index === root.selectedIndex

                    width: list.width
                    height: 44

                    NotchRect {
                        anchors.fill: parent
                        fillColor: row.current ? Theme.alpha(Theme.accent, 0.16)
                            : (rowMouse.containsMouse ? Theme.alpha(Theme.accent, 0.07) : "transparent")
                        strokeColor: row.current ? Theme.accent : "transparent"
                        notch: Theme.notchSmall
                        notchTopLeft: false
                        notchTopRight: false
                        notchBottomRight: true
                        notchBottomLeft: false

                        /*
                         * The selection travels rather than teleports.
                         *
                         * Holding an arrow key walks the highlight down a list
                         * of results, and with no transition each step was a
                         * separate hard flash - twenty of them on the way to the
                         * bottom. Fading the old row out as the new one comes up
                         * turns that into one continuous movement, and at the
                         * hover speed it still keeps up with the key repeat.
                         */
                        Behavior on fillColor { ColorAnimation { duration: Theme.durFast } }
                        Behavior on strokeColor { ColorAnimation { duration: Theme.durFast } }
                    }

                    IconImage {
                        id: appIcon
                        visible: Settings.launcher.showIcons
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.space3
                        anchors.verticalCenter: parent.verticalCenter
                        implicitSize: 28
                        source: row.modelData.entry.icon
                            ? Quickshell.iconPath(row.modelData.entry.icon, true) : ""
                    }

                    Column {
                        anchors.left: appIcon.visible ? appIcon.right : parent.left
                        anchors.leftMargin: Theme.space3
                        anchors.right: bucketLabel.left
                        anchors.rightMargin: Theme.space3
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: -1

                        CyberText {
                            width: parent.width
                            text: row.modelData.entry.name
                            role: "body"
                            color: row.current ? Theme.accent : Theme.text

                            Behavior on color { ColorAnimation { duration: Theme.durFast } }
                        }

                        CyberText {
                            width: parent.width
                            visible: row.modelData.entry.comment
                            text: row.modelData.entry.comment || ""
                            role: "micro"
                            caps: false
                            color: Theme.textMuted
                        }
                    }

                    CyberText {
                        id: bucketLabel
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.space3
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.modelData.bucket
                        role: "micro"
                        color: Theme.alpha(Theme.textMuted, 0.8)
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        // Entering counts only if the cursor got there under its
                        // own power, not because the list scrolled beneath it.
                        onEntered: if (!root.keyboardMode) root.selectedIndex = row.index

                        // Genuine movement hands control back to the mouse.
                        onPositionChanged: (mouse) => {
                            if (!root.cursorMoved(rowMouse, mouse.x, mouse.y)) return;
                            if (root.keyboardMode) root.keyboardMode = false;
                            root.selectedIndex = row.index;
                        }

                        onClicked: {
                            root.keyboardMode = false;
                            root.launch(row.index);
                        }
                    }
                }

                // Empty state should tell you what to do next, not just say "nothing".
                Column {
                    anchors.centerIn: parent
                    // Faded rather than switched: typing one character past the
                    // last match used to replace the list with a block of text
                    // between two frames, which reads as an error rather than
                    // as the list having run out.
                    opacity: root.results.length === 0 ? 1 : 0
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
                        text: Settings.t("Try a shorter search, or press Tab to change category")
                        role: "micro"
                        caps: false
                        color: Theme.textMuted
                    }
                }
            }

            Row {
                id: footer
                anchors.bottom: parent.bottom
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
                    KeyChip { text: "\u21B5" }
                    CyberText { text: Settings.t("Launch"); role: "micro"; color: Theme.textMuted
                                anchors.verticalCenter: parent.verticalCenter }
                }
                Row {
                    spacing: Theme.space1
                    KeyChip { text: "ESC" }
                    CyberText { text: Settings.t("Close"); role: "micro"; color: Theme.textMuted
                                anchors.verticalCenter: parent.verticalCenter }
                }
            }
        }
    }
}
