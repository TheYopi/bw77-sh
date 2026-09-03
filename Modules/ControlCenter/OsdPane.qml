import QtQuick
import qs.Config
import qs.Common
import qs.Services

PaneScroll {
    id: pane

    SectionHeader {
        width: pane.innerWidth
        title: Settings.t("On-screen display")
        subtitle: Settings.t("The overlay shown when volume or mute changes")
    }

    SettingRow {
        label: Settings.t("Show the OSD")
        CyberToggle {
            checked: Settings.osd.enabled
            onToggled: (v) => Settings.osd.enabled = v
        }
    }

    SettingRow {
        label: Settings.t("Style")
        alternate: true
        CyberSelector {
            options: [{ v: "arc", l: Settings.t("Arc") }, { v: "bar", l: Settings.t("Bar") }]
            current: Settings.osd.style
            onPicked: (v) => Settings.osd.style = v
        }
    }

    SettingRow {
        label: Settings.t("Position")
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
            current: Settings.osd.position
            onPicked: (v) => Settings.osd.position = v
        }
    }

    SettingRow {
        label: Settings.t("Size")
        alternate: true
        CyberSlider {
            width: 240
            from: 90; to: 260; stepSize: 10
            value: Settings.osd.size
            suffix: "px"
            onMoved: (v) => Settings.osd.size = v
        }
    }

    SettingRow {
        label: Settings.t("Show percentage")
        CyberToggle {
            checked: Settings.osd.showPercent
            onToggled: (v) => Settings.osd.showPercent = v
        }
    }

    SettingRow {
        label: Settings.t("Time on screen")
        alternate: true
        CyberSlider {
            width: 240
            from: 600; to: 5000; stepSize: 100
            value: Settings.osd.timeout
            suffix: "ms"
            onMoved: (v) => Settings.osd.timeout = v
        }
    }

    SectionHeader {
        width: pane.innerWidth
        title: Settings.t("Show it when")
        accentColor: Theme.accent
        glitch: false
    }

    SettingRow {
        label: Settings.t("Volume changes")
        CyberToggle {
            checked: Settings.osd.onVolume
            onToggled: (v) => Settings.osd.onVolume = v
        }
    }

    SettingRow {
        label: Settings.t("Output is muted or unmuted")
        alternate: true
        CyberToggle {
            checked: Settings.osd.onMute
            onToggled: (v) => Settings.osd.onMute = v
        }
    }

    SettingRow {
        label: Settings.t("Microphone is muted or unmuted")
        CyberToggle {
            checked: Settings.osd.onMicMute
            onToggled: (v) => Settings.osd.onMicMute = v
        }
    }

    SettingRow {
        label: Settings.t("Lock keys are pressed")
        description: Settings.t("Caps Lock, Num Lock and Scroll Lock. Read from the keyboard's LEDs, which have to be polled - so this costs a small amount of background work while it is on, and nothing at all while it is off.")
        alternate: true
        CyberToggle {
            checked: Settings.osd.onLocks
            onToggled: (v) => Settings.osd.onLocks = v
        }
    }

    SettingRow {
        label: Settings.t("Keyboard layout changes")
        description: Settings.t("Reported by the compositor, so this costs nothing to leave on. Only fires if a layout switch is actually configured.")
        visible: Compositor.keyboardLayouts.length > 1 || Settings.osd.onKeyboardLayout
        CyberToggle {
            checked: Settings.osd.onKeyboardLayout
            onToggled: (v) => Settings.osd.onKeyboardLayout = v
        }
    }

    CyberText {
        width: pane.innerWidth
        visible: Settings.osd.onLocks && Locks.probed && !Locks.available
        leftPadding: Theme.space4
        topPadding: Theme.space2
        text: Settings.t("No keyboard LEDs found under /sys/class/leds, so lock keys cannot be detected on this machine.")
        role: "micro"
        caps: false
        color: Theme.textDanger
        wrapMode: Text.Wrap
    }
}
