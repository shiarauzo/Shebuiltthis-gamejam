extends Control
## End screen (P3). The notebook closes (two cover panels sweep in), then opens
## to reveal the win/lose message + score. Press any key to retry.

var _can_retry := false
var _retried := false

func _ready() -> void:
	var won: bool = Game.won

	var paper := ColorRect.new()
	paper.color = Color(0.98, 0.97, 0.90)
	paper.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(paper)

	# Message (revealed after the notebook closes).
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "YOU ESCAPED!" if won else "ERASED."
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(0.20, 0.70, 0.32) if won else Color(0.82, 0.25, 0.30))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = "The notebook closes behind you." if won else "The eraser caught you."
	sub.add_theme_font_size_override("font_size", 22)
	sub.add_theme_color_override("font_color", Color(0.25, 0.25, 0.3))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub)

	var score := Label.new()
	score.text = "Survived: %.1f seconds" % Game.final_score
	score.add_theme_font_size_override("font_size", 30)
	score.add_theme_color_override("font_color", Color(0.13, 0.18, 0.55))
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(score)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	vbox.add_child(spacer)

	var retry := Label.new()
	retry.text = "Press any key to wake up again"
	retry.add_theme_font_size_override("font_size", 18)
	retry.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45))
	retry.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(retry)

	center.modulate.a = 0.0

	# Notebook cover panels (sized to the actual viewport, not a fixed constant).
	var vp := get_viewport_rect().size
	var vw := vp.x
	var vh := vp.y

	var left := ColorRect.new()
	left.color = Color(0.46, 0.29, 0.20)
	left.size = Vector2(vw / 2.0, vh)
	left.position = Vector2(-vw / 2.0, 0)
	add_child(left)

	var right := ColorRect.new()
	right.color = Color(0.42, 0.26, 0.18)
	right.size = Vector2(vw / 2.0, vh)
	right.position = Vector2(vw, 0)
	add_child(right)

	var spine := ColorRect.new()
	spine.color = Color(0.30, 0.18, 0.12)
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
	fade.color = Color(0.06, 0.06, 0.08, 1)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)
	create_tween().tween_property(fade, "color:a", 0.0, 0.3)

	# Enable retry when the close/open/reveal cinematic actually finishes,
	# not after a hardcoded delay.
	tw.finished.connect(_enable_retry)

func _enable_retry() -> void:
	_can_retry = true

func _input(event: InputEvent) -> void:
	if not _can_retry or _retried:
		return
	if (event is InputEventKey and event.pressed and not event.echo) \
			or (event is InputEventMouseButton and event.pressed):
		_retried = true  # guard against a double scene-change on key-spam
		get_tree().change_scene_to_file("res://scenes/game.tscn")
