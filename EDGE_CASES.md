# Edge-Case & Robustness Audit — Notebook Awakening

Consolidated from a parallel QA edge-case hunt and a senior code review. Each item below
becomes a GitHub issue and is fixed in its own branch/PR. Severity: **blocker** (breaks the
submission or crashes), **major** (visible bug / unfair / perf cliff), **minor** (polish/robustness),
**nit** (cleanliness).

## Blockers
| ID | Severity | Area | Issue | File(s) |
|----|----------|------|-------|---------|
| E1 | blocker | web/input | Keys "stick" when the browser tab/canvas loses focus (no focus-out handler); doodle drifts into hazards while unfocused | `player.gd` |
| E2 | blocker | perf | Unbounded ink accumulation + each ink polls `get_overlapping_bodies()` every physics frame → frame-rate cliff on long runs / mobile | `ink.gd`, `pencil.gd` |
| E3 | blocker | test infra | Test harness writes to `res://` (read-only in web/PCK) → null `FileAccess`, crashes the run outside the editor | `tests/test_main.gd` |

## Majors
| ID | Severity | Area | Issue | File(s) |
|----|----------|------|-------|---------|
| E4 | major | mobile | No touch controls — mobile/tablet visitors can start but cannot move → instant loss | `player.gd`, `title.gd` |
| E5 | major | perf | Eraser scans every ink node via `get_nodes_in_group` each *visual* frame; particle bursts in ink are never freed | `eraser.gd`, `ink.gd` |
| E6 | major | fairness | Pencil commits a stroke centered on a stationary/cornered player with no guaranteed dodge window; eraser is lethal the instant it spawns with no grace/telegraph | `pencil.gd`, `eraser.gd`, `game.gd` |
| E7 | major | robustness | Win-cinematic tween callback captures `self` and calls `get_tree()` with no validity guard; EscapeEdge collision shape positioned in world coords (works only by coincidence) | `game.gd`, `escape_edge.gd` |

## Minors
| ID | Severity | Area | Issue | File(s) |
|----|----------|------|-------|---------|
| E8 | minor | resize | FX/cover rects hardcoded to 1280×720 instead of the actual viewport → overlays misalign if the itch embed isn't 1280×720 or on fullscreen | `game.gd`, `end.gd`, `title.gd` |
| E9 | minor | polish | End screen: retry gated by a magic 1.7s timer instead of the cinematic finishing; rapid key-spam can double-fire the scene change; fade tween races the cover sequence | `end.gd` |
| E10 | minor | input | Title accepts input before the fade/awakening animation; mashing during the WebGL load skips the title unseen | `title.gd` |
| E11 | minor | fairness | Ink stroke endpoints aren't clamped to the page; strokes/splatter can render off the paper at edges | `pencil.gd` |
| E12 | minor | robustness | `shake(mag, 0.0)` would divide by zero → NaN camera offset (no current caller, but unguarded public API) | `game.gd` |

## Nits (batched)
| ID | Severity | Issue | File(s) |
|----|----------|-------|---------|
| E13 | nit | `randomize()` is a no-op in Godot 4; `VW`/`VH` duplicated across screens; lose-path signals collapse into one handler; test `_make_game` awaits only process frames; watchdog exit code 3 undocumented | `game.gd`, `title.gd`, `end.gd`, `tests/test_main.gd` |

## Verified NON-issues (don't re-report)
- Double win/lose is guarded by the `ended` flag in `_end_game`.
- `shake` div-by-zero is currently unreachable (callers pass positive durations) — E12 hardens it defensively anyway.
- Normalized zero-vectors are safe (player returns ZERO; pencil/eraser guard with `length() > 1.0`).

## Audio (tracked separately, not an edge case)
Audio is intentionally not added yet (tasks #4/#5). When added, **start music on the first user
input** (title press) — web browsers block autoplay until a user gesture.
