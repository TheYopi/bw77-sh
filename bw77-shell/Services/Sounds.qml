pragma Singleton

import QtQuick
import Quickshell
import qs.Config

/*
 * Sound playback for notifications, and anywhere else the shell needs a cue.
 *
 * Lives in a service rather than inside the notification layer so the settings
 * pane can preview a sound with the exact same code path that plays it for
 * real - a preview that takes a different route is not a preview.
 */
Singleton {
    id: root

    /*
     * Every player spells volume differently, and passing the wrong flag makes
     * the command fail silently rather than just play at the wrong level. The
     * scale is matched to the command; anything unrecognised is played at its
     * own default rather than risking an argument it will reject.
     */
    function volumeArgs(command, level) {
        const name = String(command).split("/").pop();

        if (name === "pw-play" || name === "pw-cat")
            return ["--volume=" + level.toFixed(3)];          // 0..1

        if (name === "paplay")
            return ["--volume=" + Math.round(level * 65536)]; // 0..65536

        if (name === "ffplay")
            return ["-volume", String(Math.round(level * 100))];

        if (name === "mpv")
            return ["--volume=" + Math.round(level * 100)];

        if (name === "play" || name === "sox")
            return ["-v", level.toFixed(3)];                  // gain factor

        return [];
    }


    function supportsVolume(command) {
        return volumeArgs(command, 0.5).length > 0;
    }

    function play(file, level, command) {
        if (!file || file === "") return;

        const cmd = (command && command !== "")
            ? command : Settings.notifications.soundCommand;
        const vol = Math.max(0, Math.min(1,
            level === undefined ? Settings.notifications.soundVolume : level));
        if (vol <= 0) return;

        Quickshell.execDetached([cmd].concat(volumeArgs(cmd, vol)).concat([file]));
    }

    function playNotification(critical) {
        if (!Settings.notifications.sound) return;
        const file = critical
            ? Settings.notifications.soundFileCritical
            : Settings.notifications.soundFileNormal;
        play(file);
    }
}
