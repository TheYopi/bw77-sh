pragma Singleton

import QtQuick
import Quickshell

/*
 * Keyboard focus and tip routing for the Control Center.
 *
 * The panes are built from plain SettingRows with no focus chain of their own -
 * that was fine when the arrows only ever scrolled, but the redesign needs to
 * know which single row the user is on, so that row can highlight, the arrows
 * can be handed to its control, and the description can be printed in the tip
 * panel on the right. Giving every row real Qt focus would mean touching
 * sixteen pane files and fighting the Flickable for it.
 *
 * So rows announce themselves here instead. One registry, one active row, and
 * the surface reads `activeRow` for everything it needs.
 *
 * Rows are held unordered and sorted by their on-screen position at the moment
 * navigation actually happens. Repeaters complete out of order and rows appear
 * and disappear as settings are toggled, so any ordering captured at
 * registration time would be wrong by the time it mattered.
 */
Singleton {
    id: root

    // The PaneScroll currently on screen. Used to pull a focused row into view.
    property var scroller: null

    /*
     * Bumped once each time the Control Center finishes arriving.
     *
     * Every label on the surface is static, so there is no text change for the
     * scramble to trigger off. This counter is the trigger instead, and it
     * lives here rather than on the surface because the things that watch it -
     * the category strip, every setting label - are spread across three files
     * that already talk to this singleton and would otherwise each need a
     * property threaded down to them.
     */
    property int revealNonce: 0

    property var activeRow: null

    // The control inside the active row that the arrows are steering. Controls
    // bind their own `navFocused` against this rather than being told, so
    // nothing has to imperatively clear the previous one.
    property var focusedControl: null

    // True when focus arrived by keyboard. Hover shows the tip but must not
    // draw the key chips, or the mouse appears to have keyboard focus too.
    property bool keyboardMode: false

    /*
     * Last known cursor position, in the surface's coordinates.
     *
     * Arrowing down a pane with the cursor resting over it fought itself: the
     * keyboard moved the selection, the pane scrolled under a stationary
     * cursor, and the hover event that produced dragged the selection straight
     * back to whatever row had slid beneath the pointer.
     *
     * Watching for `entered` is not enough to tell those apart, and neither is
     * `positionChanged` on its own - when the content scrolls under a still
     * mouse the row beneath it changes, its local coordinates change with it,
     * and Qt reports a position change for a mouse that never moved. Only a
     * comparison against a window-level position distinguishes an actual
     * movement from the list sliding past. Same approach as the Launcher.
     */
    property real lastCursorX: -1
    property real lastCursorY: -1

    // Returns true only when the cursor has actually travelled.
    function cursorMoved(item, x, y) {
        const p = item.mapToItem(null, x, y);
        if (!p) return false;

        if (lastCursorX < 0 && lastCursorY < 0) {
            lastCursorX = p.x;
            lastCursorY = p.y;
            return false;               // first report after a key press
        }

        const dx = Math.abs(p.x - lastCursorX);
        const dy = Math.abs(p.y - lastCursorY);
        lastCursorX = p.x;
        lastCursorY = p.y;

        // A couple of pixels of slack absorbs sub-pixel jitter.
        return dx > 2 || dy > 2;
    }

    readonly property bool hasTip: activeRow !== null
    readonly property string tipTitle: activeRow ? activeRow.label : ""
    readonly property string tipBody: activeRow ? activeRow.description : ""
    readonly property string tipKind: activeRow ? activeRow.navKind() : ""

    property var _rows: []

    // --------------------------------------------------------------- registry

    function register(row) {
        if (_rows.indexOf(row) < 0) _rows.push(row);
    }

    function unregister(row) {
        const i = _rows.indexOf(row);
        if (i >= 0) _rows.splice(i, 1);
        if (activeRow === row) clearActive();
    }

    /*
     * Called by a PaneScroll once it and all its rows are built.
     *
     * Loader teardown and construction interleave: the incoming pane's rows can
     * register before the outgoing pane's rows have run their destruction
     * handlers, so a blanket clear on tab change would wipe the new rows. Every
     * row knows which pane owns it, so the incoming pane simply keeps its own
     * and drops everything else - which is correct whichever order the two
     * halves of the swap happened to run in.
     */
    function adopt(pane) {
        scroller = pane;
        _rows = _rows.filter(r => r && r.ownerPane === pane);
        clearActive();
    }

    function release(pane) {
        if (scroller === pane) {
            scroller = null;
            _rows = _rows.filter(r => r && r.ownerPane !== pane);
            clearActive();
        }
    }

    // ------------------------------------------------------------- navigation

    // Sorted top to bottom. Rows hidden by a conditional binding are skipped,
    // so arrowing past a collapsed row does not stop on nothing.
    function ordered() {
        return _rows
            .filter(r => r && r.visible && r.navigable && r.height > 0)
            .sort((a, b) => a.absoluteY() - b.absoluteY());
    }

    function clearActive() {
        activeRow = null;
        focusedControl = null;
    }

    function setActive(row, byKeyboard) {
        keyboardMode = byKeyboard === true;
        if (keyboardMode) {
            // Freeze the reference point. Any later report differing from this
            // is a genuine move and hands control back to the mouse.
            lastCursorX = -1;
            lastCursorY = -1;
        }
        activeRow = row;
        focusedControl = row ? row.navControl() : null;
        if (row && byKeyboard && scroller && scroller.revealItem)
            scroller.revealItem(row);
    }

    function step(delta) {
        const list = ordered();
        if (list.length === 0) return false;

        let i = list.indexOf(activeRow);
        // Coming in cold from either end rather than refusing to move.
        if (i < 0) i = delta > 0 ? -1 : list.length;

        const next = Math.max(0, Math.min(list.length - 1, i + delta));
        setActive(list[next], true);
        return true;
    }

    function focusEdge(last) {
        const list = ordered();
        if (list.length === 0) return false;
        setActive(list[last ? list.length - 1 : 0], true);
        return true;
    }

    function adjust(delta) {
        if (!activeRow) return false;
        keyboardMode = true;
        return activeRow.navStep(delta);
    }

    function activate() {
        if (!activeRow) return false;
        keyboardMode = true;
        return activeRow.navActivate();
    }

    // ------------------------------------------------------------------ hover
    //
    // The tip belongs to whatever the pointer is over, but dropping it the
    // instant the pointer crosses a row boundary makes the panel strobe on the
    // way down a list. A short grace period means only a real departure clears
    // it, and any row entered in the meantime simply takes over.

    Timer {
        id: hoverGrace
        interval: 140
        onTriggered: {
            if (!root.keyboardMode && root.activeRow === hoverGrace.leaving)
                root.clearActive();
        }
        property var leaving: null
    }

    // Entering counts only if the cursor got there under its own power, not
    // because the pane scrolled beneath it.
    function hoverEntered(row) {
        if (keyboardMode) return;
        hoverGrace.stop();
        setActive(row, false);
    }

    // Called on a confirmed cursor movement, which is what takes the surface
    // back off the keyboard.
    function pointerTook(row) {
        hoverGrace.stop();
        keyboardMode = false;
        activeRow = row;
        focusedControl = row ? row.navControl() : null;
    }

    function hoverLeft(row) {
        if (keyboardMode) return;
        hoverGrace.leaving = row;
        hoverGrace.restart();
    }
}
