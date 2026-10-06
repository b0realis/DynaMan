extends Node
## Dev one-shot (v10.2): the party features on camera — a four-bomber
## TEAMS round (tags on, team letters everywhere) with one fallen
## bomber riding the REVENGE rim, bomb freshly lobbed. Restores every
## setting it touches.
##   DYNAMAN_SHOT_DIR=/abs/path godot res://tests/party_shot.tscn

func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_run()


func _run() -> void:
	var dir := OS.get_environment("DYNAMAN_SHOT_DIR")
	if dir.is_empty():
		dir = OS.get_user_data_dir()
	var keep := {"players": Settings.players, "fill": Settings.fill_bots,
		"team": Settings.team_mode, "rev": Settings.revenge_mode,
		"tags": Settings.player_tags}
	Settings.players = 2
	Settings.fill_bots = true
	Settings.team_mode = 1
	Settings.revenge_mode = true
	Settings.player_tags = true
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().create_timer(3.6).timeout   # through the countdown
	var players: Array = main.get("players")
	main.call("_kill_player", players[3])
	await get_tree().create_timer(1.0).timeout   # death anim, rim pop-in
	players[3].rim_cd = 0.0
	main.call("_rim_throw", players[3])
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir + "/party_battle.png")
	print("party shot saved")
	Settings.players = keep["players"]
	Settings.fill_bots = keep["fill"]
	Settings.team_mode = keep["team"]
	Settings.revenge_mode = keep["rev"]
	Settings.player_tags = keep["tags"]
	get_tree().quit()
