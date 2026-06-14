extends CharacterBody2D
class_name Player
## The awakened stick figure. Top-down movement (WASD + arrows), 3 lives.
## Health is shown by the sketchy hearts HUD (game.gd) plus the figure fading out.

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
var speed_mult := 1.0  # boosted in e2e fast mode so pages traverse quickly
var _focused := true
var _touching := false
var _touch_target := Vector2.ZERO
var _dead := false

func _ready() -> void:
	add_to_group("player")
	Game.boil_tick.connect(queue_redraw)
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
		_touching = false
		velocity = Vector2.ZERO
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		_focused = true

func _unhandled_input(event: InputEvent) -> void:
	# Touch/drag-to-move for mobile: the doodle steers toward your finger.
	if event is InputEventScreenTouch:
		_touching = event.pressed
		if event.pressed:
			_touch_target = event.position
	elif event is InputEventScreenDrag:
		_touching = true
		_touch_target = event.position

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

	if _focused and _touching:
		var to := _touch_target - global_position
		if to.length() > 8.0:  # deadzone so a tap near the figure doesn't jitter
			dir += to.normalized()

	velocity = dir.normalized() * SPEED * speed_mult
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

## The single death path — from running out of health or being caught by the eraser.
func die() -> void:
	if _dead:
		return
	_dead = true
	died.emit()

func take_damage() -> void:
	if invincible or _dead:
		return
	health -= 1
	health_changed.emit(health)
	_update_fade()
	if health <= 0:
		die()
		return
	invincible = true
	_iframe_t = IFRAME_TIME
	_blink_t = 0.09

func _update_fade() -> void:
	# 3 hp -> 1.0, 2 -> ~0.78, 1 -> ~0.57
	modulate.a = 0.35 + 0.65 * (float(health) / float(MAX_HEALTH))

func _draw() -> void:
	var col := Color(0.12, 0.12, 0.18)
	# Head as a boiled ring (hand-drawn wobble).
	var head := PackedVector2Array()
	for i in range(11):
		var a := i * TAU / 10.0
		head.append(Game.boil_jitter(Vector2(0, -14) + Vector2(cos(a), sin(a)) * 7.0))
	draw_polyline(head, col, 2.0)
	draw_line(Game.boil_jitter(Vector2(0, -7)), Game.boil_jitter(Vector2(0, 10)), col, 2.0)    # body
	draw_line(Game.boil_jitter(Vector2(-9, -1)), Game.boil_jitter(Vector2(9, -1)), col, 2.0)   # arms
	draw_line(Game.boil_jitter(Vector2(0, 10)), Game.boil_jitter(Vector2(-8, 22)), col, 2.0)   # left leg
	draw_line(Game.boil_jitter(Vector2(0, 10)), Game.boil_jitter(Vector2(8, 22)), col, 2.0)    # right leg
