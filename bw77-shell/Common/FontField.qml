import QtQuick
import qs.Config
import qs.Common
import qs.Services

/*
 * The control half of a font setting: shows the family in use, set in itself,
 * and hands off to the full-screen picker.
 *
 * This used to be a whole row that expanded a picker inline underneath, which
 * made it the only setting in the shell whose row changed height when you used
 * it. It is a control that sits in an ordinary SettingRow now, so the font
 * settings look and navigate like every other setting until the moment you
 * actually commit to changing one.
 */
Item {
    id: root

    property string title: ""
    property string hint: ""
    property string value: ""
    property string sample: "Night City 0123"

    signal changed(string family)

    // --- keyboard contract
    //
    // Right opens; left does not close, because there is nothing open yet to
    // close. Enter is the primary key and the tip panel says so - the arrow is
    // there for the hand that is already moving that way.
    readonly property string navKind: "picker"
    property bool navFocused: CcNav.focusedControl === root

    function navStep(delta) { if (delta > 0) root.open(); }
    function navActivate() { root.open(); }

    function open() {
        Shell.requestFont(root.title, root.hint, root.value,
                          (family) => root.changed(family));
    }

    implicitWidth: 260
    implicitHeight: 34

    NotchRect {
        anchors.fill: parent
        fillColor: Theme.alpha(Theme.bgDeep, 0.85)
        strokeColor: root.navFocused ? Theme.accent
            : (mouse.containsMouse ? Theme.alpha(Theme.accent, 0.8)
                                   : Theme.alpha(Theme.border, 0.9))
        strokeWidth: root.navFocused ? Theme.borderWidthStrong : Theme.borderWidth
        notch: 6
        notchTopLeft: false
        notchTopRight: false
        notchBottomLeft: false
        notchBottomRight: true

        Behavior on strokeColor { ColorAnimation { duration: Theme.durFast } }
    }

    // Deliberately not a CyberText: this is the one label in the shell that
    // must not be styled by the theme, because what it is showing you is the
    // font itself.
    Text {
        anchors.left: parent.left
        anchors.leftMargin: Theme.space3
        anchors.right: caret.left
        anchors.rightMargin: Theme.space2
        anchors.verticalCenter: parent.verticalCenter
        text: root.value
        font.family: root.value
        font.pixelSize: Theme.fontBase
        color: Theme.accent
        elide: Text.ElideRight
        renderType: Text.NativeRendering
    }

    CyberText {
        id: caret
        anchors.right: parent.right
        anchors.rightMargin: Theme.space3
        anchors.verticalCenter: parent.verticalCenter
        text: "\u25B8"
        role: "icon"
        color: root.navFocused ? Theme.accent : Theme.danger
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.open()
    }
}
