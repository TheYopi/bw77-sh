import QtQuick
import Quickshell
import qs.Config
import qs.Common
import qs.Services

PaneScroll {
    id: pane

    readonly property bool vertical: Settings.dock.position === "left"
                                  || Settings.dock.position === "right"

    function setPinned(list) { Settings.dock.pinned = list; }

    function movePin(index, delta) {
        const list = Settings.dock.pinned.slice();
        const target = index + delta;
        if (target < 0 || target >= list.length) return;
        const tmp = list[index];
        list[index] = list[target];
        list[target] = tmp;
        setPinned(list);
    }

    PaneGroup {
        width: pane.innerWidth
        title: Settings.t("Dock")
        subtitle: Settings.t("Pinned and running applications")
        expanded: true


        SettingRow {
            label: Settings.t("Show the dock")
            CyberToggle {
                checked: Settings.dock.enabled
                onToggled: (v) => Settings.dock.enabled = v
            }
        }

        SettingRow {
            label: Settings.t("Position")
            alternate: true
            CyberDropdown {
                width: 190
                options: [
                    { value: "bottom", label: Settings.t("Bottom") },
                    { value: "top",    label: Settings.t("Top") },
                    { value: "left",   label: Settings.t("Left") },
                    { value: "right",  label: Settings.t("Right") }
                ]
                current: Settings.dock.position
                onPicked: (v) => Settings.dock.position = v
            }
        }

        SettingRow {
            label: Settings.t("Style")
            description: "Floating is sized to its icons and grows as applications open; "
                + "attached runs the full length of its edge"
            CyberSelector {
                options: [{ v: "floating", l: Settings.t("Floating") }, { v: "attached", l: Settings.t("Attached") }]
                current: Settings.dock.style
                onPicked: (v) => Settings.dock.style = v
            }
        }

        SettingRow {
            label: Settings.t("Alignment")
            // "start" and "end" are stored side-neutral, so the labels have to
            // follow the position or a left-hand dock offers you "Left".
            description: pane.vertical
                ? Settings.t("Where the icons sit down the edge") : Settings.t("Where the icons sit along the edge")
            alternate: true
            CyberSelector {
                options: pane.vertical
                    ? [{ v: "start", l: Settings.t("Top") }, { v: "center", l: Settings.t("Center") },
                      { v: "end", l: Settings.t("Bottom") }]
                    : [{ v: "start", l: Settings.t("Left") }, { v: "center", l: Settings.t("Center") },
                      { v: "end", l: Settings.t("Right") }]
                current: Settings.dock.alignment
                onPicked: (v) => Settings.dock.alignment = v
            }
        }

        SettingRow {
            visible: Settings.dock.style === "floating"
            label: pane.vertical ? Settings.t("Margin above and below") : Settings.t("Margin either side")
            description: Settings.t("Inset from each end of the edge")
            CyberSlider {
                width: 240
                from: 0; to: 200; stepSize: 2
                value: Settings.dock.marginH
                suffix: "px"
                onMoved: (v) => Settings.dock.marginH = v
            }
        }

        SettingRow {
            visible: Settings.dock.style === "floating"
            label: Settings.t("Edge margin")
            description: Settings.t("Gap between the screen edge and the dock")
            alternate: true
            CyberSlider {
                width: 240
                from: 0; to: 60; stepSize: 1
                value: Settings.dock.marginV
                suffix: "px"
                onMoved: (v) => Settings.dock.marginV = v
            }
        }

        // Sharing an edge with the bar is fine while the dock reserves space - the
        // compositor stacks the two zones. A hiding dock reserves nothing, so it
        // steps around the bar itself, and that is worth saying out loud.
        CyberText {
            visible: !pane.vertical
                && Settings.bar.position === Settings.dock.position
                && Settings.dock.hideMode !== "none"
            width: pane.innerWidth
            text: "The bar is on this edge too. The dock is offset to clear it, "
                + "since a hiding dock reserves no space of its own."
            role: "micro"
            caps: false
            color: Theme.warn
            wrapMode: Text.Wrap
        }

        SettingRow {
            label: Settings.t("Icon size")
            CyberSlider {
                width: 240
                from: 20; to: 96; stepSize: 2
                value: Settings.dock.iconSize
                suffix: "px"
                onMoved: (v) => Settings.dock.iconSize = v
            }
        }

        SettingRow {
            label: Settings.t("Icon spacing")
            CyberSlider {
                width: 240
                from: 0; to: 32; stepSize: 1
                value: Settings.dock.spacing
                suffix: "px"
                onMoved: (v) => Settings.dock.spacing = v
            }
        }

        SettingRow {
            label: Settings.t("Padding")
            alternate: true
            CyberSlider {
                width: 240
                from: 0; to: 32; stepSize: 1
                value: Settings.dock.padding
                suffix: "px"
                onMoved: (v) => Settings.dock.padding = v
            }
        }


        SettingRow {
            visible: Settings.dock.style === "floating"
            label: Settings.t("Corner cut")
            alternate: true
            CyberSlider {
                width: 240
                from: 0; to: 28; stepSize: 1
                value: Settings.dock.notch
                suffix: "px"
                onMoved: (v) => Settings.dock.notch = v
            }
        }

        // --- hiding
    }

    PaneGroup {
        width: pane.innerWidth
        title: Settings.t("Hiding")
        accentColor: Theme.accent
        glitch: false
        expanded: false


        SettingRow {
            label: Settings.t("Hide mode")
            description: Settings.t("Always visible reserves screen space; the others reveal on a hot edge")
            CyberSelector {
                options: [{ v: "none", l: Settings.t("Always visible") }, { v: "autohide", l: Settings.t("Autohide") }]
                current: Settings.dock.hideMode
                onPicked: (v) => Settings.dock.hideMode = v
            }
        }

        SettingRow {
            visible: Settings.dock.hideMode !== "none"
            label: Settings.t("Hide delay")
            alternate: true
            CyberSlider {
                width: 240
                from: 0; to: 2000; stepSize: 50
                value: Settings.dock.hideDelay
                suffix: "ms"
                onMoved: (v) => Settings.dock.hideDelay = v
            }
        }

        SettingRow {
            visible: Settings.dock.hideMode !== "none"
            label: Settings.t("Hot edge size")
            description: Settings.t("How much of the dock stays on screen to catch the cursor")
            CyberSlider {
                width: 240
                from: 1; to: 20; stepSize: 1
                value: Settings.dock.revealSize
                suffix: "px"
                onMoved: (v) => Settings.dock.revealSize = v
            }
        }

        // --- behaviour
    }

    PaneGroup {
        width: pane.innerWidth
        title: Settings.t("Behaviour")
        accentColor: Theme.accent
        glitch: false
        expanded: false


        SettingRow {
            label: Settings.t("Magnify on hover")
            description: Settings.t("Lifts the icon under the cursor and its neighbours")
            CyberToggle {
                checked: Settings.dock.magnify
                onToggled: (v) => Settings.dock.magnify = v
            }
        }

        SettingRow {
            visible: Settings.dock.magnify
            label: Settings.t("Magnification")
            alternate: true
            CyberSlider {
                width: 240
                from: 1.0; to: 2.5; stepSize: 0.05
                decimals: 2
                value: Settings.dock.magnifyScale
                onMoved: (v) => Settings.dock.magnifyScale = v
            }
        }

        SettingRow {
            visible: Settings.dock.magnify
            label: Settings.t("Magnification spread")
            description: Settings.t("How many neighbours rise with the hovered icon")
            CyberSlider {
                width: 240
                from: 0; to: 5; stepSize: 1
                value: Settings.dock.magnifyRange
                onMoved: (v) => Settings.dock.magnifyRange = v
            }
        }

        SettingRow {
            label: Settings.t("Click action")
            description: Settings.t("Cycle walks through an application's windows on repeated clicks")
            alternate: true
            CyberSelector {
                options: [{ v: "cycle", l: Settings.t("Cycle windows") }, { v: "activate", l: Settings.t("Focus first") }]
                current: Settings.dock.clickAction
                onPicked: (v) => Settings.dock.clickAction = v
            }
        }

        SettingRow {
            label: Settings.t("Show running applications")
            description: Settings.t("Adds anything running that is not pinned")
            CyberToggle {
                checked: Settings.dock.showRunning
                onToggled: (v) => Settings.dock.showRunning = v
            }
        }

        SettingRow {
            label: Settings.t("Launcher button")
            description: Settings.t("Opens the application launcher, same as the bar button")
            CyberToggle {
                checked: Settings.dock.showLauncher
                onToggled: (v) => Settings.dock.showLauncher = v
            }
        }

        SettingRow {
            visible: Settings.dock.showLauncher
            label: Settings.t("Launcher position")
            alternate: true
            CyberSelector {
                options: [{ v: "start", l: Settings.t("First") }, { v: "end", l: Settings.t("Last") }]
                current: Settings.dock.launcherPosition
                onPicked: (v) => Settings.dock.launcherPosition = v
            }
        }

        SettingRow {
            label: Settings.t("Application actions")
            description: Settings.t("Show the extra entry points an app declares, in the right-click menu")
            CyberToggle {
                checked: Settings.dock.showAppActions
                onToggled: (v) => Settings.dock.showAppActions = v
            }
        }

        SettingRow {
            label: Settings.t("Tooltips")
            CyberToggle {
                checked: Settings.dock.showLabels
                onToggled: (v) => Settings.dock.showLabels = v
            }
        }

    }

    PaneGroup {
        width: pane.innerWidth
        title: Settings.t("Icons and indicators")
        accentColor: Theme.accent
        glitch: false
        expanded: false


        SettingRow {
            label: Settings.t("Recolour icons")
            description: Settings.t("Forces every icon to one palette colour, so a dock of mismatched brand colours reads as one piece")
            CyberToggle {
                checked: Settings.dock.colorizeIcons
                onToggled: (v) => Settings.dock.colorizeIcons = v
            }
        }

        SettingRow {
            visible: Settings.dock.colorizeIcons
            label: Settings.t("Icon colour")
            alternate: true
            Row {
                spacing: Theme.space2

                NotchRect {
                    width: 40
                    height: 26
                    anchors.verticalCenter: parent.verticalCenter
                    fillColor: Settings.dock.iconColorCustom !== ""
                        ? Settings.dock.iconColorCustom
                        : Theme.c(Settings.dock.iconColorRole)
                    strokeColor: Theme.alpha(Theme.text, 0.3)
                    notch: 5
                }

                CyberDropdown {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 190
                    options: ["accent", "accentGlow", "text", "textDim", "danger",
                              "warn", "gold", "magenta", "success"]
                    current: Settings.dock.iconColorRole
                    onPicked: (v) => {
                        Settings.dock.iconColorRole = v;
                        Settings.dock.iconColorCustom = "";
                    }
                }
            }
        }

        SettingRow {
            visible: Settings.dock.colorizeIcons
            label: Settings.t("Recolour strength")
            description: Settings.t("Below 1 keeps some of each icon's own colour")
            CyberSlider {
                width: 240
                from: 0; to: 1; stepSize: 0.05
                decimals: 2
                value: Settings.dock.colorizeStrength
                onMoved: (v) => Settings.dock.colorizeStrength = v
            }
        }

        SettingRow {
            visible: Settings.dock.colorizeIcons
            label: Settings.t("Leave the focused app in colour")
            description: Settings.t("The application with focus keeps its own icon, as a second focus cue")
            alternate: true
            CyberToggle {
                checked: Settings.dock.colorizeFocusedApp
                onToggled: (v) => Settings.dock.colorizeFocusedApp = v
            }
        }

        // --- pinned apps
        SettingRow {
            label: Settings.t("Running indicators")
            alternate: true
            CyberToggle {
                checked: Settings.dock.showIndicators
                onToggled: (v) => Settings.dock.showIndicators = v
            }
        }

        SettingRow {
            label: Settings.t("Icon outlines")
            description: Settings.t("Always keeps them visible at reduced opacity and goes solid on hover")
            CyberSelector {
                options: [{ v: "hover", l: Settings.t("On hover") }, { v: "always", l: Settings.t("Always") },
                { v: "never", l: Settings.t("Never") }]
                current: Settings.dock.itemBorders
                onPicked: (v) => Settings.dock.itemBorders = v
            }
        }

        SettingRow {
            visible: Settings.dock.itemBorders === "always"
            label: Settings.t("Outline resting opacity")
            alternate: true
            CyberSlider {
                width: 240
                from: 0.05; to: 1.0; stepSize: 0.05
                decimals: 2
                value: Settings.dock.itemBorderOpacity
                onMoved: (v) => Settings.dock.itemBorderOpacity = v
            }
        }

        SettingRow {
            visible: Settings.dock.showIndicators
            label: Settings.t("Focused application colour")
            description: Settings.t("Marks the application whose window currently has focus")
            Row {
                spacing: Theme.space2

                NotchRect {
                    width: 40
                    height: 26
                    anchors.verticalCenter: parent.verticalCenter
                    fillColor: Settings.dock.focusedColorCustom !== ""
                        ? Settings.dock.focusedColorCustom
                        : Theme.c(Settings.dock.focusedColorRole)
                    strokeColor: Theme.alpha(Theme.text, 0.3)
                    notch: 5
                }

                CyberDropdown {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 190
                    options: ["gold", "warn", "accent", "danger", "magenta", "success", "text"]
                    current: Settings.dock.focusedColorRole
                    onPicked: (v) => {
                        Settings.dock.focusedColorRole = v;
                        Settings.dock.focusedColorCustom = "";
                    }
                }
            }
        }

    }

    PaneGroup {
        width: pane.innerWidth
        title: Settings.t("Pinned applications")
        subtitle: Settings.t("Right-click any dock icon to pin or unpin it")
        accentColor: Theme.accent
        glitch: false
        expanded: false


        Repeater {
            /*
             * Modelled on the count. See the long note in DesktopPane: these
             * lists hand back a fresh array on every read, so writing to one
             * from its own delegate replaced the model and destroyed the
             * control mid-click - the button worked once and then stopped.
             */
            model: Settings.dock.pinned.length

            SettingRow {
                required property int index

                readonly property string modelData: Settings.dock.pinned[index] || ""

                label: Apps.nameFor(modelData)
                description: modelData
                alternate: index % 2 === 1

                Row {
                    spacing: Theme.space1

                    CyberButton {
                        iconText: "\u25B2"
                        hPadding: Theme.space2
                        onClicked: pane.movePin(index, -1)
                    }
                    CyberButton {
                        iconText: "\u25BC"
                        hPadding: Theme.space2
                        onClicked: pane.movePin(index, 1)
                    }
                    CyberButton {
                        text: Settings.t("Remove")
                        destructive: true
                        onClicked: Apps.unpin(modelData)
                    }
                }
            }
        }

    }

    PaneGroup {
        width: pane.innerWidth
        title: Settings.t("Add an application")
        accentColor: Theme.accent
        glitch: false
        expanded: false


        // Anything running but not pinned, offered as a one-click add.
        Flow {
            width: pane.innerWidth
            spacing: Theme.space2

            Repeater {
                model: Apps.runningIds.filter(id => id !== "" && !Apps.isPinned(id))

                CyberButton {
                    required property string modelData
                    text: Apps.nameFor(modelData)
                    hPadding: Theme.space3
                    onClicked: Apps.pin(modelData)
                }
            }
        }

        CyberText {
            width: pane.innerWidth
            visible: Apps.runningIds.filter(id => id !== "" && !Apps.isPinned(id)).length === 0
            text: Settings.t("Everything currently running is already pinned.")
            role: "micro"
            caps: false
            color: Theme.textMuted
        }
    }
}
