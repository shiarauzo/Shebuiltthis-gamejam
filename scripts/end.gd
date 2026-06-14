extends Control
## End screen (P3). The notebook closes (two cover panels sweep in), then opens
## to reveal the win/lose message + score. Press any key to retry.

var _can_retry := false
var _retried := false

func _ready() -> void:
	var won: bool = Game.won
	var vp := get_viewport_rect().size
	var hand := load("res://assets/fonts/Caveat.ttf") as Font

	# Excalidraw-style: graph paper + a rough.js sketchy frame.
	var paper := TextureRect.new()
	var grid := load("res://assets/sprites/grid_paper.jpg") as Texture2D
	if grid:
		paper.texture = grid
		paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		paper.stretch_mode = TextureRect.STRETCH_SCALE
	paper.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(paper)

	var card := TextureRect.new()
	card.texture = load("res://assets/sprites/title_card.svg")
	card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var cw := 840.0
	var chh := 360.0
	card.size = Vector2(cw, chh)
	card.position = Vector2((vp.x - cw) * 0.5, (vp.y - chh) * 0.5)
	card.rotation_degrees = -1.0
	card.pivot_offset = card.size * 0.5
	add_child(card)

	# Message (revealed after the notebook closes).
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	center.add_child(vbox)

	var title := _el("YOU ESCAPED!" if won else "ERASED.", 86, Color(0.20, 0.55, 0.34) if won else Color(0.70, 0.20, 0.24), hand)
	vbox.add_child(title)

	var sub := _el("the notebook closes behind you" if won else "the eraser caught you", 34, Color(0.2, 0.2, 0.26), hand)
	vbox.add_child(sub)

	var score := _el("survived %.1f seconds" % Game.final_score, 40, Color(0.14, 0.14, 0.2), hand)
	vbox.add_child(score)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	vbox.add_child(spacer)

	var retry := _el("press any key to continue", 30, Color(0.16, 0.45, 0.5), hand)
	vbox.add_child(retry)

	center.modulate.a = 0.0

	# Notebook cover panels (sized to the actual viewport, not a fixed constant).
	var vw := vp.x
	var vh := vp.y

	var left := ColorRect.new()
	left.color = Color(0.07, 0.07, 0.09)
	left.size = Vector2(vw / 2.0, vh)
	left.position = Vector2(-vw / 2.0, 0)
	add_child(left)

	var right := ColorRect.new()
	right.color = Color(0.05, 0.05, 0.07)
	right.size = Vector2(vw / 2.0, vh)
	right.position = Vector2(vw, 0)
	add_child(right)

	var spine := ColorRect.new()
	spine.color = Color(0.0, 0.0, 0.0)
	spine.size = Vector2(10, vh)
	spine.position = Vector2(vw / 2.0 - 5.0, 0)
	spine.modulate.a = 0.0
	add_child(spine)

	# Close -> hold -> open -> reveal.
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(left, "position", Vector2(0, 0), 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(right, "position", Vector2(vw / 2.0, 0), 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(spine, "modulate:a", 1.0, 0.55)
	tw.chain().tween_interval(0.35)
	tw.set_parallel(true)
	tw.tween_property(left, "position", Vector2(-vw / 2.0, 0), 0.5).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(right, "position", Vector2(vw, 0), 0.5).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(spine, "modulate:a", 0.0, 0.4)
	tw.tween_property(center, "modulate:a", 1.0, 0.5)

	# Quick fade-in on top of everything to smooth the cut from gameplay.
	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 1)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)
	create_tween().tween_property(fade, "color:a", 0.0, 0.3)

	# Enable retry when the close/open/reveal cinematic actually finishes,
	# not after a hardcoded delay.
	tw.finished.connect(_enable_retry)

func _el(text: String, size: int, col: Color, hand: Font) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if hand:
		l.add_theme_font_override("font", hand)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

func _enable_retry() -> void:
	_can_retry = true

func _input(event: InputEvent) -> void:
	if not _can_retry or _retried:
		return
	if (event is InputEventKey and event.pressed and not event.echo) \
			or (event is InputEventMouseButton and event.pressed) \
			or (event is InputEventScreenTouch and event.pressed):
		_retried = true  # guard against a double scene-change on key-spam
		get_tree().change_scene_to_file("res://scenes/game.tscn")
