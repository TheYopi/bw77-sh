import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import qs.Config
import qs.Common

Item {
    id: root

    required property var notif
    signal dismissed()

    /*
     * State that survives this delegate being destroyed and rebuilt, owned by
     * NotificationLayer and keyed on the notification id. See the note there.
     */
    property var meta: ({})

    // Sender's own timeout when it gave one, otherwise the configured default.
    // A notification that asks to be shown for twenty seconds is asking for a
    // reason, and overriding it with one global number was never deliberate.
    readonly property int lifetime: {
        const asked = root.notif.expireTimeout;
        return (asked !== undefined && asked > 0)
            ? asked : Settings.notifications.timeout;
    }

    // Resolved once, at construction, from the shared deadline.
    property int startRemaining: 0
    property real startFraction: 1
    property bool firstShow: true
    property real slideFrom: 0

    // Where this toast sat before the rebuild, and a flag saying the slide is
    // still waiting for the Column to place it.
    property real capturedPrevY: 0
    property bool awaitingLayout: false

    // Dismissal is deferred until the tear-out finishes, so the toast leaves
    // the way it arrived rather than being cut mid-frame.
    property bool shown: true
    function dismiss() { shown = false; }

    Component.onCompleted: {
        rebuildActions();

        if (root.meta.deadline === undefined)
            root.meta.deadline = Date.now() + root.lifetime;

        root.firstShow = root.meta.seen !== true;
        root.meta.seen = true;

        const remaining = Math.max(0, root.meta.deadline - Date.now());
        root.startRemaining = remaining;
        root.startFraction = remaining / Math.max(1, root.lifetime);

        /*
         * Note where this toast used to be, but do not start the slide yet.
         *
         * The Column has not placed this delegate at the point the component
         * completes - y is still 0 - so measuring the offset here would slide
         * every rebuilt toast in from the top of the screen. The move is
         * started on the first y change instead, which is the Column doing the
         * placement.
         */
        if (!root.firstShow && root.meta.lastY !== undefined) {
            root.capturedPrevY = root.meta.lastY;
            root.awaitingLayout = true;
        }

        if (root.critical) return;
        if (remaining <= 0) root.dismiss();
        else countdown.start();
    }

    onYChanged: {
        // The Column has just placed it. Slide from the old slot to this one.
        if (root.awaitingLayout) {
            root.awaitingLayout = false;
            const delta = root.capturedPrevY - root.y;
            if (Math.abs(delta) > 1) {
                root.slideFrom = delta;
                reflow.restart();
            }
        }

        // Recorded continuously, and after the slide is worked out - read by
        // the next incarnation of this toast.
        if (root.meta) root.meta.lastY = root.y;
    }

    // Offset used by the reflow slide. Zero at rest, so it costs nothing once
    // the toast has settled.
    property real reflowOffset: 0
    transform: Translate { y: root.reflowOffset }

    NumberAnimation {
        id: reflow
        target: root; property: "reflowOffset"
        from: root.slideFrom
        to: 0
        duration: Theme.durationFor("notifications")
        easing.type: Theme.curveFor("notifications")
    }

    readonly property bool critical: notif.urgency === NotificationUrgency.Critical
    readonly property color accent: critical ? Theme.danger
        : (notif.urgency === NotificationUrgency.Low ? Theme.textDim : Theme.accent)

    /*
     * --- the action buttons
     *
     * Held in a property and rebuilt only when the action set actually changes,
     * rather than computed in a binding on notif.actions.
     *
     * A binding hands the Repeater a brand new array every time anything about
     * the notification changes, and a new array means every button is destroyed
     * and rebuilt - including the one under the pointer, mid-signal. Telegram
     * replaces its notifications instead of posting new ones, so that happened
     * repeatedly while the toast sat there being hovered, which is the shape of
     * the crash reported against this file.
     *
     * The signature is the deciding factor: same buttons, same array, no
     * regeneration. An update that changes only the body text now leaves the
     * buttons alone entirely.
     */
    readonly property string actionSignature: {
        const given = root.notif.actions || [];
        let sig = "";
        for (let i = 0; i < given.length; i++)
            sig += String(given[i].text || "") + "\u001f";
        return sig;
    }

    property var actionList: []

    function rebuildActions() {
        const out = [];
        const given = root.notif.actions || [];
        for (let i = 0; i < given.length; i++) out.push(given[i]);

        /*
         * Always offer a way out.
         *
         * Most notifications ship no actions at all, so the row would be
         * missing exactly when the toast is hardest to get rid of. Skipped when
         * the sender already provides something that closes it.
         */
        const hasClose = out.some(a =>
            ["close", "dismiss", "cancel"].indexOf(String(a.text || "").toLowerCase()) >= 0);

        if (!hasClose)
            out.push({ text: Settings.t("Close"), invoke: () => root.dismiss() });

        root.actionList = out;
    }

    /*
     * Deferred, for the same reason the layer defers its list.
     *
     * This fires from a C++ property change on notif.actions, so rebuilding
     * here would run the Repeater's regenerate on that emitting stack - the
     * exact thing that crashed. The initial build in Component.onCompleted is
     * left synchronous: it happens once as part of construction, and deferring
     * it would render the toast a frame tall with no buttons and then resize it,
     * since the height depends on how many there are.
     */
    onActionSignatureChanged: Qt.callLater(rebuildActions)

    width: Settings.notifications.width

    // Measured off the built layout rather than recomputed from paddings and
    // font sizes. The hand-summed version had to be kept in step with the
    // layout below by hand, and was wrong the moment the body wrapped to a
    // second line.
    /*
     * One column, measured once.
     *
     * The actions used to be anchored to the frame's bottom while the message
     * was anchored to its top, with the height computed as the sum of the two
     * plus paddings. Any disagreement between that arithmetic and what the
     * layout actually did showed up as the gap between them - and it kept
     * coming out at nothing, so the message and the button sat on the same
     * line. Putting the buttons in the same Column as everything else makes the
     * gap a spacing value that cannot be computed wrongly.
     */
    height: stack.implicitHeight + Theme.space3 * 2

    // Sized to the label rather than to the width of the toast. It was 36 when
    // it spanned the frame edge to edge; a button only needs room to sit in.
    readonly property int actionsHeight: 28

    GlitchBox {
        category: "notifications"
        id: toastAnim
        anchors.fill: parent
        shown: root.shown
        // Only the first appearance is an arrival. A rebuild caused by a
        // neighbour being added or removed must not replay it.
        enabled: Settings.animations.notificationEntry && root.firstShow
        onCloseFinished: root.dismissed()

        /*
         * Two cuts here, not one.
         *
         * The study draws the notification with the top-left and bottom-right
         * corners clipped where everything else takes a single cut. It is the
         * one surface that arrives unbidden and has to be told apart from the
         * shell's own furniture at a glance, and the doubled cut does that
         * before any of the text is read.
         */
        Panel {
            anchors.fill: parent
            emphasis: root.critical ? "alert" : "normal"
            serialSeed: String(root.notif.id)
            // No serial. It is decoration for a surface you sit and read; on a
            // toast it printed between the action buttons and the countdown bar
            // and read as a fourth line of content in a three-line surface.
            serial: false
            padding: 0
            notchTopLeft: true
            notchBottomRight: true

            // --- header: who sent it, and what it is called
            //
            // Centred, per the study, and both lines in the accent - the app
            // name above its own title. The name used to sit inline with the
            // icon at micro size, which made the sender the least prominent
            // thing on a surface whose whole job is to say who is talking.
            Column {
                id: stack
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: Theme.space3
                // Wide enough that the message and the buttons are plainly
                // separate blocks. At space2 they read as one run of text.
                spacing: Theme.space3

                Item {
                    width: parent.width
                    // The icon and the two header lines sit side by side, so
                    // whichever is taller sets the row.
                    height: Math.max(icon.height, head.implicitHeight)

                    // Framed, as drawn. A bare icon floating against the fill
                    // had nothing holding it to the layout.
                    NotchRect {
                        id: icon
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 38
                        height: 38
                        fillColor: Theme.alpha(Theme.bgDeep, 0.6)
                        strokeColor: Theme.alpha(Theme.danger, 0.75)
                        notch: 7

                        IconImage {
                            id: appIcon
                            anchors.centerIn: parent
                            implicitSize: 24
                            visible: status === Image.Ready
                            source: root.notif.appIcon
                                ? Quickshell.iconPath(root.notif.appIcon, true) : ""
                        }

                        /*
                         * Fallback glyph.
                         *
                         * Keyed on whether the image actually resolved, not on
                         * whether the notification named one. Plenty of senders
                         * pass an icon name the icon theme does not have - niri
                         * is one - and testing the name left the frame sitting
                         * there empty, which looked like a rendering fault
                         * rather than a missing icon.
                         */
                        CyberText {
                            anchors.centerIn: parent
                            visible: appIcon.status !== Image.Ready
                            text: "\uf0f3"
                            role: "icon"
                            color: Theme.alpha(Theme.danger, 0.8)
                        }
                    }

                    Column {
                        id: head
                        anchors.left: icon.right
                        anchors.leftMargin: Theme.space3
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 0

                        CyberText {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: root.notif.appName || Settings.t("System")
                            role: "label"
                            bold: true
                            // The one place the danger colour earns its keep on
                            // this surface: who is interrupting you, and what
                            // about. The body stays in the accent so the two
                            // are told apart at a glance.
                            color: Theme.danger
                            elide: Text.ElideRight
                        }

                        GlitchText {
                            width: parent.width
                            textWidth: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: root.notif.summary
                            role: "micro"
                            color: Theme.alpha(Theme.danger, 0.85)
                            decodeOnChange: Settings.notifications.animation === "glitch"
                        }
                    }
                }

                CyberText {
                    width: parent.width
                    visible: root.notif.body !== ""
                    text: root.notif.body
                    role: "body"
                    caps: false
                    color: Theme.accent
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    // Two lines, as drawn. Four made a chatty application able
                    // to take over the corner of the screen.
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }

                /*
                 * --- actions
                 *
                 * In the column, so the gap above them is the column's spacing
                 * and nothing has to compute it. Discrete buttons rather than a
                 * band welded to the frame: at 36px tall and edge to edge, the
                 * way to dismiss a notification outweighed the notification.
                 */
                Item {
                    width: parent.width
                    height: root.actionList.length > 0 ? root.actionsHeight : 0
                    visible: height > 0

                    // A little more air above the buttons than between the two
                    // lines of the message, so they read as a footer rather
                    // than as a third line of it.
                    Row {
                        id: actions
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: root.actionsHeight
                        spacing: Theme.space2

                        Repeater {
                            model: root.actionList

                            Item {
                                required property var modelData
                                required property int index

                                // Split evenly, with the gaps taken out of the
                                // total so the row ends flush with the column.
                                width: (actions.width
                                        - Theme.space2 * (root.actionList.length - 1))
                                       / root.actionList.length
                                height: actions.height

                                NotchRect {
                                    anchors.fill: parent
                                    fillColor: Theme.alpha(Theme.danger,
                                        actionMouse.containsMouse ? 0.40 : 0.22)
                                    strokeColor: actionMouse.containsMouse
                                        ? Theme.danger : Theme.alpha(Theme.danger, 0.65)
                                    notch: 7

                                    Behavior on fillColor { ColorAnimation { duration: Theme.durFast } }
                                    Behavior on strokeColor { ColorAnimation { duration: Theme.durFast } }
                                }

                                CyberText {
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.space2
                                    anchors.rightMargin: Theme.space2
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    // Filled rather than centred so a long
                                    // action name elides inside its own cell
                                    // instead of running under its neighbour.
                                    elide: Text.ElideRight
                                    text: modelData.text
                                    role: "label"
                                    color: Theme.text
                                }

                                MouseArea {
                                    id: actionMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (modelData.invoke) modelData.invoke();
                                        root.dismiss();
                                    }
                                }
                            }
                        }
                    }
                }
            }

        }
    }

    // Timeout progress runs along the bottom edge, so the countdown is visible
    // without adding a number to read.
    Rectangle {
        id: timerBar
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        height: 2
        color: root.accent
        visible: !root.critical

        // Started by hand from Component.onCompleted rather than declared
        // running, because both its start value and its duration come from the
        // shared deadline and are not known until then. A toast rebuilt with
        // two seconds left resumes with a two-second bar two-thirds spent.
        width: root.width * root.startFraction

        NumberAnimation {
            id: countdown
            target: timerBar; property: "width"
            from: root.width * root.startFraction
            to: 0
            duration: root.startRemaining
            onFinished: root.dismiss()
        }
    }

    /*
     * Click anywhere to dismiss - but behind the toast, not over it.
     *
     * A sibling declared last sits on top, so this was covering the whole
     * surface and swallowing every press before the actions underneath could
     * see it. Nothing in the panel above accepts mouse events except the action
     * cells, so at z: -1 a press on the body still falls through to here while
     * a press on Open or Close reaches the button.
     */
    MouseArea {
        z: -1
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: root.dismiss()
    }
}
