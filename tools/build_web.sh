#!/usr/bin/env bash
# Full release pipeline: validate, clean single-threaded web export to
# build/web/, Playwright smoke test (desktop, mobile emulation, keyboard), then
# build/brewmagic.zip for itch.io
# (index.html at the zip root, no macOS metadata).
# Env: GODOT (Godot binary).
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
LOG_DIR=build/logs
export GODOT

tools/validate.sh

rm -rf build/web
mkdir -p build/web "$LOG_DIR"
if ! "$GODOT" --headless --path brewmagic --export-release Web "$PWD/build/web/index.html" >"$LOG_DIR/export.log" 2>&1 \
  || grep -qE "ERROR|WARNING" "$LOG_DIR/export.log"; then
  echo "FAIL export (log: $LOG_DIR/export.log)" >&2
  grep -E "ERROR|WARNING" "$LOG_DIR/export.log" >&2 || true
  exit 1
fi
for file in index.html index.js index.wasm index.pck; do
  [ -s "build/web/$file" ] || { echo "FAIL export is missing build/web/$file" >&2; exit 1; }
done

node tools/smoke_web.mjs build/web

rm -f build/brewmagic.zip
# The font's SIL OFL licence travels with the game.
cp brewmagic/fonts/OFL.txt build/web/FONT-LICENSE-PixelifySans-OFL.txt
(cd build/web && zip -X -q ../brewmagic.zip index.* FONT-LICENSE-PixelifySans-OFL.txt)
echo "PASS build: build/brewmagic.zip ($(du -h build/brewmagic.zip | cut -f1))"
