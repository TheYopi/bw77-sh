import QtQuick
import qs.Config
import qs.Common

/*
 * The roomy toggle from the study: a full-width bar with a filled swatch at the
 * left and the label beside it.
 *
 * The swatch is a checkbox in everything but name - empty when off, solid when
 * on - and the whole bar is the hit target, which is the point of using it
 * where there is room. The compact CyberToggle asks the eye to judge which half
 * of a 54px frame is filled; this one is unambiguous across a room.
 *
 * Use it where a toggle carries its own label. Inside a SettingRow, which
 * already prints the label down the left, use CyberToggle.
 */
Item {
    id: root

    property bool checked: false
    property string label: ""
    property color accentColor: Theme.accent

    signal toggled(bool value)

    readonly property string navKind: "toggle"
    property bool navFocused: CcNav.focusedControl === root

    function navStep(delta) {
        const want = delta > 0;
        if (want === root.checked) return;
        root.checked = want;
        root.toggled(root.checked);
    }

    function navActivate() {
        root.checked = !root.checked;
        root.toggled(root.checked);
    }

    implicitWidth: 260
    implicitHeight: 34

    NotchRect {
        anchors.fill: parent
        fillColor: Theme.alpha(Theme.bgDeep, mouse.containsMouse ? 0.55 : 0.75)
        strokeColor: root.navFocused ? root.accentColor : Theme.frame
        strokeWidth: root.navFocused ? Theme.borderWidthStrong : Theme.borderWidth
        notch: Theme.notch

        Behavior on strokeColor { ColorAnimation { duration: Theme.durFast } }
        Behavior on fillColor { ColorAnimation { duration: Theme.durFast } }
    }

    // Square, and sized off the bar's height so it stays square whatever the
    // theme scale does to the row.
    NotchRect {
        id: swatch
        anchors.left: parent.left
        anchors.leftMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        width: parent.height - 8
        height: parent.height - 8
        fillColor: root.checked ? root.accentColor : Theme.alpha(Theme.bgDeep, 0.6)
        strokeColor: Theme.frame
        strokeWidth: Theme.borderWidth
        notch: 7

        Behavior on fillColor { ColorAnimation { duration: Theme.durFast } }
    }

    CyberText {
        anchors.left: swatch.right
        anchors.leftMargin: Theme.space3
        anchors.right: parent.right
        anchors.rightMargin: Theme.space3
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        role: "label"
        elide: Text.ElideRight
        color: root.checked ? root.accentColor : Theme.textDim

        Behavior on color { ColorAnimation { duration: Theme.durFast } }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.checked = !root.checked;
            root.toggled(root.checked);
        }
    }
}
