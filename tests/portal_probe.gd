extends Node
## Solo exit-portal probe (v3.9), end to end: with zero monsters the
## door is open from the start; burn the portal brick, step in, and
## the escape sequence must carry the game to BATTLE_END.
##   godot --headless res://tests/portal_probe.tscn

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
	Settings.enemy_count = 0
	Settings.round_time = 300
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	var guard := 0
	while int(main.get("state")) != 1 and guard < 100:
		await get_tree().create_timer(0.2).timeout
		guard += 1
	var cell: Vector2i = main.get("portal_cell")
	if cell == Vector2i(-99, -99):
		print("PORTAL PROBE: no portal cell picked -> FAIL")
		_restore(keep)
		get_tree().quit(1)
		return
	main.call("_burn_brick", cell)
	await get_tree().create_timer(0.5).timeout
	var revealed: bool = main.get("_portal_spr") != null
	var open: bool = main.get("_portal_open")
	# Walk-in: teleport the player onto the doorway.
	var players: Array = main.get("players")
	players[0].pos = Vector2(cell)
	var saw_exit := false
	var final_state := -1
	for s in 30:  # up to 6 s for the escape animation + splash
		await get_tree().create_timer(0.2).timeout
		var st := int(main.get("state"))
		if st == 5:  # State.EXIT
			saw_exit = true
		if st == 3:  # State.BATTLE_END
			final_state = st
			break
	_restore(keep)
	var ok := revealed and open and saw_exit and final_state == 3
	print("PORTAL PROBE: revealed=%s open=%s sawExit=%s battleEnd=%s -> %s"
		% [revealed, open, saw_exit, final_state == 3, "PASS" if ok else "FAIL"])
	get_tree().quit(0 if ok else 1)


func _restore(keep: Dictionary) -> void:
	Settings.players = keep["players"]
	Settings.arena_w = keep["aw"]
	Settings.arena_h = keep["ah"]
	Settings.enemy_count = keep["enemies"]
	Settings.round_time = keep["rt"]
	Settings.solo_bots = keep["sb"]
