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
    property int weightOverride: 0

    // How long the text rests at each end before travelling back.
    property int dwell: 1400

    /*
     * The pause at the START of the run, separately from the one at the far
     * end.
     *
     * The two ends are not equivalent. Arriving back at the first character is
     * arriving back at the thing the label is for - the artist, the sender,
     * the stream name - and that is the moment worth holding still, long
     * enough that someone glancing at the bar reads it without waiting for a
     * cycle. The pause at the far end only has to be long enough to finish the
     * last word before the label travels back.
     *
     * Defaults to `dwell`, so nothing that does not set it changes.
     */
    property int startDwell: root.dwell

    // Travel speed in pixels per second. Slow enough to read while it moves.
    property real speed: 30

    implicitHeight: label.implicitHeight
    // Measured, not asked of the label, for the same reason `overflow` is -
    // an eliding Text understates what it wants.
    implicitWidth: Math.ceil(natural.advanceWidth)

    clip: true

    /*
     * --- the natural width is measured separately, and that is the whole fix
     *
     * This used to read `label.implicitWidth`, and it latched: a Text with
     * `elide` set reports its implicit width against the width it has been
     * given rather than the width the string wants, so the moment the label
     * was eliding it claimed to fit. Overflow computed to zero, `scrolling`
     * stayed false, elide stayed on, and the measurement went on confirming
     * itself. The label sat still with an ellipsis on the end - exactly the
     * state it was supposed to detect and escape.
     *
     * Measuring with TextMetrics breaks the circle, because it has no width to
     * be constrained by. It carries the label's own font, so what is measured
     * is what is drawn.
     */
    TextMetrics {
        id: natural
        font: label.font
        text: root.text
    }

    readonly property real overflow: Math.max(0, natural.advanceWidth - width)
    readonly property bool scrolling: overflow > 0 && !Theme.reducedMotion

    CyberText {
        id: label

        y: 0
        // Wide enough for the whole string while travelling, so nothing is cut
        // off the end of a label that is being scrolled to reveal that end.
        width: root.scrolling ? Math.ceil(natural.advanceWidth) + 2 : root.width
        height: root.height

        text: root.text
        role: root.role
        caps: root.caps
        color: root.color
        sizeOverride: root.sizeOverride
        weightOverride: root.weightOverride

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

        PauseAnimation { duration: root.startDwell }

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
