import QtQuick
import qs.Config

/*
 * The small L-brackets that sit just outside the corners of framed content in
 * the game's inventory and cyberware screens. Purely decorative, so the whole
 * thing is behind an FX toggle.
 */
Item {
    id: root

    property color color: Theme.accent
    property real thickness: 1
    property real length: Theme.tickLength
    property real inset: 0
    property bool topLeft: true
    property bool topRight: true
    property bool bottomLeft: true
    property bool bottomRight: true

    visible: Settings.fx.cornerTicks
    anchors.fill: parent

    Repeater {
        model: [
            { on: root.topLeft,     hx: 0, hy: 0, hAnchorRight: false, vAnchorBottom: false },
            { on: root.topRight,    hx: 1, hy: 0, hAnchorRight: true,  vAnchorBottom: false },
            { on: root.bottomLeft,  hx: 0, hy: 1, hAnchorRight: false, vAnchorBottom: true  },
            { on: root.bottomRight, hx: 1, hy: 1, hAnchorRight: true,  vAnchorBottom: true  }
        ]

        Item {
            required property var modelData
            visible: modelData.on
            width: root.length
            height: root.length
            // Rounded: at fractional offsets a 1px arm can fall between device
            // pixels and vanish, which is why some corners rendered as a dash
            // with the vertical stroke missing.
            x: Math.round(modelData.hx === 0
                ? root.inset : root.width - root.length - root.inset)
            y: Math.round(modelData.hy === 0
                ? root.inset : root.height - root.length - root.inset)

            Rectangle { // horizontal arm
                width: root.length
                height: root.thickness
                color: root.color
                antialiasing: false
                y: Math.round(modelData.vAnchorBottom ? parent.height - root.thickness : 0)
            }
            Rectangle { // vertical arm
                width: root.thickness
                height: root.length
                color: root.color
                antialiasing: false
                x: Math.round(modelData.hAnchorRight ? parent.width - root.thickness : 0)
            }
        }
    }
}
