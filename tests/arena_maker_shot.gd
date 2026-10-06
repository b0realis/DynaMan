extends Node
## Dev one-shot (v9.1): the ARENA MAKER on its bench (a seeded roll),
## then a battle actually WEARING a saved user theme. Backs up and
## restores arenas.cfg and the arena_skin setting.
##   DYNAMAN_SHOT_DIR=/abs/path godot res://tests/arena_maker_shot.tscn

func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_run()


func _run() -> void:
	var dir := OS.get_environment("DYNAMAN_SHOT_DIR")
	if dir.is_empty():
		dir = OS.get_user_data_dir()
	var bak: PackedByteArray = []
	var had := FileAccess.file_exists(TileArt.USER_PATH)
	if had:
		bak = FileAccess.get_file_as_bytes(TileArt.USER_PATH)
	var keep_skin := Settings.arena_skin
	var keep_players := Settings.players
	# --- 1. the maker, opened on a seeded roll ---------------------------
	var menu: Node = (load("res://scenes/startup.tscn") as PackedScene).instantiate()
	add_child(menu)
	await get_tree().create_timer(0.4).timeout
	menu.call("_end_splash", true)
	await get_tree().create_timer(0.2).timeout
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	menu.set("_maker_recipe", TileArt.random_recipe(rng))
	menu.set("_maker_edit_id", "")
	(menu.get("_maker_refresh") as Callable).call()
	menu.call("_open_panel", menu.get("_maker_panel"))
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir + "/arena_maker.png")
	# --- 2. a battle wearing the saved theme -----------------------------
	var id := TileArt.save_user(menu.get("_maker_recipe"))
	menu.queue_free()
	await get_tree().process_frame
	Settings.players = 2
	Settings.arena_skin = id
	Settings.arena_random = false
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().create_timer(3.6).timeout   # through the countdown
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir + "/arena_user_battle.png")
	print("arena maker shots saved (theme '%s')" % TileArt.label(id))
	main.queue_free()
	await get_tree().process_frame
	# Restore the register + settings byte-for-byte.
	TileArt.delete_user(id)
	Settings.arena_skin = keep_skin
	Settings.players = keep_players
	if had:
		var f := FileAccess.open(TileArt.USER_PATH, FileAccess.WRITE)
		f.store_buffer(bak)
		f.close()
	elif FileAccess.file_exists(TileArt.USER_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TileArt.USER_PATH))
	get_tree().quit()
