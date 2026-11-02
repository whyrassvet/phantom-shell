#!/usr/bin/env bash
# Test activation and failures with a fake compiler, without installing anything.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
scratch="$(mktemp -d /tmp/opencode/phantom-install-test.XXXXXX)"
mkdir -p "$scratch/bin" "$scratch/data" "$scratch/config"
cat > "$scratch/bin/cmake" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[ "${FAIL_BUILD:-0}" != 1 ] || exit 1
if [ "$1" = --install ]; then
  prefix="$4"
  qml="$prefix/lib/qt6/qml/Caelestia"
  mkdir -p "$qml/lib"
  for entry in '.:core' 'Config:config' 'Settings:settings' 'Components:components' 'Services:services' 'Models:models' 'Images:images' 'Blobs:blobs' 'I18n:i18n'; do
    module="${entry%%:*}"; plugin="${entry#*:}"
    mkdir -p "$qml/$module"
    : > "$qml/$module/qmldir"
    : > "$qml/$module/libcaelestia-${plugin}plugin.so"
    : > "$qml/lib/libcaelestia-$plugin.so"
  done
fi
EOF
cat > "$scratch/bin/qs" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$QML_IMPORT_PATH"
EOF
chmod +x "$scratch/bin/cmake" "$scratch/bin/qs"
export PATH="$scratch/bin:$PATH"
store="$scratch/data/phantom-shell"
installer="$root/install/install-phantom-plugins.sh"
bash "$installer" "$store" > "$scratch/first.log"
first="$(readlink "$store/plugin-current")"
env XDG_DATA_HOME="$scratch/data" PHANTOM_BAR_CONFIG="$root/quickshell/caelestia-bar" \
  "$root/bin/phantom-bar" > "$scratch/launcher.log"
grep -F "$store/plugin-current/lib/qt6/qml" "$scratch/launcher.log" >/dev/null
if FAIL_BUILD=1 bash "$installer" "$store" > "$scratch/fail.log" 2>&1; then
  echo 'Failed build unexpectedly succeeded' >&2; exit 1
fi
[ "$(readlink "$store/plugin-current")" = "$first" ]
bash "$installer" "$store" > "$scratch/second.log"
second="$(readlink "$store/plugin-current")"
[ "$first" != "$second" ]
[ -d "$store/$first" ] && [ -d "$store/$second" ]
mkdir -p "$scratch/unmanaged/plugin-current"
if bash "$installer" "$scratch/unmanaged" > "$scratch/unmanaged.log" 2>&1; then
  echo 'Unmanaged directory unexpectedly replaced' >&2; exit 1
fi
[ -d "$scratch/unmanaged/plugin-current" ] && [ ! -L "$scratch/unmanaged/plugin-current" ]
printf 'Plugin activation, failed build, previous version and unmanaged path tests passed: %s\n' "$scratch"
