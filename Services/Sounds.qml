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

    /*
     * --- UI feedback
     *
     * Navigation and click cues fire orders of magnitude more often than a
     * notification does, and every one of them is a fork: play() hands the file
     * to a player process. Hovering along a dock or holding an arrow key down a
     * settings pane would otherwise spawn a process per frame.
     *
     * So they are rate limited here rather than at each of the forty-odd call
     * sites. The navigation gap is the wider of the two because that is the one
     * a moving pointer can machine-gun; a click is a deliberate act and its gap
     * only exists to swallow double-fires from a single press.
     *
     * The clock is Date.now() rather than a Timer: a Timer per cue would be
     * state to keep in sync, and this needs no wakeups, only a comparison.
     */
    property real _lastNav: 0
    property real _lastClick: 0

    readonly property int navGapMs: 45
    readonly property int clickGapMs: 25

    function playUi(file, last, gap) {
        if (!Settings.notifications.uiSounds) return false;
        if (!file || file === "") return false;

        const now = Date.now();
        if (now - last < gap) return false;

        play(file, Settings.notifications.uiSoundVolume);
        return true;
    }

    /*
     * Hover or keyboard focus landing on something selectable.
     *
     * Called from the pointer areas of the shell's controls and from the two
     * keyboard registries (CcNav, the Launcher), so moving by arrow key sounds
     * exactly like moving by mouse - which is the point of the cue.
     */
    function playNavigation() {
        if (playUi(Settings.notifications.soundFileNavigation, _lastNav, navGapMs))
            _lastNav = Date.now();
    }

    // Activation: buttons, dock icons, bar widgets, tiles, wallpaper and theme
    // swatches. Anything the user presses to make something happen.
    function playClick() {
        if (playUi(Settings.notifications.soundFileClick, _lastClick, clickGapMs))
            _lastClick = Date.now();
    }

    function playNotification(critical) {
        if (!Settings.notifications.sound) return;
        const file = critical
            ? Settings.notifications.soundFileCritical
            : Settings.notifications.soundFileNormal;
        play(file);
    }
}
