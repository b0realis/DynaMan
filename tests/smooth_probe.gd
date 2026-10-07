extends Node
## Smooth probe (v12.6): the smoothness/robustness campaign's behaviours
## in a real battle — "GO!" hands over control at once; a burning brick
## hides its item until the burn is over; PAUSE freezes the world (the
## tree pauses, flames keep their time) and resume picks up cleanly; a
## mid-round window resize re-fits the board; a pad dropping out pauses
## the round; the round-end card waits for the deciding blast; leaving
## never hands the menu a paused tree. Restores what it changes.
##   godot --headless res://tests/smooth_probe.tscn
var main: Node
func _wait(sec: float) -> void:
	var t := 0.0
	while t < sec:
		await get_tree().process_frame
		t += get_process_delta_time()
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # keeps running through the PAUSE it tests
	var keep := {"p": Settings.players, "fill": Settings.fill_bots,
		"en": Settings.enemy_count}
	Settings.players = 2
	Settings.fill_bots = false
	Settings.enemy_count = 0
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	var fails := 0
	# GO! = go
	while int(main.get("state")) == 0:
		await get_tree().process_frame
	var go_ok: bool = (main.get("_banner") as Label).text == "GO!" and float(main.get("_count_t")) < 3.2
	print("GO! starts play: ", go_ok, " (count_t=%.2f)" % float(main.get("_count_t"))); fails += 0 if go_ok else 1
	# brick burn hides its item until the burn ends
	var arena: Arena = main.get("arena")
	var players: Array = main.get("players")
	players[0].pos = Vector2(1, 1)
	players[1].pos = Vector2(13, 11)
	arena._put(7, 5, Arena.FLOOR)
	arena._put(8, 5, Arena.BRICK)
	arena.hidden[Vector2i(8, 5)] = Arena.ITEM_FIRE
	main.call("_spawn_bomb", Vector2i(7, 5), -1, null, Color.WHITE, 1)
	for b in (main.get("bombs") as Array).duplicate():
		main.call("_detonate", b)
	var item_spr: Sprite2D = (main.get("item_sprites") as Dictionary).get(Vector2i(8, 5))
	var hidden_at_start := item_spr != null and not item_spr.visible
	# pause: the world freezes for a second of wall time
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_ESCAPE
	ev.keycode = KEY_ESCAPE
	ev.pressed = true
	Input.parse_input_event(ev)
	await _wait(0.1)
	var paused: bool = int(main.get("state")) == 4 and get_tree().paused
	var flames_before: int = (main.get("flames") as Dictionary).size()
	await _wait(1.0)
	var frozen: bool = (main.get("flames") as Dictionary).size() == flames_before and flames_before > 0 \
		and not item_spr.visible
	Input.parse_input_event(ev)    # resume
	await _wait(0.8)
	var resumed: bool = int(main.get("state")) == 1 and not get_tree().paused
	var revealed: bool = item_spr.visible and (main.get("flames") as Dictionary).is_empty()
	print("burn hides item=%s, pause freezes (tree paused=%s, flames kept=%s), resume=%s, item revealed after burn=%s"
		% [hidden_at_start, paused, frozen, resumed, revealed])
	fails += 0 if hidden_at_start and paused and frozen and resumed and revealed else 1
	# resize mid-round re-fits the board
	var cell0: float = main.get("cell_px")
	get_window().size = Vector2i(1280, 1000)
	await _wait(0.2)
	var k: float = (main as Node2D).scale.x
	var view := main.get_viewport().get_visible_rect().size
	var board_h: float = cell0 * arena.h * k
	var fits: bool = board_h <= view.y - 60.0 + 0.5 and k > 0.0
	print("resize: view=%s scale=%.3f board_h=%.0f fits=%s" % [view, k, board_h, fits]); fails += 0 if fits else 1
	get_window().size = Vector2i(1280, 720)
	await _wait(0.2)
	# a pad dropping out pauses the round
	Input.joy_connection_changed.emit(0, false)
	await _wait(0.1)
	var pad_pause: bool = int(main.get("state")) == 4
	print("pad drop pauses: ", pad_pause); fails += 0 if pad_pause else 1
	Input.parse_input_event(ev)
	await _wait(0.2)
	# the ceremony waits for the deciding blast
	players[0].pos = Vector2(1, 1)
	main.call("_kill_player", players[1])
	await _wait(0.3)
	var pending_ok: bool = (main.get("_cer_pending") as Callable).is_valid()
	await _wait(1.0)
	var shown: bool = not (main.get("_cer_pending") as Callable).is_valid()
	print("ceremony waits (pending at 0.3s=%s, shown by 1.3s=%s)" % [pending_ok, shown]); fails += 0 if pending_ok and shown else 1
	# leaving from pause never hands the menu a paused tree
	main.set("state", 4)
	await get_tree().process_frame
	main.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	print("tree unpaused after leaving: ", not get_tree().paused); fails += 0 if not get_tree().paused else 1
	Settings.players = keep["p"]
	Settings.fill_bots = keep["fill"]
	Settings.enemy_count = keep["en"]
	print("SMOOTH PROBE: " + ("PASS" if fails == 0 else "FAIL (%d)" % fails))
	get_tree().quit(0 if fails == 0 else 1)
