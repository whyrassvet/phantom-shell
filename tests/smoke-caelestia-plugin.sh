#!/usr/bin/env bash
# Smoke-test the built plugins without loading the system Caelestia QML module.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build="$(realpath "${1:?Usage: bash tests/smoke-caelestia-plugin.sh BUILD_DIR}")"
test -f "$build/qml/Caelestia/Config/qmldir"
test -d /usr/lib/qt6/qml/Caelestia || {
  echo 'This sandbox test requires the system QML directory to mask.' >&2
  exit 1
}
command -v bwrap >/dev/null
command -v pkg-config >/dev/null
test -d /tmp/opencode
scratch="$(mktemp -d /tmp/opencode/phantom-plugin-smoke.XXXXXX)"
mkdir -p "$scratch/home"

"${CXX:-c++}" -fPIC -pie -std=c++17 "$root/tests/caelestia-plugin-smoke.cpp" \
  -o "$scratch/smoke" $(pkg-config --cflags --libs Qt6Core Qt6Gui Qt6Qml)

bwrap --ro-bind / / --bind "$scratch/home" "$scratch/home" --dev /dev --proc /proc \
  --tmpfs /usr/lib/qt6/qml/Caelestia \
  --setenv HOME "$scratch/home" --setenv XDG_CONFIG_HOME "$scratch/home/config" \
  --setenv XDG_CACHE_HOME "$scratch/home/cache" --setenv QT_QPA_PLATFORM offscreen \
  --setenv PHANTOM_PLUGIN_BUILD "$build" --setenv QML_IMPORT_PATH "$build/qml" \
  "$scratch/smoke"
