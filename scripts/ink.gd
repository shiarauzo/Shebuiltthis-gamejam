extends Area2D
class_name Ink
## A persistent ink stroke drawn by the pencil. Damages the player on touch.
## Erasable by the eraser (it checks distance to `mid`).

const INK := Color(0.16, 0.16, 0.22)  # dark pencil ink (not blue)

var mid: Vector2 = Vector2.ZERO

## A randomly-chosen hand-drawn doodle (star / spiral / cloud / scribble),
## centred at c with the given radius, with a little jitter so it's not too neat.
func _doodle_points(c: Vector2, radius: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var kind := randi() % 4
	if kind == 0:  # spiral
		for i in range(40):
			var t := i / 6.0
			pts.append(c + Vector2(cos(t), sin(t)) * (2.0 + t * (radius / 13.0)))
	elif kind == 1:  # star
		for i in range(11):
			var ang := -PI / 2.0 + i * PI * 2.0 / 10.0
			var rr := radius if i % 2 == 0 else radius * 0.42
			pts.append(c + Vector2(cos(ang), sin(ang)) * rr)
	elif kind == 2:  # cloud
		for i in range(26):
			var t := i / 24.0 * TAU
			var rr := radius * 0.85 + radius * 0.3 * sin(t * 3.0)
			pts.append(c + Vector2(cos(t) * rr, sin(t) * rr * 0.6))
	else:  # loopy scribble
		for i in range(22):
			var t := i / 21.0
			var ang := t * TAU * 1.5
			pts.append(c + Vector2(lerp(-radius, radius, t), sin(ang) * radius * 0.6))
	# Hand-drawn jitter so nothing is perfectly straight/smooth.
	for i in range(pts.size()):
		pts[i] += Vector2(randf_range(-2.5, 2.5), randf_range(-2.5, 2.5))
	return pts

func setup(a: Vector2, b: Vector2) -> void:
	add_to_group("ink")
	z_index = 1
	monitoring = true
	monitorable = true
	collision_layer = 0
	collision_mask = 1
	mid = (a + b) * 0.5

	# The pencil draws a little hand-drawn doodle (a star / spiral / cloud /
	# scribble) in dark ink, centred where the stroke lands.
	var line := Line2D.new()
	line.width = 3.5
	line.default_color = INK
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	for p in _doodle_points(mid, maxf((b - a).length(), 70.0) * 0.45):
		line.add_point(p)
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
	burst.color = INK
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
