import QtQuick
import qs.Config
import qs.Common
import qs.Services

/*
 * Push the shell palette into other applications. Each target renders a template
 * from Assets/Templates into that app's config and runs its reload hook.
 */
PaneScroll {
    id: pane

    readonly property var catalog: [
        { key: "gtk",       label: "GTK 3",
          note: "Writes ~/.config/gtk-3.0/gtk.css" },
        { key: "libadwaita", label: "GTK 4 / libadwaita",
          note: "Writes ~/.config/gtk-4.0/gtk.css. Modern GNOME apps such as Nautilus read these names and ignore the GTK 3 ones entirely" },
        { key: "flatpak",   label: Settings.t("Flatpak apps"),
          note: "Copies the GTK colours into every installed Flatpak's own config. Needed because a sandboxed app cannot read the host's gtk.css" },
        { key: "qt",        label: "Qt (qt5ct/qt6ct)", note: "Adds a colour scheme you then select in qt6ct" },
        { key: "kitty",     label: "Kitty",          note: "Writes bw77.conf; include it from kitty.conf" },
        { key: "ghostty",   label: "Ghostty",        note: "Writes a theme file; set theme = bw77" },
        { key: "foot",      label: "Foot",           note: "Writes bw77.ini; include it from foot.ini" },
        { key: "alacritty", label: "Alacritty",      note: "Writes bw77.toml; import it from alacritty.toml" },
        { key: "wezterm",   label: "WezTerm",        note: "Writes a colour scheme file" },
        { key: "btop",      label: "btop",           note: "Writes a theme; select it with btop's menu" },
        { key: "cava",      label: "cava",           note: "Rewrites the cava config and reloads it" },
        { key: "fuzzel",    label: "Fuzzel",         note: "Writes bw77.ini for fuzzel --config" },
        { key: "starship",  label: "Starship",
          note: "Owns ~/.config/starship.toml, since starship reads only that one path. An existing config is backed up to starship.toml.bw77-backup first" },
        { key: "niri",      label: "niri",           note: "Writes bw77.kdl; include it from config.kdl" },
        { key: "hyprland",  label: "Hyprland",       note: "Writes bw77.conf and runs hyprctl reload" },
        { key: "micro",     label: "micro",
          note: "Writes colorschemes/bw77.micro and sets colorscheme in settings.json, editing that one key and leaving the rest of the file alone. Backed up to settings.json.bw77-backup first. Needs a 24-bit terminal; restart micro to see a palette change" },
        { key: "vscode",    label: "VS Code",        note: "Writes a colour theme JSON" },
        { key: "discord",   label: "Discord (Vesktop)", note: "Writes a CSS theme" }
    ]

    function setTarget(key, value) {
        const t = Object.assign({}, Settings.appTheming.targets);
        t[key] = value;
        Settings.appTheming.targets = t;
    }

    SectionHeader {
        width: pane.innerWidth
        title: Settings.t("App theming")
        subtitle: Settings.t("Keep other applications in step with the shell palette")
    }

    SettingRow {
        label: Settings.t("Enable app theming")
        description: Settings.t("Templates are rendered whenever the palette changes")
        CyberToggle {
            checked: Settings.appTheming.enabled
            onToggled: (v) => Settings.appTheming.enabled = v
        }
    }

    SettingRow {
        label: Settings.t("Recolour open terminals")
        description: "Pushes the palette to terminals that are already running, so a theme "
            + "change does not need a restart. Writing config files alone only affects the next one you open."
        CyberToggle {
            checked: Settings.appTheming.liveReload
            onToggled: (v) => Settings.appTheming.liveReload = v
        }
    }

    SettingRow {
        label: Settings.t("Colour vibrance")
        description: "Saturation of the exported terminal palette. A terminal needs eight "
            + "distinguishable hues where the shell has about four, so these are derived "
            + "rather than copied."
        CyberSlider {
            width: 240
            from: 0.4; to: 2.0; stepSize: 0.05
            decimals: 2
            value: Settings.appTheming.vibrance
            onMoved: (v) => Settings.appTheming.vibrance = v
        }
    }

    Row {
        width: pane.innerWidth
        spacing: Theme.space2

        CyberButton {
            text: AppTheme.applying ? Settings.t("Applying\u2026") : Settings.t("Apply now")
            enabled: Settings.appTheming.enabled && !AppTheme.applying
            onClicked: AppTheme.apply()
        }

        CyberText {
            anchors.verticalCenter: parent.verticalCenter
            text: AppTheme.lastResult
            role: "micro"
            caps: false
            color: AppTheme.lastFailed ? Theme.danger : Theme.success
        }
    }

    Repeater {
        model: pane.catalog

        SettingRow {
            required property var modelData
            required property int index

            label: modelData.label
            description: modelData.note
            alternate: index % 2 === 1

            CyberToggle {
                checked: Settings.appTheming.targets[modelData.key] === true
                onToggled: (v) => pane.setTarget(modelData.key, v)
            }
        }
    }

    SectionHeader {
        width: pane.innerWidth
        title: Settings.t("Custom templates")
        accentColor: Theme.accent
        glitch: false
    }

    CyberText {
        width: pane.innerWidth
        text: "Most applications do not read the generated file automatically. GTK and Qt "
            + "pick it up on their own, but terminals need an include line added once: "
            + "kitty wants `include bw77.conf`, foot wants `include=~/.config/foot/bw77.ini`, "
            + "alacritty wants the file in its import list. Check the note under each "
            + "application above."
        role: "body"
        caps: false
        color: Theme.textDim
        wrapMode: Text.Wrap
    }

    CyberText {
        width: pane.innerWidth
        text: "Drop a template into Assets/Templates and add a case to Scripts/apply-theme.sh. "
            + "Placeholders take the form {{accent}}, {{accent.hex}}, {{accent.rgb}} or "
            + "{{accent.hsl}}, and every role in the Theme pane is available. "
            + "{{fontUI}} and {{fontIcons}} carry the font names."
        role: "body"
        caps: false
        color: Theme.textDim
        wrapMode: Text.Wrap
    }
}
