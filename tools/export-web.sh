#!/usr/bin/env bash
# Produces build/web, which the Docker image serves. --release exports release.
set -euo pipefail

GODOT="${GODOT:-godot}"
MODE="--export-debug"
[ "${1:-}" = "--release" ] && MODE="--export-release"

cd "$(dirname "$0")/.."
"$GODOT" --headless --import --path . 2>&1 | tail -3
mkdir -p build/web
"$GODOT" --headless --path . "$MODE" Web build/web/index.html
test -s build/web/index.html
test -s build/web/index.wasm
echo "exported build/web"
