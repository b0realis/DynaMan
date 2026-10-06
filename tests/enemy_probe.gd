extends Node
## Regression probe: enemies must actually travel (the v1.0-v3.3 snapback
## bug made them vibrate in place). Fails loudly if they don't move.
func _ready() -> void:
	_run()

func _run() -> void:
	# Self-sufficient: force a testable configuration, restore after.
	# players=2 keeps the spawn table to balloons/chompers — no bomber
	# boss, so nothing bombs a fellow monster mid-probe (a mid-sample
	# death used to shrink the live array under our feet, crash the
	# scoring loop out of bounds, and hang the run without quitting).
	var keep_enemies := Settings.enemy_count
	var keep_players := Settings.players
	# The board itself is pinned too (v11.7): a player's saved 9x9 at
	# max brick density could crowd every spawn out, and fill_bots would
	# seat bombing bots — this probe measures MONSTER travel only.
	var keep_board := {"aw": Settings.arena_w, "ah": Settings.arena_h,
		"bd": Settings.brick_density, "fill": Settings.fill_bots,
		"team": Settings.team_mode}
	Settings.players = 2
	Settings.arena_w = 15
	Settings.arena_h = 13
	Settings.brick_density = 0.75
	Settings.fill_bots = false
	Settings.team_mode = 0
	if Settings.enemy_count < 3:
		Settings.enemy_count = 4
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	var guard := 0
	while int(main.get("state")) != 1 and guard < 60:
		await get_tree().create_timer(0.2).timeout
		guard += 1
	var enemies: Array = main.get("enemies")
	if enemies.is_empty():
		# With the board pinned above, no enemies is a spawner bug —
		# not a skip that run_all.sh would report as a pass.
		print("PROBE FAIL: no enemies spawned on a pinned 15x13 board")
		Settings.enemy_count = keep_enemies
		Settings.players = keep_players
		_restore_board(keep_board)
		get_tree().quit(1)
		return
	# Park the players OFF-GRID: idle players at their spawns get
	# touch-killed by wandering enemies, the round restarts, and the
	# live array refills with strangers (that once scored as 0/0).
	var players: Array = main.get("players")
	for p: Bomber in players:
		p.pos = Vector2(-7, -7)
	# Score a SNAPSHOT of the current monsters, not the live array.
	var subjects: Array = enemies.duplicate()
	# Cumulative travel, not net displacement: enemies legitimately pace
	# inside small brick pockets, so sample often and sum the deltas.
	# Tracked BY DICT IDENTITY, never by index into the live array — an
	# enemy dying mid-sample must not shift our bookkeeping.
	# Parallel arrays indexed by the SNAPSHOT (never the live array).
	# NOTE: enemy dicts can't be dictionary keys here — GDScript hashes
	# dict keys by CONTENT, and these mutate every frame.
	var travel: Array[float] = []
	var last: Array = []
	for e: Monster in subjects:
		travel.append(0.0)
		last.append(e.pos)
	for s in 16:
		await get_tree().create_timer(0.25).timeout
		for p: Bomber in players:
			p.pos = Vector2(-7, -7)  # keep them unreachable
		for i in subjects.size():
			var e: Monster = subjects[i]
			if enemies.has(e):  # skip any that somehow died
				travel[i] += e.pos.distance_to(last[i])
				last[i] = e.pos
	# Enemies sealed inside brick pockets (no open neighbor) are terrain
	# victims, not AI bugs — only free, still-living enemies must move.
	var arena_obj: RefCounted = main.get("arena")
	var moved := 0
	var required := 0
	for i in subjects.size():
		var e: Monster = subjects[i]
		if not enemies.has(e):
			continue  # died mid-window — can't judge its terrain now
		var c := Vector2i(e.pos.round())
		var open := 0
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if int(arena_obj.call("cell", c.x + d.x, c.y + d.y)) == 0:
				open += 1
		if open == 0 and travel[i] < 0.1:
			continue  # legitimately walled in
		required += 1
		if travel[i] > 2.0:
			moved += 1
	Settings.enemy_count = keep_enemies
	Settings.players = keep_players
	_restore_board(keep_board)
	print("PROBE: %d/%d free enemies traveled >2 cells (path) in 4s" % [moved, required])
	get_tree().quit(0 if moved == required else 1)


func _restore_board(k: Dictionary) -> void:
	Settings.arena_w = k["aw"]
	Settings.arena_h = k["ah"]
	Settings.brick_density = k["bd"]
	Settings.fill_bots = k["fill"]
	Settings.team_mode = k["team"]
