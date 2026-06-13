# Breadboard — Notebook Awakening

Designing from shaped parts (GAME_DESIGN.md). Places = game states/scenes.

## Places

| # | Place | Description |
|---|-------|-------------|
| P1 | Title Screen | Start screen, "press to awaken" |
| P2 | Gameplay (Notebook) | The sheet — movement, hazards, survival |
| P3 | End Screen | Notebook-close cinematic + win/lose message + score + restart |
| P4 | HTML Shell | The exported `index.html` wrapper (Sentry JS lives here) |

## Parts (mechanisms)

| Part | Mechanism |
|------|-----------|
| F1 | Player movement (top-down, WASD/arrows, 200 px/s, clamped to sheet) |
| F2 | Player health (3 lives, figure fades per hit, i-frames + blink) |
| F3 | Pencil shadow: chases player (~140 px/s), commits + flashes ~0.9s, draws ink |
| F4 | Ink hazard (persistent Line2D + collision, damages on touch) |
| F5 | Eraser (spawns after timer, chases ~120 px/s, kills on touch, erases ink) |
| F6 | Survival timer / score (= seconds survived) |
| F7 | Escape edge (opens when eraser spawns; reaching it = win) |
| F8 | Escape cinematic (scripted jump tween) + notebook close |
| F9 | End screen (win/lose message + final score + restart) |
| F10 | Sentry JS in HTML shell (browser error capture) |

## UI Affordances

| # | Place | Component | Affordance | Control | Wires Out | Returns To |
|---|-------|-----------|------------|---------|-----------|------------|
| U1 | P1 | TitleScreen | "Press to Awaken" prompt | render | — | — |
| U2 | P1 | TitleScreen | Start input (any key/click) | press | → P2 | — |
| U3 | P2 | Player | player sprite (fades w/ health) | render | — | — |
| U4 | P2 | Notebook | sheet background + doodle decor | render | — | — |
| U5 | P2 | PencilShadow | shadow marker (tracking) | render | — | — |
| U6 | P2 | PencilShadow | commit flash (telegraph) | render | — | — |
| U7 | P2 | Ink | ink stroke (hazard) | render | — | — |
| U8 | P2 | Eraser | eraser sprite (chasing) | render | — | — |
| U9 | P2 | HUD | score / timer label | render | — | — |
| U10 | P2 | EscapeEdge | glowing escape edge | render | — | — |
| U11 | P3 | EndScreen | notebook-close animation | render | — | — |
| U12 | P3 | EndScreen | win/lose message | render | — | — |
| U13 | P3 | EndScreen | final score | render | — | — |
| U14 | P3 | EndScreen | "Press to retry" input | press | → P2 | — |

## Code Affordances

| # | Place | Component | Affordance | Control | Wires Out | Returns To |
|---|-------|-----------|------------|---------|-----------|------------|
| N1 | P2 | Player | `_physics_process()` read input | call | → N2 | — |
| N2 | P2 | Player | `move_and_slide()` + clamp to sheet | call | → S1 | → U3 |
| N3 | P2 | Player | `take_damage()` (dec health, i-frames) | call | → S2, → N4 | — |
| N4 | P2 | Player | `update_fade()` (modulate by health) | call | — | → U3 |
| N5 | P2 | Player | `die()` | call | → N20 | — |
| N6 | P2 | PencilShadow | `_process()` lerp toward player | call | → S1(read), → U5 | — |
| N7 | P2 | PencilShadow | `commit()` (stop, flash timer) | call | → U6, → N8 | — |
| N8 | P2 | PencilShadow | `draw_ink()` (spawn Ink at point) | call | → N9 | — |
| N9 | P2 | Ink | `spawn()` Line2D + Area2D collider | call | → S3 | → U7 |
| N10 | P2 | Ink | ink `area_entered(player)` | signal | → N3 | — |
| N11 | P2 | GameManager | survival `Timer` tick | observe | → S4, → N12 | — |
| N12 | P2 | GameManager | `check_eraser_trigger()` (t≥threshold) | call | → N13, → N16 | — |
| N13 | P2 | Eraser | `spawn()` from page corner | call | → S5 | → U8 |
| N14 | P2 | Eraser | `_process()` chase player | call | → S1(read), → U8 | — |
| N15 | P2 | Eraser | erase-ink `area_entered(ink)` | signal | → S3(remove) | — |
| N16 | P2 | EscapeEdge | `open()` (enable + glow) | call | → S6 | → U10 |
| N17 | P2 | EscapeEdge | `body_entered(player)` | signal | → N18 | — |
| N18 | P2 | GameManager | `win()` | call | → N19, → P3 | — |
| N19 | P2 | GameManager | `final_score` = S4 | write | → S7 | — |
| N20 | P2 | GameManager | `lose()` | call | → N19, → P3 | — |
| N21 | P3 | EndScreen | `play_close_cinematic()` (tween) | call | → U11 | — |
| N22 | P3 | EndScreen | `show_result(won, score)` | call | — | → U12, U13 |
| N23 | P1/P3 | GameManager | `start_game()` (load P2) | call | → P2 | — |
| N24 | P4 | HTML shell | Sentry JS `init()` | call | → S8 | — |
| N25 | P2 | Eraser | eraser `body_entered(player)` | signal | → N5 | — |

## Data Stores

| # | Place | Store | Description |
|---|-------|-------|-------------|
| S1 | P2 | `player_position` | Read by pencil shadow + eraser to chase |
| S2 | P2 | `health` (int 0-3) | Drives fade + death |
| S3 | P2 | `active_ink[]` | Live ink hazards (erasable) |
| S4 | P2 | `survival_time` | Seconds survived (score source) |
| S5 | P2 | `eraser_active` (bool) | Phase 2 flag |
| S6 | P2 | `escape_open` (bool) | Whether edge is reachable |
| S7 | P3 | `final_score` | Passed to end screen |
| S8 | P4 | Sentry (browser) | External error store |

## Vertical Slices

| # | Slice | Mechanism | Affordances | Demo |
|---|-------|-----------|-------------|------|
| V1 | Move on the sheet | F1 | U3, U4, N1, N2, S1 + P1/U1,U2,N23 | "Stick figure moves WASD/arrows, clamped to sheet, from title" |
| V2 | Pencil hazard + health | F2,F3,F4 | U5,U6,U7, N3-N10, S2,S3 | "Pencil shadow chases, flashes, draws ink; touching ink fades figure; 3 hits = die" |
| V3 | Survival + eraser + escape | F5,F6,F7 | U8,U9,U10, N11-N17,N25, S4,S5,S6 | "Score climbs; ~60s eraser spawns, chases+kills+erases ink, edge opens" |
| V4 | Win/Lose cinematic | F8,F9 | U11-U14, N18-N23, S7 | "Reach edge → notebook closes → WIN+score; die → notebook closes → LOSE; retry" |
| V5 | Web + Sentry | F10 | U(html), N24, S8 | "Runs in itch browser (nothreads export); Sentry JS catches errors" |

Implementation order: V1 → V2 → V3 → V4 → V5. Each slice ends in a runnable, demoable state.
