pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Config

/*
 * System metrics, fed by Scripts/sysmon.sh so no /proc parsing happens on the
 * UI thread. Keeps a rolling history for the desktop graph widgets.
 */
Singleton {
    id: root

    /*
     * Sampling rate, and how often a sample is kept.
     *
     * Ten a second, because the gauges are read as live instruments and a
     * two-second step made them look broken - a value would sit still long
     * enough to seem frozen and then jump. The sampler is cheap at this rate;
     * see the note in sysmon.sh about which readings are taken less often.
     *
     * The history arrays are a separate question. They feed the desktop graphs,
     * which want a minute of context, and sixty samples at ten a second is six
     * seconds of it. So only every tenth sample is kept and the graphs still
     * span a minute - the live values update ten times a second, the history
     * once.
     */
    property real intervalSec: 0.1
    property int historyLength: 60

    readonly property int historyStride:
        Math.max(1, Math.round(1.0 / Math.max(0.01, intervalSec)))

    property int tick: 0

    /*
     * Reference counted, so the poller only runs while something is displaying
     * it. Previously it polled forever - parsing JSON and rebuilding five
     * history arrays every two seconds - even with no bar widget, no desktop
     * widget and no popup open.
     */
    property int users: 0
    readonly property bool active: users > 0

    function acquire() { users = users + 1; }
    function release() { users = Math.max(0, users - 1); }

    property int cpu: 0
    property int clock: 0          // MHz
    property int temp: 0           // degrees C
    property int mem: 0            // percent
    property int memUsedKb: 0
    property int memTotalKb: 0
    property int swap: 0
    property int down: 0           // bytes/sec
    property int up: 0
    property int disk: 0
    property real load: 0

    property var cpuHistory: []
    property var memHistory: []
    property var tempHistory: []
    property var downHistory: []
    property var upHistory: []

    readonly property string memUsedLabel: formatBytes(memUsedKb * 1024, 1)
    readonly property string memTotalLabel: formatBytes(memTotalKb * 1024, 1)
    readonly property string downLabel: formatRate(down)
    readonly property string upLabel: formatRate(up)

    function formatBytes(b, decimals) {
        const units = ["B", "K", "M", "G", "T"];
        let i = 0;
        let v = b;
        while (v >= 1024 && i < units.length - 1) { v /= 1024; i++; }
        return v.toFixed(decimals === undefined ? 0 : decimals) + units[i];
    }

    function formatRate(bytesPerSec) {
        if (bytesPerSec < 1024) return `${bytesPerSec} B/S`;
        if (bytesPerSec < 1024 * 1024) return `${(bytesPerSec / 1024).toFixed(0)} KB/S`;
        return `${(bytesPerSec / 1024 / 1024).toFixed(1)} MB/S`;
    }

    onActiveChanged: {
        if (active) return;
        // Drop the history rather than holding five arrays of samples nobody
        // is looking at until the next consumer appears.
        cpuHistory = [];
        memHistory = [];
        tempHistory = [];
        downHistory = [];
        upHistory = [];
    }

    function push(arr, v) {
        const next = arr.slice(-(historyLength - 1));
        next.push(v);
        return next;
    }

    Process {
        id: proc
        running: root.active
        command: ["bash", `${Quickshell.shellDir}/Scripts/sysmon.sh`, String(root.intervalSec)]

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                if (!line || line[0] !== "{") return;
                let d;
                try { d = JSON.parse(line); } catch (e) { return; }

                root.cpu = d.cpu;
                root.clock = d.clock;
                root.temp = d.temp;
                root.mem = d.mem;
                root.memUsedKb = d.memUsedKb;
                root.memTotalKb = d.memTotalKb;
                root.swap = d.swap;
                root.down = d.down;
                root.up = d.up;
                root.disk = d.disk;
                root.load = d.load;

                // Rebuilding five arrays ten times a second is the one part of
                // this that would actually cost something, and nothing reads
                // them at that resolution.
                root.tick = (root.tick + 1) % root.historyStride;
                if (root.tick !== 0) return;

                root.cpuHistory  = root.push(root.cpuHistory, d.cpu);
                root.memHistory  = root.push(root.memHistory, d.mem);
                root.tempHistory = root.push(root.tempHistory, d.temp);
                root.downHistory = root.push(root.downHistory, d.down);
                root.upHistory   = root.push(root.upHistory, d.up);
            }
        }
    }
}
