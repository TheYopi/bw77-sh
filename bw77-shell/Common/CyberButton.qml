import QtQuick
import qs.Config

/*
 * Primary interactive control. Hover fills the shape and inverts the label,
 * matching the game's list selection behaviour rather than a soft highlight.
 */
Item {
    id: root

    property string text: ""
    property string iconText: ""          // Nerd Font glyph, optional
    property bool destructive: false
    property bool active: false           // toggled/selected state
    property bool enabled: true
    property string keyHint: ""           // renders the little [F] key chip
    property real hPadding: Theme.space4

    signal clicked()

    readonly property color _accent: destructive ? Theme.danger : Theme.accent

    /*
     * Selected and hovered must not look the same.
     *
     * Both used to paint a solid fill, so hovering one option in a group made
     * two buttons appear chosen at once. Selection is now the solid fill;
     * hover is a wash plus a brighter outline, which reads as "you are about
     * to pick this" rather than "this is picked".
     */
    readonly property bool _selected: active && enabled
    readonly property bool _hovered: mouse.containsMouse && enabled && !active
    readonly property bool _lit: _selected

    implicitWidth: row.implicitWidth + hPadding * 2
    implicitHeight: Math.max(30, row.implicitHeight + Theme.space2 * 2)
    opacity: enabled ? 1.0 : 0.4

    NotchRect {
        anchors.fill: parent
        fillColor: root._selected ? root._accent
            : (root._hovered ? Theme.alpha(root._accent, 0.18)
                             : Theme.alpha(Theme.bgRaised, 0.85))
        strokeColor: root._selected ? root._accent
            : (root._hovered ? root._accent : Theme.alpha(root._accent, 0.55))
        strokeWidth: root._selected ? Theme.borderWidthStrong : Theme.borderWidth
        notch: Theme.notchSmall
        notchTopLeft: false
        notchTopRight: false
        notchBottomRight: true
        notchBottomLeft: false

        Behavior on fillColor { ColorAnimation { duration: Theme.durFast } }
        Behavior on strokeColor { ColorAnimation { duration: Theme.durFast } }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.space2

        CyberText {
            visible: root.iconText !== ""
            text: root.iconText
            // The slot is named iconText; it holds a glyph.
            role: "icon"
            color: root._selected ? Theme.textOnAccent : root._accent
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: Theme.durFast } }
        }

        CyberText {
            visible: root.text !== ""
            text: root.text
            role: "label"
            color: root._selected ? Theme.textOnAccent
                : (root._hovered ? root._accent : Theme.text)
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: Theme.durFast } }
        }

        // In the Row, not anchored over it: anchoring the chip to the right
        // edge while the Row stayed centred made the two overlap.
        KeyChip {
            id: keyChip
            visible: root.keyHint !== ""
            text: root.keyHint
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        enabled: root.enabled
        onClicked: root.clicked()
    }
}
