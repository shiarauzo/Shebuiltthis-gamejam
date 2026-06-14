extends Area2D
class_name Eraser
## The giant eraser (phase 2). Chases the player, erases ink it passes over,
## and chips away one heart each time it touches the player (player i-frames
## space the hits out, so contact drains a heart roughly once per i-frame
## window rather than an instant kill).

signal caught_player

const SPEED := 120.0
const ERASE_RADIUS := 92.0
const SPAWN_GRACE := 0.6  # can't catch the player for a beat after appearing

var target: Node2D
var _armed := false

func _ready() -> void:
	Game.boil_tick.connect(queue_redraw)
	z_index = 6
	monitoring = true
	collision_layer = 0
	collision_mask = 1
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(50, 66)
	cs.shape = rect
	add_child(cs)
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(SPAWN_GRACE).timeout.connect(_arm)

func _arm() -> void:
	_armed = true

	# Trailing eraser-shaving dust.
	var dust := CPUParticles2D.new()
	dust.amount = 18
	dust.lifetime = 0.6
	dust.spread = 180.0
	dust.direction = Vector2(0, 1)
	dust.gravity = Vector2(0, 50)
	dust.initial_velocity_min = 8.0
	dust.initial_velocity_max = 45.0
	dust.scale_amount_min = 1.0
	dust.scale_amount_max = 2.5
	dust.color = Color(0.96, 0.86, 0.89, 0.7)
	dust.emitting = true
	add_child(dust)

func _physics_process(delta: float) -> void:
	# Runs at a fixed 60 Hz (not the uncapped visual frame rate) and settles with
	# the physics step. Ink is capped (see Pencil.MAX_INK), so this scan is small.
	if target and is_instance_valid(target):
		var to := target.global_position - global_position
		if to.length() > 1.0:
			global_position += to.normalized() * SPEED * delta

	# Erase any ink the eraser sweeps over.
	for ink in get_tree().get_nodes_in_group("ink"):
		if is_instance_valid(ink) and global_position.distance_to(ink.mid) < ERASE_RADIUS:
			ink.queue_free()

	# Contact damage: while overlapping the player, keep signalling a hit. The
	# player's i-frames swallow the repeats, so each touch costs one heart and
	# the player gets a window to break away before the next.
	if _armed and monitoring:
		for b in get_overlapping_bodies():
			if b.is_in_group("player"):
				caught_player.emit()
				break

func _on_body_entered(body: Node) -> void:
	if _armed and body.is_in_group("player"):
		caught_player.emit()

func _draw() -> void:
	# Pink eraser body with a darker felt base + boiled scribbly outline.
	draw_rect(Rect2(-25, -33, 50, 66), Color(0.95, 0.55, 0.66), true)
	draw_rect(Rect2(-25, 16, 50, 17), Color(0.56, 0.40, 0.76), true)
	var o := PackedVector2Array([
		Game.boil_jitter(Vector2(-25, -33)), Game.boil_jitter(Vector2(25, -33)),
		Game.boil_jitter(Vector2(25, 33)), Game.boil_jitter(Vector2(-25, 33)),
		Game.boil_jitter(Vector2(-25, -33))])
	draw_polyline(o, Color(0.30, 0.18, 0.30), 1.8)
	draw_line(Game.boil_jitter(Vector2(-25, -18)), Game.boil_jitter(Vector2(25, -18)), Color(0.85, 0.45, 0.56), 1.5)
