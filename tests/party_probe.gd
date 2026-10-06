extends Node
## Party probe (v10.2): TEAMS must end the round when one team stands
## (crediting BOTH members in lockstep), and REVENGE must put the
## fallen on the rim with a working bomb lob. Restores every setting
## it touches.
##   godot --headless res://tests/party_probe.tscn

func _ready() -> void:
	_run()


func _run() -> void:
	var keep := {"players": Settings.players, "fill": Settings.fill_bots,
		"team": Settings.team_mode, "rev": Settings.revenge_mode,
		"skill": Settings.bot_skill}
	# ---- teams: P1+P3 vs P2+P4; kill team B -> team A takes the round.
	Settings.players = 2
	Settings.fill_bots = true      # 2 humans + 2 bots = the four
	Settings.team_mode = 2
	Settings.revenge_mode = false
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().create_timer(0.8).timeout
	var players: Array = main.get("players")
	var teams_ok: bool = players.size() == 4 \
		and players[0].team == 0 and players[1].team == 1 \
		and players[2].team == 0 and players[3].team == 1
	main.call("_kill_player", players[1])
	main.call("_kill_player", players[3])
	main.call("_check_round_end")
	await get_tree().create_timer(0.2).timeout
	teams_ok = teams_ok and players[0].wins == 1 and players[2].wins == 1 \
		and players[1].wins == 0 and players[3].wins == 0
	main.queue_free()
	await get_tree().process_frame
	# ---- revenge: the fallen ride the rim and can lob a real bomb.
	Settings.team_mode = 0
	Settings.revenge_mode = true
	Settings.fill_bots = false
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().create_timer(0.8).timeout
	players = main.get("players")
	main.call("_kill_player", players[1])
	await get_tree().create_timer(0.2).timeout
	var rim_ok: bool = players[1].rim \
		and is_instance_valid(players[1].rim_node)
	players[1].rim_cd = 0.0
	main.call("_rim_throw", players[1])
	var lobbed := false
	for b: Dictionary in (main.get("bombs") as Array):
		if int(b["owner"]) == 1:
			lobbed = true
	rim_ok = rim_ok and lobbed
	main.queue_free()
	await get_tree().process_frame
	Settings.players = keep["players"]
	Settings.fill_bots = keep["fill"]
	Settings.team_mode = keep["team"]
	Settings.revenge_mode = keep["rev"]
	Settings.bot_skill = keep["skill"]
	var ok := teams_ok and rim_ok
	print("PARTY PROBE: teams=%s revenge=%s -> %s"
		% [teams_ok, rim_ok, "PASS" if ok else "FAIL"])
	get_tree().quit(0 if ok else 1)
