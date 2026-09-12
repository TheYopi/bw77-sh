import QtQuick
import qs.Config

/*
 * The tear-out, for an item leaving a list.
 *
 * GlitchBox does this for a whole surface, but it does it by wrapping one - it
 * owns the item it animates, and the thing being removed here is a delegate
 * inside a Column that something else already owns. This drives an existing
 * item instead, which is the only difference between the two.
 *
 * The motion is the same signature: a sideways kick, out and then further out
 * the other way, under a fade. Per GlitchBox's own note, the kick IS the glitch
 * - every other direction in this shell travels in a straight line - so a row
 * that leaves this way reads as belonging to the same interface as a panel that
 * arrives that way.
 *
 * `collapse` takes the space back at the same time, so the rows below close the
 * gap as the row goes rather than snapping up after it. It writes `height`
 * directly, which breaks whatever binding was sizing the item - that is safe
 * here and nowhere else: this animation runs once, on something that is about
 * to be destroyed.
 *
 * Emits `completed` when it is safe to remove the item for real. The caller
 * does the removing; this only makes the leaving look like something.
 */
SequentialAnimation {
    id: root

    // The item to throw out. Its x and opacity are written directly, so it
    // wants to be something whose x is its own - a Column child qualifies,
    // since a Column places its children by y and leaves x alone.
    property Item item: null

    property bool collapse: true
    property int duration: Theme.durationFor("notifications")

    /*
     * What the collapse ends on, which is not zero.
     *
     * Removing the item does not only take its height away from the list; it
     * takes the one `spacing` the Column was reserving for its slot, and that
     * part goes in a single frame on the far side of this animation. The rows
     * below therefore stepped up by that much just after the tear finished -
     * the removal reading as a snap that the animation had failed to cover.
     *
     * Ending on minus the host Column's spacing folds that gap away at the same
     * rate as the rest of the height, because a Column places the next child at
     * `y + height + spacing`. On the frame the item is finally removed it is
     * contributing -spacing + spacing, which is exactly the nothing it becomes.
     * QsSubmenu carries the long version of this argument.
     *
     * Callers pass their Column's spacing. Zero is the old behaviour and is
     * right for anything that is not in a spaced Column.
     */
    property real hostSpacing: 0

    signal completed()

    // Where it started, so the kick is relative to wherever the layout put it
    // rather than to zero. Read once, on the frame the tear begins.
    property real homeX: 0
    ScriptAction { script: root.homeX = root.item ? root.item.x : 0 }

    ParallelAnimation {
        SequentialAnimation {
            NumberAnimation {
                target: root.item; property: "x"
                to: root.homeX + 7
                duration: Math.max(1, root.duration * 0.3)
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: root.item; property: "x"
                to: root.homeX - 16
                duration: Math.max(1, root.duration * 0.7)
                easing.type: Easing.OutCubic
            }
        }

        NumberAnimation {
            target: root.item; property: "opacity"
            to: 0
            duration: root.duration
            easing.type: Easing.OutCubic
        }

        // Held back for the first third: the row should be visibly leaving
        // before the list starts closing over it, or the collapse reads as the
        // cause and the fade as an afterthought.
        SequentialAnimation {
            PauseAnimation { duration: Math.max(1, root.duration * 0.3) }
            NumberAnimation {
                target: root.collapse ? root.item : null
                property: "height"
                to: -root.hostSpacing
                duration: Math.max(1, root.duration * 0.7)
                easing.type: Easing.OutCubic
            }
        }
    }

    ScriptAction { script: root.completed() }
}
