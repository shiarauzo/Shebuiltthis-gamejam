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

	# The pencil scribbles a little doodle (a wavy squiggle) rather than a plain
	# straight line, tapered at the ends so it still spans a..b.
	var line := Line2D.new()
	line.width = 4.0
	line.default_color = Color(0.13, 0.18, 0.55)  # ink blue
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	var dir := b - a
	var perp := (dir.normalized().rotated(PI / 2.0)) if dir.length() > 0.1 else Vector2.UP
	var seg := 18
	for i in range(seg + 1):
		var t := float(i) / float(seg)
		var envelope := sin(t * PI)  # 0 at the ends, 1 in the middle
		var wob := sin(t * TAU * 2.5) * 15.0 * envelope
		line.add_point(a.lerp(b, t) + perp * wob)
	add_child(line)

	var cs := CollisionShape2D.new()
	var cap := CapsuleShape2D.new()
	cap.radius = 6.0
	cap.height = maxf((b - a).length(), 12.0)
	cs.shape = cap
	cs.position = mid
	cs.rotation = (b - a).angle() - PI / 2.0  # capsule long axis is vertical by default
	add_child(cs)

	# Ink-splatter burst where the stroke lands.
	var burst := CPUParticles2D.new()
	burst.position = mid
	burst.one_shot = true
	burst.explosiveness = 0.9
	burst.amount = 10
	burst.lifetime = 0.5
	burst.direction = Vector2(1, 0)
	burst.spread = 180.0
	burst.initial_velocity_min = 40.0
	burst.initial_velocity_max = 130.0
	burst.gravity = Vector2.ZERO
	burst.scale_amount_min = 1.0
	burst.scale_amount_max = 2.5
	burst.color = Color(0.13, 0.18, 0.55)
	burst.emitting = true
	add_child(burst)
	burst.finished.connect(burst.queue_free)  # don't leave idle emitters in the tree

	# Damage on entry (cheap, signal-based) instead of polling every frame.
	body_entered.connect(_on_body_entered)
	# Also catch a player who was already standing where the stroke landed.
	_check_initial_overlap.call_deferred()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage()

func _check_initial_overlap() -> void:
	await get_tree().physics_frame
	if not is_instance_valid(self):
		return
	for body in get_overlapping_bodies():
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage()
