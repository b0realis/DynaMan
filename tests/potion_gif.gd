extends Node
## Potion-bomb showcase GIF (dev tool, v6.0): one potion placed center
## stage — lazy bubbles, accelerating boil, cork pop, froth, boom —
## captured at 30 fps, cropped around the bottle.
##   DYNAMAN_GIF_DIR=/abs/path godot res://tests/potion_gif.tscn

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
	Settings.solo_bots = 0
	Settings.enemy_count = 0
	Settings.arena_w = 15
	Settings.arena_h = 13
	Settings.bomb_style = "potion"
	Settings.set_player_color(0, Color("38b048"))  # green brew
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	var guard := 0
	while int(main.get("state")) != 1 and guard < 60:
		await get_tree().create_timer(0.2).timeout
		guard += 1
	var players: Array = main.get("players")
	players[0].pos = Vector2(-7, -7)
	players[1].pos = Vector2(-7, -7)
	# Clear the stage: the center cell must be FLOOR or the spawn is
	# refused; open the blast arms too so the boom has room to bloom.
	var arena_obj: RefCounted = main.get("arena")
	var bs: Dictionary = main.get("brick_sprites")
	for c: Vector2i in [Vector2i(7, 6), Vector2i(6, 6), Vector2i(8, 6),
			Vector2i(7, 5), Vector2i(7, 7)]:
		if int(arena_obj.call("cell", c.x, c.y)) == 2:
			arena_obj.call("burn", c)
		if bs.has(c):
			(bs[c] as Sprite2D).queue_free()
			bs.erase(c)
	main.call("_spawn_bomb", Vector2i(7, 6), 0, null,
		Settings.player_color(0), 2)
	# Crop window centered on the bottle (a little headroom for the cork).
	var px: Vector2 = main.call("_to_px", Vector2(7, 6))
	var rect := Rect2i(int(px.x) - 190, int(px.y) - 230, 380, 380)
	Engine.max_fps = 30
	for i in 112:  # ~3.7 s: full fuse + cork pop + boom + embers
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img = img.get_region(rect)
		img.save_png("%s/f%03d.png" % [_dir, i])
	Engine.max_fps = 0
	print("frames done: ", _dir)
	get_tree().quit()
