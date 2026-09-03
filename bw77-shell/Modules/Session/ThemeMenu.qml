import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Config
import qs.Common
import qs.Services

/*
 * Palette switcher: a horizontal carousel of preview cards.
 *
 * PathView rather than a grid or a ListView, because it wraps around on its own
 * - scrolling past the last palette lands back on the first with no special
 * casing. The path is a straight horizontal line, so the cards stay flat; the
 * only depth cue is scale and opacity falling off from the centre, which is
 * enough to say "this one is selected" without tipping into 3D.
 */
PanelWindow {
    id: root

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "bw77-theme-menu"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    // Without this the compositor shrinks the surface out of the bar's reserved
    // zone, so the dimming stops short of the bar and the dock instead of
    // covering the screen.
    exclusionMode: ExclusionMode.Ignore

    readonly property var builtins: ["nightcity", "arasaka", "militech", "kang-tao", "mox",
                                     "sixth-street", "animals", "maelstrom", "valentinos",
                                     "kuromi", "kiroshi", "breach-protocol"]
    property var userPalettes: []
    property var previews: ({})

    readonly property var palettes: {
        const out = builtins.slice();
        for (let i = 0; i < userPalettes.length; i++) {
            if (out.indexOf(userPalettes[i]) === -1) out.push(userPalettes[i]);
        }
        return out;
    }

    readonly property string selectedName:
        carousel.currentIndex >= 0 && carousel.currentIndex < palettes.length
            ? palettes[carousel.currentIndex] : ""

    function apply() {
        if (selectedName !== "") Settings.theme.name = selectedName;
        Shell.themeMenuOpen = false;
    }

    Component.onCompleted: {
        scanUser.running = true;
        loadPreviews.running = true;
    }

    // Start on whatever is already in use.
    function syncToCurrent() {
        const i = palettes.indexOf(Settings.theme.name);
        if (i >= 0) carousel.positionViewAtIndex(i, PathView.Center);
    }

    Process {
        id: scanUser
        command: ["sh", "-c",
            `ls "${Settings.configDir}/palettes"/*.json 2>/dev/null | ` +
            `xargs -r -n1 basename | sed 's/\\.json$//'`]
        stdout: StdioCollector {
            onStreamFinished: {
                root.userPalettes = text.trim() === "" ? [] : text.trim().split("\n");
                root.syncToCurrent();
            }
        }
    }

    /*
     * Every palette is read in one pass and cached as a plain object. Reading
     * each file from QML would mean one FileView per card; this is a single
     * process, and the cards are pure renderers of what it returns.
     */
    Process {
        id: loadPreviews
        command: ["sh", "-c",
            `for f in "${Quickshell.shellDir}/Config/Palettes"/*.json ` +
            `"${Settings.configDir}/palettes"/*.json; do ` +
            `[ -f "$f" ] || continue; ` +
            `printf '%s\\t' "$(basename "$f" .json)"; ` +
            `tr -d '\\n' < "$f"; printf '\\n'; done`]
        stdout: StdioCollector {
            onStreamFinished: {
                const map = {};
                const lines = text.trim().split("\n");
                for (let i = 0; i < lines.length; i++) {
                    const tab = lines[i].indexOf("\t");
                    if (tab < 0) continue;
                    const name = lines[i].substring(0, tab);
                    try {
                        map[name] = JSON.parse(lines[i].substring(tab + 1));
                    } catch (e) {
                        // A malformed user palette should not take the menu down.
                    }
                }
                root.previews = map;
                root.syncToCurrent();
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.alpha(Theme.bgDeep, 0.88)
        MouseArea { anchors.fill: parent; onClicked: Shell.themeMenuOpen = false }
    }

    Scanlines { anchors.fill: parent; strength: Settings.fx.scanlineOpacity * 1.5 }

    GlitchBox {
        category: "theme"
        anchors.fill: parent
        shown: Shell.themeMenuOpen

        Panel {
            id: card
            anchors.centerIn: parent
            width: Math.min(parent.width - 80, 1100)
            height: 460
            // Default emphasis, not "alert": the crimson double-stroke made
            // these read as warnings next to the Control Center's plain frame.
            // Matches the quick settings panel: these are surfaces in their own
            // right, not cards resting on one, so they take the base background
            // rather than the raised tone.
            fillColor: Theme.bgBase
            serialSeed: "theme"
            padding: Theme.space5

            SectionHeader {
                id: header
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                title: Settings.t("Palette")
                subtitle: `${root.palettes.length} available · in use: ${Settings.theme.name}`
                accentColor: Theme.danger
            }

            PathView {
                id: carousel

                anchors.top: header.bottom
                anchors.bottom: footer.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: Theme.space3
                anchors.bottomMargin: Theme.space3

                model: root.palettes

                // Odd number so one card sits dead centre.
                pathItemCount: 7
                cacheItemCount: 4

                // Keeps the current item pinned to the centre of the path.
                preferredHighlightBegin: 0.5
                preferredHighlightEnd: 0.5
                highlightRangeMode: PathView.StrictlyEnforceRange
                highlightMoveDuration: Theme.dur(260)

                // Whole card widths, so a flick lands on a card rather than
                // between two.
                snapMode: PathView.SnapOneItem
                dragMargin: height / 2
                flickDeceleration: 2400
                clip: true

                readonly property real cardW: 180
                readonly property real cardH: 250

                // A straight horizontal line: flat, no perspective. Scale and
                // opacity are attributes along it rather than transforms, which
                // is what keeps the motion from reading as 3D.
                path: Path {
                    startX: 0
                    startY: carousel.height / 2

                    PathAttribute { name: "itemScale"; value: 0.72 }
                    PathAttribute { name: "itemOpacity"; value: 0.35 }
                    PathAttribute { name: "itemZ"; value: 0 }

                    PathLine { x: carousel.width * 0.5; y: carousel.height / 2 }

                    PathAttribute { name: "itemScale"; value: 1.0 }
                    PathAttribute { name: "itemOpacity"; value: 1.0 }
                    PathAttribute { name: "itemZ"; value: 100 }

                    PathLine { x: carousel.width; y: carousel.height / 2 }

                    PathAttribute { name: "itemScale"; value: 0.72 }
                    PathAttribute { name: "itemOpacity"; value: 0.35 }
                    PathAttribute { name: "itemZ"; value: 0 }
                }

                delegate: Item {
                    id: slot
                    required property string modelData
                    required property int index

                    readonly property bool isCurrent: PathView.isCurrentItem

                    width: carousel.cardW
                    height: carousel.cardH

                    scale: PathView.itemScale === undefined ? 1 : PathView.itemScale
                    opacity: PathView.itemOpacity === undefined ? 1 : PathView.itemOpacity
                    z: PathView.itemZ === undefined ? 0 : PathView.itemZ

                    ThemeCard {
                        anchors.fill: parent
                        name: slot.modelData
                        palette: root.previews[slot.modelData]
                        selected: slot.isCurrent
                        hovered: cardMouse.containsMouse
                    }

                    // A tick under the card in use, so "selected" and "applied"
                    // stay visually distinct.
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.bottom
                        anchors.topMargin: 6
                        width: 40
                        height: 3
                        visible: slot.modelData === Settings.theme.name
                        color: Theme.warn
                    }

                    MouseArea {
                        id: cardMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            // First click brings a card to the centre; clicking
                            // the centred card applies it.
                            if (slot.isCurrent) root.apply();
                            else carousel.currentIndex = slot.index;
                        }
                    }
                }

                // Wheel steps one card at a time and wraps at either end.
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    onWheel: (w) => {
                        if (w.angleDelta.y > 0 || w.angleDelta.x < 0)
                            carousel.decrementCurrentIndex();
                        else
                            carousel.incrementCurrentIndex();
                    }
                }
            }

            Row {
                id: footer
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.space4

                Row {
                    spacing: Theme.space1
                    KeyChip { text: "\u2190 \u2192" }
                    CyberText { text: Settings.t("Browse"); role: "micro"; color: Theme.textMuted
                                height: parent.height }
                }
                Row {
                    spacing: Theme.space1
                    KeyChip { text: "\u21B5" }
                    CyberText { text: Settings.t("Apply"); role: "micro"; color: Theme.textMuted
                                height: parent.height }
                }
                Row {
                    spacing: Theme.space1
                    KeyChip { text: "ESC" }
                    CyberText { text: Settings.t("Close"); role: "micro"; color: Theme.textMuted
                                height: parent.height }
                }
            }
        }
    }

    Item {
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: Shell.themeMenuOpen = false
        Keys.onLeftPressed: carousel.decrementCurrentIndex()
        Keys.onRightPressed: carousel.incrementCurrentIndex()
        Keys.onUpPressed: carousel.decrementCurrentIndex()
        Keys.onDownPressed: carousel.incrementCurrentIndex()
        Keys.onReturnPressed: root.apply()
        Keys.onEnterPressed: root.apply()

        // Home and End are cheap to support and useful with a long list.
        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Home) {
                carousel.positionViewAtIndex(0, PathView.Center);
                event.accepted = true;
            } else if (event.key === Qt.Key_End) {
                carousel.positionViewAtIndex(root.palettes.length - 1, PathView.Center);
                event.accepted = true;
            }
        }
    }
}
