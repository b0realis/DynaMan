extends Node
## Dev tool: per-bot state timeline for the demo battle (v4.6).

func _ready() -> void:
	_run()


func _run() -> void:
	Settings.players = 0
	Settings.demo_bots = 3
	Settings.arena_w = 15
	Settings.arena_h = 13
	Settings.enemy_count = 0
	Settings.round_time = 300
	Engine.time_scale = 2.5
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	var guard := 0
	while int(main.get("state")) != 1 and guard < 100:
		await get_tree().create_timer(0.2).timeout
		guard += 1
	var players: Array = main.get("players")
	main.get("_brain").bot_trace = true
	for s in 40:
		await get_tree().create_timer(0.25).timeout
		if int(main.get("state")) != 1:
			print("state=%d — stopped" % int(main.get("state")))
			break
		var line := "s%02d" % s
		for b: Dictionary in main.get("bombs"):
			line += " B%s" % b["cell"]
		for p: Bomber in players:
			line += " | a=%s pos=(%.1f,%.1f) dir=%s goal=%s out=%d" % [
				p.alive, p.pos.x, p.pos.y, p.bot_dir, p.bot_goal, p.bombs_out]
		print(line)
	get_tree().quit(0)
