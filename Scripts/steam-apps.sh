#!/usr/bin/env bash
# Prints one "<appid><TAB><icon path><TAB><name>" line per Steam app this
# machine knows anything about, then exits. Either of the last two fields may
# be empty; an app with neither is not printed at all.
#
# Why this is needed at all: a running Steam game reports an app id of
# steam_app_<number> and has no desktop entry of its own, so the normal
# entry-then-icon-theme lookup finds nothing. The dock drew the generic
# executable box and captioned it "STEAM_APP_1091500", because the numeric id
# is the only thing the window itself will say. Both answers are on disk,
# keyed by exactly that number - the artwork in the library cache, the name in
# the install manifest - and this prints them together.
#
# The two come from different trees and neither is a subset of the other: a
# game can have cached artwork long after it is uninstalled, and a game
# installed on a second drive has a manifest before its artwork is fetched.
# So the union is emitted and each field stands alone.
#
# Steam has changed the layout of that cache three times now, and all three are
# checked, newest first. Within an app the preference runs from the image that
# is actually an icon down to the ones that are merely square-ish, because a
# stretched header is still better than a generic box.
#
#   1. Current. One directory per app id, and the icon inside it is named after
#      its own content hash with no hint of what it is:
#
#          librarycache/570/6b0312cda02f5f777efa2f3318c307ff9acafbb5.jpg
#
#      This is the layout that matters, and it is the one this script used to
#      miss completely. It looked for icon.jpg, then for anything with "icon"
#      in the name, then for library_600x900.jpg or header.jpg - and a
#      hash-named file matches none of those. On a 379-app library, 316 apps
#      (83%) produced no line at all, so the dock fell through to Steam's own
#      client icon for almost every game. That is the bug this tier fixes.
#
#      There is exactly one such file per app directory and it is always the
#      square icon - 38x38 and 700 bytes at the low end, 1500x1500 at the high
#      end - so no size or dimension test is needed to pick it out. Being
#      hex and long is enough to tell it apart from every name Steam gives the
#      wide artwork, none of which are hex.
#
#   2. Named artwork in the same directory: library_600x900.jpg, header.jpg and
#      friends, plus one level down into the <hash>/ subdirectories Steam also
#      keeps there. Letterboxed in a square dock slot, so these rank below a
#      real icon - but they identify the game, which the fallback box does not.
#
#   3. Oldest. A flat directory of <appid>_icon.jpg.
#
# Icons installed into the hicolor theme as steam_icon_<appid>.png are NOT
# emitted here - those are found through the normal icon theme lookup, which
# handles size selection properly. This is the fallback for everything else.

# Steam names the icon after its content hash: hex, and far longer than any
# word it uses for the wide artwork. Matched with the shell's own regex rather
# than a call out to `file` or a dimension check, because this runs once per
# app directory and there are several hundred of them.
is_hashed_name() {
  [[ "$1" =~ ^[0-9a-f]{32,}$ ]]
}

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

declare -A found=()   # appid -> icon path
declare -A names=()   # appid -> display name

# ---------------------------------------------------------------- names
#
# The name lives in steamapps/appmanifest_<appid>.acf, next to the game rather
# than next to the artwork - and "next to the game" is not necessarily under
# any of the roots above. A second drive is the normal case, not an exotic one:
# on the machine this was written against the Steam install holds exactly one
# manifest and the other thirty-eight are on an external SSD. Reading only the
# default steamapps directory would have named one game out of thirty-nine.
#
# libraryfolders.vdf is the index of those drives. It has moved between
# steamapps/ and config/ across client versions, so both are read.

declare -A libs=()

scan_library_index() {
  local vdf="$1" line
  [ -r "$vdf" ] || return
  while IFS= read -r line; do
    # "path"		"/run/media/user/2TB_SSD/SteamLibrary"
    if [[ "$line" =~ ^[[:space:]]*\"path\"[[:space:]]+\"(.*)\"[[:space:]]*$ ]]; then
      libs["${BASH_REMATCH[1]}"]=1
    fi
  done < "$vdf"
}

# Sets names[$id] from a manifest. The app id comes from the filename rather
# than from the file, which saves reading past the line that is wanted.
#
# Deliberately anchored on a line that is nothing but the "name" key: the
# manifest has nested sections further down that carry their own, and a loose
# match would hand back a depot label. The real one is the fourth line, so
# stopping at the first hit is both correct and cheap.
read_manifest_name() {
  local f="$1" id="$2" line value
  while IFS= read -r line; do
    if [[ "$line" =~ ^[[:space:]]*\"name\"[[:space:]]+\"(.*)\"[[:space:]]*$ ]]; then
      value="${BASH_REMATCH[1]}"
      # The output is tab separated and one record per line, so a name
      # carrying either would corrupt the stream rather than just look wrong.
      value="${value//$'\t'/ }"
      value="${value//$'\n'/ }"
      [ -n "$value" ] && names["$id"]="$value"
      return
    fi
  done < "$f"
}

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

# --- names first, in their own pass over the roots.
#
# Separate from the artwork walk below because it does not want the same
# starting point: that one needs a root with a librarycache in it, this one
# needs every drive the index points at, most of which are not Steam installs
# and have no cache of their own.
for root in "${roots[@]}"; do
  [ -d "$root" ] || continue
  libs["$root"]=1
  scan_library_index "$root/steamapps/libraryfolders.vdf"
  scan_library_index "$root/config/libraryfolders.vdf"
done

for lib in "${!libs[@]}"; do
  for f in "$lib"/steamapps/appmanifest_*.acf; do
    [ -f "$f" ] || continue
    base="${f##*/}"
    id="${base#appmanifest_}"
    id="${id%.acf}"
    case "$id" in
      ''|*[!0-9]*) continue ;;
    esac
    [ -n "${names[$id]:-}" ] && continue
    read_manifest_name "$f" "$id"
  done
done

# --- artwork
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

    # Named, and unambiguously an icon.
    for name in icon.jpg icon.png; do
      keep "$id" "$dir$name"
    done

    # Older builds that spell it out somewhere in the name.
    if [ -z "${found[$id]:-}" ]; then
      for f in "$dir"*icon*; do
        [ -f "$f" ] && keep "$id" "$f"
      done
    fi

    # The current layout: one hash-named image, and it is the square icon.
    # Above the wide artwork below, because it is the right shape for a dock.
    if [ -z "${found[$id]:-}" ]; then
      for f in "$dir"*.jpg "$dir"*.png; do
        [ -f "$f" ] || continue
        base="${f##*/}"
        is_hashed_name "${base%.*}" && keep "$id" "$f"
      done
    fi

    #
    # Wide artwork, none of which is the right shape for a dock slot.
    #
    # logo.png sits down here rather than up with the icons, which is where it
    # used to be. In this layout it is not an icon at all - it is the game's
    # wordmark on transparency, 640x98 for one of the games installed here and
    # 4731x1018 for Team Fortress 2. Ranked above the real icon it beat it on
    # every app that had both, so those games got a sliver of text in the dock
    # where a square icon was sitting in the same directory unused.
    #
    # A header is 460x215 and will letterbox badly too - but it identifies the
    # game, which the fallback box does not.
    for name in logo.png logo.jpg library_600x900.jpg header.jpg \
                library_header.jpg library_hero.jpg; do
      keep "$id" "$dir$name"
    done

    # Steam also files artwork one level down, in <hash>/ subdirectories of the
    # app directory. Only worth walking for an app that has turned up nothing
    # at all so far, which is a handful of them.
    if [ -z "${found[$id]:-}" ]; then
      for sub in "$dir"*/; do
        [ -d "$sub" ] || continue
        for name in icon.jpg icon.png logo.png \
                    library_600x900.jpg header.jpg library_header.jpg; do
          keep "$id" "$sub$name"
        done
      done
    fi
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

# The union of both passes. An app with artwork but no manifest is one that has
# been uninstalled and not cleaned up; an app with a manifest but no artwork is
# one Steam has not fetched images for yet. Both are worth printing, because
# each field answers a different question and the dock asks them separately.
declare -A seen=()
for id in "${!found[@]}"; do seen["$id"]=1; done
for id in "${!names[@]}"; do seen["$id"]=1; done

for id in "${!seen[@]}"; do
  printf '%s\t%s\t%s\n' "$id" "${found[$id]:-}" "${names[$id]:-}"
done
