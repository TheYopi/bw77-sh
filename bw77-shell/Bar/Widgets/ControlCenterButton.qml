import QtQuick
import qs.Config
import qs.Common
import qs.Services

/*
 * Opens the Control Center. The dock already carries the application launcher,
 * so the bar's leading button is more useful pointed at settings.
 */
BarItem {
    id: root

    accentColor: Theme.danger
    tooltip: "Control Center"
    active: Shell.controlCenterOpen
    onClicked: Shell.toggleControlCenter("home")

    // A chamfered block with a single slash: the shell's own mark, echoing the
    // game's menu glyph without reproducing licensed artwork.
    Item {
        anchors.verticalCenter: parent.verticalCenter
        width: 18
        height: 18

        NotchRect {
            anchors.fill: parent
            fillColor: (root.hovered || root.active) ? Theme.danger : "transparent"
            strokeColor: Theme.danger
            notch: 5
            notchTopLeft: true
            notchTopRight: false
            notchBottomRight: true
            notchBottomLeft: false

            Behavior on fillColor { ColorAnimation { duration: Theme.durFast } }
        }

        Rectangle {
            anchors.centerIn: parent
            width: 2
            height: parent.height * 0.75
            rotation: 35
            color: (root.hovered || root.active) ? Theme.bgDeep : Theme.danger

            Behavior on color { ColorAnimation { duration: Theme.durFast } }
        }
    }
}
