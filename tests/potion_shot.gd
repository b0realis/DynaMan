extends Node
## Dev one-shot (v6.0): catch the potion mid-uncork — bottle open,
## cork airborne, bubbles frantic — half a second before the boom.
##   DYNAMAN_SHOT_DIR=/abs/path godot res://tests/potion_shot.tscn

func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_run()


func _run() -> void:
	var keep := {"players": Settings.players, "sb": Settings.solo_bots,
		"aw": Settings.arena_w, "ah": Settings.arena_h,
		"enemies": Settings.enemy_count, "bomb": Settings.bomb_style}
	Settings.players = 2
	Settings.solo_bots = 0
	Settings.arena_w = 15
	Settings.arena_h = 13
	Settings.enemy_count = 0
	Settings.bomb_style = "potion"
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	var guard := 0
	while int(main.get("state")) != 1 and guard < 100:
		await get_tree().create_timer(0.2).timeout
		guard += 1
	var players: Array = main.get("players")
	players[0].pos = Vector2(-7, -7)  # park the humans off-grid
	players[1].pos = Vector2(-7, -7)
	main.call("_spawn_bomb", Vector2i(7, 6), 0, null,
		Settings.player_color(0), 2)
	# Catch it right after the cork lets go (uncork fires at t<0.5).
	await get_tree().create_timer(2.75).timeout
	await RenderingServer.frame_post_draw
	var dir := OS.get_environment("DYNAMAN_SHOT_DIR")
	if dir.is_empty():
		dir = OS.get_user_data_dir()
	get_viewport().get_texture().get_image().save_png(dir + "/potion_pop.png")
	print("potion pop shot saved")
	_restore(keep)
	get_tree().quit()


func _restore(keep: Dictionary) -> void:
	Settings.players = keep["players"]
	Settings.solo_bots = keep["sb"]
	Settings.arena_w = keep["aw"]
	Settings.arena_h = keep["ah"]
	Settings.enemy_count = keep["enemies"]
	Settings.bomb_style = keep["bomb"]
