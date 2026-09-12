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
            title: Settings.t("System")
            subtitle: `${SysMon.clock} MHz · load ${SysMon.load}`
            glitch: false
        }

        /*
         * Keys, not readings. See the same note in Bar/Widgets/SysMonWidget.
         *
         * An array literal naming SysMon.cpu and friends handed the Repeater a
         * new model ten times a second, so this popup destroyed and rebuilt
         * three Graphs - each one a Shape with two paths and a polyline of
         * sixty points - on every sample, for as long as it was open.
         */
        Repeater {
            model: ["cpu", "mem", "temp"]

            Column {
                id: metric
                required property string modelData

                readonly property string label: modelData === "cpu" ? "CPU"
                    : modelData === "mem" ? Settings.t("MEM") : Settings.t("TEMP")

                readonly property string reading: modelData === "cpu" ? SysMon.cpu + "%"
                    : modelData === "mem" ? `${SysMon.memUsedLabel} / ${SysMon.memTotalLabel}`
                    : SysMon.temp + "\u00B0C"

                readonly property var history: modelData === "cpu" ? SysMon.cpuHistory
                    : modelData === "mem" ? SysMon.memHistory : SysMon.tempHistory

                readonly property color tint: modelData === "cpu" ? Theme.c("chartCpu")
                    : modelData === "mem" ? Theme.c("chartRam") : Theme.c("chartTemp")

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
                    height: 48
                    values: metric.history
                    maxValue: 100
                    lineColor: metric.tint
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
