extends Node
## Headless integration test harness for Notebook Awakening.
## Run with:  Godot --headless res://tests/test_main.tscn
## Exits with code 0 if all tests pass, 1 otherwise.

var _failures: int = 0
var _passes: int = 0
var _logf: FileAccess

func _ready() -> void:
	_logf = FileAccess.open("res://tests/last_run.log", FileAccess.WRITE)
	# Watchdog: never hang forever.
	get_tree().create_timer(40.0).timeout.connect(func():
		_log("WATCHDOG TIMEOUT — harness did not finish in time")
		if _logf: _logf.flush()
		get_tree().quit(3))
	Game.testing = true
	_log("==== TEST RUN START ====")
	await get_tree().process_frame
	await _test_movement()
	await _test_focus_out_stops_movement()
	await _test_damage_and_iframes()
	await _test_death_after_three_hits()
	await _test_pencil_draws_ink()
	await _test_ink_cap()
	await _test_ink_damages_standing_player()
	await _test_phase_two_trigger()
	await _test_eraser_erases_ink()
	await _test_win_on_reaching_edge()
	await _test_lose_on_eraser_contact()

	_log("\n==== TEST SUMMARY ====")
	_log("PASSED: %d   FAILED: %d" % [_passes, _failures])
	if _failures == 0:
		_log("RESULT: ALL TESTS PASSED")
	else:
		_log("RESULT: FAILURES PRESENT")
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

func _make_game(trigger := 30.0) -> Node:
	var scene := load("res://scenes/game.tscn")
	var g = scene.instantiate()
	g.eraser_trigger_time = trigger
	add_child(g)
	await get_tree().process_frame
	await get_tree().process_frame
	return g

func _free_game(g: Node) -> void:
	g.queue_free()
	await get_tree().process_frame

# --- Tests ---------------------------------------------------------------

func _test_movement() -> void:
	_log("[movement]")
	var g = await _make_game()
	var player = g.player
	var start_x: float = player.global_position.x

	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_D
	ev.pressed = true
	Input.parse_input_event(ev)
	Input.flush_buffered_events()

	# Advance several physics frames.
	for i in range(20):
		await get_tree().physics_frame

	var rel := InputEventKey.new()
	rel.physical_keycode = KEY_D
	rel.pressed = false
	Input.parse_input_event(rel)
	Input.flush_buffered_events()

	var moved: float = player.global_position.x - start_x
	_check("moves right on D", moved > 5.0, "(dx=%.1f)" % moved)
	await _free_game(g)

func _test_focus_out_stops_movement() -> void:
	_log("[focus-out stops movement]")
	var g = await _make_game()
	var player = g.player
	# Hold D, then drop focus — the player must not drift.
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_D
	ev.pressed = true
	Input.parse_input_event(ev)
	Input.flush_buffered_events()
	player._notification(player.NOTIFICATION_APPLICATION_FOCUS_OUT)
	var x0: float = player.global_position.x
	for i in range(15):
		await get_tree().physics_frame
	var drift: float = absf(player.global_position.x - x0)
	_check("no drift while unfocused", drift < 0.5, "(drift=%.2f)" % drift)
	# Release + refocus to not leak state into later tests.
	var rel := InputEventKey.new()
	rel.physical_keycode = KEY_D
	rel.pressed = false
	Input.parse_input_event(rel)
	Input.flush_buffered_events()
	player._notification(player.NOTIFICATION_APPLICATION_FOCUS_IN)
	await _free_game(g)

func _test_damage_and_iframes() -> void:
	_log("[damage + i-frames]")
	var g = await _make_game()
	var player = g.player
	player.take_damage()
	_check("first hit drops health to 2", player.health == 2, "(hp=%d)" % player.health)
	player.take_damage()  # should be ignored (invincible)
	_check("second hit during i-frames ignored", player.health == 2, "(hp=%d)" % player.health)
	_check("fade applied", player.modulate.a < 1.0, "(a=%.2f)" % player.modulate.a)
	await _free_game(g)

func _test_death_after_three_hits() -> void:
	_log("[death]")
	var g = await _make_game()
	var player = g.player
	var died := [false]
	player.died.connect(func(): died[0] = true)
	for i in range(3):
		player.invincible = false
		player._iframe_t = 0.0
		player.take_damage()
	_check("health reaches 0", player.health <= 0, "(hp=%d)" % player.health)
	_check("died signal emitted", died[0])
	_check("game registered loss", g.ended and Game.won == false)
	await _free_game(g)

func _test_pencil_draws_ink() -> void:
	_log("[pencil draws ink]")
	Game.won = false
	var g = await _make_game()
	# Wait long enough for at least one commit + flash cycle.
	await get_tree().create_timer(3.8).timeout
	var ink_count := get_tree().get_nodes_in_group("ink").size()
	_check("pencil produced ink", ink_count >= 1, "(ink=%d)" % ink_count)
	await _free_game(g)

func _test_ink_cap() -> void:
	_log("[ink cap]")
	var g = await _make_game()
	var r: Rect2 = Game.sheet_rect
	g.pencil._commit_pos = r.position + r.size * 0.5
	g.pencil._stroke_angle = 0.0
	for i in range(Pencil.MAX_INK + 8):
		g.pencil._spawn_ink()
	await get_tree().process_frame
	var count := get_tree().get_nodes_in_group("ink").size()
	_check("ink count capped at MAX_INK", count <= Pencil.MAX_INK, "(count=%d, max=%d)" % [count, Pencil.MAX_INK])
	await _free_game(g)

func _test_ink_damages_standing_player() -> void:
	_log("[ink hits a standing player]")
	var g = await _make_game()
	var player = g.player
	var hp0: int = player.health
	# Drop a stroke right on the (idle) player.
	var ink = Ink.new()
	g.add_child(ink)
	var p: Vector2 = player.global_position
	ink.setup(p - Vector2(20, 0), p + Vector2(20, 0))
	for i in range(4):
		await get_tree().physics_frame
	_check("stroke on standing player deals damage", player.health < hp0, "(hp %d->%d)" % [hp0, player.health])
	await _free_game(g)

func _test_phase_two_trigger() -> void:
	_log("[phase 2 trigger]")
	var g = await _make_game(1.0)
	g.escape_open_delay = 0.5
	await get_tree().create_timer(1.4).timeout
	_check("phase advances to 2+", g.phase >= 2, "(phase=%d)" % g.phase)
	_check("eraser spawned", g.eraser != null and is_instance_valid(g.eraser))
	# Escape edge should NOT be open immediately (must survive the eraser first).
	await get_tree().create_timer(0.8).timeout
	_check("escape edge opens after survival window", g.escape_edge.active and g.phase == 3, "(phase=%d)" % g.phase)
	await _free_game(g)

func _test_eraser_erases_ink() -> void:
	_log("[eraser erases ink]")
	var g = await _make_game(1.0)
	# Spawn an ink stroke right where the eraser will start (top-left corner).
	var r: Rect2 = Game.sheet_rect
	var ink = Ink.new()
	g.add_child(ink)
	var p := r.position + Vector2(40, 40)
	ink.setup(p - Vector2(30, 0), p + Vector2(30, 0))
	await get_tree().process_frame
	var before := get_tree().get_nodes_in_group("ink").size()
	# Place the eraser on top of the ink and let it process.
	await get_tree().create_timer(1.4).timeout  # phase 2 spawns eraser at top-left corner
	if g.eraser:
		g.eraser.global_position = p
	for i in range(10):
		await get_tree().physics_frame
	var still_there := is_instance_valid(ink) and ink.is_in_group("ink")
	_check("eraser removed nearby ink", not still_there, "(before=%d)" % before)
	await _free_game(g)

func _test_win_on_reaching_edge() -> void:
	_log("[win on reaching edge]")
	Game.won = false
	var g = await _make_game(0.5)
	g.escape_open_delay = 0.3
	var player = g.player
	var won_flag := [false]
	g.game_over.connect(func(w): won_flag[0] = w)
	# Wait past phase 2's survival window so the escape edge opens.
	await get_tree().create_timer(1.2).timeout
	_check("escape edge open before win attempt", g.escape_edge.active)
	# Teleport player into the escape edge.
	var r: Rect2 = Game.sheet_rect
	player.global_position = Vector2(r.position.x + r.size.x - 16.0, r.position.y + r.size.y * 0.5)
	for i in range(12):
		await get_tree().physics_frame
	_check("reaching edge wins", g.ended and Game.won == true and won_flag[0] == true)
	await _free_game(g)

func _test_lose_on_eraser_contact() -> void:
	_log("[lose on eraser contact]")
	Game.won = true  # set opposite to prove it flips
	var g = await _make_game(0.5)
	var player = g.player
	await get_tree().create_timer(0.8).timeout
	_check("eraser exists for contact test", g.eraser != null)
	if g.eraser:
		# Drive the eraser onto the player.
		g.eraser.global_position = player.global_position
		for i in range(8):
			await get_tree().physics_frame
	_check("eraser contact loses", g.ended and Game.won == false)
	await _free_game(g)
