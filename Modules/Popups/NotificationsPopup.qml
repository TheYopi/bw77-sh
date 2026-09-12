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
    implicitHeight: section.item ? section.item.implicitHeight : 120

    Loader {
        id: section
        width: parent.width
        source: "../QuickSettings/SectionNotifications.qml"

        onLoaded: {
            if (item.accentRole !== undefined) item.accentRole = "accent";
        }
    }
}
