import QtQuick
import Quickshell.Services.Mpris
import qs.Config
import qs.Common
import qs.Modules.Media

/*
 * Now playing, in the quick settings panel.
 *
 * Mounts the same MediaBody as the desktop widget rather than reimplementing
 * it. Before this, the panel had no artwork and no scrub bar and the widget had
 * no button frames, so the two were recognisably different players for the same
 * track.
 *
 * Pinned to landscape: the panel is a fixed-width column and this section only
 * ever gets a strip of it, which is the shape landscape is for. Letting it
 * resolve automatically would flip it to portrait on the aspect ratio and stack
 * a large square of artwork into a panel that has no room for one.
 *
 * Framed, unlike the panel's other sections, and with no heading. The frame is
 * doing the job the "MEDIA" title was doing - marking where this section starts
 * and ends - and it does it without printing a word above artwork and a track
 * name that already say what this is. It carries the bottom-right notch every
 * other framed surface in the shell carries.
 */
Item {
    id: root

    readonly property MprisPlayer player: {
        const list = Mpris.players.values;
        if (list.length === 0) return null;
        return list.find(p => p.playbackState === MprisPlaybackState.Playing) || list[0];
    }

    // Set by the panel from the section's configured colour, the same as every
    // other section. Without it the media row would be the one section the
    // quick settings colour options had no effect on.
    property string accentRole: "warn"

    readonly property color accentColor: Theme.c(accentRole)

    property real padding: Theme.space3

    /*
     * Tall enough for the body to draw everything.
     *
     * MediaBody drops its artwork below 120px and its scrub row with it, and
     * those tests run against the body's own size - which is this height less
     * the padding on both sides. At 132 the body got 108 and quietly rendered
     * as a title and three buttons, which is the layout this change existed to
     * replace. 150 leaves it 126.
     *
     * Fixed rather than derived: the body fills whatever it is given and has no
     * implicit height of its own to ask for.
     */
    implicitHeight: 150

    NotchRect {
        anchors.fill: parent
        fillColor: Theme.alpha(Theme.bgRaised, 0.75)
        strokeColor: Theme.alpha(root.accentColor, 0.35)
        notch: Theme.notch
        notchTopLeft: false
        notchTopRight: false
        notchBottomRight: true
        notchBottomLeft: false
    }

    MediaBody {
        anchors.fill: parent
        anchors.margins: root.padding

        player: root.player
        accentColor: root.accentColor
        orientation: "landscape"
    }
}
