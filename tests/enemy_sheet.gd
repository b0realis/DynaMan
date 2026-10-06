extends Node
## Dev one-shot: the rogues' gallery — all 20 enemy types with tier
## tags (v6.8). Serpents show their head; bodies trail in-game.
##   DYNAMAN_SHOT_DIR=/abs/path godot res://tests/enemy_sheet.tscn

const ROSTER := [
	["balloon", "Balloon · T1", "drifts aimlessly"],
	["slime", "Slime · T1", "splits into two minis when burned"],
	["snail", "Snail · T1", "slow, paints slowing goo"],
	["chomper_0", "Chomper · T2", "smells you, hunts in bursts"],
	["bees", "Bee swarm · T2", "quick and jittery"],
	["frog", "Frog · T2", "hops OVER walls"],
	["mole", "Mole · T2", "burrows, pops up beside you"],
	["saw", "Saw · T2", "charges straight lanes"],
	["ghost", "Ghost · T3", "walks through bricks"],
	["elemental", "Elemental · T3", "lane fireballs"],
	["freezer", "Freezer · T3", "touch freezes, not kills"],
	["thief", "Thief · T3", "eats revealed power-ups"],
	["muncher", "Muncher · T3", "swallows ticking bombs"],
	["snake_head", "Snake · T3", "4 segments, chops shorter"],
	["mimic", "Mimic · T4", "disguised as this arena's brick"],
	["warlock", "Warlock · T4", "summons fresh monsters"],
	["bull", "Bull · T4", "telegraphed line charge"],
	["centi_head", "Centipede · T4", "6 segments, armored body"],
	["dragon_head", "Dragon · T5", "5 segments, 3 hits, breathes fire"],
	["bomber", "Bomber · T5", "the planner mini-boss"],
]

var _textures: Array[Texture2D] = []  # must OUTLIVE the draw call


func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for entry: Array in ROSTER:
		if entry[0] == "bomber":
			_textures.append(BomberArt.texture("front", 0, Color("d84040")))
		else:
			var src: Texture2D = load("res://assets/svg/%s.svg" % entry[0])
			var img := src.get_image()
			img.decompress()
			_textures.append(ImageTexture.create_from_image(img))
	_run()


func _run() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(5 * 260 + 20, 4 * 260 + 30)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var canvas := Control.new()
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.draw.connect(func() -> void:
		canvas.draw_rect(Rect2(Vector2.ZERO, canvas.size), Color("14161f"))
		var font := ThemeDB.fallback_font
		for i in ROSTER.size():
			var px := 10.0 + (i % 5) * 260
			var py := 10.0 + (i / 5) * 260
			canvas.draw_rect(Rect2(px, py, 246, 246), Color("245224"))
			var ts := 150.0
			canvas.draw_texture_rect(_textures[i], Rect2(px + (246 - ts) * 0.5,
				py + 16, ts, ts), false)
			canvas.draw_string(font, Vector2(px + 8, py + 200), ROSTER[i][1],
				HORIZONTAL_ALIGNMENT_CENTER, 230, 19, Color.WHITE)
			canvas.draw_string(font, Vector2(px + 8, py + 226), ROSTER[i][2],
				HORIZONTAL_ALIGNMENT_CENTER, 230, 13, Color("b8d8b8")))
	vp.add_child(canvas)
	canvas.queue_redraw()
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	var dir := OS.get_environment("DYNAMAN_SHOT_DIR")
	if dir.is_empty():
		dir = OS.get_user_data_dir()
	vp.get_texture().get_image().save_png(dir + "/enemy_sheet.png")
	print("enemy sheet saved (%d types)" % ROSTER.size())
	get_tree().quit()
