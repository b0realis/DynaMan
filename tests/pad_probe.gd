extends Node
## Pad probe (v12.5): the CONTROLS → GAMEPADS screen driven by synthetic
## pad events — CLAIM a pad for a player, remap a bomb to a shoulder
## button and to a trigger, remap a system button and get refused on a
## clash, d-pad refused, ESC backs out without closing the panel, an
## unanswered capture times out, the dead-zone slider reaches the
## InputMap — and then a real battle: only the CLAIMED pad's NEW bomb
## button drops a bomb. Restores every setting it touches.
##   godot --headless res://tests/pad_probe.tscn
var sc: Node


func _pad(device: int, button: int) -> void:
	for pressed in [true, false]:
		var ev := InputEventJoypadButton.new()
		ev.device = device
		ev.button_index = button
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await get_tree().process_frame
func _trigger(device: int, axis: int, v: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.device = device
	ev.axis = axis
	ev.axis_value = v
	Input.parse_input_event(ev)
	await get_tree().process_frame
func _press(key: String) -> void:
	(sc.get("_pad_btns")[key] as Button).pressed.emit()
	await get_tree().process_frame
func _status() -> String:
	return (sc.get("_pad_msg") as Label).text

func _btn(dev: int, b: int) -> void:
	for pr in [true, false]:
		var ev := InputEventJoypadButton.new()
		ev.device = dev
		ev.button_index = b
		ev.pressed = pr
		Input.parse_input_event(ev)
		await get_tree().process_frame
		await get_tree().process_frame


func _ready() -> void:
	var keep := {"p": Settings.players, "fill": Settings.fill_bots,
		"en": Settings.enemy_count}
	# The player's own pad tables, restored at the end (run alone, this
	# probe used to leave them at factory).
	var keep_pads := [Settings._pad_device.duplicate(), Settings._pad_bomb.duplicate(),
		Settings._pad_system.duplicate(), Settings._stick_deadzone]
	var fails := 0
	Settings.reset_pads()
	Settings.skip_splash_once = true
	sc = (load("res://scenes/startup.tscn") as PackedScene).instantiate()
	add_child(sc)
	for i in 10:
		await get_tree().process_frame
	sc.call("_open_panel", sc.get("_controls_panel"))
	await get_tree().process_frame
	# 1. claim: P2 claims pad device 3
	await _press("claim:1")
	await _pad(3, JOY_BUTTON_X)
	var ok1: bool = Settings.pad_device(1) == 3 and _status().contains("pad 4 now drives P2")
	print("claim -> ", ok1, "  ", _status()); fails += 0 if ok1 else 1
	# 2. bomb remap to RB, then to RT (trigger)
	await _press("bomb:0")
	await _pad(0, JOY_BUTTON_RIGHT_SHOULDER)
	var ok2: bool = Settings.pad_bomb(0) == JOY_BUTTON_RIGHT_SHOULDER \
		and (sc.get("_pad_btns")["bomb:0"] as Button).text == "BOMB: RB"
	await _press("bomb:2")
	await _trigger(0, JOY_AXIS_TRIGGER_RIGHT, 0.9)
	await _trigger(0, JOY_AXIS_TRIGGER_RIGHT, 0.0)
	ok2 = ok2 and Settings.pad_bomb(2) == Settings.PAD_TRIGGER + JOY_AXIS_TRIGGER_RIGHT
	print("bomb RB + RT -> ", ok2, "  ", _status()); fails += 0 if ok2 else 1
	# 3. system remap: pause -> B ; refusal: rematch -> RB (P1 bombs with it)
	await _press("sys:pause")
	await _pad(0, JOY_BUTTON_B)
	var ok3: bool = Settings.pad_system("pause") == JOY_BUTTON_B
	await _press("sys:restart")
	await _pad(0, JOY_BUTTON_RIGHT_SHOULDER)
	ok3 = ok3 and Settings.pad_system("restart") == JOY_BUTTON_Y and _status().contains("bombs")
	print("system + refusal -> ", ok3, "  ", _status()); fails += 0 if ok3 else 1
	# 4. ESC cancels; the armed capture swallowed pad A (no click-through)
	var panel_vis_before: bool = (sc.get("_controls_panel") as Control).visible
	await _press("bomb:3")
	await _pad(0, JOY_BUTTON_DPAD_DOWN)    # d-pad while armed: refused, capture ends
	var dpad_refused: bool = _status().contains("d-pad") and Settings.pad_bomb(3) == JOY_BUTTON_A
	await _press("bomb:3")
	var esc := InputEventKey.new()
	esc.physical_keycode = KEY_ESCAPE
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	Input.parse_input_event(esc)
	await get_tree().process_frame
	var ok4: bool = dpad_refused and _status().contains("kept the old one") \
		and str(sc.get("_pad_capture")) == "" \
		and (sc.get("_controls_panel") as Control).visible == panel_vis_before
	print("d-pad refusal + ESC cancel (panel still open) -> ", ok4, "  ", _status()); fails += 0 if ok4 else 1
	# 5. timeout
	await _press("bomb:3")
	await get_tree().create_timer(6.5).timeout
	var ok5: bool = str(sc.get("_pad_capture")) == "" and _status().contains("no button pressed")
	print("timeout -> ", ok5); fails += 0 if ok5 else 1
	# 6. dead zone slider reaches the InputMap
	(sc.get("_deadzone_slider") as HSlider).value = 0.35
	await get_tree().process_frame
	var ok6: bool = is_equal_approx(InputMap.action_get_deadzone("p3_down"), 0.35)
	print("dead zone slider -> ", ok6); fails += 0 if ok6 else 1
	sc.queue_free()
	# --- the remap in a real battle ---------------------------------------
	Settings.players = 2
	Settings.fill_bots = false
	Settings.enemy_count = 0
	Settings.reset_pads()
	Settings.claim_pad(0, 1)                         # pad 2 drives P1
	Settings.set_pad_bomb(0, JOY_BUTTON_RIGHT_SHOULDER)
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	while int(main.get("state")) != 1:
		await get_tree().process_frame
	var n0: int = (main.get("bombs") as Array).size()
	await _btn(1, JOY_BUTTON_A)                      # the old bomb button
	var n1: int = (main.get("bombs") as Array).size()
	await _btn(0, JOY_BUTTON_RIGHT_SHOULDER)         # RB on the wrong pad
	var n2: int = (main.get("bombs") as Array).size()
	await _btn(1, JOY_BUTTON_RIGHT_SHOULDER)         # RB on P1's pad
	var n3: int = (main.get("bombs") as Array).size()
	var ok7 := n1 == n0 and n2 == n0 and n3 == n0 + 1
	print("battle: old A=%d wrong-pad RB=%d P1-pad RB=%d -> %s" % [n1 - n0, n2 - n0,
		n3 - n0, ok7])
	fails += 0 if ok7 else 1
	Settings._pad_device = keep_pads[0]
	Settings._pad_bomb = keep_pads[1]
	Settings._pad_system = keep_pads[2]
	Settings._stick_deadzone = keep_pads[3]
	Settings._apply_pads()
	Settings._save()
	Settings.players = keep["p"]
	Settings.fill_bots = keep["fill"]
	Settings.enemy_count = keep["en"]
	print("PAD PROBE: " + ("PASS" if fails == 0 else "FAIL (%d)" % fails))
	get_tree().quit(0 if fails == 0 else 1)
