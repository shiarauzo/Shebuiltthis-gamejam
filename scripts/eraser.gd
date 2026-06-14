extends Area2D
class_name Eraser
## A giant eraser that DROPS FROM THE SKY, chases the doodle for a short while,
## then flies back up and leaves. Touching it chips one heart (player i-frames
## space the repeats out, so it's not an instant kill). Several can rain down at
## once on the later pages — see Game._spawn_eraser_wave().

signal caught_player

const SPEED := 130.0
const ERASE_RADIUS := 92.0
const LIFE := 4.5  # seconds spent chasing before it flies away

var target: Node2D
var land_pos := Vector2.ZERO  # set by the spawner before add_child

var _phase := "enter"  # enter | chase | leave
var _life_t := 0.0

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
	# Hand-drawn eraser doodle (Shiara). 256px art scaled to the hitbox size.
	var spr := Sprite2D.new()
	spr.texture = load("res://assets/eraser.png")
	spr.scale = Vector2(0.34, 0.34)
	add_child(spr)
	body_entered.connect(_on_body_entered)

	# Drop in from above the page to the landing spot.
	var sky := Vector2(land_pos.x, Game.sheet_rect.position.y - 170.0)
	global_position = sky
	var tw := create_tween()
	tw.tween_property(self, "global_position:y", land_pos.y, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): _phase = "chase")

func _physics_process(delta: float) -> void:
	if _phase != "chase":
		return

	_life_t += delta
	if _life_t >= LIFE:
		_leave()
		return

	if target and is_instance_valid(target):
		var to := target.global_position - global_position
		if to.length() > 1.0:
			global_position += to.normalized() * SPEED * delta

	# Erase any ink the eraser sweeps over.
	for ink in get_tree().get_nodes_in_group("ink"):
		if is_instance_valid(ink) and global_position.distance_to(ink.mid) < ERASE_RADIUS:
			ink.queue_free()

	# Contact damage: while overlapping the player, keep signalling a hit. The
	# player's i-frames swallow the repeats, so each touch costs one heart.
	for b in get_overlapping_bodies():
		if b.is_in_group("player"):
			caught_player.emit()
			break

## Fly back up off the page, then remove itself.
func _leave() -> void:
	if _phase == "leave":
		return
	_phase = "leave"
	monitoring = false
	var tw := create_tween()
	tw.tween_property(self, "global_position:y", Game.sheet_rect.position.y - 220.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)

func _on_body_entered(body: Node) -> void:
	if _phase == "chase" and body.is_in_group("player"):
		caught_player.emit()
