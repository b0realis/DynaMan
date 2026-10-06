extends SceneTree
## Render the icon set from icon.svg (the master) into dist/icons/.
##   godot --headless --script res://tests/icon_render.gd

func _init() -> void:
	var svg := FileAccess.get_file_as_string("res://icon.svg")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://dist/icons"))
	for s: int in [16, 24, 32, 48, 64, 128, 256, 512]:
		var img := Image.new()
		img.load_svg_from_string(svg, s / 128.0)
		if img.get_width() != s:
			img.resize(s, s, Image.INTERPOLATE_LANCZOS)
		img.save_png("res://dist/icons/dynaman_%d.png" % s)
		print("icon %dpx ok" % s)
	quit()
