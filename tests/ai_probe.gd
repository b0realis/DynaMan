extends Node
## Bomber-MONSTER probe (v3.9): solo battle, human idle. One enemy is
## force-converted to the bomber mini-boss; it must roam and lay real
## bombs (owner -1) via the planner brain, and never sit still.
##   godot --headless res://tests/ai_probe.tscn

func _ready() -> void:
	_run()


func _run() -> void:
	var keep := {"players": Settings.players, "aw": Settings.arena_w,
		"ah": Settings.arena_h, "enemies": Settings.enemy_count,
		"rt": Settings.round_time, "sb": Settings.solo_bots}
	Settings.players = 1
	Settings.solo_bots = 0  # force the classic arcade mode
	Settings.arena_w = 15
	Settings.arena_h = 13
	Settings.enemy_count = 4
	Settings.round_time = 300
	Engine.time_scale = 2.5
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	var guard := 0
	while int(main.get("state")) != 1 and guard < 100:
		await get_tree().create_timer(0.2).timeout
		guard += 1
	var enemies: Array = main.get("enemies")
	if enemies.is_empty():
		print("AI PROBE: no enemies spawned — cannot test")
		Engine.time_scale = 1.0
		_restore(keep)
		get_tree().quit(1)
		return
	# Deterministic mini-boss: convert the roomiest enemy into the
	# bomber (mirrors the spawn rule — cramped cells never host one).
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
	boss.dir = Vector2i.ZERO  # force a fresh decision
	# Terrain-prisoner check: a pocket sealed by pure WALLS has no brick
	# to bomb — nothing testable there (same exemption as enemy_probe).
	var start := Vector2i(boss.pos.round())
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	var qi := 0
	var any_brick := false
	while qi < queue.size():
		var c := queue[qi]
		qi += 1
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q := c + d
			var v := int(arena_obj.call("cell", q.x, q.y))
			if v == 2:
				any_brick = true
			elif v == 0 and not seen.has(q):
				seen[q] = true
				queue.append(q)
	if not any_brick:
		Engine.time_scale = 1.0
		_restore(keep)
		print("AI PROBE (bomber monster): boss walled in by PURE STONE — nothing to test -> PASS")
		get_tree().quit(0)
		return
	var bombs_seen := {}
	var travel := 0.0
	var last: Vector2 = boss.pos
	for s in 400:  # up to 80 sim-seconds (timers run on scaled time)
		await get_tree().create_timer(0.2).timeout
		if int(main.get("state")) != 1:
			break  # someone died / round over — evaluate what we saw
		if not enemies.has(boss):
			break  # the boss burned — evaluate what it did while alive
		for b: Dictionary in main.get("bombs"):
			# Only the boss under test: a naturally spawned bomber
			# monster on the same board used to earn it a free pass.
			if int(b["owner"]) == -1 and b["owner_ref"] == boss:
				bombs_seen[b["node"]] = true
		travel += boss.pos.distance_to(last)
		last = boss.pos
	Engine.time_scale = 1.0
	_restore(keep)
	var placed := bombs_seen.size()
	var died := not enemies.has(boss)
	# Free boss: must bomb repeatedly and roam. Caged boss: at least
	# the kamikaze counts — it bombed rather than rot.
	var ok := (placed >= 2 and travel > 5.0) or (placed >= 1 and died)
	print("AI PROBE (bomber monster): bombs=%d travel=%.1f died=%s -> %s"
		% [placed, travel, died, "PASS" if ok else "FAIL"])
	get_tree().quit(0 if ok else 1)


func _restore(keep: Dictionary) -> void:
	Settings.players = keep["players"]
	Settings.arena_w = keep["aw"]
	Settings.arena_h = keep["ah"]
	Settings.enemy_count = keep["enemies"]
	Settings.round_time = keep["rt"]
	Settings.solo_bots = keep["sb"]
