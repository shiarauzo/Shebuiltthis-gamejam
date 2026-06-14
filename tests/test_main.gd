extends Node
## Headless integration test harness for Notebook Awakening.
## Run with:  Godot --headless res://tests/test_main.tscn
## Results print to stdout (and to user://last_run.log).
## Exits with code 0 if all tests pass, 1 otherwise (3 = watchdog timeout).

var _failures: int = 0
var _passes: int = 0
var _logf: FileAccess

func _ready() -> void:
	_logf = FileAccess.open("user://last_run.log", FileAccess.WRITE)
	get_tree().create_timer(60.0).timeout.connect(func():
		_log("WATCHDOG TIMEOUT — harness did not finish in time")
		if _logf: _logf.flush()
		get_tree().quit(3))
	Game.testing = true
	_log("==== TEST RUN START ====")
	await get_tree().process_frame
	await _test_movement()
	await _test_touch_movement()
	await _test_focus_out_stops_movement()
	await _test_damage_and_iframes()
	await _test_hearts_track_health()
	await _test_death()
	await _test_player_collides_with_doodles()
	await _test_intro_then_play()
	await _test_threats_are_incremental()
	await _test_pencil_draws_ink()
	await _test_ink_cap()
	await _test_ink_damages_standing_player()
	await _test_eraser_contact_and_leaves()
	await _test_page_flip_advances()
	await _test_five_pages_then_win()

	_log("\n==== TEST SUMMARY ====")
	_log("PASSED: %d   FAILED: %d" % [_passes, _failures])
	_log("RESULT: ALL TESTS PASSED" if _failures == 0 else "RESULT: FAILURES PRESENT")
	if _logf:
		_logf.flush()
	get_tree().quit(0 if _failures == 0 else 1)

func _log(s: String) -> void:
	print(s)
	if _logf:
		_logf.store_line(s)
		_logf.flush()

func _check(name: String, ok: bool, detail: String = "") -> void:
	if ok:
		_passes += 1
		_log("  PASS: %s %s" % [name, detail])
	else:
		_failures += 1
		_log("  FAIL: %s %s" % [name, detail])

func _make_game() -> Node:
	var scene := load("res://scenes/game.tscn")
	var g = scene.instantiate()
	add_child(g)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().physics_frame
	return g

func _free_game(g: Node) -> void:
	g.queue_free()
	await get_tree().process_frame

func _wait_until(cond: Callable, timeout: float) -> bool:
	var elapsed := 0.0
	while elapsed < timeout:
		if cond.call():
			return true
		await get_tree().create_timer(0.1).timeout
		elapsed += 0.1
	return cond.call()

# --- Player-level tests --------------------------------------------------

func _test_movement() -> void:
	_log("[movement]")
	var g = await _make_game()
	var player = g.player
	player.set_physics_process(true)
	var start_x: float = player.global_position.x
	var ev := InputEventKey.new(); ev.physical_keycode = KEY_D; ev.pressed = true
	Input.parse_input_event(ev); Input.flush_buffered_events()
	for i in range(20):
		await get_tree().physics_frame
	var rel := InputEventKey.new(); rel.physical_keycode = KEY_D; rel.pressed = false
	Input.parse_input_event(rel); Input.flush_buffered_events()
	var moved: float = player.global_position.x - start_x
	_check("moves right on D", moved > 5.0, "(dx=%.1f)" % moved)
	await _free_game(g)

func _test_touch_movement() -> void:
	_log("[touch movement]")
	var g = await _make_game()
	var player = g.player
	player.set_physics_process(true)
	var x0: float = player.global_position.x
	player._touching = true
	player._touch_target = player.global_position + Vector2(200, 0)
	for i in range(15):
		await get_tree().physics_frame
	var moved: float = player.global_position.x - x0
	player._touching = false
	_check("moves toward touch point", moved > 5.0, "(dx=%.1f)" % moved)
	await _free_game(g)

func _test_focus_out_stops_movement() -> void:
	_log("[focus-out stops movement]")
	var g = await _make_game()
	var player = g.player
	player.set_physics_process(true)
	var ev := InputEventKey.new(); ev.physical_keycode = KEY_D; ev.pressed = true
	Input.parse_input_event(ev); Input.flush_buffered_events()
	player._notification(player.NOTIFICATION_APPLICATION_FOCUS_OUT)
	var x0: float = player.global_position.x
	for i in range(15):
		await get_tree().physics_frame
	var drift: float = absf(player.global_position.x - x0)
	_check("no drift while unfocused", drift < 0.5, "(drift=%.2f)" % drift)
	var rel := InputEventKey.new(); rel.physical_keycode = KEY_D; rel.pressed = false
	Input.parse_input_event(rel); Input.flush_buffered_events()
	player._notification(player.NOTIFICATION_APPLICATION_FOCUS_IN)
	await _free_game(g)

func _test_damage_and_iframes() -> void:
	_log("[damage + i-frames]")
	var g = await _make_game()
	var player = g.player
	player.take_damage()
	_check("first hit drops health to 2", player.health == 2, "(hp=%d)" % player.health)
	player.take_damage()
	_check("second hit during i-frames ignored", player.health == 2, "(hp=%d)" % player.health)
	_check("fade applied", player.modulate.a < 1.0, "(a=%.2f)" % player.modulate.a)
	await _free_game(g)

func _test_hearts_track_health() -> void:
	_log("[hearts HUD tracks health]")
	var g = await _make_game()
	var player = g.player
	_check("three hearts built", g.hearts.size() == 3, "(n=%d)" % g.hearts.size())
	_check("textures loaded", g.heart_full_tex != null and g.heart_empty_tex != null)
	_check("all hearts full at start", g.hearts[0].texture == g.heart_full_tex \
		and g.hearts[2].texture == g.heart_full_tex)
	player.take_damage()  # health 3 -> 2, emits health_changed -> _on_player_hit
	await get_tree().process_frame
	_check("hit empties the last heart", g.hearts[2].texture == g.heart_empty_tex)
	_check("remaining hearts stay full", g.hearts[0].texture == g.heart_full_tex \
		and g.hearts[1].texture == g.heart_full_tex, "(hp=%d)" % player.health)
	await _free_game(g)

func _test_death() -> void:
	_log("[death]")
	var g = await _make_game()
	var player = g.player
	for i in range(3):
		player.invincible = false
		player._iframe_t = 0.0
		player.take_damage()
	_check("health reaches 0", player.health <= 0, "(hp=%d)" % player.health)
	_check("game registered loss", g.ended and Game.won == false)
	await _free_game(g)

# --- Flow tests ----------------------------------------------------------

func _test_intro_then_play() -> void:
	_log("[intro -> play]")
	var g = await _make_game()
	_check("starts in intro", g.state == "intro", "(state=%s)" % g.state)
	g._begin_play()
	await get_tree().physics_frame
	_check("begins play on input", g.state == "play", "(state=%s)" % g.state)
	# Page 1 is a calm explore: no pencil, no erasers yet.
	_check("page 1 has no erasers yet", get_tree().get_nodes_in_group("erasers").size() == 0)
	_check("page 1 pencil has no target yet", g.pencil.target == null)
	await _free_game(g)

func _test_player_collides_with_doodles() -> void:
	_log("[player bumps decorative doodles]")
	var g = await _make_game()
	g._begin_play()
	g.notebook.set_page(5)  # a busy page -> plenty of obstacles to pick from
	await get_tree().process_frame  # let the old obstacles' queue_free settle
	g.player.set_physics_process(false)  # drive movement manually
	var r: Rect2 = Game.sheet_rect
	# Pick a doodle obstacle (scoped to this notebook) with room to its left.
	var ob: Node2D = null
	for o in g.notebook.get_children():
		if not (o is StaticBody2D):
			continue
		if o.position.x > r.position.x + 250.0 and o.position.x < r.position.x + r.size.x - 150.0 \
				and o.position.y > r.position.y + 100.0 and o.position.y < r.position.y + r.size.y - 100.0:
			ob = o
			break
	_check("found a testable doodle obstacle", ob != null)
	if ob == null:
		await _free_game(g)
		return
	g.player.global_position = Vector2(ob.position.x - 80.0, ob.position.y)
	for i in range(40):
		g.player.velocity = Vector2(320, 0)
		g.player.move_and_slide()
		await get_tree().physics_frame
	_check("blocked by a doodle (can't walk through)", g.player.global_position.x < ob.position.x,
		"(px=%.0f obx=%.0f)" % [g.player.global_position.x, ob.position.x])
	await _free_game(g)

func _test_threats_are_incremental() -> void:
	_log("[threats are incremental]")
	var g = await _make_game()
	g._begin_play()
	_check("page 1: no pencil", g.pencil.target == null)
	_check("page 1: no erasers", get_tree().get_nodes_in_group("erasers").size() == 0)
	g.page = 2
	g._introduce_threats()
	_check("page 2: pencil drops in", g.pencil.target != null)
	_check("page 2: still no erasers", get_tree().get_nodes_in_group("erasers").size() == 0)
	g.page = 3
	g._introduce_threats()
	_check("page 3: erasers start raining", g._erasers_on and get_tree().get_nodes_in_group("erasers").size() >= 1)
	await _free_game(g)

func _test_pencil_draws_ink() -> void:
	_log("[pencil draws ink from page 2]")
	var g = await _make_game()
	g._begin_play()
	g.page = 2
	g._introduce_threats()  # the pencil starts scribbling on page 2
	var drew := await _wait_until(func(): return get_tree().get_nodes_in_group("ink").size() >= 1, 6.0)
	_check("pencil produced ink", drew, "(ink=%d)" % get_tree().get_nodes_in_group("ink").size())
	await _free_game(g)

func _test_ink_cap() -> void:
	_log("[ink cap]")
	var g = await _make_game()
	g._begin_play()
	var r: Rect2 = Game.sheet_rect
	g.pencil._commit_pos = r.position + r.size * 0.5
	g.pencil._stroke_angle = 0.0
	for i in range(Pencil.MAX_INK + 8):
		g.pencil._spawn_ink()
	await get_tree().process_frame
	var count := get_tree().get_nodes_in_group("ink").size()
	_check("ink count capped at MAX_INK", count <= Pencil.MAX_INK, "(count=%d)" % count)
	await _free_game(g)

func _test_ink_damages_standing_player() -> void:
	_log("[ink hits a standing player]")
	var g = await _make_game()
	g._begin_play()
	var player = g.player
	var hp0: int = player.health
	var ink = Ink.new()
	g.add_child(ink)
	var p: Vector2 = player.global_position
	ink.setup(p - Vector2(20, 0), p + Vector2(20, 0))
	for i in range(4):
		await get_tree().physics_frame
	_check("stroke on standing player deals damage", player.health < hp0, "(hp %d->%d)" % [hp0, player.health])
	await _free_game(g)

func _test_eraser_contact_and_leaves() -> void:
	_log("[eraser drops in, chips a heart, then leaves]")
	var g = await _make_game()
	g._begin_play()
	g.page = 3
	g._introduce_threats()  # rains the first wave of erasers
	var erasers := get_tree().get_nodes_in_group("erasers")
	_check("an eraser dropped in", erasers.size() >= 1)
	if erasers.size() == 0:
		await _free_game(g)
		return
	var e = erasers[0]
	var player = g.player
	# Once it finishes dropping (chase phase) and we keep it on the player, contact
	# chips a heart — i-frames mean it's not an instant kill.
	var chipped := await _wait_until(func():
		if is_instance_valid(e):
			e.global_position = player.global_position
		return player.health < Player.MAX_HEALTH, 4.0)
	_check("eraser contact chips a heart, not instant death", chipped and not g.ended, "(hp=%d)" % player.health)
	# It's transient: after its lifetime it flies away and frees itself. Track by
	# instance id so the closure never captures a freed object.
	var eid := e.get_instance_id()
	var left := await _wait_until(func(): return not is_instance_valid(instance_from_id(eid)), 7.0)
	_check("eraser leaves after a while (transient)", left)
	await _free_game(g)

func _test_page_flip_advances() -> void:
	_log("[page flip advances]")
	Game.won = false
	var g = await _make_game()
	g._begin_play()
	await get_tree().physics_frame
	var r: Rect2 = Game.sheet_rect
	g.player.global_position.x = r.position.x + r.size.x - 8.0
	var ok = await _wait_until(func(): return g.page == 2 and g.state == "play", 4.0)
	_check("reaching edge flips to page 2", ok, "(page=%d state=%s)" % [g.page, g.state])
	await _free_game(g)

func _test_five_pages_then_win() -> void:
	_log("[five pages -> win]")
	Game.won = false
	var g = await _make_game()
	var won_flag := [false]
	g.game_over.connect(func(w): won_flag[0] = w)
	g._begin_play()
	await get_tree().physics_frame
	var r: Rect2 = Game.sheet_rect
	for p in range(g.total_pages):
		await _wait_until(func(): return g.state == "play", 4.0)
		g.player.global_position.x = r.position.x + r.size.x - 8.0
		await _wait_until(func(): return g.page > (p + 1) or g.ended, 4.0)
	var done = await _wait_until(func(): return g.ended, 5.0)
	_check("five pages then win", done and Game.won == true and won_flag[0] == true, "(page=%d ended=%s won=%s)" % [g.page, g.ended, Game.won])
	await _free_game(g)
