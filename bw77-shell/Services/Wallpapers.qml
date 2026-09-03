pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Config

/*
 * Indexes the wallpaper folder and owns the current selection.
 *
 * Setting a wallpaper only updates state - drawing is done by the wallpaper
 * layer window, so transitions stay inside the shell instead of shelling out to
 * swww and losing control of the animation.
 */
Singleton {
    id: root

    property var files: []
    property bool scanning: false
    readonly property string current: Settings.wallpaper.current

    function scan() {
        scanning = true;
        scanner.exec(["sh", "-c",
            `find "${Settings.wallpaper.folder}" -maxdepth 3 -type f ` +
            `\\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' ` +
            `-o -iname '*.bmp' \\) | sort`]);
    }

    function set(path, screenName) {
        if (Settings.wallpaper.perMonitor && screenName) {
            const map = Object.assign({}, Settings.wallpaper.monitorMap);
            map[screenName] = path;
            Settings.wallpaper.monitorMap = map;
        } else {
            Settings.wallpaper.current = path;
        }

        if (Settings.wallpaper.setCommand !== "") {
            Quickshell.execDetached(["sh", "-c",
                Settings.wallpaper.setCommand.replace("{path}", `'${path}'`)]);
        }
    }

    function forScreen(screenName) {
        if (Settings.wallpaper.perMonitor) {
            const m = Settings.wallpaper.monitorMap;
            if (m && m[screenName]) return m[screenName];
        }
        return Settings.wallpaper.current;
    }

    function random() {
        if (files.length === 0) return;
        set(files[Math.floor(Math.random() * files.length)]);
    }

    Process {
        id: scanner
        stdout: StdioCollector {
            onStreamFinished: {
                root.files = text.trim() === "" ? [] : text.trim().split("\n");
                root.scanning = false;
                if (root.files.length && Settings.wallpaper.current === "")
                    Settings.wallpaper.current = root.files[0];
            }
        }
    }

    Timer {
        running: Settings.wallpaper.randomize
        interval: Math.max(30, Settings.wallpaper.randomIntervalSec) * 1000
        repeat: true
        onTriggered: root.random()
    }

    Connections {
        target: Settings.wallpaper
        function onFolderChanged() { root.scan(); }
    }

    Component.onCompleted: scan()
}
