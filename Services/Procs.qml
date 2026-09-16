pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Config

/*
 * Which processes are using the most of each resource.
 *
 * Fed by Scripts/procs.sh, which groups by command name rather than listing
 * PIDs - see the note there. Four lists come back, each already cut to five
 * entries: processor, memory, graphics engine and video memory.
 *
 * --- two reference counts, not one
 *
 * The processor and memory lists come out of a single `ps`. The GPU lists come
 * out of a sweep over every open file descriptor on the machine looking for
 * DRM clients - cheap, but not free, and pointless on a desktop with no GPU
 * widget on it. So a holder says which half it needs, and the sampler is told
 * which sections to collect. A desktop with only a memory widget never walks
 * /proc for graphics clients at all.
 */
Singleton {
    id: root

    property int users: 0        // processor and memory
    property int gpuUsers: 0     // graphics engine and VRAM

    readonly property bool active: users > 0 || gpuUsers > 0

    function acquire() { users = users + 1; }
    function release() { users = Math.max(0, users - 1); }

    function acquireGpu() { gpuUsers = gpuUsers + 1; }
    function releaseGpu() { gpuUsers = Math.max(0, gpuUsers - 1); }

    /*
     * Slower than the gauges by an order of magnitude, deliberately.
     *
     * The arc under a reading is an instrument and wants to move; a list of
     * process names is read rather than watched, and at ten samples a second
     * the rows reorder faster than a person can follow one down the list. Two
     * seconds is also what makes the `ps` affordable at all.
     */
    property real intervalSec: 2.0

    // Each entry is { n: name, v: number }. Percent for cpu and gpu,
    // kibibytes for mem and vram.
    property var byCpu: []
    property var byMem: []
    property var byGpu: []
    property var byVram: []

    readonly property string sections:
        (users > 0 ? "cpu" : "") +
        (users > 0 && gpuUsers > 0 ? "," : "") +
        (gpuUsers > 0 ? "gpu" : "")

    onActiveChanged: {
        if (active) return;
        // Held only while something is displaying them.
        byCpu = [];
        byMem = [];
        byGpu = [];
        byVram = [];
    }

    /*
     * The sections are an argument, and the sampler reads its arguments once at
     * startup - so a running process keeps collecting whatever it was launched
     * for no matter what the binding says now. Bounce it, and restore the
     * binding rather than assigning `running` outright, or the poller would
     * keep going after the last holder let go. Same reasoning as SysMon.
     */
    onSectionsChanged: {
        if (!active) return;
        proc.running = false;
        proc.running = Qt.binding(() => root.active);
    }

    Process {
        id: proc
        running: root.active
        command: ["bash", `${Quickshell.shellDir}/Scripts/procs.sh`,
                  String(root.intervalSec), root.sections]

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                if (!line || line[0] !== "{") return;
                let d;
                try { d = JSON.parse(line); } catch (e) { return; }

                root.byCpu = d.cpu || [];
                root.byMem = d.mem || [];
                root.byGpu = d.gpu || [];
                root.byVram = d.vram || [];
            }
        }
    }
}
