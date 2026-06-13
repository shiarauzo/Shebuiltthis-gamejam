extends Node2D
class_name Notebook
## Placeholder notebook page drawn procedurally (paper, ruled lines, margin,
## a few static doodles). Replace with hand-drawn art later if desired.

func _draw() -> void:
	var r: Rect2 = Game.sheet_rect

	# Paper
	draw_rect(r, Color(0.98, 0.97, 0.90), true)

	# Ruled horizontal lines
	var y := r.position.y + 44.0
	while y < r.position.y + r.size.y - 8.0:
		draw_line(Vector2(r.position.x + 6, y), Vector2(r.position.x + r.size.x - 6, y),
			Color(0.62, 0.74, 0.90, 0.55), 1.0)
		y += 34.0

	# Red margin line
	var mx := r.position.x + 72.0
	draw_line(Vector2(mx, r.position.y), Vector2(mx, r.position.y + r.size.y),
		Color(0.90, 0.42, 0.46, 0.65), 2.0)

	# Page border
	draw_rect(r, Color(0.80, 0.80, 0.74), false)

	# Static decorative doodles (ambiance / obstacles, non-interactive)
	var d := Color(0.35, 0.4, 0.55, 0.7)
	_doodle_star(Vector2(r.position.x + 240, r.position.y + 120), d)
	_doodle_spiral(Vector2(r.position.x + r.size.x - 180, r.position.y + 160), d)
	_doodle_cloud(Vector2(r.position.x + 360, r.position.y + r.size.y - 120), d)
	_doodle_squiggle(Vector2(r.position.x + r.size.x - 320, r.position.y + r.size.y - 150), d)

func _doodle_star(c: Vector2, col: Color) -> void:
	var pts: PackedVector2Array = []
	for i in range(11):
		var ang := -PI / 2.0 + i * PI * 2.0 / 10.0
		var rad := 22.0 if i % 2 == 0 else 9.0
		pts.append(c + Vector2(cos(ang), sin(ang)) * rad)
	draw_polyline(pts, col, 2.0)

func _doodle_spiral(c: Vector2, col: Color) -> void:
	var pts: PackedVector2Array = []
	for i in range(40):
		var t := i / 6.0
		pts.append(c + Vector2(cos(t), sin(t)) * (2.0 + t * 3.0))
	draw_polyline(pts, col, 2.0)

func _doodle_cloud(c: Vector2, col: Color) -> void:
	draw_arc(c + Vector2(-18, 0), 16, PI, TAU, 16, col, 2.0)
	draw_arc(c + Vector2(4, -6), 20, PI * 0.8, TAU + 0.3, 18, col, 2.0)
	draw_arc(c + Vector2(26, 0), 14, PI * 1.2, TAU + 0.2, 14, col, 2.0)
	draw_line(c + Vector2(-34, 0), c + Vector2(40, 0), col, 2.0)

func _doodle_squiggle(c: Vector2, col: Color) -> void:
	var pts: PackedVector2Array = []
	for i in range(30):
		var x := i * 5.0
		pts.append(c + Vector2(x, sin(x * 0.2) * 12.0))
	draw_polyline(pts, col, 2.0)
