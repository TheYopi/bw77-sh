import QtQuick
import qs.Config
import qs.Common
import qs.Services

/*
 * Window borders belong to the compositor, not the shell, so this page writes
 * them out through the same template pipeline as app theming.
 */
PaneScroll {
    id: pane

    readonly property var roleChoices: [
        "accent", "accentDim", "accentGlow", "danger", "dangerDim",
        "warn", "gold", "magenta", "success", "border", "text", "textDim"
    ]

    SectionHeader {
        width: pane.innerWidth
        title: Settings.t("Windows")
        subtitle: Settings.t("Border colours and width for your compositor")
    }

    SettingRow {
        label: Settings.t("Manage window borders")
        description: Settings.t("Writes border settings into your compositor config. Leave off to keep managing them yourself.")
        CyberToggle {
            checked: Settings.borders.manage
            onToggled: (v) => Settings.borders.manage = v
        }
    }

    CyberText {
        width: pane.innerWidth
        visible: Settings.borders.manage && !Settings.appTheming.enabled
        text: "App theming is switched off, so nothing is written yet. "
            + "Turn it on under App theming and enable your compositor there."
        role: "micro"
        caps: false
        color: Theme.warn
        wrapMode: Text.Wrap
    }

    SettingRow {
        visible: Settings.borders.manage
        label: Settings.t("Border width")
        alternate: true
        CyberSlider {
            width: 240
            from: 0; to: 12; stepSize: 1
            value: Settings.borders.width
            suffix: "px"
            onMoved: (v) => Settings.borders.width = v
        }
    }

    SettingRow {
        visible: Settings.borders.manage
        label: Settings.t("Corner radius")
        description: Settings.t("Hyprland only; niri corner rounding is set in your own config")
        CyberSlider {
            width: 240
            from: 0; to: 20; stepSize: 1
            value: Settings.borders.radius
            suffix: "px"
            onMoved: (v) => Settings.borders.radius = v
        }
    }

    SettingRow {
        visible: Settings.borders.manage
        label: Settings.t("Gradient")
        description: Settings.t("Off uses a single colour for the focused border")
        alternate: true
        CyberToggle {
            checked: Settings.borders.gradient
            onToggled: (v) => Settings.borders.gradient = v
        }
    }

    SettingRow {
        visible: Settings.borders.manage && Settings.borders.gradient
        label: Settings.t("Gradient angle")
        CyberSlider {
            width: 240
            from: 0; to: 360; stepSize: 5
            value: Settings.borders.gradientAngle
            suffix: "\u00B0"
            onMoved: (v) => Settings.borders.gradientAngle = v
        }
    }

    SectionHeader {
        width: pane.innerWidth
        visible: Settings.borders.manage
        title: Settings.t("Colours")
        accentColor: Theme.accent
        glitch: false
    }

    // Each colour row: pick a palette role, or type a literal that overrides it.
    Repeater {
        model: Settings.borders.manage ? [
            { roleKey: "activeFromRole", customKey: "activeFromCustom",
              label: Settings.borders.gradient ? Settings.t("Focused, from") : Settings.t("Focused") },
            { roleKey: "activeToRole", customKey: "activeToCustom",
              label: Settings.t("Focused, to"), gradientOnly: true },
            { roleKey: "inactiveRole", customKey: "inactiveCustom",
              label: Settings.t("Unfocused") },
            { roleKey: "urgentRole", customKey: "urgentCustom",
              label: Settings.t("Urgent") }
        ] : []

        Column {
            id: colourRow
            required property var modelData
            required property int index

            visible: !modelData.gradientOnly || Settings.borders.gradient
            width: pane.innerWidth
            spacing: 1

            SettingRow {
                label: modelData.label
                description: Settings.borders[modelData.customKey] !== ""
                    ? Settings.t("Using a custom colour") : Settings.t("Using a palette role")
                alternate: index % 2 === 1

                Row {
                    spacing: Theme.space2

                    NotchRect {
                        width: 40
                        height: 26
                        anchors.verticalCenter: parent.verticalCenter
                        fillColor: Settings.borders[modelData.customKey] !== ""
                            ? Settings.borders[modelData.customKey]
                            : Theme.c(Settings.borders[modelData.roleKey])
                        strokeColor: Theme.alpha(Theme.text, 0.3)
                        notch: 5
                    }

                    NotchRect {
                        width: 96
                        height: 26
                        anchors.verticalCenter: parent.verticalCenter
                        fillColor: Theme.alpha(Theme.bgDeep, 0.9)
                        strokeColor: Theme.border
                        notch: 5

                        TextInput {
                            anchors.fill: parent
                            anchors.margins: Theme.space2
                            verticalAlignment: Text.AlignVCenter
                            text: Settings.borders[modelData.customKey]
                            color: Theme.text
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSmall
                            selectionColor: Theme.accent

                            onEditingFinished: {
                                if (text === "" || /^#[0-9A-Fa-f]{6}$/.test(text))
                                    Settings.borders[modelData.customKey] = text;
                            }

                            CyberText {
                                visible: parent.text === ""
                                text: "#rrggbb"
                                role: "micro"
                                caps: false
                                color: Theme.textMuted
                            }
                        }
                    }
                }
            }

            // Role picker, hidden once a literal colour is typed above.
            Item {
                width: pane.innerWidth
                height: visible ? 34 : 0
                visible: Settings.borders[colourRow.modelData.customKey] === ""

                CyberDropdown {
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.space3
                    width: 190
                    options: pane.roleChoices
                    current: Settings.borders[colourRow.modelData.roleKey]
                    onPicked: (v) => Settings.borders[colourRow.modelData.roleKey] = v
                }
            }
        }
    }
}
