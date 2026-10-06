extends Node
## Dev one-shot: kill the solo player and screenshot the defeat splash
## (crying bomber + rain cloud). Prints the end state for sanity.
##   DYNAMAN_SHOT_DIR=/abs/path godot res://tests/defeat_shot.tscn

func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_run()


func _run() -> void:
	Settings.players = 1
	Settings.solo_bots = 0  # force the classic arcade mode
	Settings.enemy_count = 2
	Settings.arena_w = 15
	Settings.arena_h = 13
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	var guard := 0
	while int(main.get("state")) != 1 and guard < 60:
		await get_tree().create_timer(0.2).timeout
		guard += 1
	var players: Array = main.get("players")
	main.call("_kill_player", players[0])
	await get_tree().create_timer(1.6).timeout  # cloud lands, tears flow
	await RenderingServer.frame_post_draw
	var dir := OS.get_environment("DYNAMAN_SHOT_DIR")
	if dir.is_empty():
		dir = OS.get_user_data_dir()
	get_viewport().get_texture().get_image().save_png(dir + "/defeat.png")
	print("defeat shot saved, state=%d (3=BATTLE_END)" % int(main.get("state")))
	get_tree().quit()
