extends Area2D
class_name Ink
## A persistent ink stroke drawn by the pencil. Damages the player on touch.
## Erasable by the eraser (it checks distance to `mid`).

var mid: Vector2 = Vector2.ZERO

func setup(a: Vector2, b: Vector2) -> void:
	add_to_group("ink")
	z_index = 1
	monitoring = true
	monitorable = true
	collision_layer = 0
	collision_mask = 1
	mid = (a + b) * 0.5

	var line := Line2D.new()
	line.width = 5.0
	line.default_color = Color(0.13, 0.18, 0.55)  # ink blue
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.add_point(a)
	line.add_point(b)
	add_child(line)

	var cs := CollisionShape2D.new()
	var cap := CapsuleShape2D.new()
	cap.radius = 6.0
	cap.height = maxf((b - a).length(), 12.0)
	cs.shape = cap
	cs.position = mid
	cs.rotation = (b - a).angle() - PI / 2.0  # capsule long axis is vertical by default
	add_child(cs)

func _physics_process(_delta: float) -> void:
	# Continuous hazard: damages on overlap (not just on entry), so a stroke
	# drawn on top of a standing player still hurts. take_damage() respects
	# i-frames, so this won't spam more than once per invulnerability window.
	for body in get_overlapping_bodies():
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage()
