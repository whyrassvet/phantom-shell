#!/usr/bin/env bash
# Build a new private version, validate it, then atomically switch the launcher.
# Previous versions are retained; an interrupted or failed build is never active.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
store="${1:?Usage: bash install/install-phantom-plugins.sh ABSOLUTE_STORE}"
case "$store" in /*) ;; *) echo 'Store must be an absolute path' >&2; exit 2 ;; esac
if [ -L "$store" ] || { [ -e "$store" ] && [ ! -d "$store" ]; }; then
  echo "Refusing non-directory or symlink store: $store" >&2
  exit 1
fi
mkdir -p -- "$store"
store="$(realpath -e -- "$store")"
versions="$store/plugin-versions"
current="$store/plugin-current"
if [ -L "$versions" ] || { [ -e "$versions" ] && [ ! -d "$versions" ]; }; then
  echo "Refusing non-directory or symlink versions path: $versions" >&2
  exit 1
fi
mkdir -p -- "$versions"
if [ -L "$store/.plugin-install.lock" ]; then
  echo "Refusing symlink lock file: $store/.plugin-install.lock" >&2
  exit 1
fi
exec 9>>"$store/.plugin-install.lock"
flock -n 9 || { echo 'Another plugin installation is running' >&2; exit 1; }

if [ -e "$current" ] || [ -L "$current" ]; then
  if [ ! -L "$current" ]; then
    echo "Refusing to replace non-symlink: $current" >&2
    exit 1
  fi
  old="$(readlink -- "$current")"
  case "$old" in
    plugin-versions/phantom-plugins.*/private) ;;
    *) echo "Refusing unmanaged plugin link: $current -> $old" >&2; exit 1 ;;
  esac
  if [ "$(dirname "$(dirname "$(realpath -e -- "$current" 2>/dev/null || true)")")" != "$versions" ]; then
    echo "Refusing broken or external plugin link: $current" >&2
    exit 1
  fi
fi

version="$(mktemp -d "$versions/phantom-plugins.XXXXXXXX")"
printf 'Building new plugin version in %s\n' "$version"
bash "$root/install/build-phantom-plugins.sh" "$version/build" "$version/private"
qml="$version/private/lib/qt6/qml/Caelestia"
for entry in '.:core' 'Config:config' 'Settings:settings' 'Components:components' 'Services:services' 'Models:models' 'Images:images' 'Blobs:blobs' 'I18n:i18n'; do
  module="${entry%%:*}"
  plugin="${entry#*:}"
  for file in "$qml/$module/qmldir" "$qml/$module/libcaelestia-${plugin}plugin.so" "$qml/lib/libcaelestia-$plugin.so"; do
    if [ ! -f "$file" ]; then
      printf 'Incomplete plugin build, missing: %s\n' "$file" >&2
      exit 1
    fi
  done
done

# The temporary link is in the version directory on the same filesystem.
ln -s -- "plugin-versions/${version##*/}/private" "$version/current-link"
mv -Tf -- "$version/current-link" "$current"
printf 'Activated %s; previous plugin versions were retained.\n' "$version/private"
