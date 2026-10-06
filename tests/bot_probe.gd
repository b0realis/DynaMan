extends Node
## Bot-player probe (v4.6): the zero-human DEMO battle. Three bots on a
## classic arena must actually play — roam the grid and lay real bombs
## (owner >= 0) through the shared BomberBrain driver. Bots dying to
## each other's blasts is the game working, so the bar is: most bots
## traveled, and at least one bot bombed.
##   godot --headless res://tests/bot_probe.tscn

func _ready() -> void:
	_run()


func _run() -> void:
	var keep := {"players": Settings.players, "db": Settings.demo_bots,
		"aw": Settings.arena_w, "ah": Settings.arena_h,
		"enemies": Settings.enemy_count, "rt": Settings.round_time,
		"pr": Settings.pressure_on, "skill": Settings.bot_skill}
	Settings.players = 0  # demo: nobody at the keys
	Settings.bot_skill = "hard"   # the skill this probe was tuned on (v10.3)
	Settings.demo_bots = 3
	Settings.arena_w = 15
	Settings.arena_h = 13
	Settings.enemy_count = 0
	Settings.round_time = 300
	Settings.pressure_on = false
	Engine.time_scale = 2.5
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	var guard := 0
	while int(main.get("state")) != 1 and guard < 100:
		await get_tree().create_timer(0.2).timeout
		guard += 1
	var players: Array = main.get("players")
	if players.size() != 3:
		_restore(keep)
		print("BOT PROBE: expected 3 bots, got %d -> FAIL" % players.size())
		get_tree().quit(1)
		return
	var all_bots := true
	for p: Bomber in players:
		all_bots = all_bots and p.bot
	# Travel per bot while it lives (snapshot scoring, enemy_probe style).
	var travel: Array[float] = [0.0, 0.0, 0.0]
	var last: Array = [players[0].pos, players[1].pos, players[2].pos]
	var bot_bombs := {}
	for s in 200:  # up to 40 sim-seconds at time_scale 2.5
		await get_tree().create_timer(0.2).timeout
		if int(main.get("state")) != 1:
			break  # someone won the round — plenty of action happened
		for i in 3:
			var p: Bomber = players[i]
			if p.alive:
				travel[i] += (p.pos as Vector2).distance_to(last[i])
				last[i] = p.pos
		for b: Dictionary in main.get("bombs"):
			if int(b["owner"]) >= 0:
				bot_bombs[b["node"]] = true
	Engine.time_scale = 1.0
	_restore(keep)
	var movers := 0
	for i in 3:
		if travel[i] > 2.0:
			movers += 1
	var ok := all_bots and movers >= 2 and bot_bombs.size() >= 1
	print("BOT PROBE: allBots=%s movers=%d/3 travel=[%.1f %.1f %.1f] bombs=%d -> %s"
		% [all_bots, movers, travel[0], travel[1], travel[2],
		bot_bombs.size(), "PASS" if ok else "FAIL"])
	get_tree().quit(0 if ok else 1)


func _restore(keep: Dictionary) -> void:
	Settings.players = keep["players"]
	Settings.demo_bots = keep["db"]
	Settings.arena_w = keep["aw"]
	Settings.arena_h = keep["ah"]
	Settings.enemy_count = keep["enemies"]
	Settings.round_time = keep["rt"]
	Settings.pressure_on = keep["pr"]
	Settings.bot_skill = keep["skill"]
