#!/usr/bin/env bash
# Renders every enabled template with the current palette and runs its reload hook.
#
#   apply-theme.sh <templates-dir> <targets-csv> <role=value> [<role=value> ...]
#
# Colours arrive as arguments rather than through a JSON file, so there is no
# dependency on jq and nothing to go stale between the shell and the renderer.
#
# A template is a plain text file containing {{role}} placeholders. Four forms
# are available per role:
#   {{accent}}      -> #2DE2E6
#   {{accent.hex}}  -> 2DE2E6         (no hash; GTK, some editors)
#   {{accent.rgb}}  -> 45,226,230     (comma separated)
#   {{accent.hsl}}  -> 181.6 76.9% 54.1%   (space separated, no commas, no wrapper)
#
# The .hsl form exists for Discord. Discord builds every translucent token in
# the client out of an HSL triplet - hsl(var(--primary-500-hsl)/0.3) is its
# standard hover overlay - so a theme that only replaces the solid colours
# leaves every hover, every divider and every modal scrim on Discord's original
# grey. Handing over the triplet means the derived colours follow the palette
# too. The format is deliberately the bare "H S% L%" that CSS Color 4 expects
# inside hsl(), with no commas and no surrounding function.

set -uo pipefail

templates_dir="${1:?usage: apply-theme.sh <templates-dir> <targets-csv> <role=value>...}"
targets_csv="${2:?missing targets}"
shift 2

[ -d "$templates_dir" ] || { echo "apply-theme: no templates at $templates_dir" >&2; exit 1; }

# Build the substitution script once and reuse it for every target.
sedfile="$(mktemp)"
trap 'rm -f "$sedfile"' EXIT

# Validate every value before writing anything.
#
# These files are sourced by the compositor, and a malformed colour does not
# degrade gracefully - niri refuses the whole config and starts with defaults.
# Better to write nothing and say why than to write something that breaks the
# session.
# Keys whose value is text rather than a colour or a number. Font names have
# spaces in them, so they cannot go through the numeric check below - they get
# their own, narrower one instead of an exemption.
is_text_key() {
  case "$1" in
    fontUI|fontIcons) return 0 ;;
    *) return 1 ;;
  esac
}

invalid=""
for pair in "$@"; do
  key="${pair%%=*}"
  val="${pair#*=}"
  [ -n "$key" ] || continue
  [ "$key" = "BW77_NO_LIVE_RELOAD" ] && continue

  if is_text_key "$key"; then
    # Letters, digits, spaces and a few punctuation marks found in real font
    # names. Everything else is rejected rather than escaped: these values are
    # pasted into a sed replacement and then into a CSS declaration, and the
    # characters that would break either one have no business in a font name.
    case "$val" in
      "") invalid="$invalid $key=<empty>" ;;
      *[!A-Za-z0-9\ ._-]*) invalid="$invalid $key=$val" ;;
      *) ;;
    esac
    continue
  fi

  case "$val" in
    \#[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]) ;;
    \#*) invalid="$invalid $key=$val" ;;
    *[!0-9.-]*) invalid="$invalid $key=$val" ;;
    *) ;;
  esac
done

if [ -n "$invalid" ]; then
  echo "apply-theme: refusing to write, malformed values:$invalid" >&2
  exit 1
fi

# Values are kept as well as substituted: the live-reload step below needs the
# actual colours, not a sed script.
declare -A VALS=()

for pair in "$@"; do
  key="${pair%%=*}"
  val="${pair#*=}"
  [ -n "$key" ] || continue
  # A pseudo-key rather than a colour: keeps the invocation self-contained.
  if [ "$key" = "BW77_NO_LIVE_RELOAD" ]; then
    BW77_NO_LIVE_RELOAD="$val"
    continue
  fi

  VALS["$key"]="$val"
  printf 's|{{%s}}|%s|g\n' "$key" "$val" >> "$sedfile"

  # Colour values also get .hex, .rgb and .hsl forms. Plain values - widths,
  # angles - are substituted as-is and skip the hex parsing entirely.
  case "$val" in
    \#[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f])
      bare="${val#\#}"
      printf 's|{{%s.hex}}|%s|g\n' "$key" "$bare" >> "$sedfile"
      r=$((16#${bare:0:2})); g=$((16#${bare:2:2})); b=$((16#${bare:4:2}))
      printf 's|{{%s.rgb}}|%s,%s,%s|g\n' "$key" "$r" "$g" "$b" >> "$sedfile"

      # awk rather than bash arithmetic: HSL needs real division and bash has
      # integers only. One fork per role, on an action the user takes by hand.
      hsl="$(awk -v r="$r" -v g="$g" -v b="$b" 'BEGIN {
        rr = r/255; gg = g/255; bb = b/255;
        max = rr; if (gg > max) max = gg; if (bb > max) max = bb;
        min = rr; if (gg < min) min = gg; if (bb < min) min = bb;
        l = (max + min) / 2;
        d = max - min;
        if (d == 0) { h = 0; s = 0 }
        else {
          s = (l > 0.5) ? d / (2 - max - min) : d / (max + min);
          if (max == rr)      h = (gg - bb) / d + (gg < bb ? 6 : 0);
          else if (max == gg) h = (bb - rr) / d + 2;
          else                h = (rr - gg) / d + 4;
          h = h * 60;
        }
        printf "%.1f %.1f%% %.1f%%", h, s * 100, l * 100;
      }')"
      printf 's|{{%s.hsl}}|%s|g\n' "$key" "$hsl" >> "$sedfile"
      ;;
  esac
done

applied=0
failed=0

render() {
  local tpl="$templates_dir/$1" dst="$2"
  if [ ! -f "$tpl" ]; then
    echo "apply-theme: missing template $1" >&2
    failed=$((failed+1))
    return 1
  fi
  mkdir -p "$(dirname "$dst")" || { failed=$((failed+1)); return 1; }
  if sed -f "$sedfile" "$tpl" > "$dst.bw77-tmp" && mv "$dst.bw77-tmp" "$dst"; then
    echo "wrote $dst"
    applied=$((applied+1))
  else
    rm -f "$dst.bw77-tmp"
    echo "apply-theme: could not write $dst" >&2
    failed=$((failed+1))
  fi
}

render_quiet() {
  local tpl="$templates_dir/$1" dst="$2"
  [ -f "$tpl" ] || return 1
  mkdir -p "$(dirname "$dst")" || return 1
  sed -f "$sedfile" "$tpl" > "$dst.bw77-tmp" && mv "$dst.bw77-tmp" "$dst"
}

apply_target() {
  case "$1" in
    gtk)
      render gtk.css "$HOME/.config/gtk-3.0/gtk.css"
      ;;
    libadwaita)
      # GTK4 and libadwaita read the same file but a different set of colour
      # names, all of which the template defines.
      render gtk.css "$HOME/.config/gtk-4.0/gtk.css"
      # Ask running apps to re-read it. Most libadwaita apps pick up gtk.css
      # changes on their own; this nudges the ones that do not.
      pkill -SIGHUP -x nautilus 2>/dev/null
      ;;
    flatpak)
      # A Flatpak app cannot read the host's ~/.config/gtk-4.0/gtk.css - the
      # sandbox hands it ~/.var/app/<id>/config as its own ~/.config instead.
      # Writing a copy there themes the app with no permission changes, which
      # is why host-only theming left Nautilus looking untouched.
      if [ ! -d "$HOME/.var/app" ]; then
        echo "apply-theme: no ~/.var/app found, nothing to theme for flatpak" >&2
        failed=$((failed+1))
      else
        count=0
        for appdir in "$HOME"/.var/app/*/; do
          [ -d "$appdir" ] || continue
          for ver in 3.0 4.0; do
            if render_quiet gtk.css "${appdir}config/gtk-${ver}/gtk.css"; then
              count=$((count+1))
            fi
          done
        done
        echo "wrote gtk.css to $count flatpak config path(s)"
        applied=$((applied+1))
      fi
      ;;
    qt)
      render qtct.conf "$HOME/.config/qt6ct/colors/bw77.conf"
      render qtct.conf "$HOME/.config/qt5ct/colors/bw77.conf"
      ;;
    kitty)
      render kitty.conf "$HOME/.config/kitty/bw77.conf"
      pkill -SIGUSR1 -x kitty 2>/dev/null || true
      ;;
    ghostty)   render ghostty        "$HOME/.config/ghostty/themes/bw77" ;;
    foot)      render foot.ini       "$HOME/.config/foot/bw77.ini" ;;
    alacritty) render alacritty.toml "$HOME/.config/alacritty/bw77.toml" ;;
    wezterm)   render wezterm.toml   "$HOME/.config/wezterm/colors/bw77.toml" ;;
    btop)      render btop.theme     "$HOME/.config/btop/themes/bw77.theme" ;;
    fuzzel)    render fuzzel.ini     "$HOME/.config/fuzzel/bw77.ini" ;;
    niri)      render niri.kdl       "$HOME/.config/niri/bw77.kdl" ;;
    starship)
      # starship reads exactly one config path, so theming it means owning that
      # file. Any hand-written config is backed up once, the first time.
      starship_target="$HOME/.config/starship.toml"
      if [ -f "$starship_target" ] && [ ! -f "$starship_target.bw77-backup" ] \
         && ! grep -q "Generated by BW77-Shell" "$starship_target" 2>/dev/null; then
        cp "$starship_target" "$starship_target.bw77-backup"
        echo "backed up your starship.toml to starship.toml.bw77-backup"
      fi
      render starship.toml "$starship_target"
      ;;
    micro)
      # The scheme itself is a drop-in file, like every other target here.
      render micro.micro "$HOME/.config/micro/colorschemes/bw77.micro"

      # Selecting it is the awkward half. Micro has no include mechanism for
      # settings, so `colorscheme` lives in its one settings.json alongside
      # everything else the user has configured - rewriting that file wholesale
      # would throw their settings away.
      #
      # So the value is edited in place and the rest of the file is left byte
      # for byte as it was, with a single backup the first time. Enabling this
      # target is the consent to own that one key; the same bargain the starship
      # target makes with its whole file.
      micro_settings="$HOME/.config/micro/settings.json"
      micro_backup="$micro_settings.bw77-backup"

      # An absent, empty or `{}` file has nothing worth preserving, and the
      # insert below cannot produce valid JSON from `{}` anyway - it would leave
      # a trailing comma before the closing brace, which Go's json parser
      # rejects and micro would then ignore the whole file.
      if [ ! -s "$micro_settings" ] || [ "$(tr -d '[:space:]' < "$micro_settings")" = "{}" ]; then
        mkdir -p "$(dirname "$micro_settings")"
        printf '{\n    "colorscheme": "bw77"\n}\n' > "$micro_settings"
        echo "micro: wrote $micro_settings"

      elif grep -q '"colorscheme"[[:space:]]*:[[:space:]]*"bw77"' "$micro_settings"; then
        : # already ours, nothing to do

      elif grep -q '"colorscheme"' "$micro_settings"; then
        [ -f "$micro_backup" ] || cp "$micro_settings" "$micro_backup"
        # Value only. Anchored to the key so a colourscheme name appearing in
        # some other setting's value is not caught by it.
        sed -i -E 's/("colorscheme"[[:space:]]*:[[:space:]]*)"[^"]*"/\1"bw77"/' \
            "$micro_settings"
        echo "micro: switched colorscheme in settings.json (backup alongside)"

      else
        [ -f "$micro_backup" ] || cp "$micro_settings" "$micro_backup"
        # After the first brace rather than after the first line: a settings
        # file written on one line is common, and inserting a whole line after
        # it would land outside the object.
        sed -i '0,/{/s//{\n    "colorscheme": "bw77",/' "$micro_settings"
        echo "micro: added colorscheme to settings.json (backup alongside)"
      fi
      ;;
    vscode)
      render vscode.json "$HOME/.config/Code/User/globalStorage/bw77-color-theme.json"
      ;;
    discord)
      render discord.css "$HOME/.config/vesktop/themes/bw77.css"
      ;;
    cava)
      render cava.conf "$HOME/.config/cava/config"
      pkill -SIGUSR1 -x cava 2>/dev/null || true
      ;;
    hyprland)
      render hyprland.conf "$HOME/.config/hypr/bw77.conf"
      hyprctl reload >/dev/null 2>&1 || true
      ;;
    *)
      echo "apply-theme: unknown target $1" >&2
      failed=$((failed+1))
      ;;
  esac
}

IFS=','
for t in $targets_csv; do
  [ -n "$t" ] || continue
  apply_target "$t"
done
unset IFS

if [ "$applied" -eq 0 ] && [ "$failed" -eq 0 ]; then
  echo "No targets enabled."
elif [ "$failed" -gt 0 ]; then
  echo "Applied $applied file(s), $failed failed."
else
  
# ---------------------------------------------------------------- live reload
#
# Writing a config file only helps the NEXT terminal you open. To recolour the
# ones already running, the colours are pushed straight to them as OSC escape
# sequences.
#
# The trick is that writing to a pty slave looks to the terminal exactly like
# the program inside it printing those bytes, and every mainstream terminal
# implements OSC 4 (palette), 10 (foreground), 11 (background) and 12 (cursor).
# That covers kitty, foot, alacritty, ghostty, wezterm, xterm and the rest with
# no per-terminal support and no remote-control sockets.
live_reload() {
  [ "${BW77_NO_LIVE_RELOAD:-0}" = "1" ] && return 0

  local seq=""
  local i name
  for i in $(seq 0 15); do
    name="ansi$i"
    [ -n "${VALS[$name]:-}" ] || continue
    seq="${seq}\033]4;${i};${VALS[$name]}\007"
  done

  [ -n "${VALS[termFg]:-}" ] && seq="${seq}\033]10;${VALS[termFg]}\007"
  [ -n "${VALS[termBg]:-}" ] && seq="${seq}\033]11;${VALS[termBg]}\007"
  [ -n "${VALS[cursor]:-}" ] && seq="${seq}\033]12;${VALS[cursor]}\007"

  [ -n "$seq" ] || return 0

  local count=0 pts
  for pts in /dev/pts/*; do
    # Only real, writable pts belonging to this user. /dev/pts/ptmx is the
    # multiplexer and must never be written to.
    [ -w "$pts" ] || continue
    [ -c "$pts" ] || continue
    case "$pts" in */ptmx) continue ;; esac
    [ -O "$pts" ] || continue

    printf '%b' "$seq" > "$pts" 2>/dev/null && count=$((count+1))
  done

  # Terminals that reload their own config from a signal get one too, so their
  # non-colour settings follow as well.
  pkill -SIGUSR1 -x kitty 2>/dev/null
  pkill -SIGUSR1 -x foot  2>/dev/null
  pkill -SIGUSR1 -x cava  2>/dev/null

  [ "$count" -gt 0 ] && echo "recoloured $count open terminal(s) live"
  return 0
}

live_reload

echo "Applied $applied file(s)."
fi
