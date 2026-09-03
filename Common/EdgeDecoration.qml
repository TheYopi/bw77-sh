import QtQuick
import qs.Config

/*
 * The shared edge treatment for framed surfaces.
 *
 * The top bar, quick settings panel and dock all draw this, so changing the
 * style once restyles all three and they keep reading as one system rather
 * than three separately decorated panels.
 *
 * `edge` names the side of THIS surface that faces the rest of the screen -
 * the bottom edge of a top bar, the left edge of a right-hand panel - because
 * that is the side the rule belongs on.
 */
Item {
    id: root

    property string edge: "bottom"          // top | bottom | left | right
    property string style: Settings.decoration.style
    property int thickness: Settings.decoration.thickness

    readonly property bool vertical: edge === "left" || edge === "right"

    readonly property color color: Settings.decoration.colorCustom !== ""
        ? Settings.decoration.colorCustom
        : Theme.c(Settings.decoration.colorRole)

    anchors.fill: parent
    visible: style !== "none"

    // --- line: fades in from both ends, so the rule reads as lit rather than
    //     drawn, and never collides with the surface's chamfered corners.
    Rectangle {
        visible: root.style === "line"

        anchors.left: root.vertical
            ? (root.edge === "left" ? parent.left : undefined)
            : parent.left
        anchors.right: root.vertical
            ? (root.edge === "right" ? parent.right : undefined)
            : parent.right
        anchors.top: root.vertical
            ? parent.top
            : (root.edge === "top" ? parent.top : undefined)
        anchors.bottom: root.vertical
            ? parent.bottom
            : (root.edge === "bottom" ? parent.bottom : undefined)

        width: root.vertical ? root.thickness : undefined
        height: root.vertical ? undefined : root.thickness

        gradient: Gradient {
            orientation: root.vertical ? Gradient.Vertical : Gradient.Horizontal
            GradientStop { position: 0.0; color: Theme.alpha(root.color, 0.0) }
            GradientStop { position: Settings.decoration.fade; color: root.color }
            GradientStop { position: 1.0 - Settings.decoration.fade; color: root.color }
            GradientStop { position: 1.0; color: Theme.alpha(root.color, 0.0) }
        }
    }

    // --- solid: the same rule at full strength from end to end.
    Rectangle {
        visible: root.style === "solid"

        anchors.left: root.vertical
            ? (root.edge === "left" ? parent.left : undefined)
            : parent.left
        anchors.right: root.vertical
            ? (root.edge === "right" ? parent.right : undefined)
            : parent.right
        anchors.top: root.vertical
            ? parent.top
            : (root.edge === "top" ? parent.top : undefined)
        anchors.bottom: root.vertical
            ? parent.bottom
            : (root.edge === "bottom" ? parent.bottom : undefined)

        width: root.vertical ? root.thickness : undefined
        height: root.vertical ? undefined : root.thickness
        color: root.color
    }

    // --- border: outlines the whole surface instead of a single edge.
    Rectangle {
        visible: root.style === "border"
        anchors.fill: parent
        color: "transparent"
        border.color: root.color
        border.width: root.thickness
    }
}
