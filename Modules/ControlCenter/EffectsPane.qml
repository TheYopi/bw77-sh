import QtQuick
import qs.Config
import qs.Common

PaneScroll {
    id: pane

    SectionHeader {
        width: pane.innerWidth
        title: Settings.t("Effects")
        subtitle: Settings.t("The parts that make it feel like a screen inside the game")
    }

    SettingRow {
        label: Settings.t("Scanlines")
        description: Settings.t("Horizontal CRT lines over panels and the desktop")
        CyberToggle {
            checked: Settings.fx.scanlines
            onToggled: (v) => Settings.fx.scanlines = v
        }
    }

    SettingRow {
        label: Settings.t("Scanline strength")
        alternate: true
        CyberSlider {
            width: 240
            from: 0; to: 0.2; stepSize: 0.005
            decimals: 3
            value: Settings.fx.scanlineOpacity
            onMoved: (v) => Settings.fx.scanlineOpacity = v
        }
    }

    SettingRow {
        label: Settings.t("Scanline drift")
        description: Settings.t("Slow vertical sweep across the lines. Reads as a live signal on a full screen and is imperceptible inside a small panel, so it only runs on the large surfaces.")
        CyberToggle {
            checked: Settings.fx.scanlineDrift
            onToggled: (v) => Settings.fx.scanlineDrift = v
        }
    }

    SettingRow {
        label: Settings.t("Drift speed")
        description: Settings.t("Seconds for one pass. Lower is faster.")
        alternate: true
        CyberSlider {
            width: 240
            // Inverted so the slider reads as speed while the setting stores a
            // duration: dragging right on something labelled "speed" has to
            // make it faster.
            from: 800; to: 6000; stepSize: 100
            decimals: 1
            displayScale: 0.001
            suffix: "s"
            enabled: Settings.fx.scanlineDrift
            value: Settings.fx.scanlineDriftDuration
            onMoved: (v) => Settings.fx.scanlineDriftDuration = v
        }
    }

    SettingRow {
        label: Settings.t("Decode animation")
        description: Settings.t("Text scrambles before settling when a value changes")
        CyberToggle {
            checked: Settings.fx.glitchOnOpen
            onToggled: (v) => Settings.fx.glitchOnOpen = v
        }
    }

    SettingRow {
        label: Settings.t("Corner brackets")
        description: Settings.t("Small L-marks at the corners of framed content")
        alternate: true
        CyberToggle {
            checked: Settings.fx.cornerTicks
            onToggled: (v) => Settings.fx.cornerTicks = v
        }
    }

    SettingRow {
        label: Settings.t("Serial numbers")
        description: Settings.t("Fake machine identifiers printed on panels")
        CyberToggle {
            checked: Settings.fx.telemetryText
            onToggled: (v) => Settings.fx.telemetryText = v
        }
    }

    SectionHeader {
        width: pane.innerWidth
        title: Settings.t("Frame decoration")
        subtitle: Settings.t("Shared by the top bar, quick settings panel and dock")
        accentColor: Theme.accent
        glitch: false
    }

    SettingRow {
        label: Settings.t("Style")
        description: "Line fades in from both ends; solid runs the full length; "
            + "border outlines the whole surface"
        CyberSelector {
            options: [{ v: "line", l: Settings.t("Line") }, { v: "solid", l: Settings.t("Solid") },
            { v: "border", l: Settings.t("Border") }, { v: "none", l: Settings.t("None") }]
            current: Settings.decoration.style
            onPicked: (v) => Settings.decoration.style = v
        }
    }

    SettingRow {
        visible: Settings.decoration.style !== "none"
        label: Settings.t("Colour")
        alternate: true
        Row {
            spacing: Theme.space2

            NotchRect {
                width: 40
                height: 26
                anchors.verticalCenter: parent.verticalCenter
                fillColor: Settings.decoration.colorCustom !== ""
                    ? Settings.decoration.colorCustom
                    : Theme.c(Settings.decoration.colorRole)
                strokeColor: Theme.alpha(Theme.text, 0.3)
                notch: 5
            }

            CyberDropdown {
                anchors.verticalCenter: parent.verticalCenter
                width: 190
                options: ["danger", "accent", "accentGlow", "warn", "gold",
                          "magenta", "success", "border"]
                current: Settings.decoration.colorRole
                onPicked: (v) => {
                    Settings.decoration.colorRole = v;
                    Settings.decoration.colorCustom = "";
                }
            }
        }
    }

    SettingRow {
        visible: Settings.decoration.style !== "none"
        label: Settings.t("Thickness")
        CyberSlider {
            width: 240
            from: 1; to: 6; stepSize: 1
            value: Settings.decoration.thickness
            suffix: "px"
            onMoved: (v) => Settings.decoration.thickness = v
        }
    }

    SettingRow {
        visible: Settings.decoration.style === "line"
        label: Settings.t("Fade length")
        description: Settings.t("How far the rule fades in from each end")
        alternate: true
        CyberSlider {
            width: 240
            from: 0; to: 0.45; stepSize: 0.01
            decimals: 2
            value: Settings.decoration.fade
            onMoved: (v) => Settings.decoration.fade = v
        }
    }
}
