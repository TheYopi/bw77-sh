import QtQuick
import Quickshell.Services.Mpris
import qs.Config
import qs.Modules.Desktop
import qs.Modules.Media

/*
 * Now playing.
 *
 * The contents live in MediaBody, which the quick settings panel mounts too -
 * the two were separate implementations of the same player and had drifted into
 * different shapes, so the same track looked like two different widgets
 * depending on where you saw it.
 *
 * All this adds is the frame, the player selection and the size floor. The
 * layout, including the portrait/landscape switch, is the body's business and
 * follows the shape this widget is dragged to.
 */
WidgetFrame {
    id: root
    accentColor: Theme.warn
    padding: Theme.space3

    property var config: ({})

    readonly property MprisPlayer player: {
        const list = Mpris.players.values;
        if (list.length === 0) return null;
        // Prefer whatever is actually playing over the first registered player.
        return list.find(p => p.playbackState === MprisPlaybackState.Playing) || list[0];
    }

    MediaBody {
        anchors.fill: parent

        player: root.player
        accentColor: root.accentColor

        // Resolved from the widget's own shape, against the same ratio the
        // resize readout shows.
        orientation: "auto"
        aspect: WidgetMetrics.of("media").aspect
    }
}
