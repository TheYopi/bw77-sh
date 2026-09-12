import QtQuick
import qs.Config
import qs.Common
import qs.Services
import qs.Modules.Desktop

Item {
    id: root

    // Polling runs only while something is displaying it.
    Component.onCompleted: SysMon.acquireFast()
    Component.onDestruction: SysMon.releaseFast()
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

        // Keys, not readings - see the note in SysMonPopup. The rate labels
        // move on every sample, so an array-literal model rebuilt both Graphs
        // ten times a second.
        Repeater {
            model: ["down", "up"]

            Column {
                id: metric
                required property string modelData

                readonly property bool isDown: modelData === "down"

                readonly property string label: isDown ? Settings.t("Down") : Settings.t("Up")
                readonly property string reading: isDown ? SysMon.downLabel : SysMon.upLabel
                readonly property var history: isDown ? SysMon.downHistory : SysMon.upHistory
                readonly property color tint: isDown ? Theme.c("chartNet") : Theme.warn

                width: col.width
                spacing: 2

                Row {
                    width: parent.width
                    CyberText {
                        text: metric.label
                        role: "micro"
                        color: Theme.textMuted
                        width: 50
                    }
                    CyberText {
                        text: metric.reading
                        role: "mono"
                        font.pixelSize: Theme.fontSmall
                        color: metric.tint
                    }
                }

                Graph {
                    width: parent.width
                    height: 54
                    values: metric.history
                    // Networks have no ceiling, so scale to the busiest sample
                    // in view rather than a fixed maximum.
                    maxValue: Math.max(1024, Math.max.apply(null, metric.history.concat([0])))
                    lineColor: metric.tint
                }
            }
        }
    }
}
