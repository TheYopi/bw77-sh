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
    // zone, so the dimming stops short of the bar and the dock instead of
    // covering the screen.
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

    Rectangle {
        anchors.fill: parent
        color: Theme.alpha(Theme.bgDeep, 0.78)
        MouseArea { anchors.fill: parent; onClicked: Shell.launcherOpen = false }
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

            // --- search
            NotchRect {
                id: searchBox
                anchors.top: header.bottom
                anchors.topMargin: Theme.space3
                anchors.left: parent.left
                anchors.right: parent.right
                height: 38
                fillColor: Theme.alpha(Theme.bgDeep, 0.9)
                strokeColor: input.activeFocus ? Theme.accent : Theme.border
                notch: Theme.notchSmall
                notchTopLeft: false
                notchTopRight: false
                notchBottomRight: true
                notchBottomLeft: false

                Behavior on strokeColor { ColorAnimation { duration: Theme.durFast } }

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

                    // Built-in delegate rather than a hand-positioned rectangle:
                    // the old one sat at a fixed offset and painted a blinking dash
                    // across the placeholder text.
                    cursorDelegate: Rectangle {
                        width: 8
                        height: 2
                        y: parent.height - 4
                        color: Theme.accent

                        SequentialAnimation on opacity {
                            running: !Theme.reducedMotion
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.2; duration: 500 }
                            NumberAnimation { to: 1.0; duration: 500 }
                        }
                    }

                    Keys.onEscapePressed: Shell.launcherOpen = false
                    Keys.onDownPressed: root.selectByKey(root.selectedIndex + 1)
                    Keys.onUpPressed: root.selectByKey(root.selectedIndex - 1)
                    Keys.onReturnPressed: root.launch(root.selectedIndex)
                    Keys.onTabPressed: root.cycleCategory(1)
                    // Shift+Tab arrives as Backtab, not as Tab with a modifier.
                    Keys.onBacktabPressed: root.cycleCategory(-1)

                    CyberText {
                        visible: input.text === ""
                        text: Settings.t("Search applications")
                        role: "body"
                        caps: false
                        color: Theme.textMuted
                    }
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
                        }

                        CyberText {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.space3
                            anchors.verticalCenter: parent.verticalCenter
                            text: catItem.modelData
                            role: "label"
                            color: catItem.current ? Theme.danger
                                : (catMouse.containsMouse ? Theme.accent : Theme.textDim)
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
                    visible: root.results.length === 0
                    spacing: Theme.space2

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
