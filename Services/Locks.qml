pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/*
 * Caps Lock, Num Lock and Scroll Lock state.
 *
 * Read from the keyboard LED nodes under /sys/class/leds, because there is
 * nowhere better to get it: Wayland gives a client no access to modifier state
 * it did not receive a key event for, and neither niri nor Hyprland reports
 * lock state over IPC. The LEDs are the only thing that is true regardless of
 * which window has focus.
 *
 * There is no change notification on those nodes - inotify does not fire on
 * them - so something has to look repeatedly. That used to be a Timer here
 * firing a shell per tick, which made each tick expensive enough that the idle
 * rate had to be 300ms, with a faster burst after any change to try to make up
 * for it. The result was that the FIRST press of a lock key was the slow one:
 * nothing was bursting yet, so it could take a third of a second to appear
 * while volume - which is event-driven - was instant. Tapping quickly made it
 * worse, because two edges inside one interval look like no change at all.
 *
 * Scripts/locks.sh replaces all of that with one long-running watcher whose
 * loop does no forking, so it can tick at 50ms for less cost than the old
 * 300ms poll, and it prints only when something actually changes. The burst and
 * attentive machinery is gone with it: there is one rate, and it is fast.
 *
 * Still reference counted - with no holders the watcher is not running at all.
 */
Singleton {
    id: root

    property bool caps: false
    property bool num: false
    property bool scroll: false

    // False when the LED nodes cannot be read at all - a machine with no
    // keyboard LEDs, or a kernel that does not export them. The Control Center
    // says so rather than offering a toggle that silently does nothing.
    property bool available: false
    property bool probed: false

    property int holders: 0

    function acquire() { holders++; }
    function release() { holders = Math.max(0, holders - 1); }

    readonly property bool polling: holders > 0

    // One rate, fast enough that a deliberate tap cannot fall between two
    // ticks. See the note in the script about why this is affordable.
    property real intervalSec: 0.05

    Process {
        id: watcher

        running: root.polling
        command: ["bash", `${Quickshell.shellDir}/Scripts/locks.sh`,
                  String(root.intervalSec)]

        /*
         * Three characters, one per lock, or "none" when the machine has no
         * lock LEDs. The watcher prints only on change, so every line that
         * arrives here is real news - there is nothing to diff on this side.
         */
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                const out = line.trim();
                if (out === "") return;

                root.probed = true;

                if (out === "none" || out.length < 3) {
                    root.available = false;
                    return;
                }

                root.available = true;
                root.caps = out.charAt(0) === "1";
                root.num = out.charAt(1) === "1";
                root.scroll = out.charAt(2) === "1";
            }
        }
    }
}
