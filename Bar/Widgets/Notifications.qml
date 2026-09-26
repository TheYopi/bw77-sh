import QtQuick
import qs.Config
import qs.Common
import qs.Services

/*
 * Notification history on the bar: a bell, and how much is behind it.
 *
 * The count is the whole point of the widget - the history was already in the
 * quick settings panel, but reaching it meant opening a panel to find out
 * whether there was anything to read. A number on the bar answers that without
 * being asked, and the popup underneath is the same list the panel draws.
 *
 * Counts records rather than groups: twenty messages from one chat is twenty
 * things you have not read, and a "1" over a stack of twenty would be telling
 * you the wrong thing. The popup does the grouping, which is where grouping
 * helps.
 */
BarItem {
    id: root

    readonly property int count: NotificationStore.count

    // Zero is not an emergency, so the bell goes quiet rather than shouting in
    // the accent colour at an empty history.
    accentColor: root.count > 0 ? Theme.accent : Theme.textDim

    tooltip: root.count === 0
        ? Settings.t("No notifications")
        : root.count + (root.count === 1 ? " notification" : " notifications")

    active: Popups.current === "notifications"

    onClicked: (m) => {
        // Middle click clears, which is the one destructive thing this widget
        // can do and the one that is tedious through the popup.
        if (m.button === Qt.MiddleButton) NotificationStore.clear();
        else Popups.openAt("notifications", root, screenRef);
    }

    Row {
        spacing: Theme.space2
        height: parent.height

        CyberText {
            height: parent.height
            // nf-fa-bell
            text: "\uf0f3"
            role: "icon"
            sizeOverride: root.cfgIconSize
            color: root.cfgColor(root.accentColor)
        }

        /*
         * The count, beside the bell rather than boxed.
         *
         * It used to sit in its own NotchRect - a frame inside the widget's
         * own frame, which is two borders deep for one number and reads as a
         * separate thing parked next to the bell instead of as the bell's
         * count. The original worry was that a bare number would be mistaken
         * for part of the clock two widgets along; the widget's own outline
         * and the tight spacing against the glyph already answer that, and the
         * badge was solving it twice.
         *
         * It still disappears entirely at zero: the quiet bell is what says
         * "nothing here", and a "0" beside it would be repeating that with an
         * extra character of bar width.
         */
        CyberText {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.count > 0
            // Past ninety-nine the exact figure has stopped being useful and
            // the widget would start pushing its neighbours around.
            text: root.count > 99 ? "99+" : String(root.count)
            role: "micro"
            sizeOverride: root.cfgFontSize
            weightOverride: root.cfgFontWeight
            color: root.cfgColor(root.accentColor)
        }
    }
}
