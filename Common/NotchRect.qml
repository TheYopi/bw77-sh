import QtQuick
import QtQuick.Shapes
import qs.Config

/*
 * The single most important shape in the shell.
 *
 * Every surface in the Cyberpunk UI is a rectangle with one or more corners cut
 * at 45 degrees - never a rounded corner, never a plain rectangle. Which corners
 * are cut carries meaning: the game cuts the corner nearest the "flow" of the
 * element, so a left-aligned list item cuts bottom-right, a right-aligned one
 * cuts bottom-left.
 *
 * One cut by default, at the bottom right. Two opposing cuts reads as a
 * parallelogram - a shape with a direction - where one cut reads as a corner
 * that has been clipped, which is the study's rule and the game's. Elements
 * that genuinely want the second cut still ask for it; the notification frame
 * is the main one.
 *
 * Both outlines are drawn as sibling paths inside one Shape. A component cannot
 * instantiate itself in QML, so the inner stroke cannot be another NotchRect -
 * and one Shape with two paths is cheaper than two nested items anyway.
 */
Item {
    id: root

    property color fillColor: Theme.bgBase
    property color strokeColor: Theme.frame
    property real strokeWidth: Theme.borderWidth
    property real notch: Theme.notch

    // Per-corner cut control.
    property bool notchTopLeft: false
    property bool notchTopRight: false
    property bool notchBottomRight: true
    property bool notchBottomLeft: false

    // Optional second stroke offset inward, used on emphasised panels.
    property bool doubleStroke: false
    property color innerStrokeColor: Theme.alpha(strokeColor, 0.35)
    property real innerStrokeInset: 3

    /*
     * ---------------------------------------------------------------- press
     *
     * Bind `pressed` to a MouseArea's and the shape acknowledges the click.
     *
     * It lives here rather than in each control because the shell had no press
     * feedback at all - not on buttons, bar widgets, quick settings tiles, dock
     * icons or selectors. Only a slider handle and one stepper arrow reacted to
     * being pressed. Everything else gave nothing back between the button going
     * down and whatever it opened appearing, which on anything slow to respond
     * is indistinguishable from the click having missed.
     *
     * Material draws this as a state layer: a wash of the accent over the
     * container at a fixed opacity, rather than each control inventing its own
     * pressed colour. That part is taken as-is, and it composites into the
     * painted fill rather than sitting on top as another item, so it follows
     * the notched silhouette exactly instead of squaring off the cut corner.
     *
     * What is not taken is the ripple. It is a touch idiom - it exists to show
     * WHERE a finger landed, which a pointer already knows - and an expanding
     * circle is the wrong vocabulary for a shell drawn in straight lines. The
     * whole shape lights instead.
     *
     * --- the attack is not the decay
     *
     * 40ms in, 120ms out. A contact closes at once and opens gently, and the
     * asymmetry is most of what makes this read as a switch rather than a
     * highlight. Reading `pressed` inside the Behavior is safe rather than
     * racy: syncPress() below assigns pressWash from the very handler that
     * observes `pressed`, so the flag is always already correct by the time
     * the animation starts.
     *
     * --- and it cannot be too quick to see
     *
     * A fast click can release inside a single frame, and without a floor the
     * wash would be applied and removed before the compositor drew either -
     * so the control that was clicked most decisively would be the one that
     * appeared not to react. The press is held for a minimum, exactly as
     * Material holds its ripple, and only then allowed to decay.
     */
    property bool pressed: false
    property color pressColor: Theme.accent

    property real pressWash: 0

    function syncPress() {
        if (root.pressed) {
            pressMin.restart();
            root.pressWash = Theme.statePressed;
        } else if (!pressMin.running) {
            root.pressWash = 0;
        }
    }

    onPressedChanged: root.syncPress()

    Timer {
        id: pressMin
        interval: 90
        onTriggered: root.syncPress()
    }

    Behavior on pressWash {
        MotionNumber { duration: root.pressed ? Theme.dur(40) : Theme.durState }
    }

    /*
     * --- one alpha does not fit every accent
     *
     * Material specifies its state layers as a flat opacity, which works
     * because Material's palettes are generated to a tonal scale. This shell
     * lets a palette name any colour it likes, and a flat alpha then lands
     * very differently depending on which one: the default cyan lifts a
     * pressed control by 27 points of luminance, while the danger red lifts it
     * by 6 - because red carries about a fifth of the luminance weight that
     * cyan does. Destructive buttons and red-tinted tiles, which are the ones
     * you most want confirmation from, were the ones that barely reacted.
     *
     * So the wash is scaled by how little luminance the accent brings. A
     * bright accent passes through at its stated opacity; a dark one gets more
     * of itself, up to two and a half times, which is what it takes for red to
     * register as a press at all. Clamped at the bottom so a near-white accent
     * is not thinned into nothing.
     */
    readonly property real pressGain: {
        const l = 0.2126 * root.pressColor.r
                + 0.7152 * root.pressColor.g
                + 0.0722 * root.pressColor.b;
        return Math.max(1.0, Math.min(2.5, 0.75 / Math.max(0.05, l)));
    }

    // Composited rather than overlaid - see above. Qt.tint puts the wash over
    // the fill at its own alpha, which is precisely the state-layer model.
    readonly property color paintedFill: root.pressWash > 0
        ? Qt.tint(root.fillColor,
                  Theme.alpha(root.pressColor,
                              Math.min(1, root.pressWash * root.pressGain)))
        : root.fillColor

    /*
     * The outline takes the wash too, and harder.
     *
     * Material puts its state layer on the container's surface, because a
     * Material control IS a surface. These are line drawings: the outline is
     * what defines the control, so leaving it out of the press would light the
     * inside of a shape whose edge had not moved. At double weight the edge
     * leads and the fill follows it.
     */
    readonly property color paintedStroke: root.pressWash > 0
        ? Qt.tint(root.strokeColor,
                  Theme.alpha(root.pressColor,
                              Math.min(1, root.pressWash * root.pressGain * 2)))
        : root.strokeColor

    implicitWidth: 100
    implicitHeight: 40

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        antialiasing: true

        // --- outer outline: fill plus the primary stroke
        ShapePath {
            id: outer
            fillColor: root.paintedFill
            strokeColor: root.paintedStroke
            strokeWidth: root.strokeWidth
            joinStyle: ShapePath.MiterJoin
            capStyle: ShapePath.FlatCap

            // Inset by half the stroke so the border is not clipped at the edge.
            readonly property real l: root.strokeWidth / 2
            readonly property real t: root.strokeWidth / 2
            readonly property real r: root.width - root.strokeWidth / 2
            readonly property real b: root.height - root.strokeWidth / 2
            readonly property real n: root.notch

            /*
             * One polyline rather than eight PathLines.
             *
             * The same nine points in the same order, so the outline is the
             * same outline - but eight PathLine objects were eight QObjects
             * with two bindings each, per path, per NotchRect, and this shape
             * is the frame of nearly everything the shell draws. The Control
             * Center alone builds hundreds of them. One element with one
             * binding does the same job.
             */
            PathPolyline {
                path: [
                    Qt.point(outer.l + (root.notchTopLeft ? outer.n : 0), outer.t),
                    Qt.point(outer.r - (root.notchTopRight ? outer.n : 0), outer.t),
                    Qt.point(outer.r, outer.t + (root.notchTopRight ? outer.n : 0)),
                    Qt.point(outer.r, outer.b - (root.notchBottomRight ? outer.n : 0)),
                    Qt.point(outer.r - (root.notchBottomRight ? outer.n : 0), outer.b),
                    Qt.point(outer.l + (root.notchBottomLeft ? outer.n : 0), outer.b),
                    Qt.point(outer.l, outer.b - (root.notchBottomLeft ? outer.n : 0)),
                    Qt.point(outer.l, outer.t + (root.notchTopLeft ? outer.n : 0)),
                    Qt.point(outer.l + (root.notchTopLeft ? outer.n : 0), outer.t)
                ]
            }
        }

        // --- inner outline: stroke only, offset inward. Empty when
        // doubleStroke is off, which is almost everywhere, so it builds no
        // geometry and its points are never computed.
        ShapePath {
            id: inner
            fillColor: "transparent"
            strokeColor: root.doubleStroke ? root.innerStrokeColor : "transparent"
            strokeWidth: root.doubleStroke ? 1 : 0
            joinStyle: ShapePath.MiterJoin
            capStyle: ShapePath.FlatCap

            readonly property real pad: root.strokeWidth / 2 + root.innerStrokeInset
            readonly property real l: inner.pad
            readonly property real t: inner.pad
            readonly property real r: root.width - inner.pad
            readonly property real b: root.height - inner.pad
            readonly property real n: Math.max(1, root.notch - root.innerStrokeInset)

            PathPolyline {
                path: !root.doubleStroke ? [] : [
                    Qt.point(inner.l + (root.notchTopLeft ? inner.n : 0), inner.t),
                    Qt.point(inner.r - (root.notchTopRight ? inner.n : 0), inner.t),
                    Qt.point(inner.r, inner.t + (root.notchTopRight ? inner.n : 0)),
                    Qt.point(inner.r, inner.b - (root.notchBottomRight ? inner.n : 0)),
                    Qt.point(inner.r - (root.notchBottomRight ? inner.n : 0), inner.b),
                    Qt.point(inner.l + (root.notchBottomLeft ? inner.n : 0), inner.b),
                    Qt.point(inner.l, inner.b - (root.notchBottomLeft ? inner.n : 0)),
                    Qt.point(inner.l, inner.t + (root.notchTopLeft ? inner.n : 0)),
                    Qt.point(inner.l + (root.notchTopLeft ? inner.n : 0), inner.t)
                ]
            }
        }
    }
}
