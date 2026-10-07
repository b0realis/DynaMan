extends Node
## Controls probe (v10.0): the rebind API must refuse system keys and
## twins (naming the owner), apply clean binds to the InputMap, keep
## the help text live, persist across a save/load cycle, and reset to
## the factory clusters. v12.5 GAMEPADS: claiming a pad swaps seats and
## rewires that player's actions to the device; d-pad bombs and system
## clashes are refused; a trigger can bomb; system buttons remap for any
## pad; the dead zone reaches the InputMap; all of it persists, and a
## corrupt table loads as the factory one. Backs up and restores
## dynaman.cfg.
##   godot --headless res://tests/controls_probe.tscn

func _ready() -> void:
	_run()


func _run() -> void:
	var bak: PackedByteArray = []
	var had := FileAccess.file_exists(Settings.SAVE_PATH)
	if had:
		bak = FileAccess.get_file_as_bytes(Settings.SAVE_PATH)
	Settings.reset_player_keys()
	# Defaults serve.
	var def_ok: bool = Settings.player_key(0, 4) == KEY_SPACE \
		and Settings.player_key_text(0).contains("Space")
	# Refusals: a twin (owner named) and a system key.
	var conflict := Settings.set_player_key(0, 0, KEY_UP)   # P2 Up owns it
	var reserved := Settings.set_player_key(0, 0, KEY_R)
	var refuse_ok: bool = conflict.contains("P2") and not reserved.is_empty() \
		and Settings.player_key(0, 0) == KEY_W
	# A clean bind lands in the InputMap and the help text.
	var bind_ok: bool = Settings.set_player_key(0, 0, KEY_T).is_empty()
	var mapped := false
	for ev: InputEvent in InputMap.action_get_events("p1_up"):
		if ev is InputEventKey and (ev as InputEventKey).physical_keycode == KEY_T:
			mapped = true
	bind_ok = bind_ok and mapped and Settings.player_key_text(0).begins_with("T ")
	# Persistence: save, corrupt in memory, reload.
	Settings._save()
	Settings._player_keys[0][0] = KEY_W
	Settings._load()
	var persist_ok: bool = Settings.player_key(0, 0) == KEY_T
	# Factory reset.
	Settings.reset_player_keys()
	var reset_ok: bool = Settings.player_key(0, 0) == KEY_W
	# v10.3: a corrupt persisted table (duplicate, reserved key, garbage)
	# must factory-reset on load, never ghost-drive two players at once.
	Settings._player_keys[0][0] = KEY_UP       # P2's Up — a twin
	Settings._player_keys[0][1] = KEY_ESCAPE   # reserved
	Settings._player_keys[0][2] = 0            # garbage
	Settings._save()
	Settings._load()
	reset_ok = reset_ok and Settings.player_key(0, 0) == KEY_W \
		and Settings.player_key(0, 1) == KEY_A \
		and Settings.player_key(0, 2) == KEY_S \
		and not Settings.set_player_key(0, 0, KEY_F11).is_empty()
	Settings.reset_player_keys()
	# --- v12.5 GAMEPADS ---------------------------------------------------
	Settings.reset_pads()
	var pad_def: bool = Settings.pad_device(0) == 0 \
		and Settings.pad_bomb(0) == JOY_BUTTON_A \
		and Settings.pad_system("pause") == JOY_BUTTON_START
	Settings.claim_pad(0, 2)   # pad 3 now drives P1 → P3 takes P1's old pad
	var claim_ok: bool = Settings.pad_device(0) == 2 and Settings.pad_device(2) == 0
	for ev: InputEvent in InputMap.action_get_events("p1_up"):
		if (ev is InputEventJoypadButton or ev is InputEventJoypadMotion) \
				and ev.device != 2:
			claim_ok = false
	var r1 := Settings.set_pad_bomb(1, JOY_BUTTON_DPAD_UP)
	var r2 := Settings.set_pad_bomb(1, JOY_BUTTON_START)            # pause's
	var r3 := Settings.set_pad_system("restart", JOY_BUTTON_A)      # bombs
	var r4 := Settings.set_pad_system("restart", JOY_BUTTON_START)  # pause's
	var r5 := Settings.set_pad_system("pause",
		Settings.PAD_TRIGGER + JOY_AXIS_TRIGGER_RIGHT)               # analog: no
	var prefuse_ok: bool = not r1.is_empty() and r2.contains("Pause") \
		and r3.contains("bombs") and not r4.is_empty() \
		and r5.contains("triggers") and Settings.pad_system("pause") == JOY_BUTTON_START \
		and Settings.pad_bomb(1) == JOY_BUTTON_A \
		and Settings.pad_system("restart") == JOY_BUTTON_Y
	var rt: int = Settings.PAD_TRIGGER + JOY_AXIS_TRIGGER_RIGHT
	var trig_ok: bool = Settings.set_pad_bomb(1, rt).is_empty() \
		and Settings.pad_text(1).ends_with("RT")
	var has_rt := false
	for ev: InputEvent in InputMap.action_get_events("p2_bomb"):
		if ev is InputEventJoypadMotion \
				and (ev as InputEventJoypadMotion).axis == JOY_AXIS_TRIGGER_RIGHT \
				and ev.device == Settings.pad_device(1):
			has_rt = true
	trig_ok = trig_ok and has_rt
	var sys_ok: bool = Settings.set_pad_system("restart", JOY_BUTTON_X).is_empty()
	var pad_evs: Array = InputMap.action_get_events("restart").filter(
		func(e: InputEvent) -> bool: return e is InputEventJoypadButton)
	sys_ok = sys_ok and pad_evs.size() == 1 \
		and (pad_evs[0] as InputEventJoypadButton).button_index == JOY_BUTTON_X \
		and (pad_evs[0] as InputEventJoypadButton).device == -1
	Settings.stick_deadzone = 0.4
	var dz_ok: bool = is_equal_approx(InputMap.action_get_deadzone("p1_left"), 0.4)
	Settings._save()
	Settings._pad_device = [0, 1, 2, 3]
	Settings._pad_bomb = [JOY_BUTTON_A, JOY_BUTTON_A, JOY_BUTTON_A, JOY_BUTTON_A]
	Settings._pad_system = Settings.PAD_SYSTEM_DEFAULTS.duplicate()
	Settings._stick_deadzone = 0.2
	Settings._load()
	var ppersist_ok: bool = Settings.pad_device(0) == 2 and Settings.pad_bomb(1) == rt \
		and Settings.pad_system("restart") == JOY_BUTTON_X \
		and is_equal_approx(Settings.stick_deadzone, 0.4)
	# A corrupt table (twin pads; pause on a bomb button) loads as factory.
	Settings._pad_device = [1, 1, 2, 3]
	Settings._pad_system["pause"] = JOY_BUTTON_A
	Settings._save()
	Settings._pad_device = [0, 1, 2, 3]
	Settings._pad_bomb = [JOY_BUTTON_A, JOY_BUTTON_A, JOY_BUTTON_A, JOY_BUTTON_A]
	Settings._pad_system = Settings.PAD_SYSTEM_DEFAULTS.duplicate()
	Settings._load()
	var pcorrupt_ok: bool = Settings.pad_device(0) == 0 and Settings.pad_device(1) == 1 \
		and Settings.pad_system("pause") == JOY_BUTTON_START
	var pads_ok := pad_def and claim_ok and prefuse_ok and trig_ok and sys_ok \
		and dz_ok and ppersist_ok and pcorrupt_ok
	print("PADS: defaults=%s claim=%s refuse=%s trigger=%s system=%s deadzone=%s persist=%s corrupt=%s"
		% [pad_def, claim_ok, prefuse_ok, trig_ok, sys_ok, dz_ok, ppersist_ok, pcorrupt_ok])
	Settings.reset_pads()
	Settings._save()
	if had:
		var f := FileAccess.open(Settings.SAVE_PATH, FileAccess.WRITE)
		f.store_buffer(bak)
		f.close()
	elif FileAccess.file_exists(Settings.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.SAVE_PATH))
	var ok := def_ok and refuse_ok and bind_ok and persist_ok and reset_ok and pads_ok
	print("CONTROLS PROBE: defaults=%s refuse=%s bind=%s persist=%s reset=%s pads=%s -> %s"
		% [def_ok, refuse_ok, bind_ok, persist_ok, reset_ok, pads_ok,
		"PASS" if ok else "FAIL"])
	get_tree().quit(0 if ok else 1)
