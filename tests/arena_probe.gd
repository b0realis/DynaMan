extends Node
## Arena Maker probe (v9.1): user themes must round-trip the registry
## and the .dynarena share file, serve through the same five TileArt
## API calls as the built-ins, survive Settings validation, and THE
## DIE must always deal legible, valid recipes. Backs up and restores
## user://arenas.cfg.
##   godot --headless res://tests/arena_probe.tscn

func _ready() -> void:
	_run()


func _run() -> void:
	var bak: PackedByteArray = []
	var had := FileAccess.file_exists(TileArt.USER_PATH)
	if had:
		bak = FileAccess.get_file_as_bytes(TileArt.USER_PATH)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# Save a rolled recipe; the API must serve it like a built-in.
	var r := TileArt.random_recipe(rng)
	r["name"] = "Probe Grotto"
	var id := TileArt.save_user(r)
	var api_ok: bool = id.begins_with(TileArt.USER_PREFIX) \
		and TileArt.has_skin(id) and TileArt.all_skins().has(id) \
		and TileArt.label(id) == "Probe_Grotto" \
		# v9.8 name rule: spaces become underscores on save
		and TileArt.MOOD_KEYS.has(TileArt.mood(id)) \
		and (TileArt.floors(id) as Array).size() == 2 \
		and TileArt.wall(id) != null and TileArt.brick(id) != null \
		and TileArt.wall(id).get_width() > 0
	# Settings must accept a user id and reject a bogus one.
	var keep := Settings.arena_skin
	Settings.arena_skin = id
	var set_ok: bool = Settings.arena_skin == id
	Settings.arena_skin = "u_no_such_thing"
	set_ok = set_ok and Settings.arena_skin == "classic"
	Settings.arena_skin = keep
	# Fresh-load round-trip: the registry must reread from disk.
	TileArt._user_loaded = false
	TileArt._user = {}
	var trip_ok: bool = TileArt.has_skin(id) \
		and TileArt.user_recipe(id).get("wall_col", null) is Color
	# Share file: export, delete, import — same theme, fresh id if taken.
	var share := OS.get_user_data_dir() + "/probe_theme.dynarena"
	var share_ok: bool = TileArt.export_user(id, share) == OK
	var got := TileArt.import_user(share)   # id taken -> remapped
	share_ok = share_ok and got.size() == 1 and str(got[0]) != id \
		and TileArt.label(str(got[0])) == "Probe_Grotto_II"
	TileArt.delete_user(str(got[0]))
	TileArt.delete_user(id)
	share_ok = share_ok and not TileArt.has_skin(id)
	DirAccess.remove_absolute(share)
	# A PNG element must validate and rasterize too.
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color.REBECCA_PURPLE)
	var pr := TileArt.random_recipe(rng)
	pr["name"] = "Probe Png"
	pr["wall_png"] = img.save_png_to_buffer()
	var pid := TileArt.save_user(pr)
	# v9.7: EVERY png normalizes to the 128 tile canvas (the board scales
	# by texture width — a pass-through odd size rendered squashed).
	var png_ok: bool = not pid.is_empty() and TileArt.wall(pid) != null \
		and TileArt.wall(pid).get_width() == 128
	TileArt.delete_user(pid)
	# v9.7 hardening: a wrong-TYPED png field (the .dynarena is untrusted)
	# must be rejected by validation AND survive rendering; a saturated
	# primary wall must still be forced legible (the channel clamp used
	# to defeat the luminance retarget); giant names must be rejected.
	var evil := TileArt.random_recipe(rng)
	evil["name"] = "Evil"
	evil["wall_png"] = "not bytes at all"
	var hard_ok: bool = not TileArt.valid_recipe(evil) \
		and TileArt.recipe_tex(evil, "wall") != null
	var sat := {"name": "Sat", "wall_shape": "bevel", "wall_col": Color(1, 0, 0),
		"brick_shape": "bricks", "brick_col": Color(0.72, 0.2, 0.2),
		"floor_col": Color.GRAY, "mood": "classic"}
	var fixed := TileArt.ensure_legible(sat.duplicate())
	hard_ok = hard_ok and absf((fixed["wall_col"] as Color).get_luminance()
		- (fixed["brick_col"] as Color).get_luminance()) >= 0.15
	var longname := TileArt.random_recipe(rng)
	longname["name"] = "x".repeat(10000)
	hard_ok = hard_ok and not TileArt.valid_recipe(longname)
	# v9.8: names keep what was typed except spaces -> underscores; twin
	# names get numerals; the TRY-IT bench is never listed nor persisted.
	var na := TileArt.random_recipe(rng)
	na["name"] = "Twin Peak"
	var ida := TileArt.save_user(na)
	var nb := TileArt.random_recipe(rng)
	nb["name"] = "Twin Peak"
	var idb := TileArt.save_user(nb)
	var v98_ok: bool = TileArt.label(ida) == "Twin_Peak" \
		and TileArt.label(idb) == "Twin_Peak_II"
	# v9.9: a theme named "_bench" must NOT claim the TRY-IT sentinel id
	# (it would silently vanish — unlisted and unpersisted).
	var nbench := TileArt.random_recipe(rng)
	nbench["name"] = "_bench"
	var idc := TileArt.save_user(nbench)
	v98_ok = v98_ok and idc != TileArt.BENCH_ID \
		and TileArt.user_ids().has(idc)
	TileArt.delete_user(idc)
	TileArt.set_bench(TileArt.random_recipe(rng))
	v98_ok = v98_ok and TileArt.has_skin(TileArt.BENCH_ID) \
		and not TileArt.user_ids().has(TileArt.BENCH_ID) \
		and not TileArt.all_skins().has(TileArt.BENCH_ID)
	TileArt.delete_user(ida)   # delete triggers a file write — the bench
	TileArt.delete_user(idb)   # must stay off the disk through it
	TileArt._user_loaded = false
	TileArt._user = {}
	v98_ok = v98_ok and not TileArt.has_skin(TileArt.BENCH_ID)
	# THE DIE: 40 rolls, all valid, all legible at a squint. The CLASSIC
	# home base (v9.4) must be a valid recipe too.
	var die_ok := TileArt.valid_recipe(TileArt.classic_recipe()) and hard_ok \
		and v98_ok
	for i in 40:
		var d := TileArt.random_recipe(rng)
		die_ok = die_ok and TileArt.valid_recipe(d) \
			and absf((d["wall_col"] as Color).get_luminance()
				- (d["brick_col"] as Color).get_luminance()) >= 0.15
	# Restore the register byte-for-byte.
	if had:
		var f := FileAccess.open(TileArt.USER_PATH, FileAccess.WRITE)
		f.store_buffer(bak)
		f.close()
	elif FileAccess.file_exists(TileArt.USER_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TileArt.USER_PATH))
	var ok := api_ok and set_ok and trip_ok and share_ok and png_ok and die_ok
	print("ARENA PROBE: api=%s settings=%s trip=%s share=%s png=%s die=%s -> %s"
		% [api_ok, set_ok, trip_ok, share_ok, png_ok, die_ok,
		"PASS" if ok else "FAIL"])
	get_tree().quit(0 if ok else 1)
