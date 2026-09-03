pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Config

/*
 * GPU metrics, fed by Scripts/gpu.sh.
 *
 * Sampled far more slowly than SysMon. The CPU gauges are read as live
 * instruments and run ten times a second off a shell that only touches /proc;
 * a GPU sample on an NVIDIA machine forks nvidia-smi, which is not something to
 * do ten times a second in the background for a widget on the wallpaper. Two
 * seconds is fast enough to watch a load arrive and cheap enough to leave on.
 *
 * Every metric is -1 when the machine cannot report it, never 0. The difference
 * matters: an idle GPU genuinely reads 0% and 0W, and a widget that cannot tell
 * that apart from "this card does not expose power draw" will confidently show
 * a card drawing no power. Consumers check `has*` rather than truthiness.
 */
Singleton {
    id: root

    property real intervalSec: 2.0
    property int historyLength: 60

    /*
     * Reference counted, like SysMon: the sampler runs only while a widget is
     * on screen showing it. With no GPU widget placed, nothing runs at all.
     */
    property int users: 0
    readonly property bool active: users > 0

    function acquire() { users = users + 1; }
    function release() { users = Math.max(0, users - 1); }

    // "amd" | "nvidia" | "intel" | "none", and "" until the first sample lands.
    property string vendor: ""
    property string name: ""

    property int usage: -1        // percent
    property int temp: -1         // degrees C
    property int vramUsedMb: -1
    property int vramTotalMb: -1
    property int power: -1        // watts

    readonly property bool present: vendor !== "" && vendor !== "none"

    readonly property bool hasUsage: usage >= 0
    readonly property bool hasTemp: temp >= 0
    readonly property bool hasVram: vramUsedMb >= 0 && vramTotalMb > 0
    readonly property bool hasPower: power >= 0

    readonly property real vramRatio:
        hasVram ? Math.min(1, vramUsedMb / vramTotalMb) : 0

    function mb(v) {
        if (v < 0) return "--";
        return v >= 1024 ? (v / 1024).toFixed(1) + " GiB" : v + " MiB";
    }

    readonly property string vramLabel:
        hasVram ? (mb(vramUsedMb) + " / " + mb(vramTotalMb)) : "--"

    property var usageHistory: []
    property var tempHistory: []
    property var vramHistory: []

    function push(arr, v) {
        const next = arr.slice(-(historyLength - 1));
        next.push(v);
        return next;
    }

    /*
     * Set once the sampler has reported a machine with no GPU it can read.
     *
     * The script exits immediately in that case rather than looping, so the
     * process stopping is expected and is not a failure to report. Without
     * this the widget would sit on "waiting for the first sample" forever on a
     * machine that had already given its answer.
     */
    readonly property bool unavailable: vendor === "none"

    Process {
        id: proc
        running: root.active && !root.unavailable
        command: ["bash", `${Quickshell.shellDir}/Scripts/gpu.sh`,
                  String(root.intervalSec)]

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                if (!line || line[0] !== "{") return;
                let d;
                try { d = JSON.parse(line); } catch (e) { return; }

                root.vendor = d.vendor !== undefined ? String(d.vendor) : "none";
                root.name = d.name !== undefined ? String(d.name) : "";

                root.usage = d.usage;
                root.temp = d.temp;
                root.vramUsedMb = d.vramUsedMb;
                root.vramTotalMb = d.vramTotalMb;
                root.power = d.power;

                // Only real readings enter the history. Pushing -1 would put a
                // notch in the sparkline every time a metric was unsupported,
                // which reads as the value having dropped.
                if (root.hasUsage)
                    root.usageHistory = root.push(root.usageHistory, root.usage);
                if (root.hasTemp)
                    root.tempHistory = root.push(root.tempHistory, root.temp);
                if (root.hasVram)
                    root.vramHistory = root.push(root.vramHistory,
                                                 Math.round(root.vramRatio * 100));
            }
        }
    }
}
