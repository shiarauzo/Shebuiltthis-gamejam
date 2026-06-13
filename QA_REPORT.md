# QA Report — Notebook Awakening

**Reviewer:** QA pass (independent test + review)
**Date:** 2026-06-13
**Engine:** Godot 4.5.1.stable · Target: HTML5/WebGL (itch.io)
**Build under test:** `build/web/` (re-exported fresh during this pass)

---

## Verdict: **SHIP** (with two recommended FIX-FIRST balance/polish items)

The game is functionally complete and demoable end-to-end. All automated logic
tests pass, the web build loads and runs in real headless Chromium with zero
console/page errors, and the export meets the itch.io no-threads requirement.
Nothing here is a blocker. The two items worth fixing before submission are a
**trivially cheeseable win** and the **missing escape "jump" cinematic** called
for in the design doc — both directly affect Gameplay/Fun and Theme scoring.

---

## What I verified passing (with actual numbers)

### 1) Headless logic test harness — **15 PASSED / 0 FAILED**
Command: `Godot --headless res://tests/test_main.tscn` → exit code 0.
`tests/last_run.log` end state: `PASSED: 15   FAILED: 0` / `RESULT: ALL TESTS PASSED`.

Covered: movement (dx=63.3 on D), damage + i-frames (hp 3→2, second hit ignored,
fade a=0.78), death after 3 hits (loss registered), pencil draws ink (ink=1),
phase-2 trigger (phase=2, eraser spawned, edge opened), eraser erases ink,
win on reaching edge, lose on eraser contact.

### 2) Web build loads in real browser — **STARTED, no errors**
Served `build/web/` via `python3 -m http.server 8099`, drove with Playwright
headless-chromium:
- `STARTED: true` — `#status` overlay removed, no fatal `#status-notice`.
- **Canvas: 1280x720** (>0).
- **Console errors / pageerrors: none** (Sentry CDN ignored per instructions).
- Engine log confirms `single-threaded, no GDExtension support` and
  `Godot Engine v4.5.1.stable`.
- Title screen and gameplay both rendered correctly (screenshots
  `/tmp/awake_web_title.png`, `/tmp/awake_web_game.png`). Key press transitioned
  title → gameplay; pencil, ink telegraph, HUD, and procedural notebook art all
  drew as intended.

### 3) Fresh re-export reproducible & no-threads — **confirmed**
`Godot --headless --export-release "Web" build/web/index.html` succeeded.
In the emitted `build/web/index.html`:
- `GODOT_THREADS_ENABLED = false` (line 139) — satisfies itch.io / no
  SharedArrayBuffer requirement.
- Sentry JS snippet present (sentry-cdn bundle 7.120.3, `SENTRY_DSN` hook,
  `release: "notebook-awakening@0.1.0"`).
- **Zero** leftover `$GODOT` placeholders.
- `export_presets.cfg` correctly sets `variant/thread_support=false`,
  `custom_html_shell=res://web/shell.html`, GL Compatibility.

---

## Issues

| # | Severity | Issue | File:line |
|---|----------|-------|-----------|
| 1 | **major** | Win is trivially cheeseable. In phase 2 the only objective is to touch the right edge. Player starts mid-page (x=640) and the edge band is at x≈1192–1232; that is ~552 px = ~2.8 s at SPEED 200. The eraser spawns at the far top-left corner (`r.position + (28,28)` ≈ (76,76)) at SPEED 120 (0.6× player) and never threatens a player who hugs the right side during phase 1 then sprints right when the edge opens. The whole "win" can be completed in ~33 s with near-zero risk; escape feels unearned. | `scripts/game.gd:80` (eraser spawn corner), `scripts/escape_edge.gd:25` (open) |
| 2 | **major** | No escape "jump out of the page" cinematic. Design F8 / GAME_DESIGN line 11 calls for a scripted jump tween before the notebook closes. `_end_game()` calls `change_scene_to_file()` immediately, so on win the player teleports straight to the end screen with no jump/leap beat. The notebook-close tween exists only on the end screen (`end.gd`). Theme ("escape") payoff is weaker than designed. | `scripts/game.gd:100` |
| 3 | **minor** | Ink drawn exactly on a stationary player deals no damage. `Ink` damage fires on `Area2D.body_entered`, which only triggers on *entry*. The pencil commits at its own position (`_commit_pos = global_position`) while chasing the player, so a stroke can spawn already overlapping an idle player — Godot emits no entry event, so the hit is silently skipped until the player moves into/out of it. Works in the player's favor (less unfair) but makes the central pencil threat softer than intended and is non-obvious behavior. | `scripts/ink.gd:36-40`, `scripts/pencil.gd:37,48-52` |
| 4 | **minor** | `eraser_trigger_time` default 30 s is on the short side for a "~2–4 min" framing. With issue #1, a confident run ends in ~33 s. Survival score (the headline metric) barely climbs because phase 1 is the only real survival window. | `scripts/game.gd:7` |
| 5 | **minor** | Pencil telegraph is dodgeable but tight against walls. 0.9 s flash = ~180 px of run room vs a 130 px stroke (65 px half-length). Fine in open space, but a player pinned in a corner when the pencil commits has little room. Not unfair given i-frames (1.2 s) + 3 lives, but worth a playtest. | `scripts/pencil.gd:8-9`, `scripts/player.gd:11` |
| 6 | **nit** | No audio (known/intentional — assets come later) and `CREDITS.txt` not yet present. Design explicitly warns "no entregues mudo"; silent web build will cost Visuals/**Audio** points. Track for the audio pass. | n/a |
| 7 | **nit** | `SENTRY_DSN` is empty, so Sentry is present but inert. Fine for "minimum snippet" requirement; set a real DSN if you want actual browser error capture during judging. | `web/shell.html:103` |

### Confirmed NOT issues (checked)
- **Winnable & losable:** both verified by tests and by reachability math. Player
  (200) outruns pencil (140, 0.7×) and eraser (120, 0.6×), so the game is always
  survivable in open space — fair. Edge collider (x 1192–1232) is reachable: a
  player clamped to max x=1220 with radius 12 overlaps the band.
- **No hard soft-locks:** pencil/eraser clamp to the sheet; player is clamped;
  ended-guard (`if ended: return`) prevents double resolution; retry path
  (`end.gd` → `game.tscn`) works.
- **Collision wiring correct:** player on layer 1 / mask 0; ink, eraser, escape
  edge all monitor mask 1. No cross-talk.

---

## Prioritized recommendations to win the jam

1. **Make the escape earned (fixes #1, biggest Gameplay/Fun + Theme win).**
   Spawn the eraser from the side the player must cross toward, or from behind the
   player, or spawn 2 erasers / a sweeping eraser, so the dash to the edge is a
   real chase. Alternatively delay the edge from opening a beat after the eraser
   spawns. Low effort, high payoff.

2. **Add the jump-out cinematic before the notebook closes (fixes #2).**
   A ~0.4–0.6 s tween of the stick figure leaping off the right edge (scale up +
   arc up-right + fade) in `game.gd` before `change_scene_to_file`, gated by
   `Game.testing` like `_end_game` already is, lands the "Awakening → escape"
   theme beat. This is the single most theme-relevant missing piece.

3. **Audio + CREDITS.txt before submission (fixes #6).**
   Even a lo-fi ambient loop + pencil-scratch / eraser-rub / page-flip SFX
   (Freesound CC0) materially lifts Visuals/Audio. Register every asset in
   `CREDITS.txt`. The design doc flags this as a SÍ-o-SÍ reservation.

4. **Lean into the art-style prize.** Procedural doodle look already reads well
   (verified in screenshot) — the trembling-line / ruled-paper aesthetic is the
   strongest "Most Interesting Art Style" asset. Consider a subtle hand-jitter on
   the stroke widths / a slight wobble on the stick figure to push it further.

5. **Optional balance tune:** bump `eraser_trigger_time` to ~45–60 s and/or make
   the pencil commit *ahead* of the player's velocity rather than on its own
   position, so ink lands where the player is heading (also sidesteps the
   on-top-of-player no-damage edge case in #3).
