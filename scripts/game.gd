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

var state := "intro"        # intro | play | flip | ending
var page := 1
var survival_time := 0.0
var ended := false
var _report_t := 0.0
var _fast := false

var player: Player
var pencil: Pencil
var eraser: Eraser
var notebook: Notebook
var edge_glow: EscapeEdge
var hud_label: Label
var dialogue_label: Label

# Sketchy heart health display (procedural rough.js SVGs).
var heart_full_tex: Texture2D
var heart_empty_tex: Texture2D
var hearts: Array[TextureRect] = []

# Screen FX
var cam: Camera2D
var flash_rect: ColorRect
var fade_rect: ColorRect
var flip_layer: CanvasLayer
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

	edge_glow = EscapeEdge.new()
	add_child(edge_glow)

	player = Player.new()
	player.global_position = Vector2(r.position.x + 60.0, r.position.y + r.size.y * 0.5)
	add_child(player)
	player.died.connect(_on_player_died)
	player.health_changed.connect(_on_player_hit)
	player.set_physics_process(false)  # not controllable until play begins
	if _fast:
		player.speed_mult = 3.0  # e2e: traverse pages quickly

	pencil = Pencil.new()
	pencil.ink_parent = self
	pencil.global_position = Vector2(r.position.x + r.size.x * 0.5, r.position.y + 24.0)
	pencil.set_process(false)  # the pencil only starts scribbling once we play
	add_child(pencil)

	_build_hud()
	_build_fx()
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
	_say("wait— I have to erase this!")
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
	pencil.target = player
	pencil.set_process(true)
	_spawn_eraser()
	edge_glow.open()

func _spawn_eraser() -> void:
	var r: Rect2 = Game.sheet_rect
	eraser = Eraser.new()
	eraser.target = player
	eraser.global_position = r.position + Vector2(28, 28)
	add_child(eraser)
	eraser.caught_player.connect(player.die)
	shake(14.0, 0.45)
	flash(Color(0.95, 0.55, 0.66), 0.35, 0.45)

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
		hud_label.text = "Page %d / %d   —   run for the edge →" % [page, total_pages]
		var r: Rect2 = Game.sheet_rect
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
	if eraser and is_instance_valid(eraser):
		eraser.monitoring = false  # can't catch the doodle mid-flip
	edge_glow.active = false
	edge_glow.queue_redraw()

	# Doodle leaps off the right edge of the page.
	var jt := create_tween()
	jt.tween_property(player, "global_position", Vector2(r.position.x + r.size.x + 90.0, player.global_position.y - 70.0), 0.35).set_trans(Tween.TRANS_SINE)
	jt.parallel().tween_property(player, "rotation", 0.5, 0.35)
	await jt.finished

	# A page sweeps across (the page being turned).
	var page_rect := ColorRect.new()
	page_rect.color = Color(0.97, 0.96, 0.88)
	page_rect.position = Vector2(r.position.x + r.size.x, r.position.y)
	page_rect.size = Vector2(0, r.size.y)
	page_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flip_layer.add_child(page_rect)
	var shadow := ColorRect.new()
	shadow.color = Color(0.0, 0.0, 0.0, 0.18)
	shadow.size = Vector2(18, r.size.y)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flip_layer.add_child(shadow)

	# Phase A: the turning page closes over from the right.
	var ta := create_tween()
	ta.tween_property(page_rect, "position:x", r.position.x, 0.28).set_trans(Tween.TRANS_QUAD)
	ta.parallel().tween_property(page_rect, "size:x", r.size.x, 0.28).set_trans(Tween.TRANS_QUAD)
	ta.parallel().tween_property(shadow, "position:x", r.position.x, 0.28)
	await ta.finished

	# Behind the covered page: advance and reset for the next sheet.
	page += 1
	if page > total_pages:
		page_rect.queue_free()
		shadow.queue_free()
		_begin_ending()
		return
	_clear_ink()
	player.global_position = Vector2(r.position.x + 60.0, r.position.y + r.size.y * 0.5)
	player.rotation = 0.0
	if eraser and is_instance_valid(eraser):
		eraser.global_position = r.position + Vector2(40.0, 40.0)

	# Phase B: the page sweeps open to reveal the fresh sheet.
	var tb := create_tween()
	tb.tween_property(page_rect, "position:x", r.position.x - r.size.x, 0.28).set_trans(Tween.TRANS_QUAD)
	tb.parallel().tween_property(shadow, "position:x", r.position.x - 18.0, 0.28)
	await tb.finished
	page_rect.queue_free()
	shadow.queue_free()

	edge_glow.active = true
	edge_glow.queue_redraw()
	if eraser and is_instance_valid(eraser):
		eraser.monitoring = true
	player.invincible = false
	player.set_physics_process(true)
	state = "play"

# --- Ending --------------------------------------------------------------

func _begin_ending() -> void:
	state = "ending"
	var r: Rect2 = Game.sheet_rect
	if pencil:
		pencil.set_process(false)
	if eraser and is_instance_valid(eraser):
		eraser.queue_free()  # the threat is over; remove it so the cinematic is safe
		eraser = null
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
	get_tree().change_scene_to_file("res://scenes/end.tscn")

# --- Helpers -------------------------------------------------------------

func _clear_ink() -> void:
	for ink in get_tree().get_nodes_in_group("ink"):
		if is_instance_valid(ink):
			ink.queue_free()

func _say(text: String) -> void:
	dialogue_label.text = text
	dialogue_label.modulate.a = 0.0
	dialogue_label.visible = true
	var tw := create_tween()
	tw.tween_property(dialogue_label, "modulate:a", 1.0, 0.25)

func _clear_dialogue() -> void:
	dialogue_label.visible = false

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	hud_label = Label.new()
	hud_label.position = Vector2(20, 12)
	hud_label.add_theme_font_size_override("font_size", 20)
	hud_label.add_theme_color_override("font_color", Color(0.15, 0.15, 0.2))
	layer.add_child(hud_label)

	dialogue_label = Label.new()
	dialogue_label.position = Vector2(360, 30)
	dialogue_label.add_theme_font_size_override("font_size", 30)
	dialogue_label.add_theme_color_override("font_color", Color(0.2, 0.25, 0.6))
	dialogue_label.rotation_degrees = -3.0
	dialogue_label.visible = false
	layer.add_child(dialogue_label)

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
