extends Node
## Dev one-shot (v5.1): all five bomb styles, in three player tints,
## on one contact sheet.
##   DYNAMAN_SHOT_DIR=/abs/path godot res://tests/bomb_sheet.tscn

func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_run()


func _run() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(BomberArt.BOMB_STYLES.size() * 150 + 20, 3 * 150 + 50)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var canvas := Control.new()
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.draw.connect(func() -> void:
		canvas.draw_rect(Rect2(Vector2.ZERO, canvas.size), Color("2e7248"))
		var font := ThemeDB.fallback_font
		var tints: Array[Color] = [Color("f2f2f6"), Color("d84040"), Color("4060d8")]
		for i in BomberArt.BOMB_STYLES.size():
			var style: String = BomberArt.BOMB_STYLES[i]
			canvas.draw_string(font, Vector2(14 + i * 150, 26),
				BomberArt.BOMB_LABELS[style], HORIZONTAL_ALIGNMENT_LEFT, -1, 15,
				Color.WHITE)
			for j in tints.size():
				canvas.draw_texture_rect(BomberArt.bomb_texture(tints[j], style),
					Rect2(14 + i * 150, 36 + j * 148, 130, 130), false))
	vp.add_child(canvas)
	canvas.queue_redraw()
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	var dir := OS.get_environment("DYNAMAN_SHOT_DIR")
	if dir.is_empty():
		dir = OS.get_user_data_dir()
	vp.get_texture().get_image().save_png(dir + "/bomb_sheet.png")
	print("bomb sheet saved")
	get_tree().quit()
