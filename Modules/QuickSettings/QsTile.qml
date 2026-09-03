import QtQuick
import qs.Config
import qs.Common

/*
 * A quick settings tile.
 *
 * Two shapes in one: a plain toggle, or an expandable entry with a chevron that
 * opens a submenu underneath. Network and bluetooth use the latter; everything
 * else is a plain toggle.
 */
Item {
    id: root

    property string glyph: ""
    property string label: ""
    property string detail: ""
    property bool on: false
    property bool danger: false
    property bool expandable: false
    property bool expanded: false
    property color tint: Theme.accent

    signal activated()
    signal expandToggled()

    readonly property color activeTint: danger ? Theme.danger : tint

    implicitHeight: 48

    NotchRect {
        anchors.fill: parent
        fillColor: root.on
            ? Theme.alpha(root.activeTint, 0.28)
            : (mouse.containsMouse ? Theme.alpha(root.activeTint, 0.12)
                                   : Theme.alpha(Theme.bgRaised, 0.6))
        strokeColor: root.on ? root.activeTint : Theme.alpha(root.activeTint, 0.4)
        strokeWidth: root.on ? Theme.borderWidthStrong : Theme.borderWidth
        notch: Theme.notchSmall
        notchTopLeft: false
        notchTopRight: false
        notchBottomRight: true
        notchBottomLeft: false

        Behavior on fillColor { ColorAnimation { duration: Theme.durFast } }
    }

    CyberText {
        id: icon
        anchors.left: parent.left
        anchors.leftMargin: Theme.space3
        height: parent.height
        text: root.glyph
        role: "icon"
        font.pixelSize: Theme.fontLarge
        color: root.on ? root.activeTint : Theme.textDim
    }

    Column {
        anchors.left: icon.right
        anchors.leftMargin: Theme.space2
        anchors.right: chevron.visible ? chevron.left : parent.right
        anchors.rightMargin: Theme.space2
        anchors.verticalCenter: parent.verticalCenter
        spacing: -2

        CyberText {
            width: parent.width
            text: root.label
            role: "micro"
            color: root.on ? Theme.text : Theme.textDim
            elide: Text.ElideRight
        }

        CyberText {
            width: parent.width
            visible: root.detail !== ""
            text: root.detail
            role: "micro"
            caps: false
            color: Theme.textMuted
            elide: Text.ElideRight
        }
    }

    // Chevron is its own hit target: tapping the tile acts, tapping the arrow
    // opens the submenu, so the primary action never costs an extra click.
    Item {
        id: chevron
        visible: root.expandable
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 26

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: 6
            anchors.bottomMargin: 6
            width: 1
            color: Theme.alpha(root.activeTint, 0.35)
        }

        CyberText {
            anchors.centerIn: parent
            text: root.expanded ? "\u25BE" : "\u25B8"
            role: "icon"
            color: chevronMouse.containsMouse ? root.activeTint : Theme.textDim
        }

        MouseArea {
            id: chevronMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expandToggled()
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        anchors.rightMargin: chevron.visible ? chevron.width : 0
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }
}
