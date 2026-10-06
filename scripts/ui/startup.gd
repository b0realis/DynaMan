extends Node
## Startup — DynaMan's front door (scenes/startup.tscn, the main scene):
## Prescription Games caduceus splash, then the menu over a blueprint-gag
## backdrop (an engineer's drawing of the bomb, drawn in code). All
## built in code; splash choreography shared with sibling games.
##
## Panels: BATTLE SETUP (players, arena size, brick/enemy/bonus/danger
## densities — all straight onto Settings), OPTIONS (audio, fullscreen),
## HELP (controls per player).

## Project convention: bump by 0.1 with EVERY shipped change.
const VERSION := "v12.3"

const COL_TEXT := Color("e8e0cc")
const COL_DIM := Color("8b8fa3")
const COL_GOLD := Color("f2c94c")
const COL_BP_BG := Color("14356b")  # cyanotype blueprint blue

const SPLASH_FADE_IN := 0.6
const SPLASH_HOLD := 1.2
const SPLASH_FADE_OUT := 0.5
const SPLASH_LOGO_PX := 300.0

var _splash_layer: CanvasLayer
var _splash_black: ColorRect
var _splash_box: VBoxContainer
var _splash_tween: Tween
var _splash_done := false

var _menu_layer: CanvasLayer
var _menu_root: Control
var _menu_column: VBoxContainer
var _setup_panel: PanelContainer
var _options_panel: PanelContainer
var _help_panel: PanelContainer
var _main_buttons: Array = []
var _backdrop: Control
var _spark_ctl: Control  # animated fuse-spark overlay (v4.5 perf split)
var _bd_time := 0.0
## Preset selection UI: [[button, preset], ...] plus the Custom indicator.
var _preset_btns: Array = []
var _custom_btn: Button
var _color_btns: Array[Button] = []
var _bstyle_btns: Array[Button] = []
## Arena Maker (v9.1): the recipe on the bench, the id being edited
## ("" = a fresh one), and the refresh hooks that keep the maker's
## widgets and the OPTIONS skin row honest.
var _maker_panel: PanelContainer
var _maker_recipe: Dictionary = {}
var _maker_edit_id := ""
var _maker_refresh := Callable()
var _maker_yours_refresh := Callable()
var _maker_focus_id := ""   # Your-themes cursor jumps here on next refresh
							# (set by save/import so the row shows what
							# just happened, not a shifted neighbour)
## CONTROLS rebinding (v10.0): the panel, the button grid, and the
## capture target (-1 = not listening).
var _controls_panel: PanelContainer
var _controls_status: Label
## Menu widgets that mirror Settings state re-read it on ANY change
## (v10.3) — F11 or a rebind must never leave a stale label on screen.
var _opt_sync: Array = []
var _rebind_btns: Array = []
var _rebind_p := -1
var _rebind_d := -1
var _skin_row_refresh := Callable()
var _color_cb := Callable()   # generic colour-popup routing (maker swatches)
var _color_pop: PopupPanel
var _color_picker: ColorPicker
var _color_target := -1
var _color_first_swatch: Button   # pad entry point into the colour popup
## THE MEDICINE CABINET (v11.0, renamed + recoloured v11.1): the
## secret cheat pharmacy. No button leads here — on the menu you TYPE
## the magic word (or play the pad code) and the cabinet swings open;
## from then on a little pill sits in the menu corner to reopen it.
## Session-only: the word must be spoken again after every launch.
const CHEAT_WORD := "PLACEBO"
const KONAMI: Array[int] = [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_UP,
	JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT,
	JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT,
	JOY_BUTTON_A, JOY_BUTTON_A]
const CHEATS := [
	{"id": "deluxe", "name": "DYNAMITE+GLUCOSE", "col": Color(0.95, 0.62, 0.2),
		"desc": "every round starts with maximum bombs, flame and speed"},
	{"id": "sugar", "name": "ADAPTOGEN PILLS", "col": Color(0.93, 0.55, 0.72),
		"desc": "the blast vest never wears off — walk through fire"},
	{"id": "sedative", "name": "SEDATIVE", "col": Color(0.62, 0.52, 0.92),
		"desc": "the whole battle runs at half speed"},
	{"id": "steel_toes", "name": "ANABOLICS", "col": Color(0.45, 0.62, 0.88),
		"desc": "bomb kick, always on"},
	{"id": "xray", "name": "X-RAY EYE DROPS", "col": Color(0.3, 0.85, 0.68),
		"desc": "bricks hiding an item glow gold (skulls too — read the label)"},
	{"id": "fever", "name": "ANTIINFECTIVES", "col": Color(0.9, 0.32, 0.26),
		"desc": "any blast detonates EVERY bomb on the field"},
]
var _cheat_panel: PanelContainer
var _cheat_typed := ""       # rolling letter buffer for the magic word
var _konami_idx := 0         # progress through the pad code
var _cheat_rows: Dictionary = {}   # id -> {btn, icon, row, tex_on, tex_off}
var _pill_btn: Button        # the corner pill — appears once unlocked


func _ready() -> void:
	_build_backdrop()
	_build_menu()
	_build_splash()
	if Settings.skip_splash_once:
		Settings.skip_splash_once = false
		_end_splash(true)
	else:
		_play_splash()
	Settings.attract_demo = false   # back from (or never in) the attract
	if Settings.try_theme:
		# Back from the TRY IT test drive (v9.8): straight to the bench,
		# mid-edit, locks and edit target intact.
		Settings.try_theme = false
		_maker_edit_id = Settings.maker_edit_id
		_maker_recipe = Settings.maker_bench_raw.duplicate() \
			if not Settings.maker_bench_raw.is_empty() \
			else TileArt.user_recipe(TileArt.BENCH_ID)
		_maker_opened_on = Settings.arena_skin  # the bench survives BACK too
		_maker_refresh.call()
		_open_panel(_maker_panel)


## Menu-idle attract (v10.1): after `Settings.attract_idle` quiet
## seconds on the BARE menu (no panel, no popup, no rebind capture),
## the demo battle takes the stage; any key in it returns here.
var _idle_t := 0.0
var _menu_focused := true   # the attract must not burn GPU for nobody


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_menu_focused = false
		_idle_t = 0.0
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_menu_focused = true
		_idle_t = 0.0


func _process(delta: float) -> void:
	_bd_time += delta
	if _backdrop != null:
		_spark_ctl.queue_redraw()  # only the spark animates; the
		# blueprint sheet redraws on resize alone (Controls re-emit
		# draw when their size changes).
	_idle_t += delta
	if _splash_done and Settings.attract_idle > 0 \
			and _idle_t >= float(Settings.attract_idle) \
			and _menu_focused \
			and not _any_panel_open() and _rebind_p < 0 \
			and (_color_pop == null or not _color_pop.visible):
		_idle_t = 0.0
		Settings.attract_demo = true
		Settings.skip_splash_once = true
		get_tree().change_scene_to_file("res://scenes/main.tscn")


func _any_panel_open() -> bool:
	for p in [_setup_panel, _options_panel, _help_panel,
			_maker_panel, _controls_panel, _cheat_panel]:
		if p != null and (p as PanelContainer).visible:
			return true
	return false


func _input(event: InputEvent) -> void:
	# Any real human signal resets the attract clock (stick drift and
	# sub-pixel mouse jitter don't count).
	if event is InputEventKey or event is InputEventMouseButton \
			or event is InputEventJoypadButton:
		_idle_t = 0.0
	elif event is InputEventMouseMotion \
			and (event as InputEventMouseMotion).relative.length() > 2.0:
		_idle_t = 0.0
	elif event is InputEventJoypadMotion \
			and absf((event as InputEventJoypadMotion).axis_value) > 0.5:
		_idle_t = 0.0
	# The cabinet's two secret doors (v11.0): listen only on the bare
	# menu of the RETAIL battle game — never in panels, mid-rebind, or
	# in the story products.
	if not _splash_done or _any_panel_open() or _rebind_p >= 0 \
			or Settings.is_blastalar_build() or OS.has_feature("story_tool"):
		return
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		var kc := (event as InputEventKey).keycode
		if kc >= KEY_A and kc <= KEY_Z:
			_cheat_typed += char(kc)
			if _cheat_typed.length() > CHEAT_WORD.length():
				_cheat_typed = _cheat_typed.right(CHEAT_WORD.length())
			if _cheat_typed == CHEAT_WORD:
				_cheat_typed = ""
				_open_cabinet()
	elif event is InputEventJoypadButton and event.is_pressed():
		var b := (event as InputEventJoypadButton).button_index
		if b == KONAMI[_konami_idx]:
			# The closing A, A must not ALSO press the focused menu
			# button (it used to start a battle — or quit — mid-code).
			if b == JOY_BUTTON_A:
				get_viewport().set_input_as_handled()
			_konami_idx += 1
			if _konami_idx >= KONAMI.size():
				_konami_idx = 0
				_open_cabinet()
		elif b == KONAMI[0]:
			# A stray extra Up keeps the Up-Up prefix alive (Up, Up, Up,
			# Down… still counts), any other Up restarts at one.
			_konami_idx = 2 if _konami_idx == 2 else 1
		else:
			_konami_idx = 0


func _unhandled_input(event: InputEvent) -> void:
	if _splash_done:
		# Key capture for CONTROLS rebinding (v10.0) eats the next key
		# press before any panel/menu handling gets a look.
		if _rebind_p >= 0:
			if event is InputEventKey and event.pressed and not event.echo:
				var kc := int((event as InputEventKey).physical_keycode)
				if kc == 0:
					return   # synthetic/IME event — keep listening (v10.3)
				if kc == KEY_ESCAPE:
					_controls_status.text = "kept the old key"
				else:
					var err := Settings.set_player_key(_rebind_p, _rebind_d, kc)
					_controls_status.text = err if not err.is_empty() \
						else "P%d %s is now %s" % [_rebind_p + 1,
							Settings.KEY_SLOT_NAMES[_rebind_d],
							OS.get_keycode_string(Settings.key_label_code(kc))]
				var done_btn: Button = _rebind_btns[_rebind_p][_rebind_d]
				_rebind_p = -1
				_rebind_d = -1
				_refresh_rebind_btns()
				done_btn.grab_focus()
				get_viewport().set_input_as_handled()
				return
			if event.is_action_pressed("ui_cancel"):   # pad B backs out
				var back_btn: Button = _rebind_btns[_rebind_p][_rebind_d]
				_rebind_p = -1
				_rebind_d = -1
				_refresh_rebind_btns()
				_controls_status.text = "kept the old key"
				back_btn.grab_focus()  # arming released focus; a pad
				# user would otherwise be stranded with nothing focused
				get_viewport().set_input_as_handled()
				return
			return
		if event.is_action_pressed("ui_cancel"):
			# The maker and CONTROLS step BACK to OPTIONS — their tweak
			# loops stay tight; other panels close to the menu as ever.
			if _maker_panel != null and _maker_panel.visible:
				_close_panel(_maker_panel)
				_open_panel(_options_panel)
				return
			if _controls_panel != null and _controls_panel.visible:
				_close_panel(_controls_panel)
				_open_panel(_options_panel)
				return
			for panel in [_setup_panel, _options_panel, _help_panel,
					_cheat_panel]:
				if (panel as PanelContainer).visible:
					_close_panel(panel)
					break
		return
	var pressed: bool = (event is InputEventKey or event is InputEventJoypadButton) \
		and event.is_pressed()
	if pressed:
		_end_splash(false)
		get_viewport().set_input_as_handled()


func _on_splash_gui_input(event: InputEvent) -> void:
	if _splash_done:
		return
	if event is InputEventMouseButton and event.is_pressed():
		_end_splash(false)
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------- backdrop -----

func _build_backdrop() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -10
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = COL_BP_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(bg)

	_backdrop = Control.new()
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.draw.connect(_draw_backdrop)
	layer.add_child(_backdrop)
	# The spark overlay: the sheet's single animated element (see
	# _draw_spark) so the full blueprint isn't re-issued per frame.
	_spark_ctl = Control.new()
	_spark_ctl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_spark_ctl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spark_ctl.draw.connect(_draw_spark)
	layer.add_child(_spark_ctl)


# The gag backdrop: an engineer's blueprint of the bomb bomberman uses.
# Cyanotype blue, white ink, dimension arrows, three projections and a
# hatched cross-section — all vector-drawn in code. Scale 1:1. TOL ±BOOM.
const BP_INK := Color(0.85, 0.91, 1.0)

func _bp_line(a: Vector2, b: Vector2, w: float, alpha: float) -> void:
	_backdrop.draw_line(a, b, Color(BP_INK, alpha), w, true)


func _bp_dash(a: Vector2, b: Vector2, alpha: float) -> void:
	_backdrop.draw_dashed_line(a, b, Color(BP_INK, alpha), 1.0, 7.0, true)


func _bp_circle(c: Vector2, r: float, w: float, alpha: float) -> void:
	_backdrop.draw_arc(c, r, 0.0, TAU, 72, Color(BP_INK, alpha), w, true)


func _bp_text(pos: Vector2, s: String, size: int, alpha: float,
		centered := false) -> void:
	var f := ThemeDB.fallback_font
	var x := pos.x - 300.0 if centered else pos.x
	_backdrop.draw_string(f, Vector2(x, pos.y), s,
		HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT,
		600.0 if centered else -1.0, size, Color(BP_INK, alpha))


func _bp_arrowhead(tip: Vector2, dirv: Vector2, alpha := 0.75) -> void:
	var n := dirv.normalized()
	var pp := Vector2(-n.y, n.x)
	_backdrop.draw_colored_polygon(PackedVector2Array([tip,
		tip - n * 9.0 + pp * 3.2, tip - n * 9.0 - pp * 3.2]),
		Color(BP_INK, alpha))


## Horizontal dimension: extension ticks, inward arrows, label above.
func _bp_dim_h(x0: float, x1: float, y: float, label: String) -> void:
	_bp_line(Vector2(x0, y - 5), Vector2(x0, y + 5), 1.0, 0.55)
	_bp_line(Vector2(x1, y - 5), Vector2(x1, y + 5), 1.0, 0.55)
	_bp_line(Vector2(x0, y), Vector2(x1, y), 1.0, 0.55)
	_bp_arrowhead(Vector2(x0, y), Vector2(-1, 0))
	_bp_arrowhead(Vector2(x1, y), Vector2(1, 0))
	_bp_text(Vector2((x0 + x1) * 0.5, y - 7), label, 12, 0.85, true)


## Leader line: dot on the part, elbow, short shelf, label.
func _bp_leader(from: Vector2, elbow: Vector2, shelf: float, label: String) -> void:
	_backdrop.draw_circle(from, 2.2, Color(BP_INK, 0.8))
	_bp_line(from, elbow, 1.0, 0.55)
	_bp_line(elbow, elbow + Vector2(shelf, 0), 1.0, 0.55)
	var tx := elbow + (Vector2(shelf + 5, 4) if shelf >= 0.0
		else Vector2(shelf - 5 - 4.5 * label.length(), 4))
	_bp_text(tx, label, 12, 0.85)


## The blueprint's one animated element, on its own overlay: the fuse
## spark twinkling at the tip. Mirrors _bp_front_view's geometry (title
## view center at 17.5%/50% of the sheet, radius 108, fuse bezier end).
func _draw_spark() -> void:
	var v := _spark_ctl.size
	var c := Vector2(v.x * 0.175, v.y * 0.50)
	var f0 := Vector2(c.x, c.y - 108.0 - 24.0)
	var f2 := f0 + Vector2(52, -34)
	for i in 7:
		var a := i * TAU / 7.0 + _bd_time * 1.6
		var l := 7.0 + sin(_bd_time * 5.0 + i) * 2.5
		_spark_ctl.draw_line(f2 + Vector2.from_angle(a) * 3.0,
			f2 + Vector2.from_angle(a) * (3.0 + l), Color(BP_INK, 0.85), 1.3, true)


func _draw_backdrop() -> void:
	var v := _backdrop.size
	# Grid: fine mesh + heavier majors, like graph vellum.
	for x in range(0, int(v.x) + 24, 24):
		_bp_line(Vector2(x, 0), Vector2(x, v.y), 1.0, 0.05 if x % 120 else 0.11)
	for y in range(0, int(v.y) + 24, 24):
		_bp_line(Vector2(0, y), Vector2(v.x, y), 1.0, 0.05 if y % 120 else 0.11)
	# Sheet frame.
	_backdrop.draw_rect(Rect2(14, 14, v.x - 28, v.y - 28), Color(BP_INK, 0.35), false, 1.5)
	_backdrop.draw_rect(Rect2(21, 21, v.x - 42, v.y - 42), Color(BP_INK, 0.16), false, 1.0)

	_bp_front_view(Vector2(v.x * 0.175, v.y * 0.50), 108.0)
	_bp_section_view(Vector2(v.x * 0.825, v.y * 0.46), 108.0)
	_bp_top_view(Vector2(v.x * 0.145, v.y * 0.155), 48.0)
	_bp_notes(Vector2(40, v.y * 0.76))
	_bp_title_block(Rect2(v.x - 366, v.y - 148, 330, 112))
	# Rubber stamp, slightly drunk.
	_backdrop.draw_set_transform(Vector2(v.x * 0.70, 52), -0.10, Vector2.ONE)
	var red := Color(1.0, 0.38, 0.38, 0.55)
	_backdrop.draw_rect(Rect2(-92, -17, 184, 34), red, false, 2.5)
	_backdrop.draw_string(ThemeDB.fallback_font, Vector2(-80, 6),
		"TOP SECRET-ISH", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, red)
	_backdrop.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## FIG. 1 — front elevation with fuse, cut line A-A and dimensions.
func _bp_front_view(c: Vector2, r: float) -> void:
	# Centerlines first, then the body over them.
	_bp_dash(c - Vector2(r + 26, 0), c + Vector2(r + 26, 0), 0.30)
	_bp_circle(c, r, 2.0, 0.9)
	_bp_circle(c, r * 0.985, 0.8, 0.25)
	# Bolt-cap collar (design No. 10): neck, cap plate, two bolt heads.
	var top_y := c.y - r
	_backdrop.draw_rect(Rect2(c.x - r * 0.22, top_y - 14, r * 0.44, 15),
		Color(BP_INK, 0.9), false, 1.6)
	_backdrop.draw_rect(Rect2(c.x - r * 0.30, top_y - 24, r * 0.60, 10),
		Color(BP_INK, 0.9), false, 1.6)
	_bp_circle(Vector2(c.x - r * 0.20, top_y - 19), 2.6, 1.2, 0.8)
	_bp_circle(Vector2(c.x + r * 0.20, top_y - 19), 2.6, 1.2, 0.8)
	# Fuse: a lazy bezier out of the cap, sparking at the tip.
	var f0 := Vector2(c.x, top_y - 24)
	var f1 := f0 + Vector2(10, -40)
	var f2 := f0 + Vector2(52, -34)
	var prev := f0
	for i in range(1, 15):
		var t := i / 14.0
		var pt := f0.lerp(f1, t).lerp(f1.lerp(f2, t), t)
		_bp_line(prev, pt, 2.0, 0.9)
		prev = pt
	# (The twinkling spark itself lives on _spark_ctl — the sheet's one
	# animated element gets its own overlay so these ~400 primitives
	# aren't re-issued every frame just to animate it; v4.5 perf.)
	_bp_leader(f2 + Vector2(4, 4), f2 + Vector2(38, 30), 12, "SPARK, FESTIVE")
	_bp_leader(f0.lerp(f2, 0.55) + Vector2(0, -6), f0 + Vector2(70, -52), 12,
		"FUSE · 2.8 s NOMINAL")
	_bp_leader(Vector2(c.x - r * 0.26, top_y - 19),
		Vector2(c.x - r * 0.9, top_y - 44), -12, "CAP, BOLT-ON (No. 10)")
	# Section cut A-A (vertical dash-dot, viewed toward Fig. right).
	_bp_dash(Vector2(c.x, c.y - r - 40), Vector2(c.x, c.y + r + 18), 0.45)
	_bp_arrowhead(Vector2(c.x + 12, c.y - r - 34), Vector2(1, 0), 0.6)
	_bp_arrowhead(Vector2(c.x + 12, c.y + r + 12), Vector2(1, 0), 0.6)
	_bp_text(Vector2(c.x - 16, c.y - r - 30), "A", 14, 0.8)
	_bp_text(Vector2(c.x - 16, c.y + r + 16), "A", 14, 0.8)
	# Dimensions.
	_bp_dim_h(c.x - r, c.x + r, c.y + r + 34, "Ø 46.0 — FILLS ONE (1) CELL")
	var rd := Vector2.from_angle(-0.5)
	_bp_line(c, c + rd * r, 1.0, 0.55)
	_bp_arrowhead(c + rd * r, rd)
	_bp_text(c + rd * r * 0.45 + Vector2(4, -4), "R 23.0", 12, 0.85)
	_bp_text(Vector2(c.x, c.y + r + 58), "FIG. 1 — BOMB, FRONT ELEVATION", 13, 0.75, true)
	_bp_text(Vector2(c.x, c.y + r + 74), "(THE ONE BOMBERMAN USES)", 11, 0.5, true)


## SECTION A-A — hatched casing, stippled powder core, fuse channel.
func _bp_section_view(c: Vector2, r: float) -> void:
	var core := r * 0.62
	_bp_circle(c, r, 2.0, 0.9)
	# 45° hatching across the casing annulus: full-circle chords, then
	# the core gets cleared by a bg-colored disc (flat bg = free eraser).
	var n := Vector2(1, 1).normalized()
	var t := Vector2(1, -1).normalized()
	var step := 9.0
	var d := -r + 4.0
	while d < r - 2.0:
		var half := sqrt(maxf(r * r - d * d, 0.0)) - 2.0
		var mid := c + n * d
		_bp_line(mid - t * half, mid + t * half, 1.0, 0.30)
		d += step
	_backdrop.draw_circle(c, core, COL_BP_BG)
	_bp_circle(c, core, 1.6, 0.85)
	# Powder stipple: hash-scattered dots (a spiral reads as machined,
	# not granular).
	for i in 120:
		var h1 := fmod(sin(float(i) * 12.9898) * 43758.5453, 1.0)
		var h2 := fmod(sin(float(i) * 78.233) * 12543.7717, 1.0)
		var rr := core * 0.90 * sqrt(absf(h2))
		_backdrop.draw_circle(c + Vector2.from_angle(h1 * TAU) * rr, 1.1,
			Color(BP_INK, 0.45))
	# Fuse channel from casing top into the core.
	var ch := 5.0
	_backdrop.draw_rect(Rect2(c.x - ch, c.y - r - 24, ch * 2, r - core + 24),
		COL_BP_BG)
	_bp_line(Vector2(c.x - ch, c.y - r - 24), Vector2(c.x - ch, c.y - core), 1.4, 0.85)
	_bp_line(Vector2(c.x + ch, c.y - r - 24), Vector2(c.x + ch, c.y - core), 1.4, 0.85)
	_bp_dash(Vector2(c.x, c.y - r - 30), Vector2(c.x, c.y + r + 24), 0.30)
	# Callouts.
	_bp_leader(c + Vector2(-r * 0.86, -r * 0.34), c + Vector2(-r - 46, -r * 0.62),
		-12, "CASING: CAST IRON")
	_bp_leader(c + Vector2(core * 0.35, core * 0.5),
		c + Vector2(r * 0.55, r + 0.0), -12, "POWDER, EXTRA LOUD")
	_bp_leader(Vector2(c.x + ch, c.y - r + 2), c + Vector2(r * 0.8, -r - 34), 12,
		"CHANNEL Ø 4.2")
	_bp_dim_h(c.x - core, c.x + core, c.y + r + 30, "Ø CORE 28.5 (100% FUN)")
	_bp_text(Vector2(c.x, c.y + r + 56), "SECTION A-A · SCALE 1:1", 13, 0.75, true)


## FIG. 2 — plan view: cap ring, six bolts, do not stand here.
func _bp_top_view(c: Vector2, r: float) -> void:
	_bp_dash(c - Vector2(r + 16, 0), c + Vector2(r + 16, 0), 0.30)
	_bp_dash(c - Vector2(0, r + 16), c + Vector2(0, r + 16), 0.30)
	_bp_circle(c, r, 1.8, 0.9)
	_bp_circle(c, r * 0.40, 1.4, 0.8)
	_bp_circle(c, r * 0.16, 1.2, 0.7)
	for i in 6:
		var a := i * TAU / 6.0 + 0.35
		_bp_circle(c + Vector2.from_angle(a) * r * 0.66, 3.0, 1.1, 0.7)
	_bp_text(Vector2(c.x, c.y + r + 20), "FIG. 2 — PLAN", 12, 0.75, true)
	_bp_text(Vector2(c.x, c.y + r + 35), "(DO NOT BE ABOVE)", 10, 0.5, true)


func _bp_notes(at: Vector2) -> void:
	var lines := ["NOTES:", "1. LIGHT FUSE.", "2. WALK AWAY BRISKLY (≥ 3 CELLS).",
		"3. DO NOT HOLD. SEE NOTE 2.", "4. COLOUR TO TASTE — SEE PICKER.",
		"5. NOT A TOY. WELL... SORT OF."]
	for i in lines.size():
		_bp_text(at + Vector2(0 if i == 0 else 10, i * 17.0), lines[i], 12,
			0.8 if i == 0 else 0.6)


func _bp_title_block(rect: Rect2) -> void:
	_backdrop.draw_rect(rect, Color(BP_INK, 0.10), true)
	_backdrop.draw_rect(rect, Color(BP_INK, 0.6), false, 1.5)
	var rows := ["PRESCRIPTION GAMES — ORDNANCE DEPT.",
		"PART: BOMB MK-10 \"THE CENTERPIECE\"",
		"DWG No. DM-B-010 · REV %s" % VERSION,
		"SCALE 1:1 · UNITS: CELLS · TOL: ±BOOM",
		"DRAWN: DYNAMAN · APPROVED: NOBODY"]
	var rh := rect.size.y / rows.size()
	for i in rows.size():
		if i > 0:
			_bp_line(rect.position + Vector2(0, i * rh),
				rect.position + Vector2(rect.size.x, i * rh), 1.0, 0.35)
		_bp_text(rect.position + Vector2(8, i * rh + rh - 6), rows[i], 11,
			0.85 if i == 0 else 0.65)


# --------------------------------------------------------------- splash -----

func _build_splash() -> void:
	_splash_layer = CanvasLayer.new()
	_splash_layer.layer = 50
	add_child(_splash_layer)
	_splash_black = ColorRect.new()
	_splash_black.color = Color.BLACK
	_splash_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_splash_black.mouse_filter = Control.MOUSE_FILTER_STOP
	_splash_black.gui_input.connect(_on_splash_gui_input)
	_splash_layer.add_child(_splash_black)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_splash_layer.add_child(center)
	_splash_box = VBoxContainer.new()
	_splash_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_splash_box.add_theme_constant_override("separation", 10)
	_splash_box.modulate.a = 0.0
	center.add_child(_splash_box)
	var logo := TextureRect.new()
	logo.texture = load("res://assets/svg/caduceus.svg") as Texture2D
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(SPLASH_LOGO_PX, SPLASH_LOGO_PX)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var logo_wrap := CenterContainer.new()
	logo_wrap.add_child(logo)
	_splash_box.add_child(logo_wrap)
	_splash_box.add_child(_spacer(14))
	_splash_box.add_child(_make_label("PRESCRIPTION GAMES", 30, COL_TEXT, true, 8))
	_splash_box.add_child(_make_label("presents", 16, COL_DIM, false, 3))


func _play_splash() -> void:
	Sfx.play("ui")
	var box := _splash_box
	await get_tree().process_frame
	if _splash_done:
		return
	box.pivot_offset = box.size * 0.5
	box.scale = Vector2(1.03, 1.03)
	_splash_tween = create_tween()
	_splash_tween.set_parallel(true)
	_splash_tween.tween_property(box, "modulate:a", 1.0, SPLASH_FADE_IN) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_splash_tween.tween_property(box, "scale", Vector2.ONE,
		SPLASH_FADE_IN + SPLASH_HOLD) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_splash_tween.set_parallel(false)
	_splash_tween.tween_interval(SPLASH_HOLD)
	_splash_tween.tween_property(box, "modulate:a", 0.0, SPLASH_FADE_OUT) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_splash_tween.tween_callback(_end_splash.bind(false))


func _end_splash(instant: bool) -> void:
	if _splash_done:
		return
	_splash_done = true
	if _splash_tween != null and _splash_tween.is_valid():
		_splash_tween.kill()
	if instant:
		_splash_layer.queue_free()
	else:
		var tw := create_tween()
		tw.tween_property(_splash_black, "modulate:a", 0.0, 0.35)
		tw.parallel().tween_property(_splash_box, "modulate:a", 0.0, 0.2)
		tw.tween_callback(_splash_layer.queue_free)
	_reveal_menu()


# ----------------------------------------------------------------- menu -----

func _build_menu() -> void:
	_menu_layer = CanvasLayer.new()
	_menu_layer.layer = 10
	add_child(_menu_layer)
	_menu_root = Control.new()
	_menu_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu_root.modulate.a = 0.0
	_menu_layer.add_child(_menu_root)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_root.add_child(center)
	_menu_column = VBoxContainer.new()
	_menu_column.alignment = BoxContainer.ALIGNMENT_CENTER
	_menu_column.add_theme_constant_override("separation", 6)
	center.add_child(_menu_column)

	# Title: bomb icon + DynaMan.
	var title_row := HBoxContainer.new()
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_theme_constant_override("separation", 14)
	var bomb_icon := TextureRect.new()
	bomb_icon.texture = load("res://assets/svg/bomb.svg") as Texture2D
	bomb_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bomb_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bomb_icon.custom_minimum_size = Vector2(64, 64)
	bomb_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_row.add_child(bomb_icon)
	title_row.add_child(_make_label("DynaMan", 64, COL_TEXT, true, 6))
	_menu_column.add_child(title_row)
	var underline := ColorRect.new()
	underline.color = COL_GOLD
	underline.custom_minimum_size = Vector2(360, 3)
	underline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var under_wrap := CenterContainer.new()
	under_wrap.add_child(underline)
	_menu_column.add_child(under_wrap)
	_menu_column.add_child(_spacer(4))
	_menu_column.add_child(_make_label("last bomber standing — 0 (demo) to 4 players, bots welcome",
		16, COL_DIM, false, 2))
	_menu_column.add_child(_spacer(22))

	_build_menu_buttons()
	_setup_panel = _build_setup_panel()
	_options_panel = _build_options_panel()
	_help_panel = _build_help_panel()
	_maker_panel = _build_maker_panel()
	_controls_panel = _build_controls_panel()
	_cheat_panel = _build_cheat_panel()
	Settings.changed.connect(func() -> void:
		for c: Callable in _opt_sync:
			c.call())
	_build_footer()


func _build_menu_buttons() -> void:
	var start_btn := _make_menu_button("START BATTLE")
	start_btn.name = "StartButton"
	var story_btn: Button = null
	var setup_btn := _make_menu_button("BATTLE SETUP")
	var options_btn := _make_menu_button("OPTIONS")
	var help_btn := _make_menu_button("HELP")
	var quit_btn := _make_menu_button("QUIT")
	_main_buttons = [start_btn, setup_btn, options_btn, help_btn, quit_btn] \
		if story_btn == null \
		else [start_btn, story_btn, setup_btn, options_btn, help_btn, quit_btn]
	for b: Button in _main_buttons:
		var wrap := CenterContainer.new()
		wrap.add_child(b)
		_menu_column.add_child(wrap)
	start_btn.focus_neighbor_top = start_btn.get_path_to(quit_btn)
	quit_btn.focus_neighbor_bottom = quit_btn.get_path_to(start_btn)
	start_btn.focus_previous = start_btn.get_path_to(quit_btn)
	quit_btn.focus_next = quit_btn.get_path_to(start_btn)
	start_btn.pressed.connect(func() -> void:
		Sfx.play("ui")
		get_tree().change_scene_to_file("res://scenes/main.tscn"))
	if story_btn != null:
		story_btn.pressed.connect(func() -> void:
			Sfx.play("ui")
			Settings.skip_splash_once = true
			get_tree().change_scene_to_file("res://scenes/blastalar_gate.tscn"))
	# Late lookup (not .bind): panels are built after the buttons.
	setup_btn.pressed.connect(func() -> void: _open_panel(_setup_panel))
	options_btn.pressed.connect(func() -> void: _open_panel(_options_panel))
	help_btn.pressed.connect(func() -> void: _open_panel(_help_panel))
	quit_btn.pressed.connect(func() -> void:
		Sfx.play("ui")
		get_tree().quit())


## One labeled slider row; setter receives the raw slider value.
func _slider_row(vb: VBoxContainer, text: String, minv: float, maxv: float,
		step: float, value: float, to_text: Callable, setter: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	vb.add_child(row)
	var lbl := _make_label(text, 15, COL_TEXT, false, 0)
	lbl.custom_minimum_size = Vector2(170, 0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(lbl)
	var slider := HSlider.new()
	slider.min_value = minv
	slider.max_value = maxv
	slider.step = step
	slider.value = value
	slider.custom_minimum_size = Vector2(210, 0)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	var val_lbl := _make_label(str(to_text.call(value)), 15, COL_GOLD, true, 0)
	val_lbl.custom_minimum_size = Vector2(74, 0)
	row.add_child(val_lbl)
	slider.value_changed.connect(func(v: float) -> void:
		setter.call(v)
		val_lbl.text = str(to_text.call(v))
		Sfx.play("ui", 0.03))


func _build_setup_panel() -> PanelContainer:
	var panel := _make_overlay_panel()
	# The body scrolls (v7.6): however many rows the setup grows to, it can
	# never run off a 720p screen — a scrollbar appears only when needed.
	var vb := _scroll_body(panel)
	vb.add_theme_constant_override("separation", 6)
	vb.add_child(_make_label("BATTLE SETUP", 24, COL_GOLD, true, 5))
	vb.add_child(_spacer(4))

	# Arena presets with a real selection state: the button matching the
	# current sliders is highlighted; anything else lights "Custom".
	var preset_row := HBoxContainer.new()
	preset_row.add_theme_constant_override("separation", 12)
	vb.add_child(preset_row)
	var preset_lbl := _make_label("Arena presets", 15, COL_TEXT, false, 0)
	preset_lbl.custom_minimum_size = Vector2(170, 0)
	preset_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	preset_row.add_child(preset_lbl)
	_preset_btns = []
	for preset: Array in Settings.PRESETS:
		var pb := Button.new()
		pb.text = "%s %d×%d" % [preset[0], preset[1], preset[2]]
		pb.add_theme_font_size_override("font_size", 15)
		_make_focusable(pb)  # v6.5: pad/keyboard reach; ring only WHILE focused
		pb.pressed.connect(func() -> void:
			Settings.arena_w = preset[1]
			Settings.arena_h = preset[2]
			Sfx.play("ui")
			_rebuild_setup_panel(pb.text))
		preset_row.add_child(pb)
		_preset_btns.append([pb, preset])
	_custom_btn = Button.new()
	_custom_btn.text = "Custom"
	_custom_btn.add_theme_font_size_override("font_size", 15)
	_custom_btn.focus_mode = Control.FOCUS_NONE
	_custom_btn.disabled = true  # indicator, not an action
	preset_row.add_child(_custom_btn)
	_update_preset_marks()

	var pct := func(v: float) -> String: return "%d%%" % int(v)
	var num := func(v: float) -> String: return str(int(v))
	# Humans; 0 = attract-mode demo where bots battle alone (v4.6).
	_slider_row(vb, "Players", 0, 4, 1, Settings.players,
		func(v: float) -> String: return "demo" if int(v) == 0 else str(int(v)),
		func(v: float) -> void: Settings.players = int(v))
	# Both bot counts stay visible so the panel doesn't reflow: the
	# first applies to 1-player battles, the second to the 0-player demo.
	_slider_row(vb, "Bots (1 player)", 0, 3, 1, Settings.solo_bots,
		func(v: float) -> String: return "arcade" if int(v) == 0 else str(int(v)),
		func(v: float) -> void: Settings.solo_bots = int(v))
	_slider_row(vb, "Bots (demo)", 2, 4, 1, Settings.demo_bots, num,
		func(v: float) -> void: Settings.demo_bots = int(v))
	# Fill empty seats with bots in a 2- or 3-human battle (v7.6): every
	# game becomes a full four (2 humans → 2 bots, 3 humans → 1 bot).
	var fill_cb := CheckBox.new()
	fill_cb.text = "Fill empty seats with bots (2–3 players)"
	fill_cb.button_pressed = Settings.fill_bots
	fill_cb.add_theme_font_size_override("font_size", 15)
	fill_cb.toggled.connect(func(on: bool) -> void:
		Settings.fill_bots = on
		Sfx.play("ui"))
	vb.add_child(fill_cb)
	_slider_row(vb, "Arena width", Settings.ARENA_W_RANGE.x, Settings.ARENA_W_RANGE.y,
		2, Settings.arena_w, num,
		func(v: float) -> void:
			Settings.arena_w = int(v)
			_update_preset_marks())
	_slider_row(vb, "Arena height", Settings.ARENA_H_RANGE.x, Settings.ARENA_H_RANGE.y,
		2, Settings.arena_h, num,
		func(v: float) -> void:
			Settings.arena_h = int(v)
			_update_preset_marks())
	_slider_row(vb, "Brick density", 10, 95, 5, Settings.brick_density * 100.0, pct,
		func(v: float) -> void: Settings.brick_density = v / 100.0)
	_slider_row(vb, "Enemies", Settings.ENEMY_RANGE.x, Settings.ENEMY_RANGE.y,
		1, Settings.enemy_count, num,
		func(v: float) -> void: Settings.enemy_count = int(v))
	_slider_row(vb, "Bonus items", 0, 60, 5, Settings.bonus_density * 100.0, pct,
		func(v: float) -> void: Settings.bonus_density = v / 100.0)
	_slider_row(vb, "Dangerous items", 0, 60, 5, Settings.danger_share * 100.0, pct,
		func(v: float) -> void: Settings.danger_share = v / 100.0)
	_slider_row(vb, "Rounds to win", 1, 5, 1, Settings.wins_target, num,
		func(v: float) -> void: Settings.wins_target = int(v))
	_slider_row(vb, "Win by margin", 1, 2, 1, Settings.win_margin, num,
		func(v: float) -> void: Settings.win_margin = int(v))
	var mmss := func(v: float) -> String: return "%d:%02d" % [int(v) / 60, int(v) % 60]
	_slider_row(vb, "Round time", 60, 300, 30, Settings.round_time, mmss,
		func(v: float) -> void: Settings.round_time = int(v))
	_slider_row(vb, "Max mini-bosses (solo)", 1, 5, 1, Settings.max_bosses, num,
		func(v: float) -> void: Settings.max_bosses = int(v))

	# Sudden death (v4.5): pressure blocks close the arena in the last
	# 45 s of multiplayer rounds. Off by default — it changes endgames.
	var press_cb := CheckBox.new()
	press_cb.text = "Sudden death — pressure blocks (multiplayer)"
	press_cb.button_pressed = Settings.pressure_on
	press_cb.add_theme_font_size_override("font_size", 15)
	press_cb.toggled.connect(func(on: bool) -> void:
		Settings.pressure_on = on
		Sfx.play("ui"))
	vb.add_child(press_cb)

	# Revenge (v10.2): the fallen ride the border rim and lob bombs
	# back in. Off by default — it changes multiplayer endgames too.
	var rev_cb := CheckBox.new()
	rev_cb.text = "Revenge — the fallen bomb from the rim (multiplayer)"
	rev_cb.button_pressed = Settings.revenge_mode
	rev_cb.add_theme_font_size_override("font_size", 15)
	rev_cb.toggled.connect(func(on: bool) -> void:
		Settings.revenge_mode = on
		Sfx.play("ui"))
	vb.add_child(rev_cb)

	# Teams 2v2 (v10.2): the three ways four bombers pair up.
	var team_row := HBoxContainer.new()
	team_row.add_theme_constant_override("separation", 8)
	vb.add_child(team_row)
	var team_lbl := _make_label("Teams", 15, COL_TEXT, false, 0)
	team_lbl.custom_minimum_size = Vector2(170, 0)
	team_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	team_row.add_child(team_lbl)
	var team_val := _make_label(Settings.TEAM_LABELS[Settings.team_mode],
		15, COL_GOLD, true, 0)
	team_val.custom_minimum_size = Vector2(190, 0)
	for arrow: Array in [["‹", -1], ["›", 1]]:
		var ab := Button.new()
		ab.text = arrow[0]
		ab.add_theme_font_size_override("font_size", 18)
		ab.custom_minimum_size = Vector2(40, 0)
		_make_focusable(ab)
		var dir: int = arrow[1]
		ab.pressed.connect(func() -> void:
			Sfx.play("ui")
			Settings.team_mode = posmod(Settings.team_mode + dir, 4)
			team_val.text = Settings.TEAM_LABELS[Settings.team_mode])
		team_row.add_child(ab)
		if dir < 0:
			team_row.add_child(team_val)
	team_row.add_child(_make_label("needs four bombers", 11, COL_DIM, false, 0))

	# Bot difficulty (v10.2): "Hard" is the classic planner brain.
	var skill_row := HBoxContainer.new()
	skill_row.add_theme_constant_override("separation", 8)
	vb.add_child(skill_row)
	var skill_lbl := _make_label("Bot difficulty", 15, COL_TEXT, false, 0)
	skill_lbl.custom_minimum_size = Vector2(170, 0)
	skill_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	skill_row.add_child(skill_lbl)
	var skills := ["easy", "normal", "hard"]
	var skill_names := {"easy": "Easy", "normal": "Normal", "hard": "Hard"}
	var skill_val := _make_label(skill_names[Settings.bot_skill], 15,
		COL_GOLD, true, 0)
	skill_val.custom_minimum_size = Vector2(120, 0)
	for arrow: Array in [["‹", -1], ["›", 1]]:
		var ab := Button.new()
		ab.text = arrow[0]
		ab.add_theme_font_size_override("font_size", 18)
		ab.custom_minimum_size = Vector2(40, 0)
		_make_focusable(ab)
		var dir: int = arrow[1]
		ab.pressed.connect(func() -> void:
			Sfx.play("ui")
			var idx: int = skills.find(Settings.bot_skill)
			Settings.bot_skill = skills[posmod(idx + dir, skills.size())]
			skill_val.text = skill_names[Settings.bot_skill])
		skill_row.add_child(ab)
		if dir < 0:
			skill_row.add_child(skill_val)

	# Player colours: one swatch button per player; click opens a full
	# colour-map picker. The chosen colour tints the suit, bombs, flames,
	# explosion particles and victory splashes alike.
	var col_row := HBoxContainer.new()
	col_row.add_theme_constant_override("separation", 12)
	vb.add_child(col_row)
	var col_lbl := _make_label("Player colours", 15, COL_TEXT, false, 0)
	col_lbl.custom_minimum_size = Vector2(170, 0)
	col_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col_row.add_child(col_lbl)
	_color_btns = []
	for i in 4:
		var b := Button.new()
		b.text = "P%d" % (i + 1)
		b.custom_minimum_size = Vector2(62, 32)
		b.add_theme_font_size_override("font_size", 15)
		_make_focusable(b)
		_style_color_button(b, Settings.player_color(i))
		var pi := i
		b.pressed.connect(func() -> void:
			Sfx.play("ui")
			_open_color_picker(pi))
		col_row.add_child(b)
		_color_btns.append(b)

	# Per-seat bomb style (v8.9): each seat cycles Global → the six
	# costumes, previewed as that player's own tinted bomb. "G" follows
	# OPTIONS → Bomb style, so the one-knob workflow still works.
	var sty_row := HBoxContainer.new()
	sty_row.add_theme_constant_override("separation", 12)
	vb.add_child(sty_row)
	var sty_lbl := _make_label("Bomb styles", 15, COL_TEXT, false, 0)
	sty_lbl.custom_minimum_size = Vector2(170, 0)
	sty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	sty_row.add_child(sty_lbl)
	_bstyle_btns = []
	for i in 4:
		var sb := Button.new()
		sb.custom_minimum_size = Vector2(62, 32)
		sb.add_theme_font_size_override("font_size", 13)
		sb.add_theme_constant_override("icon_max_width", 24)
		_make_focusable(sb)
		var pi := i
		sb.pressed.connect(func() -> void:
			Sfx.play("ui")
			var order: Array = ["global"] + BomberArt.BOMB_STYLES
			var idx: int = order.find(Settings.player_bomb_style(pi))
			Settings.set_player_bomb_style(pi,
				order[(idx + 1) % order.size()])
			_refresh_bstyle_btns())
		sty_row.add_child(sb)
		_bstyle_btns.append(sb)
	_refresh_bstyle_btns()

	vb.add_child(_spacer(2))
	vb.add_child(_make_label("bonus = share of bricks hiding an item · dangerous = share of items that are skulls",
		12, COL_DIM, false, 0))
	vb.add_child(_make_label("arenas beyond %d×%d are for the SOLO HUNT only (1 player, no bots — the camera follows you);\nwith bots or more players everyone shares one screen and the arena clamps to fit" % [Settings.MULTI_MAX_W, Settings.MULTI_MAX_H],
		12, COL_DIM, false, 0))
	_pin_back(panel)  # pinned below the scroll — never scrolls away
	return panel


func _build_options_panel() -> PanelContainer:
	var panel := _make_overlay_panel()
	var vb := _scroll_body(panel)
	vb.add_theme_constant_override("separation", 10)
	vb.add_child(_make_label("OPTIONS", 24, COL_GOLD, true, 5))
	vb.add_child(_spacer(4))
	var audio_rows: Array = [
		["Music", "music_on", "music_volume", Settings.music_on, Settings.music_volume],
		["Sound FX", "sfx_on", "sfx_volume", Settings.sfx_on, Settings.sfx_volume],
	]
	for a: Array in audio_rows:
		var a_row := HBoxContainer.new()
		a_row.add_theme_constant_override("separation", 12)
		vb.add_child(a_row)
		var a_cb := CheckBox.new()
		a_cb.text = a[0]
		a_cb.button_pressed = a[3]
		a_cb.add_theme_font_size_override("font_size", 16)
		a_cb.custom_minimum_size = Vector2(130, 0)
		var a_on: String = a[1]
		a_cb.toggled.connect(func(on: bool) -> void:
			Settings.set(a_on, on)
			Sfx.play("ui"))
		a_row.add_child(a_cb)
		var a_sl := HSlider.new()
		a_sl.min_value = 0.0
		a_sl.max_value = 1.0
		a_sl.step = 0.05
		a_sl.value = a[4]
		a_sl.custom_minimum_size = Vector2(170, 0)
		a_sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var a_vol: String = a[2]
		a_sl.value_changed.connect(func(v: float) -> void:
			Settings.set(a_vol, v))
		a_row.add_child(a_sl)
	var toggles: Array = [
		["Fullscreen (F11)", "fullscreen", Settings.fullscreen],
		["Camera shake on explosions", "screen_shake", Settings.screen_shake],
		["Blast range hint (beginners)", "blast_hint", Settings.blast_hint],
		["Player number tags (multiplayer)", "player_tags", Settings.player_tags],
	]
	for t: Array in toggles:
		var cb := CheckBox.new()
		cb.text = t[0]
		cb.button_pressed = t[2]
		cb.add_theme_font_size_override("font_size", 16)
		var prop: String = t[1]
		cb.toggled.connect(func(on: bool) -> void:
			Settings.set(prop, on)
			Sfx.play("ui"))
		_opt_sync.append(func() -> void:
			cb.set_pressed_no_signal(Settings.get(prop)))
		vb.add_child(cb)
	# CONTROLS (v10.0): rebind the four keyboard clusters.
	var ctl := Button.new()
	ctl.text = "CONTROLS — rebind keys"
	ctl.add_theme_font_size_override("font_size", 14)
	ctl.custom_minimum_size = Vector2(0, 32)
	_make_focusable(ctl)
	ctl.pressed.connect(func() -> void:
		Sfx.play("ui")
		_close_panel(_options_panel)
		_open_panel(_controls_panel))
	vb.add_child(ctl)
	# Menu attract demo (v10.1): how long the bare menu sits quiet
	# before the bots take the stage. Off by default.
	var att_row := HBoxContainer.new()
	att_row.add_theme_constant_override("separation", 8)
	vb.add_child(att_row)
	var att_lbl := _make_label("Attract demo", 16, COL_TEXT, false, 0)
	att_lbl.custom_minimum_size = Vector2(130, 0)
	att_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	att_row.add_child(att_lbl)
	var att_steps: Array = [0, 30, 60, 120, 300]
	var att_names := {0: "Off", 30: "after 30 s", 60: "after 1 min",
		120: "after 2 min", 300: "after 5 min"}
	var att_val := _make_label(att_names.get(Settings.attract_idle,
		"after %d s" % Settings.attract_idle), 16, COL_GOLD, true, 0)
	att_val.custom_minimum_size = Vector2(150, 0)
	for arrow: Array in [["‹", -1], ["›", 1]]:
		var ab := Button.new()
		ab.text = arrow[0]
		ab.add_theme_font_size_override("font_size", 18)
		ab.custom_minimum_size = Vector2(40, 0)
		_make_focusable(ab)
		var dir: int = arrow[1]
		ab.pressed.connect(func() -> void:
			Sfx.play("ui")
			var idx: int = att_steps.find(Settings.attract_idle)
			if idx < 0:
				idx = 0
			idx = (idx + dir + att_steps.size()) % att_steps.size()
			Settings.attract_idle = att_steps[idx]
			att_val.text = att_names[Settings.attract_idle])
		att_row.add_child(ab)
		if dir < 0:
			att_row.add_child(att_val)
	att_row.add_child(_make_label("bots play the menu when idle — any key returns",
		11, COL_DIM, false, 0))

	# Arena tile skin cycler (v4.8, 50 skins + live preview in v4.9):
	# ‹ Classic › with a mini board swatch so you SEE what you pick.
	var skin_row := HBoxContainer.new()
	skin_row.add_theme_constant_override("separation", 8)
	vb.add_child(skin_row)
	var skin_lbl := _make_label("Arena tiles", 16, COL_TEXT, false, 0)
	skin_lbl.custom_minimum_size = Vector2(130, 0)
	skin_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	skin_row.add_child(skin_lbl)
	var skin_val := _make_label(TileArt.label(Settings.arena_skin),
		16, COL_GOLD, true, 0)
	skin_val.custom_minimum_size = Vector2(150, 0)
	# The preview: floor checker with one wall and two bricks, exactly
	# the textures the game will use. Redrawn on every cycle.
	var preview := Control.new()
	preview.custom_minimum_size = Vector2(96, 48)
	preview.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	preview.draw.connect(func() -> void:
		var skin := Settings.arena_skin
		var fc: Array = TileArt.floors(skin)
		var cs := 24.0
		for y in 2:
			for x in 4:
				preview.draw_rect(Rect2(x * cs, y * cs, cs, cs),
					fc[0] if (x + y) % 2 == 0 else fc[1])
		preview.draw_texture_rect(TileArt.wall(skin), Rect2(0, 0, cs, cs), false)
		preview.draw_texture_rect(TileArt.brick(skin), Rect2(cs * 2, 0, cs, cs), false)
		preview.draw_texture_rect(TileArt.brick(skin), Rect2(cs, cs, cs, cs), false)
		preview.draw_rect(Rect2(0, 0, cs * 4, cs * 2), Color(0, 0, 0, 0.55), false, 2.0))
	_skin_row_refresh = func() -> void:
		skin_val.text = TileArt.label(Settings.arena_skin)
		preview.queue_redraw()
	var cycle := func(dir: int) -> void:
		# Built-ins first, then YOUR arenas (v9.1) — one wheel for all.
		var pool := TileArt.all_skins()
		var idx := pool.find(Settings.arena_skin)
		idx = (idx + dir + pool.size()) % pool.size()
		Settings.arena_skin = pool[idx]
		_skin_row_refresh.call()
		Sfx.play("ui")
	for arrow: Array in [["‹", -1], ["›", 1]]:
		var ab := Button.new()
		ab.text = arrow[0]
		ab.add_theme_font_size_override("font_size", 18)
		ab.custom_minimum_size = Vector2(40, 0)
		_make_focusable(ab)
		var dir: int = arrow[1]
		ab.pressed.connect(func() -> void: cycle.call(dir))
		if dir < 0:
			skin_row.add_child(ab)
			skin_row.add_child(skin_val)
		else:
			skin_row.add_child(ab)
	skin_row.add_child(preview)
	var mk := Button.new()
	mk.text = "ARENA THEME MAKER"
	mk.add_theme_font_size_override("font_size", 14)
	mk.custom_minimum_size = Vector2(0, 32)
	_make_focusable(mk)
	# A quiet gold nudge — the one creative door in OPTIONS deserves it.
	var mksb := StyleBoxFlat.new()
	mksb.bg_color = Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.14)
	mksb.border_color = Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.55)
	mksb.set_border_width_all(1)
	mksb.set_corner_radius_all(6)
	mksb.set_content_margin_all(8)
	mk.add_theme_stylebox_override("normal", mksb)
	mk.add_theme_color_override("font_color", COL_GOLD)
	mk.pressed.connect(func() -> void:
		Sfx.play("ui")
		_close_panel(_options_panel)
		_open_maker())
	skin_row.add_child(mk)

	# v4.9: reroll the skin every round — worlds on shuffle. The scope
	# button (v9.8) picks the deck: everything / the shipped 50 / yours.
	var rand_row := HBoxContainer.new()
	rand_row.add_theme_constant_override("separation", 10)
	vb.add_child(rand_row)
	var rand_cb := CheckBox.new()
	rand_cb.text = "Random arena — new look every round"
	rand_cb.button_pressed = Settings.arena_random
	rand_cb.add_theme_font_size_override("font_size", 16)
	rand_cb.toggled.connect(func(on: bool) -> void:
		Settings.arena_random = on
		Sfx.play("ui"))
	rand_row.add_child(rand_cb)
	var scope_names := {"all": "from: everything", "builtin": "from: the 50",
		"mine": "from: my themes"}
	var scope_btn := Button.new()
	scope_btn.text = scope_names[Settings.arena_random_scope]
	scope_btn.add_theme_font_size_override("font_size", 13)
	scope_btn.custom_minimum_size = Vector2(150, 30)
	scope_btn.tooltip_text = "What the Random die draws from (my themes fall back to everything while you have none)"
	_make_focusable(scope_btn)
	scope_btn.pressed.connect(func() -> void:
		Sfx.play("ui")
		var order := ["all", "builtin", "mine"]
		Settings.arena_random_scope = order[
			(order.find(Settings.arena_random_scope) + 1) % order.size()]
		scope_btn.text = scope_names[Settings.arena_random_scope])
	rand_row.add_child(scope_btn)

	# Bomb style cycler (v5.1): five costumes for the same bomb — the
	# preview shows it in player 1's colours.
	var bomb_row := HBoxContainer.new()
	bomb_row.add_theme_constant_override("separation", 8)
	vb.add_child(bomb_row)
	var bomb_lbl := _make_label("Bomb style", 16, COL_TEXT, false, 0)
	bomb_lbl.custom_minimum_size = Vector2(130, 0)
	bomb_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	bomb_row.add_child(bomb_lbl)
	var bomb_val := _make_label(BomberArt.BOMB_LABELS[Settings.bomb_style],
		16, COL_GOLD, true, 0)
	bomb_val.custom_minimum_size = Vector2(150, 0)
	var bomb_prev := Control.new()
	bomb_prev.custom_minimum_size = Vector2(48, 48)
	bomb_prev.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bomb_prev.draw.connect(func() -> void:
		bomb_prev.draw_texture_rect(
			BomberArt.bomb_texture(Settings.player_color(0), Settings.bomb_style),
			Rect2(2, 2, 44, 44), false))
	var bomb_cycle := func(dir: int) -> void:
		var idx: int = BomberArt.BOMB_STYLES.find(Settings.bomb_style)
		idx = (idx + dir + BomberArt.BOMB_STYLES.size()) % BomberArt.BOMB_STYLES.size()
		Settings.bomb_style = BomberArt.BOMB_STYLES[idx]
		bomb_val.text = BomberArt.BOMB_LABELS[Settings.bomb_style]
		bomb_prev.queue_redraw()
		_refresh_bstyle_btns()  # "G" seats in BATTLE SETUP follow along
		Sfx.play("ui")
	for arrow: Array in [["‹", -1], ["›", 1]]:
		var ab := Button.new()
		ab.text = arrow[0]
		ab.add_theme_font_size_override("font_size", 18)
		ab.custom_minimum_size = Vector2(40, 0)
		_make_focusable(ab)
		var dir: int = arrow[1]
		ab.pressed.connect(func() -> void: bomb_cycle.call(dir))
		if dir < 0:
			bomb_row.add_child(ab)
			bomb_row.add_child(bomb_val)
		else:
			bomb_row.add_child(ab)
	bomb_row.add_child(bomb_prev)

	_pin_back(panel)  # pinned below the scroll — never scrolls away
	return panel


func _build_help_panel() -> PanelContainer:
	var panel := _make_overlay_panel()
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 9)
	panel.add_child(vb)
	vb.add_child(_make_label("HOW TO PLAY", 24, COL_GOLD, true, 5))
	vb.add_child(_spacer(2))
	vb.add_child(_make_label(
		"Drop bombs, blast bricks, grab power-ups, and be the last bomber\nstanding. Solo: kill every monster, then find the exit portal hidden\nunder a brick and step through. Beware the skull — it curses you.\nAnd do NOT bomb the doorway. It bombs back.",
		15, COL_DIM, false, 0))
	vb.add_child(_spacer(8))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 30)
	grid.add_theme_constant_override("v_separation", 8)
	vb.add_child(grid)
	for p in 4:
		var a := _make_label("Player %d" % (p + 1), 16, COL_GOLD, false, 1)
		a.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		grid.add_child(a)
		var k := _make_label(Settings.player_key_text(p) + "   (or gamepad %d)" % (p + 1),
			16, COL_TEXT, false, 0)
		k.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		grid.add_child(k)
		var pp := p
		_opt_sync.append(func() -> void:
			k.text = Settings.player_key_text(pp) \
				+ "   (or gamepad %d)" % (pp + 1))
	for r: Array in [["Pause", "Esc  ·  pad START"],
			["Rematch", "R  ·  pad Y   (paused / battle over)"],
			["Next round now", "R  ·  pad Y   (round over)"],
			["Quit to menu", "Q  ·  pad BACK   (paused / battle over)"]]:
		var a := _make_label(r[0], 16, COL_GOLD, false, 1)
		a.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		grid.add_child(a)
		var k := _make_label(r[1], 16, COL_TEXT, false, 0)
		k.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		grid.add_child(k)
	vb.add_child(_spacer(8))
	vb.add_child(_make_label("after Dynablaster (Hudson Soft, 1991) — battle mode only, rebuilt from scratch",
		12, COL_DIM, false, 1))
	vb.add_child(_spacer(4))
	var back := Button.new()
	back.text = "BACK"
	back.add_theme_font_size_override("font_size", 16)
	back.pressed.connect(func() -> void: _close_panel(panel))
	vb.add_child(back)
	return panel


func _build_footer() -> void:
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 8)
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_root.add_child(footer)
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_top = -44.0
	footer.offset_bottom = -14.0
	footer.add_child(_make_label("a Prescription Games production", 13, COL_DIM, false, 2))
	var mini := TextureRect.new()
	mini.texture = load("res://assets/svg/caduceus.svg") as Texture2D
	mini.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mini.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mini.custom_minimum_size = Vector2(22, 22)
	mini.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_child(mini)
	footer.add_child(_make_label(VERSION, 13, COL_DIM, false, 1))


func _reveal_menu() -> void:
	var tw := create_tween()
	tw.tween_property(_menu_root, "modulate:a", 1.0, 0.45) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# Guarded: the TRY IT return opens the maker in the same _ready, and
	# a bare grab on the then-unfocusable START logged a warning (v12.2).
	_focus_start.call_deferred()


func _open_panel(panel: PanelContainer) -> void:
	Sfx.play("ui")
	_konami_idx = 0     # half-entered codes don't survive a panel
	_cheat_typed = ""
	if _pill_btn != null:
		_pill_btn.visible = false  # the pill waits outside any open panel
	panel.visible = true
	_cap_scroll(panel)  # size the scroll to the current screen before showing
	_menu_column.visible = false
	for b: Button in _main_buttons:
		b.focus_mode = Control.FOCUS_NONE
	for c: Node in panel.find_children("*", "Control", true, false):
		var ctl := c as Control
		if ctl != null and ctl.focus_mode == Control.FOCUS_ALL:
			ctl.grab_focus.call_deferred()
			break


func _close_panel(panel: PanelContainer) -> void:
	Sfx.play("ui")
	if _rebind_p >= 0:
		# An armed capture must not outlive its panel (v10.3): it would
		# silently rebind keys from OPTIONS and swallow the next ESC.
		_rebind_p = -1
		_rebind_d = -1
		_refresh_rebind_btns()
	if _color_pop != null and _color_pop.visible:
		_color_pop.hide()
	if _controls_status != null:
		_controls_status.text = ""  # no stale "press the new key…"
	panel.visible = false
	_menu_column.visible = true
	if _pill_btn != null:
		_pill_btn.visible = Settings.cabinet_unlocked
	for b: Button in _main_buttons:
		b.focus_mode = Control.FOCUS_ALL
	_focus_start.call_deferred()


## Deferred from _close_panel: by the time it runs, another panel may
## have opened in the same step (OPTIONS <-> CONTROLS / maker) and set
## the menu buttons to FOCUS_NONE — grabbing then only logs a warning.
func _focus_start() -> void:
	var start_btn := _menu_column.find_child("StartButton", true, false) as Button
	if start_btn != null and start_btn.focus_mode != Control.FOCUS_NONE \
			and start_btn.is_visible_in_tree():
		start_btn.grab_focus()


## Full colour-map picker in a popup; edits apply live so the swatch
## (and every downstream tint) follows the drag. The classic palette
## rides along as quick-pick presets.
## The seat buttons show the bomb each seat will ACTUALLY throw: the
## resolved style, tinted in that player's colour; "G" marks a seat
## following the global OPTIONS choice.
func _refresh_bstyle_btns() -> void:
	for i in _bstyle_btns.size():
		var b := _bstyle_btns[i]
		if not is_instance_valid(b):
			continue
		var raw := Settings.player_bomb_style(i)
		b.text = "G" if raw == "global" else ""
		b.icon = BomberArt.bomb_texture(Settings.player_color(i),
			Settings.bomb_style_for(i))
		b.tooltip_text = "P%d bombs: %s" % [i + 1,
			"Global (%s)" % BomberArt.BOMB_LABELS[Settings.bomb_style]
				if raw == "global" else str(BomberArt.BOMB_LABELS[raw])]


# ------------------------- ARENA MAKER (v9.1) ------------------------------
## Your own named arena theme: wall + brick from the shape library in
## YOUR colours (or your own PNGs), a floor tone, a music mood and a
## name — with THE DIE rolling colour-theory harmonies. Saved themes
## join the Arena tiles wheel and the Random pool, and travel as
## .dynarena files (EXPORT / IMPORT).

var _maker_status: Label

func _build_maker_panel() -> PanelContainer:
	var panel := _make_overlay_panel()
	var vb := _scroll_body(panel)
	vb.add_theme_constant_override("separation", 9)
	vb.add_child(_make_label("ARENA THEME MAKER", 24, COL_GOLD, true, 5))
	# NAME + its own die.
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	vb.add_child(name_row)
	name_row.add_child(_maker_lbl("Name"))
	var name_edit := LineEdit.new()
	name_edit.custom_minimum_size = Vector2(230, 34)
	name_edit.text_changed.connect(func(t: String) -> void:
		_maker_recipe["name"] = t)
	name_row.add_child(name_edit)
	var name_die := Button.new()
	name_die.icon = _die_icon_tex()
	name_die.add_theme_constant_override("icon_max_width", 24)
	name_die.tooltip_text = "Roll a name"
	name_die.custom_minimum_size = Vector2(44, 32)
	_make_focusable(name_die)
	name_die.pressed.connect(func() -> void:
		if bool(Settings.maker_locks.get("name", false)):
			Sfx.play("pickup_denied")
			_maker_status.text = "the name is locked"
			return
		Sfx.play("ui")
		_spin_die(name_die)
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		_maker_recipe["name"] = str(TileArt.random_recipe(rng)["name"])
		_maker_refresh.call())
	name_row.add_child(name_die)
	name_row.add_child(_lock_btn("name", "the name"))
	# WALL and BRICK element rows.
	var wall_r := _maker_element_row(vb, "wall", "Wall")
	var brick_r := _maker_element_row(vb, "brick", "Brick")
	# PNG guide (v10.3): one honest popup about the images the two PNG…
	# doors accept — count, formats, resolution, transparency.
	var png_help := Button.new()
	png_help.text = "?  what images work here"
	png_help.flat = true
	png_help.add_theme_font_size_override("font_size", 12)
	png_help.add_theme_color_override("font_color", COL_DIM)
	png_help.custom_minimum_size = Vector2(0, 22)
	_make_focusable(png_help)
	png_help.pressed.connect(_open_png_guide)
	var png_help_wrap := CenterContainer.new()
	png_help_wrap.visible = not OS.has_feature("web")
	png_help_wrap.add_child(png_help)
	vb.add_child(png_help_wrap)
	# FLOOR swatch (the checker pair derives from one tone).
	var floor_row := HBoxContainer.new()
	floor_row.add_theme_constant_override("separation", 8)
	vb.add_child(floor_row)
	floor_row.add_child(_maker_lbl("Floor"))
	var floor_sw := Button.new()
	floor_sw.custom_minimum_size = Vector2(44, 32)
	_make_focusable(floor_sw)
	floor_sw.pressed.connect(func() -> void:
		Sfx.play("ui")
		_open_color_for(_maker_recipe.get("floor_col", Color.GRAY),
			func(c: Color) -> void:
				_maker_recipe["floor_col"] = c
				_maker_refresh.call()))
	floor_row.add_child(floor_sw)
	floor_row.add_child(_lock_btn("floor", "the floor colour"))
	# MOOD cycler.
	var mood_row := HBoxContainer.new()
	mood_row.add_theme_constant_override("separation", 8)
	vb.add_child(mood_row)
	mood_row.add_child(_maker_lbl("Music mood"))
	var mood_val := _make_label("", 15, COL_GOLD, true, 0)
	mood_val.custom_minimum_size = Vector2(120, 0)
	for arrow: Array in [["‹", -1], ["›", 1]]:
		var ab := Button.new()
		ab.text = arrow[0]
		ab.add_theme_font_size_override("font_size", 18)
		ab.custom_minimum_size = Vector2(40, 0)
		_make_focusable(ab)
		var dir: int = arrow[1]
		ab.pressed.connect(func() -> void:
			Sfx.play("ui")
			var idx: int = TileArt.MOOD_KEYS.find(
				str(_maker_recipe.get("mood", "classic")))
			idx = (idx + dir + TileArt.MOOD_KEYS.size()) % TileArt.MOOD_KEYS.size()
			_maker_recipe["mood"] = TileArt.MOOD_KEYS[idx]
			_maker_refresh.call())
		mood_row.add_child(ab)
		if dir < 0:
			mood_row.add_child(mood_val)
	mood_row.add_child(_lock_btn("mood", "the music mood"))
	# THE DIE — just the die, big and central (v9.3); it SPINS when
	# thrown and rolls everything, colour-theory harmonized.
	var die := Button.new()
	die.icon = _die_icon_tex()
	die.add_theme_constant_override("icon_max_width", 44)
	die.custom_minimum_size = Vector2(60, 56)
	die.tooltip_text = "THE DIE — roll the whole arena"
	die.flat = true
	_make_focusable(die)
	die.pressed.connect(func() -> void:
		Sfx.play("item")
		_spin_die(die)
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		var rolled := TileArt.random_recipe(rng)
		# Locked rows stay exactly as the bench holds them (v9.8) — a
		# locked shape also holds its PNG.
		var keep := {"name": ["name"],
			"wall_shape": ["wall_shape", "wall_png"],
			"wall_col": ["wall_col"],
			"brick_shape": ["brick_shape", "brick_png"],
			"brick_col": ["brick_col"],
			"floor": ["floor_col"], "mood": ["mood"]}
		for lock: String in keep:
			if bool(Settings.maker_locks.get(lock, false)):
				for k: String in (keep[lock] as Array):
					if _maker_recipe.has(k):
						rolled[k] = _maker_recipe[k]
					else:
						rolled.erase(k)
		_maker_recipe = rolled
		_maker_refresh.call())
	var die_wrap := CenterContainer.new()
	die_wrap.add_child(die)
	vb.add_child(die_wrap)
	# The live board preview — the REAL raster path, legibility applied.
	# Textures are built in the REFRESH (a texture created inside _draw
	# renders white for that frame in the compatibility renderer); the
	# draw callback only paints what the bench prepared.
	var prevtex := {}
	var prev := Control.new()
	prev.custom_minimum_size = Vector2(200, 100)
	prev.draw.connect(func() -> void:
		var f: Color = prevtex.get("floor", Color.GRAY)
		var cs := 50.0
		for y in 2:
			for x in 4:
				prev.draw_rect(Rect2(x * cs, y * cs, cs, cs),
					f if (x + y) % 2 == 0 else f.lightened(0.07))
		if prevtex.has("wall"):
			prev.draw_texture_rect(prevtex["wall"], Rect2(0, 0, cs, cs), false)
			prev.draw_texture_rect(prevtex["brick"], Rect2(cs * 2, 0, cs, cs), false)
			prev.draw_texture_rect(prevtex["brick"], Rect2(cs, cs, cs, cs), false)
		prev.draw_rect(Rect2(0, 0, cs * 4, cs * 2), Color(0, 0, 0, 0.55), false, 2.0))
	var prev_wrap := CenterContainer.new()
	prev_wrap.add_child(prev)
	vb.add_child(prev_wrap)
	# SAVE / DELETE, then the share row.
	var act_row := HBoxContainer.new()
	act_row.alignment = BoxContainer.ALIGNMENT_CENTER
	act_row.add_theme_constant_override("separation", 8)
	vb.add_child(act_row)
	# CLASSIC: home base — the original look on the bench, ready to
	# tweak (keeps whatever name you already typed).
	var classicb := Button.new()
	classicb.text = "CLASSIC"
	classicb.tooltip_text = "Start from the original arena look"
	classicb.custom_minimum_size = Vector2(110, 36)
	_make_focusable(classicb)
	classicb.pressed.connect(func() -> void:
		Sfx.play("ui")
		var keep_name := str(_maker_recipe.get("name", "")).strip_edges()
		_maker_recipe = TileArt.classic_recipe()
		if not keep_name.is_empty():
			_maker_recipe["name"] = keep_name
		_maker_status.text = "the classic look is on the bench — make it yours"
		_maker_refresh.call())
	act_row.add_child(classicb)
	# TRY IT (v9.8): a real quick round — you + one bot — wearing the
	# UNSAVED bench theme; Q brings you straight back to this bench.
	var tryb := Button.new()
	tryb.text = "TRY IT"
	tryb.tooltip_text = "Play a quick round in this theme without saving (Q returns here)"
	tryb.custom_minimum_size = Vector2(90, 36)
	_make_focusable(tryb)
	tryb.pressed.connect(func() -> void:
		Sfx.play("portal")
		Settings.maker_bench_raw = _maker_recipe.duplicate()
		TileArt.set_bench(_maker_recipe)
		Settings.try_theme = true
		Settings.maker_edit_id = _maker_edit_id
		Settings.skip_splash_once = true
		get_tree().change_scene_to_file("res://scenes/main.tscn"))
	act_row.add_child(tryb)
	var saveb := Button.new()
	saveb.text = "SAVE && USE"
	saveb.custom_minimum_size = Vector2(150, 36)
	_make_focusable(saveb)
	saveb.pressed.connect(_maker_save)
	act_row.add_child(saveb)
	# SAVE COPY (v9.8): the bench becomes a NEW theme even while editing
	# an old one — tweak a favourite into a sibling without losing it.
	var copyb := Button.new()
	copyb.text = "SAVE COPY"
	copyb.custom_minimum_size = Vector2(120, 36)
	_make_focusable(copyb)
	copyb.pressed.connect(func() -> void: _maker_save(true))
	act_row.add_child(copyb)
	# YOUR THEMES (v9.3): browse everything you've saved, load one back
	# onto the bench, or delete the ones that didn't work out.
	var yours_row := HBoxContainer.new()
	yours_row.add_theme_constant_override("separation", 8)
	vb.add_child(yours_row)
	yours_row.add_child(_maker_lbl("Your themes"))
	var yours_val := _make_label("", 14, COL_GOLD, true, 0)
	yours_val.custom_minimum_size = Vector2(150, 0)
	var yours_idx := [0]   # boxed so the lambdas share it
	for arrow: Array in [["‹", -1], ["›", 1]]:
		var ab := Button.new()
		ab.text = arrow[0]
		ab.add_theme_font_size_override("font_size", 18)
		ab.custom_minimum_size = Vector2(40, 0)
		_make_focusable(ab)
		var dir: int = arrow[1]
		ab.pressed.connect(func() -> void:
			var ids := TileArt.user_ids()
			if ids.is_empty():
				return
			Sfx.play("ui")
			yours_idx[0] = (yours_idx[0] + dir + ids.size()) % ids.size()
			_maker_refresh.call())
		yours_row.add_child(ab)
		if dir < 0:
			yours_row.add_child(yours_val)
	var loadb := Button.new()
	loadb.text = "LOAD"
	loadb.custom_minimum_size = Vector2(66, 32)
	_make_focusable(loadb)
	loadb.pressed.connect(func() -> void:
		var ids := TileArt.user_ids()
		if ids.is_empty():
			return
		Sfx.play("ui")
		var id := str(ids[clampi(yours_idx[0], 0, ids.size() - 1)])
		_maker_edit_id = id
		_maker_recipe = TileArt.user_recipe(id)
		_maker_status.text = "'%s' is on the bench" % TileArt.label(id)
		_maker_refresh.call())
	yours_row.add_child(loadb)
	var delb := Button.new()
	delb.text = "DELETE"
	delb.custom_minimum_size = Vector2(84, 32)
	_make_focusable(delb)
	delb.pressed.connect(func() -> void:
		var ids := TileArt.user_ids()
		if ids.is_empty():
			return
		Sfx.play("brick")
		var id := str(ids[clampi(yours_idx[0], 0, ids.size() - 1)])
		var gone := TileArt.label(id)
		TileArt.delete_user(id)
		if Settings.arena_skin == id:
			Settings.arena_skin = "classic"
			_maker_opened_on = Settings.arena_skin  # the draft stays put (v12.2)
			_skin_row_refresh.call()
		if _maker_edit_id == id:
			_maker_edit_id = ""   # the bench keeps the recipe as a fresh draft
		_maker_status.text = "'%s' is gone — the wheel forgets it" % gone
		_maker_refresh.call())
	yours_row.add_child(delb)
	_maker_yours_refresh = func() -> void:
		var ids := TileArt.user_ids()
		if ids.is_empty():
			yours_val.text = "(none yet)"
			return
		if not _maker_focus_id.is_empty() and ids.has(_maker_focus_id):
			yours_idx[0] = ids.find(_maker_focus_id)
		_maker_focus_id = ""
		yours_idx[0] = clampi(yours_idx[0], 0, ids.size() - 1)
		yours_val.text = TileArt.label(str(ids[yours_idx[0]]))
	var share_row := HBoxContainer.new()
	share_row.alignment = BoxContainer.ALIGNMENT_CENTER
	share_row.add_theme_constant_override("separation", 8)
	vb.add_child(share_row)
	var expb := Button.new()
	expb.text = "EXPORT..."
	expb.custom_minimum_size = Vector2(140, 32)
	_make_focusable(expb)
	expb.pressed.connect(_maker_export)
	expb.visible = not OS.has_feature("web")   # no file dialogs in a browser
	share_row.add_child(expb)
	var impb := Button.new()
	impb.text = "IMPORT..."
	impb.custom_minimum_size = Vector2(140, 32)
	_make_focusable(impb)
	impb.pressed.connect(_maker_import)
	impb.visible = not OS.has_feature("web")
	share_row.add_child(impb)
	_maker_status = _make_label("", 13, COL_DIM, true, 0)
	vb.add_child(_maker_status)
	_maker_refresh = func() -> void:
		if name_edit.text != str(_maker_recipe.get("name", "")):
			name_edit.text = str(_maker_recipe.get("name", ""))
		wall_r.call()
		brick_r.call()
		_style_color_button(floor_sw, _maker_recipe.get("floor_col", Color.GRAY))
		floor_sw.text = ""
		mood_val.text = str(_maker_recipe.get("mood", "classic")).capitalize()
		_maker_yours_refresh.call()
		var rr := TileArt.ensure_legible(_maker_recipe.duplicate())
		prevtex["floor"] = rr.get("floor_col", Color.GRAY)
		prevtex["wall"] = TileArt.recipe_tex(rr, "wall")
		prevtex["brick"] = TileArt.recipe_tex(rr, "brick")
		prev.queue_redraw()
	# BACK steps to OPTIONS, not the menu (v9.8) — the tweak loop stays
	# tight. Bespoke footer instead of the generic _pin_back.
	var back := Button.new()
	back.text = "BACK"
	back.add_theme_font_size_override("font_size", 16)
	back.pressed.connect(func() -> void:
		_close_panel(_maker_panel)
		_open_panel(_options_panel))
	(panel.get_meta("back_host") as Node).add_child(back)
	return panel


## A thrown die SPINS (v9.3): one quick full turn with a scale pop —
## pivoted at the centre so it tumbles in place.
func _spin_die(b: Button) -> void:
	b.pivot_offset = b.size / 2.0
	b.rotation = 0.0
	var tw := b.create_tween()
	tw.tween_property(b, "rotation", TAU, 0.45) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(b, "scale", Vector2.ONE * 1.22, 0.2) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(b, "scale", Vector2.ONE, 0.22).set_delay(0.2)
	tw.tween_callback(func() -> void: b.rotation = 0.0)


## ------------------------- CONTROLS panel (v10.0) --------------------------
## Rebind the four keyboard clusters: click a key button, press its
## replacement. System keys (ESC/R/Q/H/Enter) are refused, twins are
## refused with the owner named; gamepads stay fixed (pad N = player N).
func _build_controls_panel() -> PanelContainer:
	var panel := _make_overlay_panel()
	var vb := _scroll_body(panel)
	vb.add_theme_constant_override("separation", 8)
	vb.add_child(_make_label("CONTROLS", 24, COL_GOLD, true, 5))
	vb.add_child(_make_label(
		"click a key, then press its replacement — keyboard only;\n"
		+ "gamepad N always drives player N (d-pad/stick + A)",
		12, COL_DIM, true, 0))
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	vb.add_child(head)
	var corner := _make_label("", 13, COL_DIM, false, 0)
	corner.custom_minimum_size = Vector2(52, 0)
	head.add_child(corner)
	for n: String in Settings.KEY_SLOT_NAMES:
		var h := _make_label(n, 13, COL_DIM, true, 0)
		h.custom_minimum_size = Vector2(88, 0)
		head.add_child(h)
	_rebind_btns = []
	for p in 4:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		vb.add_child(row)
		var pl := _make_label("P%d" % (p + 1), 16, Settings.player_color(p),
			false, 1)
		pl.custom_minimum_size = Vector2(52, 0)
		row.add_child(pl)
		var pcol := p
		_opt_sync.append(func() -> void:   # recoloured in BATTLE SETUP
			pl.add_theme_color_override("font_color", Settings.player_color(pcol)))
		var prow: Array = []
		for d in 5:
			var kb := Button.new()
			kb.custom_minimum_size = Vector2(88, 34)
			kb.add_theme_font_size_override("font_size", 13)
			_make_focusable(kb)
			var pp := p
			var dd := d
			kb.pressed.connect(func() -> void:
				Sfx.play("ui")
				_rebind_p = pp
				_rebind_d = dd
				# Focus would EAT space/enter/arrows before the capture
				# sees them — the very keys people rebind. Drop it.
				kb.release_focus()
				_refresh_rebind_btns()
				_controls_status.text = "press the new key for P%d %s (ESC keeps the old one)" \
					% [pp + 1, Settings.KEY_SLOT_NAMES[dd]])
			row.add_child(kb)
			prow.append(kb)
		_rebind_btns.append(prow)
	_controls_status = _make_label("", 13, COL_DIM, true, 0)
	vb.add_child(_controls_status)
	var rst := Button.new()
	rst.text = "RESET TO DEFAULTS"
	rst.add_theme_font_size_override("font_size", 14)
	rst.custom_minimum_size = Vector2(0, 32)
	_make_focusable(rst)
	rst.pressed.connect(func() -> void:
		Sfx.play("brick")
		_rebind_p = -1   # a click-armed slot must not eat the next key
		_rebind_d = -1
		Settings.reset_player_keys()
		_refresh_rebind_btns()
		_controls_status.text = "the factory clusters are back")
	vb.add_child(rst)
	var back := Button.new()
	back.text = "BACK"
	back.add_theme_font_size_override("font_size", 16)
	back.pressed.connect(func() -> void:
		_close_panel(_controls_panel)
		_open_panel(_options_panel))
	(panel.get_meta("back_host") as Node).add_child(back)
	_refresh_rebind_btns()
	return panel


func _refresh_rebind_btns() -> void:
	for p in 4:
		for d in 5:
			var b: Button = _rebind_btns[p][d]
			if not is_instance_valid(b):
				continue
			b.text = "..." if (p == _rebind_p and d == _rebind_d) \
				else OS.get_keycode_string(
					Settings.key_label_code(Settings.player_key(p, d)))


## Padlocks (v9.8, the NPC Studio pattern): a locked row is THE DIE's
## no-go zone. Gold closed lock = held; grey open lock = free to roll.
## Lock state lives in Settings.maker_locks (transient) so it survives
## the TRY IT scene round-trip.
var _lock_tex: Array = [null, null]   # [unlocked, locked]

func _lock_icon_tex(locked: bool) -> Texture2D:
	var idx := 1 if locked else 0
	if _lock_tex[idx] != null:
		return _lock_tex[idx]
	var svg: String
	if locked:
		svg = """<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">
<path d="M20 30 V22 Q20 10 32 10 Q44 10 44 22 V30" fill="none" stroke="#f2c94c" stroke-width="7"/>
<rect x="14" y="28" width="36" height="28" rx="7" fill="#f2c94c"/>
<circle cx="32" cy="40" r="4.4" fill="#101018"/>
<rect x="30" y="42" width="4" height="8" rx="2" fill="#101018"/></svg>"""
	else:
		svg = """<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">
<path d="M24 28 V20 Q24 8 36 8 Q48 8 48 20" fill="none" stroke="#6d7382" stroke-width="6"/>
<rect x="14" y="28" width="34" height="26" rx="7" fill="none" stroke="#6d7382" stroke-width="4"/>
<circle cx="31" cy="39" r="3.6" fill="#6d7382"/></svg>"""
	var img := Image.new()
	if img.load_svg_from_string(svg, 1.5) != OK:
		return null
	_lock_tex[idx] = ImageTexture.create_from_image(img)
	return _lock_tex[idx]


func _lock_btn(key: String, what: String) -> Button:
	var b := Button.new()
	b.flat = true
	b.custom_minimum_size = Vector2(30, 30)
	b.add_theme_constant_override("icon_max_width", 20)
	b.icon = _lock_icon_tex(bool(Settings.maker_locks.get(key, false)))
	b.tooltip_text = "Lock %s — THE DIE keeps it as is" % what
	_make_focusable(b)
	b.pressed.connect(func() -> void:
		Sfx.play("ui")
		Settings.maker_locks[key] = not bool(Settings.maker_locks.get(key, false))
		b.icon = _lock_icon_tex(bool(Settings.maker_locks[key])))
	return b


## The maker's game die, drawn in code like everything else: a white
## five-pip die with a soft shadow and a playful tilt. Rasterized once.
var _die_icon: Texture2D

func _die_icon_tex() -> Texture2D:
	if _die_icon != null:
		return _die_icon
	var svg := """<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">
<ellipse cx="33" cy="56" rx="20" ry="4" fill="#000" opacity="0.25"/>
<g transform="rotate(-10 32 32)">
<rect x="10" y="10" width="44" height="44" rx="10" fill="#101018"/>
<rect x="12" y="12" width="40" height="40" rx="8" fill="#fbfbfd"/>
<path d="M12 30 Q12 12 30 12 L44 12 Q40 24 30 30 Q22 34 12 30 Z" fill="#ffffff"/>
<path d="M52 28 Q52 52 30 52 L44 52 Q52 52 52 44 Z" fill="#d8d8e2"/>
<g fill="#14141c">
<circle cx="22" cy="22" r="4.2"/><circle cx="42" cy="22" r="4.2"/>
<circle cx="32" cy="32" r="4.2"/>
<circle cx="22" cy="42" r="4.2"/><circle cx="42" cy="42" r="4.2"/>
</g></g></svg>"""
	var img := Image.new()
	if img.load_svg_from_string(svg, 2.0) != OK:
		return null
	_die_icon = ImageTexture.create_from_image(img)
	return _die_icon


## The PNG guide (v10.3): everything a player needs to know before
## pointing the maker at their own images. Built once, popped on tap.
var _png_guide: PopupPanel

func _open_png_guide() -> void:
	Sfx.play("ui")
	if _png_guide == null:
		_png_guide = PopupPanel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("0d1630")
		sb.border_color = COL_GOLD
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(10)
		sb.set_content_margin_all(18)
		_png_guide.add_theme_stylebox_override("panel", sb)
		var gvb := VBoxContainer.new()
		gvb.add_theme_constant_override("separation", 9)
		gvb.add_child(_make_label("YOUR OWN TILES", 20, COL_GOLD, true, 3))
		for line: String in [
			"You need at most TWO images per theme — one for the WALL, "
				+ "one for the BRICK. Either row may keep a library shape "
				+ "instead.",
			"PNG, JPG or WebP go in; the image is stored as PNG inside "
				+ "the theme itself — SAVE keeps it, EXPORT ships it inside "
				+ "the .dynarena file, nothing else to send.",
			"Any resolution works: everything is normalized to the square "
				+ "128×128 tile canvas, so SQUARE sources look best "
				+ "(non-square gets stretched). Keep files under 512 KB.",
			"Transparency is honoured: a transparent background makes an "
				+ "'organic' tile — the floor shows through, like the "
				+ "built-in bushes and barrels.",
			"House rule: the WALL should read darker and calmer, the "
				+ "BRICK brighter and busier — they must tell apart at a "
				+ "squint.",
			"Changed your mind? Cycle that row's shape and the image is "
				+ "dropped.",
		]:
			var l := _make_label("·  " + line, 13, COL_TEXT, false, 0)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size = Vector2(530, 0)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			gvb.add_child(l)
		var closeb := Button.new()
		closeb.text = "GOT IT"
		closeb.add_theme_font_size_override("font_size", 15)
		closeb.custom_minimum_size = Vector2(0, 32)
		_make_focusable(closeb)
		closeb.pressed.connect(func() -> void:
			Sfx.play("ui")
			_png_guide.hide())
		gvb.add_child(closeb)
		_png_guide.add_child(gvb)
		add_child(_png_guide)
	_png_guide.popup_centered()
	# Keyboard/pad reach (the colour popup does the same): without a
	# focused control, GOT IT was mouse-only.
	var got_it := _png_guide.find_children("*", "Button", true, false)
	if not got_it.is_empty():
		(got_it[0] as Button).grab_focus.call_deferred()


func _maker_lbl(text: String) -> Label:
	var l := _make_label(text, 16, COL_TEXT, false, 0)
	l.custom_minimum_size = Vector2(130, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return l


## One element (wall/brick): ‹ shape › + colour swatch + "PNG...".
## Returns the row's refresh callable.
func _maker_element_row(vb: VBoxContainer, el: String, title: String) -> Callable:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	vb.add_child(row)
	row.add_child(_maker_lbl(title))
	var shape_val := _make_label("", 15, COL_GOLD, true, 0)
	shape_val.custom_minimum_size = Vector2(150, 0)
	for arrow: Array in [["‹", -1], ["›", 1]]:
		var ab := Button.new()
		ab.text = arrow[0]
		ab.add_theme_font_size_override("font_size", 18)
		ab.custom_minimum_size = Vector2(40, 0)
		_make_focusable(ab)
		var dir: int = arrow[1]
		ab.pressed.connect(func() -> void:
			Sfx.play("ui")
			_maker_recipe.erase(el + "_png")   # back to the shape library
			var idx: int = TileSvg.USER_SHAPES.find(
				str(_maker_recipe.get(el + "_shape", "bevel")))
			idx = (idx + dir + TileSvg.USER_SHAPES.size()) % TileSvg.USER_SHAPES.size()
			_maker_recipe[el + "_shape"] = TileSvg.USER_SHAPES[idx]
			_maker_refresh.call())
		row.add_child(ab)
		if dir < 0:
			row.add_child(shape_val)
	row.add_child(_lock_btn(el + "_shape", "the %s shape" % el))
	var sw := Button.new()
	sw.custom_minimum_size = Vector2(44, 32)
	_make_focusable(sw)
	sw.pressed.connect(func() -> void:
		Sfx.play("ui")
		_open_color_for(_maker_recipe.get(el + "_col", Color.GRAY),
			func(c: Color) -> void:
				_maker_recipe[el + "_col"] = c
				_maker_refresh.call()))
	row.add_child(sw)
	row.add_child(_lock_btn(el + "_col", "the %s colour" % el))
	var pngb := Button.new()
	pngb.text = "PNG..."
	pngb.custom_minimum_size = Vector2(70, 32)
	pngb.tooltip_text = "Use your own image as the %s (cycle the shape to drop it)" % el
	_make_focusable(pngb)
	pngb.pressed.connect(func() -> void: _maker_png_dialog(el))
	pngb.visible = not OS.has_feature("web")   # no file dialogs in a browser
	row.add_child(pngb)
	return func() -> void:
		var has_png: bool = not (_maker_recipe.get(el + "_png",
			PackedByteArray()) as PackedByteArray).is_empty()
		shape_val.text = "your PNG" if has_png else str(
			TileSvg.USER_SHAPE_NAMES.get(
				str(_maker_recipe.get(el + "_shape", "bevel")), "?"))
		_style_color_button(sw, _maker_recipe.get(el + "_col", Color.GRAY))
		sw.text = ""


## The wheel's theme when the maker last opened: stepping BACK to
## OPTIONS (or B) and returning must find the bench as it was left —
## re-rolling on every open discarded unsaved work (v11.8). A fresh
## bench only when there is none, or the wheel moved meanwhile.
var _maker_opened_on := ""


func _open_maker() -> void:
	if not _maker_recipe.is_empty() and Settings.arena_skin == _maker_opened_on:
		_maker_status.text = ""
		_maker_refresh.call()
		_open_panel(_maker_panel)
		return
	_maker_opened_on = Settings.arena_skin
	if TileArt.is_user(Settings.arena_skin):
		# The wheel sits on one of YOURS — open it on the bench.
		_maker_edit_id = Settings.arena_skin
		_maker_recipe = TileArt.user_recipe(Settings.arena_skin)
	else:
		_maker_edit_id = ""
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		_maker_recipe = TileArt.random_recipe(rng)
	_maker_status.text = ""
	_maker_refresh.call()
	_open_panel(_maker_panel)


func _maker_save(as_copy := false) -> void:
	Sfx.play("ui")
	var id := TileArt.save_user(_maker_recipe, "" if as_copy else _maker_edit_id)
	if id.is_empty():
		_maker_status.text = "give it a name first"
		return
	_maker_edit_id = id
	_maker_recipe = TileArt.user_recipe(id)  # pick up legibility/name nudges
	Settings.arena_skin = id
	_maker_opened_on = id   # BACK + reopen keeps tweaks made after SAVE (v12.2)
	_maker_focus_id = id
	_skin_row_refresh.call()
	_maker_refresh.call()
	Sfx.play("win")
	_maker_status.text = ("saved a COPY — '%s' joins the wheel" if as_copy
		else "saved — '%s' is on the Arena tiles wheel") % TileArt.label(id)


func _maker_png_dialog(el: String) -> void:
	Sfx.play("ui")
	var fd := _maker_file_dialog(FileDialog.FILE_MODE_OPEN_FILE,
		"Use an image as the %s" % el, "*.png, *.jpg, *.jpeg, *.webp ; Images")
	fd.file_selected.connect(func(path: String) -> void:
		var img := Image.new()
		if img.load(path) == OK:
			img.resize(128, 128, Image.INTERPOLATE_LANCZOS)
			if img.get_format() != Image.FORMAT_RGBA8:
				img.convert(Image.FORMAT_RGBA8)
			_maker_recipe[el + "_png"] = img.save_png_to_buffer()
			_maker_status.text = "your image is the %s now" % el
			_maker_refresh.call()
		else:
			_maker_status.text = "could not read that image"
		fd.queue_free())
	fd.canceled.connect(fd.queue_free)
	fd.popup_centered()


func _maker_export() -> void:
	Sfx.play("ui")
	# The bench state ships — but only into the FILE (v11.8): saving it
	# into your themes first meant a cancelled dialog had already
	# overwritten the theme being edited. SAVE is SAVE's job.
	if str(_maker_recipe.get("name", "")).strip_edges().is_empty():
		_maker_status.text = "give it a name first"
		return
	var bench := _maker_recipe.duplicate()
	var fd := _maker_file_dialog(FileDialog.FILE_MODE_SAVE_FILE,
		"Export arena theme", "*.dynarena ; DynaMan arena theme")
	# A safe file name: "AC/DC" must not point into a folder (v12.2).
	fd.current_file = TileArt._sanitize_id(str(bench["name"]).strip_edges()) + ".dynarena"
	fd.file_selected.connect(func(path: String) -> void:
		if not path.ends_with(".dynarena"):
			path += ".dynarena"
		var err := TileArt.export_recipe(bench, path)
		_maker_status.text = "exported %s — share it, they IMPORT it" % path.get_file() \
			if err.is_empty() else err
		fd.queue_free())
	fd.canceled.connect(fd.queue_free)
	fd.popup_centered()


func _maker_import() -> void:
	Sfx.play("ui")
	var fd := _maker_file_dialog(FileDialog.FILE_MODE_OPEN_FILE,
		"Import arena theme(s)", "*.dynarena ; DynaMan arena theme")
	fd.file_selected.connect(func(path: String) -> void:
		var got := TileArt.import_user(path)
		if got.is_empty():
			_maker_status.text = "that file holds no arena themes"
		else:
			_maker_edit_id = str(got[0])
			_maker_recipe = TileArt.user_recipe(str(got[0]))
			Settings.arena_skin = str(got[0])
			_maker_opened_on = Settings.arena_skin
			_maker_focus_id = str(got[0])
			_skin_row_refresh.call()
			_maker_refresh.call()
			Sfx.play("win")
			_maker_status.text = "imported %d theme%s — '%s' is on the wheel" \
				% [got.size(), "" if got.size() == 1 else "s",
				TileArt.label(str(got[0]))]
		fd.queue_free())
	fd.canceled.connect(fd.queue_free)
	fd.popup_centered()


func _maker_file_dialog(mode: FileDialog.FileMode, title: String,
		filter: String) -> FileDialog:
	var fd := FileDialog.new()
	fd.file_mode = mode
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.filters = [filter]
	fd.title = title
	fd.size = Vector2(760, 520)
	add_child(fd)
	return fd


func _open_color_picker(pi: int) -> void:
	if _color_pop == null:
		_color_pop = PopupPanel.new()
		# Solid panel — the default popup style is translucent and the
		# picker was hard to read over the setup panel behind it.
		var pop_sb := StyleBoxFlat.new()
		pop_sb.bg_color = Color("0d1630")
		pop_sb.border_color = Color("e8b020")
		pop_sb.set_border_width_all(2)
		pop_sb.set_corner_radius_all(10)
		pop_sb.set_content_margin_all(14)
		_color_pop.add_theme_stylebox_override("panel", pop_sb)
		var pick_vb := VBoxContainer.new()
		pick_vb.add_theme_constant_override("separation", 8)
		# The pad lane (v10.1): the ColorPicker's innards are rough with
		# a gamepad — a row of focusable classic swatches + OK makes the
		# popup fully drivable from the couch. First swatch gets focus.
		var srow := HBoxContainer.new()
		srow.add_theme_constant_override("separation", 6)
		srow.alignment = BoxContainer.ALIGNMENT_CENTER
		for c: Color in Settings.PALETTE:
			var swb := Button.new()
			swb.custom_minimum_size = Vector2(34, 30)
			_make_focusable(swb)
			_style_color_button(swb, c)
			var cc := c
			swb.pressed.connect(func() -> void:
				Sfx.play("ui")
				_color_picker.color = cc
				_on_picker_color(cc))
			srow.add_child(swb)
			if _color_first_swatch == null:
				_color_first_swatch = swb
		pick_vb.add_child(srow)
		_color_picker = ColorPicker.new()
		_color_picker.edit_alpha = false
		_color_picker.edit_intensity = false  # no HDR tints — they'd blow out the glow
		_color_picker.sampler_visible = false
		_color_picker.color_modes_visible = false
		_color_picker.hex_visible = true
		_color_picker.presets_visible = true
		for c: Color in Settings.PALETTE:
			_color_picker.add_preset(c)
		_color_picker.color_changed.connect(_on_picker_color)
		pick_vb.add_child(_color_picker)
		# Edits apply live, so OK just confirms and closes.
		var ok := Button.new()
		ok.text = "OK"
		ok.add_theme_font_size_override("font_size", 16)
		ok.pressed.connect(func() -> void:
			Sfx.play("ui")
			_color_pop.hide())
		pick_vb.add_child(ok)
		_color_pop.add_child(pick_vb)
		add_child(_color_pop)
	_color_cb = Callable()   # a PLAYER edit — clear any maker routing
	_color_target = pi
	_color_picker.color = Settings.player_color(pi)
	_color_pop.popup_centered()
	if _color_first_swatch != null:
		_color_first_swatch.grab_focus.call_deferred()


## Reuse the same popup for ANY colour edit (v9.1, the Arena Maker's
## swatches): live changes route into `cb` instead of a player slot.
func _open_color_for(current: Color, cb: Callable) -> void:
	_open_color_picker(0)    # builds the popup lazily, pops it centered
	_color_target = -1
	_color_cb = cb
	_color_picker.color = current


func _on_picker_color(col: Color) -> void:
	if _color_cb.is_valid():
		_color_cb.call(col)
		return
	if _color_target < 0:
		return
	Settings.set_player_color(_color_target, col)
	if _color_target < _color_btns.size() and is_instance_valid(_color_btns[_color_target]):
		_style_color_button(_color_btns[_color_target], Settings.player_color(_color_target))
	_refresh_bstyle_btns()  # the seat's bomb preview wears the new tint


## Paint a player swatch button in that player's colour, keeping the
## text readable on light swatches.
func _style_color_button(b: Button, col: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(6)
	sb.border_color = Color(1, 1, 1, 0.5)
	sb.set_border_width_all(1)
	# NOT "focus": that slot holds _make_focusable's gold ring, drawn on
	# top of the swatch — overriding it made a focused swatch invisible.
	for style in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(style, sb)
	var dark_text := col.get_luminance() > 0.55
	b.add_theme_color_override("font_color", Color.BLACK if dark_text else Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.BLACK if dark_text else Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.BLACK if dark_text else Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color.BLACK if dark_text else Color.WHITE)


## Highlight whichever preset matches the current arena size — or the
## Custom indicator when the sliders wandered off both presets.
func _update_preset_marks() -> void:
	var matched := false
	for pair: Array in _preset_btns:
		var active: bool = Settings.arena_w == pair[1][1] \
			and Settings.arena_h == pair[1][2]
		_style_preset_btn(pair[0], active)
		matched = matched or active
	if _custom_btn != null:
		_style_preset_btn(_custom_btn, not matched)


func _style_preset_btn(b: Button, active: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	if active:
		sb.bg_color = Color(0.24, 0.20, 0.06, 0.95)
		sb.border_color = COL_GOLD
		sb.set_border_width_all(2)
	else:
		sb.bg_color = Color(0.05, 0.08, 0.19, 0.75)
		sb.border_color = Color(COL_DIM.r, COL_DIM.g, COL_DIM.b, 0.35)
		sb.set_border_width_all(1)
	for style in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(style, sb)
	var fcol := COL_GOLD if active else COL_DIM
	for fstyle in ["font_color", "font_hover_color", "font_pressed_color",
			"font_disabled_color"]:
		b.add_theme_color_override(fstyle, fcol)


## Presets change several Settings at once; rebuilding the panel is the
## simplest way to refresh every slider's position and value label.
func _rebuild_setup_panel(refocus := "") -> void:
	var was_open := _setup_panel.visible
	_setup_panel.get_parent().queue_free()  # frees the CenterContainer wrap
	_setup_panel = _build_setup_panel()
	if was_open:
		_open_panel(_setup_panel)
		# A pad/keyboard press on "Wide" must leave focus ON Wide, not
		# snap back to the first preset (a second A undid the choice).
		for pr: Array in _preset_btns:
			if (pr[0] as Button).text == refocus:
				(pr[0] as Button).grab_focus.call_deferred()


# -------------------------------------------------------------- helpers -----

## Wrap a panel's content in a vertical ScrollContainer so a long list of
## settings never runs off a 720p screen. Returns the inner VBox the caller
## fills with setting rows; the BACK button is pinned BELOW the scroll (via
## _pin_back) so it stays on screen no matter how far you scroll. The scroll
## region is height-capped in _cap_scroll when the panel opens.
func _scroll_body(panel: PanelContainer) -> VBoxContainer:
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	panel.add_child(outer)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	outer.add_child(scroll)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vb)
	panel.set_meta("scroll", scroll)
	panel.set_meta("back_host", outer)
	return vb


## Add the BACK button. In a scrollable panel it rides in the pinned footer
## (below the scroll) so it never scrolls away; plain panels keep it inline.
func _pin_back(panel: PanelContainer) -> void:
	var back := Button.new()
	back.text = "BACK"
	back.add_theme_font_size_override("font_size", 16)
	back.pressed.connect(func() -> void: _close_panel(panel))
	var host: Node = panel.get_meta("back_host", panel)
	host.add_child(back)


## Size a panel's scroll region to its content, but never taller than the
## screen allows — that is what makes the scrollbar appear only when the
## settings actually overflow (and stay hidden when they fit). The pinned
## BACK button and panel chrome are kept off-limits so nothing clips.
func _cap_scroll(panel: PanelContainer) -> void:
	if not panel.has_meta("scroll"):
		return  # panels that don't use _scroll_body (help) opt out here
	var scroll := panel.get_meta("scroll") as ScrollContainer
	if scroll == null or scroll.get_child_count() == 0:
		return
	var vb := scroll.get_child(0) as Control
	var m := vb.get_combined_minimum_size()
	# _menu_root fills the screen, so its height is the UI-space viewport
	# height (720 units at the base) regardless of the window's pixel size.
	# Reserve room for the panel margins + pinned BACK + a breathing margin.
	var cap: float = _menu_root.size.y - 128.0
	scroll.custom_minimum_size = Vector2(m.x + 18.0, minf(m.y, maxf(cap, 200.0)))


## The word was spoken (or the code played): rattle the pills, shake
## the shelf, swing the cabinet open.
func _open_cabinet() -> void:
	Settings.cabinet_unlocked = true
	Sfx.play("rattle")
	var tw := create_tween()
	for i in 4:
		tw.tween_property(_menu_root, "position",
			Vector2(6.0 if i % 2 == 0 else -6.0, 0), 0.04)
	tw.tween_property(_menu_root, "position", Vector2.ZERO, 0.04)
	_open_panel(_cheat_panel)
	_refresh_cheat_rows()


## A tiny pixel pill bottle in the cheat's own colour: white cap,
## cream label — vivid when the bottle is open, ashen when sealed.
func _bottle_tex(base: Color, open: bool) -> ImageTexture:
	var img := Image.create(13, 17, false, Image.FORMAT_RGBA8)
	var body := base if open else base.lerp(Color(0.44, 0.43, 0.41), 0.45).darkened(0.2)
	var cap := Color(0.92, 0.93, 0.95) if open else Color(0.6, 0.6, 0.62)
	var label := Color(0.97, 0.94, 0.85) if open else Color(0.55, 0.54, 0.5)
	var mark := Color(0.85, 0.25, 0.2) if open else Color(0.4, 0.4, 0.4)
	for x in range(4, 9):
		for y in range(0, 3):
			img.set_pixel(x, y, cap)
	for x in range(2, 11):
		for y in range(3, 17):
			if (y == 3 or y == 16) and (x == 2 or x == 10):
				continue  # rounded corners
			img.set_pixel(x, y, body)
	for x in range(3, 10):
		for y in range(7, 12):
			img.set_pixel(x, y, label)
	img.set_pixel(6, 8, mark)
	img.set_pixel(6, 9, mark)
	img.set_pixel(6, 10, mark)
	img.set_pixel(5, 9, mark)
	img.set_pixel(7, 9, mark)
	return ImageTexture.create_from_image(img)


func _build_cheat_panel() -> PanelContainer:
	var panel := _make_overlay_panel()
	# The pharmacy wears clinical mint-on-teal, not the menu's navy —
	# stepping in here should feel like slipping backstage.
	var sb := panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	sb.bg_color = Color(0.03, 0.13, 0.11, 0.96)
	sb.border_color = Color(0.5, 0.9, 0.72, 0.5)
	panel.add_theme_stylebox_override("panel", sb)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)
	var title := _make_label("THE MEDICINE CABINET", 30, Color(0.62, 0.95, 0.78), true, 4)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	var sub := _make_label("Rx  ·  take as directed  ·  wears off when the game closes",
		13, Color(0.5, 0.72, 0.62), false, 1)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sub)
	vb.add_child(HSeparator.new())
	for c: Dictionary in CHEATS:
		var id: String = c["id"]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var tex_on := _bottle_tex(c["col"], true)
		var tex_off := _bottle_tex(c["col"], false)
		var icon := TextureRect.new()
		icon.texture = tex_off
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.custom_minimum_size = Vector2(34, 44)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		var txt := VBoxContainer.new()
		txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		txt.add_theme_constant_override("separation", 0)
		var nm := _make_label(c["name"], 19, COL_TEXT, true, 2)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		txt.add_child(nm)
		var ds := _make_label(c["desc"], 12, Color(0.55, 0.7, 0.63), false, 0)
		ds.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		txt.add_child(ds)
		row.add_child(txt)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(120, 40)
		btn.add_theme_font_size_override("font_size", 15)
		_make_focusable(btn)
		btn.pressed.connect(func() -> void:
			var now_on: bool = not Settings.cheats.get(id, false)
			Settings.cheats[id] = now_on
			Sfx.play("item" if now_on else "ui")
			_refresh_cheat_rows())
		row.add_child(btn)
		vb.add_child(row)
		_cheat_rows[id] = {"btn": btn, "icon": icon, "row": row,
			"tex_on": tex_on, "tex_off": tex_off}
	vb.add_child(HSeparator.new())
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 16)
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	var seal := _make_menu_button("SEAL ALL")
	seal.custom_minimum_size = Vector2(180, 40)
	seal.pressed.connect(func() -> void:
		Settings.cheats.clear()
		Sfx.play("ui")
		_refresh_cheat_rows())
	foot.add_child(seal)
	var back := _make_menu_button("CLOSE THE CABINET")
	back.custom_minimum_size = Vector2(240, 40)
	back.pressed.connect(func() -> void: _close_panel(_cheat_panel))
	foot.add_child(back)
	vb.add_child(foot)
	var warn := _make_label("while medicated the HUD wears the Rx badge — everyone can see you cheated",
		12, Color(0.85, 0.55, 0.5), false, 0)
	warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(warn)
	# The corner pill: once the word has been spoken this session, a
	# little capsule sits by the menu to reopen the cabinet — no
	# retyping until the next launch, when it vanishes again.
	_pill_btn = Button.new()
	_pill_btn.flat = true
	_pill_btn.custom_minimum_size = Vector2(52, 40)
	_pill_btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_pill_btn.offset_left = -70.0
	_pill_btn.offset_top = -58.0
	_pill_btn.offset_right = -18.0
	_pill_btn.offset_bottom = -18.0
	_make_focusable(_pill_btn)
	var pic := TextureRect.new()
	pic.texture = _pill_tex()
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pill_btn.add_child(pic)
	_pill_btn.visible = Settings.cabinet_unlocked
	_pill_btn.pressed.connect(func() -> void:
		if not _any_panel_open():
			_open_cabinet())
	_menu_root.add_child(_pill_btn)
	return panel


## The menu-corner capsule: red on the left, cream on the right.
func _pill_tex() -> ImageTexture:
	var img := Image.create(14, 7, false, Image.FORMAT_RGBA8)
	var left := Color(0.88, 0.3, 0.28)
	var right := Color(0.95, 0.92, 0.85)
	for x in range(0, 14):
		for y in range(0, 7):
			if (y == 0 or y == 6) and (x == 0 or x == 13):
				continue  # rounded ends
			img.set_pixel(x, y, left if x < 7 else right)
	for x in range(1, 13):
		img.set_pixel(x, 1, (left if x < 7 else right).lightened(0.25))
	return ImageTexture.create_from_image(img)


func _refresh_cheat_rows() -> void:
	for id: String in _cheat_rows:
		var r: Dictionary = _cheat_rows[id]
		var on: bool = Settings.cheats.get(id, false)
		(r["btn"] as Button).text = "· DOSED ·" if on else "SEALED"
		(r["btn"] as Button).add_theme_color_override("font_color",
			Color(0.62, 0.95, 0.78) if on else Color(0.5, 0.55, 0.52))
		(r["icon"] as TextureRect).texture = (r["tex_on"] if on
			else r["tex_off"]) as Texture2D
		(r["row"] as HBoxContainer).modulate = Color(1, 1, 1, 1.0 if on else 0.75)


func _make_overlay_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.08, 0.19, 0.94)
	sb.border_color = Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.3)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 38.0
	sb.content_margin_right = 38.0
	sb.content_margin_top = 22.0
	sb.content_margin_bottom = 22.0
	panel.add_theme_stylebox_override("panel", sb)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_root.add_child(center)
	center.add_child(panel)
	return panel


## v6.5: every interactive control must be reachable without a mouse.
## Small buttons (presets, cycler arrows, colour swatches) get focus,
## a gold ring and the focus tick via this helper.
func _make_focusable(btn: Button) -> void:
	btn.focus_mode = Control.FOCUS_ALL
	var ring := StyleBoxFlat.new()
	ring.bg_color = Color(0, 0, 0, 0)
	ring.border_color = Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.9)
	ring.set_border_width_all(2)
	ring.set_corner_radius_all(5)
	btn.add_theme_stylebox_override("focus", ring)
	btn.focus_entered.connect(func() -> void: Sfx.play("ui"))


func _make_menu_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(300, 46)
	btn.focus_mode = Control.FOCUS_ALL
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", COL_TEXT)
	btn.add_theme_color_override("font_hover_color", COL_GOLD)
	btn.add_theme_color_override("font_focus_color", COL_GOLD)
	btn.add_theme_color_override("font_pressed_color", COL_GOLD)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.05, 0.08, 0.19, 0.75)
	normal.border_color = Color(COL_DIM.r, COL_DIM.g, COL_DIM.b, 0.35)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(6)
	var focus := normal.duplicate() as StyleBoxFlat
	focus.bg_color = Color(0.09, 0.12, 0.25, 0.92)
	focus.border_color = Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.85)
	focus.set_border_width_all(2)
	var pressed := focus.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.14, 0.13, 0.10, 0.95)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", focus)
	btn.add_theme_stylebox_override("focus", focus)
	btn.add_theme_stylebox_override("hover_pressed", pressed)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.mouse_entered.connect(func() -> void:
		if btn.focus_mode != Control.FOCUS_NONE:
			btn.grab_focus())
	btn.focus_entered.connect(func() -> void: Sfx.play("ui"))
	return btn


func _make_label(text: String, size_px: int, color: Color, bold: bool,
		letter_spacing: int) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", size_px)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	lbl.add_theme_constant_override("shadow_offset_x", 2)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	if bold or letter_spacing > 0:
		var f := FontVariation.new()
		f.base_font = ThemeDB.fallback_font
		if bold:
			f.variation_embolden = 0.85
		if letter_spacing > 0:
			f.set_spacing(TextServer.SPACING_GLYPH, letter_spacing)
		lbl.add_theme_font_override("font", f)
	return lbl


func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c
