import QtQuick
import QtQuick.Shapes
import qs.Config

/*
 * The solid triangle used on both ends of every stepper and slider.
 *
 * Drawn as a Shape rather than set as a glyph. The arrowheads were text -
 * U+25C1 and U+25B7 - which made them dependent on whichever font happened to
 * carry those codepoints, and the two faces the shell now ships draw them at
 * noticeably different weights and baselines. A path is the same triangle in
 * every theme, sizes exactly, and centres on the pixel it is given.
 *
 * Filled, not outlined, and in the accent colour: in the study these are the
 * brightest thing on the control, because they are the only part of it that
 * says "this can be changed".
 */
Item {
    id: root

    // "left" or "right".
    property string direction: "right"

    property color color: Theme.accent
    property real size: 11

    // No `enabled` property declared here on purpose. Item already has one, and
    // redeclaring it shadows the built-in: call sites would set the shadow
    // while the real Item.enabled - the one that propagates down to the
    // MouseArea - stayed true. Using the inherited property means a disabled
    // arrow stops accepting clicks for free.

    signal triggered()

    readonly property bool hovered: mouse.containsMouse

    implicitWidth: size + Theme.space2
    implicitHeight: size + 2

    opacity: enabled ? 1 : 0.3

    Shape {
        anchors.centerIn: parent
        width: root.size
        height: root.size
        preferredRendererType: Shape.CurveRenderer
        antialiasing: true

        /*
         * The triangle.
         *
         * Every coordinate goes through `root` rather than through `parent`.
         * PathLine is a PathElement, not an Item, so it has no `parent` at all
         * - the bindings that used one silently resolved to nothing, the path
         * collapsed, and the arrows have been drawing as empty space since they
         * were introduced. That is the missing arrowheads on the audio sliders,
         * and it was equally true of every stepper in the shell.
         *
         * Wound from the flat edge to the point, so the same three lines serve
         * both directions with only the x values mirrored.
         */
        ShapePath {
            fillColor: (mouse.pressed || root.hovered) ? Theme.accentGlow : root.color
            strokeWidth: 0
            strokeColor: "transparent"

            // Small and quick to cross, so it wants the transition more than a
            // large target does - a bare colour swap on something this size
            // registers as a flicker rather than as a response.
            Behavior on fillColor { ColorAnimation { duration: Theme.durFast } }

            startX: root.direction === "right" ? 0 : root.size
            startY: 0

            PathLine {
                x: root.direction === "right" ? 0 : root.size
                y: root.size
            }
            PathLine {
                x: root.direction === "right" ? root.size : 0
                y: root.size / 2
            }
            PathLine {
                x: root.direction === "right" ? 0 : root.size
                y: 0
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        // Generous beyond the drawn triangle. The shape is 11px across and a
        // hit target that small is a miss most of the time.
        anchors.margins: -6
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.triggered()
    }
}
