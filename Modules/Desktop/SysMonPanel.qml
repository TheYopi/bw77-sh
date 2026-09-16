import QtQuick
import qs.Config
import qs.Common
import qs.Services
import qs.Modules.Desktop

/*
 * System monitor.
 *
 * Every reading is a block: a ticked arc with the figure set inside its mouth,
 * a rule, and underneath it either the processes responsible for the reading or
 * the reading's own recent history. MetricBlock draws one; this decides which
 * ones there are and what goes into them.
 *
 * --- what changed, and why the history moved
 *
 * The readings used to be a number with a segmented bar under it and the
 * sparkline washed out behind the whole thing as texture. That says how much,
 * and nothing else. A gauge says how much OUT OF WHAT at a glance - the point
 * of a dial is that a half-full one is recognisable without reading the number
 * at all - and the space under it is worth more spent on WHY: on a memory
 * block, "firefox 4.2 G" is the thing a person opened the widget to find out,
 * and no amount of history tells them.
 *
 * So history is kept for the readings that have nothing to attribute. Nothing
 * owns a temperature, and a transfer rate belongs to a link rather than to a
 * process, so those blocks keep their graph and it is drawn to be read rather
 * than to be texture.
 *
 * Two layouts, chosen by shape. Down the widget when it is tall, across it when
 * it is wide - a 600x120 strip along the top of a screen and a 280x400 column
 * down the side are both reasonable things to want, and one arrangement cannot
 * serve both. Each block turns on its own axis as well; see MetricBlock.
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
     * "cpu" | "memory" | "network" | "gpu" | "sysmon"
     */
    property string kind: "sysmon"

    readonly property bool needsSysMon: kind !== "gpu"
    readonly property bool needsGpu: kind === "gpu"

    /*
     * The process lists are a second sampler, and a more expensive one, so it
     * is acquired only by the widgets that draw them.
     *
     * A network widget has no process list at all - a rate belongs to a link,
     * not to a program - so it holds neither half. A GPU widget wants the DRM
     * half and not `ps`; everything else wants `ps` and not the DRM sweep. See
     * Services/Procs.
     */
    readonly property bool needsProcs: kind === "cpu" || kind === "memory"
                                    || kind === "sysmon"
    readonly property bool needsGpuProcs: kind === "gpu"

    Component.onCompleted: {
        if (root.needsSysMon) SysMon.acquire();
        if (root.needsGpu) Gpu.acquire();
        if (root.needsProcs) Procs.acquire();
        if (root.needsGpuProcs) Procs.acquireGpu();
    }
    Component.onDestruction: {
        if (root.needsSysMon) SysMon.release();
        if (root.needsGpu) Gpu.release();
        if (root.needsProcs) Procs.release();
        if (root.needsGpuProcs) Procs.releaseGpu();
    }
    padding: Theme.space3

    readonly property bool wide: WidgetMetrics.isWide(root.kind, width, height)

    function cfg(key, fallback) {
        return (config && config[key] !== undefined) ? config[key] : fallback;
    }

    /*
     * --- how the process figures are written
     *
     * Percentages are whole numbers: the sampler reports hundredths so that
     * small users can be ranked against each other, but "3.72%" in a 40px
     * column is four characters of noise for one of signal.
     *
     * Everything below one percent is written as "<1%" rather than rounded.
     * Rounding it prints "0%", which reads as "this process is not using the
     * GPU" next to the name of a process that is - and a column of zeroes
     * looks like a readout that has stopped. A compositor drawing a desktop
     * genuinely sits at a few tenths of a percent, so this is the common case
     * rather than an edge one.
     */
    function pctLabel(v) {
        if (v <= 0) return "0%";
        if (v < 1) return "<1%";
        return Math.round(v) + "%";
    }

    // Kibibytes in, the same units the memory readout above uses out. One
    // decimal, so a list of five processes does not read as five identical
    // "2 G" rows.
    function kibLabel(v) { return SysMon.formatBytes(v * 1024, 1); }

    /*
     * --- the readings
     *
     * Each is a description rather than a component: a label, the figure, the
     * proportion for the arc, and what belongs underneath. MetricBlock does not
     * know what it is drawing, which is what lets a GPU block and a memory
     * block be the same thing with different contents.
     */
    readonly property var cpuMetric: ({
        label: "CPU", text: SysMon.cpu + "%", ratio: SysMon.cpu / 100,
        gauge: true, detail: "procs",
        procs: Procs.byCpu, formatter: root.pctLabel,
        empty: Settings.t("Reading processes..."),
        history: SysMon.cpuHistory, historyMax: 100,
        color: Theme.c("chartCpu") })

    /*
     * Memory reads as an amount, not as a proportion.
     *
     * The arc already says what fraction of the machine is in use - that is
     * what an arc is for - so repeating it as "72%" in the middle of the dial
     * spends the largest text in the block on the one thing the block was
     * already saying. The absolute figure is the part the gauge cannot show.
     */
    readonly property var memMetric: ({
        label: Settings.t("RAM"), text: SysMon.memUsedLabel,
        ratio: SysMon.mem / 100, gauge: true, detail: "procs",
        procs: Procs.byMem, formatter: root.kibLabel,
        empty: Settings.t("Reading processes..."),
        history: SysMon.memHistory, historyMax: 100,
        color: Theme.c("chartRam") })

    // Nothing owns a temperature, so this one keeps its history.
    readonly property var tempMetric: ({
        label: Settings.t("TEMP"), text: SysMon.temp + "°",
        ratio: Math.min(1, SysMon.temp / 100), gauge: true, detail: "graph",
        procs: [], formatter: root.pctLabel, empty: "",
        history: SysMon.tempHistory, historyMax: 100,
        color: Theme.c("chartTemp") })

    /*
     * --- the two directions, as two blocks
     *
     * They used to share one: the big figure was the download rate with no
     * marker on it and the upload was a note underneath carrying the only
     * arrow in the block, so the one labelled direction was upload and the
     * unlabelled number above it could be read as anything. Worse, the note was
     * dropped on a short cell - which is exactly what the standalone network
     * widget is - so on that widget the marked direction was the one that
     * disappeared.
     *
     * Two blocks, each named, each with its own history. Neither reading
     * depends any more on the other one being visible.
     *
     * No gauge on either: see the note in MetricBlock about inventing a
     * ceiling. The graph is scaled to the highest sample it holds instead, so
     * the shape of the traffic is legible whether the link is doing kilobytes
     * or gigabits.
     */
    function peak(list) {
        let m = 1;
        for (let i = 0; i < (list || []).length; i++)
            if (list[i] > m) m = list[i];
        return m;
    }

    readonly property var downMetric: ({
        label: Settings.t("DOWNLOAD"), text: SysMon.downLabel, ratio: 0,
        gauge: false, detail: "graph",
        procs: [], formatter: root.kibLabel, empty: "",
        history: SysMon.downHistory, historyMax: root.peak(SysMon.downHistory),
        color: Theme.c("chartNet") })

    readonly property var upMetric: ({
        label: Settings.t("UPLOAD"), text: SysMon.upLabel, ratio: 0,
        gauge: false, detail: "graph",
        procs: [], formatter: root.kibLabel, empty: "",
        history: SysMon.upHistory, historyMax: root.peak(SysMon.upHistory),
        color: Theme.c("chartNet") })

    /*
     * --- GPU
     *
     * Each reading is included only when the card actually reports it, which
     * is why Gpu exposes hasUsage/hasTemp/hasVram/hasPower rather than letting
     * a caller test the number. An idle GPU genuinely reads 0% and 0W, so a
     * widget that treats "not reported" and "zero" the same will state, with
     * total confidence, that a card is drawing no power.
     *
     * The process lists come from the kernel's DRM fdinfo, which only accounts
     * for clients this user can see - so the empty text says the list may be
     * incomplete rather than claiming nothing is using the card.
     */
    function gpuMetricFor(key) {
        switch (key) {
        case "gpuUsage":
            return { label: "GPU", text: Gpu.usage + "%", ratio: Gpu.usage / 100,
                     gauge: true, detail: "procs",
                     procs: Procs.byGpu, formatter: root.pctLabel,
                     empty: Settings.t("Nothing drawing"),
                     history: Gpu.usageHistory, historyMax: 100,
                     color: Theme.c("chartCpu") };
        case "gpuVram":
            return { label: "VRAM", text: Gpu.hasVram
                        ? SysMon.formatBytes(Gpu.vramUsedMb * 1024 * 1024, 1) : "--",
                     ratio: Gpu.vramRatio, gauge: true, detail: "procs",
                     procs: Procs.byVram, formatter: root.kibLabel,
                     empty: Settings.t("Nothing drawing"),
                     history: Gpu.vramHistory, historyMax: 100,
                     color: Theme.c("chartRam") };
        case "gpuTemp":
            return { label: Settings.t("TEMP"), text: Gpu.temp + "°",
                     ratio: Math.min(1, Gpu.temp / 100),
                     gauge: true, detail: "graph",
                     procs: [], formatter: root.pctLabel, empty: "",
                     history: Gpu.tempHistory, historyMax: 100,
                     color: Theme.c("chartTemp") };
        }
        return { label: "GPU", text: Gpu.power + " W", ratio: 0,
                 gauge: false, detail: "none",
                 procs: [], formatter: root.pctLabel, empty: "",
                 history: [], historyMax: 100,
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
     * A delegate here is not cheap: an ArcMeter with its canvas, a Graph with
     * two paths and a sixty-point polyline, a process table, and several
     * CyberTexts each carrying its own FontMetrics. Multiply by the number of
     * metrics switched on, destroy and rebuild the lot ten times a second, and
     * do it permanently, because this widget lives on the wallpaper and is
     * never closed. That was the single largest recurring cost in the shell.
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
        case "network": return ["down", "up"];
        case "gpu":     return root.gpuKeys;
        }

        // The combined widget, which keeps its per-metric switches.
        const out = [];
        if (root.cfg("showCpu", true))  out.push("cpu");
        if (root.cfg("showRam", true))  out.push("mem");
        if (root.cfg("showTemp", true)) out.push("temp");
        if (root.cfg("showNet", true))  { out.push("down"); out.push("up"); }
        return out;
    }

    function metricFor(key) {
        switch (key) {
        case "cpu":  return root.cpuMetric;
        case "mem":  return root.memMetric;
        case "temp": return root.tempMetric;
        case "down": return root.downMetric;
        case "up":   return root.upMetric;
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
    Item {
        id: body
        anchors.fill: parent
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
        readonly property int gap: Theme.space3

        readonly property real cellW: root.wide
            ? Math.max(84, (width - gap * (count - 1)) / count)
            : width
        readonly property real cellH: root.wide
            ? height
            : Math.max(46, (height - gap * (count - 1)) / count)

        Grid {
            columns: root.wide ? body.count : 1
            rows: root.wide ? 1 : body.count
            spacing: body.gap

            Repeater {
                model: root.metricKeys

                MetricBlock {
                    id: cell
                    required property string modelData

                    // The readings, re-resolved whenever a sample lands. One
                    // binding on the block rather than eight separate lookups
                    // in its children, so one sample costs one call.
                    readonly property var metric: root.metricFor(modelData)

                    width: body.cellW
                    height: body.cellH

                    label: metric.label
                    valueText: metric.text
                    ratio: metric.ratio
                    hasGauge: metric.gauge && root.cfg("showBars", true)
                    accentColor: metric.color
                    detail: metric.detail
                    procModel: metric.procs
                    procFormatter: metric.formatter
                    procEmptyText: metric.empty
                    history: metric.history
                    historyMax: metric.historyMax
                }
            }
        }
    }
}
