import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Config
import qs.Common
import qs.Modules.Desktop

/*
 * Free-placed desktop widgets, in two distinct modes.
 *
 * Normal mode gives each widget its own layer surface, sized to the widget.
 * Input lands on the widget and nowhere else, so the media player's buttons
 * work and clicks elsewhere reach the desktop - no input mask involved.
 *
 * Edit mode replaces all of them with ONE full-screen surface holding
 * draggable proxies. Dragging inside a widget-sized window does not work: the
 * window follows the cursor, so the cursor never moves relative to it and the
 * drag delta stays at zero. A single stationary surface gives stable
 * coordinates to drag against.
 */
Variants {
    id: screens
    model: Quickshell.screens

    Scope {
        id: screenScope
        required property var modelData

        readonly property bool editing: Settings.desktop.enabled && Settings.desktop.editMode

        /*
         * Only the widgets that belong to THIS display.
         *
         * Every widget used to get a surface on every display, with `visible`
         * deciding which one showed - and reassigning a widget's display then
         * came down to flipping `visible` on two wlr layer surfaces. That is
         * the one link in the chain I could not test from here, and it is the
         * one that behaved as though the change had not happened: the widget
         * stayed put however many times the display was switched.
         *
         * Making the model itself per-display means a reassignment destroys
         * the surface on the old output and creates one on the new, which is
         * an operation the compositor cannot quietly ignore. It also stops the
         * shell holding a full set of surfaces per monitor for widgets that
         * were never going to be drawn on them.
         */
        // Widgets are addressed by index rather than by object identity.
        // Settings.desktop.widgets returns a fresh array of fresh objects on
        // every read, so indexOf(modelData) never matched and every write was
        // silently dropped - which is why nothing could be moved.
        readonly property var mine: {
            const out = [];
            const list = Settings.desktop.widgets;
            for (let i = 0; i < list.length; i++)
                if (screenScope.onThisScreen(list[i])) out.push(i);
            return out;
        }

        /*
         * --- which display a widget belongs to
         *
         * An unassigned widget used to appear on every display, at the same x
         * and y on each - so a second monitor got a duplicate set of widgets
         * placed by coordinates that were chosen for the first one, which is
         * exactly the "copied over with weird coordinates" behaviour.
         *
         * The tempting fix is one coordinate space spanning all the outputs,
         * and it cannot be done: a Wayland layer-shell surface is bound to a
         * single output at the protocol level. There is no surface that spans
         * two monitors to place anything on, so a combined resolution would be
         * a fiction the shell maintained and the compositor ignored - and the
         * moment a display is unplugged or its position changes, every widget
         * would be somewhere unexpected. Per-display placement is what the
         * protocol actually supports, so that is what this does.
         *
         * An unassigned widget therefore lands on the first display rather than
         * all of them. Assign one explicitly to move it; Control Center ->
         * Desktop lists every placed widget with the display it is on.
         */
        readonly property bool multiMonitor: Quickshell.screens.length > 1

        readonly property string firstScreenName:
            Quickshell.screens.length > 0 ? Quickshell.screens[0].name : ""

        function onThisScreen(w) {
            const here = screenScope.modelData.name;
            if (!w || !w.screen || w.screen === "")
                return !multiMonitor || here === firstScreenName;
            return w.screen === here;
        }

        /*
         * --- normal mode: one surface per widget
         *
         * The model empties when widgets are disabled rather than the windows
         * merely being hidden. A hidden PanelWindow keeps its entire item tree
         * alive - canvases, timers, bindings and all - which is why turning
         * widgets off did not give the memory back.
         */
        Variants {
            model: (!Settings.desktop.enabled || screenScope.editing)
                ? [] : screenScope.mine

            PanelWindow {
                id: win
                required property var modelData          // the index

                readonly property var cfg: Settings.desktop.widgets[modelData]

                screen: screenScope.modelData
                // The model already filtered to this display; all that is left
                // is the frame where an entry has just been removed.
                visible: cfg !== undefined

                WlrLayershell.layer: WlrLayer.Bottom
                WlrLayershell.namespace: "bw77-desktop"
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

                // Anchored to two edges so the margins act as an x/y position.
                anchors { top: true; left: true }
                margins.left: cfg ? cfg.x : 0
                margins.top: cfg ? cfg.y : 0
                /*
                 * Clamped up to the widget's floor.
                 *
                 * A size can reach here from a hand-edited settings.json, from
                 * a config written before a widget's contents grew, or from a
                 * default that was never revisited - none of which pass through
                 * the resize handle that used to be the only thing enforcing a
                 * minimum. Correcting it on the way out means an existing
                 * config draws properly without the file being rewritten
                 * underneath the person who wrote it.
                 */
                implicitWidth: cfg
                    ? WidgetMetrics.clampWidth(cfg.type, cfg.w) : 200
                implicitHeight: cfg
                    ? WidgetMetrics.clampHeight(cfg.type, cfg.h) : 150
                exclusionMode: ExclusionMode.Ignore
                color: "transparent"

                DesktopWidgetContent {
                    anchors.fill: parent
                    config: win.cfg
                }
            }
        }

        // --- edit mode: one surface, everything draggable on it
        LazyLoader {
            active: screenScope.editing

            PanelWindow {
                id: editWin
                screen: screenScope.modelData

                WlrLayershell.layer: WlrLayer.Top
                WlrLayershell.namespace: "bw77-desktop-edit"
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

                anchors { top: true; bottom: true; left: true; right: true }
                exclusionMode: ExclusionMode.Ignore
                color: "transparent"

                Rectangle {
                    anchors.fill: parent
                    color: Theme.alpha(Theme.bgDeep, 0.45)
                }

                /*
                 * Grid, plus the display's own centre lines.
                 *
                 * The centre axes are drawn heavier and in crimson because they
                 * are the only two lines on the surface that mean something -
                 * every other line is just spacing. Centring a widget by eye
                 * against a uniform grid means counting squares to each edge,
                 * and getting it wrong by one is invisible until you look at
                 * the finished desktop.
                 */
                Canvas {
                    id: guides
                    anchors.fill: parent

                    // Repainting on resize matters here: a Canvas keeps its old
                    // buffer, so the centre lines would stay where the old
                    // centre was after a resolution change.
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()

                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);

                        // Drawn only while it means something. Lines nothing
                        // lands on are worse than no lines - they say a widget
                        // will align to them, and it will not.
                        if (Settings.desktop.snapToGrid) {
                            ctx.strokeStyle = Theme.alpha(Theme.accent, 0.15);
                            ctx.lineWidth = 1;
                            const step = Math.max(4, Settings.desktop.gridSnap * 4);
                            for (let x = 0; x < width; x += step) {
                                ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, height); ctx.stroke();
                            }
                            for (let y = 0; y < height; y += step) {
                                ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(width, y); ctx.stroke();
                            }
                        }

                        // Half-pixel offset so a 2px line lands on the pixel
                        // grid instead of straddling it and rendering as 3px
                        // of half-strength grey.
                        const cx = Math.round(width / 2) + 0.5;
                        const cy = Math.round(height / 2) + 0.5;

                        ctx.strokeStyle = Theme.alpha(Theme.danger, 0.55);
                        ctx.lineWidth = 2;
                        ctx.beginPath(); ctx.moveTo(cx, 0); ctx.lineTo(cx, height); ctx.stroke();
                        ctx.beginPath(); ctx.moveTo(0, cy); ctx.lineTo(width, cy); ctx.stroke();
                    }

                    Connections {
                        target: Settings.desktop
                        function onGridSnapChanged() { guides.requestPaint(); }
                        function onSnapToGridChanged() { guides.requestPaint(); }
                    }
                }

                // Marker at the exact centre of the display, so "the middle" is
                // a point to aim at and not an intersection to infer.
                Item {
                    anchors.centerIn: parent
                    width: 26
                    height: 26

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width
                        height: 2
                        color: Theme.danger
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: 2
                        height: parent.height
                        color: Theme.danger
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: 8
                        height: 8
                        rotation: 45
                        color: "transparent"
                        border.color: Theme.danger
                        border.width: 1
                    }
                }

                Repeater {
                    // Same per-display model the normal-mode surfaces use, so
                    // edit mode shows exactly the widgets that display owns
                    // rather than building a proxy for every widget on every
                    // monitor and hiding most of them.
                    model: screenScope.mine

                    DesktopWidgetProxy {
                        required property var modelData
                        widgetIndex: modelData
                        hostScreen: screenScope.modelData
                    }
                }

                /*
                 * The edit toolbar.
                 *
                 * Was a fixed 420x74 box, which is why the heading ran out
                 * through both sides of its own frame: the text is translated
                 * and scales with the interface font, so no fixed width is
                 * right for long. It measures its contents now and only clamps
                 * against the display, which is the one limit that is real.
                 */
                Panel {
                    id: toolbar

                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Theme.space6

                    width: Math.min(editWin.width - Theme.space6 * 2,
                                    Math.max(420, bar.implicitWidth + padding * 2))
                    height: bar.implicitHeight + padding * 2

                    emphasis: "alert"
                    serial: false
                    padding: Theme.space4

                    Column {
                        id: bar
                        anchors.centerIn: parent
                        spacing: Theme.space3

                        CyberText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: screenScope.multiMonitor
                                ? Settings.t("Drag to move - across displays too - and pull the corner to resize")
                                : Settings.t("Drag to move, pull the corner to resize")
                            role: "label"
                            color: Theme.text
                        }

                        // Which display this surface is. Edit mode opens one of
                        // these per monitor and they look identical otherwise.
                        CyberText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: screenScope.multiMonitor
                            text: screenScope.modelData.name
                                + (screenScope.modelData.name === screenScope.firstScreenName
                                    ? " \u00B7 " + Settings.t("holds unassigned widgets") : "")
                            role: "micro"
                            color: Theme.textMuted
                        }

                        /*
                         * Snap controls.
                         *
                         * Two settings rather than one, because "off" and "8px"
                         * are different questions and folding them into a
                         * single number meant the only way to move freely was
                         * to set the grid to 1 and then not remember what it
                         * had been. The step stepper dims rather than vanishes
                         * when snapping is off - it is still the value that
                         * comes back when you switch snapping on again.
                         */
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: Theme.space3

                            CyberToggleRow {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 180
                                height: 30
                                label: Settings.t("Snap to grid")
                                checked: Settings.desktop.snapToGrid
                                onToggled: (v) => {
                                    Settings.desktop.snapToGrid = v;
                                    guides.requestPaint();
                                }
                            }

                            CyberSelector {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 150
                                height: 30
                                opacity: Settings.desktop.snapToGrid ? 1 : 0.4
                                wrap: false
                                options: [
                                    { v: 4,  l: "4 PX" },
                                    { v: 8,  l: "8 PX" },
                                    { v: 16, l: "16 PX" },
                                    { v: 24, l: "24 PX" },
                                    { v: 32, l: "32 PX" }
                                ]
                                current: Settings.desktop.gridSnap
                                onPicked: (v) => {
                                    Settings.desktop.gridSnap = v;
                                    guides.requestPaint();
                                }
                            }
                        }

                        CyberButton {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Settings.t("Done")
                            keyHint: "ESC"
                            onClicked: Settings.desktop.editMode = false
                        }
                    }
                }

                Item {
                    anchors.fill: parent
                    focus: true
                    Keys.onEscapePressed: Settings.desktop.editMode = false
                }
            }
        }
    }
}
