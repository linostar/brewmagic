#!/usr/bin/env bash
# iOS build: validate, export the "iOS" preset as an Xcode project (build/ios/brewmagic.xcodeproj),
# then build it with xcodebuild:
#   (default)    an unsigned simulator app (x86_64: Godot 4.7.1 ships its simulator library for
#                x86_64 only, so Apple Silicon runs it under Rosetta 2), installed and launched on a booted simulator if
#                one is running (xcrun simctl boot "iPhone 16" first);
#   --ipa METHOD a signed .ipa in build/ios/ipa/ through automatic signing with the preset's
#                team (application/app_store_team_id): METHOD is "debugging" (a registered
#                device; a free Personal Team works) or "app-store-connect" (needs the paid
#                Apple Developer Program; upload the .ipa with Transporter or xcrun altool).
# Needs: the Godot 4.7.1 iOS export template (templates/ios.zip) and Xcode signed in to the
# team (Xcode > Settings > Accounts). Env: GODOT (Godot binary).
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
LOG_DIR=build/logs
export GODOT
method=""
if [ "${1:-}" = "--ipa" ]; then
  method="${2:?usage: tools/build_ios.sh [--ipa debugging|app-store-connect]}"
fi

tools/validate.sh

mkdir -p build/ios "$LOG_DIR"
rm -rf build/ios/brewmagic build/ios/brewmagic.xcodeproj build/ios/brewmagic.pck
log="$LOG_DIR/export_ios.log"
# Godot 4.7.1's launch storyboard still reads the removed setting application/boot_splash/fullsize
# and warns; that one warning is tolerated, any other fails the build.
problems() { grep -E "ERROR|WARNING" "$log" | grep -v "Property not found: application/boot_splash/fullsize"; }
if ! "$GODOT" --headless --path brewmagic --export-release "iOS" "$PWD/build/ios/brewmagic.ipa" >"$log" 2>&1 \
  || problems >/dev/null || [ ! -d build/ios/brewmagic.xcodeproj ]; then
  echo "FAIL export iOS (log: $log)" >&2
  problems >&2 || true
  exit 1
fi

xlog="$LOG_DIR/xcodebuild_ios.log"
if [ -z "$method" ]; then
  if ! xcodebuild -project build/ios/brewmagic.xcodeproj -scheme brewmagic -configuration Release \
    -sdk iphonesimulator -destination "generic/platform=iOS Simulator" -derivedDataPath build/ios/derived \
    ARCHS=x86_64 ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO build >"$xlog" 2>&1; then
    echo "FAIL xcodebuild (log: $xlog)" >&2; grep -E "error:" "$xlog" >&2 || true; exit 1
  fi
  app="$(ls -d build/ios/derived/Build/Products/Release-iphonesimulator/*.app | head -1)"
  echo "PASS build: $app"
  if xcrun simctl list devices booted | grep -q Booted; then
    xcrun simctl install booted "$app"
    xcrun simctl launch booted com.uniquity.brewmagic
  fi
  exit 0
fi

archive=build/ios/brewmagic.xcarchive
rm -rf "$archive" build/ios/ipa
if ! xcodebuild -project build/ios/brewmagic.xcodeproj -scheme brewmagic -configuration Release \
  -destination "generic/platform=iOS" -archivePath "$archive" -allowProvisioningUpdates archive >"$xlog" 2>&1; then
  echo "FAIL xcodebuild archive (log: $xlog)" >&2; grep -E "error:" "$xlog" >&2 || true; exit 1
fi
team="$(sed -n 's/^application\/app_store_team_id="\(.*\)"$/\1/p' brewmagic/export_presets.cfg)"
plist=build/ios/ExportOptions.plist
cat >"$plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>method</key><string>$method</string>
<key>teamID</key><string>$team</string>
<key>signingStyle</key><string>automatic</string>
</dict></plist>
EOF
if ! xcodebuild -exportArchive -archivePath "$archive" -exportOptionsPlist "$plist" -exportPath build/ios/ipa \
  -allowProvisioningUpdates >>"$xlog" 2>&1; then
  echo "FAIL xcodebuild -exportArchive (log: $xlog)" >&2; grep -E "error:" "$xlog" >&2 || true; exit 1
fi
ipa="$(ls build/ios/ipa/*.ipa | head -1)"
echo "PASS build: $ipa ($(du -h "$ipa" | cut -f1))"
