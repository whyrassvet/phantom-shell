#!/usr/bin/env bash
# Replace "random" with: fade, wipe, grow, outer, wave, center, any, random
set -e

img="$1"
[[ -f "$img" ]] || { echo "commands.sh: not a file: $img" >&2; exit 1; }

awww img "$img" -t random --transition-duration 1

src="$HOME/.cache/quickshell/thumbs/$(basename "$img")"
[[ -f "$src" ]] || src="$img"

sat=$(convert -define jpeg:size=200x200 "$src" -resize 100x100! -colorspace HSL -channel G -separate +channel -format "%[fx:mean*100]" info:)
mode="$(cat "$HOME/.config/rice/color-mode" 2>/dev/null || true)"
scheme=""
case "$mode" in
  grey) sat=0 ;;
  navy) ;;
  ""|auto) ;;
  *) scheme="$("$HOME/.local/bin/rice-colors" scheme "$mode" 2>/dev/null || true)" ;;
esac

if [ -n "$scheme" ]; then
  # named color scheme from Settings > Home > Colors: "<matugen type> <seed> <workspace marker>"
  read -r stype seed ws <<<"$scheme"
  cmd=(matugen color hex "$seed" --type "$stype" -q)
elif [ "$mode" = navy ]; then
  ws='#8a8a8a'
  cmd=(matugen color hex "#1a2a5e" -q)
elif awk "BEGIN{exit !($sat < 12)}"; then
  ws='#8a8a8a'
  cmd=(matugen image "$src" --type scheme-monochrome --source-color-index 0 -q)
else
  ws='@on_accent'
  cmd=(matugen image "$src" --source-color-index 0 -q)
fi

mkdir -p "$HOME/.config/waybar"
printf '@define-color ws_active %s;\n' "$ws" > "$HOME/.config/waybar/ws-active.css"
"${cmd[@]}"

mkdir -p "$HOME/.cache"
echo "$img" > "$HOME/.cache/hyprquickpaper-current"

# recolor notifications and the lock screen (Phantom Shell)
"$HOME/.local/bin/rice-colors" refresh >/dev/null 2>&1 &
