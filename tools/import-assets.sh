#!/usr/bin/env bash
# Processes assets/source into assets/sprites, then re-imports so Godot can
# load the new PNGs (a .png is not loadable until it has been imported).
#   tools/import-assets.sh [--status]
set -uo pipefail

cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"

if [ "${1:-}" = "--status" ]; then
	"$GODOT" --headless --path . --script tools/import_assets.gd -- --status 2>&1 |
		grep -vE "^$|Godot Engine"
	exit 0
fi

"$GODOT" --headless --path . --script tools/import_assets.gd 2>&1 |
	grep -vE "^$|Godot Engine"
echo "== re-importing =="
"$GODOT" --headless --import --path . >/dev/null 2>&1
"$GODOT" --headless --path . --script tools/import_assets.gd -- --status 2>&1 |
	grep -vE "^$|Godot Engine"
