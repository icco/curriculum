#!/usr/bin/env bash
# Launches the game windowed, screenshots it, quits. The only way to check anything
# visual: --headless does not render, so a headless screenshot comes back blank.
#   ./tools/shot.sh <out.png> [seed] [screen]
set -euo pipefail

GODOT="${GODOT:-godot}"
OUT="${1:?usage: shot.sh <out.png> [seed] [screen]}"
SEED="${2:-0}"
SCREEN="${3:-}"

cd "$(dirname "$0")/.."
"$GODOT" --headless --import --path . >/dev/null 2>&1

output=$("$GODOT" --path . --resolution 540x960 \
  -- --shot "$OUT" --seed "$SEED" --screen "$SCREEN" 2>&1)
echo "$output"

if grep -qE 'SCRIPT ERROR|Parse Error' <<<"$output"; then
  echo "shot: engine reported script errors" >&2
  exit 1
fi
test -s "$OUT" || { echo "shot: no image written to $OUT" >&2; exit 1; }
echo "wrote $OUT"
