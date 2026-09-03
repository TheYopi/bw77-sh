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

    implicitWidth: 100
    implicitHeight: 40

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        antialiasing: true

        // --- outer outline: fill plus the primary stroke
        ShapePath {
            id: outer
            fillColor: root.fillColor
            strokeColor: root.strokeColor
            strokeWidth: root.strokeWidth
            joinStyle: ShapePath.MiterJoin
            capStyle: ShapePath.FlatCap

            // Inset by half the stroke so the border is not clipped at the edge.
            readonly property real l: root.strokeWidth / 2
            readonly property real t: root.strokeWidth / 2
            readonly property real r: root.width - root.strokeWidth / 2
            readonly property real b: root.height - root.strokeWidth / 2
            readonly property real n: root.notch

            startX: outer.l + (root.notchTopLeft ? outer.n : 0)
            startY: outer.t

            PathLine { x: outer.r - (root.notchTopRight ? outer.n : 0); y: outer.t }
            PathLine { x: outer.r; y: outer.t + (root.notchTopRight ? outer.n : 0) }
            PathLine { x: outer.r; y: outer.b - (root.notchBottomRight ? outer.n : 0) }
            PathLine { x: outer.r - (root.notchBottomRight ? outer.n : 0); y: outer.b }
            PathLine { x: outer.l + (root.notchBottomLeft ? outer.n : 0); y: outer.b }
            PathLine { x: outer.l; y: outer.b - (root.notchBottomLeft ? outer.n : 0) }
            PathLine { x: outer.l; y: outer.t + (root.notchTopLeft ? outer.n : 0) }
            PathLine { x: outer.l + (root.notchTopLeft ? outer.n : 0); y: outer.t }
        }

        // --- inner outline: stroke only, offset inward. Transparent and zero
        // width when doubleStroke is off, so the path costs nothing to keep.
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

            startX: inner.l + (root.notchTopLeft ? inner.n : 0)
            startY: inner.t

            PathLine { x: inner.r - (root.notchTopRight ? inner.n : 0); y: inner.t }
            PathLine { x: inner.r; y: inner.t + (root.notchTopRight ? inner.n : 0) }
            PathLine { x: inner.r; y: inner.b - (root.notchBottomRight ? inner.n : 0) }
            PathLine { x: inner.r - (root.notchBottomRight ? inner.n : 0); y: inner.b }
            PathLine { x: inner.l + (root.notchBottomLeft ? inner.n : 0); y: inner.b }
            PathLine { x: inner.l; y: inner.b - (root.notchBottomLeft ? inner.n : 0) }
            PathLine { x: inner.l; y: inner.t + (root.notchTopLeft ? inner.n : 0) }
            PathLine { x: inner.l + (root.notchTopLeft ? inner.n : 0); y: inner.t }
        }
    }
}
