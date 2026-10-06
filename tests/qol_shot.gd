extends Node
## Dev one-shot (v10.0): the couch-QoL pass on camera — the CONTROLS
## rebind panel, and a PAUSED battle showing the quick options plus
## the optional player number tags. Restores settings it touches.
##   DYNAMAN_SHOT_DIR=/abs/path godot res://tests/qol_shot.tscn

func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_run()


func _run() -> void:
	var dir := OS.get_environment("DYNAMAN_SHOT_DIR")
	if dir.is_empty():
		dir = OS.get_user_data_dir()
	var keep := {"players": Settings.players, "tags": Settings.player_tags}
	# --- 1. the CONTROLS panel ------------------------------------------
	var menu: Node = (load("res://scenes/startup.tscn") as PackedScene).instantiate()
	add_child(menu)
	await get_tree().create_timer(0.4).timeout
	menu.call("_end_splash", true)
	await get_tree().create_timer(0.2).timeout
	menu.call("_open_panel", menu.get("_controls_panel"))
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir + "/controls_panel.png")
	menu.queue_free()
	await get_tree().process_frame
	# --- 2. paused battle: quick options + player tags ------------------
	Settings.players = 2
	Settings.player_tags = true
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().create_timer(3.6).timeout   # through the countdown
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_ESCAPE
	ev.keycode = KEY_ESCAPE
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir + "/pause_qol.png")
	print("qol shots saved")
	Settings.players = keep["players"]
	Settings.player_tags = keep["tags"]
	get_tree().quit()
