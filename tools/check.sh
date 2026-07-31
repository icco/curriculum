#!/usr/bin/env bash
# The gate. Refreshes Godot's script-class cache, runs the headless suite, and fails on
# engine errors as well as on failed assertions — Godot exits 0 while printing
# SCRIPT ERROR every frame, so the exit code alone proves nothing.
#
# Every Godot invocation is time-boxed. A script that fails to COMPILE makes
# `--import` hang forever rather than erroring out, which in CI burns the whole job
# timeout and reports nothing useful. A hang has to become a failure.
set -uo pipefail

GODOT="${GODOT:-godot}"
IMPORT_TIMEOUT="${IMPORT_TIMEOUT:-180}"
TEST_TIMEOUT="${TEST_TIMEOUT:-300}"

cd "$(dirname "$0")/.."

if ! command -v "$GODOT" >/dev/null 2>&1 && [ ! -x "$GODOT" ]; then
  echo "check: godot not found (set \$GODOT)" >&2
  exit 127
fi

# `timeout` is GNU coreutils: present on CI's ubuntu runners, absent from a stock
# macOS. Fall back to a background-and-kill shim so behaviour matches either way.
# Exit code 124 means the command was killed for running too long.
run_limited() {
  local limit="$1"
  shift
  if [ -z "${CHECK_FORCE_SHIM:-}" ] && command -v timeout >/dev/null 2>&1; then
    timeout "$limit" "$@"
    return $?
  fi
  "$@" &
  local pid=$!
  # The `>/dev/null 2>&1` on the watcher is load-bearing, not tidiness. Without it the
  # subshell and its `sleep` child inherit this function's stdout. Killing the subshell
  # orphans the `sleep`, which keeps the write end of the caller's command-substitution
  # pipe open, so `$(run_limited ...)` blocks for the FULL limit even when the wrapped
  # command exited instantly — turning a fail-fast guard into a far worse hang.
  (
    sleep "$limit"
    kill -9 "$pid" 2>/dev/null
  ) >/dev/null 2>&1 &
  local watcher=$!
  wait "$pid" 2>/dev/null
  local status=$?
  kill "$watcher" 2>/dev/null
  wait "$watcher" 2>/dev/null
  # 137 is SIGKILL, which here only comes from the watcher firing.
  [ "$status" -eq 137 ] && return 124
  return "$status"
}

# class_name globals are unresolvable until this has built
# .godot/global_script_class_cache.cfg at least once.
#
# The import output is checked, not discarded: content is generated into .tres by
# tools/generate_*.gd, and a bad ext_resource path or an unparseable typed array is
# reported HERE. Swallowing it turns a broken resource into a null load and an
# assertion failure somewhere unrelated.
#
# Note the limit of this check: --import scans assets but does not eagerly load an
# unreferenced .tres, so an orphaned broken resource slips past it. Catching that is
# test_content's job, via a walk of resources/ added when generated content lands.
import_output=$(run_limited "$IMPORT_TIMEOUT" "$GODOT" --headless --import --path . 2>&1)
import_status=$?
if [ "$import_status" -eq 124 ]; then
  echo "$import_output" >&2
  echo "check: import hung for ${IMPORT_TIMEOUT}s — a script almost certainly failed to compile" >&2
  exit 1
fi
# Two teardown lines are filtered out before the check, and the reason matters.
# CourseData exports a self-referential `Array[CourseData]` for its prerequisites, which
# is legal and required. Godot's exit-time accounting reports the resulting reference as
# "resources still in use at exit" plus a leaked-ObjectDB count. That is Godot noticing
# its own cleanup order, not a broken import.
#
# A blanket 'ERROR' match therefore failed the build for a benign message — and the cost
# was paid in the code: it forced GameManager to reference Run and SaveGame via load()
# instead of by class_name, purely so `--import` would not resolve CourseData while
# building autoloads. Narrowing the pattern here is the correct fix; contorting call
# sites to keep an over-broad grep happy is not.
import_signal=$(grep -vE 'resources still in use at exit|ObjectDB instances leaked' <<<"$import_output")
if grep -qE 'ERROR|Parse Error|Failed loading|Failed to load' <<<"$import_signal"; then
  echo "$import_output" >&2
  echo "check: import reported errors" >&2
  exit 1
fi

output=$(run_limited "$TEST_TIMEOUT" "$GODOT" --headless --path . --script tests/run_tests.gd 2>&1)
status=$?
echo "$output"

if [ "$status" -eq 124 ]; then
  echo "check: test run hung for ${TEST_TIMEOUT}s" >&2
  exit 1
fi

if grep -qE 'SCRIPT ERROR|Parse Error|Cannot open file|not declared in the current scope' <<<"$output"; then
  echo "check: engine reported script errors" >&2
  exit 1
fi

exit "$status"
