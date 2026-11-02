#!/usr/bin/env bash
# Create personal Hyprland files once; never overwrite existing files or symlinks.
ensure_phantom_user_configs() {
  local dir="${XDG_CONFIG_HOME:-$HOME/.config}/phantom-shell" name src
  mkdir -p -- "$dir" || return 1
  for name in hyprland-vars.lua hyprland-user.lua; do
    src="$ROOT/install/templates/phantom-shell/$name"
    [ -f "$src" ] || { echo "Missing template: $src" >&2; return 1; }
    if [ -e "$dir/$name" ] || [ -L "$dir/$name" ]; then
      continue
    fi
    # noclobber also protects against another process creating the file in the meantime.
    ( set -C; cat -- "$src" > "$dir/$name" ) || {
      echo "Could not create personal configuration: $dir/$name" >&2
      return 1
    }
  done
}
