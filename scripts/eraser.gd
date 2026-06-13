extends Area2D
class_name Eraser
## The giant eraser (phase 2). Chases the player, erases ink it passes over,
## and kills the player on contact.

signal caught_player

const SPEED := 120.0
const ERASE_RADIUS := 92.0

var target: Node2D

func _ready() -> void:
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

func _process(delta: float) -> void:
	if target and is_instance_valid(target):
		var to := target.global_position - global_position
		if to.length() > 1.0:
			global_position += to.normalized() * SPEED * delta

	# Erase any ink the eraser sweeps over.
	for ink in get_tree().get_nodes_in_group("ink"):
		if is_instance_valid(ink) and global_position.distance_to(ink.mid) < ERASE_RADIUS:
			ink.queue_free()

	queue_redraw()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		caught_player.emit()

func _draw() -> void:
	# Pink eraser body with a darker felt base + scribbly outline.
	draw_rect(Rect2(-25, -33, 50, 66), Color(0.95, 0.55, 0.66), true)
	draw_rect(Rect2(-25, 16, 50, 17), Color(0.56, 0.40, 0.76), true)
	draw_rect(Rect2(-25, -33, 50, 66), Color(0.30, 0.18, 0.30), false)
	draw_line(Vector2(-25, -18), Vector2(25, -18), Color(0.85, 0.45, 0.56), 1.5)
