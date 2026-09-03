import QtQuick
import qs.Config
import qs.Common

/*
 * One labelled setting. The control goes in `control`; the row handles the
 * label, alternating background, hover highlight and keyboard focus.
 *
 * The description no longer prints under the label. Sixteen panes of two-line
 * rows put a paragraph of explanation next to every switch whether or not
 * anyone was asking, which is what pushed the list long enough to need the
 * scrollbar in the first place. It is still declared here - it just renders in
 * the tip panel, for the one row you are actually on.
 */
Item {
    id: root

    default property alias control: slot.data
    property string label: ""
    property string description: ""
    property bool alternate: false

    // Rows that hold no steerable control - a header-ish row, a bare button -
    // opt out so the arrows do not stop on them.
    property bool navigable: true

    readonly property bool active: CcNav.activeRow === root

    /*
     * The PaneScroll this row lives in.
     *
     * Walked rather than passed down: rows sit inside Repeaters, Columns and
     * conditional wrappers at varying depths, and threading a property through
     * every one of those would mean editing every pane.
     */
    readonly property var ownerPane: {
        let p = parent;
        while (p) {
            if (p.isPaneScroll === true) return p;
            p = p.parent;
        }
        return null;
    }

    width: parent ? parent.width : 0
    // Collapse to nothing when hidden, or conditional rows leave a gap in the
    // Column where the row used to be.
    implicitHeight: visible ? Math.max(44, slot.height + Theme.space3) : 0

    // mapToItem is a call, not a binding, so this is deliberately a function -
    // it is only ever asked for at the moment the arrows move.
    function absoluteY() {
        const p = mapToItem(null, 0, 0);
        return p ? p.y : 0;
    }

    /*
     * The thing the left/right arrows steer.
     *
     * Controls are dropped into `slot` bare in most rows but wrapped in a Row
     * in others (a swatch beside a stepper, say), so this looks a couple of
     * levels down rather than assuming the first child. Anything that answers
     * to navStep is steerable; that is the whole contract.
     */
    function navControl() {
        function find(item, depth) {
            if (!item || depth > 3) return null;
            for (let i = 0; i < item.children.length; i++) {
                const c = item.children[i];
                if (!c || !c.visible) continue;
                if (typeof c.navStep === "function") return c;
                const deeper = find(c, depth + 1);
                if (deeper) return deeper;
            }
            return null;
        }
        return find(slot, 0);
    }

    function navKind() {
        const c = navControl();
        return (c && c.navKind !== undefined) ? c.navKind : "";
    }

    function navStep(delta) {
        const c = navControl();
        if (!c) return false;
        c.navStep(delta);
        return true;
    }

    function navActivate() {
        const c = navControl();
        if (!c || typeof c.navActivate !== "function") return false;
        c.navActivate();
        return true;
    }

    Component.onCompleted: CcNav.register(root)
    Component.onDestruction: CcNav.unregister(root)

    // --- background: selection, then hover, then the zebra stripe
    /*
     * --- one selected look, whatever selected it
     *
     * The mouse and the keyboard used to draw different marks: a full-height
     * accent tick under the arrows, a short crimson stub under the pointer,
     * with different fill strengths behind them. The reasoning was that "the
     * arrows are here" and "the pointer is here" should never be the same
     * mark.
     *
     * In practice they never needed telling apart. CcNav has exactly one
     * active row and both inputs set the same one, so there is never a crimson
     * stub and an accent tick on screen at once to confuse - only the same row
     * changing appearance depending on how you last touched it, which read as
     * the row flickering between two states as the pointer crossed a pane the
     * keyboard was already on.
     *
     * The distinction itself still exists where it earns its keep: the tip
     * panel on the right shows its key hints only under the keyboard, which is
     * the one place the difference changes what you can do rather than just
     * how a row looks.
     */
    Rectangle {
        anchors.fill: parent
        color: root.active ? Theme.alpha(Theme.accent, 0.14)
            : (root.alternate ? Theme.alpha(Theme.bgDeep, 0.35) : "transparent")

        Behavior on color { ColorAnimation { duration: Theme.durFast } }
    }

    // Left tick: full height, in accent, for both inputs.
    Rectangle {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 3
        height: root.active ? parent.height : 0
        color: Theme.accent

        Behavior on height { NumberAnimation { duration: Theme.durFast; easing.type: Theme.easeSnap } }
    }

    // The label resolves out of noise when the surface opens, along with
    // everything else on it.
    GlitchText {
        id: labelText
        anchors.left: parent.left
        anchors.leftMargin: Theme.space4
        anchors.right: slot.left
        anchors.rightMargin: Theme.space4
        anchors.verticalCenter: parent.verticalCenter
        height: implicitHeight
        text: root.label
        role: "label"
        elide: Text.ElideRight
        color: root.active ? Theme.text : Theme.textDim
        decodeTrigger: CcNav.revealNonce

        Behavior on color { ColorAnimation { duration: Theme.durFast } }
    }

    Item {
        id: slot
        anchors.right: parent.right
        anchors.rightMargin: Theme.space4
        anchors.verticalCenter: parent.verticalCenter
        width: childrenRect.width
        height: childrenRect.height
    }

    MouseArea {
        id: rowMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton

        onEntered: if (root.navigable) CcNav.hoverEntered(root)
        onExited: if (root.navigable) CcNav.hoverLeft(root)

        // Real cursor travel takes the surface back off the keyboard; the
        // scroll-under-a-still-mouse case does not. See CcNav.cursorMoved.
        onPositionChanged: (mouse) => {
            if (!root.navigable) return;
            if (!CcNav.cursorMoved(rowMouse, mouse.x, mouse.y)) return;
            CcNav.pointerTook(root);
        }
    }
}
