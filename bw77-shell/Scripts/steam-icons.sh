#!/usr/bin/env bash
# Prints one "<appid><TAB><path>" line per Steam game that has a usable image
# on disk, then exits. One line per app, best available image only.
#
# Why this is needed at all: a running Steam game reports an app id of
# steam_app_<number> and has no desktop entry of its own, so the normal
# entry-then-icon-theme lookup finds nothing and the dock draws the generic
# executable box. The number is the one thing it does tell us, and Steam keeps
# per-game artwork on disk keyed by exactly that number.
#
# Steam has changed the layout of that cache. The older one put everything in a
# single directory as <appid>_icon.jpg; the newer one gives each app its own
# subdirectory. Both are checked, newest layout first, and within an app the
# preference runs from the image that is actually an icon down to the ones that
# are merely square-ish, because a stretched header is still better than a
# generic box.
#
# Icons installed into the hicolor theme as steam_icon_<appid>.png are NOT
# emitted here - those are found through the normal icon theme lookup, which
# handles size selection properly. This is the fallback for everything else.

emit_dir="" # scratch

# Every place a Steam install might be. Flatpak and the various symlink farms
# Valve has shipped over the years all end up pointing at the same content, so
# duplicates are filtered by app id below rather than by path.
roots=(
  "$HOME/.local/share/Steam"
  "$HOME/.steam/steam"
  "$HOME/.steam/root"
  "$HOME/.steam/debian-installation"
  "$HOME/.var/app/com.valvesoftware.Steam/data/Steam"
)

declare -A found=()

# Records the first path seen for an app id. Tiers are walked in preference
# order, so first-wins gives the best available image without any comparison.
keep() {
  local id="$1" path="$2"
  [ -z "$id" ] && return
  [ -n "${found[$id]:-}" ] && return
  [ -r "$path" ] || return
  # Zero-length files show up in this cache when a download was interrupted,
  # and an empty file loads as a broken image rather than falling through.
  [ -s "$path" ] || return
  found["$id"]="$path"
}

for root in "${roots[@]}"; do
  cache="$root/appcache/librarycache"
  [ -d "$cache" ] || continue

  # --- newer layout: one directory per app id
  for dir in "$cache"/*/; do
    [ -d "$dir" ] || continue
    id="${dir%/}"
    id="${id##*/}"
    # Directory names are numeric app ids; anything else here is not an app.
    case "$id" in
      ''|*[!0-9]*) continue ;;
    esac

    for name in icon.jpg icon.png logo.png logo.jpg; do
      keep "$id" "$dir$name"
    done

    # Some builds name the icon after its content hash, so fall back to any
    # file with "icon" in the name before giving up on a real icon.
    if [ -z "${found[$id]:-}" ]; then
      for f in "$dir"*icon*; do
        [ -f "$f" ] && keep "$id" "$f"
      done
    fi

    # Last resort. A header is 460x215, so it will be letterboxed badly in a
    # square dock slot - but it identifies the game, which the fallback box
    # does not.
    for name in library_600x900.jpg header.jpg; do
      keep "$id" "$dir$name"
    done
  done

  # --- older layout: flat files named <appid>_icon.jpg
  for f in "$cache"/*_icon.*; do
    [ -f "$f" ] || continue
    base="${f##*/}"
    id="${base%%_icon.*}"
    case "$id" in
      ''|*[!0-9]*) continue ;;
    esac
    keep "$id" "$f"
  done
done

for id in "${!found[@]}"; do
  printf '%s\t%s\n' "$id" "${found[$id]}"
done
