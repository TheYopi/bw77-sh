import QtQuick
import qs.Config
import qs.Common
import qs.Services

PaneScroll {
    id: pane

    SectionHeader {
        width: pane.innerWidth
        title: Settings.t("Notifications")
        subtitle: Settings.t("Placement, timing and sound")
    }

    SettingRow {
        label: Settings.t("Do not disturb")
        description: Settings.t("Hold everything except critical alerts")
        CyberToggle {
            checked: Settings.notifications.doNotDisturb
            onToggled: (v) => Settings.notifications.doNotDisturb = v
        }
    }

    SettingRow {
        label: Settings.t("Position")
        alternate: true
        CyberDropdown {
            width: 220
            options: [
                { value: "top-left",      label: Settings.t("Top left") },
                { value: "top-center",    label: Settings.t("Top centre") },
                { value: "top-right",     label: Settings.t("Top right") },
                { value: "bottom-left",   label: Settings.t("Bottom left") },
                { value: "bottom-center", label: Settings.t("Bottom centre") },
                { value: "bottom-right",  label: Settings.t("Bottom right") }
            ]
            current: Settings.notifications.position
            onPicked: (v) => Settings.notifications.position = v
        }
    }

    SettingRow {
        label: Settings.t("Keep clear of the bar")
        description: Settings.t("Offsets toasts by the bar height so they do not overlap it")
        CyberToggle {
            checked: Settings.notifications.avoidBar
            onToggled: (v) => Settings.notifications.avoidBar = v
        }
    }

    SettingRow {
        label: Settings.t("Edge margin")
        alternate: true
        CyberSlider {
            width: 240
            from: 0; to: 60; stepSize: 2
            value: Settings.notifications.edgeMargin
            suffix: "px"
            onMoved: (v) => Settings.notifications.edgeMargin = v
        }
    }

    SettingRow {
        label: Settings.t("Animation")
        CyberSelector {
            options: [{ v: "glitch", l: Settings.t("Glitch") },
                      { v: "slide",  l: Settings.t("Slide") },
                      { v: "fade",   l: Settings.t("Fade") }]
            current: Settings.notifications.animation
            onPicked: (v) => Settings.notifications.animation = v
        }
    }

    SettingRow {
        label: Settings.t("Timeout")
        alternate: true
        CyberSlider {
            width: 240
            from: 2000; to: 20000; stepSize: 500
            value: Settings.notifications.timeout
            suffix: "ms"
            onMoved: (v) => Settings.notifications.timeout = v
        }
    }

    SettingRow {
        label: Settings.t("Width")
        CyberSlider {
            width: 240
            from: 260; to: 560; stepSize: 10
            value: Settings.notifications.width
            suffix: "px"
            onMoved: (v) => Settings.notifications.width = v
        }
    }

    SettingRow {
        label: Settings.t("Maximum on screen")
        alternate: true
        CyberSlider {
            width: 240
            from: 1; to: 10; stepSize: 1
            value: Settings.notifications.maxVisible
            onMoved: (v) => Settings.notifications.maxVisible = v
        }
    }

    SectionHeader {
        width: pane.innerWidth
        title: Settings.t("Sound")
        accentColor: Theme.accent
        glitch: false
    }

    SettingRow {
        label: Settings.t("Play a sound")
        description: Settings.t("Set the files below; leave empty for silent notifications")
        CyberToggle {
            checked: Settings.notifications.sound
            onToggled: (v) => Settings.notifications.sound = v
        }
    }

    SettingRow {
        opacity: Settings.notifications.sound ? 1 : 0.45
        label: Settings.t("Volume")
        description: Settings.t("Applied per playback, so it does not touch your system volume")
        CyberSlider {
            width: 240
            // Stored 0..1 because that is what pw-play takes; shown as a
            // percentage because that is what people read.
            from: 0; to: 1; stepSize: 0.05
            value: Settings.notifications.soundVolume
            decimals: 0
            displayScale: 100
            suffix: "%"
            onMoved: (v) => Settings.notifications.soundVolume = v
        }
    }

    SettingRow {
        opacity: Settings.notifications.sound ? 1 : 0.45
        label: Settings.t("Player")
        description: Sounds.supportsVolume(Settings.notifications.soundCommand)
            ? Settings.t("Volume is passed in this player's own units") : "This player is not recognised, so the volume setting will not reach it. "
              + "Known: pw-play, paplay, mpv, ffplay, play"
        alternate: true

        Row {
            spacing: Theme.space2

            NotchRect {
                width: 150
                height: 28
                anchors.verticalCenter: parent.verticalCenter
                fillColor: Theme.alpha(Theme.bgDeep, 0.9)
                strokeColor: Theme.border
                notch: 5

                TextInput {
                    anchors.fill: parent
                    anchors.margins: Theme.space2
                    verticalAlignment: Text.AlignVCenter
                    text: Settings.notifications.soundCommand
                    color: Theme.text
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSmall
                    selectionColor: Theme.accent
                    onEditingFinished: Settings.notifications.soundCommand = text.trim()
                }
            }

            CyberButton {
                anchors.verticalCenter: parent.verticalCenter
                text: Settings.t("Test")
                // Previews through the same path that plays it for real.
                enabled: Settings.notifications.soundFileNormal !== ""
                onClicked: Sounds.play(Settings.notifications.soundFileNormal)
            }
        }
    }

    Repeater {
        model: [
            { label: Settings.t("Normal sound file"), key: "soundFileNormal" },
            { label: Settings.t("Critical sound file"), key: "soundFileCritical" }
        ]

        SettingRow {
            required property var modelData
            label: modelData.label
            alternate: true

            NotchRect {
                width: 320
                height: 28
                fillColor: Theme.alpha(Theme.bgDeep, 0.9)
                strokeColor: Theme.border
                notch: 5

                TextInput {
                    anchors.fill: parent
                    anchors.margins: Theme.space2
                    verticalAlignment: Text.AlignVCenter
                    text: Settings.notifications[modelData.key]
                    color: Theme.text
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSmall
                    selectionColor: Theme.accent
                    onEditingFinished: Settings.notifications[modelData.key] = text
                }
            }
        }
    }
}
