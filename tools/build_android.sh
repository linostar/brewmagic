#!/usr/bin/env bash
# Android build: validate, then export
#   (default) the "Android" preset as a debug APK -> build/android/brewmagic.apk, signed with
#             the editor's debug keystore, for side-loading (adb install build/android/brewmagic.apk);
#   --play    the "Android (Play Store)" preset as a release App Bundle -> build/android/brewmagic.aab
#             (Gradle build; installs Godot's Android build template into brewmagic/android/ on first
#             use; needs the release keystore set in the preset or GODOT_ANDROID_KEYSTORE_RELEASE_*).
# Needs: the Godot 4.7.1 Android export templates, JDK 17 and the Android SDK set in Editor
# Settings > Export > Android. Env: GODOT (Godot binary), ANDROID_SDK (default ~/Library/Android/sdk).
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
ANDROID_SDK="${ANDROID_SDK:-$HOME/Library/Android/sdk}"
LOG_DIR=build/logs
export GODOT

preset="Android"
mode="--export-debug"
out="build/android/brewmagic.apk"
if [ "${1:-}" = "--play" ]; then
  preset="Android (Play Store)"
  mode="--export-release"
  out="build/android/brewmagic.aab"
fi

tools/validate.sh

mkdir -p build/android "$LOG_DIR"
rm -f "$out"
# The Gradle preset builds from Godot's Android build template (brewmagic/android/,
# gitignored). --install-android-build-template only works with an export, and that first
# pass also logs editor-scan warnings, so it runs on its own (a debug export) before the
# checked one.
if [ "$preset" != "Android" ] && [ ! -f brewmagic/android/.build_version ]; then
  "$GODOT" --headless --path brewmagic --install-android-build-template --export-debug "$preset" "$PWD/$out" >"$LOG_DIR/android_template.log" 2>&1 || true
  rm -f "$out"
  [ -f brewmagic/android/.build_version ] || { echo "FAIL installing the Android build template (log: $LOG_DIR/android_template.log)" >&2; exit 1; }
fi
log="$LOG_DIR/export_android.log"
if ! "$GODOT" --headless --path brewmagic "$mode" "$preset" "$PWD/$out" >"$log" 2>&1 \
  || grep -qE "ERROR|WARNING" "$log" || [ ! -s "$out" ]; then
  echo "FAIL export $preset (log: $log)" >&2
  grep -E "ERROR|WARNING|keystore" "$log" >&2 || true
  exit 1
fi

if [ "$preset" = "Android" ]; then
  aapt2="$(ls -d "$ANDROID_SDK"/build-tools/*/aapt2 | sort -V | tail -1)"
  badging="$("$aapt2" dump badging "$out")"
  echo "$badging" | grep -E "^(package|sdkVersion|targetSdkVersion|application-label|native-code):"
  echo "$badging" | grep -q "name='com.linostar.brewmagic'" || { echo "FAIL $out has the wrong package" >&2; exit 1; }
fi
echo "PASS build: $out ($(du -h "$out" | cut -f1))"
