extends Node2D
class_name Pencil
## The giant pencil. Its shadow chases the player (slower than the player's run),
## commits to a spot, flashes a telegraph preview of the stroke, then inks it.

const SPEED := 140.0
const COMMIT_INTERVAL := 2.4
const FLASH_TIME := 0.9
const STROKE_LEN := 130.0

var target: Node2D
var ink_parent: Node

var _state := "track"  # "track" | "commit"
var _t := 0.0
var _commit_pos := Vector2.ZERO
var _stroke_angle := 0.0

func _ready() -> void:
	z_index = 10

func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return

	if _state == "track":
		var to := target.global_position - global_position
		if to.length() > 1.0:
			global_position += to.normalized() * SPEED * delta
		var r: Rect2 = Game.sheet_rect
		global_position.x = clampf(global_position.x, r.position.x, r.position.x + r.size.x)
		global_position.y = clampf(global_position.y, r.position.y, r.position.y + r.size.y)
		_t += delta
		if _t >= COMMIT_INTERVAL:
			_state = "commit"
			_t = 0.0
			_commit_pos = global_position
			_stroke_angle = randf() * TAU
	else:  # commit
		_t += delta
		if _t >= FLASH_TIME:
			_spawn_ink()
			_t = 0.0
			_state = "track"

	queue_redraw()

func _spawn_ink() -> void:
	var half := Vector2(cos(_stroke_angle), sin(_stroke_angle)) * (STROKE_LEN * 0.5)
	var ink := Ink.new()
	ink_parent.add_child(ink)
	ink.setup(_commit_pos - half, _commit_pos + half)

func _draw() -> void:
	# Pencil hovering above the page (a yellow shaft + tip), drawn from the marker.
	draw_line(Vector2.ZERO, Vector2(34, -86), Color(0.86, 0.66, 0.20, 0.85), 7.0)
	draw_line(Vector2(34, -86), Vector2(46, -112), Color(0.95, 0.85, 0.6, 0.9), 7.0)
	draw_circle(Vector2(46, -112), 4.0, Color(0.85, 0.5, 0.25, 0.9))

	if _state == "commit":
		# Telegraph: faint pulsing preview of the exact stroke that will be inked.
		var half := Vector2(cos(_stroke_angle), sin(_stroke_angle)) * (STROKE_LEN * 0.5)
		var pulse := 0.5 + 0.5 * sin(_t * 18.0)
		draw_line(-half, half, Color(0.55, 0.55, 0.6, 0.30 + 0.45 * pulse), 3.0)
		draw_circle(Vector2.ZERO, 5.0, Color(0.85, 0.12, 0.12, 0.85))
	else:
		draw_circle(Vector2.ZERO, 5.0, Color(0.35, 0.35, 0.4, 0.45))
