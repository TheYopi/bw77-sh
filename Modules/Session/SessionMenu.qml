import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Config
import qs.Common
import qs.Services

/*
 * Centered power menu. Grabs focus so Escape and click-outside both dismiss it,
 * and the destructive actions carry the crimson emphasis rather than being
 * separated by position alone.
 */
PanelWindow {
    id: root

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "bw77-session"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    // Without this the compositor shrinks the surface out of the bar's reserved
    // zone, so the dimming stops short of the bar and the dock instead of
    // covering the screen.
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
        anchors.fill: parent
        color: Theme.alpha(Theme.bgDeep, 0.82)

        MouseArea {
            anchors.fill: parent
            onClicked: Shell.sessionOpen = false
        }
    }

    Scanlines { anchors.fill: parent; strength: Settings.fx.scanlineOpacity * 1.5 }

    GlitchBox {
        category: "menus"
        id: surfaceAnim
        anchors.fill: parent
        shown: Shell.sessionOpen

        Panel {
            id: card
            anchors.centerIn: parent
            width: 620
            height: 300
            // Default emphasis, not "alert": the crimson double-stroke made
            // these read as warnings next to the Control Center's plain frame.
            // Matches the quick settings panel: these are surfaces in their own
            // right, not cards resting on one, so they take the base background
            // rather than the raised tone.
            fillColor: Theme.bgBase
            serialSeed: "session"
            padding: Theme.space5

            // Snap in with a brief vertical stretch - reads as a signal locking on.

            SectionHeader {
                id: header
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                title: Settings.t("System")
                subtitle: Quickshell.env("USER") + "@" + Quickshell.env("HOSTNAME")
                accentColor: Theme.danger
            }

            // Positioned below the header rather than centred in the card, so
            // the username is never covered by the tile row.
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: header.bottom
                anchors.topMargin: Theme.space4
                spacing: Theme.space3

                Repeater {
                    model: [
                        { label: Settings.t("Lock"),     glyph: "\uf023", act: () => Session.lock(),      danger: false },
                        { label: Settings.t("Log out"),  glyph: "\uf2f5", act: () => Session.logout(),    danger: false },
                        { label: Settings.t("Suspend"),  glyph: "\uf186", act: () => Session.suspend(),   danger: false },
                        { label: Settings.t("Restart"),  glyph: "\uf021", act: () => Session.reboot(),    danger: true  },
                        { label: Settings.t("Shut down"),glyph: "\uf011", act: () => Session.shutdown(),  danger: true  }
                    ]

                    Item {
                        id: tile
                        required property var modelData
                        required property int index

                        width: 96
                        height: 108

                        readonly property bool selected: root.selectedIndex === index

                        NotchRect {
                            anchors.fill: parent
                            fillColor: tile.selected
                                ? Theme.alpha(tile.modelData.danger ? Theme.danger : Theme.accent, 0.9)
                                : Theme.alpha(Theme.bgRaised, 0.9)
                            strokeColor: tile.modelData.danger ? Theme.danger : Theme.accent
                            notch: Theme.notch
                            notchTopLeft: false
                            notchTopRight: false
                            notchBottomRight: true
                            notchBottomLeft: false

                            Behavior on fillColor { ColorAnimation { duration: Theme.durFast } }
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: Theme.space3

                            CyberText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: tile.modelData.glyph
                                role: "icon"
                                font.pixelSize: 28
                                color: tile.selected
                                    ? Theme.textOnAccent
                                    : (tile.modelData.danger ? Theme.danger : Theme.accent)
                            }

                            CyberText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                // "Shut down" is wider than the tile.
                                width: tile.width - Theme.space2
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                text: tile.modelData.label
                                role: "label"
                                color: tile.selected ? Theme.textOnAccent : Theme.text
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.selectedIndex = tile.index
                            onClicked: {
                                Shell.sessionOpen = false;
                                tile.modelData.act();
                            }
                        }
                    }
                }
            }

            Row {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                spacing: Theme.space3

                KeyChip { text: "\u2190 \u2192" }
                CyberText { text: Settings.t("Select"); role: "micro"; color: Theme.textMuted
                            anchors.verticalCenter: parent.verticalCenter }
                KeyChip { text: "ESC" }
                CyberText { text: Settings.t("Close"); role: "micro"; color: Theme.textMuted
                            anchors.verticalCenter: parent.verticalCenter }
            }
        }
    }

    property int selectedIndex: 0

    // Keyboard driving: arrows move, Enter fires, Escape closes.
    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: Shell.sessionOpen = false
        Keys.onLeftPressed: root.selectedIndex = (root.selectedIndex + 4) % 5
        Keys.onRightPressed: root.selectedIndex = (root.selectedIndex + 1) % 5
        Keys.onReturnPressed: {
            const actions = [Session.lock, Session.logout, Session.suspend,
                             Session.reboot, Session.shutdown];
            Shell.sessionOpen = false;
            actions[root.selectedIndex]();
        }
    }
}
