extends Node
## Menagerie probe (v6.8): force-spawn every non-bomber type at once,
## run the zoo for ~25 sim-seconds and demand that (a) nothing crashes,
## (b) the free-roaming types actually roam, (c) serpents drag real
## bodies behind a moving head. Mimic is exempt from the travel bar
## (it is SUPPOSED to sit still in costume with nobody nearby).
##   godot --headless res://tests/menagerie_probe.tscn

const TYPES := ["balloon", "slime", "snail", "chomper", "bees", "frog",
	"mole", "saw", "ghost", "elemental", "freezer", "thief", "muncher",
	"snake", "mimic", "warlock", "bull", "centipede", "dragon"]

func _ready() -> void:
	_run()


func _run() -> void:
	var keep := {"players": Settings.players, "sb": Settings.solo_bots,
		"aw": Settings.arena_w, "ah": Settings.arena_h,
		"enemies": Settings.enemy_count, "rt": Settings.round_time,
		"bd": Settings.brick_density}
	Settings.players = 1
	Settings.solo_bots = 0
	Settings.arena_w = 31
	Settings.arena_h = 25
	Settings.enemy_count = 0
	Settings.round_time = 300
	# Nearly open arena: at default density many spawn cells are sealed
	# brick pockets and a walled-in monster reads as a false FAIL.
	Settings.brick_density = 0.1
	Engine.time_scale = 2.5
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	var guard := 0
	while int(main.get("state")) != 1 and guard < 100:
		await get_tree().create_timer(0.2).timeout
		guard += 1
	var players: Array = main.get("players")
	players[0].pos = Vector2(-7, -7)
	# Seed the whole roster on spread-out floor cells.
	var arena_obj: RefCounted = main.get("arena")
	var free: Array = arena_obj.call("floor_cells")
	var spawned: Array = []
	var step := maxi(free.size() / TYPES.size(), 1)
	for i in TYPES.size():
		var c: Vector2i = free[mini(i * step, free.size() - 1)]
		spawned.append(main.call("_spawn_enemy_at", TYPES[i], c))
	var start: Array[Vector2] = []
	var travel: Array[float] = []
	for e: Monster in spawned:
		start.append(e.pos)
		travel.append(0.0)
	var last := start.duplicate()
	var enemies: Array = main.get("enemies")
	for s in 50:  # ~25 sim-seconds
		await get_tree().create_timer(0.2).timeout
		if int(main.get("state")) != 1:
			break
		players[0].pos = Vector2(-7, -7)  # stay unreachable
		for i in spawned.size():
			var e: Monster = spawned[i]
			if enemies.has(e):
				travel[i] += (e.pos as Vector2).distance_to(last[i])
				last[i] = e.pos
	Engine.time_scale = 1.0
	var movers := 0
	var idle: Array[String] = []
	for i in TYPES.size():
		if TYPES[i] == "mimic":
			continue  # in costume by design
		if travel[i] > 1.0 or not enemies.has(spawned[i]):
			movers += 1
		else:
			idle.append(TYPES[i])
	var serp_ok := true
	for i in TYPES.size():
		if TYPES[i] in ["snake", "centipede", "dragon"] \
				and enemies.has(spawned[i]):
			var e: Monster = spawned[i]
			if e.body.is_empty() or travel[i] < 1.0:
				serp_ok = false
	_restore(keep)
	var ok := movers >= 16 and serp_ok
	print("MENAGERIE PROBE: movers=%d/18 serpents=%s idle=%s -> %s"
		% [movers, serp_ok, idle, "PASS" if ok else "FAIL"])
	get_tree().quit(0 if ok else 1)


func _restore(keep: Dictionary) -> void:
	Settings.players = keep["players"]
	Settings.solo_bots = keep["sb"]
	Settings.arena_w = keep["aw"]
	Settings.arena_h = keep["ah"]
	Settings.enemy_count = keep["enemies"]
	Settings.round_time = keep["rt"]
	Settings.brick_density = keep["bd"]
