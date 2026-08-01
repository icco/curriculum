#!/usr/bin/env bash
# Converts every accepted raw generator output into a real .png sprite and imports
# it, so ArtLibrary.has_sprite() (backed by ResourceLoader.exists()) can see it.
#
# Two steps, both required:
#   1. tools/import_assets.gd decodes assets/source/<id>/accepted.* (whatever Recraft
#      actually served -- sniffed by magic bytes, not trusted by extension) and
#      re-encodes it as assets/sprites/<id>.png.
#   2. `--headless --import` runs Godot's importer over the new files. A .png that
#      exists on disk is NOT loadable via ResourceLoader until this has run --
#      writing the file is not enough.
set -euo pipefail

GODOT="${GODOT:-godot}"

cd "$(dirname "$0")/.."

if ! command -v "$GODOT" >/dev/null 2>&1 && [ ! -x "$GODOT" ]; then
  echo "import-assets: godot not found (set \$GODOT)" >&2
  exit 127
fi

# class_name globals (Schools, ContentLibrary, ...) are unresolvable until this has
# built .godot/global_script_class_cache.cfg at least once -- same requirement
# check.sh documents. Without this first pass, tools/import_assets.gd itself fails
# to parse on a fresh checkout even though it never references a game class.
"$GODOT" --headless --import --path . >/dev/null 2>&1

convert_output=$("$GODOT" --headless --path . --script tools/import_assets.gd 2>&1)
echo "$convert_output"
if grep -qE 'SCRIPT ERROR|Parse Error' <<<"$convert_output"; then
  echo "import-assets: engine reported script errors during conversion" >&2
  exit 1
fi

"$GODOT" --headless --import --path . >/dev/null 2>&1

echo "import-assets: done"
