import QtQuick
import qs.Config
import qs.Common

/* Radio toggle plus a scan action, shared by both submenus. */
Item {
    id: root

    property string label: ""
    property bool checked: false
    property bool toggleEnabled: true
    property bool scanning: false
    property bool showScan: true
    property color tint: Theme.accent

    signal toggled()
    signal scanRequested()

    width: parent ? parent.width : 0
    height: 32

    CyberText {
        id: text
        anchors.left: parent.left
        anchors.leftMargin: Theme.space2
        height: parent.height
        text: root.label
        role: "micro"
        color: Theme.textDim
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: Theme.space2
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.space3

        CyberText {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.showScan
            text: root.scanning ? Settings.t("SCANNING") : Settings.t("SCAN")
            role: "micro"
            color: root.scanning ? root.tint
                : (scanMouse.containsMouse ? root.tint : Theme.textMuted)

            Behavior on color { ColorAnimation { duration: Theme.durFast } }

            SequentialAnimation on opacity {
                running: root.scanning && !Theme.reducedMotion
                loops: Animation.Infinite
                NumberAnimation { to: 0.4; duration: 600 }
                NumberAnimation { to: 1.0; duration: 600 }
            }

            MouseArea {
                id: scanMouse
                anchors.fill: parent
                anchors.margins: -5
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                enabled: root.checked
                onClicked: root.scanRequested()
            }
        }

        CyberToggle {
            anchors.verticalCenter: parent.verticalCenter
            showLabel: false
            enabled: root.toggleEnabled
            checked: root.checked
            onToggled: root.toggled()
        }
    }
}
