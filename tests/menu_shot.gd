extends Node
## Dev one-shot: open the BATTLE SETUP panel and screenshot it (the
## panel gained rows in v4.6 — this guards against overflow).
##   DYNAMAN_SHOT_DIR=/abs/path godot res://tests/menu_shot.tscn

func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_run()


func _run() -> void:
	var menu: Node = (load("res://scenes/startup.tscn") as PackedScene).instantiate()
	add_child(menu)
	await get_tree().create_timer(0.4).timeout
	menu.call("_end_splash", true)
	await get_tree().create_timer(0.3).timeout
	menu.call("_open_panel", menu.get("_setup_panel"))
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	var dir := OS.get_environment("DYNAMAN_SHOT_DIR")
	if dir.is_empty():
		dir = OS.get_user_data_dir()
	get_viewport().get_texture().get_image().save_png(dir + "/setup_panel.png")
	menu.call("_close_panel", menu.get("_setup_panel"))
	menu.call("_open_panel", menu.get("_options_panel"))
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir + "/options_panel.png")
	print("setup + options panel shots saved")
	get_tree().quit()
