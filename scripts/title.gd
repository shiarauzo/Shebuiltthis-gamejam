extends Control
## Title screen (P1), Excalidraw-style: graph paper + a rough.js sketchy title
## card. Press any key / click to start.

var _can_input := false

func _ready() -> void:
	var vp := get_viewport_rect().size

	# Graph-paper background (same texture as the game) for the Excalidraw canvas feel.
	var bg := TextureRect.new()
	var grid := load("res://assets/sprites/grid_paper.jpg") as Texture2D
	if grid:
		bg.texture = grid
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Sketchy rough.js title card, centred and tilted a hair like a placed sticker.
	var card := TextureRect.new()
	card.texture = load("res://assets/sprites/title_card.svg")
	card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var cw := 880.0
	var ch := 330.0
	card.size = Vector2(cw, ch)
	card.position = Vector2((vp.x - cw) * 0.5, (vp.y - ch) * 0.5 - 30.0)
	card.rotation_degrees = -1.5
	card.pivot_offset = card.size * 0.5
	add_child(card)

	var ink := Color(0.12, 0.14, 0.22)
	var card_top := card.position.y

	var title := _ctext("The Notebook", 76, ink, vp.x)
	title.position = Vector2(0, card_top + 58.0)
	add_child(title)

	var sub := _ctext("you are a doodle.  you just woke up.", 24, Color(0.32, 0.34, 0.42), vp.x)
	sub.position = Vector2(0, card_top + 198.0)
	add_child(sub)

	var how := _ctext("move: WASD / arrows / drag      dodge the ink, survive, escape", 18, Color(0.42, 0.44, 0.5), vp.x)
	how.position = Vector2(0, card_top + 244.0)
	add_child(how)

	var prompt := _ctext("press any key to awaken", 26, Color(0.16, 0.45, 0.5), vp.x)
	prompt.position = Vector2(0, card_top + ch + 36.0)
	add_child(prompt)
	var pt := create_tween().set_loops()
	pt.tween_property(prompt, "modulate:a", 0.4, 0.7).set_trans(Tween.TRANS_SINE)
	pt.tween_property(prompt, "modulate:a", 1.0, 0.7).set_trans(Tween.TRANS_SINE)

	# A little doodle waking up beside the title.
	var doodle := _TitleDoodle.new()
	doodle.position = Vector2(vp.x * 0.5, card_top + ch - 16.0)
	doodle.scale = Vector2.ZERO
	add_child(doodle)
	var dt := create_tween()
	dt.tween_interval(0.2)
	dt.tween_property(doodle, "scale", Vector2(1.5, 1.5), 0.55).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	# Fade in from black.
	var fade := ColorRect.new()
	fade.color = Color(0.0, 0.0, 0.0, 1)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)
	create_tween().tween_property(fade, "color:a", 0.0, 0.45)

	get_tree().create_timer(0.5).timeout.connect(func(): _can_input = true)

func _ctext(text: String, size: int, col: Color, width: float) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size.x = width
	l.position.x = 0
	return l

func _input(event: InputEvent) -> void:
	if not _can_input:
		return
	if (event is InputEventKey and event.pressed and not event.echo) \
			or (event is InputEventMouseButton and event.pressed) \
			or (event is InputEventScreenTouch and event.pressed):
		get_tree().change_scene_to_file("res://scenes/game.tscn")


class _TitleDoodle extends Node2D:
	func _ready() -> void:
		Game.boil_tick.connect(queue_redraw)

	func _draw() -> void:
		var col := Color(0.12, 0.12, 0.18, 0.55)
		var head := PackedVector2Array()
		for i in range(11):
			var a := i * TAU / 10.0
			head.append(Game.boil_jitter(Vector2(0, -14) + Vector2(cos(a), sin(a)) * 9.0))
		draw_polyline(head, col, 2.0)
		draw_line(Game.boil_jitter(Vector2(0, -5)), Game.boil_jitter(Vector2(0, 14)), col, 2.0)
		draw_line(Game.boil_jitter(Vector2(-12, 1)), Game.boil_jitter(Vector2(12, 1)), col, 2.0)
		draw_line(Game.boil_jitter(Vector2(0, 14)), Game.boil_jitter(Vector2(-10, 30)), col, 2.0)
		draw_line(Game.boil_jitter(Vector2(0, 14)), Game.boil_jitter(Vector2(10, 30)), col, 2.0)
