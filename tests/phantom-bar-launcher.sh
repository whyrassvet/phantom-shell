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
