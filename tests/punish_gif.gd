extends Node
## Dev one-shot: capture the portal-punishment sequence — bomb the
## revealed doorway, blast, then the random-coloured mini-boss storms
## out with its spawn burst and the door slams shut.
##   DYNAMAN_GIF_DIR=/abs/path godot res://tests/punish_gif.tscn

func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_run()


func _run() -> void:
	Settings.players = 1
	Settings.enemy_count = 0
	Settings.arena_w = 15
	Settings.arena_h = 13
	var dir := OS.get_environment("DYNAMAN_GIF_DIR")
	if dir.is_empty():
		dir = OS.get_user_data_dir() + "/gif"
	DirAccess.make_dir_recursive_absolute(dir)
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	var guard := 0
	while int(main.get("state")) != 1 and guard < 60:
		await get_tree().create_timer(0.2).timeout
		guard += 1
	var cell: Vector2i = main.get("portal_cell")
	main.call("_burn_brick", cell)
	await get_tree().create_timer(0.8).timeout
	var arena_obj: RefCounted = main.get("arena")
	var spot := cell
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var q: Vector2i = cell + d
		if int(arena_obj.call("cell", q.x, q.y)) == 0:
			spot = q
			break
	main.call("_spawn_bomb", spot, 0, null, Color("f2f2f6"), 2)
	((main.get("bombs") as Array)[0] as Dictionary)["t"] = 0.6
	Engine.max_fps = 30
	for i in 90:
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.resize(640, 360, Image.INTERPOLATE_BILINEAR)
		img.save_png("%s/x%03d.png" % [dir, i])
	Engine.max_fps = 0
	print("punish frames done: ", dir)
	get_tree().quit()
