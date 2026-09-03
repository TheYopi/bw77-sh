import QtQuick
import qs.Config
import qs.Common

/*
 * One row in a network or bluetooth submenu.
 *
 * `busy` covers pairing and connecting: those take seconds and a row that does
 * not visibly react feels like a dead click.
 */
Item {
    id: root

    property string glyph: ""
    property string label: ""
    property string detail: ""
    property bool active: false
    property bool busy: false
    property int signal: -1
    property color tint: Theme.accent
    property bool showRemove: false

    signal activated()
    signal removed()

    width: parent ? parent.width : 0
    height: 34

    Rectangle {
        anchors.fill: parent
        color: root.active
            ? Theme.alpha(root.tint, 0.18)
            : (mouse.containsMouse ? Theme.alpha(root.tint, 0.1) : "transparent")
    }

    CyberText {
        id: icon
        anchors.left: parent.left
        anchors.leftMargin: Theme.space2
        height: parent.height
        text: root.busy ? "\uf110" : root.glyph
        role: "icon"
        font.pixelSize: Theme.fontSmall
        color: root.active ? root.tint : Theme.textMuted

        // A slow spin while pairing, so the row reads as working rather than stuck.
        RotationAnimator on rotation {
            running: root.busy && !Theme.reducedMotion
            loops: Animation.Infinite
            from: 0; to: 360
            duration: 1200
        }
    }

    Column {
        anchors.left: icon.right
        anchors.leftMargin: Theme.space2
        anchors.right: trailing.left
        anchors.rightMargin: Theme.space2
        anchors.verticalCenter: parent.verticalCenter
        spacing: -3

        CyberText {
            width: parent.width
            text: root.label
            role: "micro"
            caps: false
            color: root.active ? root.tint : Theme.text
            elide: Text.ElideRight
        }

        CyberText {
            width: parent.width
            visible: root.detail !== ""
            text: root.detail
            role: "micro"
            caps: false
            font.pixelSize: Theme.fontMicro
            color: Theme.textMuted
            elide: Text.ElideRight
        }
    }

    Row {
        id: trailing
        anchors.right: parent.right
        anchors.rightMargin: Theme.space2
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.space2

        SegmentBar {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.signal >= 0
            width: 30
            height: 10
            segments: 4
            value: root.signal / 100
            fillColor: root.active ? root.tint : Theme.textDim
            warnAtHigh: false
        }

        CyberText {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.showRemove
            text: "\u2715"
            role: "micro"
            color: removeMouse.containsMouse ? Theme.danger : Theme.textMuted

            MouseArea {
                id: removeMouse
                anchors.fill: parent
                anchors.margins: -5
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.removed()
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        anchors.rightMargin: root.showRemove ? 22 : 0
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }
}
