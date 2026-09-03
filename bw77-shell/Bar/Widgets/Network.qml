import QtQuick
import qs.Config
import qs.Common
import qs.Services

BarItem {
    id: root

    // Polling runs only while something is displaying it.
    Component.onCompleted: SysMon.acquire()
    Component.onDestruction: SysMon.release()

    readonly property bool anyTraffic: SysMon.down > 0 || SysMon.up > 0
    readonly property bool showIcon: (config && config.showIcon !== undefined)
        ? config.showIcon : true
    readonly property bool showRates: (config && config.showRates !== undefined)
        ? config.showRates : true

    tooltip: "Network activity"
    active: Popups.current === "network"
    onClicked: Popups.openAt("network", root, screenRef)

    Row {
        spacing: Theme.space2
        height: parent.height

        CyberText {
            visible: root.showIcon
            height: parent.height
            text: root.anyTraffic ? "\uf1eb" : "\uf127"
            role: "icon"
            sizeOverride: root.cfgFontSize
            color: root.cfgColor(root.anyTraffic ? Theme.accent : Theme.textMuted)
        }

        Column {
            visible: root.showRates
            anchors.verticalCenter: parent.verticalCenter
            spacing: -3

            CyberText {
                // Reserved width so changing rates never reflow the bar.
                width: 76
                text: "\u25BC " + SysMon.downLabel
                role: "micro"
                color: root.cfgColor(Theme.c("chartNet"))
            }
            CyberText {
                width: 76
                text: "\u25B2 " + SysMon.upLabel
                role: "micro"
                color: root.cfgColor(Theme.textMuted)
            }
        }
    }
}
