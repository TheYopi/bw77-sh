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
