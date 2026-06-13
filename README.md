# Notebook Awakening

A tiny top-down survival game for **She Built This: Game Jam** (powered by Sentry).
**Theme: Awakening.**

You are a stick figure doodled in the margin of a notebook — and you've just *woken up*.
A giant pencil hunts you across the page, scribbling ink that hurts. Survive long enough
and the page's eraser awakens too: it chases everything and wipes the ink away. Outlast it,
then sprint to the glowing edge and **leap out of the page** before the notebook closes.

Built in **Godot 4.5**, exported to **HTML5/WebGL** for itch.io.

## Controls
- **Move:** WASD or Arrow keys
- **Any key / click:** start, and retry on the end screen

## How it plays
1. **Phase 1 — Dodge:** the pencil's shadow chases you, locks onto a spot, flashes a
   preview of its stroke, then inks it. Ink is permanent and damaging. You have 3 lives —
   each hit fades your figure (your body *is* your health bar).
2. **Phase 2 — Survive:** the eraser awakens and hunts you, erasing ink in its path.
   Survive it for a while and the right edge of the page opens.
3. **Escape:** reach the glowing edge to jump out and win. Your score is how long you survived.

## Run it locally
Open the project in Godot 4.5 and press Play, or from the CLI:

```
"/Applications/Godot.app/Contents/MacOS/Godot" --path .
```

## Export the web build (for itch.io)
A `Web` export preset is already configured (`export_presets.cfg`).

```
"/Applications/Godot.app/Contents/MacOS/Godot" --headless --export-release "Web" build/web/index.html
```

> **Important — itch.io compatibility:** the preset exports with **Thread Support OFF**
> (`variant/thread_support=false`). Threaded web builds need `SharedArrayBuffer` /
> cross-origin-isolation headers that itch.io does not send by default, which would show a
> black screen. The no-threads build runs anywhere.

To publish: zip the **contents** of `build/web/` (so `index.html` is at the zip root),
upload to itch.io, and tick **"This file will be played in the browser."**

## Sentry
The web shell (`web/shell.html`) includes the Sentry JavaScript SDK. It's a safe no-op until
you add your DSN: open the exported `build/web/index.html` (or the shell before exporting) and
set `var SENTRY_DSN = "...";` to your project DSN.

## Tests
Headless integration tests cover movement, damage/i-frames, death, ink spawning, the phase-2
trigger, ink erasing, win, and lose:

```
"/Applications/Godot.app/Contents/MacOS/Godot" --headless res://tests/test_main.tscn
# results stream to tests/last_run.log; exit code 0 = all passed
```

## Project layout
- `scenes/` — `title`, `game`, `end` (minimal roots; the world is built in code)
- `scripts/` — `player`, `pencil`, `ink`, `eraser`, `escape_edge`, `notebook`, orchestrator `game.gd`, autoload `game_state.gd`
- `web/shell.html` — custom HTML shell with the Sentry snippet
- `tests/` — headless test harness
- `GAME_DESIGN.md`, `BREADBOARD.md` — design docs
- `CREDITS.txt` — asset disclosure (jam requirement)

## Credits
See [`CREDITS.txt`](CREDITS.txt). Art is procedural placeholder; audio to be added from
free/CC libraries (credited). No generative AI was used for art, music, or written assets;
AI coding assistance was used for programming (permitted by the jam rules).
