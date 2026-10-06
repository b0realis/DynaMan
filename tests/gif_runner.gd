extends Node
## Chain-explosion GIF capture (dev tool). Engineers a corridor with three
## of P1's bombs, shortens only the FIRST fuse (the other two prove chains
## fire the same instant), and records ~2 s of frames at 30 fps.
##   DYNAMAN_GIF_DIR=/abs/path godot res://tests/gif_runner.tscn

var _dir := ""


func _ready() -> void:
	_dir = OS.get_environment("DYNAMAN_GIF_DIR")
	if _dir.is_empty():
		_dir = OS.get_user_data_dir() + "/gif"
	DirAccess.make_dir_recursive_absolute(_dir)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_run()


func _run() -> void:
	Settings.players = 2
	Settings.enemy_count = 0
	Settings.set_player_color(0, Color("38b048"))  # green
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	var guard := 0
	while int(main.get("state")) != 1 and guard < 60:
		await _wait(0.2)
		guard += 1
	# Carve a corridor along row 5 plus the escape cell.
	var arena_obj: RefCounted = main.get("arena")
	var bs: Dictionary = main.get("brick_sprites")
	var cells: Array[Vector2i] = []
	for x in range(4, 13):
		cells.append(Vector2i(x, 5))
	cells.append(Vector2i(11, 6))
	for c: Vector2i in cells:
		if int(arena_obj.call("cell", c.x, c.y)) == 2:
			arena_obj.call("burn", c)
		if bs.has(c):
			(bs[c] as Sprite2D).queue_free()
			bs.erase(c)
	# Three bombs from P1 (boosted: 3 bombs, flame 3) along the corridor.
	var players: Array = main.get("players")
	players[0].bombs_max = 3
	players[0]["flame"] = 3
	for x in [5, 7, 9]:
		players[0].pos = Vector2(x, 5)
		players[0].node.position = main.call("_to_px", Vector2(x, 5))
		_key(KEY_SPACE)
		await _wait(0.15)
	players[0].pos = Vector2(11, 6)
	players[0].node.position = main.call("_to_px", Vector2(11, 6))
	await _wait(0.1)
	var bombs: Array = main.get("bombs")
	if bombs.size() >= 3:
		bombs[0]["t"] = 0.5
		bombs[1]["t"] = 3.0  # long fuses: only the CHAIN can fire these now
		bombs[2]["t"] = 3.0
	# Record: ticking trio -> chain -> fire -> embers/smoke, 30 fps.
	Engine.max_fps = 30
	for i in 62:
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.resize(640, 360, Image.INTERPOLATE_BILINEAR)
		img.save_png("%s/f%03d.png" % [_dir, i])
	Engine.max_fps = 0
	print("frames done: ", _dir)
	get_tree().quit()


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _key(keycode: Key) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	ev.keycode = keycode
	ev.pressed = true
	Input.parse_input_event(ev)
	var up := ev.duplicate() as InputEventKey
	up.pressed = false
	Input.parse_input_event(up)
