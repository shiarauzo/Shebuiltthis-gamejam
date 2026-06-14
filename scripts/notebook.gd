extends Node2D
class_name Notebook
## Graph-paper notebook page drawn procedurally (white sheet, light-blue square
## grid, a few static doodles). Every stroke "boils" via Game.boil_jitter so the
## whole page wobbles like a living doodle.

const OBSTACLE_LAYER := 2  # the doodle player bumps into these (matches Player.OBSTACLE_LAYER)

var _grid_tex: Texture2D

func _ready() -> void:
	_grid_tex = load("res://assets/sprites/grid_paper.jpg") as Texture2D
	Game.boil_tick.connect(queue_redraw)
	_build_obstacles()

## Solid colliders under the decorative doodles so the player bumps them
## instead of walking over them. Positions mirror the ones drawn in _draw().
func _build_obstacles() -> void:
	var r: Rect2 = Game.sheet_rect
	_add_circle(r.position + Vector2(240, 120), 30.0)                       # star
	_add_circle(r.position + Vector2(r.size.x - 180, 160), 22.0)           # spiral
	_add_circle(r.position + Vector2(360, r.size.y - 120), 22.0)           # cloud
	_add_rect(r.position + Vector2(r.size.x - 320 + 87, r.size.y - 150), Vector2(174, 30))  # squiggle

func _add_obstacle(shape: Shape2D, pos: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = pos
	body.collision_layer = OBSTACLE_LAYER
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	cs.shape = shape
	body.add_child(cs)
	add_child(body)

func _add_circle(pos: Vector2, radius: float) -> void:
	var sh := CircleShape2D.new()
	sh.radius = radius
	_add_obstacle(sh, pos)

func _add_rect(pos: Vector2, size: Vector2) -> void:
	var sh := RectangleShape2D.new()
	sh.size = size
	_add_obstacle(sh, pos)

func _j(p: Vector2, amp := 1.3) -> Vector2:
	return Game.boil_jitter(p, amp)

func _draw() -> void:
	var r: Rect2 = Game.sheet_rect

	# Graph-paper sheet: the hand-picked squared-paper texture stretched to fill.
	if _grid_tex:
		draw_texture_rect(_grid_tex, r, false)
	else:
		draw_rect(r, Color(0.99, 0.99, 0.98), true)

	# Page border as a boiled rectangle outline.
	var border := PackedVector2Array([
		_j(r.position), _j(r.position + Vector2(r.size.x, 0)),
		_j(r.position + r.size), _j(r.position + Vector2(0, r.size.y)), _j(r.position)])
	draw_polyline(border, Color(0.80, 0.80, 0.74), 1.5)

	# Static decorative doodles (ambiance / obstacles, non-interactive).
	var d := Color(0.35, 0.4, 0.55, 0.7)
	_doodle_star(Vector2(r.position.x + 240, r.position.y + 120), d)
	_doodle_spiral(Vector2(r.position.x + r.size.x - 180, r.position.y + 160), d)
	_doodle_cloud(Vector2(r.position.x + 360, r.position.y + r.size.y - 120), d)
	_doodle_squiggle(Vector2(r.position.x + r.size.x - 320, r.position.y + r.size.y - 150), d)

func _doodle_star(c: Vector2, col: Color) -> void:
	var pts: PackedVector2Array = []
	for i in range(11):
		var ang := -PI / 2.0 + i * PI * 2.0 / 10.0
		var rad := 32.0 if i % 2 == 0 else 13.0
		pts.append(_j(c + Vector2(cos(ang), sin(ang)) * rad))
	draw_polyline(pts, col, 2.5)

func _doodle_spiral(c: Vector2, col: Color) -> void:
	var pts: PackedVector2Array = []
	for i in range(46):
		var t := i / 6.0
		pts.append(_j(c + Vector2(cos(t), sin(t)) * (2.0 + t * 4.2)))
	draw_polyline(pts, col, 2.5)

func _doodle_cloud(c: Vector2, col: Color) -> void:
	var pts: PackedVector2Array = []
	for i in range(25):
		var t := i / 24.0 * TAU
		var rad := 26.0 + 9.0 * sin(t * 3.0)
		pts.append(_j(c + Vector2(cos(t) * rad, sin(t) * rad * 0.55)))
	pts.append(pts[0])
	draw_polyline(pts, col, 2.5)

func _doodle_squiggle(c: Vector2, col: Color) -> void:
	var pts: PackedVector2Array = []
	for i in range(30):
		var x := i * 6.0
		pts.append(_j(c + Vector2(x, sin(x * 0.2) * 16.0)))
	draw_polyline(pts, col, 2.5)
