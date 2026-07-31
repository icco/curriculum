#!/usr/bin/env bash
# Points Godot at the Android SDK and JDK. Godot reads these from editor settings, not
# from $ANDROID_HOME, so an APK export fails without this and reports an empty error
# list rather than saying what is missing.
set -euo pipefail

SETTINGS_DIR="$HOME/.config/godot"
mkdir -p "$SETTINGS_DIR"
SETTINGS="$SETTINGS_DIR/editor_settings-4.tres"

SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Android/Sdk}}"
JDK="${JAVA_HOME:-/usr/lib/jvm/temurin-17-jdk-amd64}"

cat > "$SETTINGS" <<INNER
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/android_sdk_path = "$SDK"
export/android/java_sdk_path = "$JDK"
INNER

echo "wrote $SETTINGS (sdk=$SDK jdk=$JDK)"
