import QtQuick
import qs.Config

/*
 * A label that scrolls itself when it does not fit.
 *
 * Stream names are the reason this exists. "Brave" and "Spotify" fit the column
 * in the audio popup with room to spare, but the same field carries things like
 * "Firefox - YouTube - Some Video Title" and a browser tab title can run to a
 * paragraph. Eliding those loses the end, which for a stream label is usually
 * the part that identifies it - every Chromium stream elides to "Chromium".
 *
 * It only moves when it has to: text that fits is drawn normally and never
 * animates, so a panel of short names is completely still. Overflowing text
 * runs from one end to the other and back, pausing at each end long enough to
 * read, rather than looping continuously - a label that never stops moving is
 * hard to read and harder to ignore in peripheral vision.
 *
 * Under reduced motion it does not scroll at all and elides instead, because
 * the whole point of that setting is that things hold still.
 */
Item {
    id: root

    property string text: ""
    property string role: "micro"
    property bool caps: false
    property color color: Theme.text
    property real sizeOverride: 0

    // How long the text rests at each end before travelling back.
    property int dwell: 1400

    // Travel speed in pixels per second. Slow enough to read while it moves.
    property real speed: 30

    implicitHeight: label.implicitHeight
    implicitWidth: label.implicitWidth

    clip: true

    readonly property real overflow: Math.max(0, label.implicitWidth - width)
    readonly property bool scrolling: overflow > 0 && !Theme.reducedMotion

    CyberText {
        id: label

        y: 0
        width: root.scrolling ? implicitWidth : root.width
        height: root.height

        text: root.text
        role: root.role
        caps: root.caps
        color: root.color
        sizeOverride: root.sizeOverride

        // Only elide when it is not going to travel - eliding a scrolling label
        // would put an ellipsis in the middle of the thing being scrolled to.
        elide: root.scrolling ? Text.ElideNone : Text.ElideRight
    }

    /*
     * Restarted whenever the text or the space it has changes, because both
     * change how far there is to travel - and an animation left running with a
     * stale `to` either stops short or walks the label off the edge.
     */
    SequentialAnimation {
        id: sweep

        running: root.scrolling
        loops: Animation.Infinite

        PauseAnimation { duration: root.dwell }

        NumberAnimation {
            target: label
            property: "x"
            from: 0
            to: -root.overflow
            duration: Math.max(1, (root.overflow / Math.max(1, root.speed)) * 1000)
            easing.type: Easing.InOutSine
        }

        PauseAnimation { duration: root.dwell }

        NumberAnimation {
            target: label
            property: "x"
            from: -root.overflow
            to: 0
            duration: Math.max(1, (root.overflow / Math.max(1, root.speed)) * 1000)
            easing.type: Easing.InOutSine
        }
    }

    // Parked at the start whenever it is not travelling, so a label that has
    // just become short enough to fit does not stay pushed off to the left.
    onScrollingChanged: if (!scrolling) label.x = 0
    onTextChanged: label.x = 0
    onWidthChanged: label.x = 0
}
