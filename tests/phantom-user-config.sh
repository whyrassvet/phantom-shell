#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
scratch="$(mktemp -d /tmp/opencode/phantom-user-config-test.XXXXXXXX)"
export HOME="$scratch/home" XDG_CONFIG_HOME="$scratch/config"
mkdir -p "$HOME"
. "$ROOT/install/lib/phantom-user-config.sh"
ensure_phantom_user_configs
dir="$XDG_CONFIG_HOME/phantom-shell"
luac -p "$dir/hyprland-vars.lua" "$dir/hyprland-user.lua"
printf '%s\n' 'return { terminal = "my-terminal" }' > "$dir/hyprland-vars.lua"
printf '%s\n' '-- personal binding' > "$dir/hyprland-user.lua"
ensure_phantom_user_configs
grep -Fx 'return { terminal = "my-terminal" }' "$dir/hyprland-vars.lua" >/dev/null
grep -Fx -- '-- personal binding' "$dir/hyprland-user.lua" >/dev/null

# Existing symlinks, including dangling ones, are never followed or overwritten.
mkdir -p "$scratch/link-config/phantom-shell"
ln -s "$scratch/nonexistent" "$scratch/link-config/phantom-shell/hyprland-user.lua"
XDG_CONFIG_HOME="$scratch/link-config" ensure_phantom_user_configs
test -L "$scratch/link-config/phantom-shell/hyprland-user.lua"
test ! -e "$scratch/nonexistent"
printf 'Personal files created once and existing files/symlinks preserved: %s\n' "$scratch"
