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
            title: Settings.t("Network")
            subtitle: Settings.t("Throughput across all interfaces")
            glitch: false
        }

        Repeater {
            model: [
                { label: Settings.t("Down"), value: SysMon.downLabel,
                  history: SysMon.downHistory, color: Theme.c("chartNet") },
                { label: Settings.t("Up"),   value: SysMon.upLabel,
                  history: SysMon.upHistory,   color: Theme.warn }
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
                    height: 54
                    values: modelData.history
                    // Networks have no ceiling, so scale to the busiest sample
                    // in view rather than a fixed maximum.
                    maxValue: Math.max(1024, Math.max.apply(null, modelData.history.concat([0])))
                    lineColor: modelData.color
                }
            }
        }
    }
}
