extends Node
## Dev one-shot: record the defeat ceremony — cloud bounces in, rain
## starts, shoulders heave, tears flow.
##   DYNAMAN_GIF_DIR=/abs/path godot res://tests/defeat_gif.tscn

func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_run()


func _run() -> void:
	Settings.players = 1
	Settings.enemy_count = 2
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
	var players: Array = main.get("players")
	main.call("_kill_player", players[0])
	await get_tree().create_timer(0.75).timeout  # death spin finishes
	Engine.max_fps = 30
	for i in 90:
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.resize(640, 360, Image.INTERPOLATE_BILINEAR)
		img.save_png("%s/d%03d.png" % [dir, i])
	Engine.max_fps = 0
	print("defeat frames done: ", dir)
	get_tree().quit()
