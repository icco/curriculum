#!/usr/bin/env bash
# Godot resolves the Android SDK and JDK from editor settings rather than the
# environment, so CI writes them before an Android export.
set -euo pipefail

VERSION="${GODOT_VERSION:-4.7.1}"
MINOR="${VERSION%.*}"                     # 4.7.1 -> 4.7
SDK="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
JDK="${JAVA_HOME:-}"

if [ -z "$SDK" ] || [ -z "$JDK" ]; then
	echo "ANDROID_SDK_ROOT/ANDROID_HOME and JAVA_HOME must be set" >&2
	exit 1
fi

dir="$HOME/.config/godot"
mkdir -p "$dir"
cat >"$dir/editor_settings-${MINOR}.tres" <<EOF
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/android_sdk_path = "${SDK}"
export/android/java_sdk_path = "${JDK}"
EOF
echo "wrote $dir/editor_settings-${MINOR}.tres (sdk=${SDK} jdk=${JDK})"
