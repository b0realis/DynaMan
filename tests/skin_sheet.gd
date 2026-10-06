extends Node
## Dev one-shot (v4.8, 50 skins in v4.9): render every arena tile skin —
## floor checker, walls, bricks — on one big contact sheet for visual
## review. Draws into a SubViewport so the sheet can be far larger than
## the window.
##   DYNAMAN_SHOT_DIR=/abs/path godot res://tests/skin_sheet.tscn

const CELL := 34.0
const COLS := 5
const PANEL_W := 246.0
const PANEL_H := 174.0

func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_run()


func _run() -> void:
	var rows := ceili(TileArt.SKINS.size() / float(COLS))
	var vp := SubViewport.new()
	vp.size = Vector2i(int(COLS * PANEL_W + 16), int(rows * PANEL_H + 40))
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var canvas := Control.new()
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.draw.connect(_draw_sheet.bind(canvas))
	vp.add_child(canvas)
	canvas.queue_redraw()
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	var dir := OS.get_environment("DYNAMAN_SHOT_DIR")
	if dir.is_empty():
		dir = OS.get_user_data_dir()
	vp.get_texture().get_image().save_png(dir + "/skin_sheet.png")
	print("skin sheet saved (%d skins)" % TileArt.SKINS.size())
	get_tree().quit()


func _draw_sheet(canvas: Control) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO, canvas.size), Color("14161f"))
	var font := ThemeDB.fallback_font
	for i in TileArt.SKINS.size():
		var skin: String = TileArt.SKINS[i]
		var px := 8.0 + (i % COLS) * PANEL_W
		var py := 8.0 + (i / COLS) * PANEL_H + 22.0
		canvas.draw_string(font, Vector2(px + 4, py - 5), TileArt.label(skin),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
		var fc: Array = TileArt.floors(skin)
		for y in 4:
			for x in 7:
				canvas.draw_rect(Rect2(px + x * CELL, py + y * CELL,
					CELL + 1, CELL + 1), fc[0] if (x + y) % 2 == 0 else fc[1])
		var wall := TileArt.wall(skin)
		var brick := TileArt.brick(skin)
		# Layout mimics play: walls on the pillar grid, bricks between.
		for spot: Array in [[wall, 1, 1], [wall, 3, 1], [wall, 5, 1],
				[brick, 2, 1], [brick, 4, 1], [wall, 2, 2],
				[brick, 1, 2], [brick, 3, 2], [brick, 5, 2]]:
			canvas.draw_texture_rect(spot[0], Rect2(px + spot[1] * CELL,
				py + spot[2] * CELL, CELL, CELL), false)
