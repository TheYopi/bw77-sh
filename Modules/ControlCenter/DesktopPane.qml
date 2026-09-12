import QtQuick
import Quickshell
import qs.Config
import qs.Common
import qs.Services
import qs.Modules.Desktop

PaneScroll {
    id: pane

    readonly property var types: ["sysmon", "cpu", "memory", "network", "gpu",
                                 "visualizer", "media", "clock", "battery"]

    function addWidget(type) {
        const list = Settings.desktop.widgets.slice();

        // Started at its own floor rather than at a flat 300x200. A network
        // readout does not want to arrive four times taller than it needs to
        // be, and the combined monitor does not want to arrive too short to
        // draw its four rows - which the fixed size did, since the floor is
        // 240 and it was being handed 200.
        const m = WidgetMetrics.of(type);
        list.push({ type: type, screen: "", x: 60, y: 60,
                    w: Math.max(m.w, 220), h: m.h });

        Settings.desktop.widgets = list;
    }

    /*
     * Move a widget to a display, and put it somewhere sensible on arrival.
     *
     * The coordinates are not carried across. They describe a position on the
     * display the widget came from, and the displays need not be the same size
     * or even the same orientation - a widget at x=3200 on an ultrawide lands
     * off the edge of a 1080p panel next to it and cannot be seen or grabbed
     * to bring back. Centring is the one placement that is always on-screen
     * and always reachable, whatever the target display turns out to be.
     *
     * Dragging a widget across a screen boundary still keeps where it was
     * dropped - that is a placement the person made deliberately, and it is
     * already known to be inside the target.
     */
    function moveToScreen(index, screenName) {
        const list = Settings.desktop.widgets.slice();
        if (index < 0 || index >= list.length) return;

        const w = list[index];
        let nx = w.x;
        let ny = w.y;

        for (let i = 0; i < Quickshell.screens.length; i++) {
            const sc = Quickshell.screens[i];
            if (sc.name !== screenName) continue;
            // Clamped at zero so a widget larger than the target display lands
            // at the top left rather than at a negative offset.
            nx = Math.max(0, Math.round((sc.width - w.w) / 2));
            ny = Math.max(0, Math.round((sc.height - w.h) / 2));
            break;
        }

        list[index] = Object.assign({}, w, { screen: screenName, x: nx, y: ny });
        Settings.desktop.widgets = list;
    }


    function removeWidget(index) {
        const list = Settings.desktop.widgets.slice();
        list.splice(index, 1);
        Settings.desktop.widgets = list;
    }

    SectionHeader {
        width: pane.innerWidth
        title: Settings.t("Desktop widgets")
        subtitle: Settings.t("Turn on edit mode, then drag widgets and pull the corner to resize")
    }

    SettingRow {
        label: Settings.t("Show desktop widgets")
        CyberToggle {
            checked: Settings.desktop.enabled
            onToggled: (v) => Settings.desktop.enabled = v
        }
    }

    SettingRow {
        label: Settings.t("Edit mode")
        description: Settings.t("Widgets become draggable and the alignment grid appears. The Control Center closes so you can reach them.")
        alternate: true

        /*
         * A button, not a switch.
         *
         * Edit mode is something you go and do, not a preference you leave
         * set - and as a switch it was the one control on the pane that could
         * not show you its own effect, because the Control Center was sitting
         * on top of the desktop it had just made editable. Turning it on
         * looked like nothing happening.
         *
         * Leaving edit mode is already handled where you are when you want to:
         * on the desktop itself.
         */
        CyberButton {
            text: Settings.t("Enter edit mode")
            onClicked: Shell.enterDesktopEditMode()
        }
    }

    SettingRow {
        label: Settings.t("Widget opacity")
        description: Settings.t("How solid a widget is over the wallpaper. These are the one part of the shell that is deliberately translucent - everything else appears briefly and has to be read, these sit there permanently and have to be lived with.")
        CyberSlider {
            width: 240
            from: 0.2; to: 1.0; stepSize: 0.02
            decimals: 0
            displayScale: 100
            value: Settings.desktop.widgetOpacity
            onMoved: (v) => Settings.desktop.widgetOpacity = v
        }
    }

    SettingRow {
        label: Settings.t("Snap to grid")
        CyberSlider {
            width: 240
            from: 1; to: 32; stepSize: 1
            value: Settings.desktop.gridSnap
            suffix: "px"
            onMoved: (v) => Settings.desktop.gridSnap = v
        }
    }

    SectionHeader {
        width: pane.innerWidth
        title: Settings.t("Audio visualiser")
        subtitle: Settings.t("The single most expensive widget to run")
        accentColor: Theme.accent
        glitch: false
    }

    SettingRow {
        label: Settings.t("Frame rate")
        description: "Frames per second requested from cava. Lower costs less; "
            + "60 is smooth without being wasteful"
        CyberSlider {
            width: 240
            from: 15; to: 90; stepSize: 5
            value: Audio.framerate
            suffix: " fps"
            onMoved: (v) => Audio.framerate = v
        }
    }

    SettingRow {
        label: Settings.t("Bands")
        alternate: true
        CyberSlider {
            width: 240
            from: 8; to: 64; stepSize: 2
            value: Audio.bands
            onMoved: (v) => Audio.bands = v
        }
    }

    SectionHeader {
        width: pane.innerWidth
        title: Settings.t("Placed widgets")
        accentColor: Theme.accent
        glitch: false
    }

    /*
     * Modelled on the COUNT, not on the list itself.
     *
     * This is what made the display stepper stick after one press.
     * Settings.desktop.widgets hands back a fresh array of fresh objects on
     * every read - see the note in DesktopLayer - so writing any field
     * produced an array with a new identity, the Repeater treated that as a
     * whole new model, and every delegate was destroyed and rebuilt.
     *
     * Which is survivable when it happens between events, and not when it
     * happens DURING one: the arrow's click handler ended up writing the
     * list, which replaced the model, which tore down the very MouseArea
     * that was mid-click. The rebuilt arrow never saw the press finish and the
     * pointer was left over an item that had never been entered, so the first
     * click worked and nothing after it did.
     *
     * An integer model only changes when a widget is added or removed. Editing
     * one leaves the delegates alone, and each reads its own entry by index,
     * so the values still update - verified: three consecutive edits, zero
     * delegates destroyed.
     */
    Repeater {
        model: Settings.desktop.widgets.length

        SettingRow {
            id: widgetRow
            required property int index

            // Guarded: on the frame where a widget is removed, the count has
            // dropped but this delegate can still evaluate once at its old
            // index, and reading `.type` off undefined would throw.
            readonly property var modelData: Settings.desktop.widgets[index] || ({})

            label: modelData.type || ""
            description: `${modelData.w}\u00D7${modelData.h} at ${modelData.x},${modelData.y}`
                // Not "every display" any more - see DesktopLayer.onThisScreen.
                // A layer surface cannot span outputs, so an unassigned widget
                // is drawn on the first one rather than duplicated onto all.
                + (modelData.screen ? ` on ${modelData.screen}` : Settings.t(" on the first display"))
            alternate: index % 2 === 1

            Row {
                spacing: Theme.space2

                /*
                 * Which display it lives on.
                 *
                 * Discoverable placement, which edit mode alone was not: a
                 * widget with no display assigned lands on the first one, and
                 * the only ways to move it were to drag it off the edge of a
                 * screen or to find a small button in the corner of its proxy.
                 * Neither is something you would guess at.
                 *
                 * Hidden with one monitor, where the question does not arise.
                 */
                CyberSelector {
                    visible: Quickshell.screens.length > 1
                    anchors.verticalCenter: parent.verticalCenter
                    width: 200

                    /*
                     * Wraps, unlike most steppers here.
                     *
                     * It did not, and on the usual two-monitor setup that made
                     * it look broken: move a widget to the far display and the
                     * arrow you just used goes dead, because there is nothing
                     * past the end of the list. The first click worked, every
                     * click after it did nothing, and the only way on was to
                     * notice the other arrow.
                     *
                     * A list of displays has no natural first or last - they
                     * are a set, not a range like a margin or a font size - so
                     * there is no end for the stepper to stop at.
                     */
                    wrap: true

                    options: Quickshell.screens.map(sc => ({ v: sc.name, l: sc.name }))
                    // An unassigned widget draws on the first display, so that
                    // is what the control should read rather than showing empty.
                    current: modelData.screen && modelData.screen !== ""
                        ? modelData.screen
                        : (Quickshell.screens.length > 0 ? Quickshell.screens[0].name : "")
                    /*
                     * `widgetRow.index`, not `index`.
                     *
                     * This is what made moving a widget between displays fail
                     * while the same action from edit mode worked. CyberSelector
                     * declares its own `index` - the position of the selected
                     * OPTION - and an unqualified `index` inside its handler
                     * resolves to that, because the nearest enclosing object
                     * wins. So every row passed the selected screen's position,
                     * 0 or 1, as the widget to edit: clicking any row rewrote
                     * widget 0 or widget 1, never necessarily the one clicked,
                     * and a widget could sit there apparently refusing to move
                     * while a different one was being sent back and forth.
                     */
                    onPicked: (v) => pane.moveToScreen(widgetRow.index, v)
                }

                CyberButton {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Settings.t("Remove")
                    destructive: true
                    onClicked: pane.removeWidget(index)
                }
            }
        }
    }

    Flow {
        width: pane.innerWidth
        spacing: Theme.space2

        Repeater {
            model: pane.types
            CyberButton {
                required property string modelData
                text: "Add " + modelData
                onClicked: pane.addWidget(modelData)
            }
        }
    }
}
