extends Node2D
class_name Notebook
## Graph-paper notebook page: the squared-paper texture plus a set of decorative
## doodles that GROWS each page (more clutter to weave around the deeper you go).
## Every stroke "boils" via Game.boil_jitter so the page wobbles like a doodle.

const OBSTACLE_LAYER := 2  # the doodle player bumps into these (matches Player.OBSTACLE_LAYER)

var _grid_tex: Texture2D
var _page := 1
var _doodles: Array = []  # [{pos, type, size}], regenerated per page

func _ready() -> void:
	_grid_tex = load("res://assets/sprites/grid_paper.jpg") as Texture2D
	Game.boil_tick.connect(queue_redraw)

## Regenerate the decorative doodles + their colliders for the given page. The
## count grows with the page, so reaching the end gets busier and harder.
func set_page(p: int) -> void:
	_page = p
	_doodles.clear()
	var r: Rect2 = Game.sheet_rect
	var count := 4 + (p - 1) * 3  # 4, 7, 10, 13, 16 ...
	for i in range(count):
		var k := p * 100 + i
		var hx := _h(k * 2 + 1)
		var hy := _h(k * 2 + 2)
		var pos := r.position + Vector2(
			lerpf(150.0, r.size.x - 110.0, hx),   # leave the start column and the edge clear
			lerpf(70.0, r.size.y - 70.0, hy))
		_doodles.append({
			"pos": pos,
			"type": int(_h(k * 3 + 5) * 4.0) % 4,
			"size": 0.8 + _h(k * 4 + 9) * 0.7,
		})
	_rebuild_obstacles()
	queue_redraw()

func _h(n: int) -> float:
	var s := sin(float(n) * 12.9898 + 78.233) * 43758.5453
	return s - floor(s)

# --- Obstacles -----------------------------------------------------------

func _rebuild_obstacles() -> void:
	for c in get_children():
		if c is StaticBody2D:
			c.queue_free()
	for d in _doodles:
		match d.type:
			3:  # squiggle: a horizontal bar
				_add_rect(d.pos + Vector2(87.0 * d.size, 0), Vector2(174.0 * d.size, 28.0))
			_:  # star / spiral / cloud: a circle
				_add_circle(d.pos, 28.0 * d.size)

func _add_obstacle(shape: Shape2D, pos: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = pos
	body.collision_layer = OBSTACLE_LAYER
	body.collision_mask = 0
	body.add_to_group("doodle_obstacles")
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

# --- Drawing -------------------------------------------------------------

func _j(p: Vector2, amp := 1.3) -> Vector2:
	return Game.boil_jitter(p, amp)

func _draw() -> void:
	var r: Rect2 = Game.sheet_rect

	# Graph-paper sheet: the squared-paper texture stretched to fill.
	if _grid_tex:
		draw_texture_rect(_grid_tex, r, false)
	else:
		draw_rect(r, Color(0.99, 0.99, 0.98), true)

	# Page border as a boiled rectangle outline.
	var border := PackedVector2Array([
		_j(r.position), _j(r.position + Vector2(r.size.x, 0)),
		_j(r.position + r.size), _j(r.position + Vector2(0, r.size.y)), _j(r.position)])
	draw_polyline(border, Color(0.80, 0.80, 0.74), 1.5)

	# Decorative doodles for this page (also the things the player bumps into).
	var col := Color(0.35, 0.4, 0.55, 0.7)
	for d in _doodles:
		match d.type:
			0: _doodle_star(d.pos, col, d.size)
			1: _doodle_spiral(d.pos, col, d.size)
			2: _doodle_cloud(d.pos, col, d.size)
			3: _doodle_squiggle(d.pos, col, d.size)

func _doodle_star(c: Vector2, col: Color, s := 1.0) -> void:
	var pts: PackedVector2Array = []
	for i in range(11):
		var ang := -PI / 2.0 + i * PI * 2.0 / 10.0
		var rad := (32.0 if i % 2 == 0 else 13.0) * s
		pts.append(_j(c + Vector2(cos(ang), sin(ang)) * rad))
	draw_polyline(pts, col, 2.5)

func _doodle_spiral(c: Vector2, col: Color, s := 1.0) -> void:
	var pts: PackedVector2Array = []
	for i in range(46):
		var t := i / 6.0
		pts.append(_j(c + Vector2(cos(t), sin(t)) * (2.0 + t * 4.2) * s))
	draw_polyline(pts, col, 2.5)

func _doodle_cloud(c: Vector2, col: Color, s := 1.0) -> void:
	var pts: PackedVector2Array = []
	for i in range(25):
		var t := i / 24.0 * TAU
		var rad := (26.0 + 9.0 * sin(t * 3.0)) * s
		pts.append(_j(c + Vector2(cos(t) * rad, sin(t) * rad * 0.55)))
	pts.append(pts[0])
	draw_polyline(pts, col, 2.5)

func _doodle_squiggle(c: Vector2, col: Color, s := 1.0) -> void:
	var pts: PackedVector2Array = []
	for i in range(30):
		var x := i * 6.0 * s
		pts.append(_j(c + Vector2(x, sin(x * 0.2) * 16.0)))
	draw_polyline(pts, col, 2.5)
