import QtQuick
import qs.Common
import qs.Services

/*
 * A MouseArea that makes a noise.
 *
 * The shell's UI cues - "Navigation" on hover or focus, "Click" on activation -
 * have to reach roughly forty pointer areas spread across the bar, the dock,
 * quick settings, the launcher, the menus and every control in the Control
 * Center. Adding two handlers to each of those by hand would mean forty places
 * to get the condition wrong and forty places to revisit whenever the rule
 * changes.
 *
 * So the cue lives in the MouseArea itself and the call sites only change the
 * type they declare. Everything else about them - their handlers, their
 * accepted buttons, their anchors - stays exactly as it was.
 *
 * The handlers are wired through a Connections block rather than written as
 * `onEntered:` here, and that is the whole reason this works. A signal handler
 * declared in a base component is a property like any other: a use site that
 * writes its own `onEntered:` would replace this one, silently, and the sound
 * would go missing from precisely the areas that do the most. A Connections
 * object attaches a second, independent listener that no use site can shadow.
 */
MouseArea {
    id: area

    /*
     * Per-site opt-outs.
     *
     * Not every pointer area wants both cues. A scrim that exists to catch a
     * click outside a surface should not announce itself as the pointer crosses
     * the screen; a row that only tracks hover so something else can highlight
     * has nothing to click. Defaults are on, because the common case is a
     * control that wants both.
     */
    property bool navSound: true
    property bool clickSound: true

    Connections {
        target: area

        /*
         * Hover, via the property rather than the `entered` signal.
         *
         * containsMouse also goes false when the area is disabled or hidden
         * under the cursor, so this reports the state the user can actually
         * see. The guard on hoverEnabled keeps areas that never asked to track
         * hover from firing on the synthetic transition a press produces.
         */
        function onContainsMouseChanged() {
            if (!area.navSound) return;
            if (!area.hoverEnabled || !area.containsMouse) return;
            // A control inside a Control Center row is part of that row, and
            // the row has already said so. See CcNav.insideRow.
            if (CcNav.insideRow(area)) return;
            Sounds.playNavigation();
        }

        // Fires only for buttons the area accepts, so an area left on
        // Qt.NoButton to track hover alone stays silent on a click that passes
        // through it to whatever is underneath.
        function onClicked(mouse) {
            if (area.clickSound) Sounds.playClick();
        }
    }
}
