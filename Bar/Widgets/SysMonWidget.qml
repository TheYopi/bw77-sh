import QtQuick
import qs.Config
import qs.Common
import qs.Services

/* Compact readouts with segmented meters, matching the in-game stat columns. */
BarItem {
    id: root

    // Polling runs only while something is displaying it.
    Component.onCompleted: SysMon.acquire()
    Component.onDestruction: SysMon.release()

    readonly property bool showCpu:  (config && config.showCpu  !== undefined) ? config.showCpu  : true
    readonly property bool showRam:  (config && config.showRam  !== undefined) ? config.showRam  : true
    readonly property bool showTemp: (config && config.showTemp !== undefined) ? config.showTemp : true
    readonly property bool showNet:  (config && config.showNet  !== undefined) ? config.showNet  : false
    readonly property bool showBars: (config && config.showBars !== undefined) ? config.showBars : true
    readonly property bool showLabels: (config && config.showLabels !== undefined)
        ? config.showLabels : true

    tooltip: `Load ${SysMon.load}  ·  ${SysMon.clock} MHz  ·  disk ${SysMon.disk}%`
    active: Popups.current === "sysmon"
    onClicked: Popups.openAt("sysmon", root, screenRef)

    Row {
        spacing: Theme.space3
        height: parent.height

        Repeater {
            model: [
                { on: root.showCpu,  label: "CPU",  value: SysMon.cpu / 100,
                  text: SysMon.cpu + "%",       color: Theme.c("chartCpu") },
                { on: root.showRam,  label: Settings.t("MEM"),  value: SysMon.mem / 100,
                  text: SysMon.mem + "%",       color: Theme.c("chartRam") },
                { on: root.showTemp, label: Settings.t("TMP"),  value: Math.min(1, SysMon.temp / 100),
                  text: SysMon.temp + "\u00B0",  color: Theme.c("chartTemp") }
            ]

            Row {
                required property var modelData
                visible: modelData.on
                spacing: Theme.space1
                height: parent.height

                CyberText {
                    visible: root.showLabels
                    height: parent.height
                    text: modelData.label
                    role: "micro"
                    color: root.cfgColor(Theme.textMuted)
                }

                SegmentBar {
                    visible: root.showBars
                    anchors.verticalCenter: parent.verticalCenter
                    width: 34
                    height: 9
                    segments: 8
                    value: modelData.value
                    fillColor: modelData.color
                }

                CyberText {
                    height: parent.height
                    // Reserved width for the widest reading ("100%", "-40C").
                    // Letting this size to content made every widget to the
                    // left jump on each two-second update.
                    width: 38
                    horizontalAlignment: Text.AlignRight
                    text: modelData.text
                    role: "mono"
                    sizeOverride: root.cfgFontSize
                    weightOverride: root.cfgFontWeight
                    color: root.cfgColor(Theme.textDim)
                }
            }
        }

        Column {
            visible: root.showNet
            anchors.verticalCenter: parent.verticalCenter
            spacing: -2

            CyberText {
                width: 76
                text: "\u2193 " + SysMon.downLabel
                role: "micro"
                color: Theme.c("chartNet")
            }
            CyberText {
                width: 76
                text: "\u2191 " + SysMon.upLabel
                role: "micro"
                color: Theme.textMuted
            }
        }
    }
}
