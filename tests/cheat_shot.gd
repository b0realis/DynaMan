extends Node
## Dev one-shot (v11.0): THE MEDICINE CABINET on camera — the secret
## panel with two bottles dosed, then a medicated battle wearing the
## Rx badge with X-RAY bricks aglow. Restores what it touches.
##   DYNAMAN_SHOT_DIR=/abs/path godot res://tests/cheat_shot.tscn

func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_run()


func _run() -> void:
	var dir := OS.get_environment("DYNAMAN_SHOT_DIR")
	if dir.is_empty():
		dir = OS.get_user_data_dir()
	var keep := {"players": Settings.players}
	# --- 1. the cabinet, two bottles dosed ------------------------------
	var menu: Node = (load("res://scenes/startup.tscn") as PackedScene).instantiate()
	add_child(menu)
	await get_tree().create_timer(0.4).timeout
	menu.call("_end_splash", true)
	await get_tree().create_timer(0.2).timeout
	Settings.cheats = {"deluxe": true, "xray": true}
	menu.call("_open_cabinet")
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir + "/medicine_cabinet.png")
	# --- 1b. cabinet closed: the corner pill on the bare menu -----------
	menu.call("_close_panel", menu.get("_cheat_panel"))
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir + "/menu_pill.png")
	menu.queue_free()
	await get_tree().process_frame
	# --- 2. a medicated battle: Rx badge + X-ray bricks -----------------
	Settings.players = 2
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().create_timer(3.6).timeout   # through the countdown
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir + "/medicated_battle.png")
	print("cheat shots saved")
	Settings.players = keep["players"]
	Settings.cheats.clear()
	Engine.time_scale = 1.0
	get_tree().quit()
