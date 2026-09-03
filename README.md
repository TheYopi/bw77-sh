# BW77

A Cyberpunk 2077 inspired desktop shell for Wayland, built on
[Quickshell](https://quickshell.org).

Chamfered panels cut at the top left and bottom right, segmented meters instead
of smooth bars, crimson for structure and cyan for data. Twelve palettes, a top
bar you rearrange by dragging, free-placed desktop widgets, and a Control Center
that configures all of it without ever touching a config file.

Everything here is keyboard navigable, every surface is opaque and bordered, and
the whole shell reads from one settings file you can also just edit by hand.

---

## Features

**Top bar** — thirteen widgets across three sections, dragged between them in the
Control Center. Clock, workspaces, active window, tray, battery, network,
volume, keyboard layout, system monitor, and buttons for the launcher, quick
settings, Control Center and session menu. One text size and one text weight for
the whole bar, with workspace numbers held a step heavier.

**Dock** — pinned and running applications, autohide, right-click menus. Steam
games resolve their real artwork rather than drawing a generic box.

**Desktop widgets** — free-placed on the wallpaper, snapping to a grid from the
top-left corner as you drag and resize. Clock, media player, audio visualiser,
and system monitors that can be placed as one combined block or as separate CPU,
memory, network and GPU widgets. GPU covers AMD, NVIDIA and Intel.

**Quick Settings** — volume and brightness sliders, media player, notification
history, calendar, and tiles for network, Bluetooth, power profile, do not
disturb, sound, mic and reduced motion. Network, Bluetooth and power profile
expand into pickers.

**Control Center** — sixteen categories down a grouped rail, settings in the
middle, and a description of whatever you are on down the right. Panes with more
than three sections fold. Keyboard driven end to end.

**Launcher** — search, categories, keyboard driven, with usage-ordered results.

**Notifications** — full server with toasts, grouping, history and per-app
rules.

**Lock screen** — PAM authentication over `ext-session-lock`.

**Wallpaper** — a full-screen picker with Source, Style and Colour steppers, or
a solid/gradient fill built from the palette. Per-monitor assignment.

**App theming** — writes the current palette out to eighteen other programs, so
your terminal, editor, launcher and GTK apps follow the shell's colours.

**On-screen display** — volume, mute, mic, lock keys and keyboard layout.

**Two languages** — English and Russian, switchable live.

---

## Requirements

### Compositor

A Wayland compositor supporting `wlr-layer-shell` and `ext-session-lock`.

| Compositor | Support |
| --- | --- |
| [niri](https://github.com/YaLTeR/niri) | Full — workspaces, window list, layout switching |
| [Hyprland](https://hyprland.org) | Full — workspaces, window list, layout switching |
| Sway and other wlroots compositors | Everything except workspace and window integration |

The compositor-specific parts live in `Services/Backends/`. Without a matching
backend the shell still runs; the workspace and active-window widgets simply
have nothing to show.

### Required

| Package | Used for |
| --- | --- |
| `quickshell` | The runtime. 0.3 or newer — the power profile tile needs `Quickshell.Services.UPower`, which is not in older builds |
| `bash` 5.0+ | Helper scripts. `EPOCHREALTIME` and associative arrays are both used |
| `jq` | App theming |
| `coreutils`, `awk`, `sed` | System monitor sampling |
| `pipewire`, `wireplumber` | Audio. Volume, mute, per-application streams |
| A Nerd Font | Every icon in the shell. Get this wrong and the icons draw as empty boxes |

### Strongly recommended

| Package | Without it |
| --- | --- |
| `networkmanager` (`nmcli`) | The network widget and tile have nothing to report |
| `bluez`, `bluez-utils` (`bluetoothctl`) | The Bluetooth tile cannot scan or pair |
| `power-profiles-daemon` | The power profile tile shows Balanced and cannot change it |
| `brightnessctl` | The brightness slider does nothing |
| `polkit` | Authentication prompts fall back to whatever else is running |
| `cava` | The audio visualiser widget is empty |
| `ttf-chakra-petch` | Falls back to a default sans face |
| `ttf-jetbrains-mono-nerd` | Icons draw as empty boxes |

### Optional

| Package | Enables |
| --- | --- |
| `nvidia-utils` (`nvidia-smi`) | GPU monitoring on NVIDIA. AMD needs nothing — it reads sysfs directly |
| `xdg-desktop-portal` | The folder picker in the wallpaper pane |
| Any of the theming targets below | App theming writes their config only if they are installed |

### Arch

```sh
# required
sudo pacman -S quickshell jq pipewire wireplumber

# strongly recommended
sudo pacman -S networkmanager bluez bluez-utils power-profiles-daemon \
               brightnessctl polkit cava

# fonts
sudo pacman -S ttf-chakra-petch ttf-jetbrains-mono-nerd

# services
sudo systemctl enable --now NetworkManager bluetooth power-profiles-daemon
```

`quickshell-git` works too if you want master.

### Fedora / openSUSE / Debian

Quickshell is not packaged in most distributions — build it from
[the upstream instructions](https://quickshell.org/docs/master/guide/install-setup/).
Everything else is packaged under roughly the names above (`NetworkManager`,
`bluez`, `power-profiles-daemon`, `brightnessctl`, `polkit`, `cava`,
`pipewire`).

---

## Install

```sh
git clone https://github.com/<you>/bw77 ~/src/bw77
~/src/bw77/Scripts/install.sh
qs -c bw77-shell
```

The installer symlinks the repository into `~/.config/quickshell/bw77-shell`,
creates the state and palette directories under `~/.config/bw77-shell`, and
warns about anything missing. It does not install packages.

Working from a clone means `git pull` updates the shell in place — there is
nothing to copy afterwards.

### Autostart

**niri**, in `config.kdl`:

```kdl
spawn-at-startup "qs" "-c" "bw77-shell"
```

**Hyprland**, in `hyprland.conf`:

```
exec-once = qs -c bw77-shell
```

### Wallpaper in the niri overview

niri draws its overview on a backdrop that shell surfaces are not part of by
default, so the wallpaper has to be opted in by name. Enabling niri under
Control Center → App theming writes this rule for you; otherwise add it to
`config.kdl` yourself:

```kdl
layer-rule {
    match namespace="^bw77-backdrop"
    place-within-backdrop true
}
```

### Keybinds

Nothing is bound for you. The shell exposes everything over IPC, so bind what
you want:

```kdl
// niri
Mod+Space       { spawn "qs" "-c" "bw77-shell" "ipc" "call" "shell" "toggleLauncher"; }
Mod+Shift+S     { spawn "qs" "-c" "bw77-shell" "ipc" "call" "quickSettings" "toggle"; }
Mod+Comma       { spawn "qs" "-c" "bw77-shell" "ipc" "call" "shell" "toggleControlCenter" ""; }
Mod+Shift+W     { spawn "qs" "-c" "bw77-shell" "ipc" "call" "wallpaper" "toggle"; }
Mod+Escape      { spawn "qs" "-c" "bw77-shell" "ipc" "call" "shell" "toggleSession"; }
Mod+L           { spawn "qs" "-c" "bw77-shell" "ipc" "call" "shell" "lock"; }
XF86AudioRaiseVolume { spawn "qs" "-c" "bw77-shell" "ipc" "call" "audio" "volumeUp"; }
XF86AudioLowerVolume { spawn "qs" "-c" "bw77-shell" "ipc" "call" "audio" "volumeDown"; }
XF86AudioMute        { spawn "qs" "-c" "bw77-shell" "ipc" "call" "audio" "toggleMute"; }
```

Full IPC surface:

| Target | Calls |
| --- | --- |
| `shell` | `toggleLauncher`, `toggleSession`, `toggleControlCenter <tab>`, `openControlCenter <tab>`, `lock`, `closeAll`, `build`, `language <code>` |
| `theme` | `set <name>`, `menu`, `current`, `pick <role>`, `pickerState` |
| `wallpaper` | `toggle`, `open`, `close`, `random`, `rescan`, `set <path>`, `current`, `state` |
| `audio` | `toggleMute`, `toggleMicMute`, `volumeUp`, `volumeDown`, `setVolume <percent>` |
| `quickSettings` | `toggle`, `open`, `close` |
| `polkit` | `describe`, `cancel`, `status` |
| `desktop` | `toggleEdit`, `toggleDnd`, `widgets`, `moveWidget <index> <screen>` |

`desktop widgets` prints each widget's stored display next to your real output
names, which is the first thing to check if a widget is not where you expect.

---

## Configuration

Everything is in the Control Center. It writes to
`~/.config/bw77-shell/settings.json`, which you can also edit directly — the
shell reloads it as it changes.

Custom palettes go in `~/.config/bw77-shell/palettes/` as JSON, using the same
shape as the built-ins in `Config/Palettes/`. They appear in the theme switcher
alongside the shipped ones.

### Palettes

`nightcity`, `arasaka`, `militech`, `kang-tao`, `mox`, `maelstrom`,
`valentinos`, `sixth-street`, `kiroshi`, `breach-protocol`, `kuromi`, `animals`.

### App theming

Enable targets under Control Center → App theming. Each writes a config file
when the palette changes:

`alacritty`, `btop`, `cava`, `discord` (Vesktop), `flatpak`, `foot`, `fuzzel`,
`ghostty`, `gtk`, `hyprland`, `kitty`, `libadwaita`, `micro`, `niri`, `qt`,
`starship`, `vscode`, `wezterm`.

Templates live in `Assets/Templates/`. To add a target, drop a template in
there, add a case to `Scripts/apply-theme.sh`, and use `{{role}}`,
`{{role.hex}}`, `{{role.rgb}}` or `{{role.hsl}}` placeholders — every palette
role is available, plus `{{fontUI}}` and `{{fontIcons}}`.

---

## Fonts

Two faces. **Chakra Petch** sets every word in the shell and **JetBrains Mono
Nerd Font** draws every glyph. Change either under Control Center → Theme.

The icon font must be a Nerd Font patched build. It is the one setting that
fails visibly rather than subtly: get it wrong and every icon draws as an empty
box.

Only `role: "icon"` resolves to the icon font. Everything else, including the
monospace readouts, is text and gets the interface face.

**Base text size** drives the whole ramp — micro, small, base, large, title and
huge are ratios of it. **Icon size** is a multiplier on top, defaulting to 1.3,
because a Nerd Font glyph drawn at the text size looks smaller than the text
beside it: glyphs sit inside the em box with their own padding.

**Text vertical trim** is there for patched fonts whose declared metrics do not
match their drawn capitals. The shell centres text on its cap height
automatically, computed from the font at runtime; the trim is a manual nudge if
your face still sits high or low.

---

## Development

```sh
python3 Scripts/qml-check.py .    # brace balance, duplicate assignments, missing functions
python3 Scripts/qml-props.py      # properties assigned to components that do not declare them
qs -c bw77-shell                  # run in a terminal to see load errors
```

Run both before reloading after bulk edits. They catch different things, and
neither is what `qmllint` reports — `qmllint` cannot resolve the `qs.*`
directory modules Quickshell handles its own way, so it has no idea what a
project component declares.

`qml-props.py` exists because of a specific failure: a property assigned to a
component that does not declare it is a **load** error, which takes the whole
file down and renders it as an empty rectangle. The syntax is perfectly valid,
so brace counting passes it happily.

If something renders blank, run `qs -c bw77-shell` from a terminal. The load
error names the file and line.

### Layout

```
Bar/            top bar and its widgets
Common/         shared visual primitives - panels, text, sliders, steppers
Config/         theme tokens, palettes, the settings model, translations
Modules/        one directory per surface
  ControlCenter/  the settings card
  Desktop/        free-placed wallpaper widgets
  Dock/           application dock
  Launcher/       application launcher
  Lock/           session lock
  Media/          shared media body, used by the widget and Quick Settings
  Notifications/  server, toasts and history
  OSD/            on-screen display
  Popups/         bar popups
  QuickSettings/  the side panel
  Session/        session and theme menus
  Wallpaper/      wallpaper layer and picker
Services/        state and system integration
  Backends/       compositor-specific code
Scripts/         helper scripts and the installer
Assets/Templates/ app theming templates
```

---

## Troubleshooting

**Icons are empty boxes.** The icon font is not a Nerd Font patched build.
Control Center → Theme → Icon font.

**A pane in the Control Center is blank.** A QML load error. Run
`qs -c bw77-shell` from a terminal; the error names the file and line.

**The workspace or active window widget is empty.** No compositor backend
matched. Currently niri and Hyprland.

**The power profile tile will not change.** `power-profiles-daemon` is not
running. `systemctl status power-profiles-daemon`. The service exposes no
"installed" flag, so a machine without it looks identical to one sitting on
Balanced.

**No GPU readings.** AMD reads `/sys/class/drm/card*/device` and needs nothing
installed. NVIDIA needs `nvidia-smi`. Intel reports temperature and power only —
utilisation there comes from perf counters, which need elevated privileges a
desktop widget should not ask for. Check with
`bash Scripts/gpu.sh` — it prints one JSON line per interval.

**Steam games show a generic icon.** Check
`bash Scripts/steam-icons.sh` — it prints one line per game it can find artwork
for. Steam has changed its cache layout over the years; both known layouts are
handled, but a listing of `~/.local/share/Steam/appcache/librarycache` is worth
opening an issue with.

**A desktop widget is on the wrong display.** `qs -c bw77-shell ipc call desktop
widgets` prints what is actually stored.
