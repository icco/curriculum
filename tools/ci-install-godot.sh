#!/usr/bin/env bash
# Installs the Godot editor binary (and optionally the export templates) into
# ~/godot-bin and the user data dir. Used by CI; safe to run locally.
#   tools/ci-install-godot.sh [--with-templates]
set -euo pipefail

VERSION="${GODOT_VERSION:-4.7.1}"
BASE="https://github.com/godotengine/godot/releases/download/${VERSION}-stable"
FILE="Godot_v${VERSION}-stable_linux.x86_64"

mkdir -p "$HOME/godot-bin"
echo "installing Godot ${VERSION}"
curl -fsSL -o /tmp/godot.zip "${BASE}/${FILE}.zip"
unzip -qo /tmp/godot.zip -d "$HOME/godot-bin"
mv -f "$HOME/godot-bin/${FILE}" "$HOME/godot-bin/godot"
chmod +x "$HOME/godot-bin/godot"

if [ "${1:-}" = "--with-templates" ]; then
	echo "installing export templates"
	curl -fsSL -o /tmp/templates.tpz \
		"${BASE}/Godot_v${VERSION}-stable_export_templates.tpz"
	rm -rf /tmp/godot-templates
	unzip -qo /tmp/templates.tpz -d /tmp/godot-templates
	# The archive unpacks to templates/; Godot looks for
	# <data dir>/export_templates/<version>.stable/
	target="$HOME/.local/share/godot/export_templates/${VERSION}.stable"
	mkdir -p "$target"
	mv -f /tmp/godot-templates/templates/* "$target"/
	echo "templates installed: $(ls "$target" | wc -l) files"
fi
