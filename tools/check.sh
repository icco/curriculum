#!/usr/bin/env bash
# Full verification pass: refresh Godot's script-class cache, then run the
# headless suite. Fails on a non-zero exit *or* on any engine-level error in
# the output, because Godot happily exits 0 while spewing SCRIPT ERROR.
set -uo pipefail

cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
LOG="${TMPDIR:-/tmp}/loopwood-check.log"

echo "== refreshing script class cache =="
"$GODOT" --headless --import --path . >"$LOG" 2>&1
if grep -qE "^(SCRIPT )?ERROR: (Parse|Compile)" "$LOG"; then
	echo "!! parse errors during import"
	grep -E "^(SCRIPT )?ERROR|^ +at: " "$LOG" | head -40
	exit 1
fi

echo "== running tests =="
"$GODOT" --headless --path . --script tests/run_tests.gd 2>&1 | tee "$LOG"
status=${PIPESTATUS[0]}

if grep -qE "SCRIPT ERROR|Parse Error|Failed to load script" "$LOG"; then
	echo "!! engine errors detected in test output"
	exit 1
fi
if [ "$status" -ne 0 ]; then
	echo "!! test runner exited $status"
	exit "$status"
fi
echo "== check passed =="
