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

    // Re-read periodically so external changes (function keys) are reflected.
    Timer {
        running: root.available && root.writable
        interval: 4000
        repeat: true
        onTriggered: probe.running = true
    }
}
