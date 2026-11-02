#!/usr/bin/env bash
# Load the real bar in an isolated headless Wayland compositor.
# Cage does not provide the layer-shell support needed for visual testing.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
stage="$(realpath "${1:?Usage: bash tests/headless-phantom-bar.sh STAGE_PREFIX}")"
qml="$stage/lib/qt6/qml"
for cmd in bwrap cage timeout; do command -v "$cmd" >/dev/null; done
test -d /tmp/opencode
scratch="$(mktemp -d /tmp/opencode/phantom-headless-test.XXXXXX)"
mkdir -m 700 "$scratch/runtime"
mkdir -p "$scratch/home" "$scratch/config" "$scratch/cache" "$scratch/state" "$scratch/data" "$scratch/bin"
if [ "${PHANTOM_TEST_SCHEME_TEXT+x}" = x ]; then
  mkdir -p "$scratch/state/phantom-shell"
  printf '%s' "$PHANTOM_TEST_SCHEME_TEXT" > "$scratch/state/phantom-shell/scheme.json"
fi
cat > "$scratch/bin/caelestia" <<'EOF'
#!/usr/bin/env bash
printf 'caelestia CLI was invoked: %s\n' "$*" >> "$PHANTOM_CLI_PROBE"
exit 1
EOF
chmod +x "$scratch/bin/caelestia"

# Hide the installed CLI even from callers that use its absolute path.
mask_cli=()
if [ -e /usr/bin/caelestia ]; then
  mask_cli=(--ro-bind "$scratch/bin/caelestia" /usr/bin/caelestia)
fi
mask_qml=()
if [ -d /usr/lib/qt6/qml/Caelestia ]; then
  mask_qml=(--tmpfs /usr/lib/qt6/qml/Caelestia)
fi
mask_shell=()
if [ -d /etc/xdg/quickshell/caelestia ]; then
  mask_shell=(--tmpfs /etc/xdg/quickshell/caelestia)
fi
mask_dbus=()
if [ -d /run/dbus ]; then
  mask_dbus=(--tmpfs /run/dbus)
fi
rc=0
bwrap --ro-bind / / --bind "$scratch" "$scratch" --dev /dev --proc /proc \
  --unshare-net --unshare-pid "${mask_dbus[@]}" "${mask_qml[@]}" "${mask_shell[@]}" "${mask_cli[@]}" \
  --setenv HOME "$scratch/home" --setenv XDG_CONFIG_HOME "$scratch/config" \
  --setenv XDG_CACHE_HOME "$scratch/cache" --setenv XDG_STATE_HOME "$scratch/state" \
  --setenv XDG_DATA_HOME "$scratch/data" --setenv XDG_RUNTIME_DIR "$scratch/runtime" \
  --setenv PATH "$scratch/bin:$PATH" --setenv PHANTOM_CLI_PROBE "$scratch/cli.log" \
  --setenv WLR_BACKENDS headless --setenv WLR_RENDERER pixman --setenv WLR_LIBINPUT_NO_DEVICES 1 \
  --setenv QT_QPA_PLATFORM wayland --setenv QT_QUICK_BACKEND software \
  --setenv PHANTOM_BAR_CONFIG "$root/quickshell/caelestia-bar" --setenv PHANTOM_QML_ROOT "$qml" \
  --unsetenv WAYLAND_DISPLAY --unsetenv DISPLAY --unsetenv DBUS_SESSION_BUS_ADDRESS \
  --unsetenv HYPRLAND_INSTANCE_SIGNATURE --unsetenv LD_PRELOAD --unsetenv LD_LIBRARY_PATH \
  --unsetenv QML_IMPORT_PATH --unsetenv QML2_IMPORT_PATH \
  timeout "${PHANTOM_HEADLESS_TIMEOUT:-10}" cage -- "$root/bin/phantom-bar" > "$scratch/log" 2>&1 || rc=$?

printf 'Headless log: %s/log\n' "$scratch"
if [ "$rc" -ne 124 ]; then
  printf 'Unexpected headless process exit: %s\n' "$rc" >&2
  cat "$scratch/log" >&2
  exit 1
fi
if ! grep -Fq 'Configuration Loaded' "$scratch/log" || grep -Fq 'Failed to load configuration' "$scratch/log"; then
  cat "$scratch/log" >&2
  exit 1
fi
if [ -s "$scratch/cli.log" ]; then
  printf 'Unexpected call to Caelestia CLI: %s/cli.log\n' "$scratch" >&2
  exit 1
fi
if [ "${PHANTOM_EXPECT_SCHEME_WARNING:-0}" = 1 ] && ! grep -Fq 'Ignoring invalid phantom-shell colour scheme:' "$scratch/log"; then
  printf 'Expected invalid-scheme warning was not found in %s/log\n' "$scratch" >&2
  exit 1
fi
printf 'Configuration loaded without a Caelestia CLI call; visual and interactive behaviour not tested.\n'
