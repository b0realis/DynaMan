extends Node
## Screenshot runner (dev tool). Drives splash → menu → setup panel →
## battle (countdown, explosion, pause, round win) with injected input.
##   OUTBLOCKIT_SHOT_DIR-style env: DYNAMAN_SHOT_DIR=/abs/path
##   godot res://tests/shot_runner.tscn

var _dir := ""
var _trace_f: FileAccess


func _ready() -> void:
	_dir = OS.get_environment("DYNAMAN_SHOT_DIR")
	if _dir.is_empty():
		_dir = OS.get_user_data_dir() + "/shots"
	DirAccess.make_dir_recursive_absolute(_dir)
	_trace_f = FileAccess.open(_dir + "/trace.txt", FileAccess.WRITE)
	# The tour window usually opens unfocused; compositors throttle
	# occluded vsynced windows and every timer dilates. Never block on swap.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_run()


## Crash/kill-proof checkpoint log (stdout is lost when timeout kills us).
func _trace(msg: String) -> void:
	if _trace_f != null:
		_trace_f.store_line("%d %s" % [Time.get_ticks_msec(), msg])
		_trace_f.flush()


func _run() -> void:
	# --- splash + menu ---
	var startup: Node = (load("res://scenes/startup.tscn") as PackedScene).instantiate()
	add_child(startup)
	await _wait(1.3)
	await _shot("01_splash")
	await _wait(2.6)
	await _shot("02_menu")
	# Battle setup panel: focus starts on START; STORY MODE sits between
	# it and SETUP since v7.1, so two DOWNs now.
	_key(KEY_DOWN)
	await _wait(0.15)
	_key(KEY_DOWN)
	await _wait(0.1)
	_key(KEY_ENTER)
	await _wait(0.35)
	await _shot("03_setup")
	# Colour-map picker: open it for P2 exactly as a swatch click would.
	startup.call("_open_color_picker", 1)
	await _wait(0.4)
	await _shot("03b_colorpicker")
	(startup.get("_color_pop") as PopupPanel).hide()
	await _wait(0.2)
	_key(KEY_ESCAPE)
	await _wait(0.25)
	startup.queue_free()
	await _wait(0.3)

	# --- battle: 2 players, a few balloons, default arena. Best-of with
	# --- target 2 so the tour can show BOTH victory splashes; P1 cycled
	# --- to green to demo the tint system (green flames too).
	Settings.players = 2
	Settings.enemy_count = 3
	Settings.wins_target = 2
	Settings.win_margin = 1
	Settings.set_player_color(0, Color("38b048"))  # green
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await _wait(1.1)
	await _shot("04_countdown")
	# Wait for PLAY (state enum: COUNTDOWN=0, PLAY=1).
	var guard := 0
	while int(main.get("state")) != 1 and guard < 40:
		await _wait(0.2)
		guard += 1
	# Carve a guaranteed-safe demo pocket mid-board (random bricks would
	# otherwise trap P1 next to its own bomb), teleport P1 there, bomb,
	# and run around the corner.
	var arena_obj: RefCounted = main.get("arena")
	var bs: Dictionary = main.get("brick_sprites")
	for c: Vector2i in [Vector2i(5, 5), Vector2i(6, 5), Vector2i(7, 5),
			Vector2i(7, 6), Vector2i(5, 6), Vector2i(4, 5)]:
		if int(arena_obj.call("cell", c.x, c.y)) == 2:  # BRICK
			arena_obj.call("burn", c)
		if bs.has(c):
			(bs[c] as Sprite2D).queue_free()
			bs.erase(c)
	var players: Array = main.get("players")
	players[0].pos = Vector2(5, 5)
	players[0].node.position = main.call("_to_px", Vector2(5, 5))
	# Relocate balloons to the far right edge so none can wander into the
	# demo pocket and photobomb (or kill) P1 during the ~2 s window.
	var floors: Array = arena_obj.call("floor_cells")
	var spots: Array = []
	for fc in floors:
		if (fc as Vector2i).x >= 11:
			spots.append(fc)
	var enemies_arr: Array = main.get("enemies")
	for j in enemies_arr.size():
		if j < spots.size():
			enemies_arr[j].pos = Vector2(spots[j] as Vector2i)
	await _wait(0.15)
	# Deterministic bomb: tap SPACE until the bomb actually exists (input
	# lands on process ticks), then TELEPORT P1 to safety — timed walks
	# kept racing the fuse across runs.
	_key(KEY_SPACE)
	var bomb_guard := 0
	while (main.get("bombs") as Array).is_empty() and bomb_guard < 20:
		await _wait(0.05)
		_key(KEY_SPACE)
		bomb_guard += 1
	_trace("bomb placed, tries=%d" % bomb_guard)
	players[0].pos = Vector2(7, 6)
	players[0].node.position = main.call("_to_px", Vector2(7, 6))
	# The ticking player-tinted bomb, mid-heartbeat with fuse sparks.
	await _wait(0.5)
	await _shot("04b_bomb_ticking")
	var bombs: Array = main.get("bombs")
	if not bombs.is_empty():
		bombs[0]["t"] = 0.3
	# Trigger the shots off the flames dict itself; two frames for choice.
	var flame_guard := 0
	while (main.get("flames") as Dictionary).is_empty() and flame_guard < 60:
		await _wait(0.03)
		flame_guard += 1
	_trace("flames live, polls=%d" % flame_guard)
	await _shot("05_explosion")
	await _wait(0.12)
	await _shot("05b_explosion")
	await _wait(0.8)
	await _shot("06_battle")
	# Pause overlay.
	_key(KEY_ESCAPE)
	await _wait(0.3)
	await _shot("07_pause")
	_key(KEY_ESCAPE)
	await _wait(0.25)
	# Round-win splash (medal): fell P2; P1 is 1 of 2 needed wins.
	main.call("_kill_player", players[1])
	_trace("kill1 done")
	await _wait(1.4)  # mid medal-bounce
	_trace("pre shot08 state=%s" % str(main.get("state")))
	await _shot("08_match_win")
	_trace("post shot08")
	# Next round starts after the splash; wait for PLAY again.
	guard = 0
	while int(main.get("state")) != 1 and guard < 60:
		await _wait(0.2)
		guard += 1
	_trace("poll done state=%s guard=%d" % [str(main.get("state")), guard])
	# Battle-win splash (trophy): second win takes the battle.
	main.call("_kill_player", players[1])
	_trace("kill2 done")
	await _wait(1.4)
	_trace("pre shot09 state=%s" % str(main.get("state")))
	await _shot("09_battle_win")
	_trace("post shot09")
	# Restore defaults the tour changed.
	Settings.wins_target = 3
	Settings.set_player_color(0, Color("f2f2f6"))  # back to white
	print("shots saved to ", _dir)
	get_tree().quit()


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _key(keycode: Key) -> void:
	_key_down(keycode)
	_key_up(keycode)


func _key_down(keycode: Key) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	ev.keycode = keycode
	ev.pressed = true
	Input.parse_input_event(ev)


func _key_up(keycode: Key) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	ev.keycode = keycode
	ev.pressed = false
	Input.parse_input_event(ev)


## Hold a key for a duration (movement needs held keys, not taps).
func _hold(keycode: Key, sec: float) -> void:
	_key_down(keycode)
	await _wait(sec)
	_key_up(keycode)


func _shot(name_base: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [_dir, name_base])
