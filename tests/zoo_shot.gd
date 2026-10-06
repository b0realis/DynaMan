extends Node
## Dev one-shot (v6.8): a staged arena with the three serpents mid-slither
## plus a few newcomers, for the family album.
##   DYNAMAN_SHOT_DIR=/abs/path godot res://tests/zoo_shot.tscn

func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_run()


func _run() -> void:
	var keep := {"players": Settings.players, "sb": Settings.solo_bots,
		"aw": Settings.arena_w, "ah": Settings.arena_h,
		"enemies": Settings.enemy_count, "bd": Settings.brick_density}
	Settings.players = 1
	Settings.solo_bots = 0
	Settings.arena_w = 21
	Settings.arena_h = 13
	Settings.enemy_count = 0
	Settings.brick_density = 0.15
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	var guard := 0
	while int(main.get("state")) != 1 and guard < 100:
		await get_tree().create_timer(0.2).timeout
		guard += 1
	var players: Array = main.get("players")
	players[0].pos = Vector2(1, 1)
	players[0].node.position = main.call("_to_px", Vector2(1, 1))
	for pair: Array in [["snake", Vector2i(5, 3)], ["dragon", Vector2i(11, 6)],
			["centipede", Vector2i(15, 9)], ["frog", Vector2i(3, 9)],
			["mimic", Vector2i(7, 11)], ["bull", Vector2i(17, 3)],
			["warlock", Vector2i(9, 1)], ["slime", Vector2i(13, 2)]]:
		main.call("_spawn_enemy_at", pair[0], pair[1])
	await get_tree().create_timer(4.0).timeout  # serpents stretch out
	await RenderingServer.frame_post_draw
	var dir := OS.get_environment("DYNAMAN_SHOT_DIR")
	if dir.is_empty():
		dir = OS.get_user_data_dir()
	get_viewport().get_texture().get_image().save_png(dir + "/zoo.png")
	print("zoo shot saved")
	Settings.players = keep["players"]
	Settings.solo_bots = keep["sb"]
	Settings.arena_w = keep["aw"]
	Settings.arena_h = keep["ah"]
	Settings.enemy_count = keep["enemies"]
	Settings.brick_density = keep["bd"]
	get_tree().quit()
