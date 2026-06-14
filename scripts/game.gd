extends Node2D
## Gameplay orchestrator (P2). Builds the world in code, runs the survival timer,
## triggers phase 2 (eraser), opens the escape edge only after you survive the
## eraser for a while, and resolves win/lose.
##
## Phases:
##   1 - dodge the pencil's ink for `eraser_trigger_time` seconds
##   2 - the eraser hunts you; survive `escape_open_delay` seconds
##   3 - the escape edge opens; reach it to win

signal game_over(won: bool)

@export var eraser_trigger_time := 22.0
@export var escape_open_delay := 10.0

var survival_time := 0.0
var phase := 1
var phase2_time := 0.0
var ended := false

var player: Player
var pencil: Pencil
var eraser: Eraser
var escape_edge: EscapeEdge
var hud_label: Label
var phase_label: Label

# Screen FX
var cam: Camera2D
var flash_rect: ColorRect
var fade_rect: ColorRect
var _shake_t := 0.0
var _shake_dur := 0.0
var _shake_mag := 0.0

func _ready() -> void:
	randomize()
	var r: Rect2 = Game.sheet_rect

	cam = Camera2D.new()
	cam.position = Vector2(640, 360)
	add_child(cam)
	cam.make_current()

	var nb := Notebook.new()
	nb.z_index = -10
	add_child(nb)

	escape_edge = EscapeEdge.new()
	add_child(escape_edge)
	escape_edge.reached.connect(_on_escape_reached)

	player = Player.new()
	player.global_position = r.position + r.size * 0.5
	add_child(player)
	player.died.connect(_on_player_died)
	player.health_changed.connect(_on_player_hit)

	pencil = Pencil.new()
	pencil.target = player
	pencil.ink_parent = self
	pencil.global_position = Vector2(r.position.x + r.size.x * 0.5, r.position.y + 24.0)
	add_child(pencil)

	_build_hud()

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	hud_label = Label.new()
	hud_label.position = Vector2(20, 12)
	hud_label.add_theme_font_size_override("font_size", 22)
	hud_label.add_theme_color_override("font_color", Color(0.15, 0.15, 0.2))
	layer.add_child(hud_label)

	phase_label = Label.new()
	phase_label.position = Vector2(20, 44)
	phase_label.add_theme_font_size_override("font_size", 16)
	phase_label.add_theme_color_override("font_color", Color(0.55, 0.30, 0.32))
	layer.add_child(phase_label)

	# Screen-FX overlay (flash + fade), above the HUD.
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
	var fade_tw := create_tween()
	fade_tw.tween_property(fade_rect, "color:a", 0.0, 0.45)

func shake(mag: float, dur: float) -> void:
	if dur <= 0.0:
		return  # guard the per-frame division _shake_t / _shake_dur
	_shake_mag = mag
	_shake_dur = dur
	_shake_t = dur

func flash(col: Color, peak: float, dur: float) -> void:
	if flash_rect == null:
		return
	flash_rect.color = Color(col.r, col.g, col.b, peak)
	var tw := create_tween()
	tw.tween_property(flash_rect, "color:a", 0.0, dur)

func _on_player_hit(_health: int) -> void:
	shake(9.0, 0.28)
	flash(Color(0.85, 0.1, 0.1), 0.32, 0.32)

func _process(delta: float) -> void:
	# Screen shake decays even during the end cinematic.
	if _shake_t > 0.0 and cam:
		_shake_t -= delta
		var amt := _shake_mag * maxf(0.0, _shake_t / _shake_dur)
		cam.offset = Vector2(randf_range(-amt, amt), randf_range(-amt, amt))
	elif cam:
		cam.offset = Vector2.ZERO

	if ended:
		return
	survival_time += delta
	hud_label.text = "Survived: %.1fs" % survival_time

	match phase:
		1:
			var remain := maxf(0.0, eraser_trigger_time - survival_time)
			phase_label.text = "A pencil is scribbling... hold on (%.0fs)" % remain
			if survival_time >= eraser_trigger_time:
				_start_phase_two()
		2:
			phase2_time += delta
			var left := maxf(0.0, escape_open_delay - phase2_time)
			phase_label.text = "THE ERASER WOKE UP! Survive it (%.0fs)" % left
			if phase2_time >= escape_open_delay:
				phase = 3
				escape_edge.open()
		3:
			phase_label.text = "RUN! Reach the glowing edge →"

func _start_phase_two() -> void:
	phase = 2
	eraser = Eraser.new()
	eraser.target = player
	eraser.global_position = _farthest_corner_from(player.global_position)
	add_child(eraser)
	eraser.caught_player.connect(_on_player_died)
	# Dramatic "the eraser woke up" jolt.
	shake(16.0, 0.5)
	flash(Color(0.95, 0.55, 0.66), 0.4, 0.5)

func _farthest_corner_from(p: Vector2) -> Vector2:
	var r: Rect2 = Game.sheet_rect
	var corners := [
		r.position + Vector2(40, 40),
		Vector2(r.position.x + r.size.x - 40, r.position.y + 40),
		Vector2(r.position.x + 40, r.position.y + r.size.y - 40),
		r.position + r.size - Vector2(40, 40),
	]
	var best: Vector2 = corners[0]
	var best_d := -1.0
	for c in corners:
		var d := p.distance_to(c)
		if d > best_d:
			best_d = d
			best = c
	return best

func _on_player_died() -> void:
	_end_game(false)

func _on_escape_reached() -> void:
	_end_game(true)

func _end_game(won: bool) -> void:
	if ended:
		return
	ended = true
	Game.won = won
	Game.final_score = survival_time
	game_over.emit(won)
	if Game.testing:
		return
	if won:
		_play_win_cinematic()
	else:
		get_tree().change_scene_to_file("res://scenes/end.tscn")

func _play_win_cinematic() -> void:
	# Freeze hazards + input, then leap off the right edge of the page.
	if pencil:
		pencil.set_process(false)
	if eraser:
		eraser.set_process(false)
		eraser.set_physics_process(false)  # eraser chases in _physics_process
	player.set_physics_process(false)

	var r: Rect2 = Game.sheet_rect
	var leap_to := Vector2(r.position.x + r.size.x + 140.0, player.global_position.y - 60.0)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(player, "global_position", leap_to, 0.75).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(player, "rotation", 0.7, 0.75)
	tw.tween_property(player, "scale", Vector2(0.55, 0.55), 0.75)
	tw.chain().tween_callback(func():
		if is_instance_valid(self):
			get_tree().change_scene_to_file("res://scenes/end.tscn"))
