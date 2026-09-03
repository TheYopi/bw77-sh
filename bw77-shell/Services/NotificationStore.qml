pragma Singleton

import QtQuick
import Quickshell
import qs.Config

/*
 * Notification history.
 *
 * The server itself stays in the shell tree (see Modules/Notifications), since
 * a NotificationServer inside a singleton is not reliably registered. This is
 * only the store: the layer pushes records in, and the quick settings panel
 * reads them out.
 *
 * Records are plain objects rather than live Notification handles - a handle is
 * invalid once the sender withdraws it, and history has to outlive that.
 */
Singleton {
    id: root

    property int limit: 100
    property var records: []

    readonly property int count: records.length
    readonly property bool empty: records.length === 0

    function add(notif) {
        const record = {
            key: String(notif.id) + ":" + Date.now(),
            appName: notif.appName && notif.appName !== "" ? notif.appName : "System",
            appIcon: notif.appIcon || "",
            summary: notif.summary || "",
            body: notif.body || "",
            urgency: notif.urgency,
            time: Date.now()
        };

        const next = [record].concat(records);
        records = next.slice(0, limit);
    }

    function remove(key) {
        records = records.filter(r => r.key !== key);
    }

    function removeApp(appName) {
        records = records.filter(r => r.appName !== appName);
    }

    function clear() {
        records = [];
    }

    /*
     * History grouped by application, newest group first.
     *
     * Grouping is what keeps the list readable: twenty messages from one chat
     * are one entry with a count, not twenty rows pushing everything else off
     * the panel.
     */
    readonly property var groups: {
        const order = [];
        const byApp = {};

        for (let i = 0; i < records.length; i++) {
            const r = records[i];
            if (!byApp[r.appName]) {
                byApp[r.appName] = {
                    appName: r.appName,
                    appIcon: r.appIcon,
                    latest: r,
                    items: [],
                    time: r.time
                };
                order.push(r.appName);
            }
            byApp[r.appName].items.push(r);
            // The group carries the newest icon it has seen, since early
            // notifications from an app sometimes arrive without one.
            if (!byApp[r.appName].appIcon && r.appIcon)
                byApp[r.appName].appIcon = r.appIcon;
        }

        return order.map(name => byApp[name]);
    }

    function timeAgo(ms) {
        const secs = Math.max(0, Math.round((Date.now() - ms) / 1000));
        if (secs < 60) return "now";
        const mins = Math.round(secs / 60);
        if (mins < 60) return mins + "m";
        const hours = Math.round(mins / 60);
        if (hours < 24) return hours + "h";
        return Math.round(hours / 24) + "d";
    }
}
