extends Node
## Dev one-shot (v6.1): the hold-H quick-help overlay, forced visible.
##   DYNAMAN_SHOT_DIR=/abs/path godot res://tests/help_shot.tscn

func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_run()


func _run() -> void:
	var keep := {"players": Settings.players, "sb": Settings.solo_bots,
		"enemies": Settings.enemy_count,
		"bs": [Settings.player_bomb_style(0), Settings.player_bomb_style(1)]}
	Settings.players = 2
	Settings.solo_bots = 0
	Settings.enemy_count = 2
	# Distinct seat costumes so the per-seat bomb icons (v9.0) show.
	Settings.set_player_bomb_style(0, "potion")
	Settings.set_player_bomb_style(1, "naval")
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	var guard := 0
	while int(main.get("state")) != 1 and guard < 60:
		await get_tree().create_timer(0.2).timeout
		guard += 1
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_H
	ev.keycode = KEY_H
	ev.pressed = true
	Input.parse_input_event(ev)  # hold H
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	var dir := OS.get_environment("DYNAMAN_SHOT_DIR")
	if dir.is_empty():
		dir = OS.get_user_data_dir()
	get_viewport().get_texture().get_image().save_png(dir + "/help_overlay.png")
	print("help overlay shot saved")
	Settings.players = keep["players"]
	Settings.solo_bots = keep["sb"]
	Settings.enemy_count = keep["enemies"]
	Settings.set_player_bomb_style(0, keep["bs"][0])
	Settings.set_player_bomb_style(1, keep["bs"][1])
	get_tree().quit()
