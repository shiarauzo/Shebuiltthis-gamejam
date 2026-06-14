extends CharacterBody2D
class_name Player
## The awakened stick figure. Top-down movement (WASD + arrows), 3 lives.
## Health is shown by the figure fading out — no HUD hearts.

signal died
signal health_changed(health: int)

const SPEED := 200.0
const MAX_HEALTH := 3
const IFRAME_TIME := 1.2
const RADIUS := 12.0

var health := MAX_HEALTH
var invincible := false
var _iframe_t := 0.0
var _blink_t := 0.0
var _focused := true

func _ready() -> void:
	add_to_group("player")
	z_index = 5
	collision_layer = 1
	collision_mask = 0
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = RADIUS
	cs.shape = shape
	add_child(cs)

func _notification(what: int) -> void:
	# When the tab/canvas loses focus the browser stops sending keyup, so keys
	# would "stick". Treat focus-out as all-keys-released.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_focused = false
		velocity = Vector2.ZERO
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		_focused = true

func _physics_process(delta: float) -> void:
	var dir := Vector2.ZERO
	if _focused:
		if Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			dir.y -= 1.0
		if Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			dir.y += 1.0
		if Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			dir.x -= 1.0
		if Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			dir.x += 1.0

	velocity = dir.normalized() * SPEED
	move_and_slide()

	# Clamp to the notebook page.
	var r: Rect2 = Game.sheet_rect
	global_position.x = clampf(global_position.x, r.position.x + RADIUS, r.position.x + r.size.x - RADIUS)
	global_position.y = clampf(global_position.y, r.position.y + RADIUS, r.position.y + r.size.y - RADIUS)

	if invincible:
		_iframe_t -= delta
		_blink_t -= delta
		if _blink_t <= 0.0:
			_blink_t = 0.09
			visible = not visible
		if _iframe_t <= 0.0:
			invincible = false
			visible = true

func take_damage() -> void:
	if invincible:
		return
	health -= 1
	health_changed.emit(health)
	_update_fade()
	if health <= 0:
		died.emit()
		return
	invincible = true
	_iframe_t = IFRAME_TIME
	_blink_t = 0.09

func _update_fade() -> void:
	# 3 hp -> 1.0, 2 -> ~0.78, 1 -> ~0.57
	modulate.a = 0.35 + 0.65 * (float(health) / float(MAX_HEALTH))

func _draw() -> void:
	var col := Color(0.12, 0.12, 0.18)
	draw_arc(Vector2(0, -14), 7.0, 0, TAU, 24, col, 2.0)   # head
	draw_line(Vector2(0, -7), Vector2(0, 10), col, 2.0)    # body
	draw_line(Vector2(-9, -1), Vector2(9, -1), col, 2.0)   # arms
	draw_line(Vector2(0, 10), Vector2(-8, 22), col, 2.0)   # left leg
	draw_line(Vector2(0, 10), Vector2(8, 22), col, 2.0)    # right leg
