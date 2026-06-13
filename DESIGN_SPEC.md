# Notebook Awakening — Art Direction Spec

**For:** Shiara (solo dev, hand-drawing all assets in Krita/Photoshop — NO AI art)
**Deadline:** tomorrow. This spec is built to be drawn by ONE person in ~2-3 hours.
**Bet:** the "Most Interesting Art Style" special prize. Interesting, not pretty.

---

## 1. Art style statement

**Ballpoint-on-lined-paper doodle.** Everything looks like it was scribbled in the
margin of a real school notebook during a boring class: shaky, single-weight pen
strokes, lines that don't quite close, accidental double-strokes, slightly-off
fills that bleed past their own outline. The "camera" is the page itself. Lean hard
into authenticity — scan or photograph a real lined page if you can, draw with a
textured ballpoint/ink brush at 100% (no smoothing, no perfect circles), and leave
the wobble in. That deliberate imperfection is exactly what makes it *interesting*:
it reads as a living drawing, not a polished game, which sells the whole premise (a
doodle that woke up) and stands out in a sea of clean pixel-art and vector entries.
Rule of thumb: **if a line looks like a tool drew it, redraw it by hand.**

---

## 2. Color palette

Pulled directly from the current code so swapped art stays consistent.

| Role | Hex | Notes (matches code) |
|------|------|----------------------|
| Paper cream | `#FAF7E6` | page + all screen backgrounds |
| Paper border | `#CCCCBD` | faint page edge |
| Ruled line blue | `#9EBCE6` | horizontal rules (~55% alpha) |
| Red margin | `#E66B75` | vertical margin line |
| Ink blue | `#212D8C` | strokes, title text, score — the "pen" color |
| Ink dark | `#1E1E2E` | player stick figure, near-black outlines |
| Pencil yellow | `#DBA833` | pencil shaft |
| Pencil wood/tip | `#F2D999` | sharpened tip area |
| Pencil lead | `#D98040` | graphite point |
| Eraser pink | `#F28CA8` | eraser body |
| Eraser felt | `#8F66C2` | purple base band |
| Eraser outline | `#4D2E4D` | scribbly dark outline |
| Escape green | `#33E66B` / `#2DCC52` | glowing escape edge |
| Win green | `#33B352` | "YOU ESCAPED!" |
| Lose red | `#D14050` | "ERASED." |
| Notebook cover | `#754A33` / `#6B4230` | end-screen cover panels |
| Cover spine | `#4D2E1F` | spine line |

Keep alphas low on background elements (rules, margin) so gameplay sprites pop.

---

## 3. Asset list

All sprites: **transparent PNG**, drawn on the ink-blue / dark palette above, with
the **origin at the visual center** unless noted (the code currently draws around
each node's origin, so center-pivot makes the swap a 1-line change). Dimensions are
the *recommended canvas*; the figure should fill most of it with a few px of bleed
room. Draw at 2x then export at the listed size if you want crisper lines.

| # | Asset | Canvas (px) | Origin | Description | Save to |
|---|-------|-------------|--------|-------------|---------|
| 1 | Player — idle | 48 × 64 | center | Stick figure: round head, body, arms, 2 legs. ~28px tall figure inside the canvas, wobbly ink. | `assets/sprites/player_idle.png` |
| 2 | Player — hit/scared | 48 × 64 | center | Same figure, panicked: arms up, mouth "O", maybe one sweat drop. Used during i-frame blink. | `assets/sprites/player_hit.png` |
| 3 | Player — leap *(optional)* | 48 × 64 | center | Figure mid-jump, legs tucked, arms forward. For the win cinematic only. | `assets/sprites/player_leap.png` |
| 4 | Giant pencil | 96 × 160 | **bottom-center / tip** | Yellow hex shaft going up-right, sharpened wood tip, dark-orange lead point. Tip = the business end near the page. | `assets/sprites/pencil.png` |
| 5 | Giant eraser | 64 × 80 | center | Pink rubber block, purple felt band across the lower third, scribbly dark outline, a worn smudge on top. | `assets/sprites/eraser.png` |
| 6 | Ink-stroke brush | 160 × 24 | center | A single horizontal pen stroke, ink-blue, round caps, ~130px long with a tiny splatter at one end. Used as the texture/look reference for the Line2D (or as a stamped sprite). | `assets/sprites/ink_stroke.png` |
| 7 | Paper texture | 1184 × 624 | top-left (0,0) | The full page: cream paper grain, optional faint coffee-ring/smudge. **No rules/margin baked in** (code draws those) OR bake them and remove the code — pick one (see Integration). | `assets/sprites/paper.png` |
| 8 | Margin doodles (sheet) | ~256 × 256 each, or 1 sheet | each centered | 4 small static doodles to scatter: star, spiral, cloud, squiggle (match current positions). Drawn as loose pen scribbles. | `assets/sprites/doodles.png` |
| 9 | Title lettering | 720 × 160 | center | Hand-lettered "NOTEBOOK AWAKENING" in shaky ink-blue caps, a couple letters askew, maybe an eye drawn inside an "O". | `assets/sprites/title_text.png` |
| 10 | Notebook cover | 1280 × 720 (or 640×720 half) | — | Closed-book cover for the end: cardboard-brown, a taped label, "MY NOTEBOOK" scrawled, doodles in the corner. Can be one full image or a left/right half. | `assets/sprites/cover.png` |

---

## 4. Animation notes

Keep it to **2-frame swaps**. No real rigs. Three places earn it:

1. **Player walk** — two frames: legs apart / legs crossed. Swap every ~0.15s while
   moving. (Optional: a 3rd idle frame that just breathes.) Files `player_idle.png`
   + a `player_walk.png`, or reuse idle + hit as the two states if time is tight.
2. **Eraser wobble** — two frames tilted ±3-4°, swap every ~0.2s, so the giant
   eraser visibly *jitters* as it chases. Cheap, very alive. `eraser.png` +
   `eraser_b.png` (just rotate-and-redraw a couple outline lines).
3. **Pencil telegraph pulse** — the code already pulses the preview line in code;
   **don't draw frames for this.** Optionally a 2nd pencil frame with the tip
   pressed-down for the inking moment.

Everything else (hit flash, screen shake, leap, notebook close) is already done in
code via tweens — **do not animate those by hand.**

---

## 5. Screen layouts

**Title (1280×720)** — cream page, faint rules behind everything.
```
+--------------------------------------------------------------+
|  (faint ruled lines + red margin run full-page behind)       |
|                                                              |
|            N O T E B O O K   A W A K E N I N G               |  <- title_text.png, ink-blue, wobbly
|            "You are a doodle. You just woke up."             |  <- small ink
|                                                              |
|                        \o/   *  *                            |  <- title doodle pops awake (code tween)
|                         |    sparks                          |
|                        / \                                   |
|                                                              |
|     Move: WASD / Arrows   Dodge the ink. Survive. Escape.    |  <- small grey ink
|                  > Press any key to awaken <                 |  <- pulsing green (code)
+--------------------------------------------------------------+
```

**Gameplay HUD (page = Rect2 48,48,1184,624)** — diegetic, top-left corner.
```
+--------------------------------------------------------------+
| Survived: 12.4s                                  [ giant ]   |  <- HUD text, top-left, ink-dark
| A pencil is scribbling... hold on (10s)          [ pencil ] /|  <- phase line, red-ish
| | (margin)                                                   |
| |        *(star)              ~~~(squiggle)        (spiral)  |  <- static doodles
| |                                                            |
| |                 \o/  <- player                  | |        |  <- ESCAPE EDGE glows
| |                  |                              | |  green |     green when open (right)
| |                 / \           ====(ink)         | |        |
| |   (cloud)                                       | |        |
+--------------------------------------------------------------+
```
HUD text stays as Godot Labels (top-left, ink-dark/red). The escape edge is a
green glow strip on the **right** edge — keep as code draw OR a tall green PNG.

**End / notebook-close (1280×720)** — code sweeps two cover halves shut, holds,
opens to the message.
```
   [ cover sweeps in from sides ]        ...then opens to:
+---------------------+---------------------+   +--------------------------------+
|####### MY ##########|######## NOTEBOOK ###|   |                                |
|####### NOTEBOOK ####|####### (doodles) ###|   |        YOU ESCAPED!  /  ERASED. |
|##### (taped label)##|##### cardboard #####|   |   The notebook closes behind...|
|##### cardboard #####|######## brown ######|   |        Survived: 12.4 seconds  |
|######## brown ######|######## spine | #####|   |   Press any key to wake up again|
+---------------------+---------------------+   +--------------------------------+
        cover.png (brown), spine line center        Labels (green/red, ink-blue)
```

---

## 6. Integration notes

The scripts currently draw everything in `_draw()`. Swapping to art is a small,
mechanical change per node — **origins centered + transparent PNGs make it trivial.**

- **Import:** drop PNGs in `assets/sprites/`. In `import` settings, for this crisp
  hand-drawn look use **Filter = Off (nearest)** if you draw at final size, or keep
  default linear if you draw at 2x and downscale. Mipmaps off.
- **Player (`player.gd`):** add a `Sprite2D` child with `player_idle.png`, delete
  the `_draw()` body (or leave it as fallback). The figure is drawn around origin
  with head at y≈-14 and feet at y≈+22 — so center your 48×64 canvas on that, feet
  near the bottom. Health fade already works via `modulate.a`; the hit/blink uses
  `visible` toggling — to use `player_hit.png` instead, swap the sprite's texture in
  `take_damage()`. **Keep the CircleShape2D (radius 12) untouched.**
- **Pencil (`pencil.gd`):** replace the 3 `draw_line`/`draw_circle` shaft calls with
  a `Sprite2D` (`pencil.png`) whose **pivot is the tip/marker point** (origin), since
  the code moves the node by its marker and draws the shaft going up-right to
  `(46,-112)`. Keep the telegraph + commit-dot draws in code (they pulse). z_index 10.
- **Eraser (`eraser.gd`):** replace the 4 `draw_rect`/`draw_line` calls with a
  centered `Sprite2D` (`eraser.png`) — the body is `Rect2(-25,-33,50,66)`, so a
  64×80 centered PNG fits with margin. **Keep the 50×66 RectangleShape2D and the
  dust CPUParticles2D.** For wobble, swap between two textures on a timer.
- **Notebook (`notebook.gd`):** two options. (A) Easiest: keep the procedural paper,
  rules, margin, and doodles as-is (they already look hand-drawn-ish) and skip
  assets 7-8 entirely. (B) Replace the paper `draw_rect` with a `Sprite2D`
  (`paper.png`) at `Rect2` top-left, and the 4 `_doodle_*` calls with positioned
  doodle sprites. Either way, **keep `Game.sheet_rect` = the layout source of truth.**
- **Ink (`ink.gd`):** simplest win is to keep the `Line2D` (color `#212D8C`, width 5,
  round caps) — it already looks like a pen. `ink_stroke.png` is mainly a *reference*
  for matching your hand-drawn pen texture; only stamp it as a sprite if the Line2D
  looks too clean.
- **Title/End (`title.gd`/`end.gd`):** these are `Control` scenes. Add a
  `TextureRect` for `title_text.png` / `cover.png` over the existing ColorRect bg.
  Cover panels are two `ColorRect`s that slide — swap their color for a `cover.png`
  half-image via TextureRect, keep the slide tweens.
- **General:** transparent backgrounds everywhere, center pivots, don't resize
  collision shapes, don't touch `Game.sheet_rect`.

---

## 7. Scope cuts (if time runs short)

Do these in order; stop when you run out of time. Each cut still looks intentional.

**Minimum must-draw set (looks like a finished, deliberate art game):**
1. **Player idle** (`player_idle.png`) — the star of the show.
2. **Giant pencil** (`pencil.png`) — the main threat, on-screen constantly.
3. **Giant eraser** (`eraser.png`) — the second threat + the climax.
4. **Title lettering** (`title_text.png`) — first impression for judges.

That's **4 sprites.** With those drawn and the rest left procedural, the entry
already reads as a cohesive hand-drawn doodle game.

**Add next, in priority order, as time allows:**
5. Player hit/scared frame (cheap, big juice payoff).
6. Notebook cover for the end screen (nice closing beat).
7. Margin doodles sheet (only if the procedural ones feel too geometric).
8. Eraser wobble 2nd frame.
9. Paper texture / player leap frame.

**Safe to SKIP entirely:** paper texture (procedural paper is fine), ink-stroke
sprite (Line2D is fine), player leap frame (the code tween rotates+scales the idle
sprite and it reads great), doodle replacements (procedural doodles already look
hand-drawn). **Never skip:** player, pencil, eraser — those three carry the prize bet.
