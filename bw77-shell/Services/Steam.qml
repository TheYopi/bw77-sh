pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/*
 * Icons for running Steam games.
 *
 * A Steam game reports its app id as "steam_app_<number>" and ships no desktop
 * entry, so the normal resolve-then-icon-theme path in Apps finds nothing and
 * the dock falls back to the generic executable box. The number in that app id
 * is enough to find the game's artwork, which Steam keeps on disk keyed by it.
 *
 * Two places are tried, in this order:
 *
 *   1. The icon theme, as "steam_icon_<number>". Steam installs these for games
 *      you have made a shortcut for, and going through the theme means proper
 *      size selection. Handled in Apps.iconFor, not here - it needs no scan.
 *
 *   2. Steam's own artwork cache, via Scripts/steam-icons.sh. This is the
 *      fallback for the majority of games, which have no shortcut.
 *
 * The scan is lazy and cached. Nothing runs until something actually asks for a
 * steam_app_ icon, which on a machine with no games installed is never. After
 * that it is one pass over a directory of a few hundred entries, held in memory
 * and refreshed only when a request misses - a game installed while the shell
 * is running is a miss, and one rescan picks it up.
 */
Singleton {
    id: root

    // appid (string) -> absolute file path
    property var icons: ({})

    property bool scanning: false
    property bool scanned: false

    // Guards against rescanning on every frame when a game genuinely has no
    // artwork at all. Without it, a miss would start a scan, the scan would
    // finish still missing, and the next binding evaluation would ask again.
    property var missed: ({})

    // Files can appear after a scan - a game installed, or artwork downloaded
    // lazily on first launch - so a miss is allowed to retry, just not often.
    readonly property int retryMs: 30000
    property real lastScan: 0

    /*
     * Returns a path, or "" if nothing is known yet.
     *
     * Deliberately not a blocking lookup: the first call for an unknown id
     * returns empty and schedules a scan, and the binding re-evaluates when
     * `icons` is replaced. The dock shows its fallback for that one pass.
     *
     * The bookkeeping is deferred rather than done inline because this is
     * called from a binding. Touching `missed` and `lastScan` here would make
     * the caller's binding depend on them, and then writing them would
     * invalidate the very binding being evaluated - it settles, but only after
     * re-running itself for no reason. Through callLater the binding depends on
     * `icons` alone, which is the only thing that changes the answer.
     */
    function iconFor(appid) {
        const key = String(appid);
        if (!key) return "";

        const hit = root.icons[key];
        if (hit) return hit;

        Qt.callLater(root.noteMiss, key);
        return "";
    }

    function noteMiss(key) {
        const now = Date.now();

        // Already known to be missing, and it is too soon to look again.
        if (root.missed[key] && (now - root.lastScan) <= root.retryMs) return;

        const next = Object.assign({}, root.missed);
        next[key] = true;
        root.missed = next;

        root.scan();
    }

    function scan() {
        if (root.scanning) return;
        root.scanning = true;
        root.lastScan = Date.now();
        proc.running = true;
    }

    Process {
        id: proc
        running: false
        command: ["bash", `${Quickshell.shellDir}/Scripts/steam-icons.sh`]

        /*
         * Collected whole rather than parsed line by line as it arrives.
         *
         * A SplitParser here would race the process ending: the scan is a
         * one-shot that exits as soon as it has printed, and reading the
         * collected map on `running` going false can miss whatever had not been
         * drained yet. onStreamFinished only fires once stdout is closed and
         * complete, which is the same reason the rest of the shell's one-shot
         * processes use it.
         */
        stdout: StdioCollector {
            onStreamFinished: {
                const next = {};

                const lines = text.split("\n");
                for (let i = 0; i < lines.length; i++) {
                    const line = lines[i];
                    const at = line.indexOf("\t");
                    if (at <= 0) continue;

                    const id = line.substring(0, at).trim();
                    const path = line.substring(at + 1).trim();
                    if (id === "" || path === "") continue;

                    next[id] = "file://" + path;
                }

                // Replaced wholesale rather than mutated, so the change is
                // visible to bindings - assigning into a var object in place
                // emits nothing and the dock would keep its fallback.
                root.icons = next;
                root.scanned = true;
                root.scanning = false;
            }
        }

        // A scan that fails outright - no bash, script missing - must still
        // clear the flag, or nothing would ever try again.
        onExited: (code, status) => {
            if (root.scanning) root.scanning = false;
        }
    }
}
