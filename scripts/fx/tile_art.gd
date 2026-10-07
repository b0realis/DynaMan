class_name TileArt
extends RefCounted
## Arena tile skins: the WALL block, the destructible BRICK and the two
## floor-checker colours, per selectable theme (50 of them in v4.9).
## Chosen in OPTIONS ("Arena tiles" cycler with live preview), stored as
## Settings.arena_skin; "Random arena" picks a fresh one every round.
##
## The API, cache and palette live here; the actual drawings live in
## TileSvg (scripts/fx/tile_svg.gd) — SVG built in code, rasterized once
## per skin, cached. "classic" delegates to the original assets/svg
## tiles so the default look stays pixel-identical.
##
## Canvas is 64×64, rasterized at 2× (128 px) — main.gd scales sprites
## by texture width, so mixed sizes (classic imports at 64) are fine.

const RASTER_SCALE := 2.0

## Cycler order: classics → accessibility → the v4.8 world tour → the
## v4.9 collections (beautiful 15, pastel 5, art 4, cards 1, fantasy 10).
const SKINS: Array[String] = [
	"classic", "classic_colourful", "classic_dark",
	"eye_relief", "ultra_contrast",
	"marble", "space_station", "woods", "forest", "hedge", "garden",
	"mine", "desert", "mountain", "volcano",
	"ocean", "sunset", "sakura", "lavender", "autumn", "nordic", "jade",
	"terracotta", "glacier", "honey", "vineyard", "copper", "midnight",
	"savanna", "rose",
	"pastel_mint", "pastel_peach", "pastel_sky", "pastel_lilac", "candy",
	"mondrian", "vangogh", "monet", "ukiyoe",
	"casino",
	"gingerbread", "atlantis", "moonbase", "crystal", "mushroom",
	"clockwork", "haunted", "cloud", "neon", "pirate", "sea",
]

const LABELS := {
	"classic": "Classic", "classic_colourful": "Classic colourful",
	"classic_dark": "Classic dark", "eye_relief": "Eye relief",
	"ultra_contrast": "Ultra contrast", "marble": "Marble",
	"space_station": "Space station", "woods": "Woods", "forest": "Forest",
	"hedge": "Hedge labyrinth", "garden": "Garden", "mine": "Mine",
	"desert": "Desert", "mountain": "Mountain", "volcano": "Volcano",
	"ocean": "Ocean", "sunset": "Sunset", "sakura": "Sakura",
	"lavender": "Lavender fields", "autumn": "Autumn", "nordic": "Nordic",
	"jade": "Jade temple", "terracotta": "Terracotta",
	"glacier": "Glacier", "honey": "Honeycomb", "vineyard": "Vineyard",
	"copper": "Copper patina", "midnight": "Midnight gold",
	"savanna": "Savanna", "rose": "Rose quartz",
	"pastel_mint": "Pastel mint", "pastel_peach": "Pastel peach",
	"pastel_sky": "Pastel sky", "pastel_lilac": "Pastel lilac",
	"candy": "Candy shop", "mondrian": "Mondrian", "vangogh": "Starry night",
	"monet": "Water lilies", "ukiyoe": "Great wave", "casino": "Casino royale",
	"gingerbread": "Gingerbread", "atlantis": "Atlantis",
	"moonbase": "Moon base", "crystal": "Crystal cavern",
	"mushroom": "Mushroom grove", "clockwork": "Clockwork",
	"haunted": "Haunted yard", "cloud": "Cloud kingdom",
	"neon": "Neon city", "pirate": "Pirate cove", "sea": "Open sea",
}

## Floor checker pairs [even, odd] — close tones so the grid reads
## without shouting (ultra_contrast is allowed to shout). Each pair is
## picked to harmonize with its skin's wall/brick palette: complements
## for the accents, analogous tones for the ground.
const FLOORS := {
	"classic": [Color("3ba03b"), Color("359635")],
	"classic_colourful": [Color("52c23e"), Color("41b12d")],
	"classic_dark": [Color("1f4020"), Color("1a381b")],
	"eye_relief": [Color("4f6b4f"), Color("486348")],
	"ultra_contrast": [Color("ffffff"), Color("d8d8d8")],
	"marble": [Color("ece7db"), Color("ded8c8")],
	"space_station": [Color("2c3140"), Color("262b38")],
	"woods": [Color("4c7a3a"), Color("446e33")],
	"forest": [Color("35582c"), Color("2e4e26")],
	"hedge": [Color("7ab648"), Color("6ca840")],
	"garden": [Color("8cc44f"), Color("7eb646")],
	"mine": [Color("6b5138"), Color("604832")],
	"desert": [Color("dcc084"), Color("d0b276")],
	"mountain": [Color("79876d"), Color("6e7c62")],
	"volcano": [Color("37302c"), Color("2e2825")],
	"ocean": [Color("1f6f80"), Color("1b6474")],
	"sunset": [Color("7a5570"), Color("6f4d66")],
	"sakura": [Color("9db487"), Color("93aa7e")],
	"lavender": [Color("8a9a7a"), Color("7f8f70")],
	"autumn": [Color("a08a4a"), Color("937e42")],
	"nordic": [Color("e8e4dc"), Color("dcd7cc")],
	"jade": [Color("b8d4b0"), Color("accaa4")],
	"terracotta": [Color("e8d9c0"), Color("ddcdb2")],
	"glacier": [Color("bcd8e4"), Color("aecbd9")],
	"honey": [Color("d9a83c"), Color("cd9d34")],
	"vineyard": [Color("7a9a4a"), Color("6f8d42")],
	"copper": [Color("6f8a80"), Color("647d74")],
	"midnight": [Color("1c2440"), Color("171e36")],
	"savanna": [Color("c8a858"), Color("bd9d4e")],
	"rose": [Color("d8b8c0"), Color("ccadb6")],
	"pastel_mint": [Color("c8e8d4"), Color("bcdfc9")],
	"pastel_peach": [Color("f8dfc8"), Color("efd4ba")],
	"pastel_sky": [Color("cce4f4"), Color("c0daec")],
	"pastel_lilac": [Color("e0d4ec"), Color("d5c8e2")],
	"candy": [Color("f8d0e0"), Color("ecc4d5")],
	"mondrian": [Color("f4f4f0"), Color("e7e7e1")],
	"vangogh": [Color("2a3a6a"), Color("24335e")],
	"monet": [Color("8ab8b0"), Color("7eaca4")],
	"ukiyoe": [Color("e8ded0"), Color("ddd2c2")],
	"casino": [Color("2e7248"), Color("286a42")],
	"gingerbread": [Color("b87a4a"), Color("ac7043")],
	"atlantis": [Color("1f5c6c"), Color("1b5362")],
	"moonbase": [Color("6a6e78"), Color("60646e")],
	"crystal": [Color("3a2c50"), Color("332748")],
	"mushroom": [Color("4a7a6a"), Color("427060")],
	"clockwork": [Color("8a6f4a"), Color("7d6543")],
	"haunted": [Color("4c5a4c"), Color("435243")],
	"cloud": [Color("a8d0f0"), Color("9cc4e6")],
	"neon": [Color("22242e"), Color("1c1e28")],
	"pirate": [Color("d8bc84"), Color("ccb079")],
	"sea": [Color("1f5f86"), Color("1b5578")],
}

## Which music mood each skin plays in (v6.6, see Music.MOODS).
## Unlisted skins fall back to classic.
const MOOD := {
	"classic_dark": "dark", "volcano": "dark", "haunted": "dark",
	"crystal": "dark", "midnight": "dark", "neon": "dark",
	"space_station": "dark", "moonbase": "dark", "mine": "dark",
	"vangogh": "dark", "copper": "dark",
	"candy": "cozy", "pastel_mint": "cozy", "pastel_peach": "cozy",
	"pastel_sky": "cozy", "pastel_lilac": "cozy", "gingerbread": "cozy",
	"garden": "cozy", "sakura": "cozy", "rose": "cozy",
	"mushroom": "cozy", "cloud": "cozy",
	"jade": "zen", "ukiyoe": "zen", "monet": "zen", "glacier": "zen",
	"nordic": "zen", "eye_relief": "zen", "lavender": "zen",
	"forest": "zen", "marble": "zen", "sunset": "zen",
	"desert": "desert", "savanna": "desert", "terracotta": "desert",
	"autumn": "desert", "honey": "desert", "pirate": "desert",
	"ocean": "aquatic", "atlantis": "aquatic",
	"casino": "jazz", "clockwork": "jazz", "vineyard": "jazz",
	"sea": "aquatic",
}


static func mood(skin: String) -> String:
	_ensure_user()
	if _user.has(skin):
		return str((_user[skin] as Dictionary).get("mood", "classic"))
	return MOOD.get(skin, "classic")


static var _cache: Dictionary = {}


# ------------------------- user arenas (v9.1) -------------------------------
## A USER ARENA is a named recipe, not code: per element (wall/brick) a
## shape from TileSvg.USER_SHAPES + ONE base colour (tints derived), or
## an embedded PNG; plus a floor colour (checker pair derived), a music
## mood and a name. Stored in user://arenas.cfg, served through the
## same five API calls as the built-ins — the OPTIONS cycler, previews,
## Random arena and battles need no special cases. Shareable as
## .dynarena files (single theme or a pack).

const USER_PATH := "user://arenas.cfg"
const USER_PREFIX := "u_"
const MOOD_KEYS := ["classic", "dark", "cozy", "zen", "desert",
	"aquatic", "jazz"]

static var _user: Dictionary = {}
static var _user_loaded := false
static var last_write_error: Error = OK   # the last arenas.cfg write
## Sections of arenas.cfg that failed validation, kept VERBATIM so the
## next unrelated SAVE/DELETE doesn't erase them for good (v11.8).
static var _user_unreadable: Dictionary = {}

## The only keys a theme recipe carries. Loads and imports copy THESE
## and nothing else (v11.8): unknown keys of any size used to ride
## along into arenas.cfg and every re-export — past the PNG size cap.
const RECIPE_KEYS := ["name", "mood", "wall_shape", "wall_col", "wall_png",
	"brick_shape", "brick_col", "brick_png", "floor_col"]


static func _recipe_from(cf: ConfigFile, sec: String) -> Dictionary:
	var r := {}
	for k: String in RECIPE_KEYS:
		if cf.has_section_key(sec, k):
			r[k] = cf.get_value(sec, k)
	return r


static func _ensure_user() -> void:
	if _user_loaded:
		return
	_user_loaded = true
	var cf := ConfigFile.new()
	var err := cf.load(USER_PATH)
	if err != OK:
		if FileAccess.file_exists(USER_PATH):
			# Unparseable, not absent: keep a copy before any later save
			# rewrites the file from an empty registry (v11.8).
			DirAccess.copy_absolute(ProjectSettings.globalize_path(USER_PATH),
				ProjectSettings.globalize_path(USER_PATH + ".bak"))
		return
	for id in cf.get_sections():
		var r := _recipe_from(cf, id)
		if valid_recipe(r):
			_user[id] = r
		else:
			var raw := {}
			for k in cf.get_section_keys(id):
				raw[k] = cf.get_value(id, k)
			_user_unreadable[id] = raw


## The maker's TRY IT test drive (v9.8): the bench recipe registers
## under this transient id so a battle can wear it UNSAVED. It is never
## listed, never written to arenas.cfg, and never joins Random.
const BENCH_ID := "u__bench"

static func set_bench(r: Dictionary) -> void:
	_ensure_user()
	r = ensure_legible(r.duplicate())
	if str(r.get("name", "")).strip_edges().is_empty():
		r["name"] = "(bench_test)"
	_user[BENCH_ID] = r
	_cache.erase(BENCH_ID + "/wall")
	_cache.erase(BENCH_ID + "/brick")


static func user_ids() -> Array:
	_ensure_user()
	var ids := _user.keys()
	ids.erase(BENCH_ID)   # the bench is a test rig, not a theme
	ids.sort()
	return ids


## Every selectable skin: the 50 built-ins, then yours.
static func all_skins() -> Array:
	return Array(SKINS) + user_ids()


static func has_skin(skin: String) -> bool:
	_ensure_user()
	return FLOORS.has(skin) or _user.has(skin)


static func is_user(skin: String) -> bool:
	_ensure_user()
	return _user.has(skin)


static func user_recipe(skin: String) -> Dictionary:
	_ensure_user()
	return (_user.get(skin, {}) as Dictionary).duplicate()


## A recipe passes if every field the renderer needs is sane. PNG
## elements carry their pixels; shape elements name a library shape.
const MAX_PNG_BYTES := 512 * 1024   # a 128x128 tile never needs more —
									# and a shared bundle must not be a
									# memory bomb (v9.7 hardening)

static func valid_recipe(r: Dictionary) -> bool:
	# STRICT field typing (v9.7): a .dynarena is untrusted input — a
	# wrong-typed field must die HERE, not crash the board later (a
	# String wall_png used to slip through and null the wall texture).
	var nm_v: Variant = r.get("name", "")
	if not (nm_v is String) or (nm_v as String).length() > 4096:
		return false   # length gate BEFORE any full-string processing
	var nm := (nm_v as String).strip_edges()
	if nm.is_empty() or nm.length() > 100:
		return false
	if not (r.get("mood", "classic") is String):
		return false
	for el in ["wall", "brick"]:
		var png_v: Variant = r.get(el + "_png", null)
		if png_v != null and not (png_v is PackedByteArray):
			return false
		var png: PackedByteArray = png_v if png_v is PackedByteArray \
			else PackedByteArray()
		if png.size() > MAX_PNG_BYTES:
			return false
		if not png.is_empty() and not _png_dims_ok(png):
			return false
		var has_png := not png.is_empty()
		var shape_v: Variant = r.get(el + "_shape", "")
		if not (shape_v is String):
			return false
		var shape := shape_v as String
		if not has_png and not TileSvg.USER_SHAPES.has(shape) \
				and shape != "runestone":   # retired id still renders (as moai)
			return false
		if not (r.get(el + "_col", null) is Color):
			return false
	return r.get("floor_col", null) is Color


## PNG header sanity (v11.8): the 512 KB cap limits the COMPRESSED
## bytes only — a tiny palette PNG can declare 16384x16384 and decode
## into a gigabyte. Read the IHDR size before anything decodes it.
static func _png_dims_ok(png: PackedByteArray) -> bool:
	if png.size() < 24 or png.slice(0, 8) != PackedByteArray(
			[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]):
		return false
	var w := (png[16] << 24) | (png[17] << 16) | (png[18] << 8) | png[19]
	var h := (png[20] << 24) | (png[21] << 16) | (png[22] << 8) | png[23]
	return w >= 1 and h >= 1 and w <= 1024 and h <= 1024


## The tint set a shape template needs, derived from ONE base colour.
static func recipe_tints(base: Color) -> Dictionary:
	return {
		"base": "#" + base.to_html(false),
		"soft": "#" + base.lightened(0.12).to_html(false),
		"shade": "#" + base.darkened(0.15).to_html(false),
		"light": "#" + base.lightened(0.3).to_html(false),
		"pale": "#" + base.lightened(0.55).to_html(false),
		"dark": "#" + base.darkened(0.28).to_html(false),
		"deep": "#" + base.darkened(0.5).to_html(false),
	}


## The house LEGIBILITY RULE, enforced: wall vs brick must read at a
## squint. Too close in luminance? The wall is RETARGETED to sit a firm
## step on the far side of the brick — get_luminance() is linear in the
## components, so scaling RGB lands the target exactly (no blind nudge
## that can saturate at black beside a dark brick).
static func ensure_legible(r: Dictionary) -> Dictionary:
	var w: Color = r.get("wall_col", Color.GRAY)
	var bl: float = (r.get("brick_col", Color.RED) as Color).get_luminance()
	if absf(w.get_luminance() - bl) >= 0.16:
		return r
	var target := clampf(bl + (0.24 if bl < 0.4 else -0.24), 0.03, 0.95)
	var lum := w.get_luminance()
	if lum < 0.02:
		r["wall_col"] = Color(target, target, target)  # near-black: grey it
	else:
		var k := target / lum
		var scaled := Color(clampf(w.r * k, 0.0, 1.0),
			clampf(w.g * k, 0.0, 1.0), clampf(w.b * k, 0.0, 1.0))
		if absf(scaled.get_luminance() - bl) < 0.16:
			# The channel clamp fell short (a saturated primary — pure
			# red can't get brighter by scaling): grey is the honest
			# fallback that always lands the target (v9.7).
			scaled = Color(target, target, target)
		r["wall_col"] = scaled
	return r


## Rasterize one element of a recipe WITHOUT saving — the maker's live
## preview. PNG elements load their pixels; shape elements go through
## TileSvg.user_shape.
static func recipe_tex(r: Dictionary, kind: String) -> Texture2D:
	# Untyped read + explicit type check (v9.7): a typed local would
	# THROW on a wrong-typed field and null the texture into the board.
	var png_v: Variant = r.get(kind + "_png", null)
	var img := Image.new()
	if png_v is PackedByteArray and not (png_v as PackedByteArray).is_empty():
		if img.load_png_from_buffer(png_v) == OK \
				and img.get_width() <= 1024 and img.get_height() <= 1024:
			# Normalize ANY source (registry, bundle, hand-edited cfg) to
			# the tile canvas: the board scales sprites by texture WIDTH,
			# so a non-square image would render squashed (v9.7).
			if img.get_width() != 128 or img.get_height() != 128:
				img.resize(128, 128, Image.INTERPOLATE_LANCZOS)
			return ImageTexture.create_from_image(img)
	var body := TileSvg.user_shape(str(r.get(kind + "_shape", "bevel")),
		recipe_tints(r.get(kind + "_col", Color.GRAY)))
	var svg := "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"64\" height=\"64\" viewBox=\"0 0 64 64\">" \
		+ body + "</svg>"
	if img.load_svg_from_string(svg, RASTER_SCALE) != OK:
		return load("res://assets/svg/%s.svg" % kind)
	return ImageTexture.create_from_image(img)


static func _write_user_file() -> void:
	var cf := ConfigFile.new()
	for id: String in _user_unreadable:
		if not _user.has(id):
			for k: String in (_user_unreadable[id] as Dictionary):
				cf.set_value(id, k, _user_unreadable[id][k])
	for id: String in _user:
		if id == BENCH_ID:
			continue   # the test rig never touches disk
		for k: String in (_user[id] as Dictionary):
			cf.set_value(id, k, _user[id][k])
	# Beside, then swapped in (no half-written file on a power cut), and
	# the outcome is kept for the maker to report (v12.6: it said "saved"
	# even when the user folder was read-only).
	var tmp := USER_PATH + ".tmp"
	last_write_error = cf.save(tmp)
	if last_write_error == OK:
		last_write_error = DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp),
			ProjectSettings.globalize_path(USER_PATH))
	if last_write_error != OK:
		push_warning("TileArt: could not save %s (error %d)" % [USER_PATH, last_write_error])


static func _sanitize_id(s: String) -> String:
	s = s.substr(0, 64)   # never scan a novel-length name (v9.7)
	var out := ""
	for ch in s.to_lower():
		out += ch if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") \
			or ch == "_" else ("_" if ch == " " else "")
	return out.substr(0, 40) if not out.is_empty() else "arena"


## Save (or update, when `keep_id` names an existing user skin) and
## return the skin id.
## Does any OTHER saved theme already wear this name? (Ids are always
## unique; names must be too, or the wheel shows unpickable twins.)
static func _name_taken(nm: String, self_id: String) -> bool:
	if LABELS.values().has(nm):
		return true   # a user "Forest" would twin the built-in on the wheel
	for id: String in _user:
		if id != self_id and id != BENCH_ID \
				and str((_user[id] as Dictionary).get("name", "")) == nm:
			return true
	return false


static func save_user(r: Dictionary, keep_id := "") -> String:
	_ensure_user()
	r = ensure_legible(r.duplicate())
	# The name keeps exactly what was typed — the ONLY transform is
	# spaces -> underscores (player's rule, v9.8) plus the safety cap.
	r["name"] = str(r.get("name", "")).strip_edges().substr(0, 40) \
		.replace(" ", "_")
	if not valid_recipe(r):
		return ""
	# Twin names get a numeral so every wheel entry stays pickable.
	var base_name := str(r["name"])
	var nn := 1
	const NUMERALS := ["II", "III", "IV", "V", "VI", "VII", "VIII", "IX"]
	while _name_taken(str(r["name"]), keep_id):
		nn += 1
		r["name"] = "%s_%s" % [base_name,
			NUMERALS[nn - 2] if nn - 2 < NUMERALS.size() else str(nn)]
	var id := keep_id
	if id.is_empty() or not _user.has(id) or id == BENCH_ID:
		id = USER_PREFIX + _sanitize_id(str(r["name"]))
		var n := 1
		# BENCH_ID counts as taken even when no bench is registered — a
		# theme named "_bench" would otherwise claim the TRY-IT sentinel
		# and silently vanish (unlisted, unpersisted) (v9.9).
		# …nor a kept-unreadable section's id (it would be overwritten).
		while _user.has(id) or FLOORS.has(id) or id == BENCH_ID \
				or _user_unreadable.has(id):
			n += 1
			id = "%s%s_%d" % [USER_PREFIX, _sanitize_id(str(r["name"])), n]
	_user[id] = r
	_cache.erase(id + "/wall")
	_cache.erase(id + "/brick")
	_write_user_file()
	return id


static func delete_user(id: String) -> void:
	_ensure_user()
	_user.erase(id)
	_cache.erase(id + "/wall")
	_cache.erase(id + "/brick")
	_write_user_file()


## ---- sharing: .dynarena files (a theme, or a pack of them) ----

static func export_user(id: String, path: String) -> Error:
	_ensure_user()
	if not _user.has(id):
		return ERR_DOES_NOT_EXIST
	var cf := ConfigFile.new()
	for k: String in (_user[id] as Dictionary):
		cf.set_value(id, k, _user[id][k])
	return cf.save(path)


## Import every valid theme in the file; ids that are taken get a fresh
## suffix (never clobbering yours). Returns the imported skin ids.
static func import_user(path: String) -> Array:
	_ensure_user()
	var cf := ConfigFile.new()
	if cf.load(path) != OK:
		return []
	var got: Array = []
	for sec in cf.get_sections():
		var r := _recipe_from(cf, sec)
		if not valid_recipe(r):
			continue
		got.append(save_user(r))
	return got


## The maker's EXPORT: the bench as a shareable .dynarena WITHOUT
## touching your saved themes (v11.8). EXPORT used to SAVE first — so
## exploring with THE DIE and then cancelling the export dialog had
## already overwritten the theme being edited (or added a phantom).
## "" = written; otherwise the refusal to show.
static func export_recipe(r: Dictionary, path: String) -> String:
	r = ensure_legible(r.duplicate())
	r["name"] = str(r.get("name", "")).strip_edges().substr(0, 40) \
		.replace(" ", "_")
	if not valid_recipe(r):
		return "give it a name first"
	var cf := ConfigFile.new()
	var sec := USER_PREFIX + _sanitize_id(str(r["name"]))
	for k: String in RECIPE_KEYS:
		if r.has(k):
			cf.set_value(sec, k, r[k])
	return "" if cf.save(path) == OK else "could not write there"


## THE DIE: a colour-theory roll — one hue anchors the theme, the wall
## goes dark and muted, the brick bright on the complement (or a loud
## analogous), the floor stays a calm close pair; shapes and mood ride
## along, and the name deals itself from the pools.
const _NAME_A := ["Neon", "Velvet", "Amber", "Frost", "Ember", "Moss",
	"Cobalt", "Rust", "Ivory", "Onyx", "Coral", "Sage", "Gilded",
	"Misty", "Thorn", "Sunken",
	# The literary sixteen (v9.5) — words with a library smell.
	"Sable", "Gossamer", "Halcyon", "Vermilion", "Argent", "Umbral",
	"Sylvan", "Auroral", "Cerulean", "Elysian", "Lambent", "Twilit",
	"Wuthering", "Obsidian", "Verdant", "Hallowed"]
const _NAME_B := ["Bog", "Foundry", "Keep", "Grove", "Reef", "Bazaar",
	"Vault", "Hollow", "Terrace", "Quarry", "Atrium", "Docks",
	"Parlor", "Warren", "Court", "Arcade",
	# The literary sixteen (v9.5) — places worth a chapter.
	"Bastion", "Labyrinth", "Necropolis", "Conservatory", "Menagerie",
	"Scriptorium", "Aviary", "Catacomb", "Promenade", "Sanctum",
	"Rookery", "Grotto", "Belfry", "Observatory", "Undercroft",
	"Gloaming"]

## The original arena look as a starting recipe (v9.4): the classic
## grey bevel, the classic light-red brick courses, the classic green
## floor, the classic tune — home base to tweak from, instead of a
## random roll.
static func classic_recipe() -> Dictionary:
	return {
		"name": "My Classic",
		"wall_shape": "bevel", "wall_col": Color("8e95a2"),
		"brick_shape": "bricks", "brick_col": Color("c06246"),
		"floor_col": Color("3ba03b"),
		"mood": "classic",
	}


static func random_recipe(rng: RandomNumberGenerator) -> Dictionary:
	var hue := rng.randf()
	var brick_hue := fposmod(hue + (0.5 if rng.randf() < 0.6
		else rng.randf_range(0.06, 0.14)), 1.0)
	return ensure_legible({
		"name": "%s %s" % [_NAME_A[rng.randi() % _NAME_A.size()],
			_NAME_B[rng.randi() % _NAME_B.size()]],
		"wall_shape": TileSvg.USER_SHAPES[rng.randi() % TileSvg.USER_SHAPES.size()],
		"wall_col": Color.from_hsv(hue, rng.randf_range(0.25, 0.5),
			rng.randf_range(0.3, 0.48)),
		"brick_shape": TileSvg.USER_SHAPES[rng.randi() % TileSvg.USER_SHAPES.size()],
		"brick_col": Color.from_hsv(brick_hue, rng.randf_range(0.5, 0.85),
			rng.randf_range(0.62, 0.85)),
		"floor_col": Color.from_hsv(fposmod(hue + rng.randf_range(-0.06, 0.06), 1.0),
			rng.randf_range(0.12, 0.3), rng.randf_range(0.45, 0.72)),
		"mood": MOOD_KEYS[rng.randi() % MOOD_KEYS.size()],
	})


static func wall(skin: String) -> Texture2D:
	return _tex(skin, "wall")


static func brick(skin: String) -> Texture2D:
	return _tex(skin, "brick")


static func floors(skin: String) -> Array:
	_ensure_user()
	if _user.has(skin):
		var f: Color = (_user[skin] as Dictionary).get("floor_col", Color.GRAY)
		return [f, f.lightened(0.07)]  # the house "close tones" pair
	return FLOORS.get(skin, FLOORS["classic"])


static func label(skin: String) -> String:
	_ensure_user()
	if _user.has(skin):
		return str((_user[skin] as Dictionary).get("name", skin))
	return LABELS.get(skin, skin.capitalize())


static func _tex(skin: String, kind: String) -> Texture2D:
	if not has_skin(skin):
		skin = "classic"
	var key := skin + "/" + kind
	if _cache.has(key):
		return _cache[key]
	var tex: Texture2D
	if skin == "classic":
		tex = load("res://assets/svg/%s.svg" % kind)
	elif _user.has(skin):
		tex = recipe_tex(_user[skin], kind)
	else:
		var img := Image.new()
		if img.load_svg_from_string(TileSvg.svg(skin, kind), RASTER_SCALE) != OK:
			push_warning("TileArt: failed to rasterize %s" % key)
			tex = load("res://assets/svg/%s.svg" % kind)  # fail safe
		else:
			tex = ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex
