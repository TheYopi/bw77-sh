import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Config
import qs.Common
import qs.Services

/*
 * The settings surface: a card with a category rail down the left.
 *
 * This spent a while as a full-screen layout with the categories running across
 * the top as a scrolling strip. It was worse. Sixteen categories in a
 * horizontal carousel means most of them are off-screen at any moment and the
 * only way to see what exists is to scroll a list sideways; the vertical rail
 * shows all sixteen at once, grouped, with no interaction needed to read it.
 * Full screen also meant the settings ran the whole width of a wide monitor,
 * so a row's label and its control ended up a forearm apart.
 *
 * What the full-screen version got right is kept: the keyboard drives
 * everything, and a setting's description prints in its own column rather than
 * under every label at once.
 *
 * Layout:
 *
 *   +----------------------------------------------------------+
 *   |  CONTROL CENTER                                           |
 *   +-----------+-----------------------------+----------------+
 *   | OVERVIEW  |                             |                |
 *   |  Overview |   settings for the          |  what the      |
 *   | SURFACES  |   selected category         |  focused       |
 *   |  Top bar  |   (scrolls, crimson bar)    |  setting does  |
 *   |  Dock     |                             |                |
 *   |  ...      |                             |                |
 *   +-----------+-----------------------------+----------------+
 *   |  [F1] RESTORE DEFAULTS            [ESC] CLOSE             |
 *   +----------------------------------------------------------+
 *
 * Panes are separate files with no knowledge of each other, so adding one is a
 * file plus a line in the model below.
 */
PanelWindow {
    id: root

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "bw77-control-center"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    // Without this the compositor shrinks the surface out of the bar's reserved
    // zone, so the card cannot be centred on the actual screen.
    exclusionMode: ExclusionMode.Ignore

    /*
     * --- categories
     *
     * Grouped, because sixteen flat entries is a list you read rather than a
     * structure you navigate. The groups are how you would go looking: the
     * surfaces first, then how they all look, then the machine underneath.
     *
     * `groups` is what [F1] restores. Most panes map to one settings group;
     * where a pane owns only part of one, it names the keys, because `general`
     * in particular is spread across three different panes and resetting Theme
     * should not reach over and change the interface language.
     */
    readonly property var rail: [
        { group: Settings.t("Overview") },
        { id: "home",          label: Settings.t("Overview"),          source: "HomePane.qml",
          groups: ["general:language"] },

        { group: Settings.t("Surfaces") },
        { id: "bar",           label: Settings.t("Top bar"),           source: "BarPane.qml",
          groups: ["bar", "clock"] },
        { id: "dock",          label: Settings.t("Dock"),              source: "DockPane.qml",
          groups: ["dock"] },
        { id: "desktop",       label: Settings.t("Desktop"),           source: "DesktopPane.qml",
          groups: ["desktop"] },
        { id: "launcher",      label: Settings.t("Launcher"),          source: "LauncherPane.qml",
          groups: ["launcher"] },
        { id: "quickSettings", label: Settings.t("Quick settings"),    source: "QuickSettingsPane.qml",
          groups: ["quickSettings"] },
        { id: "notifications", label: Settings.t("Notifications"),     source: "NotificationPane.qml",
          groups: ["notifications"] },
        { id: "osd",           label: Settings.t("On-screen display"), source: "OsdPane.qml",
          groups: ["osd"] },

        { group: Settings.t("Appearance") },
        { id: "theme",         label: Settings.t("Theme"),             source: "ThemePane.qml",
          groups: ["theme", "general:fontUI,fontIcons,fontSizeBase,textNudge,iconScale,scale"] },
        { id: "wallpaper",     label: Settings.t("Wallpaper"),         source: "WallpaperPane.qml",
          groups: ["wallpaper"] },
        { id: "effects",       label: Settings.t("Effects"),           source: "EffectsPane.qml",
          groups: ["fx", "decoration"] },
        { id: "animations",    label: Settings.t("Animations"),        source: "AnimationsPane.qml",
          groups: ["animations", "general:reducedMotion"] },
        { id: "apps",          label: Settings.t("App theming"),       source: "AppThemePane.qml",
          groups: ["appTheming"] },

        { group: Settings.t("System") },
        { id: "windows",       label: Settings.t("Windows"),           source: "WindowsPane.qml",
          groups: ["borders"] },
        { id: "audio",         label: Settings.t("Audio"),             source: "AudioPane.qml",
          groups: ["audio"] },
        // Nothing on this pane is a setting, so there is nothing to restore.
        { id: "about",         label: Settings.t("About"),             source: "AboutPane.qml",
          groups: [] }
    ]

    // The selectable entries, in rail order. Q and E walk this rather than the
    // rail itself, so a group heading is never something you can land on.
    readonly property var panes: rail.filter(e => e.id !== undefined)

    function paneIndex(id) {
        for (let i = 0; i < panes.length; i++)
            if (panes[i].id === id) return i;
        return 0;
    }

    readonly property var currentPane: panes[paneIndex(Shell.controlCenterTab)]

    /*
     * Nothing dims behind the card.
     *
     * There was a full-screen wash and, before that, two coloured slabs sliding
     * in from the edges. Both fought the card's own entrance: the backdrop was
     * a plain child of the window, so it snapped to full strength while the
     * card was still animating, and on the way out the window is destroyed
     * after a fixed delay rather than when a fade finishes - so the wash sat
     * there at full opacity and then vanished. That mismatch is the glitch.
     *
     * The card is opaque and has a border. It does not need the desktop dimmed
     * to be legible, and without the wash the open is one animation instead of
     * two that disagree.
     */
    MouseArea {
        anchors.fill: parent
        onClicked: Shell.controlCenterOpen = false
    }

    GlitchBox {
        id: anim
        category: "controlCenter"
        anchors.fill: parent
        shown: Shell.controlCenterOpen

        // Bumped once each time the card finishes arriving; every label on it
        // resolves out of noise off this. See CcNav.revealNonce.
        onShownChanged: {
            if (!shown) return;
            CcNav.clearActive();
            keys.usedKeyboard = false;
            keys.resetArmed = false;
            if (!Theme.reducedMotion && Settings.animations.surfaceOpen)
                Qt.callLater(() => CcNav.revealNonce++);
        }

        Panel {
            id: card

            anchors.centerIn: parent
            width: Math.min(1180, root.width - Theme.space6 * 2)
            height: Math.min(760, root.height - Theme.space6 * 2)

            emphasis: "normal"
            serialSeed: "controlcenter"
            padding: Theme.space4

            // Swallows clicks so a press on the card itself does not reach the
            // dismiss catcher behind it.
            MouseArea { anchors.fill: parent }

            /*
             * --- system readings, across the head of the card
             *
             * These replace the "Control Center" title, which was a word the
             * surface did not need: you opened it, you know what it is. The
             * readings are worth the space because they are the only thing here
             * that changes on its own, and because they are useful on every tab
             * rather than only on the one that used to hold them.
             *
             * Four equal cells filling the width - flexbox row, space-evenly,
             * stretch. Sized by division rather than by a Row's spacing so the
             * cells stay equal and the row stays flush at any card width.
             */
            Item {
                id: head
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 96

                // Held for as long as the surface is open, so the four gauges
                // are live on every tab. The Overview pane used to hold this on
                // its own behalf, which is why they only ran on that tab.
                Component.onCompleted: SysMon.acquire()
                Component.onDestruction: SysMon.release()

                readonly property int cellWidth:
                    Math.floor((width - Theme.space4 * 3) / 4)

                Row {
                    anchors.fill: parent
                    spacing: Theme.space4

                    SysGauges {
                        width: head.cellWidth
                        height: head.height
                        label: "CPU"
                        value: SysMon.cpu + "%"
                        fraction: SysMon.cpu / 100
                        tint: Theme.c("chartCpu")
                    }

                    SysGauges {
                        width: head.cellWidth
                        height: head.height
                        label: "RAM"
                        value: SysMon.memUsedLabel + " / " + SysMon.memTotalLabel
                        fraction: SysMon.mem / 100
                        tint: Theme.c("chartRam")
                    }

                    SysGauges {
                        width: head.cellWidth
                        height: head.height
                        label: Settings.t("CPU TEMP")
                        value: SysMon.temp + "\u00B0C"
                        // Capped rather than scaled: a CPU at 100C is at the
                        // top of the gauge, and anything past that is off the
                        // scale in every sense.
                        fraction: Math.min(1, SysMon.temp / 100)
                        tint: Theme.c("chartTemp")
                    }

                    SysGauges {
                        width: head.cellWidth
                        height: head.height
                        label: "DISK"
                        value: SysMon.disk + "%"
                        fraction: SysMon.disk / 100
                        tint: Theme.c("chartNet")
                    }
                }
            }

            Rectangle {
                id: headRule
                anchors.top: head.bottom
                anchors.topMargin: Theme.space3
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: Theme.alpha(Theme.border, 0.9)
            }

            /*
             * --- the rail
             *
             * Scrolls, because sixteen entries plus four headings will not fit
             * a short card on a small display - but at the usual size nothing
             * scrolls and the whole list is simply visible, which is the point
             * of it being vertical.
             */
            Flickable {
                id: railView

                anchors.top: headRule.bottom
                anchors.topMargin: Theme.space3
                anchors.left: parent.left
                anchors.bottom: footRule.top
                anchors.bottomMargin: Theme.space3
                width: 190

                clip: true
                contentWidth: width
                contentHeight: railColumn.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                /*
                 * Bring the selected entry into view after a Q or E.
                 *
                 * Computed from the index rather than measured off the item,
                 * because every row in the rail is the same height - including
                 * the group headings, deliberately, so this arithmetic holds
                 * and there is no need to reach into the Repeater for a
                 * delegate that may not be built yet.
                 */
                readonly property int rowPitch: 31

                function revealTab() {
                    let idx = -1;
                    for (let i = 0; i < root.rail.length; i++)
                        if (root.rail[i].id === Shell.controlCenterTab) { idx = i; break; }
                    if (idx < 0 || contentHeight <= height) return;

                    const top = idx * rowPitch;
                    const bottom = top + rowPitch;
                    const max = Math.max(0, contentHeight - height);

                    if (top < contentY) contentY = Math.max(0, top);
                    else if (bottom > contentY + height) contentY = Math.min(max, bottom - height);
                }

                Column {
                    id: railColumn
                    width: railView.width
                    spacing: 1

                    Repeater {
                        model: root.rail

                        Item {
                            id: entry
                            required property var modelData

                            readonly property bool isGroup: modelData.group !== undefined
                            readonly property bool current:
                                !isGroup && modelData.id === Shell.controlCenterTab

                            width: railColumn.width
                            height: isGroup ? 30 : 30

                            // Group heading. Not selectable, and set apart by
                            // weight rather than by a rule, which would be a
                            // fifth line in a list that is already lines.
                            CyberText {
                                visible: entry.isGroup
                                anchors.left: parent.left
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 4
                                text: entry.modelData.group || ""
                                role: "micro"
                                color: Theme.alpha(Theme.textMuted, 0.8)
                            }

                            NotchRect {
                                anchors.fill: parent
                                anchors.rightMargin: Theme.space2
                                visible: !entry.isGroup
                                    && (entry.current || railMouse.containsMouse)
                                fillColor: entry.current
                                    ? Theme.alpha(Theme.accent, 0.16)
                                    : Theme.alpha(Theme.accent, 0.07)
                                strokeColor: entry.current
                                    ? Theme.accent : "transparent"
                                strokeWidth: entry.current ? Theme.borderWidth : 0
                                notch: 6
                            }

            /*
             * No crimson marker on the selected entry.
             *
             * There was a 3px bar down its left edge, on the reasoning that
             * crimson is what the shell uses for "you are here". The selected
             * entry already says so twice - an accent outline and an accent
             * fill - and the bar landed on top of the outline's left edge in a
             * colour that fights it, so the row read as two overlapping
             * indicators rather than one selection.
             */

                            GlitchText {
                                visible: !entry.isGroup
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.space3
                                anchors.right: parent.right
                                anchors.rightMargin: Theme.space3
                                anchors.verticalCenter: parent.verticalCenter
                                textWidth: parent.width - Theme.space3 * 2
                                text: entry.modelData.label || ""
                                role: "label"
                                elide: Text.ElideRight
                                color: entry.current ? Theme.accent
                                    : (railMouse.containsMouse ? Theme.text : Theme.textDim)
                                decodeTrigger: CcNav.revealNonce
                            }

                            MouseArea {
                                id: railMouse
                                anchors.fill: parent
                                enabled: !entry.isGroup
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.selectTab(entry.modelData.id)
                            }
                        }
                    }
                }

                // Same crimson bar as the panes. `parent` is the Flickable, not
                // its content, or it would scroll along with the list.
                Rectangle {
                    parent: railView
                    x: railView.width - width
                    y: railView.contentHeight > 0
                        ? railView.visibleArea.yPosition * railView.height : 0
                    width: 3
                    height: Math.max(24, railView.visibleArea.heightRatio * railView.height)
                    color: Theme.alpha(Theme.danger, 0.85)
                    visible: railView.contentHeight > railView.height
                }
            }

            Rectangle {
                id: railRule
                anchors.left: railView.right
                anchors.leftMargin: Theme.space3
                anchors.top: railView.top
                anchors.bottom: railView.bottom
                width: 1
                color: Theme.alpha(Theme.border, 0.9)
            }

            // --- settings
            Loader {
                id: paneHost

                anchors.left: railRule.right
                anchors.leftMargin: Theme.space4
                anchors.right: tips.left
                anchors.rightMargin: Theme.space4
                anchors.top: railView.top
                anchors.bottom: railView.bottom

                source: root.currentPane ? root.currentPane.source : "HomePane.qml"

                onSourceChanged: swapIn.restart()

                onLoaded: {
                    // Land on the first setting only for someone already
                    // driving with the keyboard. Doing it unconditionally would
                    // put a highlight and a description on screen for a mouse
                    // user who has not pointed at anything yet.
                    if (keys.usedKeyboard) CcNav.focusEdge(false);
                }

                // Ends by forcing opacity to 1: an interrupted fade would leave
                // the pane invisible with no way back but reopening.
                SequentialAnimation {
                    id: swapIn
                    NumberAnimation {
                        target: paneHost; property: "opacity"
                        from: 0; to: 1
                        // Half the category, so the pane swap stays quicker
                        // than the card's own entrance but still tracks it.
                        duration: Math.max(1, Theme.durationFor("controlCenter") * 0.5)
                        easing.type: Theme.curveFor("controlCenter")
                    }
                    ScriptAction { script: paneHost.opacity = 1 }
                }
            }

            // --- descriptions
            TipsPanel {
                id: tips
                anchors.right: parent.right
                anchors.top: railView.top
                anchors.bottom: railView.bottom
                // Wide enough for a sentence to break twice at most, narrow
                // enough that it never becomes the main column.
                width: Math.max(220, Math.min(280, card.width * 0.24))
            }

            // --- footer
            Rectangle {
                id: footRule
                anchors.bottom: footer.top
                anchors.bottomMargin: Theme.space3
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: Theme.alpha(Theme.border, 0.9)
            }

            Item {
                id: footer
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 28

                CyberText {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: Settings.t("Changes save as you make them")
                    role: "micro"
                    caps: false
                    color: Theme.alpha(Theme.textMuted, 0.8)
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.space5

                    /*
                     * Restore.
                     *
                     * Two presses. This throws away everything on the pane with
                     * no undo, and it is bound to a key that sits alone at the
                     * top-left of the keyboard where it gets hit by accident -
                     * a confirm step costs one keystroke and saves an afternoon
                     * of re-tuning.
                     */
                    Item {
                        height: footer.height
                        width: resetRow.implicitWidth
                        opacity: keys.canReset ? 1 : 0.35

                        Row {
                            id: resetRow
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.space2

                            KeyChip {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "F1"
                            }

                            CyberText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: keys.resetArmed
                                    ? Settings.t("Press again to confirm")
                                    : Settings.t("Restore defaults")
                                role: "label"
                                color: keys.resetArmed ? Theme.danger
                                    : (resetMouse.containsMouse ? Theme.text : Theme.textDim)

                                Behavior on color { ColorAnimation { duration: Theme.durFast } }
                            }
                        }

                        MouseArea {
                            id: resetMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: keys.canReset
                            onClicked: keys.requestReset()
                        }
                    }

                    Item {
                        height: footer.height
                        width: closeRow.implicitWidth

                        Row {
                            id: closeRow
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.space2

                            KeyChip {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "ESC"
                            }

                            CyberText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: Settings.t("Close")
                                role: "label"
                                color: closeMouse.containsMouse ? Theme.text : Theme.textDim

                                Behavior on color { ColorAnimation { duration: Theme.durFast } }
                            }
                        }

                        MouseArea {
                            id: closeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Shell.controlCenterOpen = false
                        }
                    }
                }
            }
        }
    }

    // --- font picker, modal over everything
    Loader {
        id: fontLoader
        anchors.fill: parent
        active: Shell.fontPickerOpen
        z: 100

        sourceComponent: FontPicker {
            title: Shell.fontPickerTitle
            hint: Shell.fontPickerHint
            current: Shell.fontPickerCurrent
            sample: Shell.fontPickerHint.indexOf("Nerd") >= 0
                ? "\uf015 \uf0c9 \uf028 \uf53f \uf05a 0123"
                : "Night City 0123"
            onPicked: (family) => Shell.applyFont(family)
            onCancelled: Shell.closeFontPicker()
        }
    }

    Connections {
        target: Shell
        function onControlCenterOpenChanged() {
            if (Shell.controlCenterOpen) return;
            Shell.closeColorPicker();
            Shell.closeFontPicker();
            CcNav.clearActive();
        }
    }

    function selectTab(id) {
        if (id === Shell.controlCenterTab) return;
        Shell.controlCenterTab = id;
        keys.resetArmed = false;
        railView.revealTab();
    }

    function stepTab(delta) {
        const next = Math.max(0, Math.min(panes.length - 1,
                                          paneIndex(Shell.controlCenterTab) + delta));
        selectTab(panes[next].id);
    }

    /*
     * --- keyboard
     *
     * One handler for the whole surface rather than a focus chain: the panes
     * are built from plain MouseAreas and there is nothing to tab through.
     * The axes are separated by hand -
     *
     *   Q / E        category, up and down the rail
     *   Up / Down    setting, within the category
     *   Left / Right the focused setting's own control
     *   Enter        commit, for the controls where a step makes no sense
     *
     * so no key ever changes meaning depending on where focus happens to be,
     * and there is no mode to be in the wrong one of.
     */
    Item {
        id: keys

        anchors.fill: parent
        focus: true

        // Set by the first navigation keystroke. Until then the surface stays
        // out of the way of a mouse user - nothing is highlighted and the tip
        // panel is empty.
        property bool usedKeyboard: false

        property bool resetArmed: false

        readonly property bool canReset:
            root.currentPane && root.currentPane.groups.length > 0

        Timer {
            id: disarm
            interval: 3500
            onTriggered: keys.resetArmed = false
        }

        function requestReset() {
            if (!canReset) return;

            if (!resetArmed) {
                resetArmed = true;
                disarm.restart();
                return;
            }

            resetArmed = false;
            disarm.stop();
            Settings.resetGroups(root.currentPane.groups);
        }

        function scroll(px) {
            const p = paneHost.item;
            if (p && p.scrollBy) p.scrollBy(px);
        }

        Keys.onPressed: (event) => {
            event.accepted = true;

            // The font picker is modal over the card; while it is up it gets
            // every key, including the ones that would otherwise change tab.
            if (Shell.fontPickerOpen) {
                const picker = fontLoader.item;
                if (picker && picker.handleKey(event)) return;
                event.accepted = false;
                return;
            }

            // So is the colour picker, but it handles its own keys - all this
            // has to do is not steal Escape from it.
            if (Shell.colorPickerOpen) {
                if (event.key === Qt.Key_Escape) Shell.closeColorPicker();
                else event.accepted = false;
                return;
            }

            switch (event.key) {
            case Qt.Key_Escape:
                // Escape backs out of the armed reset before it closes the
                // surface, so cancelling does not also lose your place.
                if (keys.resetArmed) {
                    keys.resetArmed = false;
                    disarm.stop();
                } else {
                    Shell.controlCenterOpen = false;
                }
                return;

            case Qt.Key_F1:
                keys.requestReset();
                return;

            case Qt.Key_Up:
                keys.usedKeyboard = true;
                if (!CcNav.step(-1)) keys.scroll(-90);
                return;

            case Qt.Key_Down:
                keys.usedKeyboard = true;
                if (!CcNav.step(1)) keys.scroll(90);
                return;

            case Qt.Key_Left:
                keys.usedKeyboard = true;
                CcNav.adjust(-1);
                return;

            case Qt.Key_Right:
                keys.usedKeyboard = true;
                CcNav.adjust(1);
                return;

            case Qt.Key_Return:
            case Qt.Key_Enter:
            case Qt.Key_Space:
                keys.usedKeyboard = true;
                CcNav.activate();
                return;

            case Qt.Key_Home:
                keys.usedKeyboard = true;
                CcNav.focusEdge(false);
                return;

            case Qt.Key_End:
                keys.usedKeyboard = true;
                CcNav.focusEdge(true);
                return;

            // Paging moves the view rather than the selection. On a long pane
            // it is the one thing you want when you are looking for a setting
            // rather than changing one.
            case Qt.Key_PageUp:
                keys.scroll(-(paneHost.height - 60));
                return;
            case Qt.Key_PageDown:
                keys.scroll(paneHost.height - 60);
                return;

            case Qt.Key_Tab:
                keys.usedKeyboard = true;
                root.stepTab(1);
                return;
            case Qt.Key_Backtab:
                keys.usedKeyboard = true;
                root.stepTab(-1);
                return;
            }

            // Q and E walk the rail. Matched on text rather than on Key_Q and
            // Key_E so they follow the keyboard layout: on AZERTY the key in
            // that position reports as A, and binding the keycode would put
            // "previous category" somewhere else on the board.
            const ch = event.text.toLowerCase();
            if (ch === "q") {
                keys.usedKeyboard = true;
                root.stepTab(-1);
            } else if (ch === "e") {
                keys.usedKeyboard = true;
                root.stepTab(1);
            } else {
                event.accepted = false;
            }
        }
    }
}
