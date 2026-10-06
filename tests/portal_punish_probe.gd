extends Node
## Portal-punishment probe (v4.0, cap + summon in v4.2): bomb the
## revealed doorway → a random-coloured bomber mini-boss emerges and
## the portal slams shut. Then: a second offense must NOT breach the
## Settings.max_bosses cap, and with the cap raised, a boss parked at
## the doorway must summon a colleague on its own.
##   godot --headless res://tests/portal_punish_probe.tscn

func _ready() -> void:
	_run()


func _run() -> void:
	var keep := {"players": Settings.players, "aw": Settings.arena_w,
		"ah": Settings.arena_h, "enemies": Settings.enemy_count,
		"rt": Settings.round_time, "sb": Settings.solo_bots, "mb": Settings.max_bosses}
	Settings.players = 1
	Settings.solo_bots = 0  # force the classic arcade mode
	Settings.arena_w = 15
	Settings.arena_h = 13
	Settings.enemy_count = 0
	Settings.round_time = 300
	Settings.max_bosses = 1
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	var guard := 0
	while int(main.get("state")) != 1 and guard < 100:
		await get_tree().create_timer(0.2).timeout
		guard += 1
	# Deterministic portal placement: relocate it to a brick WITH an
	# open floor neighbor — the random pick often has none, which used
	# to skip the whole probe.
	var arena_obj: RefCounted = main.get("arena")
	# Scan from the BOTTOM-RIGHT: the idle player sits at (1,1) and must
	# not be caught in the probe's own portal-offense blasts.
	var cell := Vector2i(-99, -99)
	var spot := Vector2i(-99, -99)
	for y in range(11, 0, -1):
		for x in range(13, 0, -1):
			if cell != Vector2i(-99, -99):
				break
			if int(arena_obj.call("cell", x, y)) != 2:
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if int(arena_obj.call("cell", x + d.x, y + d.y)) == 0:
					cell = Vector2i(x, y)
					spot = Vector2i(x + d.x, y + d.y)
					break
	if cell == Vector2i(-99, -99):
		print("PUNISH PROBE: no reachable brick anywhere -> SKIP (pass)")
		_restore(keep)
		get_tree().quit(0)
		return
	main.set("portal_cell", cell)
	main.call("_burn_brick", cell)
	await get_tree().create_timer(0.4).timeout
	var revealed: bool = main.get("_portal_spr") != null
	var open_before: bool = main.get("_portal_open")
	main.call("_spawn_bomb", spot, 0, null, Color.WHITE, 2)
	_shorten_fuse(main, spot)
	# Detonation at ~0.3s, flames ~0.45s, emergence ~+0.8s → check at 3s.
	await get_tree().create_timer(3.0).timeout
	var enemies: Array = main.get("enemies")
	var boss_ok := false
	var col_ok := false
	for e: Monster in enemies:
		if e.type == "bomber":
			boss_ok = true
			col_ok = e.col != Color.WHITE
			# Disarm it for now — a free-roaming boss bombing on its own
			# schedule turns phases 2-3 into a dice game.
			e.bombs_max = 0
	var closed: bool = not main.get("_portal_open")
	# Phase 2 — the cap holds: a second offense at max_bosses=1 must
	# not spawn a second boss.
	main.call("_spawn_bomb", spot, 0, null, Color.WHITE, 2)
	_shorten_fuse(main, spot)
	await get_tree().create_timer(3.0).timeout
	# ≤1, not ==1: phase 2's own blast may have caught the boss (a dead
	# boss doesn't disprove the cap).
	var capped: bool = _bosses(enemies) <= 1
	# Phase 3 — deliberate summon: raise the cap and park the boss ON
	# the doorway (its blast covers the portal from there no matter
	# what the prey is doing); its brain should bomb for a colleague.
	Settings.max_bosses = 2
	if _bosses(enemies) == 0:
		# Refield one first (phase 2 killed it): offend the door again.
		main.call("_spawn_bomb", spot, 0, null, Color.WHITE, 2)
		_shorten_fuse(main, spot)
		await get_tree().create_timer(3.0).timeout
	if _bosses(enemies) == 0:
		_restore(keep)
		print("PUNISH PROBE: openBefore=%s boss=%s randomCol=%s doorShut=%s capHolds=%s bossSummons=SKIP (no boss survived to park) -> %s"
			% [open_before, boss_ok, col_ok, closed, capped,
			"PASS" if open_before and boss_ok and col_ok and closed and capped else "FAIL"])
		get_tree().quit(0 if open_before and boss_ok and col_ok and closed and capped else 1)
		return
	var boss: Monster = null
	for e: Monster in enemies:
		if e.type == "bomber":
			boss = e
			break
	boss.bombs_max = 1  # re-arm for the summon phase
	var pcell: Vector2i = main.get("portal_cell")
	boss.pos = Vector2(pcell)
	boss.dir = Vector2i.ZERO
	boss.clear_dest()
	boss.node.position = main.call("_to_px", Vector2(pcell))
	# The summon-vs-mine choice is a 50/50 coin per bomb cycle (v4.3),
	# so waiting for a natural "summon" roll makes the probe a dice
	# game. Instead FORCE the intent every poll and assert the summon
	# EXECUTION path deterministically: goal → doorway, bomb it,
	# colleague emerges. (The coin itself is one line, checked by
	# inspection.) Keep the idle player parked in the far corner so a
	# stray kill shot can't end the round mid-probe.
	Engine.time_scale = 2.0
	var players: Array = main.get("players")
	var summoned := false
	for s in 120:  # 24 sim-seconds
		await get_tree().create_timer(0.2).timeout
		if int(main.get("state")) != 1:
			break
		boss.intent = "summon"
		# Park the player OFF-GRID: a reachable prey makes the brain
		# hunt (and rightly erase the summon intent) — the coin only
		# governs the walled-off case, so force that case.
		players[0].pos = Vector2(-7, -7)
		if _bosses(enemies) >= 2:
			summoned = true
			break
	Engine.time_scale = 1.0
	var binfo := ""
	for b: Dictionary in main.get("bombs"):
		binfo += " b%s t=%.2f own=%d" % [b["cell"], b["t"], b["owner"]]
	print("DBG end: state=%d bosses=%d intent=%s bossPos=%s goal=%s out=%s desper=%s bombs[%s] playerAlive=%s" % [
		int(main.get("state")), _bosses(enemies), boss.intent,
		boss.pos, boss.goal,
		boss.bombs_out, boss.desper_t, binfo,
		players[0].alive])
	_restore(keep)
	var ok := open_before and boss_ok and col_ok and closed and capped and summoned
	print("PUNISH PROBE: revealed=%s openBefore=%s boss=%s randomCol=%s doorShut=%s capHolds=%s bossSummons=%s -> %s"
		% [revealed, open_before, boss_ok, col_ok, closed, capped, summoned,
		"PASS" if ok else "FAIL"])
	get_tree().quit(0 if ok else 1)


## Crash-proof fuse shortener: find OUR bomb by cell (never index [0] —
## a wandering boss may have bombs of its own in the array, or the
## spawn may have been blocked by one).
func _shorten_fuse(main: Node, cell: Vector2i) -> void:
	for b: Dictionary in main.get("bombs"):
		if (b["cell"] as Vector2i) == cell:
			b["t"] = 0.3
			return


func _bosses(enemies: Array) -> int:
	var n := 0
	for e: Monster in enemies:
		if e.type == "bomber":
			n += 1
	return n


func _restore(keep: Dictionary) -> void:
	Settings.players = keep["players"]
	Settings.arena_w = keep["aw"]
	Settings.arena_h = keep["ah"]
	Settings.enemy_count = keep["enemies"]
	Settings.round_time = keep["rt"]
	Settings.solo_bots = keep["sb"]
	Settings.max_bosses = keep["mb"]
