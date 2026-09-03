import QtQuick
import qs.Config
import qs.Common
import qs.Services
import qs.Modules.Desktop

Item {
    id: root

    // Polling runs only while something is displaying it.
    Component.onCompleted: SysMon.acquire()
    Component.onDestruction: SysMon.release()
    implicitWidth: 340
    implicitHeight: col.implicitHeight

    Column {
        id: col
        width: parent.width
        spacing: Theme.space3

        SectionHeader {
            width: parent.width
            title: Settings.t("System")
            subtitle: `${SysMon.clock} MHz · load ${SysMon.load}`
            glitch: false
        }

        Repeater {
            model: [
                { label: "CPU",  value: SysMon.cpu + "%",
                  history: SysMon.cpuHistory,  color: Theme.c("chartCpu") },
                { label: Settings.t("MEM"),  value: `${SysMon.memUsedLabel} / ${SysMon.memTotalLabel}`,
                  history: SysMon.memHistory,  color: Theme.c("chartRam") },
                { label: Settings.t("TEMP"), value: SysMon.temp + "\u00B0C",
                  history: SysMon.tempHistory, color: Theme.c("chartTemp") }
            ]

            Column {
                required property var modelData
                width: col.width
                spacing: 2

                Row {
                    width: parent.width
                    CyberText {
                        text: modelData.label
                        role: "micro"
                        color: Theme.textMuted
                        width: 50
                    }
                    CyberText {
                        text: modelData.value
                        role: "mono"
                        font.pixelSize: Theme.fontSmall
                        color: modelData.color
                    }
                }

                Graph {
                    width: parent.width
                    height: 48
                    values: modelData.history
                    maxValue: 100
                    lineColor: modelData.color
                }
            }
        }

        Row {
            width: parent.width
            spacing: Theme.space3
            CyberText { text: Settings.t("DISK"); role: "micro"; color: Theme.textMuted; width: 50 }
            SegmentBar {
                anchors.verticalCenter: parent.verticalCenter
                width: col.width - 110
                height: 10
                segments: 20
                value: SysMon.disk / 100
                fillColor: Theme.c("chartNet")
            }
            CyberText {
                text: SysMon.disk + "%"
                role: "mono"
                font.pixelSize: Theme.fontSmall
                color: Theme.textDim
            }
        }
    }
}
