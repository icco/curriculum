#!/usr/bin/env bash
# Installs Godot to ~/godot-bin/godot for CI. With --with-templates, also installs the
# export templates the Web/Linux/Android presets need.
set -euo pipefail

VERSION="${GODOT_VERSION:-4.7.1}"
WITH_TEMPLATES="${1:-}"
BASE="https://github.com/godotengine/godot/releases/download/${VERSION}-stable"
DEST="$HOME/godot-bin"

mkdir -p "$DEST"
WORK="$(mktemp -d)"
cd "$WORK"

curl -fsSLO "$BASE/Godot_v${VERSION}-stable_linux.x86_64.zip"
unzip -q "Godot_v${VERSION}-stable_linux.x86_64.zip"
mv "Godot_v${VERSION}-stable_linux.x86_64" "$DEST/godot"
chmod +x "$DEST/godot"

if [ "$WITH_TEMPLATES" = "--with-templates" ]; then
  curl -fsSLO "$BASE/Godot_v${VERSION}-stable_export_templates.tpz"
  TEMPLATES="$HOME/.local/share/godot/export_templates/${VERSION}.stable"
  mkdir -p "$TEMPLATES"
  unzip -q "Godot_v${VERSION}-stable_export_templates.tpz"
  mv templates/* "$TEMPLATES/"
fi

"$DEST/godot" --version
