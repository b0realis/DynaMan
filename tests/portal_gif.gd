extends Node
## Dev one-shot: capture the solo exit-portal sequence — reveal, open
## sparkles, player steps in, spiral-shrink escape, victory splash.
##   DYNAMAN_GIF_DIR=/abs/path godot res://tests/portal_gif.tscn

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
	await get_tree().create_timer(0.9).timeout
	var players: Array = main.get("players")
	Engine.max_fps = 30
	for i in 80:
		if i == 12:  # step into the doorway mid-recording
			players[0].pos = Vector2(cell)
			players[0].node.position = main.call("_to_px", Vector2(cell))
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.resize(640, 360, Image.INTERPOLATE_BILINEAR)
		img.save_png("%s/p%03d.png" % [dir, i])
	Engine.max_fps = 0
	print("portal frames done: ", dir)
	get_tree().quit()
