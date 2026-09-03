import QtQuick
import qs.Config
import qs.Common

/*
 * The compact toggle from the study: a frame split in two, with the filled half
 * showing which side you are on.
 *
 * Off fills the left half in the dim red, on fills the right half in the bright
 * one. Position is the primary signal and colour is the confirmation, which is
 * the right way round - a control that changed only colour would be unreadable
 * to anyone who cannot separate the two reds, and a control that only moved
 * would be hard to spot at a glance down a column of twenty.
 *
 * This is the crammed variant. Where a toggle stands on its own and has room
 * for its own label, use CyberToggleRow instead.
 */
Item {
    id: root

    property bool checked: false
    property bool showLabel: false
    property string labelOn: "ON"
    property string labelOff: "OFF"

    signal toggled(bool value)

    // --- keyboard contract
    //
    // Left and right set the state outright rather than toggling. On a stepper
    // the arrows mean "move that way", and a toggle that flipped on both keys
    // would be the one control on the pane where they meant the same thing.
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

    implicitWidth: (showLabel ? stateLabel.implicitWidth + Theme.space3 : 0) + track.width
    implicitHeight: 24

    CyberText {
        id: stateLabel
        visible: root.showLabel
        anchors.right: track.left
        anchors.rightMargin: Theme.space3
        anchors.verticalCenter: parent.verticalCenter
        text: root.checked ? root.labelOn : root.labelOff
        role: "label"
        color: root.checked ? Theme.accent : Theme.textDim
        Behavior on color { ColorAnimation { duration: Theme.durFast } }
    }

    NotchRect {
        id: track
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 54
        height: 22
        fillColor: root.checked ? Theme.alpha(Theme.bgDeep, 0.9)
                                : Theme.alpha(Theme.dangerDim, 0.35)
        strokeColor: root.navFocused ? Theme.accent
            : (root.checked ? Theme.accent : Theme.danger)
        strokeWidth: root.navFocused ? Theme.borderWidthStrong : Theme.borderWidth
        notch: 7

        Behavior on strokeColor { ColorAnimation { duration: Theme.durFast } }

        // The filled half. Inset by the stroke so it sits inside the frame
        // rather than painting over it, and it carries the same cut as the
        // frame so the two corners agree.
        NotchRect {
            width: parent.width / 2 - 3
            height: parent.height - 4
            anchors.verticalCenter: parent.verticalCenter
            x: root.checked ? parent.width / 2 : 2
            fillColor: root.checked ? Theme.accent : Theme.alpha(Theme.danger, 0.55)
            strokeColor: "transparent"
            strokeWidth: 0
            notch: 6

            Behavior on x { NumberAnimation { duration: Theme.durFast; easing.type: Theme.easeSnap } }
            Behavior on fillColor { ColorAnimation { duration: Theme.durFast } }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.checked = !root.checked;
            root.toggled(root.checked);
        }
    }
}
