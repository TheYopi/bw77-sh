import QtQuick
import qs.Config
import qs.Common

/*
 * Single-choice control, in the stepper shape.
 *
 * This used to expand a list over its neighbours, reparented onto the window
 * overlay to get around Qt not delivering clicks outside a parent's bounds. It
 * worked, but it was the one control in the shell that opened a second surface
 * to answer a question the stepper answers in place - and in a full-screen
 * Control Center driven from the keyboard, a floating list that has to be
 * positioned, flipped when it runs off the bottom, and polled at 32ms to follow
 * the pane as it scrolls is a lot of machinery for "pick one of eight".
 *
 * So it is a CyberSelector now. The API is unchanged - `options` still takes
 * plain strings or { value, label } objects and `picked` still emits a string -
 * because eight call sites across six panes were written against it and none of
 * them cared how it drew itself.
 */
Item {
    id: root

    // Either plain strings, or { value, label } objects.
    property var options: []
    property string current: ""

    signal picked(string value)

    // --- keyboard contract
    //
    // Declared here as well as on the inner selector because the row's control
    // search stops at the first item that answers to navStep, and that is this
    // wrapper. Pointing the inner selector's focus binding back at this item
    // keeps the two in step.
    readonly property string navKind: "selector"
    readonly property bool navFocused: CcNav.focusedControl === root

    function navStep(delta) { sel.step(delta); }
    function navActivate() { sel.step(1); }

    implicitWidth: 170
    implicitHeight: 34

    function valueOf(o) { return (o && o.value !== undefined) ? o.value : o; }
    function labelOf(o) { return (o && o.label !== undefined) ? o.label : o; }

    CyberSelector {
        id: sel
        anchors.fill: parent

        // Role lists elsewhere in the shell are bare strings ("accent",
        // "warn"); position lists are objects. Both normalise to the same pair.
        options: (root.options || []).map(o => ({
            v: root.valueOf(o),
            l: String(root.labelOf(o))
        }))

        current: root.current
        navFocused: root.navFocused
        onPicked: (v) => root.picked(String(v))
    }
}
