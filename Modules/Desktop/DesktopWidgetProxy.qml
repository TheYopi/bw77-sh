import QtQuick
import Quickshell
import qs.Config
import qs.Common
import qs.Modules.Desktop

/*
 * A widget's stand-in while arranging. Lives on the full-screen edit surface,
 * so drag coordinates are stable and deltas actually accumulate.
 */
Item {
    id: root

    property int widgetIndex: -1

    // The display this proxy is being edited on. Needed to turn the widget's
    // position on this surface into a position in the compositor's global
    // layout, which is the only space in which "which monitor is this over"
    // has an answer.
    property var hostScreen: null

    readonly property var cfg: Settings.desktop.widgets[widgetIndex]

    x: cfg ? cfg.x : 0
    y: cfg ? cfg.y : 0
    width: cfg ? cfg.w : 200
    height: cfg ? cfg.h : 150

    /*
     * The floor below which a widget's contents collide.
     *
     * The table used to live here, which meant it only applied while this
     * handle was being dragged - a size arriving from anywhere else went
     * straight through. It is shared with the layer now; see WidgetMetrics.
     */
    readonly property string widgetType: cfg ? cfg.type : ""
    readonly property var minSize: WidgetMetrics.of(widgetType)

    /*
     * --- snapping
     *
     * Both of these snap live, while the handle is moving, rather than only on
     * release. Snapping at the end meant the widget followed the pointer freely
     * and then jumped somewhere else when let go, so the grid was something you
     * found out about afterwards instead of something you aimed with. Moving in
     * grid steps makes the alignment visible as it happens, and the crosshair
     * and the readout agree with where the widget will actually end up.
     *
     * The anchor is the TOP-LEFT corner, for both moving and resizing. That is
     * the corner the stored x/y describes, and it is the only choice that makes
     * two widgets on the same grid line up: snapping a centre puts the edges on
     * half-steps, and snapping whichever edge is nearest means the anchor
     * changes depending on which way you happened to drag.
     */
    function snap(v) {
        if (!Settings.desktop.snapToGrid) return v;
        const g = Settings.desktop.gridSnap;
        return g > 1 ? Math.round(v / g) * g : v;
    }

    /*
     * A size snapped to the grid but never below the widget's floor.
     *
     * Rounding to the nearest step can land under the minimum, and clamping
     * after the round would put the edge back off-grid - so it steps up until
     * it clears instead. With the top-left on the grid and the size a whole
     * number of steps, the bottom-right corner lands on the grid too, which is
     * what makes a row of widgets share an edge.
     */
    function snapSize(v, floor) {
        const wanted = Math.max(floor, v);
        if (!Settings.desktop.snapToGrid) return wanted;

        const g = Settings.desktop.gridSnap;
        if (g <= 1) return wanted;

        let stepped = Math.round(wanted / g) * g;
        while (stepped < floor) stepped += g;
        return stepped;
    }

    /*
     * --- moving a widget between displays
     *
     * Dragging works, and it took the compositor's global geometry to make it
     * work. Each display is its own layer surface, so a drag genuinely cannot
     * leave the one it started on - what it can do is end up past that
     * surface's edge, and every ShellScreen carries its x/y position in the
     * compositor's overall layout. Converting the widget's centre into that
     * space says which monitor it was dropped over, whatever surface the
     * pointer happened to be on.
     *
     * The visual limitation is unavoidable: the proxy is clipped at the screen
     * edge, so the last stretch of the drag happens half off-screen. The banner
     * that appears while the centre is over another display is there to say the
     * drop will land, since you cannot see that it will.
     *
     * The button remains as well. Dragging is fine for adjacent monitors and
     * awkward for a display stacked above or below, and it needs a steady hand
     * either way.
     */
    readonly property var screenNames: Quickshell.screens.map(s => s.name)

    readonly property string currentScreen: {
        if (cfg && cfg.screen) return cfg.screen;
        return screenNames.length > 0 ? screenNames[0] : "";
    }

    // Centre of the widget in global coordinates. The centre rather than the
    // corner, so a widget nudged one pixel over a boundary does not jump
    // displays.
    readonly property real globalCentreX:
        (hostScreen ? hostScreen.x : 0) + x + width / 2
    readonly property real globalCentreY:
        (hostScreen ? hostScreen.y : 0) + y + height / 2

    function screenAt(gx, gy) {
        const list = Quickshell.screens;
        for (let i = 0; i < list.length; i++) {
            const s = list[i];
            if (gx >= s.x && gx < s.x + s.width && gy >= s.y && gy < s.y + s.height)
                return s;
        }
        return null;
    }

    // Non-null only while the drag is currently over a different display.
    readonly property var pendingScreen: {
        if (!hostScreen || !dragArea.pressed) return null;
        const target = screenAt(globalCentreX, globalCentreY);
        if (!target || target.name === hostScreen.name) return null;
        return target;
    }

    /*
     * Write a widget's geometry back to settings.
     *
     * This function went missing in an earlier edit and nothing noticed,
     * because a ReferenceError inside a QML signal handler is a warning on
     * stderr rather than a failure - the handler simply stops. Both the drag
     * and the resize released into it, so no move and no resize had been saved
     * since; the widget snapped back to its stored position the moment edit
     * mode closed.
     *
     * The array is copied and reassigned rather than mutated in place, because
     * Settings.desktop.widgets returns a fresh array on every read: mutating
     * what comes back changes a temporary and is dropped.
     */
    function persist(nx, ny, nw, nh) {
        if (widgetIndex < 0) return;

        const list = Settings.desktop.widgets.slice();
        if (widgetIndex >= list.length) return;

        list[widgetIndex] = Object.assign({}, list[widgetIndex], {
            x: Math.max(0, Math.round(nx)),
            y: Math.max(0, Math.round(ny)),
            w: Math.round(WidgetMetrics.clampWidth(root.widgetType, nw)),
            h: Math.round(WidgetMetrics.clampHeight(root.widgetType, nh))
        });

        Settings.desktop.widgets = list;
    }

    function assign(screenName, nx, ny) {
        if (widgetIndex < 0) return;
        const list = Settings.desktop.widgets.slice();
        if (widgetIndex >= list.length) return;
        list[widgetIndex] = Object.assign({}, list[widgetIndex], {
            screen: screenName,
            x: Math.max(0, Math.round(nx)),
            y: Math.max(0, Math.round(ny)),
            // Carried across too: a widget resized and then sent to another
            // display would otherwise arrive at its old size.
            w: Math.round(WidgetMetrics.clampWidth(root.widgetType, root.width)),
            h: Math.round(WidgetMetrics.clampHeight(root.widgetType, root.height))
        });
        Settings.desktop.widgets = list;
    }

    function commitDrag() {
        const target = hostScreen ? screenAt(globalCentreX, globalCentreY) : null;

        if (target && target.name !== hostScreen.name) {
            // Re-express the position relative to the display it landed on.
            assign(target.name,
                   snap(globalCentreX - width / 2 - target.x),
                   snap(globalCentreY - height / 2 - target.y));
            return;
        }
        persist(snap(x), snap(y), width, height);
    }

    /*
     * Send the widget to the next display, centred on arrival.
     *
     * The old coordinates are not carried over. They describe a position on
     * the display the widget is leaving, and two displays need not be the same
     * size or orientation - a widget at x=3200 on an ultrawide lands off the
     * edge of the 1080p panel beside it, where it cannot be seen and cannot be
     * dragged back. The centre is the one spot that is always on-screen and
     * always reachable whatever the target turns out to be.
     *
     * Dragging across a screen boundary still keeps where it was dropped, in
     * commitDrag - that is a position chosen deliberately and already known to
     * be inside the target.
     */
    function moveToNextScreen() {
        if (widgetIndex < 0 || screenNames.length < 2) return;

        const at = screenNames.indexOf(currentScreen);
        const nextName = screenNames[(at + 1) % screenNames.length];

        let nx = x;
        let ny = y;
        for (let i = 0; i < Quickshell.screens.length; i++) {
            const sc = Quickshell.screens[i];
            if (sc.name !== nextName) continue;
            // Clamped at zero, so a widget wider than the target display lands
            // at the top left rather than at a negative offset.
            nx = Math.max(0, Math.round((sc.width - width) / 2));
            ny = Math.max(0, Math.round((sc.height - height) / 2));
            break;
        }

        assign(nextName, nx, ny);
    }

    // Live preview of the real widget, dimmed behind the edit chrome.
    DesktopWidgetContent {
        anchors.fill: parent
        config: root.cfg
        opacity: 0.5
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.alpha(Theme.accent, dragArea.pressed ? 0.28 : 0.14)
        border.color: dragArea.pressed ? Theme.danger : Theme.accent
        border.width: dragArea.pressed ? 2 : 1
    }

    /*
     * Centre crosshair.
     *
     * Aligning two widgets against each other by their edges only works when
     * they are the same size; by their centres it always works. The type label
     * used to sit dead centre and is offset above it now, because the one place
     * the mark has to be legible is the exact place the label was covering.
     */
    Item {
        id: crosshair
        anchors.centerIn: parent
        width: 22
        height: 22

        Rectangle {
            anchors.centerIn: parent
            width: parent.width
            height: 1
            color: dragArea.pressed ? Theme.danger : Theme.accent
        }

        Rectangle {
            anchors.centerIn: parent
            width: 1
            height: parent.height
            color: dragArea.pressed ? Theme.danger : Theme.accent
        }

        Rectangle {
            anchors.centerIn: parent
            width: 7
            height: 7
            rotation: 45
            color: "transparent"
            border.color: dragArea.pressed ? Theme.danger : Theme.accent
            border.width: 1
        }
    }

    CyberText {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: crosshair.top
        anchors.bottomMargin: Theme.space2
        text: root.cfg ? root.cfg.type : ""
        role: "title"
        color: Theme.accent
    }

    Row {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: Theme.space1
        spacing: Theme.space2

        CyberText {
            text: `${Math.round(root.x)},${Math.round(root.y)}  ${Math.round(root.width)}\u00D7${Math.round(root.height)}`
            role: "micro"
            color: Theme.textDim
        }

        /*
         * Which way the widget will lay itself out at this size.
         *
         * Several of them reflow across instead of down once they are wide
         * enough, and without this the change happens mid-drag for no visible
         * reason - the readout says what the threshold did.
         */
        CyberText {
            text: WidgetMetrics.isWide(root.widgetType, root.width, root.height)
                ? "\u2194 WIDE" : "\u2195 TALL"
            role: "micro"
            color: Theme.accent
        }

        // Says why the handle stopped moving.
        CyberText {
            visible: root.width <= root.minSize.w + 1 || root.height <= root.minSize.h + 1
            text: "MIN"
            role: "micro"
            color: Theme.danger
        }
    }

    /*
     * Where the drop will land.
     *
     * Shown only while the widget's centre is over another display. Without it
     * the last part of the drag is invisible - the proxy is clipped at the
     * screen edge - and there is nothing to say whether letting go will move
     * the widget or snap it back.
     */
    Rectangle {
        anchors.centerIn: parent
        visible: root.pendingScreen !== null
        width: banner.implicitWidth + Theme.space4
        height: 28
        color: Theme.alpha(Theme.bgDeep, 0.9)
        border.color: Theme.danger
        border.width: 2

        CyberText {
            id: banner
            anchors.centerIn: parent
            text: "\u2192 " + (root.pendingScreen ? root.pendingScreen.name : "")
            role: "label"
            bold: true
            color: Theme.danger
        }
    }

    /*
     * Send to the next display. Only worth drawing when there is another one.
     *
     * `z` is what makes it clickable. The drag area below fills the whole proxy
     * and is declared after this, so it stacked on top and swallowed every
     * press before the button saw it - the button drew, highlighted on hover,
     * and did nothing at all. Raising it above the drag area is the fix; the
     * resize handle already sits after the drag area and never had the problem.
     */
    CyberButton {
        z: 10
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.space1
        visible: root.screenNames.length > 1
        height: 22
        iconText: "\uf24d"
        text: root.currentScreen
        onClicked: root.moveToNextScreen()
    }

    MouseArea {
        id: dragArea
        anchors.fill: parent
        anchors.rightMargin: 16
        anchors.bottomMargin: 16
        cursorShape: Qt.SizeAllCursor

        /*
         * Driven by hand rather than by `drag.target`.
         *
         * The built-in drag moves the item to follow the pointer exactly, and
         * there is no hook to quantise that on the way through - assigning to
         * x/y from a change handler fights the same frame's drag update and
         * jitters. Tracking the grab offset and setting the position outright
         * gives the snap for free, and the offset is what stops the widget
         * jumping so its corner is under the cursor on the first press.
         */
        property real grabX: 0
        property real grabY: 0

        onPressed: (m) => {
            const p = mapToItem(root.parent, m.x, m.y);
            grabX = p.x - root.x;
            grabY = p.y - root.y;
        }

        onPositionChanged: (m) => {
            if (!pressed) return;
            const p = mapToItem(root.parent, m.x, m.y);
            root.x = root.snap(p.x - grabX);
            root.y = root.snap(p.y - grabY);
        }

        // Written once on release rather than on every frame: the position is
        // held by `root` during the drag and only committed at the end, so a
        // settings write cannot fight the drag in progress.
        onReleased: root.commitDrag()
    }

    Rectangle {
        id: resizeHandle
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: 16
        height: 16
        color: resizeArea.pressed ? Theme.danger : Theme.accent

        MouseArea {
            id: resizeArea
            anchors.fill: parent
            cursorShape: Qt.SizeFDiagCursor

            property real startW: 0
            property real startH: 0
            property real startMouseX: 0
            property real startMouseY: 0

            onPressed: (m) => {
                startW = root.width;
                startH = root.height;
                // Map to the edit surface: the handle itself moves as the widget
                // grows, so its local coordinates are not a stable reference.
                const p = mapToItem(root.parent, m.x, m.y);
                startMouseX = p.x;
                startMouseY = p.y;
            }

            onPositionChanged: (m) => {
                if (!pressed) return;
                const p = mapToItem(root.parent, m.x, m.y);
                // Snapped as it moves, so the edge you are dragging sits on the
                // grid throughout instead of jumping to it on release.
                root.width = root.snapSize(startW + (p.x - startMouseX), root.minSize.w);
                root.height = root.snapSize(startH + (p.y - startMouseY), root.minSize.h);
            }

            // Already on the grid by the time the button comes up, so this
            // commits what is on screen rather than snapping again.
            onReleased: root.persist(root.x, root.y, root.width, root.height)
        }
    }
}
