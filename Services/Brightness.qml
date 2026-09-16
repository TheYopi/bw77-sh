pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Config

/*
 * Display backlight.
 *
 * brightnessctl is preferred because it handles permissions through udev; the
 * sysfs path is read directly as a fallback so the slider still shows a value
 * on machines without it, even if it cannot be changed.
 */
Singleton {
    id: root

    property bool available: false
    property bool writable: false
    property int current: 0
    property int maximum: 100
    property string device: ""

    readonly property real fraction: maximum > 0 ? current / maximum : 0
    readonly property int percent: Math.round(fraction * 100)

    function setFraction(f) {
        if (!writable) return;
        const target = Math.max(1, Math.min(100, Math.round(f * 100)));

        // Optimistic update: waiting for the next poll makes the slider feel
        // like it is lagging behind the cursor.
        current = Math.round(maximum * target / 100);
        Quickshell.execDetached(["brightnessctl", "-q", "set", `${target}%`]);
    }

    function step(delta) {
        setFraction(fraction + delta);
    }

    // Re-read now rather than at the next poll. The brightness keys change the
    // backlight from outside the shell and then say so over IPC, and an OSD
    // that shows the old level for up to four seconds is showing a wrong one.
    function refresh() {
        probe.running = true;
    }

    /*
     * --- polled only while something is looking
     *
     * The poll exists to catch changes made from outside the shell, and it used
     * to run from startup to shutdown: a shell plus a brightnessctl forked
     * every four seconds, twenty-odd thousand processes a day, for a number
     * that is drawn by exactly two surfaces - the brightness slider and the
     * OSD - neither of which is on screen for more than a few seconds at a
     * time.
     *
     * So it is reference counted like SysMon and Locks. The slider takes a
     * holder while it is built and gives it back when it is destroyed, which
     * covers the case the poll was really for: the function keys being pressed
     * while the panel is open, with the slider expected to follow.
     *
     * The OSD needs no holder. The keys reach the shell over IPC and that path
     * calls refresh() before raising the OSD, so the level it shows is read
     * fresh at the moment it appears rather than up to four seconds stale -
     * which is better than anything the poll was providing.
     */
    property int watchers: 0

    // Read once on the way in as well as on the timer: with no poll running
    // while nothing was watching, the value in hand is as old as the last
    // holder, and a slider that opens showing a level the backlight left
    // behind ten minutes ago is worse than one that opens a frame late.
    function acquire() {
        watchers = watchers + 1;
        if (watchers === 1) refresh();
    }

    function release() { watchers = Math.max(0, watchers - 1); }

    Process {
        id: probe
        running: true
        command: ["sh", "-c",
            `if command -v brightnessctl >/dev/null 2>&1; then ` +
            `  echo "ctl $(brightnessctl -m 2>/dev/null | head -1)"; ` +
            `else ` +
            `  for d in /sys/class/backlight/*; do ` +
            `    [ -r "$d/brightness" ] || continue; ` +
            `    echo "sys $(basename "$d") $(cat "$d/brightness") $(cat "$d/max_brightness")"; ` +
            `    break; ` +
            `  done; ` +
            `fi`]

        stdout: StdioCollector {
            onStreamFinished: {
                const line = text.trim();
                if (line === "") { root.available = false; return; }

                if (line.startsWith("ctl ")) {
                    // brightnessctl -m: device,class,current,percent,max
                    const parts = line.substring(4).split(",");
                    if (parts.length >= 5) {
                        root.device = parts[0];
                        root.current = parseInt(parts[2]);
                        root.maximum = parseInt(parts[4]);
                        root.available = root.maximum > 0;
                        root.writable = true;
                    }
                } else if (line.startsWith("sys ")) {
                    const parts = line.substring(4).split(" ");
                    if (parts.length >= 3) {
                        root.device = parts[0];
                        root.current = parseInt(parts[1]);
                        root.maximum = parseInt(parts[2]);
                        root.available = root.maximum > 0;
                        root.writable = false;   // no brightnessctl to write with
                    }
                }
            }
        }
    }

    // Re-read periodically so external changes (function keys) are reflected
    // for as long as anything is displaying them.
    Timer {
        running: root.watchers > 0 && root.available && root.writable
        interval: 4000
        repeat: true
        onTriggered: probe.running = true
    }
}
