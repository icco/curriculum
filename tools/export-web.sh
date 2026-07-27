#!/usr/bin/env bash
# Exports the browser build into build/web (what the Docker image serves).
#   tools/export-web.sh [--release]
set -euo pipefail

cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
MODE="--export-debug"
[ "${1:-}" = "--release" ] && MODE="--export-release"

rm -rf build/web
mkdir -p build/web
"$GODOT" --headless --import --path . >/dev/null 2>&1
"$GODOT" --headless --path . "$MODE" Web build/web/index.html
test -s build/web/index.html
test -s build/web/index.wasm
echo "web export ready in build/web ($(du -sh build/web | cut -f1))"
