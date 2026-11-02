#!/usr/bin/env bash
# Sourced by install.sh. Keep the vendored bar separate from package files.
copy_phantom_bar() {
  local src="$1" dst="$2" package="/etc/xdg/quickshell/caelestia" name target f dir
  [ -d "$src" ] || { echo "Bar source not found: $src" >&2; return 1; }
  for name in components services utils assets; do
    target="$package/$name"
    [ -d "$target" ] || { echo "Missing Caelestia dependency: $target" >&2; return 1; }
    if [ -e "$dst/$name" ] || [ -L "$dst/$name" ]; then
      if [ ! -L "$dst/$name" ] || [ "$(readlink "$dst/$name")" != "$target" ]; then
        echo "Refusing to replace existing bar dependency: $dst/$name" >&2
        return 1
      fi
    fi
  done
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
  for name in components services utils assets; do
    [ -L "$dst/$name" ] || ln -s "$package/$name" "$dst/$name" || return 1
  done
}
