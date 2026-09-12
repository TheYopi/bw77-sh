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

                /*
                 * --- the rows outlive the fold
                 *
                 * The member rows used to be a Repeater over
                 * `expanded ? items.slice(1) : []`, which meant collapsing a
                 * group destroyed every row on the frame the model emptied.
                 * There was nothing left on screen to fold, so the group could
                 * only ever snap shut - and the panel below it snapped up with
                 * it.
                 *
                 * The model is filled on the way open and emptied only once the
                 * fold has finished, so the rows are still there to be rolled
                 * over by the clip. It is the same reason SurfaceHolder keeps a
                 * closing surface alive: you cannot animate something you have
                 * already deleted.
                 */
                property var memberRows: []

                function fillRows() {
                    groupCol.memberRows = groupCol.modelData.items.slice(1);
                }

                /*
                 * --- and the fold does not replay itself
                 *
                 * A new message rebuilds every group delegate in the section,
                 * because the model is a fresh array each time. A group that
                 * was open is rebuilt open, and its rows are filled a moment
                 * after construction rather than during it - which is late
                 * enough for the height Behavior to treat it as a fold and roll
                 * the whole list open again. With Telegram replacing its
                 * notification every few seconds, an expanded group would spend
                 * its life unrolling.
                 *
                 * So the fold is armed one event loop pass after the delegate
                 * exists: the first sizing is instant, every one after it is a
                 * fold the reader actually asked for.
                 */
                property bool foldArmed: false

                Component.onCompleted: {
                    if (groupCol.expanded) groupCol.fillRows();
                    Qt.callLater(() => groupCol.foldArmed = true);
                }

                /*
                 * --- deleting
                 *
                 * Removing a record rewrites the store, which rebuilds every
                 * delegate in the section, which destroys this one. So the tear
                 * has to run first and the removal has to be what it ends with -
                 * the same order as everything else that leaves in this shell.
                 *
                 * Only when the card is actually going. Deleting the newest
                 * message of an expanded group leaves the group standing with
                 * one fewer message in it, and the card restates itself rather
                 * than departing; tearing it out and letting the next message
                 * pop into the hole would read as a glitch in the other sense.
                 */
                property bool removing: false

                readonly property bool deleteTakesCard:
                    !(groupCol.expanded && groupCol.multiple)

                clip: groupCol.removing

                function requestDelete() {
                    if (!groupCol.deleteTakesCard) {
                        NotificationStore.remove(groupCol.modelData.latest.key);
                        return;
                    }
                    if (groupCol.removing) return;
                    groupCol.removing = true;
                    groupTear.start();
                }

                GlitchAway {
                    id: groupTear
                    item: groupCol
                    hostSpacing: Theme.space2
                    onCompleted: {
                        // Collapsed with more behind it, the delete took the
                        // whole stack; otherwise there was only ever this one.
                        if (groupCol.multiple)
                            NotificationStore.removeApp(groupCol.modelData.appName);
                        else
                            NotificationStore.remove(groupCol.modelData.latest.key);
                    }
                }

                // A row on its way out shrinks the column the fold is sized
                // from. Letting the fold ease after it as well would leave the
                // rows below chasing a moving target through two animations.
                property bool rowTearing: false

                onExpandedChanged: {
                    if (groupCol.expanded) groupCol.fillRows();
                    else dropRows.restart();
                }

                Timer {
                    id: dropRows
                    interval: Theme.durationFor("quickSettings")
                    repeat: false
                    // Re-opened while it was closing: the rows are wanted after
                    // all, and this drain is stale.
                    onTriggered: if (!groupCol.expanded) groupCol.memberRows = [];
                }

                // The stack tell: a second card peeking out behind the first.
                Item {
                    width: parent.width
                    height: card.height + (groupCol.multiple && !groupCol.expanded ? 4 : 0)

                    // The 4px the peeking card sits in goes back to the layout
                    // over the same span the card itself fades out.
                    Behavior on height {
                        enabled: !Theme.reducedMotion && Settings.animations.surfaceOpen
                        NumberAnimation {
                            duration: Theme.durationFor("quickSettings")
                            easing.type: Theme.curveFor("quickSettings")
                        }
                    }

                    NotchRect {
                        opacity: groupCol.multiple && !groupCol.expanded ? 1 : 0
                        visible: opacity > 0.01
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

                        Behavior on opacity {
                            enabled: !Theme.reducedMotion && Settings.animations.surfaceOpen
                            NumberAnimation { duration: Theme.durationFor("quickSettings") }
                        }
                    }

                    Item {
                        id: card
                        width: parent.width

                        // Nothing draws outside the frame, whatever arrives.
                        // The cap on the body is the thing that is supposed to
                        // hold, and it now does - but a card that spills its
                        // contents over the rest of the panel is a bad enough
                        // failure to be worth making structurally impossible.
                        clip: true

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
                                            onClicked: groupCol.requestDelete()
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
                //
                // Explicit height on the container, clipped, so the rows are
                // revealed by the frame growing down over them rather than by
                // arriving all at once. `visible` follows the height so a shut
                // group leaves no gap behind in the Column above it.
                Item {
                    id: memberFold
                    width: parent.width

                    // Shut is minus one of the group's spacings, so the gap
                    // the Column reserves for this slot closes at the same rate
                    // as the fold instead of vanishing on the frame after it.
                    // QsSubmenu explains it at length.
                    readonly property real shutHeight: -groupCol.spacing
                    readonly property bool drawable: height > 0

                    height: groupCol.expanded ? memberColumn.implicitHeight
                                              : shutHeight

                    // Only mid-fold; see PaneGroup for the same reasoning.
                    clip: height < memberColumn.implicitHeight
                    visible: height > shutHeight + 0.01

                    // Ease-in-out on the way shut, category curve on the way
                    // open, for the reason QsSubmenu explains at length.
                    Behavior on height {
                        enabled: groupCol.foldArmed && !groupCol.rowTearing
                            && !Theme.reducedMotion && Settings.animations.surfaceOpen
                        NumberAnimation {
                            duration: Theme.durationFor("quickSettings")
                            easing.type: groupCol.expanded
                                ? Theme.curveFor("quickSettings") : Easing.InOutCubic
                        }
                    }

                    Column {
                        id: memberColumn
                        width: parent.width
                        spacing: 2

                        // Deliberately no `visible`: the fold above it is
                        // hidden when shut, and a Column that hides itself
                        // cannot report a height for the fold to open to. See
                        // PaneGroup, where that cost every collapsed group on
                        // every settings pane the ability to open at all.

                        Repeater {
                            model: groupCol.memberRows

                            Item {
                                id: memberRow
                                required property var modelData
                                width: groupCol.width - Theme.space4
                                height: 40
                                x: Theme.space4
                                clip: true

                                // Same tear-out as the card above it, for the
                                // same reason: the removal is what the animation
                                // ends with, not what replaces it.
                                property bool removing: false

                                function requestDelete() {
                                    if (memberRow.removing) return;
                                    memberRow.removing = true;
                                    groupCol.rowTearing = true;
                                    rowTear.start();
                                }

                                GlitchAway {
                                    id: rowTear
                                    item: memberRow
                                    hostSpacing: memberColumn.spacing
                                    onCompleted:
                                        NotificationStore.remove(memberRow.modelData.key)
                                }

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
                                        // One line here, in a row of fixed height. A
                                        // stored body keeps its newlines for the cards
                                        // that show two lines of it, and Text.NoWrap
                                        // only turns off AUTOMATIC wrapping - an
                                        // explicit newline still breaks the line and
                                        // would push this row past the 40px it is
                                        // given.
                                        text: NotificationStore.collapse(modelData.body)
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

                                    Behavior on color { ColorAnimation { duration: Theme.durFast } }

                                    MouseArea {
                                        id: oneMouse
                                        anchors.fill: parent
                                        anchors.margins: -6
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: memberRow.requestDelete()
                                    }
                                }
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
