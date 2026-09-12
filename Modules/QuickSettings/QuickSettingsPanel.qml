import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Config
import qs.Common
import qs.Services

/*
 * Quick settings, as an edge panel rather than a popup.
 *
 * Full height on one side of the screen, sections stacked and independently
 * switchable. Order comes from settings, so a section can be moved, hidden or
 * recoloured without any code change here.
 */
PanelWindow {
    id: root

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "bw77-quick-settings"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    readonly property bool onRight: Settings.quickSettings.side === "right"

    // Sections are polled only while the panel is on screen.
    Component.onCompleted: {
        SysState.active = true;
        Audio.devicesActive = true;
    }
    Component.onDestruction: {
        SysState.active = false;
        Audio.devicesActive = false;
        // Closing the panel must stop discovery too, or the adapter keeps
        // scanning in the background with nothing on screen to show for it.
        SysState.setBtScanning(false);
    }

    /*
     * Click-outside-to-close, with nothing drawn.
     *
     * There used to be a wash over the desktop here. It was a plain child of
     * the window rather than part of the sheet's animation, so it snapped to
     * full strength the instant the panel opened while the sheet was still
     * sliding in - and on the way out the window is destroyed after a fixed
     * delay rather than when a fade completes, so the wash sat at full opacity
     * and then disappeared. Two things animating to different clocks is what
     * read as a glitch.
     *
     * The sheet is opaque and bordered; it does not need the desktop dimmed to
     * be legible.
     */
    MouseArea {
        anchors.fill: parent
        onClicked: Shell.quickSettingsOpen = false
    }

    GlitchBox {
        category: "quickSettings"
        id: anim
        anchors.fill: parent
        shown: Shell.quickSettingsOpen

        /*
         * --- how the panel arrives
         *
         * It used to grow: with no direction of its own it fell through to the
         * scale that GlitchBox does by default, and on a sheet that is the full
         * height of the screen a scale reads as the panel stretching from a
         * small box up to full height. Nothing about it said "a drawer came in
         * from the edge", which is what it is.
         *
         * "auto" now resolves to the edge the panel is actually docked to, so
         * a right-hand panel slides in from the right and a left-hand one from
         * the left. Setting Direction explicitly under Animations still wins -
         * ask for a fade or a glitch and that is what you get.
         *
         * `travel` is the sheet's own width rather than GlitchBox's 18px
         * default. That default is tuned for a menu appearing near the pointer,
         * where a small nudge is the whole effect; a panel docked to the screen
         * edge has to come from off-screen or it looks like it twitched.
         */
        // GlitchBox names a direction by where the surface STARTS, not by the
        // way it travels: "right" begins right of its resting place and moves
        // left, which is a drawer entering from the right edge. So the panel
        // names the edge it is docked to.
        autoDirection: root.onRight ? "right" : "left"
        travel: sheet.width

        Item {
            id: sheet
            width: Math.min(Settings.quickSettings.width, root.width - Theme.space4)
            height: root.height
            x: root.onRight ? root.width - width : 0

            /*
             * The same chrome the Control Center card wears - border, corner
             * ticks and scanlines - so the two surfaces read as one system
             * rather than two designs.
             */
            Panel {
                anchors.fill: parent
                fillColor: Theme.bgBase
                /*
                 * No serial here.
                 *
                 * It prints along the bottom edge of the panel, which is where
                 * the pinned calendar sits - so it read as part of the calendar
                 * rather than as chrome on the panel.
                 */
                serial: false
                padding: 0
                notch: Theme.notch * 2

                // Chamfer only the corners facing the screen interior.
                notchTopLeft: root.onRight
                notchBottomLeft: root.onRight
                notchTopRight: !root.onRight
                notchBottomRight: !root.onRight
            }

            // The same decoration the bar and dock draw, on the edge facing the
            // desktop. This used to be a hardcoded crimson gradient, which meant
            // it ignored the style entirely and stayed put while the bar changed.
            EdgeDecoration {
                edge: root.onRight ? "left" : "right"
            }

            Flickable {
                id: scroll
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: pinned.top
                anchors.margins: Theme.space4
                anchors.bottomMargin: pinned.height > 0 ? Theme.space2 : Theme.space4
                contentWidth: width
                contentHeight: column.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: column
                    width: scroll.width
                    spacing: Theme.space3

                    Repeater {
                        model: Settings.quickSettings.sections.filter(
                            sec => !(Settings.quickSettings.pinCalendar && sec.id === "calendar"))

                        Loader {
                            required property var modelData

                            width: column.width
                            active: modelData.enabled === true
                            height: active && item ? item.implicitHeight : 0

                            source: {
                                switch (modelData.id) {
                                case "header":        return "SectionHeaderBlock.qml";
                                case "toggles":       return "SectionToggles.qml";
                                case "volume":        return "SectionVolume.qml";
                                case "brightness":    return "SectionBrightness.qml";
                                case "media":         return "SectionMedia.qml";
                                case "notifications": return "SectionNotifications.qml";
                                case "calendar":      return "SectionCalendar.qml";
                                default:              return "";
                                }
                            }

                            // Each section paints in its configured role, so the
                            // panel can be tuned without editing any section.
                            onLoaded: {
                                if (item.accentRole !== undefined)
                                    item.accentRole = modelData.color || "accent";
                            }
                        }
                    }
                }
            }

            /*
             * Pinned footer.
             *
             * The calendar sits here rather than in the scrolling column so it
             * stays reachable as notification history grows - otherwise the one
             * section with a fixed size is the first thing pushed out of view.
             */
            Item {
                id: pinned
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: Theme.space4
                anchors.topMargin: 0
                height: pinnedLoader.active && pinnedLoader.item
                    ? pinnedLoader.item.implicitHeight : 0

                readonly property var calendarSection:
                    Settings.quickSettings.sections.find(sec => sec.id === "calendar")

                Loader {
                    id: pinnedLoader
                    width: parent.width
                    active: Settings.quickSettings.pinCalendar
                            && pinned.calendarSection !== undefined
                            && pinned.calendarSection.enabled === true
                    source: "SectionCalendar.qml"

                    onLoaded: {
                        if (item.accentRole !== undefined && pinned.calendarSection)
                            item.accentRole = pinned.calendarSection.color || "accent";
                    }
                }
            }

            // Scrollbar, matching the Control Center's.
            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 2
                y: scroll.y + (scroll.contentHeight > 0
                    ? scroll.visibleArea.yPosition * scroll.height : 0)
                width: 3
                height: Math.max(24, scroll.visibleArea.heightRatio * scroll.height)
                color: Theme.alpha(Theme.danger, 0.8)
                visible: scroll.contentHeight > scroll.height
            }
        }
    }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: Shell.quickSettingsOpen = false
    }
}
