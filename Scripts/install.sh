#!/usr/bin/env bash
# Links this config into place and checks for the packages it depends on.
set -euo pipefail

src="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dest="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/bw77-shell"

mkdir -p "$(dirname "$dest")"
if [ -e "$dest" ] && [ ! -L "$dest" ]; then
  echo "A real directory already exists at $dest. Move it aside first." >&2
  exit 1
fi
ln -sfn "$src" "$dest"
echo "Linked $src -> $dest"

# Carry over an existing nightcity config if this is a rename rather than a
# fresh install, so settings and custom palettes are not silently orphaned.
old="$HOME/.config/nightcity"
new="$HOME/.config/bw77-shell"
if [ -d "$old" ] && [ ! -d "$new" ]; then
  mv "$old" "$new"
  echo "Moved $old -> $new"
fi

mkdir -p "$new/palettes" "$new/state"

required=(quickshell jq)
optional=(cava niri hyprland kitty btop)

missing=()
for p in "${required[@]}"; do
  command -v "$p" >/dev/null || missing+=("$p")
done
if [ ${#missing[@]} -gt 0 ]; then
  echo "Missing required commands: ${missing[*]}" >&2
  echo "On Arch: sudo pacman -S quickshell jq" >&2
fi

echo
echo "Recommended fonts: ttf-rajdhani ttf-chakra-petch ttf-jetbrains-mono-nerd"
echo "Start with: qs -c bw77-shell"
