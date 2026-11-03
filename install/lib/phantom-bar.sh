#!/usr/bin/env bash
# Sourced by install.sh. Copy the vendored bar without following symlinks.
install_phantom_plugins() {
  local store="${XDG_DATA_HOME:-$HOME/.local/share}/phantom-shell"
  bash "$ROOT/install/install-phantom-plugins.sh" "$store"
}

copy_phantom_bar() {
  local src="$1" dst="$2" name f dir
  [ -d "$src" ] || { echo "Bar source not found: $src" >&2; return 1; }
  for name in components services utils assets; do
    if [ ! -d "$src/$name" ] || [ -L "$src/$name" ]; then
      echo "Missing vendored bar directory: $src/$name" >&2
      return 1
    fi
  done
  if [ -n "$(find -P "$src" -type l -print -quit)" ]; then
    echo "Refusing symlinks in bar source: $src" >&2
    return 1
  fi
  # Never follow existing symlinked destination directories while copying files.
  [ ! -L "$dst" ] || { echo "Refusing symlinked bar destination: $dst" >&2; return 1; }
  while IFS= read -r -d '' f; do
    dir="$(dirname "$dst/${f#"$src"/}")"
    while [ "$dir" != "$dst" ] && [ "$dir" != / ]; do
      [ ! -L "$dir" ] || { echo "Refusing symlinked bar directory: $dir" >&2; return 1; }
      dir="$(dirname "$dir")"
    done
  done < <(find -P "$src" -type f ! -name '*.bak*' ! -name '.gitkeep' -print0)
  [ "$DRY_RUN" = 1 ] && return 0
  mkdir -p "$dst"
  while IFS= read -r -d '' f; do
    put "$f" "$dst/${f#"$src"/}" || return 1
  done < <(find -P "$src" -type f ! -name '*.bak*' ! -name '.gitkeep' -print0)
}
