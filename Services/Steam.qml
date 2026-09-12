pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/*
 * Icons and names for running Steam games.
 *
 * A Steam game reports its app id as "steam_app_<number>" and ships no desktop
 * entry, so the normal resolve-then-icon-theme path in Apps finds nothing for
 * either question. The dock drew the generic executable box and captioned it
 * "STEAM_APP_1091500". The number in that app id is enough to answer both:
 * Steam keeps the artwork and the install manifest on disk keyed by it.
 *
 * For the icon, two places are tried in this order:
 *
 *   1. The icon theme, as "steam_icon_<number>". Steam installs these for games
 *      you have made a shortcut for, and going through the theme means proper
 *      size selection. Handled in Apps.iconFor, not here - it needs no scan.
 *
 *   2. Steam's own artwork cache, via Scripts/steam-apps.sh. This is the
 *      fallback for the majority of games, which have no shortcut.
 *
 * The name has only one source, the same script - it reads it out of the
 * game's appmanifest. There is no theme equivalent to try first.
 *
 * The scan is lazy and cached, and one pass answers both questions, so asking
 * for a name costs nothing once an icon has been asked for and vice versa.
 * Nothing runs until something actually asks about a steam_app_ id, which on a
 * machine with no games is never.
 */
Singleton {
    id: root

    // appid (string) -> absolute file path
    property var icons: ({})

    // appid (string) -> display name, e.g. "Cyberpunk 2077"
    property var names: ({})

    property bool scanning: false
    property bool scanned: false

    // Guards against rescanning on every frame when a game genuinely has no
    // artwork at all. Without it, a miss would start a scan, the scan would
    // finish still missing, and the next binding evaluation would ask again.
    property var missed: ({})

    /*
     * Files can appear after a scan - a game installed, or artwork downloaded
     * lazily on first launch - so a miss is allowed to retry, just not often.
     *
     * The retry has to be driven from here rather than from the next lookup.
     * `iconFor` is only ever called when something re-evaluates the binding
     * that reads it, and the only thing that invalidates that binding is
     * `icons` being replaced - which is to say, a scan finishing. So once the
     * last scan had run, a game whose artwork had not been written yet was
     * never asked about again, and it kept the fallback icon for the rest of
     * the session. That is the first launch of a freshly installed game, which
     * is exactly the case the retry existed for.
     *
     * Bounded, because the other end of this is a game that genuinely has no
     * artwork at all - a non-Steam shortcut, say - and that must not turn into
     * a rescan every thirty seconds forever. A few attempts covers Steam
     * getting round to writing the file; after that the answer is taken as
     * final until some app id nobody has asked about before comes along, which
     * is a real change in the question and resets the count.
     */
    readonly property int retryMs: 30000
    readonly property int maxRetries: 3
    property int retries: 0
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
     * the map alone, which is the only thing that changes the answer.
     */
    function iconFor(appid) {
        const key = String(appid);
        if (!key) return "";

        const hit = root.icons[key];
        if (hit) return hit;

        Qt.callLater(root.noteMiss, key);
        return "";
    }

    // The game's own name, or "" if it is not known yet. Same contract as
    // iconFor: empty on the first ask, filled in when the scan lands.
    function nameFor(appid) {
        const key = String(appid);
        if (!key) return "";

        const hit = root.names[key];
        if (hit) return hit;

        Qt.callLater(root.noteMiss, key);
        return "";
    }

    function noteMiss(key) {
        const now = Date.now();

        // Already known to be missing, and it is too soon to look again.
        if (root.missed[key] && (now - root.lastScan) <= root.retryMs) return;

        // An id nobody has missed before is a new question, not a repeat of the
        // one that has already been given up on.
        if (!root.missed[key]) root.retries = 0;

        const next = Object.assign({}, root.missed);
        next[key] = true;
        root.missed = next;

        root.scan();
    }

    // True while some id that has been asked for is still missing either
    // answer. A running game ends up with both, so anything short of that is
    // worth one more look.
    function hasOutstanding() {
        for (const key in root.missed) {
            if (!root.icons[key] || !root.names[key]) return true;
        }
        return false;
    }

    Timer {
        id: retryTimer
        interval: root.retryMs
        onTriggered: {
            if (!root.hasOutstanding()) return;
            root.retries = root.retries + 1;
            root.scan();
        }
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
        command: ["bash", `${Quickshell.shellDir}/Scripts/steam-apps.sh`]

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
                const nextIcons = {};
                const nextNames = {};

                /*
                 * Three tab-separated fields: id, icon path, name. The last two
                 * are independently optional - a game uninstalled but still in
                 * the artwork cache has no name, one installed before Steam has
                 * fetched its images has no icon - so each is tested on its own
                 * rather than the record being dropped when either is blank.
                 *
                 * Split with a limit rather than on every tab: a name is free
                 * text from a store page and the shell should not be the thing
                 * that decides what happens when one contains a separator. The
                 * script strips tabs on the way out; this is the second half of
                 * that guarantee.
                 */
                const lines = text.split("\n");
                for (let i = 0; i < lines.length; i++) {
                    const line = lines[i];
                    if (line === "") continue;

                    const first = line.indexOf("\t");
                    if (first <= 0) continue;

                    const id = line.substring(0, first).trim();
                    if (id === "") continue;

                    const rest = line.substring(first + 1);
                    const second = rest.indexOf("\t");

                    const path = (second < 0 ? rest : rest.substring(0, second)).trim();
                    const name = second < 0 ? "" : rest.substring(second + 1).trim();

                    if (path !== "") nextIcons[id] = "file://" + path;
                    if (name !== "") nextNames[id] = name;
                }

                // Replaced wholesale rather than mutated, so the change is
                // visible to bindings - assigning into a var object in place
                // emits nothing and the dock would keep its fallback.
                root.icons = nextIcons;
                root.names = nextNames;
                root.scanned = true;
                root.scanning = false;

                // Anything still unaccounted for gets another look shortly, up
                // to the cap. See the note on retryMs.
                if (root.retries < root.maxRetries && root.hasOutstanding())
                    retryTimer.restart();
            }
        }

        // A scan that fails outright - no bash, script missing - must still
        // clear the flag, or nothing would ever try again.
        onExited: (code, status) => {
            if (root.scanning) root.scanning = false;
        }
    }
}
