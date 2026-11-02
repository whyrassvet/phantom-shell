#!/usr/bin/env bash
# Verify the launcher environment without starting a real Quickshell process.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
stage="$(realpath "${1:?Usage: bash tests/phantom-bar-launcher.sh STAGE_PREFIX}")"
qml="$stage/lib/qt6/qml"
scratch="$(mktemp -d /tmp/opencode/phantom-launcher-smoke.XXXXXX)"
mkdir -p "$scratch/bin" "$scratch/empty"
cat > "$scratch/bin/qs" <<'EOF'
#!/usr/bin/env bash
printf 'qml=%s\nld=%s\narg1=%s\narg2=%s\n' "$QML_IMPORT_PATH" "$LD_LIBRARY_PATH" "$1" "$2"
EOF
chmod +x "$scratch/bin/qs"
env PATH="$scratch/bin:$PATH" PHANTOM_BAR_CONFIG="$root/quickshell/caelestia-bar" \
  PHANTOM_QML_ROOT="$qml" QML_IMPORT_PATH="$scratch/other-qml" LD_LIBRARY_PATH="$scratch/other-lib" \
  "$root/bin/phantom-bar" > "$scratch/output"
grep -Fx "qml=$qml:$scratch/other-qml" "$scratch/output"
grep -Fx "ld=$qml/Caelestia/lib:$scratch/other-lib" "$scratch/output"
grep -Fx 'arg1=-p' "$scratch/output"
grep -Fx "arg2=$root/quickshell/caelestia-bar" "$scratch/output"

if env PATH="$scratch/bin:$PATH" PHANTOM_BAR_CONFIG="$root/quickshell/caelestia-bar" \
  PHANTOM_QML_ROOT="$scratch/empty" "$root/bin/phantom-bar" > "$scratch/fail.out" 2> "$scratch/fail.err"; then
  echo 'Launcher unexpectedly accepted missing private modules' >&2
  exit 1
fi
grep -F 'private QML module not found' "$scratch/fail.err"

# All module descriptors and libraries exist, but the I18n plugin is missing.
for entry in '.:core' 'Config:config' 'Settings:settings' 'Components:components' 'Services:services' 'Models:models' 'Images:images' 'Blobs:blobs' 'I18n:i18n'; do
  module="${entry%%:*}"
  plugin="${entry#*:}"
  mkdir -p "$scratch/partial/Caelestia/$module" "$scratch/partial/Caelestia/lib"
  : > "$scratch/partial/Caelestia/$module/qmldir"
  : > "$scratch/partial/Caelestia/lib/libcaelestia-$plugin.so"
  if [ "$module" != I18n ]; then
    : > "$scratch/partial/Caelestia/$module/libcaelestia-${plugin}plugin.so"
  fi
done
if env PATH="$scratch/bin:$PATH" PHANTOM_BAR_CONFIG="$root/quickshell/caelestia-bar" \
  PHANTOM_QML_ROOT="$scratch/partial" "$root/bin/phantom-bar" > "$scratch/partial.out" 2> "$scratch/partial.err"; then
  echo 'Launcher unexpectedly accepted a missing private plugin' >&2
  exit 1
fi
grep -F 'private plugin not found' "$scratch/partial.err"
