import QtQuick
import Quickshell
import qs.Config
import qs.Common
import qs.Services

PaneScroll {
    id: pane

    SectionHeader {
        width: pane.innerWidth
        title: Settings.t("About")
        // Bumped whenever the config changes, so "is the shell actually running
        // the files I just copied in" is a question you can answer by looking.
        subtitle: "bw77-shell \u00B7 config 2026-08-19"
    }

    Repeater {
        model: [
            { k: "Config directory", v: Settings.configDir },
            { k: "Shell directory",  v: Quickshell.shellDir },
            { k: "Compositor",       v: Compositor.kindName },
            { k: "Displays",         v: String(Quickshell.screens.length) },
            { k: "Palette",          v: Settings.theme.name }
        ]

        SettingRow {
            required property var modelData
            required property int index
            label: modelData.k
            alternate: index % 2 === 1

            CyberText {
                width: 380
                elide: Text.ElideLeft
                text: modelData.v
                role: "mono"
                caps: false
                font.pixelSize: Theme.fontSmall
                color: Theme.textDim
            }
        }
    }

    SectionHeader {
        width: pane.innerWidth
        title: Settings.t("Authentication agent")
        subtitle: Settings.t("Handles the password prompt for privileged actions")
        accentColor: Theme.accent
        glitch: false
    }

    SettingRow {
        label: Settings.t("Act as the polkit agent")
        description: "Only one agent may run per session. Disable polkit-gnome, "
            + "polkit-kde or any other agent first, or registration will fail."
        CyberToggle {
            checked: Settings.polkit.enabled
            onToggled: (v) => Settings.polkit.enabled = v
        }
    }

    SettingRow {
        visible: Settings.polkit.enabled
        label: Settings.t("Status")
        alternate: true
        CyberText {
            text: !Polkit.supported
                ? "Module unavailable in this build"
                : (Polkit.registered
                    ? Settings.t("Registered") : Settings.t("Another agent is already running"))
            role: "micro"
            caps: false
            color: Polkit.registered ? Theme.success : Theme.textDanger
        }
    }

    SectionHeader {
        width: pane.innerWidth
        title: Settings.t("Keybinds to set in your compositor")
        accentColor: Theme.accent
        glitch: false
    }

    Repeater {
        model: [
            "qs -c bw77-shell ipc call shell toggleLauncher",
            "qs -c bw77-shell ipc call shell toggleControlCenter home",
            "qs -c bw77-shell ipc call shell toggleSession",
            "qs -c bw77-shell ipc call shell lock",
            "qs -c bw77-shell ipc call quickSettings toggle",
            "qs -c bw77-shell ipc call theme menu",
            "qs -c bw77-shell ipc call audio toggleMute",
            "qs -c bw77-shell ipc call audio toggleMicMute",
            "qs -c bw77-shell ipc call audio volumeUp",
            "qs -c bw77-shell ipc call desktop toggleDnd",
            "qs -c bw77-shell ipc call wallpaper random",
            "qs -c bw77-shell ipc show   # lists everything available"
        ]

        CyberText {
            required property string modelData
            width: pane.innerWidth
            text: modelData
            role: "mono"
            caps: false
            font.pixelSize: Theme.fontSmall
            color: Theme.textDim
        }
    }
}
