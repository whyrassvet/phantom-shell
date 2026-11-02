#!/usr/bin/env bash
# Exercise the bar installer's existing symlink guards in an isolated tree.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
scratch="$(mktemp -d /tmp/opencode/phantom-bar-copy.XXXXXXXX)"
trap 'rm -rf -- "$scratch"' EXIT
source "$ROOT/install/lib/phantom-bar.sh"
DRY_RUN=0
put() { mkdir -p "$(dirname "$2")"; cp -- "$1" "$2"; }
src="$scratch/source"
dst="$scratch/destination"
outside="$scratch/outside"
mkdir -p "$src"/{components,services,utils,assets} "$outside"
printf 'bar\n' > "$src/shell.qml"
printf 'service\n' > "$src/services/service.qml"
printf 'untouched\n' > "$outside/sentinel"

copy_phantom_bar "$src" "$dst"
cmp "$src/services/service.qml" "$dst/services/service.qml"

ln -s "$outside" "$src/components/unsafe"
if copy_phantom_bar "$src" "$scratch/source-link-dst" 2>/dev/null; then
    echo 'Source symlink unexpectedly accepted' >&2; exit 1
fi
rm "$src/components/unsafe"

ln -s "$outside" "$scratch/destination-link"
if copy_phantom_bar "$src" "$scratch/destination-link" 2>/dev/null; then
    echo 'Destination symlink unexpectedly accepted' >&2; exit 1
fi

mkdir -p "$scratch/nested"
ln -s "$outside" "$scratch/nested/services"
if copy_phantom_bar "$src" "$scratch/nested" 2>/dev/null; then
    echo 'Nested destination symlink unexpectedly accepted' >&2; exit 1
fi
test "$(cat "$outside/sentinel")" = untouched
test ! -e "$outside/service.qml"
test ! -e "$scratch/nested/shell.qml"

DRY_RUN=1
copy_phantom_bar "$src" "$scratch/dry-run"
test ! -e "$scratch/dry-run"
echo 'Bar copy and symlink preflight tests passed'
