extends Control
## Title screen (P1). Press any key / click to start.

var _can_input := false

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.98, 0.97, 0.90)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# A faint doodled stick figure waking up, drawn via a small Node2D.
	var vp := get_viewport_rect().size
	var doodle := _TitleDoodle.new()
	doodle.position = Vector2(vp.x * 0.5, vp.y * 0.5 + 90)
	doodle.scale = Vector2.ZERO
	add_child(doodle)
	# Awakening beat: the doodle pops awake with a little wobble.
	var dt := create_tween()
	dt.tween_interval(0.25)
	dt.tween_property(doodle, "scale", Vector2(1.6, 1.6), 0.55).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	dt.parallel().tween_property(doodle, "rotation", 0.12, 0.3).set_trans(Tween.TRANS_SINE)
	dt.tween_property(doodle, "rotation", 0.0, 0.25).set_trans(Tween.TRANS_SINE)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "NOTEBOOK AWAKENING"
	title.add_theme_font_size_override("font_size", 60)
	title.add_theme_color_override("font_color", Color(0.13, 0.18, 0.55))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = "You are a doodle. You just woke up."
	sub.add_theme_font_size_override("font_size", 22)
	sub.add_theme_color_override("font_color", Color(0.3, 0.3, 0.35))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 40)
	vbox.add_child(spacer)

	var how := Label.new()
	how.text = "Move: WASD / Arrows / drag      Dodge the ink. Survive. Escape."
	how.add_theme_font_size_override("font_size", 18)
	how.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45))
	how.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(how)

	var prompt := Label.new()
	prompt.text = "Press any key to awaken"
	prompt.add_theme_font_size_override("font_size", 24)
	prompt.add_theme_color_override("font_color", Color(0.2, 0.7, 0.32))
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(prompt)
	# Gentle pulsing on the prompt to draw the eye.
	var pt := create_tween().set_loops()
	pt.tween_property(prompt, "modulate:a", 0.4, 0.7).set_trans(Tween.TRANS_SINE)
	pt.tween_property(prompt, "modulate:a", 1.0, 0.7).set_trans(Tween.TRANS_SINE)

	# Fade in from black.
	var fade := ColorRect.new()
	fade.color = Color(0.06, 0.06, 0.08, 1)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)
	create_tween().tween_property(fade, "color:a", 0.0, 0.45)

	# Don't let a stray keypress during the WebGL load skip the title unseen.
	get_tree().create_timer(0.5).timeout.connect(func(): _can_input = true)

func _input(event: InputEvent) -> void:
	if not _can_input:
		return
	if (event is InputEventKey and event.pressed and not event.echo) \
			or (event is InputEventMouseButton and event.pressed):
		get_tree().change_scene_to_file("res://scenes/game.tscn")


class _TitleDoodle extends Node2D:
	func _draw() -> void:
		var col := Color(0.12, 0.12, 0.18, 0.5)
		draw_arc(Vector2(0, -14), 9.0, 0, TAU, 24, col, 2.0)
		draw_line(Vector2(0, -5), Vector2(0, 14), col, 2.0)
		draw_line(Vector2(-12, 1), Vector2(12, 1), col, 2.0)
		draw_line(Vector2(0, 14), Vector2(-10, 30), col, 2.0)
		draw_line(Vector2(0, 14), Vector2(10, 30), col, 2.0)
		# little "awakening" sparks
		for i in range(3):
			var a := -PI / 2.0 + (i - 1) * 0.5
			var p := Vector2(cos(a), sin(a)) * 34.0 + Vector2(0, -18)
			draw_line(p, p + Vector2(cos(a), sin(a)) * 8.0, col, 2.0)
