extends Node
## Feel probe (v11.7): core movement / blast / chain-sound rules the
## bug-hunt campaigns fixed, pinned so they stay fixed.
##  1. CORNER ASSIST — a bomber parked short of an opening (0.4 off the
##     cell centre, pillar ahead, open diagonal) must slide round the
##     pillar and walk on, in ALL FOUR directions. The center pull used
##     to cancel the assist exactly (v11.7), and left/up never reached
##     the assist branch at all (v11.8). KICK is checked the same way.
##  2. CHAIN (v12.1) — bomb A burns a brick hiding an item and lights
##     bomb B, whose ray points at that brick. B must go off a beat
##     LATER (propagation, not one frame), the burning brick must still
##     shield the item from B's ray, A plays the short hop and B — the
##     end of the chain — the full BOOM on the same voice.
##  3. SEPARATE BOMBS (v12.0) — two lone bombs ring on two voices at
##     once, each its full boom.
##  4. CHAIN DRAW (v12.2) — a chain whose first blast kills one player
##     and whose next link kills the other is a DRAW: the round waits
##     for the chain instead of crowning whoever died second.

func _ready() -> void:
	var keep := {"p": Settings.players, "fill": Settings.fill_bots,
		"en": Settings.enemy_count, "aw": Settings.arena_w,
		"ah": Settings.arena_h, "team": Settings.team_mode,
		"rnd": Settings.arena_random, "sfx": Settings.sfx_on,
		"vol": Settings.sfx_volume, "rev": Settings.revenge_mode}
	Settings.revenge_mode = false   # the draw check below needs plain deaths
	# Sound ON for the chain-sound checks: with the player's sfx off,
	# Sfx.play returns early and those checks could pass vacuously.
	Settings.sfx_on = true
	Settings.sfx_volume = 0.8
	Settings.players = 2
	Settings.fill_bots = false
	Settings.enemy_count = 0
	Settings.arena_w = 15
	Settings.arena_h = 13
	Settings.team_mode = 0
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	while int(main.get("state")) != 1:
		await get_tree().process_frame
	var arena: Arena = main.get("arena")
	var players: Array = main.get("players")
	var fails := 0

	# --- 1. corner assist, all four directions ---------------------------
	# Each case: start short of an opening (offset 0.4 off the cell
	# centre), the way ahead blocked by a pillar, the diagonal + side
	# cell open. v11.8: left/up never reached the assist branch at all.
	var p0: Bomber = players[0]
	var p1: Bomber = players[1]
	var corner_cases := [
		# [start, held action, opened cells, want-cell after the slide]
		[Vector2(1, 2.4), "p1_right", [Vector2i(1, 3), Vector2i(2, 3)], Vector2i(3, 3)],
		[Vector2(13, 2.4), "p1_left", [Vector2i(13, 3), Vector2i(12, 3)], Vector2i(11, 3)],
		[Vector2(2.4, 11), "p1_up", [Vector2i(3, 11), Vector2i(3, 10)], Vector2i(3, 9)],
		[Vector2(2.4, 1), "p1_down", [Vector2i(3, 1), Vector2i(3, 2)], Vector2i(3, 3)],
	]
	for cc: Array in corner_cases:
		var start: Vector2 = cc[0]
		var opened: Array = cc[2]
		var want: Vector2i = cc[3]
		arena._put(int(roundf(start.x)), int(roundf(start.y)), Arena.FLOOR)
		for c: Vector2i in opened + [want]:
			arena._put(c.x, c.y, Arena.FLOOR)
		p1.pos = Vector2(7, 7)
		p0.pos = start
		p0.move_dir = Vector2.ZERO
		Input.action_press(cc[1])
		await get_tree().create_timer(0.7).timeout
		Input.action_release(cc[1])
		var ok: bool = p0.pos.distance_to(Vector2(want)) < 0.9
		print("corner assist %s from %s: pos=%s (want near %s) -> %s"
			% [cc[1], start, p0.pos, want, "PASS" if ok else "FAIL"])
		if not ok:
			fails += 1

	# --- 1b. kick, all four directions -----------------------------------
	var hub := Vector2i(7, 5)
	for i in range(1, 6):
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var c := hub + d * i
			if arena.cell(c.x, c.y) != Arena.WALL:
				arena._put(c.x, c.y, Arena.FLOOR)
	arena._put(hub.x, hub.y, Arena.FLOOR)
	p0.kick = true
	for kc: Array in [[Vector2i(1, 0), "p1_right"], [Vector2i(-1, 0), "p1_left"],
			[Vector2i(0, 1), "p1_down"], [Vector2i(0, -1), "p1_up"]]:
		var d: Vector2i = kc[0]
		p0.pos = Vector2(hub)
		p0.move_dir = Vector2.ZERO
		p1.pos = Vector2(1, 11)
		main.call("_spawn_bomb", hub + d, -1, null, Color.WHITE, 1)
		var bomb: Dictionary = {}
		for b: Dictionary in main.get("bombs"):
			if b["cell"] == hub + d:
				bomb = b
		Input.action_press(kc[1])
		await get_tree().create_timer(0.25).timeout
		Input.action_release(kc[1])
		var moved: bool = bomb.has("slide") or bomb["cell"] != hub + d
		print("kick %s: bomb cell=%s slide=%s -> %s" % [kc[1], bomb["cell"],
			bomb.has("slide"), "PASS" if moved else "FAIL"])
		if not moved:
			fails += 1
		if (main.get("bombs") as Array).has(bomb):
			main.call("_defuse_bomb", bomb)
	p0.kick = false

	# --- 2. a propagating chain: shield, beats, finale ---------------------
	p0.pos = Vector2(1, 1)
	p0.vest_t = 0.0
	p1.pos = Vector2(13, 11)
	for c: Vector2i in [Vector2i(3, 5), Vector2i(4, 5)]:
		arena._put(c.x, c.y, Arena.FLOOR)
	arena._put(5, 5, Arena.BRICK)
	arena.hidden[Vector2i(5, 5)] = Arena.ITEM_FIRE
	(main.get("ground_items") as Dictionary).erase(Vector2i(5, 5))
	main.call("_spawn_bomb", Vector2i(4, 5), -1, null, Color.WHITE, 1)  # A
	main.call("_spawn_bomb", Vector2i(3, 5), -1, null, Color.WHITE, 3)  # B
	var bombs: Array = main.get("bombs")
	var bomb_a: Dictionary = {}
	for b: Dictionary in bombs:
		if b["cell"] == Vector2i(4, 5):
			bomb_a = b
	var boom_wav: AudioStreamWAV = Sfx.get("_streams")["boom"]
	var hop_wav: AudioStreamWAV = Sfx.get("_streams")["boom_hop"]
	var voices: Array = Sfx.get("_boom_players")
	var gap: float = main.get("CHAIN_GAP")
	main.call("_detonate", bomb_a)
	# PROPAGATION (v12.1): B is still on the board right after A, lit
	# for the next beat — and A's own beat, the short hop, is ringing
	# on the chain's voice.
	var bomb_b: Dictionary = {}
	for b: Dictionary in main.get("bombs"):
		if b["cell"] == Vector2i(3, 5):
			bomb_b = b
	var voice := -1
	var lit_ok := false
	if bomb_b.has("chain"):
		voice = int(bomb_b["chain"]["voice"])
		lit_ok = float(bomb_b["t"]) <= gap + 0.001 \
			and (voices[voice] as AudioStreamPlayer).playing \
			and (voices[voice] as AudioStreamPlayer).stream == hop_wav
	# Until B pops (capped at 2 s) — a fixed wait could flake on a hitch,
	# since main caps each frame's delta.
	var waited := 0.0
	while (main.get("bombs") as Array).has(bomb_b) and waited < 2.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	var kept: bool = (main.get("ground_items") as Dictionary).has(Vector2i(5, 5))
	var chained: bool = not (main.get("bombs") as Array).has(bomb_b)
	# B ended the chain: the full BOOM, on the same voice (cutting A's hop).
	var finale_ok: bool = voice >= 0 \
		and (voices[voice] as AudioStreamPlayer).playing \
		and (voices[voice] as AudioStreamPlayer).stream == boom_wav
	print("chain: B lit a beat later=%s, item kept=%s, B went off=%s, BOOM on the chain voice=%s -> %s"
		% [lit_ok, kept, chained, finale_ok,
		"PASS" if lit_ok and kept and chained and finale_ok else "FAIL"])
	if not (lit_ok and kept and chained and finale_ok):
		fails += 1

	# --- 3. separate bombs keep their own full boom ---------------------
	var hop_ok: bool = absf(hop_wav.get_length() - 0.11) < 0.01
	var started_before: Array = (Sfx.get("_boom_started") as Array).duplicate()
	for c: Vector2i in [Vector2i(1, 11), Vector2i(13, 1)]:
		arena._put(c.x, c.y, Arena.FLOOR)
		main.call("_spawn_bomb", c, -1, null, Color.WHITE, 1)
	for c: Vector2i in [Vector2i(1, 11), Vector2i(13, 1)]:
		for b: Dictionary in (main.get("bombs") as Array).duplicate():
			if b["cell"] == c:
				main.call("_detonate", b)
	var fresh := 0
	var started_now: Array = Sfx.get("_boom_started")
	for i in voices.size():
		var vp2: AudioStreamPlayer = voices[i]
		if started_now[i] != started_before[i] and vp2.playing and vp2.stream == boom_wav:
			fresh += 1
	var overlap_ok := fresh == 2
	print("separate bombs: voices=%d (want 2), hop=%s -> %s" % [fresh, hop_ok,
		"PASS" if overlap_ok and hop_ok else "FAIL"])
	if not (overlap_ok and hop_ok):
		fails += 1

	# --- 4. a chain that takes BOTH players is a draw (v12.2) ------------
	# P0 in bomb A's ray, P1 only in its lit partner B's: A kills P0 a beat
	# before B kills P1 — the round must wait for the chain and call it a
	# DRAW (v12.1 handed P1 the round, standing in B's fire).
	for x in range(1, 14):
		arena._put(x, 9, Arena.FLOOR)
	for b: Dictionary in (main.get("bombs") as Array).duplicate():
		main.call("_defuse_bomb", b)
	await get_tree().create_timer(0.6).timeout   # let earlier fire die down
	p0.pos = Vector2(3, 9)
	p1.pos = Vector2(10, 9)
	p0.vest_t = 0.0
	p1.vest_t = 0.0
	main.call("_spawn_bomb", Vector2i(5, 9), -1, null, Color.WHITE, 2)  # A
	main.call("_spawn_bomb", Vector2i(7, 9), -1, null, Color.WHITE, 3)  # B
	for b: Dictionary in (main.get("bombs") as Array).duplicate():
		if b["cell"] == Vector2i(5, 9):
			main.call("_detonate", b)
	var w := 0.0
	while int(main.get("state")) == 1 and w < 2.0:
		await get_tree().process_frame
		w += get_process_delta_time()
	var draw_ok: bool = not p0.alive and not p1.alive \
		and p0.wins == 0 and p1.wins == 0 and int(main.get("state")) != 1
	print("chain draw: p0 dead=%s p1 dead=%s wins=%d/%d state=%d -> %s" % [
		not p0.alive, not p1.alive, p0.wins, p1.wins, int(main.get("state")),
		"PASS" if draw_ok else "FAIL"])
	if not draw_ok:
		fails += 1

	print("FEEL PROBE: " + ("PASS" if fails == 0 else "FAIL (%d)" % fails))
	Settings.players = keep["p"]
	Settings.fill_bots = keep["fill"]
	Settings.enemy_count = keep["en"]
	Settings.arena_w = keep["aw"]
	Settings.arena_h = keep["ah"]
	Settings.team_mode = keep["team"]
	Settings.arena_random = keep["rnd"]
	Settings.revenge_mode = keep["rev"]
	Settings.sfx_on = keep["sfx"]
	Settings.sfx_volume = keep["vol"]
	get_tree().quit(0 if fails == 0 else 1)
