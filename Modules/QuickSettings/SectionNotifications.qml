import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.Config
import qs.Common
import qs.Services

/*
 * Notification history, grouped by application.
 *
 * Grouping is what keeps this readable: twenty messages from one chat are one
 * entry with a stack behind it, not twenty rows pushing the rest of the panel
 * off screen. Expanding a group reveals its messages individually.
 */
QsSection {
    id: root
    title: Settings.t("Notifications")
    accentRole: "text"

    subtitle: NotificationStore.empty
        ? "" : NotificationStore.count + (NotificationStore.count === 1 ? " message" : " messages")

    property var expandedApp: ""

    readonly property var shown: Settings.quickSettings.groupNotifications
        ? NotificationStore.groups.slice(0, Settings.quickSettings.notificationsShown)
        : NotificationStore.records.slice(0, Settings.quickSettings.notificationsShown)
            .map(r => ({ appName: r.appName, appIcon: r.appIcon,
                         latest: r, items: [r], time: r.time }))

    Column {
        width: parent.width
        spacing: Theme.space2

        CyberText {
            visible: NotificationStore.empty
            width: parent.width
            text: Settings.t("Nothing here")
            role: "micro"
            caps: false
            color: Theme.textMuted
        }

        Repeater {
            model: root.shown

            Column {
                id: groupCol
                required property var modelData

                readonly property bool multiple: modelData.items.length > 1
                readonly property bool expanded: root.expandedApp === modelData.appName

                width: parent.width
                spacing: 2

                // The stack tell: a second card peeking out behind the first.
                Item {
                    width: parent.width
                    height: card.height + (groupCol.multiple && !groupCol.expanded ? 4 : 0)

                    NotchRect {
                        visible: groupCol.multiple && !groupCol.expanded
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: card.height - 2
                        width: parent.width - 12
                        height: 6
                        fillColor: Theme.alpha(Theme.bgRaised, 0.9)
                        strokeColor: Theme.alpha(root.accentColor, 0.35)
                        notch: 4
                        notchTopLeft: false
                        notchTopRight: false
                        notchBottomRight: true
                        notchBottomLeft: false
                    }

                    Item {
                        id: card
                        width: parent.width

                        /*
                         * Height follows the content rather than being fixed.
                         *
                         * The body is capped at two lines and elided, so a long
                         * message cannot push the card open, and the app name
                         * and summary always keep their own line - they were
                         * being squeezed out by bodies that ran on.
                         */
                        height: cardBody.implicitHeight + Theme.space2 * 2

                        NotchRect {
                            id: body
                            anchors.fill: parent
                            fillColor: Theme.alpha(Theme.bgDeep, 0.85)
                            strokeColor: groupCol.modelData.latest.urgency === 2
                                ? Theme.danger : Theme.alpha(root.accentColor, 0.35)
                            notch: Theme.notchSmall
                            notchTopLeft: false
                            notchTopRight: false
                            notchBottomRight: true
                            notchBottomLeft: false
                        }

                        Column {
                            id: cardBody
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: Theme.space2
                            anchors.rightMargin: Theme.space2
                            spacing: 1

                            // --- app name, time, and the delete control
                            Item {
                                width: parent.width
                                height: 16

                                IconImage {
                                    id: appIcon
                                    visible: groupCol.modelData.appIcon !== ""
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    implicitSize: 14
                                    source: groupCol.modelData.appIcon
                                        ? Quickshell.iconPath(groupCol.modelData.appIcon, true) : ""
                                }

                                CyberText {
                                    anchors.left: appIcon.visible ? appIcon.right : parent.left
                                    anchors.leftMargin: appIcon.visible ? Theme.space1 : 0
                                    anchors.right: metaRow.left
                                    anchors.rightMargin: Theme.space2
                                    height: parent.height
                                    text: groupCol.modelData.appName
                                    role: "micro"
                                    color: root.accentColor
                                    elide: Text.ElideRight
                                }

                                Row {
                                    id: metaRow
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: Theme.space2

                                    CyberText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: NotificationStore.timeAgo(groupCol.modelData.time)
                                        role: "micro"
                                        color: Theme.textMuted
                                    }

                                    // How many more are stacked behind this one.
                                    NotchRect {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: groupCol.multiple
                                        width: 22
                                        height: 16
                                        fillColor: Theme.alpha(root.accentColor, 0.25)
                                        strokeColor: root.accentColor
                                        notch: 3

                                        CyberText {
                                            anchors.centerIn: parent
                                            text: String(groupCol.modelData.items.length)
                                            role: "micro"
                                            color: root.accentColor
                                        }
                                    }

                                    /*
                                     * Delete sits in the corner rather than
                                     * sliding out from behind the card. The
                                     * slide moved the whole card sideways on
                                     * hover, which made the list feel unstable
                                     * just from passing the cursor over it.
                                     */
                                    CyberText {
                                        id: deleteButton
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "\u2715"
                                        role: "micro"
                                        color: deleteMouse.containsMouse
                                            ? Theme.danger : Theme.alpha(Theme.danger, 0.55)

                                        Behavior on color {
                                            ColorAnimation { duration: Theme.durFast }
                                        }

                                        MouseArea {
                                            id: deleteMouse
                                            anchors.fill: parent
                                            anchors.margins: -5
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (groupCol.multiple && !groupCol.expanded)
                                                    NotificationStore.removeApp(
                                                        groupCol.modelData.appName);
                                                else
                                                    NotificationStore.remove(
                                                        groupCol.modelData.latest.key);
                                            }
                                        }
                                    }
                                }
                            }

                            // --- summary, always one line
                            CyberText {
                                width: parent.width
                                text: groupCol.modelData.latest.summary
                                role: "label"
                                color: Theme.text
                                elide: Text.ElideRight
                            }

                            // --- body, capped at two lines
                            CyberText {
                                width: parent.width
                                visible: groupCol.modelData.latest.body !== ""
                                text: groupCol.modelData.latest.body
                                role: "micro"
                                caps: false
                                color: Theme.textDim
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            id: cardMouse
                            anchors.fill: parent
                            anchors.rightMargin: 40      // clear of the delete control
                            hoverEnabled: true
                            cursorShape: groupCol.multiple ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: {
                                if (!groupCol.multiple) return;
                                root.expandedApp = groupCol.expanded
                                    ? "" : groupCol.modelData.appName;
                            }
                        }
                    }
                }

                // Expanded members of the group, minus the one already shown.
                Repeater {
                    model: groupCol.expanded ? groupCol.modelData.items.slice(1) : []

                    Item {
                        required property var modelData
                        width: groupCol.width - Theme.space4
                        height: 40
                        x: Theme.space4

                        NotchRect {
                            anchors.fill: parent
                            fillColor: Theme.alpha(Theme.bgDeep, 0.7)
                            strokeColor: Theme.alpha(Theme.border, 0.9)
                            notch: 5
                            notchTopLeft: false
                            notchTopRight: false
                            notchBottomRight: true
                            notchBottomLeft: false
                        }

                        Column {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.space2
                            anchors.right: dropOne.left
                            anchors.rightMargin: Theme.space2
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: -2

                            CyberText {
                                width: parent.width
                                text: modelData.summary
                                role: "micro"
                                color: Theme.text
                                elide: Text.ElideRight
                            }
                            CyberText {
                                width: parent.width
                                visible: modelData.body !== ""
                                text: modelData.body
                                role: "micro"
                                caps: false
                                color: Theme.textMuted
                                elide: Text.ElideRight
                            }
                        }

                        CyberText {
                            id: dropOne
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.space2
                            anchors.verticalCenter: parent.verticalCenter
                            text: "\u2715"
                            role: "micro"
                            color: oneMouse.containsMouse ? Theme.danger : Theme.textMuted

                            MouseArea {
                                id: oneMouse
                                anchors.fill: parent
                                anchors.margins: -6
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: NotificationStore.remove(modelData.key)
                            }
                        }
                    }
                }
            }
        }

        Row {
            width: parent.width
            spacing: Theme.space2
            visible: !NotificationStore.empty

            CyberText {
                anchors.verticalCenter: parent.verticalCenter
                visible: NotificationStore.groups.length > Settings.quickSettings.notificationsShown
                width: parent.width - clearAll.width - Theme.space2
                text: `${NotificationStore.groups.length - Settings.quickSettings.notificationsShown} more hidden`
                role: "micro"
                caps: false
                color: Theme.textMuted
            }

            CyberButton {
                id: clearAll
                anchors.verticalCenter: parent.verticalCenter
                text: Settings.t("Clear all")
                destructive: true
                hPadding: Theme.space3
                onClicked: NotificationStore.clear()
            }
        }
    }
}
