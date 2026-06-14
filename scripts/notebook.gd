extends Node2D
class_name Notebook
## Graph-paper notebook page drawn procedurally (white sheet, light-blue square
## grid, a few static doodles). Every stroke "boils" via Game.boil_jitter so the
## whole page wobbles like a living doodle.

const GRID := 28.0  # square size of the graph-paper grid
const OBSTACLE_LAYER := 2  # the doodle player bumps into these (matches Player.OBSTACLE_LAYER)

func _ready() -> void:
	Game.boil_tick.connect(queue_redraw)
	_build_obstacles()

## Solid colliders under the decorative doodles so the player bumps them
## instead of walking over them. Positions mirror the ones drawn in _draw().
func _build_obstacles() -> void:
	var r: Rect2 = Game.sheet_rect
	_add_circle(r.position + Vector2(240, 120), 20.0)                       # star
	_add_circle(r.position + Vector2(r.size.x - 180, 160), 16.0)           # spiral
	_add_circle(r.position + Vector2(360, r.size.y - 120), 16.0)           # cloud
	_add_rect(r.position + Vector2(r.size.x - 320 + 72, r.size.y - 150), Vector2(150, 22))  # squiggle

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

	# Paper (solid white fill stays stable so text/UI read cleanly).
	draw_rect(r, Color(0.99, 0.99, 0.98), true)

	# Graph-paper grid: light-blue squares, gently boiled both ways.
	var grid_col := Color(0.55, 0.78, 0.90, 0.55)
	var x := r.position.x + GRID
	while x < r.position.x + r.size.x - 2.0:
		draw_line(_j(Vector2(x, r.position.y + 4), 1.0), _j(Vector2(x, r.position.y + r.size.y - 4), 1.0), grid_col, 1.0)
		x += GRID
	var y := r.position.y + GRID
	while y < r.position.y + r.size.y - 2.0:
		draw_line(_j(Vector2(r.position.x + 4, y), 1.0), _j(Vector2(r.position.x + r.size.x - 4, y), 1.0), grid_col, 1.0)
		y += GRID

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
		var rad := 22.0 if i % 2 == 0 else 9.0
		pts.append(_j(c + Vector2(cos(ang), sin(ang)) * rad))
	draw_polyline(pts, col, 2.0)

func _doodle_spiral(c: Vector2, col: Color) -> void:
	var pts: PackedVector2Array = []
	for i in range(40):
		var t := i / 6.0
		pts.append(_j(c + Vector2(cos(t), sin(t)) * (2.0 + t * 3.0)))
	draw_polyline(pts, col, 2.0)

func _doodle_cloud(c: Vector2, col: Color) -> void:
	var pts: PackedVector2Array = []
	for i in range(25):
		var t := i / 24.0 * TAU
		var rad := 18.0 + 6.0 * sin(t * 3.0)
		pts.append(_j(c + Vector2(cos(t) * rad, sin(t) * rad * 0.55)))
	pts.append(pts[0])
	draw_polyline(pts, col, 2.0)

func _doodle_squiggle(c: Vector2, col: Color) -> void:
	var pts: PackedVector2Array = []
	for i in range(30):
		var x := i * 5.0
		pts.append(_j(c + Vector2(x, sin(x * 0.2) * 12.0)))
	draw_polyline(pts, col, 2.0)
