#!/usr/bin/env bash
# The gate. Refreshes Godot's script-class cache, runs the headless suite, and fails on
# engine errors as well as on failed assertions — Godot exits 0 while printing
# SCRIPT ERROR every frame, so the exit code alone proves nothing.
set -uo pipefail

GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."

if ! command -v "$GODOT" >/dev/null 2>&1 && [ ! -x "$GODOT" ]; then
  echo "check: godot not found (set \$GODOT)" >&2
  exit 127
fi

# class_name globals are unresolvable until this has built
# .godot/global_script_class_cache.cfg at least once.
"$GODOT" --headless --import --path . >/dev/null 2>&1

output=$("$GODOT" --headless --path . --script tests/run_tests.gd 2>&1)
status=$?
echo "$output"

if grep -qE 'SCRIPT ERROR|Parse Error|Cannot open file|not declared in the current scope' <<<"$output"; then
  echo "check: engine reported script errors" >&2
  exit 1
fi

exit "$status"
