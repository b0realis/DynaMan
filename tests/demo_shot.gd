extends Node
## Dev one-shot: a frame of the v4.6 zero-human DEMO battle mid-play.
##   DYNAMAN_SHOT_DIR=/abs/path godot res://tests/demo_shot.tscn

func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_run()


func _run() -> void:
	var keep := {"players": Settings.players, "db": Settings.demo_bots,
		"aw": Settings.arena_w, "ah": Settings.arena_h,
		"enemies": Settings.enemy_count, "skin": Settings.arena_skin,
		"rand": Settings.arena_random}
	# DYNAMAN_SKIN=volcano → shoot the demo in that tile skin (v4.8). A
	# forced skin must beat the per-round randomiser, else you shoot a
	# random skin instead of the one you asked for.
	var skin := OS.get_environment("DYNAMAN_SKIN")
	if not skin.is_empty():
		Settings.arena_skin = skin
		Settings.arena_random = false
	# DYNAMAN_BOMB=acme → and in that bomb style (v5.1).
	var keep_bomb := Settings.bomb_style
	var bstyle := OS.get_environment("DYNAMAN_BOMB")
	if not bstyle.is_empty():
		Settings.bomb_style = bstyle
	Settings.players = 0
	Settings.demo_bots = 4
	Settings.arena_w = 15
	Settings.arena_h = 13
	Settings.enemy_count = 2
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	var guard := 0
	while int(main.get("state")) != 1 and guard < 100:
		await get_tree().create_timer(0.2).timeout
		guard += 1
	await get_tree().create_timer(6.0).timeout  # let the bots brawl a bit
	await RenderingServer.frame_post_draw
	var dir := OS.get_environment("DYNAMAN_SHOT_DIR")
	if dir.is_empty():
		dir = OS.get_user_data_dir()
	get_viewport().get_texture().get_image().save_png(dir + "/demo_battle%s.png" % ("" if skin.is_empty() else "_" + skin))
	Settings.players = keep["players"]
	Settings.demo_bots = keep["db"]
	Settings.arena_w = keep["aw"]
	Settings.arena_h = keep["ah"]
	Settings.enemy_count = keep["enemies"]
	Settings.arena_skin = keep["skin"]
	Settings.arena_random = keep["rand"]
	Settings.bomb_style = keep_bomb
	print("demo battle shot saved, state=%d" % int(main.get("state")))
	get_tree().quit()
