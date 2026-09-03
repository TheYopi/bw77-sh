import QtQuick
import qs.Config
import qs.Common

/*
 * Font chooser, keyboard first.
 *
 * The old one was a row that expanded into a 260px scrolling list with a search
 * field at the top - which meant the pane it lived in grew by a third, the rows
 * below it jumped, and choosing a font required clicking into a text field
 * before typing. On a surface driven with the arrow keys that is three separate
 * things going wrong at once.
 *
 * This takes the screen instead. Arrows move, Enter picks, Escape backs out,
 * and typing filters - with no field to focus first, because there is nothing
 * else on screen that could want the keystroke. The search strip only appears
 * once there is a query to show, so the default state is a list and a preview
 * rather than a list, a preview and an empty box.
 *
 * Every row is set in the family it names. That is the only honest way to
 * choose a typeface, and it is why this is a list rather than a stepper like
 * the other one-of-N controls in the shell.
 */
Item {
    id: root

    property string title: ""
    property string hint: ""
    property string current: ""

    // Sample printed beside each name and blown up in the preview. Icon fonts
    // are chosen for glyph coverage, so they get glyphs to look at rather than
    // a pangram that tells you nothing about whether the icons will render.
    property string sample: "Night City 0123"

    signal picked(string family)
    signal cancelled()

    property string query: ""
    property int highlight: 0

    // ---------------------------------------------------------------- sources

    /*
     * Qt.fontFamilies() is whatever fontconfig has registered, so no shelling
     * out to fc-list, and it is correct for fonts installed while the shell is
     * running as long as the picker is reopened.
     */
    property var families: []

    function rescan() {
        const all = Qt.fontFamilies();
        // Qt lists style variants as separate families ("Rajdhani Light"). They
        // are valid choices so they stay, but the list is deduplicated.
        const seen = {};
        const out = [];
        for (let i = 0; i < all.length; i++) {
            if (seen[all[i]]) continue;
            seen[all[i]] = true;
            out.push(all[i]);
        }
        return out.sort((a, b) => a.localeCompare(b));
    }

    readonly property var results: {
        const q = root.query.trim().toLowerCase();
        if (q === "") return root.families;
        return root.families.filter(f => f.toLowerCase().indexOf(q) !== -1);
    }

    readonly property string highlighted:
        (highlight >= 0 && highlight < results.length) ? results[highlight] : ""

    Component.onCompleted: {
        families = rescan();
        // Open on the family already in use rather than at the top of the
        // alphabet - the most likely reason to be here is to move away from it,
        // and that is easier when you can see what you are moving away from.
        const at = families.indexOf(root.current);
        highlight = at >= 0 ? at : 0;
        list.positionViewAtIndex(highlight, ListView.Center);
    }

    // Refiltering must not leave the cursor pointing past the end of a shorter
    // list, and should hold onto the highlighted family when it survives.
    onResultsChanged: {
        const keep = results.indexOf(root.highlighted);
        highlight = keep >= 0 ? keep : 0;
        list.positionViewAtIndex(highlight, ListView.Contain);
    }

    // ------------------------------------------------------------- navigation

    function move(delta) {
        if (results.length === 0) return;
        highlight = Math.max(0, Math.min(results.length - 1, highlight + delta));
        list.positionViewAtIndex(highlight, ListView.Contain);
    }

    function commit() {
        if (root.highlighted !== "") root.picked(root.highlighted);
    }

    /*
     * Returns true when the key was consumed.
     *
     * Handled through a call from the surface above rather than by taking Qt
     * focus: the Control Center already owns the keyboard for the whole window,
     * and two competing focus scopes on one layer surface is how you end up
     * with a list that scrolls behind a dialog.
     */
    function handleKey(event) {
        switch (event.key) {
        case Qt.Key_Escape:
            // First press clears the filter, second leaves. Escaping straight
            // out of a narrowed list means retyping the query to correct one
            // character of it.
            if (root.query !== "") root.query = "";
            else root.cancelled();
            return true;

        case Qt.Key_Return:
        case Qt.Key_Enter:
            root.commit();
            return true;

        case Qt.Key_Up:       root.move(-1); return true;
        case Qt.Key_Down:     root.move(1); return true;
        case Qt.Key_PageUp:   root.move(-8); return true;
        case Qt.Key_PageDown: root.move(8); return true;

        case Qt.Key_Home:
            root.highlight = 0;
            list.positionViewAtBeginning();
            return true;
        case Qt.Key_End:
            root.highlight = Math.max(0, root.results.length - 1);
            list.positionViewAtEnd();
            return true;

        case Qt.Key_Backspace:
            root.query = root.query.slice(0, -1);
            return true;
        }

        // Anything printable is a filter keystroke. No field to click into
        // first - that was the whole problem with the previous one.
        if (event.text.length === 1 && event.text >= " ") {
            root.query += event.text;
            return true;
        }
        return false;
    }

    // ----------------------------------------------------------------- chrome

    Rectangle {
        anchors.fill: parent
        color: Theme.alpha(Theme.bgDeep, 0.9)
        MouseArea { anchors.fill: parent; onClicked: root.cancelled() }
    }

    Panel {
        id: card
        anchors.centerIn: parent
        width: Math.min(parent.width - Theme.space6 * 2, 720)
        height: Math.min(parent.height - Theme.space6 * 2, 620)
        fillColor: Theme.bgBase
        fillOpacity: 0.98
        emphasis: "alert"
        serialSeed: "fontpicker"
        padding: Theme.space4

        // Swallows clicks so the dismiss catcher behind does not fire when the
        // pointer lands on the card itself.
        MouseArea { anchors.fill: parent }

        SectionHeader {
            id: head
            anchors.left: parent.left
            anchors.right: parent.right
            title: root.title
            subtitle: root.hint
            accentColor: Theme.danger
        }

        /*
         * Search strip.
         *
         * Absent until there is something to show. An always-present empty
         * field is a permanent invitation to click it, which is exactly the
         * habit this picker is trying to break - and it costs 30px of list on
         * every open to say nothing.
         */
        Item {
            id: search
            anchors.top: head.bottom
            anchors.topMargin: active ? Theme.space3 : 0
            anchors.left: parent.left
            anchors.right: parent.right

            readonly property bool active: root.query !== ""

            height: active ? 32 : 0
            opacity: active ? 1 : 0
            clip: true

            Behavior on height { NumberAnimation { duration: Theme.durFast; easing.type: Theme.easeSnap } }
            Behavior on opacity { NumberAnimation { duration: Theme.durFast } }

            NotchRect {
                anchors.fill: parent
                fillColor: Theme.alpha(Theme.bgDeep, 0.9)
                strokeColor: Theme.accent
                notch: 5
            }

            CyberText {
                id: prompt
                anchors.left: parent.left
                anchors.leftMargin: Theme.space3
                anchors.verticalCenter: parent.verticalCenter
                text: "/"
                role: "mono"
                color: Theme.danger
            }

            CyberText {
                id: queryText
                anchors.left: prompt.right
                anchors.leftMargin: Theme.space2
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, search.width * 0.6)
                text: root.query
                role: "label"
                caps: false
                color: Theme.text
                elide: Text.ElideLeft
            }

            // Blinking block cursor, because there is no real text field here
            // and without one there is nothing to say the typing is landing.
            Rectangle {
                anchors.left: queryText.right
                anchors.leftMargin: 2
                anchors.verticalCenter: parent.verticalCenter
                width: 7
                height: 13
                color: Theme.accent

                SequentialAnimation on opacity {
                    running: search.active && !Theme.reducedMotion
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.15; duration: 480 }
                    NumberAnimation { to: 1.0; duration: 480 }
                }
            }

            CyberText {
                anchors.right: parent.right
                anchors.rightMargin: Theme.space3
                anchors.verticalCenter: parent.verticalCenter
                text: root.results.length + "/" + root.families.length
                role: "micro"
                color: root.results.length === 0 ? Theme.danger : Theme.textMuted
            }
        }

        // --- the list
        ListView {
            id: list

            anchors.top: search.bottom
            anchors.topMargin: Theme.space3
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: preview.top
            anchors.bottomMargin: Theme.space3

            clip: true
            spacing: 1
            model: root.results
            boundsBehavior: Flickable.StopAtBounds

            delegate: Item {
                id: row
                required property string modelData
                required property int index

                readonly property bool isCurrent: modelData === root.current
                readonly property bool isHighlighted: index === root.highlight

                width: list.width - 6
                height: 34

                NotchRect {
                    anchors.fill: parent
                    visible: row.isHighlighted || row.isCurrent || rowMouse.containsMouse
                    fillColor: row.isHighlighted
                        ? Theme.alpha(Theme.accent, 0.2)
                        : Theme.alpha(Theme.accent, rowMouse.containsMouse ? 0.1 : 0.05)
                    strokeColor: row.isHighlighted ? Theme.accent : "transparent"
                    strokeWidth: row.isHighlighted ? Theme.borderWidthStrong : 0
                    notch: 5
                    notchTopLeft: false
                    notchTopRight: false
                    notchBottomRight: true
                    notchBottomLeft: false
                }

                // A diamond rather than a word: "in use" is a fact about one row
                // in several hundred, and a label would be dead weight on all of
                // them just to mark the one.
                Rectangle {
                    id: marker
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.space3
                    anchors.verticalCenter: parent.verticalCenter
                    width: 5
                    height: 5
                    rotation: 45
                    color: Theme.danger
                    visible: row.isCurrent
                }

                // The name, set in the face it names.
                Text {
                    anchors.left: marker.right
                    anchors.leftMargin: Theme.space3
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width * 0.5
                    text: row.modelData
                    font.family: row.modelData
                    font.pixelSize: Theme.fontBase
                    color: row.isHighlighted ? Theme.accent : Theme.text
                    elide: Text.ElideRight
                    renderType: Text.NativeRendering
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.space4
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.sample
                    font.family: row.modelData
                    font.pixelSize: Theme.fontSmall
                    color: row.isHighlighted ? Theme.textDim : Theme.textMuted
                    renderType: Text.NativeRendering
                }

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.highlight = row.index
                    // Single click commits. A list where clicking only
                    // highlights needs a second target to confirm against, and
                    // there is nowhere sensible to put one.
                    onClicked: root.picked(row.modelData)
                }
            }

            // Same crimson bar as the settings panes.
            Rectangle {
                parent: list
                x: list.width - width
                y: list.contentHeight > 0 ? list.visibleArea.yPosition * list.height : 0
                width: 3
                height: Math.max(24, list.visibleArea.heightRatio * list.height)
                color: Theme.alpha(Theme.danger, 0.85)
                visible: list.contentHeight > list.height
            }

            CyberText {
                anchors.centerIn: parent
                visible: root.results.length === 0
                text: Settings.t("No font matches that")
                role: "label"
                color: Theme.textMuted
            }
        }

        // --- preview and key legend
        Item {
            id: preview
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 84

            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: Theme.alpha(Theme.border, 0.9)
            }

            Text {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: Theme.space3
                text: root.highlighted === "" ? "" : root.sample
                font.family: root.highlighted
                font.pixelSize: Math.round(26 * Theme.scale)
                color: Theme.text
                elide: Text.ElideRight
                renderType: Text.NativeRendering
            }

            Row {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                spacing: Theme.space3

                Repeater {
                    model: [
                        { k: "\u2191\u2193", t: Settings.t("Move") },
                        { k: "\u21B5",       t: Settings.t("Apply") },
                        { k: "A-Z",          t: Settings.t("Search") },
                        { k: "ESC",          t: Settings.t("Back") }
                    ]

                    Row {
                        required property var modelData
                        spacing: Theme.space1

                        KeyChip {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.k
                        }

                        CyberText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.t
                            role: "micro"
                            color: Theme.textMuted
                        }
                    }
                }
            }
        }
    }
}
