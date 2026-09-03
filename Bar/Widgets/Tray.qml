import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import qs.Config
import qs.Common
import qs.Services

/*
 * System tray. Icons arrive at whatever size the application shipped them at,
 * so everything is forced to Settings.bar.trayIconSize to keep the row even.
 *
 * Optional colourisation flattens every icon to a single theme colour, which is
 * what makes a tray of mismatched vendor logos read as part of the shell.
 */
BarItem {
    id: root

    // Interactive so the frame and hover state are drawn around the tray area,
    // but clicks belong to the individual icons.
    interactive: true
    captureClicks: false
    visible: SystemTray.items.values.length > 0

    // Global pixel size, times an optional per-instance scale. Two knobs
    // because two tray widgets on different bars often want different sizes.
    readonly property real scale: (config && config.scale) ? config.scale : 1.0
    readonly property int iconSize: Math.round(Settings.bar.trayIconSize * scale)
    readonly property color tint: Settings.bar.trayColorCustom !== ""
        ? Settings.bar.trayColorCustom
        : Theme.c(Settings.bar.trayColorRole)

    Row {
        spacing: Theme.space2
        height: parent.height

        Repeater {
            model: SystemTray.items

            Item {
                id: entry
                required property SystemTrayItem modelData

                width: root.iconSize
                height: root.iconSize
                anchors.verticalCenter: parent.verticalCenter

                IconImage {
                    id: icon
                    anchors.fill: parent
                    source: entry.modelData.icon
                    // Hidden when colourising: MultiEffect draws the result and
                    // showing both would double up the alpha.
                    visible: !Settings.bar.trayColorize
                    opacity: itemMouse.containsMouse ? 1.0 : 0.85

                    Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
                }

                MultiEffect {
                    anchors.fill: parent
                    source: icon
                    visible: Settings.bar.trayColorize
                    colorization: 1.0
                    colorizationColor: root.tint
                    opacity: itemMouse.containsMouse ? 1.0 : 0.85

                    Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
                }

                // Attention state gets the game's warning yellow rather than a badge.
                Rectangle {
                    visible: entry.modelData.status === SystemTrayItem.NeedsAttention
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    width: 5
                    height: 5
                    color: Theme.warn
                }

                MouseArea {
                    id: itemMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: (m) => {
                        if (m.button === Qt.LeftButton && !entry.modelData.onlyMenu) {
                            entry.modelData.activate();
                            return;
                        }
                        if (!entry.modelData.hasMenu) return;

                        // Our own menu, themed to match. Falling back to the
                        // platform menu is possible but it is a Qt or GTK widget
                        // the application owns, so it can never match the shell.
                        if (Settings.bar.customTrayMenu)
                            Popups.openMenu(entry.modelData.menu, entry, root.screenRef);
                        else
                            menuAnchor.open();
                    }
                }

                QsMenuAnchor {
                    id: menuAnchor
                    menu: entry.modelData.menu
                    anchor.item: entry
                    anchor.edges: Edges.Bottom
                }
            }
        }
    }
}
