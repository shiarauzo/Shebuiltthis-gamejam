extends CharacterBody2D
class_name Player
## The awakened doodle. Top-down movement (WASD + arrows), 3 lives.
## Drawn as a hand-made run animation (assets/sprites/doodle_run); health is
## shown by the sketchy hearts HUD (game.gd) plus the doodle fading out.

signal died
signal health_changed(health: int)

const SPEED := 200.0
const MAX_HEALTH := 3
const IFRAME_TIME := 1.2
const RADIUS := 15.0
const OBSTACLE_LAYER := 2  # the decorative page doodles the player bumps into

var health := MAX_HEALTH
var invincible := false
var _iframe_t := 0.0
var _blink_t := 0.0
var speed_mult := 1.0  # boosted in e2e fast mode so pages traverse quickly
var _focused := true
var _touching := false
var _touch_target := Vector2.ZERO
var _dead := false
var _sprite: AnimatedSprite2D
var _godmode := false  # test-only: __AWAKE_INVINCIBLE lets the e2e prove the win flow

func _ready() -> void:
	add_to_group("player")
	_godmode = Game.web_flag("__AWAKE_INVINCIBLE")  # cached once (no per-hit JS eval)
	z_index = 5
	collision_layer = 1
	collision_mask = OBSTACLE_LAYER  # bump into the page's decorative doodles
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = RADIUS
	cs.shape = shape
	add_child(cs)
	_build_sprite()

func _build_sprite() -> void:
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	frames.add_animation("run")
	frames.set_animation_loop("run", true)
	frames.set_animation_speed("run", 14.0)
	for i in range(7):
		var tex := load("res://assets/sprites/doodle_run/run_%d.png" % i) as Texture2D
		if tex:
			frames.add_frame("run", tex)
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = frames
	_sprite.animation = "run"
	_sprite.scale = Vector2(0.23, 0.23)  # 256px art -> ~59px doodle
	_sprite.play("run")
	add_child(_sprite)

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

	# Animate the doodle: run while moving, settle on a still pose otherwise,
	# and face the way it's heading.
	if _sprite:
		if velocity.length() > 1.0:
			if not _sprite.is_playing():
				_sprite.play("run")
			if absf(velocity.x) > 0.1:
				_sprite.flip_h = velocity.x < 0.0
		elif _sprite.is_playing():
			_sprite.stop()
			_sprite.frame = 0

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
	if _godmode or invincible or _dead:
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
