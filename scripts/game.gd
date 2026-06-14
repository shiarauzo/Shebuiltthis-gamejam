extends Node2D
## Gameplay orchestrator (P2).
##
## Flow:
##   intro  - a pencil draws the doodle; it wakes up ("it is alive! this is so
##            weird."); the artist decides to erase it and the eraser appears
##   play   - dodge the pencil's ink and the eraser; reach the right edge to
##            flip to the next page
##   flip   - page-turn animation; the doodle jumps to the next page
##   ending - after 5 pages the notebook closes and the doodle runs out
##
## Lose at any time by losing all health or being caught by the eraser.

signal game_over(won: bool)

@export var total_pages := 5

const PAPER := Color(0.99, 0.99, 0.98)   # graph-paper sheet colour
const COVER := Color(0.22, 0.45, 0.50)   # closed-notebook cover colour

var state := "opening"      # opening | intro | play | flip | ending
var page := 1
var survival_time := 0.0
var ended := false
var _report_t := 0.0
var _fast := false

var player: Player
var pencil: Pencil
var _erasers_on := false      # eraser rain enabled (from page 3)
var _eraser_timer := 0.0      # time until the next wave drops
var _edge_hint_shown := false # page-1 "the path continues" nudge
var notebook: Notebook
var edge_glow: EscapeEdge
var hud_label: Label
var dialogue_label: Label
var dialogue_box: PanelContainer

# Sketchy heart health display (procedural rough.js SVGs).
var heart_full_tex: Texture2D
var heart_empty_tex: Texture2D
var hearts: Array[TextureRect] = []

# Screen FX
var cam: Camera2D
var flash_rect: ColorRect
var fade_rect: ColorRect
var flip_layer: CanvasLayer

# 3D page-turn: a real lit sheet (Camera3D + QuadMesh in a SubViewport) turns
# over the 2D notebook, so the flip reads as paper rotating in space.
var flip3d_layer: CanvasLayer
var flip_vp: SubViewport
var flip_pivot: Node3D
var flip_mat: StandardMaterial3D

var _shake_t := 0.0
var _shake_dur := 0.0
var _shake_mag := 0.0

func _ready() -> void:
	_fast = Game.web_flag("__AWAKE_FAST")
	var r: Rect2 = Game.sheet_rect

	cam = Camera2D.new()
	cam.position = Vector2(640, 360)
	add_child(cam)
	cam.make_current()

	notebook = Notebook.new()
	notebook.z_index = -10
	add_child(notebook)
	notebook.set_page(1)

	edge_glow = EscapeEdge.new()
	add_child(edge_glow)

	player = Player.new()
	player.global_position = Vector2(r.position.x + 60.0, r.position.y + r.size.y * 0.5)
	add_child(player)
	player.died.connect(_on_player_died)
	player.health_changed.connect(_on_player_hit)
	player.set_physics_process(false)  # not controllable until play begins
	player.modulate.a = 0.0  # hidden until the notebook opens and it's drawn in
	if _fast:
		player.speed_mult = 3.0  # e2e: traverse pages quickly

	pencil = Pencil.new()
	pencil.ink_parent = self
	pencil.global_position = Vector2(r.position.x + r.size.x * 0.5, r.position.y + 24.0)
	add_child(pencil)
	pencil.set_process(false)  # inert until it's introduced on page 2 (also gated by target)
	pencil.visible = false     # hidden until it appears on page 2

	_build_hud()
	_build_fx()
	# Headless tests skip the closed-book cinematic and go straight to the intro.
	if Game.testing:
		_run_intro()
	else:
		_run_open()

# --- Opening: the closed notebook swings open ----------------------------

func _run_open() -> void:
	state = "opening"
	Game.web_report({"state": state, "page": page, "ended": false, "won": false})
	_ensure_flip3d()
	# Dress the turning sheet as the closed cover, laid flat over the page.
	flip_mat.albedo_color = Color(COVER.r, COVER.g, COVER.b, 1.0)
	flip_mat.emission = COVER
	flip_pivot.rotation.y = 0.0
	flip3d_layer.visible = true
	await get_tree().create_timer(0.3 if _fast else 0.9).timeout
	if state != "opening":
		return
	# The cover swings open around the spine, revealing the first page.
	var dur := 0.25 if _fast else 0.9
	var tw := create_tween()
	tw.tween_property(flip_pivot, "rotation:y", -PI, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_method(_set_flip_alpha, 1.0, 0.0, dur * 0.4).set_delay(dur * 0.6)
	await tw.finished
	flip3d_layer.visible = false
	# Restore the paper colour for subsequent page turns.
	flip_mat.albedo_color = Color(PAPER.r, PAPER.g, PAPER.b, 0.0)
	flip_mat.emission = PAPER
	_run_intro()

# --- Intro ---------------------------------------------------------------

func _run_intro() -> void:
	state = "intro"
	Game.web_report({"state": state, "page": page, "ended": false, "won": false})
	# The doodle is being drawn into existence.
	player.modulate.a = 0.0
	player.scale = Vector2(0.2, 0.2)
	var draw_t := 0.4 if _fast else 1.0
	var tw := create_tween()
	tw.tween_property(player, "modulate:a", 1.0, draw_t)
	tw.parallel().tween_property(player, "scale", Vector2(1, 1), draw_t).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished
	if state != "intro":
		return
	_say("it is alive! this is so weird.")
	await get_tree().create_timer(0.6 if _fast else 2.0).timeout
	if state != "intro":
		return
	_say("...let's see what's out here →")
	await get_tree().create_timer(0.5 if _fast else 1.5).timeout
	if state != "intro":
		return
	_begin_play()

func _begin_play() -> void:
	if state == "play" or ended:
		return
	_clear_dialogue()
	state = "play"
	player.set_physics_process(true)
	# Page 1 is a calm explore: no pencil, no eraser yet. Threats are introduced
	# page by page as the doodle advances (see _introduce_threats).
	edge_glow.open()

## Bring in the hazards gradually: the pencil drops in on page 2, the erasers
## start raining from the sky on page 3 (more of them on later pages).
func _introduce_threats() -> void:
	if page >= 2 and pencil.target == null:
		_drop_in_pencil()
		_say("uh— a pencil falls from the sky!")
	if page >= 3 and not _erasers_on:
		_erasers_on = true
		_eraser_timer = 1.2 if _fast else 2.4
		_spawn_eraser_wave()  # the first one right away
		_say("erasers!! they're raining down— run!")

## The pencil drops from above, then starts hunting once it lands.
func _drop_in_pencil() -> void:
	var top := Game.sheet_rect.position.y + 24.0
	pencil.target = player
	pencil.visible = true
	pencil.set_process(false)
	pencil.global_position = Vector2(player.global_position.x, Game.sheet_rect.position.y - 170.0)
	var tw := create_tween()
	tw.tween_property(pencil, "global_position:y", top, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): pencil.set_process(true))

func _eraser_wave_size() -> int:
	if page >= 5:
		return 3
	if page >= 4:
		return 2
	return 1

func _spawn_eraser_wave() -> void:
	var r: Rect2 = Game.sheet_rect
	for i in range(_eraser_wave_size()):
		var lx := r.position.x + randf_range(r.size.x * 0.2, r.size.x * 0.9)
		var ly := r.position.y + randf_range(60.0, 120.0)
		_spawn_eraser(Vector2(lx, ly))
	shake(10.0, 0.3)
	flash(Color(0.95, 0.55, 0.66), 0.28, 0.4)

func _spawn_eraser(landing: Vector2) -> void:
	var e := Eraser.new()
	e.target = player
	e.land_pos = landing
	e.add_to_group("erasers")
	add_child(e)
	e.caught_player.connect(player.take_damage)  # contact chips a heart, not instant death

func _clear_erasers() -> void:
	for e in get_tree().get_nodes_in_group("erasers"):
		if is_instance_valid(e):
			e.queue_free()

# --- Per-frame -----------------------------------------------------------

func _process(delta: float) -> void:
	if _shake_t > 0.0 and cam:
		_shake_t -= delta
		var amt := _shake_mag * maxf(0.0, _shake_t / _shake_dur)
		cam.offset = Vector2(randf_range(-amt, amt), randf_range(-amt, amt))
	elif cam:
		cam.offset = Vector2.ZERO

	if ended:
		return

	_report_t += delta
	if _report_t >= 0.3:
		_report_t = 0.0
		Game.web_report({"state": state, "page": page, "ended": ended, "won": Game.won, "t": survival_time, "health": player.health, "x": int(player.global_position.x)})

	if state == "play":
		survival_time += delta
		hud_label.text = "Page %d / %d" % [page, total_pages]
		var r: Rect2 = Game.sheet_rect

		# Rain erasers from the sky in waves once enabled (page 3+).
		if _erasers_on:
			_eraser_timer -= delta
			if _eraser_timer <= 0.0:
				_eraser_timer = maxf(1.6, 4.0 - page * 0.4)
				_spawn_eraser_wave()

		# Page 1: nudge the doodle onward when it nears the (invisible) edge.
		if page == 1 and not _edge_hint_shown and player.global_position.x >= r.position.x + r.size.x - 260.0:
			_edge_hint_shown = true
			_say("huh— looks like the path continues →")

		if player.global_position.x >= r.position.x + r.size.x - 24.0:
			_flip_page()

# --- Page flip -----------------------------------------------------------

func _flip_page() -> void:
	if state != "play":
		return
	state = "flip"
	_play_flip()

func _play_flip() -> void:
	var r: Rect2 = Game.sheet_rect
	player.set_physics_process(false)
	player.invincible = true  # safe during the flip cinematic
	_clear_erasers()          # any in-flight erasers leave with the page
	_eraser_timer = 1.0
	edge_glow.active = false
	edge_glow.queue_redraw()

	# Doodle leaps off the right edge of the page.
	var jt := create_tween()
	jt.tween_property(player, "global_position", Vector2(r.position.x + r.size.x + 90.0, player.global_position.y - 70.0), 0.35).set_trans(Tween.TRANS_SINE)
	jt.parallel().tween_property(player, "rotation", 0.5, 0.35)
	await jt.finished

	# A real 3D sheet turns over the whole view.
	_ensure_flip3d()
	var dur := 0.18 if _fast else 0.6
	flip_pivot.rotation.y = 0.0
	_set_flip_alpha(0.0)
	flip3d_layer.visible = true

	# The leaving page settles flat over the screen, hiding the swap beneath it.
	var tin := create_tween()
	tin.tween_method(_set_flip_alpha, 0.0, 1.0, dur * 0.18)
	await tin.finished

	# Behind the covered page: advance and reset for the next sheet.
	page += 1
	var ending := page > total_pages
	if not ending:
		_clear_ink()
		notebook.set_page(page)  # more decorative doodles each page
		player.global_position = Vector2(r.position.x + 60.0, r.position.y + r.size.y * 0.5)
		player.rotation = 0.0

	# Turn the page around the left-hand spine: it lifts edge-on (the 3D beat),
	# then lays over to the left, fading out so the fresh sheet is revealed.
	var tt := create_tween()
	tt.tween_property(flip_pivot, "rotation:y", -PI, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tt.parallel().tween_method(_set_flip_alpha, 1.0, 0.0, dur * 0.45).set_delay(dur * 0.55)
	await tt.finished
	flip3d_layer.visible = false

	if ending:
		_begin_ending()
		return

	edge_glow.active = true
	edge_glow.queue_redraw()
	player.invincible = false
	player.set_physics_process(true)
	state = "play"
	_introduce_threats()  # pencil from page 2, erasers rain from page 3

# Lazily build the 3D page (a lit QuadMesh hinged at the spine, rendered into a
# transparent SubViewport overlaid on the 2D game).
func _ensure_flip3d() -> void:
	if flip3d_layer:
		return
	flip3d_layer = CanvasLayer.new()
	flip3d_layer.layer = 6
	flip3d_layer.visible = false
	add_child(flip3d_layer)

	var vpc := SubViewportContainer.new()
	vpc.stretch = true
	vpc.set_anchors_preset(Control.PRESET_FULL_RECT)
	vpc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flip3d_layer.add_child(vpc)

	flip_vp = SubViewport.new()
	flip_vp.size = Vector2i(1280, 720)
	flip_vp.transparent_bg = true
	flip_vp.own_world_3d = true
	flip_vp.world_3d = World3D.new()
	flip_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vpc.add_child(flip_vp)

	# Page sized to the notebook sheet (not the whole frame) so its edge is
	# visibly seen sweeping across and revealing the next sheet behind it.
	# Camera maps ~12.21 x 6.87 units to the full viewport; the sheet is
	# 1184x624 of 1280x720, hence these dimensions.
	var pw := 11.3
	var ph := 5.95

	var cam3d := Camera3D.new()
	cam3d.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam3d.fov = 55.0
	cam3d.position = Vector3(0.0, 0.0, 6.6)
	# No environment: an environment background clears the viewport opaque
	# (white) in GL Compatibility, which would hide the 2D game. Keeping the
	# viewport transparent and lighting both faces directly avoids that.
	flip_vp.add_child(cam3d)

	# Key + fill so whichever way the sheet faces, it catches light (shading is
	# what sells the turn); emission below keeps it from ever going black.
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40.0, 35.0, 0.0)
	key.light_energy = 1.0
	flip_vp.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20.0, -150.0, 0.0)
	fill.light_energy = 0.6
	flip_vp.add_child(fill)

	# Pivot at the left spine; the sheet hangs to its right.
	flip_pivot = Node3D.new()
	flip_pivot.position = Vector3(-pw * 0.5, 0.0, 0.0)
	flip_vp.add_child(flip_pivot)

	var mesh := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(pw, ph)
	mesh.mesh = quad
	mesh.position = Vector3(pw * 0.5, 0.0, 0.0)  # left edge rests on the pivot
	flip_mat = StandardMaterial3D.new()
	flip_mat.albedo_color = Color(0.99, 0.99, 0.98, 0.0)
	flip_mat.cull_mode = BaseMaterial3D.CULL_DISABLED  # both faces of the page
	flip_mat.roughness = 0.95
	flip_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Faint self-illumination so the paper always reads cream, with the lights
	# adding the directional shading that makes the turn feel 3D.
	flip_mat.emission_enabled = true
	flip_mat.emission = Color(0.99, 0.99, 0.98)
	flip_mat.emission_energy_multiplier = 0.45
	mesh.material_override = flip_mat
	flip_pivot.add_child(mesh)

func _set_flip_alpha(a: float) -> void:
	if flip_mat:
		flip_mat.albedo_color.a = a

# --- Ending --------------------------------------------------------------

func _begin_ending() -> void:
	state = "ending"
	var r: Rect2 = Game.sheet_rect
	if pencil:
		pencil.set_process(false)
	_erasers_on = false
	_clear_erasers()  # the threat is over; remove any so the cinematic is safe
	_clear_ink()
	player.set_physics_process(false)
	player.invincible = true
	hud_label.text = "You made it off the page!"
	_say("...where did it go?!")

	# The doodle lands, then leaps up and runs off the closing notebook.
	var land := r.position + Vector2(r.size.x * 0.5, r.size.y * 0.5)
	var tw := create_tween()
	tw.tween_property(player, "global_position", land, 0.4).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(player, "rotation", 0.0, 0.3)
	tw.tween_interval(0.3)
	# Leap up and dash off to the right, out of the notebook.
	tw.tween_property(player, "global_position", Vector2(r.position.x + r.size.x + 220.0, r.position.y - 120.0), 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(player, "scale", Vector2(0.5, 0.5), 0.8)
	tw.tween_callback(func():
		if is_instance_valid(self):
			_end_game(true))

# --- Outcomes ------------------------------------------------------------

func _on_player_died() -> void:
	_end_game(false)

func _on_player_hit(health: int) -> void:
	shake(9.0, 0.28)
	flash(Color(0.85, 0.1, 0.1), 0.32, 0.32)
	_update_hearts(health)
	# Pop the heart that just emptied for tactile feedback.
	if health >= 0 and health < hearts.size():
		var lost := hearts[health]
		lost.scale = Vector2(1.5, 1.5)
		var tw := create_tween()
		tw.tween_property(lost, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _end_game(won: bool) -> void:
	if ended:
		return
	ended = true
	Game.won = won
	Game.final_score = survival_time
	Game.web_report({"state": "done", "page": page, "ended": true, "won": won, "t": survival_time, "health": player.health})
	game_over.emit(won)
	if Game.testing:
		return
	# Deferred: a loss can be triggered from inside a physics callback (the
	# eraser's contact check), and swapping scenes mid-callback tears down
	# collision objects illegally. Defer to the idle frame.
	get_tree().call_deferred("change_scene_to_file", "res://scenes/end.tscn")

# --- Helpers -------------------------------------------------------------

func _clear_ink() -> void:
	for ink in get_tree().get_nodes_in_group("ink"):
		if is_instance_valid(ink):
			ink.queue_free()

func _say(text: String) -> void:
	dialogue_label.text = text
	dialogue_box.modulate.a = 0.0
	dialogue_box.visible = true
	var tw := create_tween()
	tw.tween_property(dialogue_box, "modulate:a", 1.0, 0.25)

func _clear_dialogue() -> void:
	dialogue_box.visible = false

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	hud_label = Label.new()
	hud_label.position = Vector2(20, 12)
	hud_label.add_theme_font_size_override("font_size", 20)
	hud_label.add_theme_color_override("font_color", Color(0.15, 0.15, 0.2))
	layer.add_child(hud_label)

	# Dialogue shown in a little speech bubble so it reads as someone talking.
	var bubble := StyleBoxFlat.new()
	bubble.bg_color = Color(0.99, 0.98, 0.92, 0.97)
	bubble.border_color = Color(0.18, 0.20, 0.28)
	bubble.set_border_width_all(3)
	bubble.set_corner_radius_all(14)
	bubble.set_content_margin_all(14)
	bubble.shadow_color = Color(0, 0, 0, 0.18)
	bubble.shadow_size = 5
	bubble.shadow_offset = Vector2(2, 3)
	dialogue_box = PanelContainer.new()
	dialogue_box.add_theme_stylebox_override("panel", bubble)
	dialogue_box.position = Vector2(360, 26)
	dialogue_box.rotation_degrees = -3.0
	dialogue_box.visible = false
	layer.add_child(dialogue_box)

	dialogue_label = Label.new()
	dialogue_label.add_theme_font_size_override("font_size", 28)
	dialogue_label.add_theme_color_override("font_color", Color(0.16, 0.18, 0.30))
	dialogue_box.add_child(dialogue_label)

	_build_hearts(layer)

func _build_hearts(layer: CanvasLayer) -> void:
	heart_full_tex = load("res://assets/sprites/heart_full.svg") as Texture2D
	heart_empty_tex = load("res://assets/sprites/heart_empty.svg") as Texture2D

	# Three hearts pinned to the top-right of the page.
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.position = Vector2(Game.sheet_rect.position.x + Game.sheet_rect.size.x - 150.0, 10.0)
	box.rotation_degrees = -2.0  # slight hand-pinned tilt
	layer.add_child(box)

	for i in range(Player.MAX_HEALTH):
		var h := TextureRect.new()
		h.texture = heart_full_tex
		h.custom_minimum_size = Vector2(44, 44)
		h.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		h.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		h.pivot_offset = Vector2(22, 22)
		box.add_child(h)
		hearts.append(h)

	_update_hearts(player.health)

func _update_hearts(health: int) -> void:
	for i in range(hearts.size()):
		hearts[i].texture = heart_full_tex if i < health else heart_empty_tex

func _build_fx() -> void:
	var fx := CanvasLayer.new()
	fx.layer = 10
	add_child(fx)

	flash_rect = ColorRect.new()
	flash_rect.color = Color(1, 0, 0, 0)
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx.add_child(flash_rect)

	fade_rect = ColorRect.new()
	fade_rect.color = Color(0.06, 0.06, 0.08, 1)
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx.add_child(fade_rect)
	create_tween().tween_property(fade_rect, "color:a", 0.0, 0.45)

	flip_layer = CanvasLayer.new()
	flip_layer.layer = 5
	add_child(flip_layer)

func shake(mag: float, dur: float) -> void:
	if dur <= 0.0:
		return
	_shake_mag = mag
	_shake_dur = dur
	_shake_t = dur

func flash(col: Color, peak: float, dur: float) -> void:
	if flash_rect == null:
		return
	flash_rect.color = Color(col.r, col.g, col.b, peak)
	var tw := create_tween()
	tw.tween_property(flash_rect, "color:a", 0.0, dur)

func _unhandled_input(event: InputEvent) -> void:
	# Let the player skip the intro.
	if state == "intro":
		if (event is InputEventKey and event.pressed and not event.echo) \
				or (event is InputEventMouseButton and event.pressed) \
				or (event is InputEventScreenTouch and event.pressed):
			_begin_play()
