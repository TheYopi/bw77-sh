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
            // nf-cod-bell
            text: "\ueaa2"
            role: "icon"
            sizeOverride: root.cfgIconSize
            color: root.cfgColor(root.accentColor)
        }

        /*
         * The count, in its own frame when there is one.
         *
         * A bare number next to the bell read as part of the clock two widgets
         * along. Boxed, it reads as a badge belonging to the bell - and the box
         * disappears entirely at zero rather than sitting there saying nothing,
         * which is what the bell on its own is already for.
         */
        NotchRect {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.count > 0
            width: visible ? Math.max(18, badge.implicitWidth + Theme.space2) : 0
            height: 16
            fillColor: Theme.alpha(Theme.accent, 0.22)
            strokeColor: Theme.alpha(Theme.accent, 0.8)
            notch: 4
            notchTopLeft: false
            notchTopRight: false
            notchBottomRight: true
            notchBottomLeft: false

            Behavior on width {
                enabled: !Theme.reducedMotion
                NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutQuad }
            }

            CyberText {
                id: badge
                anchors.centerIn: parent
                // Past ninety-nine the exact figure has stopped being useful and
                // the widget would start pushing its neighbours around.
                text: root.count > 99 ? "99+" : String(root.count)
                role: "micro"
                sizeOverride: root.cfgFontSize
                weightOverride: root.cfgFontWeight
                color: root.cfgColor(Theme.accent)
            }
        }
    }
}
