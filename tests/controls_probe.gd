extends Node
## Controls probe (v10.0): the rebind API must refuse system keys and
## twins (naming the owner), apply clean binds to the InputMap, keep
## the help text live, persist across a save/load cycle, and reset to
## the factory clusters. Backs up and restores dynaman.cfg.
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
	Settings._save()
	if had:
		var f := FileAccess.open(Settings.SAVE_PATH, FileAccess.WRITE)
		f.store_buffer(bak)
		f.close()
	elif FileAccess.file_exists(Settings.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.SAVE_PATH))
	var ok := def_ok and refuse_ok and bind_ok and persist_ok and reset_ok
	print("CONTROLS PROBE: defaults=%s refuse=%s bind=%s persist=%s reset=%s -> %s"
		% [def_ok, refuse_ok, bind_ok, persist_ok, reset_ok,
		"PASS" if ok else "FAIL"])
	get_tree().quit(0 if ok else 1)
