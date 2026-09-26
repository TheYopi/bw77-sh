import QtQuick
import qs.Config

/*
 * Notification history, hung off the bar's bell.
 *
 * This is the quick settings section, mounted in a popup rather than
 * reimplemented in one. The grouping, the stack tell, the expansion, the
 * per-message delete and the tear-out that goes with it all took work to get
 * right, and a second copy of them would be a second set of the same bugs -
 * the same reason SectionMedia mounts the desktop widget's MediaBody instead of
 * drawing its own player.
 *
 * It also means the two agree by construction. A message cleared here is gone
 * from the panel too, because there is one store and one section reading it.
 *
 * --- loaded by path, not imported as a type
 *
 * qs.Modules.QuickSettings already imports qs.Modules.Popups - SectionCalendar
 * mounts CalendarPopup - so importing the module here would close a loop
 * between the two directories. The quick settings panel mounts these same
 * sections by relative URL for its own reasons, and doing it that way here
 * needs no import at all, so there is no loop to reason about.
 */
Item {
    id: root

    // Wider than the panel's fixed column, which is what a free-floating card
    // can afford: the summaries and bodies get a good deal more room before
    // they elide.
    implicitWidth: 400

    /*
     * Ceiling handed down by the popup surface, which is the only thing that
     * knows how much screen is left below the bar. Zero means "not told", in
     * which case the content is free to be whatever height it likes - that is
     * the old behaviour, kept so this stays usable if it is ever mounted
     * somewhere that does not offer a budget.
     */
    property real maxHeight: 0

    readonly property real naturalHeight: section.item ? section.item.implicitHeight : 120

    implicitHeight: root.maxHeight > 0
        ? Math.min(root.naturalHeight, root.maxHeight)
        : root.naturalHeight

    /*
     * --- scrolling, the same way the quick settings panel does it
     *
     * Expanding a group is what makes this overflow: the history is short
     * until you open a stack of twenty messages, and then it is taller than
     * the screen. The panel has always had a Flickable around the identical
     * section, so the popup was the one place where the same content could
     * grow past the edge with no way to reach the bottom of it.
     *
     * StopAtBounds rather than the default: this is a small card anchored
     * under a bar widget, and a rubber-band overshoot inside it reads as the
     * card coming loose.
     */
    Flickable {
        id: scroll
        anchors.fill: parent
        contentWidth: width
        contentHeight: section.item ? section.item.implicitHeight : 0
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        // Only takes the wheel when there is something to scroll to, so a
        // history that fits still passes the wheel through untouched.
        interactive: scroll.contentHeight > scroll.height

        Loader {
            id: section
            width: scroll.width
            source: "../QuickSettings/SectionNotifications.qml"

            onLoaded: {
                if (item.accentRole !== undefined) item.accentRole = "accent";
            }
        }
    }

    // Matching the quick settings panel's and the Control Center's.
    Rectangle {
        anchors.right: parent.right
        anchors.rightMargin: -2
        y: scroll.contentHeight > 0
            ? scroll.visibleArea.yPosition * scroll.height : 0
        width: 3
        height: Math.max(24, scroll.visibleArea.heightRatio * scroll.height)
        color: Theme.alpha(Theme.danger, 0.8)
        visible: scroll.contentHeight > scroll.height
    }
}
