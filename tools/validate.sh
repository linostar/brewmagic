#!/usr/bin/env bash
# Validation gate: pixel art check (when tools/pixelart.py exists), asset import,
# project check (touch-first restriction + strict script compile), headless
# gameplay tests, content tests (when tools/test_content.gd exists), headless
# run of the main scene. Exits non-zero on the first failure and points at the
# log that explains it. Every Godot call is killed after GODOT_TIMEOUT seconds.
# Env: GODOT (Godot binary), GODOT_TIMEOUT (default 300), RUN_FRAMES (headless run length, default 300).
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
GODOT_TIMEOUT="${GODOT_TIMEOUT:-300}"
LOG_DIR=build/logs
mkdir -p "$LOG_DIR"

fail() {
  echo "FAIL $1 (log: $2)" >&2
  grep -E "ERROR|WARNING|check_project|test_gameplay|test_content|run_main|pixelart" "$2" >&2 || true
  exit 1
}

# Runs Godot with a hard timeout (macOS has no coreutils `timeout`; perl's alarm
# kills the process with SIGALRM, exit status 142). Usage: godot <log> <args...>
godot() {
  local log="$1"
  shift
  local status=0
  perl -e 'alarm shift @ARGV; exec @ARGV or die "exec failed: $!\n"' "$GODOT_TIMEOUT" "$GODOT" "$@" >"$log" 2>&1 || status=$?
  if [ "$status" -eq 142 ]; then
    echo "ERROR: timed out after ${GODOT_TIMEOUT}s" >>"$log"
  fi
  return "$status"
}

# Runs a Godot --script and requires its explicit OK line and a log free of
# ERROR/WARNING. Usage: run_script <name> <log> <extra godot args...>
run_script() {
  local name="$1" log="$2"
  shift 2
  # Godot exits 0 even when a --script fails to compile, so the explicit OK line
  # is the only trustworthy success signal for script runs.
  godot "$log" --headless --path brewmagic "$@" --script "$PWD/tools/$name.gd" || true
  if ! grep -q "^$name: OK" "$log" || grep -qE "ERROR|WARNING" "$log"; then
    fail "$name" "$log"
  fi
}

# The compiled sprites must match their sources before Godot imports them.
if [ -f tools/pixelart.py ]; then
  if ! python3 tools/pixelart.py --check >"$LOG_DIR/pixelart.log" 2>&1 || ! grep -q "^pixelart: OK" "$LOG_DIR/pixelart.log"; then
    fail "pixel art check" "$LOG_DIR/pixelart.log"
  fi
fi

# On a fresh clone (no import cache) the first import reports errors because the
# project's default font is loaded before its TTF has been imported. A priming
# import fills the cache; the checked import below then must be clean.
# Only those font errors are tolerated there.
if [ ! -d brewmagic/.godot/imported ]; then
  godot "$LOG_DIR/import_prime.log" --headless --path brewmagic --import || true
  if grep -E "ERROR|WARNING" "$LOG_DIR/import_prime.log" | grep -qvE "PixelifySans-Variable\.ttf"; then
    fail "priming import reported problems besides the project font" "$LOG_DIR/import_prime.log"
  fi
fi
godot "$LOG_DIR/import.log" --headless --path brewmagic --import || fail "import exited non-zero" "$LOG_DIR/import.log"
if grep -qE "ERROR|WARNING" "$LOG_DIR/import.log"; then fail "import reported problems" "$LOG_DIR/import.log"; fi

run_script check_project "$LOG_DIR/check.log"
run_script test_gameplay "$LOG_DIR/test.log" --fixed-fps 60
summary="$(grep "^check_project: OK" "$LOG_DIR/check.log"); $(grep "^test_gameplay: OK" "$LOG_DIR/test.log")"
if [ -f tools/test_content.gd ]; then
  run_script test_content "$LOG_DIR/content.log"
  summary="$summary; $(grep "^test_content: OK" "$LOG_DIR/content.log")"
fi
RUN_FRAMES="${RUN_FRAMES:-300}" run_script run_main "$LOG_DIR/run.log"

echo "PASS validate ($summary)"
