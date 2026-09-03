import QtQuick
import qs.Config
import qs.Common

/*
 * Wallpaper colour controls.
 *
 * Colours are chosen as palette roles rather than fixed values, so switching
 * theme repaints the desktop along with everything else. A literal hex is
 * accepted too, and overrides the role.
 */
Column {
    id: root

    readonly property var roleChoices: [
        "bgDeep", "bgBase", "bgRaised", "bgOverlay", "bgHover", "bgActive",
        "accent", "accentDim", "accentGlow", "danger", "dangerDim",
        "warn", "gold", "magenta", "success", "border"
    ]

    readonly property color fillA: Settings.wallpaper.colorCustom !== ""
        ? Settings.wallpaper.colorCustom
        : Theme.c(Settings.wallpaper.colorRole)

    readonly property color fillB: Settings.wallpaper.colorCustom2 !== ""
        ? Settings.wallpaper.colorCustom2
        : Theme.c(Settings.wallpaper.colorRole2)

    readonly property bool gradient: Settings.wallpaper.colorStyle === "gradient"

    width: parent ? parent.width : 0
    spacing: Theme.space2

    // --- live preview
    NotchRect {
        width: parent.width
        height: 90
        fillColor: root.fillA
        strokeColor: Theme.border
        notch: Theme.notch

        /*
         * Clipping wrapper.
         *
         * The gradient is an oversized square rotated to give the angle, since
         * Gradient itself only runs vertically. Sized to the diagonal so it
         * still covers the box at 45 degrees - which also means it is far wider
         * than the box, and with nothing clipping it, it painted straight over
         * everything around it.
         */
        Item {
            anchors.fill: parent
            clip: true
            visible: root.gradient

            Item {
                anchors.centerIn: parent
                width: Math.sqrt(parent.width * parent.width + parent.height * parent.height)
                height: width
                rotation: Settings.wallpaper.gradientAngle

                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: root.fillA }
                        GradientStop { position: 1.0; color: root.fillB }
                    }
                }
            }
        }

        // Kept inside the frame so the preview reads as a desktop, not a swatch.
        Scanlines { anchors.fill: parent; anchors.margins: 1 }

        CyberText {
            anchors.centerIn: parent
            text: Settings.t("Preview")
            role: "micro"
            color: Theme.alpha(Theme.text, 0.6)
        }
    }

    Row {
        width: parent.width
        spacing: Theme.space2

        CyberText {
            anchors.verticalCenter: parent.verticalCenter
            width: 90
            text: Settings.t("Style")
            role: "label"
            color: Theme.text
        }

        CyberSelector {
            anchors.verticalCenter: parent.verticalCenter
            options: [{ v: "solid", l: Settings.t("Solid") }, { v: "gradient", l: Settings.t("Gradient") }]
            current: Settings.wallpaper.colorStyle
            onPicked: (v) => Settings.wallpaper.colorStyle = v
        }
    }

    // --- the two colour stops
    Repeater {
        model: [
            { label: root.gradient ? Settings.t("From") : Settings.t("Colour"),
              roleKey: "colorRole", customKey: "colorCustom", always: true },
            { label: Settings.t("To"),
              roleKey: "colorRole2", customKey: "colorCustom2", always: false }
        ]

        Row {
            required property var modelData
            visible: modelData.always || root.gradient
            width: root.width
            spacing: Theme.space2

            CyberText {
                anchors.verticalCenter: parent.verticalCenter
                width: 90
                text: modelData.label
                role: "label"
                color: Theme.text
            }

            NotchRect {
                anchors.verticalCenter: parent.verticalCenter
                width: 40
                height: 28
                fillColor: Settings.wallpaper[modelData.customKey] !== ""
                    ? Settings.wallpaper[modelData.customKey]
                    : Theme.c(Settings.wallpaper[modelData.roleKey])
                strokeColor: Theme.alpha(Theme.text, 0.3)
                notch: 5
            }

            CyberDropdown {
                anchors.verticalCenter: parent.verticalCenter
                width: 190
                options: root.roleChoices
                current: Settings.wallpaper[modelData.roleKey]
                onPicked: (v) => {
                    Settings.wallpaper[modelData.roleKey] = v;
                    Settings.wallpaper[modelData.customKey] = "";
                }
            }

            NotchRect {
                anchors.verticalCenter: parent.verticalCenter
                width: 100
                height: 28
                fillColor: Theme.alpha(Theme.bgDeep, 0.9)
                strokeColor: Theme.border
                notch: 5

                TextInput {
                    anchors.fill: parent
                    anchors.margins: Theme.space2
                    verticalAlignment: Text.AlignVCenter
                    text: Settings.wallpaper[modelData.customKey]
                    color: Theme.text
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSmall
                    selectionColor: Theme.accent

                    onEditingFinished: {
                        if (text === "" || /^#[0-9A-Fa-f]{6}$/.test(text))
                            Settings.wallpaper[modelData.customKey] = text;
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

    Row {
        visible: root.gradient
        width: parent.width
        spacing: Theme.space2

        CyberText {
            anchors.verticalCenter: parent.verticalCenter
            width: 90
            text: Settings.t("Angle")
            role: "label"
            color: Theme.text
        }

        CyberSlider {
            anchors.verticalCenter: parent.verticalCenter
            width: 260
            from: 0; to: 360; stepSize: 5
            value: Settings.wallpaper.gradientAngle
            suffix: "\u00B0"
            onMoved: (v) => Settings.wallpaper.gradientAngle = v
        }
    }
}
