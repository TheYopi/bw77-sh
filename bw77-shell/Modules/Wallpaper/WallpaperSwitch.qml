import QtQuick
import qs.Config
import qs.Common

/*
 * One labelled multi-switch in the wallpaper picker's header row.
 *
 * A caption over a CyberSelector, plus the focus treatment the picker's own
 * keyboard ring drives. The selector already knows how to draw itself focused
 * and how to step; what it does not have is a caption or a notion of being one
 * stop in a ring, and both of those are the picker's business rather than the
 * control's - so they live here and CyberSelector stays untouched.
 *
 * `navFocused` is overridden rather than left on its default CcNav binding: the
 * Control Center's navigator does not run on this surface, and pointing the
 * control at a singleton that is not steering it would leave it permanently
 * unfocused.
 *
 * A disabled switch is dimmed and stops taking the cursor. The picker also
 * leaves it out of the ring, so it is never possible to focus one and find the
 * arrows doing nothing.
 */
Item {
    id: root

    property string label: ""
    property var options: []
    property var current
    property bool focused: false
    property color accentColor: Theme.accent

    signal picked(var value)

    // Raised when the block is clicked, so a mouse user landing on a switch
    // moves the keyboard ring with them rather than leaving the focus ring
    // somewhere they are not looking.
    signal focusRequested()

    implicitWidth: 210
    implicitHeight: caption.implicitHeight + Theme.space1 + selector.implicitHeight

    opacity: enabled ? 1 : 0.35

    Behavior on opacity { NumberAnimation { duration: Theme.durFast } }

    CyberText {
        id: caption
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        // Elided rather than allowed to grow: the compound captions ("Style ·
        // Transition", "Colour · From") are wider than the 200px the stepper
        // under them gets, and an unbounded Text would run straight over the
        // next switch in the row.
        elide: Text.ElideRight
        text: root.label
        role: "micro"
        color: root.focused ? root.accentColor : Theme.textMuted

        Behavior on color { ColorAnimation { duration: Theme.durFast } }
    }

    CyberSelector {
        id: selector

        anchors.top: caption.bottom
        anchors.topMargin: Theme.space1
        anchors.left: parent.left
        anchors.right: parent.right

        options: root.options
        current: root.current
        accentColor: root.accentColor

        // The picker owns focus, not CcNav.
        navFocused: root.focused

        onPicked: (v) => root.picked(v)
    }

    // Sits under the selector's own MouseArea, so it only catches clicks on the
    // caption and the padding. The selector's arrows and label keep working as
    // they always did; this just moves the ring when the block is clicked.
    MouseArea {
        anchors.fill: parent
        z: -1
        acceptedButtons: Qt.LeftButton
        onPressed: (m) => {
            root.focusRequested();
            m.accepted = false;
        }
    }
}
