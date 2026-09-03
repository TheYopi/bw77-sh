import QtQuick
import qs.Config
import qs.Common
import qs.Services

BarItem {
    id: root

    accentColor: Theme.danger
    tooltip: "Applications"
    active: Shell.launcherOpen
    onClicked: Shell.toggleLauncher()

    // The Samurai-adjacent mark: a chamfered block with a single slash, close to
    // the game's menu glyph without reproducing licensed artwork.
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
