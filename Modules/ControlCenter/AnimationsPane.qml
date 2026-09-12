import QtQuick
import qs.Config
import qs.Common

PaneScroll {
    id: pane

    SectionHeader {
        width: pane.innerWidth
        title: Settings.t("Animations")
        subtitle: Settings.t("Cyberpunk motion snaps rather than eases; speed scales every duration")
    }

    SettingRow {
        label: Settings.t("Speed")
        description: Theme.reducedMotion
            ? "Motion is off"
            : `A ${Math.round(Theme.durNormal)}ms transition at this setting`
        CyberSlider {
            width: 260
            from: 0; to: 3; stepSize: 0.05
            decimals: 2
            value: Settings.animations.speed
            barColor: Settings.animations.speed <= 0 ? Theme.danger : Theme.accent
            onMoved: (v) => Settings.animations.speed = v
        }
    }

    SettingRow {
        label: Settings.t("Reduce motion")
        description: Settings.t("Overrides everything below and disables all animation")
        alternate: true
        CyberToggle {
            checked: Settings.general.reducedMotion
            onToggled: (v) => Settings.general.reducedMotion = v
        }
    }

    SectionHeader {
        width: pane.innerWidth
        title: Settings.t("Individual effects")
        accentColor: Theme.accent
        glitch: false
    }

    Repeater {
        model: [
            { key: "surfaceOpen", label: Settings.t("Surface open"),
              hint: "Panels and popups scale in when they appear" },
            { key: "textDecode", label: Settings.t("Text decode"),
              hint: "Characters scramble before settling when a value changes" },
            { key: "workspaceMorph", label: Settings.t("Workspace pips"),
              hint: "The focused pip widens instead of switching instantly" },
            { key: "barHover", label: Settings.t("Bar hover"),
              hint: "Widgets fill behind the cursor" },
            { key: "notificationEntry", label: Settings.t("Notification entry"),
              hint: "Toasts animate in; the style is set on the Notifications tab" },
            { key: "wallpaperTransition", label: Settings.t("Wallpaper transition"),
              hint: "Cross-fade or glitch when the wallpaper changes" }
        ]

        SettingRow {
            required property var modelData
            required property int index

            label: modelData.label
            description: modelData.hint
            alternate: index % 2 === 1

            CyberToggle {
                checked: Settings.animations[modelData.key] === true
                onToggled: (v) => Settings.animations[modelData.key] = v
            }
        }
    }

    SectionHeader {
        width: pane.innerWidth
        title: Settings.t("Motion by category")
        subtitle: Settings.t("Curve, length and entry direction for each surface family")
        accentColor: Theme.accent
        glitch: false
    }

    /*
     * One block per surface family.
     *
     * Built from Theme.motionCategories rather than written out, so a category
     * added there appears here with its defaults and needs no work in this
     * file. Only fields the user actually changes are stored; the rest fall
     * through to Theme.motionDefaults.
     */
    Repeater {
        model: [
            { key: "dock",          label: Settings.t("Dock"),
              hint: "The dock's reveal slide, its icon hovers and its right-click menu" },
            { key: "bar",           label: Settings.t("Top bar"),
              hint: "Workspace pips and the popups the bar widgets open" },
            { key: "osd",           label: Settings.t("On-screen display"),
              hint: "The volume, mute and lock-key overlay" },
            { key: "notifications", label: Settings.t("Notifications"),
              hint: "Toast entry and the slide when the stack reflows" },
            { key: "quickSettings", label: Settings.t("Quick settings"),
              hint: "The quick settings panel" },
            { key: "controlCenter", label: Settings.t("Control Center"),
              hint: "This window, and the crossfade between its panes" },
            { key: "launcher",      label: Settings.t("Launcher"),
              hint: "The application launcher" },
            { key: "menus",         label: Settings.t("Menus"),
              hint: "Session menu, polkit prompt, colour picker, wallpaper picker" },
            { key: "tooltip",       label: Settings.t("Tooltips"),
              hint: "The label that appears beside a dock icon under the pointer" },
            { key: "wallpaper",     label: Settings.t("Wallpaper"),
              hint: "The swap when the wallpaper changes" },
            { key: "theme",         label: Settings.t("Theme"),
              hint: "The palette switcher" }
        ]

        Column {
            id: cat

            required property var modelData
            required property int index

            width: pane.innerWidth
            spacing: 0

            readonly property string key: modelData.key
            readonly property bool customised:
                Settings.animations.motion && Settings.animations.motion[cat.key] !== undefined

            Item { width: 1; height: Theme.space3 }

            Row {
                width: pane.innerWidth
                spacing: Theme.space2

                CyberText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: cat.modelData.label
                    role: "label"
                    color: Theme.accent
                }

                CyberText {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: cat.customised
                    text: Settings.t("Overridden")
                    role: "micro"
                    color: Theme.warn
                }

                CyberButton {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: cat.customised
                    text: Settings.t("Reset")
                    hPadding: Theme.space2
                    onClicked: Settings.resetMotion(cat.key)
                }
            }

            // What this category actually moves. Without it the ten headings
            // are just surface names, and there is no way to tell from the pane
            // which of them owns, say, the workspace pips.
            CyberText {
                width: pane.innerWidth
                text: cat.modelData.hint
                role: "micro"
                caps: false
                color: Theme.textDim
                wrapMode: Text.Wrap
            }

            SettingRow {
                width: pane.innerWidth
                label: Settings.t("Curve")
                CyberSelector {
                    options: Theme.curveNames.map(c => ({ v: c, l: c }))
                    current: Theme.motionOf(cat.key, "curve")
                    onPicked: (v) => Settings.setMotion(cat.key, "curve", v)
                }
            }

            SettingRow {
                width: pane.innerWidth
                label: Settings.t("Direction")
                description: Settings.t("Auto follows the edge the surface opens from")
                alternate: true
                CyberSelector {
                    options: Theme.directionNames.map(d => ({ v: d, l: Settings.t(d) }))
                    current: Theme.motionOf(cat.key, "direction")
                    onPicked: (v) => Settings.setMotion(cat.key, "direction", v)
                }
            }

            SettingRow {
                width: pane.innerWidth
                label: Settings.t("Duration")
                // The scaled figure, not the stored one: with speed at 0.5 a
                // 200ms setting actually runs for 100ms, and that is the number
                // worth showing.
                description: Theme.reducedMotion
                    ? Settings.t("Motion is off")
                    : Theme.durationFor(cat.key) + "ms " + Settings.t("after speed")
                CyberSlider {
                    width: 240
                    from: 40; to: 900; stepSize: 10
                    suffix: "ms"
                    value: Theme.motionOf(cat.key, "duration")
                    onMoved: (v) => Settings.setMotion(cat.key, "duration", v)
                }
            }
        }
    }
}
