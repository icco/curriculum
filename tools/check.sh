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
#
# The import output is checked, not discarded: content is generated into .tres by
# tools/generate_*.gd, and a bad ext_resource path or an unparseable typed array is
# reported HERE. Swallowing it turns a broken resource into a null load and an
# assertion failure somewhere unrelated.
import_output=$("$GODOT" --headless --import --path . 2>&1)
if grep -qE 'ERROR|Parse Error|Failed loading|Failed to load' <<<"$import_output"; then
  echo "$import_output" >&2
  echo "check: import reported errors" >&2
  exit 1
fi

output=$("$GODOT" --headless --path . --script tests/run_tests.gd 2>&1)
status=$?
echo "$output"

if grep -qE 'SCRIPT ERROR|Parse Error|Cannot open file|not declared in the current scope' <<<"$output"; then
  echo "check: engine reported script errors" >&2
  exit 1
fi

exit "$status"
