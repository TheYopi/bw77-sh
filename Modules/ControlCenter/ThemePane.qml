import QtQuick
import Quickshell
import qs.Config
import qs.Common
import qs.Services

/*
 * Palette editor. Every role in the theme is listed with a live swatch; editing
 * one writes an override into settings, which repaints the entire shell
 * immediately because every widget binds to Theme rather than to a literal.
 */
PaneScroll {
    id: pane

    // Roles are grouped so the list reads as a system rather than 30 flat rows.
    readonly property var groups: [
        { name: "Surfaces", roles: ["bgDeep", "bgBase", "bgRaised", "bgOverlay", "bgHover", "bgActive"] },
        { name: "Structure", roles: ["border", "borderStrong", "borderAccent"] },
        { name: "Accents", roles: ["accent", "accentDim", "accentGlow", "danger", "dangerDim",
                                   "warn", "gold", "magenta", "success"] },
        { name: "Text", roles: ["text", "textDim", "textMuted", "textOnAccent", "textDanger"] },
        { name: "Data", roles: ["chartCpu", "chartRam", "chartNet", "chartTemp"] }
    ]

    readonly property var builtins: ["nightcity", "arasaka", "militech", "kang-tao", "mox", "sixth-street",
                                     "animals", "maelstrom", "valentinos", "kuromi", "kiroshi",
                                     "breach-protocol"]

    function setOverride(role, value) {
        const o = Object.assign({}, Settings.theme.overrides);
        o[role] = value;
        Settings.theme.overrides = o;
    }

    function clearOverrides() {
        Settings.theme.overrides = ({});
    }

    function clearOverride(role) {
        const o = Object.assign({}, Settings.theme.overrides);
        delete o[role];
        Settings.theme.overrides = o;
    }

    SectionHeader {
        width: pane.innerWidth
        title: Settings.t("Theme")
        subtitle: Settings.t("Base palette, per-role overrides and typography")
    }

    // --- preset picker
    Flow {
        width: pane.innerWidth
        spacing: Theme.space2

        Repeater {
            model: pane.builtins
            CyberButton {
                required property string modelData
                text: modelData
                active: Settings.theme.name === modelData
                onClicked: {
                    Settings.theme.name = modelData;
                    pane.clearOverrides();
                }
            }
        }

        CyberButton {
            text: Settings.t("Reset overrides")
            destructive: true
            enabled: Object.keys(Settings.theme.overrides || {}).length > 0
            onClicked: pane.clearOverrides()
        }
    }

    SettingRow {
        label: Settings.t("Follow wallpaper")
        description: Settings.t("Derive the accent colours from the current wallpaper instead of the palette file")
        CyberToggle {
            checked: Settings.theme.followWallpaper
            onToggled: (v) => Settings.theme.followWallpaper = v
        }
    }

    // --- role editor
    Repeater {
        model: pane.groups

        Column {
            required property var modelData
            width: pane.innerWidth
            spacing: 1

            SectionHeader {
                width: parent.width
                title: modelData.name
                accentColor: Theme.accent
                glitch: false
            }

            Repeater {
                model: modelData.roles

                SettingRow {
                    id: roleRow
                    required property string modelData
                    required property int index

                    readonly property bool overridden:
                        Settings.theme.overrides && Settings.theme.overrides[modelData] !== undefined

                    label: modelData
                    description: overridden ? Settings.t("Overridden") : Settings.t("From palette")
                    alternate: index % 2 === 1

                    Row {
                        spacing: Theme.space2

                        NotchRect {
                            width: 90
                            height: 26
                            anchors.verticalCenter: parent.verticalCenter
                            fillColor: Theme.alpha(Theme.bgDeep, 0.9)
                            strokeColor: roleRow.overridden ? Theme.warn : Theme.border
                            notch: 5

                            TextInput {
                                anchors.fill: parent
                                anchors.margins: Theme.space2
                                verticalAlignment: Text.AlignVCenter
                                text: String(Theme.c(roleRow.modelData)).toUpperCase()
                                color: Theme.text
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSmall
                                selectionColor: Theme.accent
                                onEditingFinished: {
                                    if (/^#[0-9A-Fa-f]{6}$/.test(text))
                                        pane.setOverride(roleRow.modelData, text);
                                }
                            }
                        }

                        /*
                         * The swatch used to BE the reset control - one click
                         * on the most obvious target in the row silently threw
                         * the override away. It opens the picker now, and
                         * reverting has its own button next to it.
                         */
                        NotchRect {
                            width: 40
                            height: 26
                            anchors.verticalCenter: parent.verticalCenter
                            fillColor: Theme.c(roleRow.modelData)
                            strokeColor: swatchMouse.containsMouse
                                ? Theme.accent : Theme.alpha(Theme.text, 0.3)
                            notch: 5

                            MouseArea {
                                id: swatchMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Shell.requestColor(
                                    roleRow.modelData,
                                    Theme.c(roleRow.modelData),
                                    (hex) => pane.setOverride(roleRow.modelData, hex),
                                    () => pane.clearOverride(roleRow.modelData))
                            }
                        }

                        /*
                         * Revert to the palette value.
                         *
                         * Drawn at full strength whether or not there is
                         * anything to revert. The first version dimmed it to a
                         * quarter opacity over a transparent fill, which on a
                         * dark row came out at about 15% alpha on the border
                         * and nothing else - so on a pane where every role
                         * still says "From palette", the button was invisible
                         * and the swatch looked like the only control in the
                         * row. A disabled button has to still be a button.
                         */
                        NotchRect {
                            width: 28
                            height: 26
                            anchors.verticalCenter: parent.verticalCenter

                            fillColor: roleRow.overridden && resetMouse.containsMouse
                                ? Theme.alpha(Theme.warn, 0.25)
                                : Theme.alpha(Theme.bgDeep, 0.9)
                            strokeColor: roleRow.overridden
                                ? Theme.warn : Theme.alpha(Theme.border, 0.9)
                            notch: 5

                            CyberText {
                                anchors.centerIn: parent
                                // Plain Unicode rather than a Nerd Font glyph:
                                // the mono face is the one thing in the shell a
                                // user is invited to change, and a missing
                                // private-use codepoint draws as a blank box.
                                text: "\u21BA"
                                role: "icon"
                                color: roleRow.overridden ? Theme.warn : Theme.textMuted
                            }

                            MouseArea {
                                id: resetMouse
                                anchors.fill: parent
                                enabled: roleRow.overridden
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: pane.clearOverride(roleRow.modelData)
                            }
                        }
                    }
                }
            }
        }
    }

    SectionHeader {
        width: pane.innerWidth
        title: Settings.t("Typography")
        subtitle: Settings.t("One face for text, one for icons")
        accentColor: Theme.accent
        glitch: false
    }

    SettingRow {
        label: Settings.t("Interface font")
        description: Settings.t("Every word in the shell - headings, labels, menus and readouts")
        FontField {
            title: Settings.t("Interface font")
            hint: Settings.t("Every word in the shell")
            value: Settings.general.fontUI
            sample: "Night City 0123"
            onChanged: (f) => Settings.general.fontUI = f
        }
    }

    SettingRow {
        label: Settings.t("Icon font")
        description: Settings.t("Used only for glyphs. This must be a Nerd Font or every icon in the shell draws as an empty box.")
        alternate: true
        FontField {
            title: Settings.t("Icon font")
            hint: Settings.t("Must be a Nerd Font")
            value: Settings.general.fontIcons
            // Glyphs rather than a pangram: what this font is for is icon
            // coverage, and a row of letters cannot tell you whether it has it.
            sample: "\uf015 \uf0c9 \uf028 \uf53f \uf05a 0123"
            onChanged: (f) => Settings.general.fontIcons = f
        }
    }

    SettingRow {
        label: Settings.t("Icon size")
        description: Settings.t("Multiplies the text size. Nerd Font glyphs never fill their box the way letters do, so icons need to be larger than the text to look the same weight.")
        CyberSlider {
            width: 240
            from: 0.8; to: 2.0; stepSize: 0.05
            decimals: 2
            value: Settings.general.iconScale
            onMoved: (v) => Settings.general.iconScale = v
        }
    }

    SettingRow {
        label: Settings.t("Base text size")
        CyberSlider {
            width: 240
            from: 8; to: 22; stepSize: 1
            value: Settings.general.fontSizeBase
            suffix: "px"
            onMoved: (v) => Settings.general.fontSizeBase = v
        }
    }

    SettingRow {
        label: Settings.t("Text vertical trim")
        description: Settings.t("Text is centred on its capitals automatically; nudge it if your font still sits high or low")
        alternate: true
        CyberSlider {
            width: 240
            from: -4; to: 4; stepSize: 1
            value: Settings.general.textNudge
            suffix: "px"
            onMoved: (v) => Settings.general.textNudge = v
        }
    }

    SettingRow {
        label: Settings.t("Interface scale")
        description: Settings.t("Scales every size in the shell at once, including this window")
        alternate: true
        CyberSlider {
            width: 240
            from: 0.75; to: 1.75; stepSize: 0.05
            decimals: 2
            value: Settings.general.scale
            onMoved: (v) => Settings.general.scale = v
        }
    }
}
