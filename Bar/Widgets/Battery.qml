import QtQuick
import Quickshell.Services.UPower
import qs.Config
import qs.Common

BarItem {
    id: root

    readonly property var dev: UPower.displayDevice
    readonly property bool present: dev && dev.isLaptopBattery
    readonly property real pct: dev ? dev.percentage : 0
    readonly property bool charging: dev && dev.state === UPowerDeviceState.Charging

    visible: present
    accentColor: pct < 0.15 && !charging ? Theme.danger : Theme.accent
    tooltip: dev && dev.timeToEmpty > 0
        ? `${Math.round(dev.timeToEmpty / 60)} min remaining`
        : (charging ? "Charging" : "")

    Row {
        spacing: Theme.space2
        height: parent.height

        CyberText {
            height: parent.height
            visible: root.charging
            text: "\u26A1"
            role: "icon"
            color: Theme.warn
        }

        SegmentBar {
            anchors.verticalCenter: parent.verticalCenter
            width: 30
            height: 10
            segments: 6
            value: root.pct
            fillColor: root.charging ? Theme.warn
                : (root.pct < 0.15 ? Theme.danger : Theme.accent)
            warnAtHigh: false
        }

        CyberText {
            height: parent.height
            width: 38
            horizontalAlignment: Text.AlignRight
            text: Math.round(root.pct * 100) + "%"
            role: "mono"
            sizeOverride: root.cfgFontSize
            weightOverride: root.cfgFontWeight
            color: root.cfgColor(Theme.textDim)
        }
    }
}
