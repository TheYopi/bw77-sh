import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Notifications
import qs.Config
import qs.Common
import qs.Services

/*
 * Notification server plus the on-screen stack.
 *
 * Urgency drives colour and dismissal: critical toasts are crimson and never
 * time out, everything else fades on its own.
 */
Scope {
    id: scope

    property var visibleList: []

    /*
     * --- why the list is never written directly
     *
     * `Repeater.model` binds to visibleList, so assigning it runs
     * QQuickRepeater::regenerate() synchronously: every delegate is destroyed
     * and a new set is incubated, right there on the current stack. Doing that
     * from inside the notification server's D-Bus callback means the delegates
     * are torn down while Qt is still part-way through delivering the signal
     * that caused it, and with a pointer grab live on one of the action buttons
     * it segfaults inside QQmlModels during incubation.
     *
     * Telegram makes it easy to hit: it replaces its notifications rather than
     * posting new ones, so the handler fires repeatedly while a toast is on
     * screen and under the mouse.
     *
     * So changes are queued and applied from a zero-interval timer instead,
     * which lands on a clean stack in the next event loop pass. Coalescing is
     * a bonus rather than the point: three notifications arriving together now
     * regenerate the Repeater once instead of three times.
     */
    property var pendingList: null

    // Whatever the list will be once the queue drains. Reading this rather than
    // visibleList is what lets two changes in one pass compose instead of the
    // second discarding the first.
    function currentList() {
        const list = scope.pendingList !== null ? scope.pendingList : scope.visibleList;
        // Belt and braces against a handle that went away without telling us.
        return list.filter(n => n);
    }

    function scheduleList(next) {
        scope.pendingList = next;
        listFlush.restart();
    }

    /*
     * --- a notification the sender takes back
     *
     * `visibleList` holds live Notification handles, and a handle is a C++
     * object owned by the server: when the sending application withdraws the
     * notification - CloseNotification, or a replacement of an earlier id - the
     * server destroys it. The array is a plain JS list of raw pointers and is
     * not told, so it goes on holding an address that no longer belongs to
     * anything, and the next time the Repeater regenerates it hands that to
     * QQmlDelegateModel and the shell dies inside incubation.
     *
     * That is the crash, and it is why the delegate was seen reading properties
     * off a null notification in the log just before it went: some of the dead
     * handles JS had wrapped came back as null, and the ones it had not came
     * back as a dangling pointer.
     *
     * So every tracked notification is dropped from the list the moment it says
     * it is closing. The handle is still alive while its own signal is being
     * delivered, which is what makes filtering by identity safe here - it is
     * the last moment it ever will be.
     */
    function forget(notif) {
        scope.scheduleList(scope.currentList().filter(n => n !== notif));
        delete scope.toastMeta[notif.id];
    }

    Timer {
        id: listFlush
        interval: 0
        repeat: false
        onTriggered: {
            if (scope.pendingList === null) return;
            const next = scope.pendingList;
            // Cleared before the assignment, not after: the write regenerates
            // the Repeater synchronously, and anything that queues a further
            // change during that must not be dropped by this same drain.
            scope.pendingList = null;
            scope.visibleList = next.filter(n => n);
        }
    }

    /*
     * --- per-notification state that has to outlive the delegate
     *
     * A Repeater given a plain JS array rebuilds every delegate whenever the
     * array is reassigned. That is the whole bug: pushing a second toast
     * destroyed and recreated the first, which restarted its countdown from
     * zero, and removing an expired toast did the same to every survivor - so
     * they replayed their entry animation instead of moving up into the gap,
     * and their timers reset again.
     *
     * The countdown therefore cannot live in the delegate. It is a deadline
     * kept here, keyed by notification id, so a rebuilt toast picks the same
     * clock back up where it left off. `lastY` is kept the same way, so a
     * rebuilt toast knows where it used to be and can slide from there rather
     * than appearing in its new slot.
     *
     * Properties cannot be attached to the Notification object itself - it is a
     * C++ QObject and JS cannot add to it - hence the side table.
     */
    property var toastMeta: ({})

    function metaFor(id) {
        if (scope.toastMeta[id] === undefined) scope.toastMeta[id] = ({});
        return scope.toastMeta[id];
    }

    function dismiss(id) {
        const handle = scope.currentList().find(n => n.id === id);
        scheduleList(scope.currentList().filter(n => n.id !== id));
        // Dropped once the toast is gone, or the table grows for the life of
        // the session and a reused id would inherit a stale deadline.
        delete scope.toastMeta[id];

        /*
         * And hand the handle back.
         *
         * Dropping it from the list only takes the toast off the screen. The
         * notification was marked tracked, so without this the server keeps it
         * alive for the rest of the session and the application that sent it is
         * never told the message was read. Closing it here fires `closed`,
         * which runs forget() - harmlessly, the list no longer holds it.
         */
        if (handle) handle.dismiss();
    }

    NotificationServer {
        id: server
        keepOnReload: false
        actionsSupported: true
        bodyMarkupSupported: true
        imageSupported: true
        inlineReplySupported: true

        onNotification: (notif) => {
            if (Settings.notifications.doNotDisturb
                && notif.urgency !== NotificationUrgency.Critical) {
                NotificationStore.add(notif);
                notif.dismiss();
                return;
            }

            notif.tracked = true;

            // Before it is put in the list, so a notification withdrawn in the
            // same pass it arrived still unhooks itself.
            notif.closed.connect(() => scope.forget(notif));

            // Recorded before display, so a notification that arrives while
            // do-not-disturb is on still lands in history.
            NotificationStore.add(notif);
            const list = scope.currentList().slice();
            list.unshift(notif);
            scope.scheduleList(list.slice(0, Settings.notifications.maxVisible));

            Sounds.playNotification(notif.urgency === NotificationUrgency.Critical);
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "bw77-notifications"

            readonly property string pos: Settings.notifications.position
            readonly property bool onTop: pos.indexOf("top") !== -1
            readonly property bool onRight: pos.indexOf("right") !== -1
            readonly property bool onCenter: pos.indexOf("center") !== -1

            // Overlay layers ignore the bar's exclusion zone, so the offset has
            // to be applied by hand or toasts sit on top of the bar.
            readonly property int barOffset: {
                if (!Settings.notifications.avoidBar) return 0;
                if (!Settings.bar.exclusive) return 0;
                const barAtTop = Settings.bar.position === "top";
                if (win.onTop && barAtTop) return Settings.bar.height;
                if (!win.onTop && !barAtTop) return Settings.bar.height;
                return 0;
            }

            readonly property int edge: Settings.notifications.edgeMargin

            anchors {
                top: win.onTop
                bottom: !win.onTop
                left: !win.onRight || win.onCenter
                right: win.onRight || win.onCenter
            }

            margins {
                top: win.edge + (win.onTop ? win.barOffset : 0)
                bottom: win.edge + (win.onTop ? 0 : win.barOffset)
                left: win.onCenter ? 0 : win.edge
                right: win.onCenter ? 0 : win.edge
            }

            // Centre anchors both sides, so the window spans the screen and the
            // stack is centred inside it instead of the window being centred.
            implicitWidth: win.onCenter
                ? 0
                : Settings.notifications.width + win.edge * 2
            implicitHeight: Math.max(1, stack.implicitHeight + win.edge * 2)
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            visible: scope.visibleList.length > 0

            mask: Region { item: stack }

            // Two Columns rather than one with conditional anchors: assigning
            // undefined to an anchor does not clear it, so flipping top/bottom
            // would leave the stack stretched between both edges.
            Column {
                id: stack
                anchors.horizontalCenter: parent.horizontalCenter
                // Plain y rather than conditional anchors, for the same reason
                // as the bar rule: an anchor set to undefined is not cleared.
                y: win.onTop ? 0 : parent.height - height
                spacing: Theme.space2

                Repeater {
                    model: scope.visibleList
                    NotificationToast {
                        required property var modelData
                        notif: modelData
                        meta: modelData ? scope.metaFor(modelData.id) : ({})
                        // Removal happens only after the tear-out has run; the
                        // toast owns its own exit timing.
                        onDismissed: if (modelData) scope.dismiss(modelData.id)
                    }
                }
            }
        }
    }
}
