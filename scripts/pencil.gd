extends Node2D
class_name Pencil
## The giant pencil. Its shadow chases the player (slower than the player's run),
## commits to a spot, flashes a telegraph preview of the stroke, then inks it.

const SPEED := 140.0
const COMMIT_INTERVAL := 2.4
const FLASH_TIME := 0.9
const STROKE_LEN := 130.0
const MAX_INK := 18  # cap live strokes so long runs don't accumulate nodes

var target: Node2D
var ink_parent: Node

var _strokes: Array[Ink] = []

var _state := "track"  # "track" | "commit"
var _t := 0.0
var _commit_pos := Vector2.ZERO
var _stroke_angle := 0.0

func _ready() -> void:
	z_index = 10
	# Hand-drawn pencil doodle (Shiara). Its drawn tip is at the lower-left of the
	# 500px art; offset the sprite so that tip lands on the action point (origin).
	var spr := Sprite2D.new()
	spr.texture = load("res://assets/pencil.png")
	var s := 0.6
	spr.scale = Vector2(s, s)
	spr.position = Vector2(140, -150) * s  # keep the drawn tip on the action point
	add_child(spr)

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
			# Fairness: if the pencil has caught up to a (stationary) player, push
			# the stroke off-center so it never pins them dead-on and repeated
			# commits don't stack on the same spot. A moving player is already
			# safe because the pencil (140 px/s) lags behind them (200 px/s).
			if is_instance_valid(target) and _commit_pos.distance_to(target.global_position) < 28.0:
				var off := randf() * TAU
				_commit_pos = target.global_position + Vector2(cos(off), sin(off)) * 60.0
			# Keep the whole stroke on the page (it extends STROKE_LEN/2 each way).
			var r2: Rect2 = Game.sheet_rect
			var inset := STROKE_LEN * 0.5
			_commit_pos.x = clampf(_commit_pos.x, r2.position.x + inset, r2.position.x + r2.size.x - inset)
			_commit_pos.y = clampf(_commit_pos.y, r2.position.y + inset, r2.position.y + r2.size.y - inset)
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

	# Cap live ink: drop the oldest stroke once over the limit (FIFO).
	_strokes = _strokes.filter(func(s): return is_instance_valid(s))
	_strokes.append(ink)
	while _strokes.size() > MAX_INK:
		var oldest: Ink = _strokes.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()

func _draw() -> void:
	# The pencil body is the hand-drawn sprite; here we only draw the marker and
	# the telegraph preview of the stroke that's about to be inked.
	if _state == "commit":
		# Telegraph: faint pulsing preview of the exact stroke that will be inked.
		var half := Vector2(cos(_stroke_angle), sin(_stroke_angle)) * (STROKE_LEN * 0.5)
		var pulse := 0.5 + 0.5 * sin(_t * 18.0)
		draw_line(Game.boil_jitter(-half), Game.boil_jitter(half), Color(0.55, 0.55, 0.6, 0.30 + 0.45 * pulse), 3.0)
		draw_circle(Vector2.ZERO, 5.0, Color(0.85, 0.12, 0.12, 0.85))
	else:
		draw_circle(Vector2.ZERO, 5.0, Color(0.35, 0.35, 0.4, 0.45))
