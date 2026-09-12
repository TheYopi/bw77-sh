import QtQuick
import qs.Config
import qs.Common
import qs.Services

/*
 * Quick settings layout.
 *
 * Sections are reordered and switched here rather than in code, and each takes
 * its own colour role, so the panel can be rearranged without touching any
 * section file.
 */
PaneScroll {
    id: pane

    readonly property var sectionNames: ({
        "header":        "Clock and shortcuts",
        "toggles":       "Tiles, network and bluetooth",
        "volume":        "Volume",
        "brightness":    "Brightness",
        "media":         "Media player",
        "notifications": "Notifications",
        "calendar":      "Calendar"
    })

    readonly property var elementNames: ({
        "controlCenter": "Control Center button",
        "wallpaper":     "Wallpapers button",
        "theme":         "Palette button",
        "session":       "Session button",
        "network":       "Network tile",
        "bluetooth":     "Bluetooth tile",
        "power":         "Power profile tile",
        "dnd":           "Do not disturb tile",
        "sound":         "Sound tile",
        "mic":           "Microphone tile",
        "reduceMotion":  "Reduce motion tile"
    })

    readonly property var colorChoices: [
        "accent", "accentGlow", "danger", "warn", "gold",
        "magenta", "success", "text", "textDim"
    ]

    function writeSections(list) { Settings.quickSettings.sections = list; }

    function setEnabled(index, value) {
        const list = Settings.quickSettings.sections.slice();
        list[index] = Object.assign({}, list[index], { enabled: value });
        writeSections(list);
    }

    function setColor(index, role) {
        const list = Settings.quickSettings.sections.slice();
        list[index] = Object.assign({}, list[index], { color: role });
        writeSections(list);
    }

    /*
     * Toggles a whole section by id.
     *
     * Sections can already be switched off in the list further down, but the
     * sliders are what people go looking for by name - so the common ones are
     * surfaced here too, driving the same underlying setting rather than a
     * second copy of the state.
     */
    function sectionEnabled(id) {
        const list = Settings.quickSettings.sections;
        for (let i = 0; i < list.length; i++) {
            if (list[i].id === id) return list[i].enabled === true;
        }
        return false;
    }

    function setSectionEnabled(id, value) {
        const list = Settings.quickSettings.sections.slice();
        for (let i = 0; i < list.length; i++) {
            if (list[i].id === id) {
                list[i] = Object.assign({}, list[i], { enabled: value });
                Settings.quickSettings.sections = list;
                return;
            }
        }
    }

    function setElement(listName, index, value) {
        const list = (listName === "headerButtons"
            ? Settings.quickSettings.headerButtons
            : Settings.quickSettings.tiles).slice();

        list[index] = Object.assign({}, list[index], { enabled: value });

        if (listName === "headerButtons") Settings.quickSettings.headerButtons = list;
        else Settings.quickSettings.tiles = list;
    }

    function move(index, delta) {
        const list = Settings.quickSettings.sections.slice();
        const target = index + delta;
        if (target < 0 || target >= list.length) return;
        const tmp = list[index];
        list[index] = list[target];
        list[target] = tmp;
        writeSections(list);
    }

    PaneGroup {
        width: pane.innerWidth
        title: Settings.t("Quick settings")
        subtitle: Settings.t("The side panel opened from the bar or by keybind")
        expanded: true


        SettingRow {
            label: Settings.t("Side")
            CyberSelector {
                // Left first: the stepper reads as an axis, and an axis that
                // starts at "right" is the one thing on the pane that runs backwards.
                options: [{ v: "left", l: Settings.t("Left") }, { v: "right", l: Settings.t("Right") }]
                current: Settings.quickSettings.side
                onPicked: (v) => Settings.quickSettings.side = v
            }
        }

        SettingRow {
            label: Settings.t("Width")
            alternate: true
            CyberSlider {
                width: 240
                from: 280; to: 640; stepSize: 10
                value: Settings.quickSettings.width
                suffix: "px"
                onMoved: (v) => Settings.quickSettings.width = v
            }
        }


        SettingRow {
            label: Settings.t("Pin the calendar")
            description: Settings.t("Keeps it at the bottom of the panel instead of scrolling with history")
            CyberToggle {
                checked: Settings.quickSettings.pinCalendar
                onToggled: (v) => Settings.quickSettings.pinCalendar = v
            }
        }

        SettingRow {
            label: Settings.t("Seconds on the clock")
            CyberToggle {
                checked: Settings.quickSettings.showSeconds
                onToggled: (v) => Settings.quickSettings.showSeconds = v
            }
        }

        // --- notifications
    }

    PaneGroup {
        width: pane.innerWidth
        title: Settings.t("Notification history")
        page: true
        accentColor: Theme.accent
        glitch: false


        SettingRow {
            label: Settings.t("Group by application")
            description: Settings.t("Several messages from one app collapse into a single stacked entry")
            CyberToggle {
                checked: Settings.quickSettings.groupNotifications
                onToggled: (v) => Settings.quickSettings.groupNotifications = v
            }
        }

        SettingRow {
            label: Settings.t("Entries shown")
            alternate: true
            CyberSlider {
                width: 240
                from: 1; to: 15; stepSize: 1
                value: Settings.quickSettings.notificationsShown
                onMoved: (v) => Settings.quickSettings.notificationsShown = v
            }
        }

        SettingRow {
            label: Settings.t("Stored history")
            description: `${NotificationStore.count} kept, oldest dropped past 100`
            CyberButton {
                text: Settings.t("Clear history")
                destructive: true
                enabled: !NotificationStore.empty
                onClicked: NotificationStore.clear()
            }
        }

        // --- individual elements
    }

    PaneGroup {
        width: pane.innerWidth
        title: Settings.t("Sliders")
        page: true
        subtitle: Settings.t("Hide individual controls without turning off a whole section")
        accentColor: Theme.accent
        glitch: false


        Repeater {
            /*
             * Modelled on the count. See the long note in DesktopPane: these
             * lists hand back a fresh array on every read, so writing to one
             * from its own delegate replaced the model and destroyed the
             * control mid-click - the button worked once and then stopped.
             */
            model: Settings.quickSettings.headerButtons.length

            SettingRow {
                required property int index

                readonly property var modelData:
                    Settings.quickSettings.headerButtons[index] || ({})

                label: pane.elementNames[modelData.id] !== undefined
                    ? pane.elementNames[modelData.id] : modelData.id
                alternate: index % 2 === 1

                CyberToggle {
                    checked: modelData.enabled !== false
                    onToggled: (v) => pane.setElement("headerButtons", index, v)
                }
            }
        }

        Repeater {
            /*
             * Modelled on the count. See the long note in DesktopPane: these
             * lists hand back a fresh array on every read, so writing to one
             * from its own delegate replaced the model and destroyed the
             * control mid-click - the button worked once and then stopped.
             */
            model: Settings.quickSettings.tiles.length

            SettingRow {
                required property int index

                readonly property var modelData:
                    Settings.quickSettings.tiles[index] || ({})

                label: pane.elementNames[modelData.id] !== undefined
                    ? pane.elementNames[modelData.id] : modelData.id
                alternate: index % 2 === 0

                CyberToggle {
                    checked: modelData.enabled !== false
                    onToggled: (v) => pane.setElement("tiles", index, v)
                }
            }
        }

        SettingRow {
            label: Settings.t("Microphone slider")
            description: Settings.t("The input level slider under the volume section")
            alternate: true
            CyberToggle {
                checked: Settings.quickSettings.showMicSlider
                onToggled: (v) => Settings.quickSettings.showMicSlider = v
            }
        }

        SettingRow {
            label: Settings.t("Brightness slider")
            description: Brightness.available
                ? Settings.t("The backlight slider") : Settings.t("No backlight detected on this machine")
            CyberToggle {
                checked: pane.sectionEnabled("brightness")
                onToggled: (v) => pane.setSectionEnabled("brightness", v)
            }
        }

        // --- sections
    }

    PaneGroup {
        width: pane.innerWidth
        title: Settings.t("Sections")
        page: true
        subtitle: Settings.t("Order here is the order on the panel")
        accentColor: Theme.accent
        glitch: false


        Repeater {
            /*
             * Modelled on the count. See the long note in DesktopPane: these
             * lists hand back a fresh array on every read, so writing to one
             * from its own delegate replaced the model and destroyed the
             * control mid-click - the button worked once and then stopped.
             */
            model: Settings.quickSettings.sections.length

            SettingRow {
                required property int index

                readonly property var modelData:
                    Settings.quickSettings.sections[index] || ({})

                label: pane.sectionNames[modelData.id] !== undefined
                    ? pane.sectionNames[modelData.id] : modelData.id
                alternate: index % 2 === 1

                Row {
                    spacing: Theme.space2

                    CyberButton {
                        anchors.verticalCenter: parent.verticalCenter
                        iconText: "\u25B2"
                        hPadding: Theme.space2
                        enabled: index > 0
                        onClicked: pane.move(index, -1)
                    }

                    CyberButton {
                        anchors.verticalCenter: parent.verticalCenter
                        iconText: "\u25BC"
                        hPadding: Theme.space2
                        enabled: index < Settings.quickSettings.sections.length - 1
                        onClicked: pane.move(index, 1)
                    }

                    NotchRect {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 26
                        height: 26
                        fillColor: Theme.c(modelData.color || "accent")
                        strokeColor: Theme.alpha(Theme.text, 0.3)
                        notch: 5
                    }

                    CyberDropdown {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 170
                        options: pane.colorChoices
                        current: modelData.color || "accent"
                        onPicked: (v) => pane.setColor(index, v)
                    }

                    CyberToggle {
                        anchors.verticalCenter: parent.verticalCenter
                        showLabel: false
                        checked: modelData.enabled === true
                        onToggled: (v) => pane.setEnabled(index, v)
                    }
                }
            }
        }
    }
}
