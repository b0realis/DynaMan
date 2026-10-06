extends Node
## Dev tool: fine-grained post-mortem of the bomber monster's death.

var _log: Array[String] = []

func _ready() -> void:
	_run()


func _run() -> void:
	Settings.players = 1
	Settings.solo_bots = 0  # force the classic arcade mode
	Settings.arena_w = 15
	Settings.arena_h = 13
	Settings.enemy_count = 4
	Settings.round_time = 300
	Engine.time_scale = 2.5  # match ai_probe — chasing a scale-dependent bug
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	var guard := 0
	while int(main.get("state")) != 1 and guard < 100:
		await get_tree().create_timer(0.2).timeout
		guard += 1
	var enemies: Array = main.get("enemies")
	var arena_obj: RefCounted = main.get("arena")
	var boss: Monster = enemies[0]
	var best_open := -1
	for e: Monster in enemies:
		var c := Vector2i(e.pos.round())
		var open := 0
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if int(arena_obj.call("cell", c.x + d.x, c.y + d.y)) == 0:
				open += 1
		if open > best_open:
			best_open = open
			boss = e
	boss.type = "bomber"
	boss.col = Color("d84040")
	boss.dir = Vector2i.ZERO
	for s in 3000:
		await get_tree().create_timer(0.05).timeout
		if int(main.get("state")) != 1 or not enemies.has(boss):
			_log.append("=== BOSS GONE (state=%d) ===" % int(main.get("state")))
			break
		var binfo := ""
		for b: Dictionary in main.get("bombs"):
			binfo += " b%s t=%.2f" % [b["cell"], b["t"]]
		var fl: Dictionary = main.get("flames")
		var cur := Vector2i(boss.pos.round())
		_log.append("%4d pos=(%.2f,%.2f) dir=%s dest=%s inFlame=%s%s"
			% [s, boss.pos.x, boss.pos.y,
			boss.dir, boss.dest, fl.has(cur), binfo])
	print("=== last 45 samples ===")
	for line in _log.slice(maxi(0, _log.size() - 45)):
		print(line)
	get_tree().quit(0)
