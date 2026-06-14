#!/usr/bin/env bash
# End-to-end browser test for Notebook Awakening using agent-browser (real Chrome).
# Exports the web build, serves it, plays it, and asserts the full game loop via
# the window.__AWAKE state bridge + console-error checks.
#
# Usage: bash tests/e2e/e2e.sh
# Exit 0 = all e2e checks passed, 1 = failure.

set -uo pipefail
cd "$(dirname "$0")/../.."
ROOT="$(pwd)"
GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
PORT=8137
URL="http://localhost:${PORT}/index.html"
SHOTS="$ROOT/tests/e2e/shots"
mkdir -p "$SHOTS"

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  PASS: $1"; }
no()  { FAIL=$((FAIL+1)); echo "  FAIL: $1"; }

cleanup() { agent-browser close >/dev/null 2>&1; [ -n "${SRV:-}" ] && kill "$SRV" >/dev/null 2>&1; }
trap cleanup EXIT

echo "[e2e] export web build"
"$GODOT" --headless --export-release "Web" build/web/index.html >/tmp/e2e_export.log 2>&1 || { echo "export failed"; exit 1; }

echo "[e2e] serve build/web on :$PORT"
python3 -m http.server "$PORT" --directory build/web >/tmp/e2e_httpd.log 2>&1 &
SRV=$!
sleep 1

# Read fields individually — agent-browser prints raw numbers/booleans cleanly,
# whereas JSON.stringify comes back as an escaped string that's painful to parse.
num()  { agent-browser eval "(window.__AWAKE||{}).$1 ?? 0" 2>/dev/null | grep -oE '[0-9]+' | tail -1; }
bool() { agent-browser eval "(window.__AWAKE||{}).$1 === true" 2>/dev/null | grep -oE 'true|false' | tail -1; }

echo "[e2e] open $URL"
agent-browser open "$URL" >/dev/null 2>&1

# Wait for the Godot engine to start (loading overlay #status is removed).
started=0
for i in $(seq 1 60); do
  r=$(agent-browser eval "(document.getElementById('status')?0:1)" 2>/dev/null | grep -oE '[01]' | tail -1)
  cw=$(agent-browser eval "(document.getElementById('canvas')||{}).width||0" 2>/dev/null | grep -oE '[0-9]+' | tail -1)
  if [ "${r:-0}" = "1" ] && [ "${cw:-0}" -gt 0 ]; then started=1; break; fi
  sleep 0.5
done
[ "$started" = "1" ] && ok "engine started (canvas ${cw}px)" || no "engine did not start"

agent-browser screenshot "$SHOTS/01-title.png" >/dev/null 2>&1

# Enable fast mode BEFORE starting, then click the canvas to begin from the title.
agent-browser eval "window.__AWAKE_FAST=1" >/dev/null 2>&1
agent-browser click "#canvas" >/dev/null 2>&1
sleep 0.5

# Poll the state bridge for ~24s, tracking the furthest phase + end state.
max_phase=0; saw_started=0; ended="false"; won=""
for i in $(seq 1 48); do
  p=$(num phase); p=${p:-0}
  [ "$p" -ge 1 ] 2>/dev/null && saw_started=1
  [ "$p" -gt "$max_phase" ] 2>/dev/null && max_phase=$p
  if [ "$(bool ended)" = "true" ]; then ended="true"; won=$(bool won); break; fi
  sleep 0.5
done
echo "[e2e] result: max_phase=$max_phase ended=$ended won=${won:-?}"

agent-browser screenshot "$SHOTS/02-gameplay.png" >/dev/null 2>&1

[ "$saw_started" = "1" ] && ok "game started (phase >= 1)" || no "game never started"
[ "$max_phase" -ge 2 ] 2>/dev/null && ok "reached phase 2 (eraser)" || no "never reached phase 2"
[ "$max_phase" -ge 3 ] 2>/dev/null && ok "reached phase 3 (escape opened)" || no "never reached phase 3"
[ "$ended" = "true" ] && ok "game ended" || no "game never ended within timeout"
[ "$won" = "false" ] && ok "stationary player loses to the eraser" || no "expected a loss (won=$won)"

# No page errors.
errs=$(agent-browser errors 2>/dev/null | grep -iE "error|exception|uncaught" | grep -viE "no errors|0 error" | head -5)
[ -z "$errs" ] && ok "no page errors" || no "page errors: $errs"

echo ""
echo "==== E2E SUMMARY ===="
echo "PASSED: $PASS   FAILED: $FAIL"
[ "$FAIL" -eq 0 ] && echo "RESULT: ALL E2E PASSED" || echo "RESULT: E2E FAILURES"
[ "$FAIL" -eq 0 ]
