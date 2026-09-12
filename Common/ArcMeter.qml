import QtQuick
import qs.Config

/*
 * Circular meter drawn as discrete ticks around an arc, so it belongs to the
 * same family as SegmentBar rather than looking like a generic progress ring.
 */
Item {
    id: root

    property real value: 0            // 0..1

    /*
     * Eased, so the ring sweeps to a new reading instead of snapping to it.
     *
     * Everything below draws from `shown`, not from `value`. With samples
     * arriving ten a second an un-eased ring flickers - several ticks light and
     * clear on the same frame and the eye reads it as noise rather than as
     * movement. A short ease is longer than the gap between samples, so the
     * ring is always travelling and it reads like an instrument.
     */
    property real shown: value
    Behavior on shown {
        enabled: !Theme.reducedMotion && root.smooth_
        NumberAnimation { duration: root.smoothing; easing.type: Easing.OutCubic }
    }

    property bool smooth_: true
    property int smoothing: 260

    /*
     * Geometry, for gauges that are not a full circle.
     *
     * `centreY` moves the pivot within the item, and `radius` overrides the
     * size derived from the box - together they let a 180-degree arc sit in a
     * short wide cell with its opening used for the reading, instead of a
     * semicircle floating in a square with the bottom half empty.
     */
    property real centreY: 0.5
    property real radius: 0

    // 20 ticks means one tick per 5%, which is the step volume actually moves
    // in - so every keypress lights or clears exactly one.
    property int segments: 20
    property real startAngle: 135     // degrees, 0 = 3 o'clock, clockwise
    property real sweepAngle: 270
    property color fillColor: Theme.accent
    property color emptyColor: Theme.alpha(Theme.border, 0.6)
    property real thickness: 8
    property real tickWidth: 5

    implicitWidth: 140
    implicitHeight: 140

    /*
     * What the canvas actually draws is a tick count, not a fraction.
     *
     * `shown` is eased, so it changes on every frame of the sweep - and
     * repainting on it meant a full software repaint of the ring, plus a
     * texture upload, at the display's refresh rate for as long as the ease
     * ran. With samples arriving ten a second the ease never finishes, so four
     * gauges in the Control Center repainted forever.
     *
     * The picture is identical for every value inside one tick's band, so the
     * only change worth a repaint is the lit count crossing a boundary. A
     * 32-segment gauge sweeping its whole range now paints 32 times instead of
     * once per frame, and looks exactly the same doing it.
     */
    readonly property int lit: Math.round(shown * segments)
    onLitChanged: canvas.requestPaint()

    onFillColorChanged: canvas.requestPaint()
    onEmptyColorChanged: canvas.requestPaint()
    onSegmentsChanged: canvas.requestPaint()
    onWidthChanged: canvas.requestPaint()
    onHeightChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.clearRect(0, 0, width, height);

            const cx = width / 2;
            const cy = height * root.centreY;
            const outer = root.radius > 0
                ? root.radius
                : Math.min(width, height) / 2 - 2;
            const innerR = outer - root.thickness;
            const lit = root.lit;

            for (let i = 0; i < root.segments; i++) {
                /*
                 * Each tick stands for a band of the range, so it is drawn at
                 * the CENTRE of its band rather than at the leading edge.
                 *
                 * Placing them at i/segments pushed the whole ring backwards by
                 * half a tick: at 50% the last lit tick sat a full band short of
                 * the top and the boundary landed at 48.75%. The error scales
                 * with the tick count, so going from 40 ticks to 20 would have
                 * doubled it to 6.8 degrees. Centring puts the lit/unlit
                 * boundary exactly on the value for any number of segments.
                 */
                const frac = (i + 0.5) / root.segments;
                const deg = root.startAngle + frac * root.sweepAngle;
                const rad = deg * Math.PI / 180;

                ctx.strokeStyle = i < lit ? root.fillColor : root.emptyColor;
                ctx.lineWidth = root.tickWidth;
                ctx.beginPath();
                ctx.moveTo(cx + Math.cos(rad) * innerR, cy + Math.sin(rad) * innerR);
                ctx.lineTo(cx + Math.cos(rad) * outer, cy + Math.sin(rad) * outer);
                ctx.stroke();
            }
        }
    }
}
