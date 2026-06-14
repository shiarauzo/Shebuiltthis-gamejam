#!/usr/bin/env bash
# End-to-end browser test for Notebook Awakening using agent-browser (real Chrome).
# Exports the web build, serves it, plays it, and asserts the full new flow
# (intro -> play -> 5 page flips -> win, plus the lose path) via the
# window.__AWAKE state bridge + console-error checks.
#
# Usage: bash tests/e2e/e2e.sh   (exit 0 = pass)

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

cleanup() { agent-browser close --all >/dev/null 2>&1; [ -n "${SRV:-}" ] && kill "$SRV" >/dev/null 2>&1; }
trap cleanup EXIT

echo "[e2e] export web build"
"$GODOT" --headless --export-release "Web" build/web/index.html >/tmp/e2e_export.log 2>&1 || { echo "export failed"; exit 1; }

echo "[e2e] serve build/web on :$PORT"
python3 -m http.server "$PORT" --directory build/web >/tmp/e2e_httpd.log 2>&1 &
SRV=$!
sleep 1

num()    { agent-browser eval "(window.__AWAKE||{}).$1 ?? 0" 2>/dev/null | grep -oE '[0-9]+' | tail -1; }
bool()   { agent-browser eval "(window.__AWAKE||{}).$1 === true" 2>/dev/null | grep -oE 'true|false' | tail -1; }
sstate() { agent-browser eval "(window.__AWAKE||{}).state || 'none'" 2>/dev/null | grep -oE 'opening|intro|play|flip|ending|done|none' | tail -1; }

start_game() {
  agent-browser open "$URL" >/dev/null 2>&1
  for i in $(seq 1 60); do
    r=$(agent-browser eval "(document.getElementById('status')?0:1)" 2>/dev/null | grep -oE '[01]' | tail -1)
    cw=$(agent-browser eval "(document.getElementById('canvas')||{}).width||0" 2>/dev/null | grep -oE '[0-9]+' | tail -1)
    [ "${r:-0}" = "1" ] && [ "${cw:-0}" -gt 0 ] && break
    sleep 0.5
  done
  agent-browser eval "window.__AWAKE_FAST=1" >/dev/null 2>&1
  agent-browser click "#canvas" >/dev/null 2>&1   # start from the title
}

# ---- scenario 1: intro -> play -> 5 pages -> win -------------------------
echo "[e2e] open $URL"
start_game
[ -n "$(sstate)" ] && ok "engine started" || no "engine did not start"
agent-browser screenshot "$SHOTS/01-start.png" >/dev/null 2>&1

# Wait for the intro to hand off to play.
played=0
for i in $(seq 1 30); do [ "$(sstate)" = "play" ] && { played=1; break; }; sleep 0.5; done
[ "$played" = "1" ] && ok "intro hands off to play" || no "never reached play (state=$(sstate))"
agent-browser screenshot "$SHOTS/02-play.png" >/dev/null 2>&1

# Hold a touch (mouse-emulated) at the right edge: the doodle runs there and
# auto-advances page after page.
agent-browser mouse move 1245 360 >/dev/null 2>&1
agent-browser mouse down >/dev/null 2>&1
max_page=1; won=""
for i in $(seq 1 120); do
  agent-browser mouse move 1245 360 >/dev/null 2>&1
  p=$(num page); p=${p:-1}
  [ "$p" -gt "$max_page" ] 2>/dev/null && max_page=$p
  if [ "$(bool ended)" = "true" ]; then won=$(bool won); break; fi
  sleep 0.3
done
agent-browser mouse up >/dev/null 2>&1
agent-browser screenshot "$SHOTS/03-win.png" >/dev/null 2>&1
echo "[e2e] scenario 1: max_page=$max_page ended won=${won:-?}"
[ "$max_page" -ge 5 ] 2>/dev/null && ok "advanced through all 5 pages" || no "did not reach page 5 (max=$max_page)"
[ "$won" = "true" ] && ok "runs out of the notebook and wins" || no "win failed (won=${won:-?})"

# ---- scenario 2: reach a threat page, then stand still -> lose -----------
# Threats are now incremental (pencil page 2, eraser page 3), so page 1 is safe.
# Advance to page 3 where the eraser appears, then stop and let it drain us.
echo "[e2e] --- scenario 2: reach the eraser page, then stand still ---"
start_game
for i in $(seq 1 30); do [ "$(sstate)" = "play" ] && break; sleep 0.5; done
agent-browser mouse move 1245 360 >/dev/null 2>&1
agent-browser mouse down >/dev/null 2>&1
for i in $(seq 1 60); do
  agent-browser mouse move 1245 360 >/dev/null 2>&1
  p=$(num page); p=${p:-1}
  [ "$p" -ge 3 ] 2>/dev/null && break
  sleep 0.3
done
agent-browser mouse up >/dev/null 2>&1   # release: the doodle stands still on page 3
echo "[e2e] scenario 2: reached page $(num page), standing still"
won2=""
for i in $(seq 1 40); do
  if [ "$(bool ended)" = "true" ]; then won2=$(bool won); break; fi
  sleep 0.5
done
echo "[e2e] scenario 2: ended won=${won2:-?}"
[ "$won2" = "false" ] && ok "standing still on a threat page loses" || no "expected a loss (won=${won2:-?})"

# ---- page errors --------------------------------------------------------
errs=$(agent-browser errors 2>/dev/null | grep -iE "error|exception|uncaught" | grep -viE "no errors|0 error" | head -5)
[ -z "$errs" ] && ok "no page errors" || no "page errors: $errs"

echo ""
echo "==== E2E SUMMARY ===="
echo "PASSED: $PASS   FAILED: $FAIL"
[ "$FAIL" -eq 0 ] && echo "RESULT: ALL E2E PASSED" || echo "RESULT: E2E FAILURES"
[ "$FAIL" -eq 0 ]
