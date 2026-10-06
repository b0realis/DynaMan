extends Node
## Fill-empty-seats probe (v7.6): with Settings.fill_bots on, a 2-human
## battle must field 4 bombers (2 human + 2 bot) and a 3-human battle 4
## (3 human + 1 bot); humans take the first slots, bots the tail. With it
## off, 2 humans stay 2. Snapshots/restores the real config either way.
##   godot --headless res://tests/fill_bots_probe.tscn

func _ready() -> void:
	_run()


func _run() -> void:
	var keep := {"players": Settings.players, "fill": Settings.fill_bots,
		"aw": Settings.arena_w, "ah": Settings.arena_h,
		"enemies": Settings.enemy_count, "rt": Settings.round_time,
		"pr": Settings.pressure_on, "skill": Settings.bot_skill}
	Settings.arena_w = 15
	Settings.arena_h = 13
	Settings.enemy_count = 0
	Settings.round_time = 300
	Settings.pressure_on = false

	var cases := [
		{"humans": 2, "fill": true, "total": 4, "bots": 2},
		{"humans": 3, "fill": true, "total": 4, "bots": 1},
		{"humans": 2, "fill": false, "total": 2, "bots": 0},
		{"humans": 4, "fill": true, "total": 4, "bots": 0},  # already full
	]
	var all_ok := true
	var report: Array = []
	for c: Dictionary in cases:
		var res := await _spawn(int(c["humans"]), bool(c["fill"]))
		var ok: bool = res.size() == int(c["total"]) \
			and _count_bots(res) == int(c["bots"]) \
			and _humans_first(res, int(c["humans"]))
		all_ok = all_ok and ok
		report.append("%dp fill=%s -> %d bombers (%d bot) %s"
			% [int(c["humans"]), c["fill"], res.size(), _count_bots(res),
			"ok" if ok else "FAIL"])

	_restore(keep)
	print("FILL BOTS PROBE: %s -> %s"
		% [" | ".join(report), "PASS" if all_ok else "FAIL"])
	get_tree().quit(0 if all_ok else 1)


## Instantiate a battle with the given roster, let it reach PLAY, and
## return a snapshot of its bomber list (freed before the next case so
## the two mains never coexist).
func _spawn(humans: int, fill: bool) -> Array:
	Settings.bot_skill = "hard"   # the skill this probe was tuned on (v10.3)
	Settings.players = humans
	Settings.fill_bots = fill
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	var guard := 0
	while int(main.get("state")) != 1 and guard < 60:
		await get_tree().create_timer(0.1).timeout
		guard += 1
	var out: Array = []
	for p: Bomber in main.get("players"):
		out.append(p.bot)
	main.queue_free()
	await get_tree().process_frame
	return out


func _count_bots(roster: Array) -> int:
	var n := 0
	for is_bot: bool in roster:
		if is_bot:
			n += 1
	return n


## Humans must own the first `humans` slots, bots the rest.
func _humans_first(roster: Array, humans: int) -> bool:
	for i in roster.size():
		if bool(roster[i]) != (i >= humans):
			return false
	return true


func _restore(keep: Dictionary) -> void:
	Settings.players = keep["players"]
	Settings.fill_bots = keep["fill"]
	Settings.arena_w = keep["aw"]
	Settings.arena_h = keep["ah"]
	Settings.enemy_count = keep["enemies"]
	Settings.round_time = keep["rt"]
	Settings.pressure_on = keep["pr"]
	Settings.bot_skill = keep["skill"]
