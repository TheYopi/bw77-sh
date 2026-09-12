import QtQuick
import qs.Config
import qs.Common
import qs.Services
import qs.Modules.Desktop

/*
 * System monitor.
 *
 * The previous version was a label, a number and a line graph, stacked three
 * times with a network row underneath - which is what every system monitor
 * widget on every desktop looks like, and it read as a chart library with a
 * border rather than as part of this shell. Worse, the three rows divided the
 * remaining height between them by arithmetic, so shrinking the widget drove
 * each row's height towards zero and the label, the value and the graph piled
 * up on the same pixels. That is the overlap.
 *
 * What it looks like now: each metric is a readout block, with the number set
 * large in its own colour, a segmented meter beneath it in the game's style,
 * and the sparkline behind the whole thing as a backdrop rather than beside it
 * as a chart. The numbers are the widget; the history is texture.
 *
 * Two layouts, chosen by shape. Down the widget when it is tall, across it when
 * it is wide - a 600x120 strip along the top of a screen and a 280x400 column
 * down the side are both reasonable things to want, and one arrangement cannot
 * serve both.
 */
WidgetFrame {
    id: root
    accentColor: Theme.danger

    property var config: ({})

    /*
     * Which device this instance reports on.
     *
     * "sysmon" is the original all-in-one and stays, because an existing
     * desktop has one placed and because a single strip covering everything is
     * a reasonable thing to want. The rest are the same panel scoped to one
     * device, so a CPU block and a GPU block can be sized and placed
     * independently rather than sharing one frame's worth of height between
     * however many metrics happened to be switched on.
     *
     * The renderer below never knew what it was drawing - it walks a list of
     * readout descriptions - so this is a change to what goes into that list,
     * not to how it is drawn.
     *
     * "cpu" | "memory" | "network" | "gpu" | "sysmon"
     */
    property string kind: "sysmon"

    readonly property bool needsSysMon: kind !== "gpu"
    readonly property bool needsGpu: kind === "gpu"

    // Polling runs only while something is displaying it, and only the
    // samplers this widget actually reads.
    Component.onCompleted: {
        if (root.needsSysMon) SysMon.acquire();
        if (root.needsGpu) Gpu.acquire();
    }
    Component.onDestruction: {
        if (root.needsSysMon) SysMon.release();
        if (root.needsGpu) Gpu.release();
    }
    padding: Theme.space3

    readonly property bool wide: WidgetMetrics.isWide(root.kind, width, height)

    function cfg(key, fallback) {
        return (config && config[key] !== undefined) ? config[key] : fallback;
    }

    readonly property var cpuMetric: ({
        label: "CPU", value: SysMon.cpu, text: SysMon.cpu + "%",
        ratio: SysMon.cpu / 100, history: SysMon.cpuHistory,
        note: SysMon.clock + " MHz", color: Theme.c("chartCpu") })

    readonly property var memMetric: ({
        label: Settings.t("MEM"), value: SysMon.mem, text: SysMon.mem + "%",
        ratio: SysMon.mem / 100, history: SysMon.memHistory,
        note: SysMon.memUsedLabel + " / " + SysMon.memTotalLabel,
        color: Theme.c("chartRam") })

    readonly property var tempMetric: ({
        label: Settings.t("TEMP"), value: SysMon.temp,
        text: SysMon.temp + "\u00B0",
        ratio: Math.min(1, SysMon.temp / 100), history: SysMon.tempHistory,
        note: Settings.t("load") + " " + SysMon.load,
        color: Theme.c("chartTemp") })

    /*
     * Both directions, each with its arrow.
     *
     * The big figure was the download rate with no marker on it, and the
     * upload was the note underneath carrying the only arrow in the block - so
     * the one labelled direction was upload and the unlabelled number above it
     * could be read as anything. Worse, the note is dropped on a short cell,
     * which is exactly what the standalone network widget is, so on that
     * widget the marked direction was the one that disappeared.
     *
     * The download arrow goes on the main figure and the upload note keeps
     * its own, so neither reading depends on the other being visible.
     */
    readonly property var netMetric: ({
        label: Settings.t("NET"), value: SysMon.down,
        text: "\u25BC " + SysMon.downLabel,
        ratio: 0, history: SysMon.downHistory,
        note: "\u25B2 " + SysMon.upLabel, color: Theme.c("chartNet") })

    /*
     * --- GPU
     *
     * Each reading is included only when the card actually reports it, which
     * is why Gpu exposes hasUsage/hasTemp/hasVram/hasPower rather than letting
     * a caller test the number. An idle GPU genuinely reads 0% and 0W, so a
     * widget that treats "not reported" and "zero" the same will state, with
     * total confidence, that a card is drawing no power.
     *
     * Power rides along as the note on the usage block rather than taking a
     * block of its own: it is a single number with no meaningful percentage
     * behind it, so a meter under it would be measuring against a maximum
     * nothing here knows.
     */
    function gpuMetricFor(key) {
        switch (key) {
        case "gpuUsage":
            return { label: "GPU", value: Gpu.usage, text: Gpu.usage + "%",
                     ratio: Gpu.usage / 100, history: Gpu.usageHistory,
                     note: Gpu.hasPower ? (Gpu.power + " W") : Gpu.name,
                     color: Theme.c("chartCpu") };
        case "gpuVram":
            return { label: "VRAM", value: Math.round(Gpu.vramRatio * 100),
                     text: Math.round(Gpu.vramRatio * 100) + "%",
                     ratio: Gpu.vramRatio, history: Gpu.vramHistory,
                     note: Gpu.vramLabel, color: Theme.c("chartRam") };
        case "gpuTemp":
            return { label: Settings.t("TEMP"), value: Gpu.temp,
                     text: Gpu.temp + "\u00B0",
                     ratio: Math.min(1, Gpu.temp / 100), history: Gpu.tempHistory,
                     note: Gpu.name, color: Theme.c("chartTemp") };
        }
        return { label: "GPU", value: Gpu.power, text: Gpu.power + " W",
                 ratio: 0, history: [], note: Gpu.name,
                 color: Theme.c("chartCpu") };
    }

    readonly property var gpuKeys: {
        const out = [];
        if (!Gpu.present) return out;

        if (Gpu.hasUsage) out.push("gpuUsage");
        if (Gpu.hasVram)  out.push("gpuVram");
        if (Gpu.hasTemp)  out.push("gpuTemp");

        // A card that reports power and nothing else - some Intel parts - still
        // gets a block, or the widget would be empty on a machine that does
        // have a GPU.
        if (out.length === 0 && Gpu.hasPower) out.push("gpuPower");

        return out;
    }

    /*
     * --- what the Repeater below is given, and why it is names rather than
     *     readings
     *
     * This was a list of metric OBJECTS, each one built from SysMon.cpu,
     * SysMon.mem and the rest. Those move ten times a second, so the binding
     * produced a fresh array ten times a second - and a Repeater handed a new
     * JavaScript array rebuilds every delegate it has.
     *
     * A delegate here is not cheap. It is a Graph, which is a Shape with two
     * paths and a sixty-point polyline; three CyberTexts, each carrying its own
     * FontMetrics; and a SegmentBar, which builds one Rectangle with a colour
     * Behavior per segment and sizes that count from the cell width, so a wide
     * widget is thirty of them. Multiply by the number of metrics switched on,
     * destroy and rebuild the lot ten times a second, and do it permanently,
     * because this widget lives on the wallpaper and is never closed. That was
     * the single largest recurring cost in the shell.
     *
     * The composition of the list only changes when the user changes it, so
     * that is what the model carries. Each delegate looks its own readings up
     * and re-binds them in place, which is the part that was always supposed to
     * be happening ten times a second.
     */
    readonly property var metricKeys: {
        switch (root.kind) {
        case "cpu":     return ["cpu", "temp"];
        case "memory":  return ["mem"];
        case "network": return ["net"];
        case "gpu":     return root.gpuKeys;
        }

        // The combined widget, which keeps its per-metric switches.
        const out = [];
        if (root.cfg("showCpu", true))  out.push("cpu");
        if (root.cfg("showRam", true))  out.push("mem");
        if (root.cfg("showTemp", true)) out.push("temp");
        if (root.cfg("showNet", true))  out.push("net");
        return out;
    }

    function metricFor(key) {
        switch (key) {
        case "cpu":  return root.cpuMetric;
        case "mem":  return root.memMetric;
        case "temp": return root.tempMetric;
        case "net":  return root.netMetric;
        }
        return root.gpuMetricFor(key);
    }

    /*
     * No heading.
     *
     * This drew its own: a crimson tick, the word SYSTEM, a hairline out to the
     * edge and a disk percentage on the right. It cost 22px of a 240px widget
     * to name something the readings underneath already name, and every widget
     * having its own idea of a heading is what made four of them on one
     * wallpaper look like four unrelated programs.
     */
    /*
     * --- the metrics
     *
     * A Grid rather than a Column or a Row, with the axis chosen by shape: one
     * column when tall, one row when wide. Cells are sized by division, but
     * unlike before there is a floor under them - and when the widget is too
     * small for the number of metrics enabled, the cells stop shrinking and the
     * overflow is clipped rather than being allowed to stack on top of itself.
     */
    Item {
        id: body
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true

        /*
         * Something to read when there is nothing to report.
         *
         * A GPU widget on a machine with no readable card would otherwise be an
         * empty frame, which is indistinguishable from the widget being broken.
         * It says which of the two it is.
         */
        CyberText {
            anchors.centerIn: parent
            width: parent.width - Theme.space2 * 2
            visible: root.metricKeys.length === 0
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            role: "micro"
            caps: false
            color: Theme.textMuted
            text: root.kind !== "gpu" ? Settings.t("Nothing selected")
                : (Gpu.unavailable
                    ? Settings.t("No readable GPU on this machine")
                    : (Gpu.present ? Settings.t("This GPU reports no metrics")
                                   : Settings.t("Reading GPU...")))
        }

        readonly property int count: Math.max(1, root.metricKeys.length)
        readonly property int gap: Theme.space2

        readonly property real cellW: root.wide
            ? Math.max(76, (width - gap * (count - 1)) / count)
            : width
        readonly property real cellH: root.wide
            ? height
            : Math.max(38, (height - gap * (count - 1)) / count)

        Grid {
            columns: root.wide ? body.count : 1
            rows: root.wide ? 1 : body.count
            spacing: body.gap

            Repeater {
                model: root.metricKeys

                Item {
                    id: cell
                    required property string modelData

                    // The readings, re-resolved whenever a sample lands. This
                    // is a binding on the cell rather than four separate
                    // lookups in the children, so one sample costs one call.
                    readonly property var metric: root.metricFor(modelData)

                    width: body.cellW
                    height: body.cellH

                    // History as a backdrop, not a chart. Drawn behind the
                    // numbers at low opacity and bled off the bottom edge, so
                    // it reads as the texture of the reading rather than as a
                    // second thing to look at.
                    Graph {
                        anchors.fill: parent
                        anchors.topMargin: cell.height * 0.35
                        values: cell.metric.history
                        maxValue: 100
                        lineColor: cell.metric.color
                        opacity: 0.28
                        visible: root.cfg("showBars", true) && cell.height >= 44
                    }

                    Row {
                        id: readout
                        anchors.left: parent.left
                        anchors.top: parent.top
                        spacing: Theme.space2

                        CyberText {
                            anchors.baseline: bigValue.baseline
                            text: cell.metric.label
                            role: "micro"
                            color: Theme.textMuted
                            visible: root.cfg("showLabels", true)
                        }

                        CyberText {
                            id: bigValue
                            text: cell.metric.text
                            role: "mono"
                            // Scales with the cell so a large widget is
                            // genuinely readable across a room, capped so a
                            // small one does not blow out.
                            sizeOverride: Math.max(Theme.fontSmall,
                                Math.min(Theme.fontTitle, cell.height * 0.42))
                            color: cell.metric.color
                        }
                    }

                    // Secondary reading - the clock speed, the absolute memory
                    // figure, the upload rate. Dropped first when space runs
                    // out, because the number above it is the point.
                    CyberText {
                        anchors.left: parent.left
                        anchors.top: readout.bottom
                        anchors.right: parent.right
                        text: cell.metric.note
                        role: "micro"
                        caps: false
                        color: Theme.alpha(Theme.textMuted, 0.85)
                        elide: Text.ElideRight
                        visible: cell.height >= 58 && cell.width >= 110
                    }

                    // Segmented meter along the bottom, in the game's style
                    // rather than a smooth progress bar.
                    SegmentBar {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 6
                        segments: Math.max(6, Math.floor(cell.width / 9))
                        value: cell.metric.ratio
                        visible: root.cfg("showBars", true)
                            && cell.metric.ratio > 0
                            && cell.height >= 40
                    }
                }
            }
        }
    }
}
