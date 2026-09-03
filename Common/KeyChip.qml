import QtQuick
import qs.Config

/* The bracketed keycap the game prints next to every action: [F] ПОДТВЕРДИТЬ */
Item {
    id: root
    property string text: ""

    implicitWidth: Math.max(20, label.implicitWidth + 10)
    implicitHeight: 20

    NotchRect {
        anchors.fill: parent
        fillColor: "transparent"
        strokeColor: Theme.accent
        notch: 4
        notchTopLeft: false
        notchTopRight: false
        notchBottomLeft: false
        notchBottomRight: true
    }

    CyberText {
        id: label
        anchors.centerIn: parent
        text: root.text
        role: "micro"
        color: Theme.accent
    }
}
