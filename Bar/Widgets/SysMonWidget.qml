import QtQuick
import qs.Config
import qs.Common
import qs.Services

/*
 * Compact readouts: a label and a figure per metric.
 *
 * The segmented meters are gone. At bar height they were eight blocks four
 * pixels wide, redrawn as fast as the sampler runs, and the figure beside them
 * already said the same thing more precisely - the desktop widget is where a
 * meter has the room to be read as one.
 */
BarItem {
    id: root

    // Polling runs only while something is displaying it.
    Component.onCompleted: SysMon.acquire()
    Component.onDestruction: SysMon.release()

    readonly property bool showCpu:  (config && config.showCpu  !== undefined) ? config.showCpu  : true
    readonly property bool showRam:  (config && config.showRam  !== undefined) ? config.showRam  : true
    readonly property bool showTemp: (config && config.showTemp !== undefined) ? config.showTemp : true
    readonly property bool showNet:  (config && config.showNet  !== undefined) ? config.showNet  : false
    readonly property bool showLabels: (config && config.showLabels !== undefined)
        ? config.showLabels : true
    readonly property bool showDividers: (config && config.showDividers !== undefined)
        ? config.showDividers : true

    tooltip: `Load ${SysMon.load}  ·  ${SysMon.clock} MHz  ·  disk ${SysMon.disk}%`
    active: Popups.current === "sysmon"
    onClicked: Popups.openAt("sysmon", root, screenRef)

    Row {
        // The same gap inside a readout and between them, which is what keeps
        // the divider centred in the space it divides.
        spacing: Theme.space2
        height: parent.height

        /*
         * The model is three fixed keys, and every live value is resolved
         * inside the delegate.
         *
         * It used to be an array literal holding the readings themselves. A
         * Repeater given a JavaScript array rebuilds its delegates whenever the
         * array identity changes, and that binding named SysMon.cpu, .mem and
         * .temp - all of which move ten times a second. So ten times a second,
         * every second the bar was on screen, this tore down and reconstructed
         * three Rows, six Texts and three SegmentBars, and each SegmentBar
         * built eight Rectangles with a colour Behavior apiece. Around thirty
         * scene-graph objects and their bindings, created and destroyed 600
         * times a minute, to print three numbers that each fit in four
         * characters.
         *
         * Keyed like this the tree is built once and only the leaf bindings
         * re-evaluate. Nothing about what is drawn changed.
         */
        Repeater {
            model: ["cpu", "mem", "temp"]

            Row {
                id: metric
                required property string modelData
                required property int index

                // Whether anything is drawn to the left of this one, so the
                // first readout on the bar never leads with a divider - which
                // is what would happen with CPU switched off.
                readonly property bool hasPrev: index === 1 ? root.showCpu
                    : index === 2 ? (root.showCpu || root.showRam) : false

                readonly property bool on: modelData === "cpu" ? root.showCpu
                    : modelData === "mem" ? root.showRam : root.showTemp

                readonly property string label: modelData === "cpu" ? "CPU"
                    : modelData === "mem" ? Settings.t("MEM") : Settings.t("TEMP")

                // Memory reads as what is in use rather than as a percentage:
                // "7.4G" is the figure people check against the machine they
                // know they have, and the percentage is in the popup.
                readonly property string reading: modelData === "cpu" ? SysMon.cpu + "%"
                    : modelData === "mem" ? SysMon.memUsedLabel
                    : SysMon.temp + "\u00B0"

                visible: on
                spacing: Theme.space2
                height: parent.height

                // A rule, not a gap: three readouts in a row at the same size
                // read as one long string of numbers without it.
                Rectangle {
                    visible: root.showDividers && metric.hasPrev
                    anchors.verticalCenter: parent.verticalCenter
                    width: 1
                    height: Math.round(parent.height * 0.42)
                    color: Theme.alpha(Theme.border, 0.9)
                }

                CyberText {
                    visible: root.showLabels
                    height: parent.height
                    text: metric.label
                    // The bar's text size, like the figure beside it. On the
                    // "micro" role's own size the label sat noticeably smaller
                    // than the number it names, so "CPU 42%" read as two
                    // different pieces of text rather than one readout.
                    role: "mono"
                    sizeOverride: root.cfgFontSize
                    color: root.cfgColor(Theme.textMuted)
                }

                CyberText {
                    height: parent.height
                    // Reserved width for the widest reading ("100%", "-40C").
                    // Letting this size to content made every widget to the
                    // left jump on each two-second update.
                    width: 38
                    horizontalAlignment: Text.AlignRight
                    text: metric.reading
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
