import QtQuick
import qs.Config
import qs.Common
import qs.Services

BarItem {
    id: root

    accentColor: Theme.danger
    tooltip: "Session"
    onClicked: Shell.toggleSession()

    CyberText {
        // Full height so the glyph centres on the bar's centre line rather than
        // sitting at the top of the content area.
        height: parent.height
        text: "\u23FB"
        role: "icon"
        font.pixelSize: Theme.fontLarge
        color: root.hovered ? Theme.danger : Theme.textDim

        Behavior on color { ColorAnimation { duration: Theme.durFast } }
    }
}
