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

    /*
     * --- markup in, plain text out
     *
     * The freedesktop notification spec lets an application put a small subset
     * of HTML in a body: <b>, <i>, <u>, <a href> and <img>. The shell draws
     * everything as plain text (see Common/CyberText), so that markup has to
     * come off here rather than being handed to a Text item to puzzle over -
     * otherwise a bold sender name reads as a literal "<b>" in the panel.
     *
     * This used to be left to Qt, which sniffed each string and switched to the
     * rich text engine when it saw a tag. That is what caused the overflow:
     * eliding does not work in rich text, so the two-line cap on a notification
     * body quietly stopped applying and a long message drew itself over the
     * rest of the panel at full height.
     *
     * Order matters. Tags are stripped first and entities decoded second, so a
     * sender who escaped their own angle brackets - "&lt;b&gt;" for a literal
     * "<b>" - gets them back as text rather than having them stripped as
     * markup on a second pass.
     */
    function plainText(src) {
        if (!src) return "";
        let out = String(src);

        // <br> is not in the spec but is sent widely enough to be worth
        // honouring, and a line break carries meaning the tag soup does not.
        out = out.replace(/<br\s*\/?>/gi, "\n");

        // An image is not drawable here, but its alt text is what the sender
        // wanted read out when it was not.
        out = out.replace(/<img\b[^>]*\balt=["']([^"']*)["'][^>]*>/gi, "$1");

        /*
         * Everything else is a wrapper around text worth keeping - the link
         * text, the bolded name - so the tags go and their contents stay.
         *
         * Named explicitly rather than matched by shape. Anything tag-SHAPED is
         * far too greedy for text people actually send: /<[^>]+>/ turns
         * "5 < 7 and 9 > 3" into "5  3", and even insisting on a letter after
         * the "<" still eats the middle of "if x<y then y>x". Both are ordinary
         * sentences, and comparisons and emoticons appear in messages a great
         * deal more often than markup does.
         *
         * The list is the five tags the notification spec allows, plus the
         * Pango set that GTK applications send instead - they are writing for
         * the notification daemons that pass the body to Pango, and there are
         * enough of them that dropping the tags is worth doing.
         */
        out = out.replace(
            /<\/?(?:b|i|u|s|a|em|tt|big|sub|sup|pre|img|code|span|small|strong)\b[^<>]*>/gi,
            "");

        out = out.replace(/&lt;/g, "<")
                 .replace(/&gt;/g, ">")
                 .replace(/&quot;/g, "\"")
                 .replace(/&apos;/g, "'")
                 // Ampersand last, or "&amp;lt;" decodes twice and turns a
                 // literal "&lt;" the sender escaped into a "<".
                 .replace(/&amp;/g, "&");

        return out;
    }

    /*
     * A summary is a title and gets one line wherever it is drawn.
     *
     * Explicit newlines survive Text.NoWrap - it only turns off AUTOMATIC
     * wrapping - so a summary carrying one pushes every row below it down and
     * out of a card sized for a single line. Collapsing whitespace here fixes
     * that everywhere at once, rather than each of the four places that draw a
     * summary having to remember a line cap.
     */
    function oneLine(src) {
        return root.collapse(root.plainText(src));
    }

    /*
     * Whitespace only, and safe to run on text that has already been through
     * plainText - which oneLine is NOT.
     *
     * plainText decodes entities, so running it twice takes a body that
     * legitimately reads "use <b> for bold" - because the sender escaped it as
     * "&lt;b&gt;" and the first pass gave the brackets back - and strips the
     * <b> as though it were markup on the second. Anywhere a stored record
     * needs flattening to one line, this is the function to reach for.
     */
    function collapse(text) {
        if (!text) return "";
        return String(text).replace(/\s+/g, " ").trim();
    }

    function add(notif) {
        const record = {
            key: String(notif.id) + ":" + Date.now(),
            appName: root.oneLine(notif.appName) !== "" ? root.oneLine(notif.appName) : "System",
            appIcon: notif.appIcon || "",
            summary: root.oneLine(notif.summary),
            // Newlines are kept: a body is genuinely multi-line and the surfaces
            // that draw it cap the line count. Runs of blank lines are not,
            // since they only spend the cap on nothing.
            body: root.plainText(notif.body).replace(/\n{3,}/g, "\n\n").trim(),
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
