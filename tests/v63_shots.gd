extends Node
## Dev one-shot (v6.3): three captures — draw ceremony, blast-range
## hint, random-arena countdown note.
##   DYNAMAN_SHOT_DIR=/abs/path godot res://tests/v63_shots.tscn

var _dir := ""


func _ready() -> void:
	_dir = OS.get_environment("DYNAMAN_SHOT_DIR")
	if _dir.is_empty():
		_dir = OS.get_user_data_dir()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_run()


func _run() -> void:
	var keep := {"players": Settings.players, "sb": Settings.solo_bots,
		"enemies": Settings.enemy_count, "hint": Settings.blast_hint,
		"rand": Settings.arena_random}
	Settings.players = 2
	Settings.solo_bots = 0
	Settings.enemy_count = 0
	Settings.blast_hint = true
	Settings.arena_random = true
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	# 1. Countdown note (random arena announcement).
	await get_tree().create_timer(1.2).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_dir + "/random_note.png")
	var guard := 0
	while int(main.get("state")) != 1 and guard < 100:
		await get_tree().create_timer(0.2).timeout
		guard += 1
	# 2. Blast hint: two ticking bombs, danger tiles pulsing.
	var players: Array = main.get("players")
	players[0].pos = Vector2(-7, -7)
	players[1].pos = Vector2(-7, -7)
	var arena_obj: RefCounted = main.get("arena")
	var bs: Dictionary = main.get("brick_sprites")
	for c: Vector2i in [Vector2i(5, 6), Vector2i(6, 6), Vector2i(4, 6),
			Vector2i(5, 5), Vector2i(5, 7), Vector2i(9, 6), Vector2i(10, 6),
			Vector2i(8, 6), Vector2i(9, 5), Vector2i(9, 7)]:
		if int(arena_obj.call("cell", c.x, c.y)) == 2:
			arena_obj.call("burn", c)
		if bs.has(c):
			(bs[c] as Sprite2D).queue_free()
			bs.erase(c)
	main.call("_spawn_bomb", Vector2i(5, 6), 0, null, Settings.player_color(0), 3)
	main.call("_spawn_bomb", Vector2i(9, 6), 1, null, Settings.player_color(1), 3)
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_dir + "/blast_hint.png")
	# Defuse before they muddy the draw shot.
	for b: Dictionary in main.get("bombs"):
		b["t"] = 99.0
	# 3. Draw ceremony: both fall in the same instant.
	main.call("_kill_player", players[0])
	main.call("_kill_player", players[1])
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_dir + "/draw_ceremony.png")
	print("v6.3 shots saved")
	Settings.players = keep["players"]
	Settings.solo_bots = keep["sb"]
	Settings.enemy_count = keep["enemies"]
	Settings.blast_hint = keep["hint"]
	Settings.arena_random = keep["rand"]
	get_tree().quit()
