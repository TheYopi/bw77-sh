import QtQuick
import QtQuick.Shapes
import qs.Config

/*
 * Filled line graph over a history array.
 *
 * Built from Shape rather than Canvas. A Canvas has to clear and repaint the
 * whole surface on every update, and that clear is visible as a flash on slower
 * paints - which is what made the system monitor blink every two seconds.
 * Shapes are retained: the geometry is replaced, nothing is ever blanked.
 *
 * Quickshell has no built-in system monitor, so the data still comes from
 * Scripts/sysmon.sh; only the drawing changed.
 */
Item {
    id: root

    property var values: []
    property real maxValue: 100
    property color lineColor: Theme.accent
    property real fillOpacity: 0.16
    property bool showGrid: true
    property real lineWidth: 1.5

    // Points are computed once and shared by the fill and the stroke. The
    // array is rebuilt per sample, which at one sample every two seconds is
    // nothing - unlike the visualiser, which is why that one uses a Canvas.
    readonly property var points: {
        const v = values;
        if (!v || v.length < 2 || width <= 0 || height <= 0) return [];
        const dx = width / (v.length - 1);
        const out = [];
        for (let i = 0; i < v.length; i++) {
            const clamped = Math.max(0, Math.min(1, v[i] / Math.max(0.0001, maxValue)));
            out.push(Qt.point(i * dx, height - clamped * height));
        }
        return out;
    }

    // Grid rules, static geometry so they never redraw.
    Repeater {
        model: root.showGrid ? 3 : 0
        Rectangle {
            required property int index
            width: root.width
            height: 1
            y: root.height * (index + 1) / 4
            color: Theme.alpha(Theme.border, 0.5)
        }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        antialiasing: true
        visible: root.points.length > 1

        // Fill: the line, closed down to the baseline.
        ShapePath {
            fillColor: Theme.alpha(root.lineColor, root.fillOpacity)
            strokeColor: "transparent"
            strokeWidth: 0

            PathPolyline {
                path: {
                    const p = root.points;
                    if (p.length < 2) return [];
                    return p.concat([
                        Qt.point(root.width, root.height),
                        Qt.point(0, root.height),
                        p[0]
                    ]);
                }
            }
        }

        // Stroke: the line itself, drawn over the fill.
        ShapePath {
            fillColor: "transparent"
            strokeColor: root.lineColor
            strokeWidth: root.lineWidth
            joinStyle: ShapePath.RoundJoin
            capStyle: ShapePath.RoundCap

            PathPolyline { path: root.points }
        }
    }
}
