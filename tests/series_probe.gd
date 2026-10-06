extends Node
## Series probe (v11.5): 1 human + 2 bots, wins_target 3, margin 1.
## The human wins three rounds — rounds 1-2 must land in ROUND_END
## and round 3 in BATTLE_END — and an impatient R during each round
## ceremony must skip to the NEXT round with the tally INTACT (it
## used to full-rematch and silently wipe the series: the "rounds to
## win is not respected" playtest bug).

func _ready() -> void:
	var keep := {"p": Settings.players, "s": Settings.solo_bots,
		"wt": Settings.wins_target, "wm": Settings.win_margin,
		"r": Settings.revenge_mode, "t": Settings.team_mode}
	Settings.players = 1
	Settings.solo_bots = 2
	Settings.wins_target = 3
	Settings.win_margin = 1
	Settings.revenge_mode = false
	Settings.team_mode = 0
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	var fails := 0
	for round_i in 3:
		# ride out the countdown
		while int(main.get("state")) == 0:
			await get_tree().process_frame
		await get_tree().create_timer(0.5).timeout
		for p in main.get("players"):
			if p.bot and p.alive:
				main.call("_kill_player", p)
		await get_tree().create_timer(0.3).timeout
		var st := int(main.get("state"))
		var wins: int = main.get("players")[0].wins
		var want := 2 if round_i < 2 else 3
		print("round %d: state=%d (want %d) p0.wins=%d" % [round_i + 1, st, want, wins])
		if st != want or wins != round_i + 1:
			fails += 1
		if round_i < 2:
			# the impatient skip (v11.5): R during ROUND_END must jump
			# to the next round with the tally INTACT, not full-rematch
			var ev := InputEventKey.new()
			ev.physical_keycode = KEY_R
			ev.keycode = KEY_R
			ev.pressed = true
			Input.parse_input_event(ev)
			await get_tree().create_timer(0.2).timeout
			var st2 := int(main.get("state"))
			var wins2: int = main.get("players")[0].wins
			print("  after R: state=%d (want 0) p0.wins=%d (want %d)" % [st2, wins2, round_i + 1])
			if st2 != 0 or wins2 != round_i + 1:
				fails += 1
	print("SERIES PROBE: " + ("PASS" if fails == 0 else "FAIL (%d)" % fails))
	Settings.players = keep["p"]
	Settings.solo_bots = keep["s"]
	Settings.wins_target = keep["wt"]
	Settings.win_margin = keep["wm"]
	Settings.revenge_mode = keep["r"]
	Settings.team_mode = keep["t"]
	get_tree().quit(0 if fails == 0 else 1)
