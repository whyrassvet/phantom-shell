#!/usr/bin/env bash
# Build vendored QML plugins and install them into a new private prefix.
set -euo pipefail

if [ "$#" -ne 2 ]; then
  printf 'Usage: bash %s BUILD_DIR NEW_PRIVATE_PREFIX\n' "$0" >&2
  exit 2
fi
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_dir="$root/vendor/caelestia-shell-plugin-v2.5.0"
build="$1"
prefix="$2"

case "$build" in /*) ;; *) echo 'BUILD_DIR must be absolute' >&2; exit 2 ;; esac
case "$prefix" in /*) ;; *) echo 'NEW_PRIVATE_PREFIX must be absolute' >&2; exit 2 ;; esac
if [ -e "$prefix" ] || [ -L "$prefix" ]; then
  printf 'Refusing to overwrite existing prefix: %s\n' "$prefix" >&2
  exit 1
fi
if [ ! -d "$(dirname "$prefix")" ]; then
  printf 'Prefix parent does not exist: %s\n' "$(dirname "$prefix")" >&2
  exit 1
fi

# mkdir is atomic and fails if another process creates the path in the meantime.
mkdir -- "$prefix"
cmake -S "$source_dir" -B "$build" -DENABLE_MODULES=plugin -DVERSION=2.5.0 \
  -DCMAKE_INSTALL_PREFIX="$prefix" -DINSTALL_QMLDIR=lib/qt6/qml
cmake --build "$build" --parallel "${PHANTOM_BUILD_JOBS:-2}"
cmake --install "$build" --prefix "$prefix"
printf 'Private plugins staged at: %s\n' "$prefix"
