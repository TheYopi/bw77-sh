import QtQuick
import Quickshell.Services.Mpris
import qs.Config
import qs.Common

/*
 * The media player's contents, shared by the desktop widget and the quick
 * settings panel.
 *
 * The two used to be separate implementations of the same thing and had drifted
 * into different shapes - the panel drew framed transport buttons and no
 * artwork, the widget drew unframed glyphs and a scrub row - so the same track
 * looked like two different players depending on where you saw it. This is one
 * body with two layouts, and both surfaces mount it.
 *
 * --- the two layouts
 *
 * `landscape` puts the artwork on the left with the title and artist beside it,
 * then the scrub row and the transport across the full width. It is the shape
 * for anything appreciably wider than it is tall, which includes the quick
 * settings panel at any height.
 *
 * `portrait` centres the artwork with room around it and stacks the title,
 * artist, scrub and transport underneath. This is the layout the widget had
 * been missing: dragged tall, the old one kept its small left-aligned tile and
 * its two lines of text at the top and simply grew a hole in the middle, since
 * the scrub and transport are anchored to the bottom and nothing claimed the
 * space between. Artwork is the only element here that can usefully absorb it,
 * so in portrait it takes whatever is left after the fixed rows.
 *
 * `orientation` is "auto" by default and resolves against the aspect ratio, so
 * a widget changes layout as it is resized. A surface that knows its shape can
 * pin it - quick settings does.
 */
Item {
    id: root

    property MprisPlayer player: null
    property color accentColor: Theme.warn

    // "auto" | "portrait" | "landscape"
    property string orientation: "auto"

    // The ratio at which auto flips. Matches the media entry in WidgetMetrics,
    // so the layout the resize readout promises is the layout that appears.
    property real aspect: 1.8

    readonly property bool wide: {
        if (root.orientation === "landscape") return true;
        if (root.orientation === "portrait") return false;
        if (height <= 0) return false;
        return (width / height) >= root.aspect;
    }

    readonly property bool playing:
        player && player.playbackState === MprisPlaybackState.Playing

    readonly property bool live: player !== null

    /*
     * --- is there a timeline at all
     *
     * Carried over from the widget, and still needed. Testing
     * `lengthSupported && length > 0` is not enough: the players that break it
     * are the ones that report a length anyway - a browser tab on a live stream
     * hands over a duration in the tens of thousands of seconds - which passes
     * the test and produces a countdown of minus twenty-five hours.
     */
    readonly property real maxTrackSeconds: 12 * 60 * 60

    readonly property bool hasTimeline: {
        if (!player) return false;
        if (!player.lengthSupported) return false;

        const len = player.length;
        if (len === undefined || isNaN(len) || !isFinite(len)) return false;
        if (len <= 0) return false;
        if (len > root.maxTrackSeconds) return false;

        const pos = player.position;
        if (pos !== undefined && isFinite(pos) && pos > len * 1.5) return false;

        return true;
    }

    readonly property bool seekable: hasTimeline

    /*
     * Elapsed time, held rather than bound.
     *
     * `player.position` is a cached value on the D-Bus side and nothing pushes
     * an update as it advances, so a binding to it resolves once and then sits
     * still. Re-reading it on a timer into a real property is what makes it
     * tick.
     */
    property real elapsed: 0

    readonly property real total: seekable ? player.length : 0

    function refreshPosition() {
        root.elapsed = root.player ? root.player.position : 0;
    }

    onPlayerChanged: refreshPosition()

    function clock(seconds) {
        if (seconds === undefined || isNaN(seconds) || !isFinite(seconds) || seconds < 0)
            return "0:00";

        const whole = Math.floor(seconds);
        const h = Math.floor(whole / 3600);
        const m = Math.floor((whole % 3600) / 60);
        const s = whole % 60;

        if (h > 0) return h + ":" + (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    Timer {
        running: root.playing && root.visible
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshPosition()
    }

    Connections {
        target: root.player
        ignoreUnknownSignals: true
        function onTrackTitleChanged() { root.refreshPosition(); }
        function onPlaybackStateChanged() { root.refreshPosition(); }
    }

    readonly property string titleText: root.player
        ? (root.player.trackTitle || Settings.t("Unknown track"))
        : Settings.t("Nothing playing")

    readonly property string artistText:
        root.player ? (root.player.trackArtist || "") : ""

    /*
     * --- what gets dropped as the widget shrinks
     *
     * Artwork first in landscape: it is the one part carrying no information
     * the two lines beside it do not. Then the scrub row, then the artist. The
     * title and the transport are never dropped - a media widget that cannot
     * say what is playing or stop it has nothing left to be.
     *
     * Portrait is the other way round, and the test is the leftover space
     * itself rather than a height threshold. Gating it on overall height was
     * how the hole in the middle came back: a widget at, say, 300x200 is
     * portrait but under any sensible height cutoff, so the artwork was
     * suppressed and nothing else claimed the space it would have filled. Since
     * the artwork is what absorbs the slack, it is shown whenever there is
     * slack to absorb - anything down to a thumbnail beats a gap.
     */
    readonly property bool showArt: root.wide
        ? (width >= 240 && height >= 120)
        : (width >= 24 && artRegion >= 24)

    readonly property bool showScrub: height >= 120
    readonly property bool showArtist: height >= 96

    // ------------------------------------------------------------- transport

    Row {
        id: transport
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        spacing: Theme.space2

        /*
         * Framed, like the panel's have always been.
         *
         * The widget drew bare glyphs, which on a wallpaper gave the only
         * clickable things in the widget no hit target you could see - the
         * frame is what says these are buttons rather than status icons.
         */
        CyberButton {
            width: 44
            iconText: "\uf04a"
            enabled: root.player !== null && root.player.canGoPrevious
            onClicked: root.player.previous()
        }

        CyberButton {
            width: 54
            iconText: root.playing ? "\uf04c" : "\uf04b"
            active: root.playing
            enabled: root.player !== null && root.player.canTogglePlaying
            onClicked: root.player.togglePlaying()
        }

        CyberButton {
            width: 44
            iconText: "\uf04e"
            enabled: root.player !== null && root.player.canGoNext
            onClicked: root.player.next()
        }
    }

    // ------------------------------------------------------------ scrub row

    Item {
        id: scrub
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: transport.top
        anchors.bottomMargin: Theme.space2
        height: root.showScrub ? 14 : 0
        visible: root.showScrub

        CyberText {
            id: elapsedText
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            // Fixed width so the bar does not jump sideways as the clock
            // crosses from 9:59 to 10:00.
            width: 34
            text: root.seekable ? root.clock(root.elapsed) : ""
            role: "micro"
            color: Theme.textDim
        }

        CyberText {
            id: remainingText
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 40
            horizontalAlignment: Text.AlignRight
            // Counting down. Total duration is a fact about the track; time
            // left is a fact about now.
            text: root.seekable
                ? "-" + root.clock(Math.max(0, root.total - root.elapsed))
                : ""
            role: "micro"
            color: Theme.textDim
        }

        CyberText {
            anchors.centerIn: parent
            visible: !root.seekable
            text: root.live ? "[LIVE]" : ""
            role: "micro"
            bold: true
            color: root.accentColor
        }

        SegmentBar {
            anchors.left: elapsedText.right
            anchors.right: remainingText.left
            anchors.leftMargin: Theme.space2
            anchors.rightMargin: Theme.space2
            anchors.verticalCenter: parent.verticalCenter
            height: 6
            visible: root.seekable
            segments: Math.max(10, Math.floor(width / 6))
            warnAtHigh: false
            fillColor: root.accentColor
            emptyColor: Theme.alpha(Theme.border, 0.7)
            value: root.seekable ? Math.min(1, root.elapsed / root.total) : 0

            MouseArea {
                anchors.fill: parent
                // Generous vertically: the bar is six pixels tall and a scrub
                // target that thin is a miss most of the time.
                anchors.topMargin: -6
                anchors.bottomMargin: -6
                enabled: root.seekable && root.player.canSeek
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: (m) => {
                    root.player.position = (m.x / width) * root.total;
                    root.refreshPosition();
                }
            }
        }
    }

    // -------------------------------------------------------------- metadata
    //
    // GlitchText rather than CyberText, so a new track resolves out of noise
    // instead of swapping in place. It decodes on any text change by itself and
    // honours the Decode Animation switch under Effects, so there is nothing to
    // drive from here - the track changing IS the trigger.
    //
    // Positioned by computed height rather than by swapping anchors between the
    // two layouts. Clearing an anchor with `undefined` is fine, but clearing a
    // width or a height that way is not - they are doubles, and undefined does
    // not assign to one. So the sizes are always real numbers and only the
    // numbers change with the layout.

    Item {
        id: meta

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: scrub.visible ? scrub.top : transport.top
        anchors.bottomMargin: Theme.space2

        // Landscape: the metadata shares the top block with the artwork, so it
        // takes everything above the scrub row and centres its lines in it.
        // Portrait: it is just the two lines, sitting directly under the art.
        height: root.wide
            ? Math.max(stack.implicitHeight,
                       (scrub.visible ? scrub.y : transport.y) - Theme.space2)
            : stack.implicitHeight

        // Leaves room for the tile beside it. Short-circuits before reading
        // showArt in portrait, where showArt is derived from the space this
        // item leaves behind and reading it here would be circular.
        anchors.leftMargin: root.wide && root.showArt
            ? root.artSize + Theme.space3 : 0

        Column {
            id: stack
            width: parent.width
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            GlitchText {
                width: parent.width
                textWidth: parent.width
                text: root.titleText
                role: "label"
                bold: true
                color: Theme.text
                horizontalAlignment: root.wide ? Text.AlignLeft : Text.AlignHCenter
            }

            GlitchText {
                width: parent.width
                textWidth: parent.width
                visible: root.showArtist
                text: root.artistText
                role: "micro"
                caps: false
                color: Theme.textDim
                horizontalAlignment: root.wide ? Text.AlignLeft : Text.AlignHCenter
            }
        }
    }

    // -------------------------------------------------------------- artwork

    /*
     * Square in both layouts, sized from different things.
     *
     * Landscape pins it to a small tile beside the text. Portrait hands it
     * everything left between the top edge and the metadata - which is what
     * closes the hole the old layout grew when it was dragged tall - clamped by
     * the width so it stays square, and centred in that space so the padding
     * around it is even.
     */
    readonly property real artRegion: Math.max(0, meta.y - Theme.space3)

    readonly property real artSize: root.wide
        ? Math.min(56, root.height * 0.36)
        : Math.max(0, Math.min(root.width, root.artRegion))

    Rectangle {
        id: art

        visible: root.showArt
        width: root.showArt ? root.artSize : 0
        height: width

        // Placed rather than anchored, for the same reason the metadata is
        // sized rather than re-anchored.
        x: root.wide ? 0 : Math.round((root.width - width) / 2)
        y: root.wide ? 0 : Math.round(Math.max(0, (root.artRegion - height) / 2))

        color: Theme.alpha(Theme.bgDeep, 0.85)

        Image {
            id: cover
            anchors.fill: parent
            source: root.player && root.player.trackArtUrl
                ? root.player.trackArtUrl : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            // Cropped to fill: cover art is square far more often than not, and
            // letterboxing the exceptions wastes more than trimming their edges
            // does. Decoded at the size it is drawn, which in portrait can be
            // most of the widget - a 128px thumbnail blown up to 274 is visibly
            // soft.
            sourceSize.width: Math.max(128, Math.ceil(art.width))
            sourceSize.height: Math.max(128, Math.ceil(art.width))
            visible: status === Image.Ready
        }

        // Shown when the player supplies no art, or the URL will not load - an
        // empty tile looks like a rendering fault.
        CyberText {
            anchors.centerIn: parent
            visible: cover.status !== Image.Ready
            text: "\uf001"
            role: "icon"
            sizeOverride: Math.max(Theme.fontIcon, art.width * 0.3)
            color: Theme.alpha(root.accentColor, 0.6)
        }

        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.color: Theme.alpha(root.accentColor, 0.45)
            border.width: 1
        }
    }
}
