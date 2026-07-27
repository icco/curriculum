#!/usr/bin/env bash
# Launch the game windowed, run an optional scripted sequence, screenshot and
# quit.  Usage: tools/shot.sh <out.png> [seed] [script] [delay]
#   tools/shot.sh /tmp/a.png 7 "wait:0.4,tap_cell:20:20,confirm" 1.2
set -uo pipefail

cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
OUT="${1:?usage: shot.sh <out.png> [seed] [script] [delay]}"
SEED="${2:-7}"
STEPS="${3:-}"
DELAY="${4:-1.0}"
LOG="${TMPDIR:-/tmp}/loopwood-shot.log"

mkdir -p "$(dirname "$OUT")"
rm -f "$OUT"

"$GODOT" --headless --import --path . >/dev/null 2>&1

LOOPWOOD_SEED="$SEED" LOOPWOOD_SHOT="$OUT" LOOPWOOD_SHOT_AFTER="$DELAY" \
	LOOPWOOD_SCRIPT="$STEPS" LOOPWOOD_FRESH="${LOOPWOOD_FRESH:-1}" \
	timeout 120 "$GODOT" --path . scenes/Main.tscn >"$LOG" 2>&1
status=$?

if grep -qE "SCRIPT ERROR|Parse Error|Failed to load script|Condition .* is true" "$LOG"; then
	echo "!! engine errors:"
	grep -E "SCRIPT ERROR|Parse Error|Failed to load|ERROR:|   at: " "$LOG" | head -30
	exit 1
fi
if [ ! -f "$OUT" ]; then
	echo "!! no screenshot produced (exit $status)"
	tail -20 "$LOG"
	exit 1
fi
grep -E "^\[(log|shot)\]" "$LOG" | tail -20
echo "ok -> $OUT"
