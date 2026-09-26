pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

/*
 * Which player the shell is talking about when it says "now playing".
 *
 * Four surfaces need that answer - the media keys in the OSD, the desktop
 * widget, the quick settings section and the bar widget - and until this
 * existed the first three each carried their own copy of the same three lines.
 * Three copies is a coincidence; four is a decision, and the decision is worth
 * making once where it can be read.
 *
 * The rule is: whatever is actually playing, else whatever registered first.
 * That second half matters more than it looks. A paused player is still the
 * one you were listening to, so the transport keeps working on it rather than
 * the widget going blank the moment you hit pause - which is the exact moment
 * you are most likely to reach for it again.
 */
Singleton {
    id: root

    readonly property MprisPlayer active: {
        const list = Mpris.players.values;
        if (list.length === 0) return null;
        return list.find(p => p.playbackState === MprisPlaybackState.Playing)
            || list[0];
    }

    readonly property bool hasPlayer: root.active !== null

    readonly property bool playing: root.active !== null
        && root.active.playbackState === MprisPlaybackState.Playing

    /*
     * --- is this a stream, rather than a track
     *
     * Written out as a binding over `active` rather than as a function taking
     * a player, which is what it was first tried as. In that form every
     * surface that mounts MediaBody began calling every track live: the test
     * was copied across unchanged, so what failed was the evaluation, not the
     * logic. The difference that matters is that a binding reads the
     * properties it depends on in its own expression, from a typed property,
     * and this one does.
     *
     * MediaBody keeps its own copy for the player it is handed. Two copies of
     * nine lines, deliberately, after one copy turned out to cost the scrub
     * bar on every surface at once.
     *
     * Testing `lengthSupported && length > 0` is not enough on its own: the
     * players that break it are the ones that report a length anyway - a
     * browser tab on a live stream hands over a duration in the tens of
     * thousands of seconds - which passes that test and produces a countdown
     * of minus twenty-five hours. Hence the ceiling, and the check on
     * position, which catches a player whose position has run past the length
     * it claimed.
     */
    readonly property real maxTrackSeconds: 12 * 60 * 60

    readonly property bool hasTimeline: {
        if (!root.active) return false;
        if (!root.active.lengthSupported) return false;

        const len = root.active.length;
        if (len === undefined || isNaN(len) || !isFinite(len)) return false;
        if (len <= 0) return false;
        if (len > root.maxTrackSeconds) return false;

        const pos = root.active.position;
        if (pos !== undefined && isFinite(pos) && pos > len * 1.5) return false;

        return true;
    }

    /*
     * A player holding a track with no timeline is a stream.
     *
     * The title check matters: a player sitting idle with nothing loaded also
     * has no timeline, and calling that live would badge silence.
     */
    readonly property bool liveStream: root.active !== null
        && !root.hasTimeline
        && (root.active.trackTitle || "") !== ""

    /*
     * "Artist - Title", or just the title when the player reports no artist.
     *
     * Built here rather than in the bar widget because the separator is a
     * presentation decision that should not differ between two surfaces
     * showing the same track, and because the empty-artist case is the common
     * one for browser tabs and podcasts - joining unconditionally would give
     * every one of those a leading " - ".
     */
    function trackLabel(separator) {
        if (!root.active) return "";

        const title = root.active.trackTitle || "";
        const artist = root.active.trackArtist || "";

        if (title === "" && artist === "") return "";
        if (artist === "") return title;
        if (title === "") return artist;

        return artist + (separator === undefined ? " - " : separator) + title;
    }
}
