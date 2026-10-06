class_name Ceremonies
extends RefCounted
## The end-of-round and end-of-battle splash screens (main.gd, v4.5).
##
## Two ceremonies, deliberately mirrored:
##   - VICTORY: the winner's bomber center stage in their colour, a
##     gold MEDAL (round win) or the TROPHY (battle win — different
##     backdrop tint) bouncing down onto them, "PLAYER X WINS ...".
##     Solo escape says "YOU ESCAPED!".
##   - DEFEAT (solo, v4.4): the loser center stage with the crying
##     face (assets/bomber/cry.svgt), a sobbing-shoulder loop, tear
##     particles, and the anti-medal — a personal rain cloud that
##     bounces down and just drizzles on them. Sad trombone.
##
## Everything is built in code and parented under g._hud, held by one
## root Control so hide() can wipe a whole ceremony at once. Looping
## tweens are NODE-BOUND (bomber.create_tween()) so they die with the
## splash instead of screaming about freed targets. `g` is the battle
## scene (scripts/main.gd).

var g  # the battle scene (scripts/main.gd)
var _root: Control


func _init(scene) -> void:
	g = scene


## Round or battle won. `battle` = the whole series ended (trophy,
## purple backdrop, rematch hint) rather than one round (medal).
func show_victory(winner_idx: int, battle: bool) -> void:
	hide()
	var col: Color = g._player_col(winner_idx)
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g._hud.add_child(_root)

	var bg := ColorRect.new()
	bg.color = Color("2a1650") if battle else Color(col.r * 0.22, col.g * 0.22, col.b * 0.22)
	bg.color.a = 0.96
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bg)

	var anchor := Control.new()
	anchor.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(anchor)

	# The champion, big, front view, in their color.
	var bomber := TextureRect.new()
	bomber.texture = BomberArt.texture("front", 0, col)
	bomber.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bomber.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bomber.size = Vector2(220, 262)
	bomber.position = Vector2(-110, -140)
	bomber.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor.add_child(bomber)

	# The prize falls from above and bounces onto the bomber.
	var prize := TextureRect.new()
	prize.texture = g._tex["trophy"] if battle else g._tex["medal"]
	prize.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	prize.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	prize.size = Vector2(170, 170) if battle else Vector2(140, 175)
	prize.position = Vector2(-prize.size.x * 0.5, -620.0)
	prize.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor.add_child(prize)
	var land_y := -240.0 if battle else -235.0
	var tw: Tween = prize.create_tween()
	tw.tween_property(prize, "position:y", land_y, 1.0) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: Sfx.play("item"))

	var text: Label = g._make_label(
		"%s WINS THE BATTLE!" % g._victory_name(winner_idx) if battle
		else "%s WINS THE ROUND!" % g._victory_name(winner_idx),
		44, g.COL_GOLD if battle else col.lerp(Color.WHITE, 0.55), true, 4)
	if g.players.size() == 1:
		text.text = "YOU ESCAPED!"
	text.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	text.grow_horizontal = Control.GROW_DIRECTION_BOTH
	text.offset_top = 150.0
	text.offset_bottom = 210.0
	text.modulate.a = 0.0
	_root.add_child(text)
	var tw2: Tween = text.create_tween()
	tw2.tween_interval(0.5)
	tw2.tween_property(text, "modulate:a", 1.0, 0.4)
	if battle:
		# Battle stats (v6.3): numbers for the rivalry to argue about.
		# Sorted by wins, winner first; each row in its owner's colour.
		var stats := VBoxContainer.new()
		stats.add_theme_constant_override("separation", 2)
		stats.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		stats.grow_horizontal = Control.GROW_DIRECTION_BOTH
		stats.offset_top = 218.0
		stats.alignment = BoxContainer.ALIGNMENT_BEGIN
		_root.add_child(stats)
		var order: Array = g.players.duplicate()
		order.sort_custom(func(a: Bomber, b: Bomber) -> bool:
			return a.wins > b.wins)
		for p: Bomber in order:
			var row: Label = g._make_label(
				"%s   %d wins  ·  %d bombs  ·  %d bricks  ·  %d KOs  ·  %d items"
				% [g._pname(p.i), p.wins, p.stat_bombs, p.stat_bricks,
					p.stat_kills, p.stat_items],
				15, g._player_col(p.i).lerp(Color.WHITE, 0.45), false, 1)
			row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			stats.add_child(row)
		var hint: Label = g._make_label("R rematch  ·  Q or ENTER menu",
			16, g.COL_DIM, false, 2)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stats.add_child(g._spacer_ctl(6))
		stats.add_child(hint)
	Sfx.play("win")


## The mirror ceremony (v4.4): solo defeat. The loser center stage in
## their colour — crying face, sobbing shoulders, waterfall-tear
## particles — while a personal little rain cloud bounces down (the
## anti-medal) and drizzles on them. Sad trombone included.
func show_defeat(timeout: bool) -> void:
	hide()
	var col: Color = g._player_col(0)
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g._hud.add_child(_root)

	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.10, 0.15, 0.96)  # gloomy slate
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bg)

	var anchor := Control.new()
	anchor.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(anchor)

	# The loser, big, crying, slightly hunched.
	var bomber := TextureRect.new()
	bomber.texture = BomberArt.texture("cry", -1, col)
	bomber.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bomber.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bomber.size = Vector2(220, 262)
	bomber.position = Vector2(-110, -140)
	bomber.pivot_offset = Vector2(110, 200)
	bomber.rotation = 0.05
	bomber.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor.add_child(bomber)
	# Sobbing: shoulders heave in a small loop (node-bound tween — it
	# must die with the splash).
	var sob := bomber.create_tween().set_loops()
	sob.tween_property(bomber, "position:y", -132.0, 0.26) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	sob.tween_property(bomber, "position:y", -140.0, 0.38) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Waterfall tears from both eyes.
	for ex: float in [-17.0, 17.0]:
		var tears := CPUParticles2D.new()
		tears.amount = 7
		tears.lifetime = 0.7
		tears.local_coords = false
		tears.direction = Vector2(signf(ex), 2.0).normalized()
		tears.spread = 14.0
		tears.gravity = Vector2(0, 640)
		tears.initial_velocity_min = 60.0
		tears.initial_velocity_max = 130.0
		tears.scale_amount_min = 3.4
		tears.scale_amount_max = 5.6
		var ramp := Gradient.new()
		ramp.set_color(0, Color("aee6fb"))
		ramp.set_color(1, Color(0.5, 0.84, 0.95, 0.0))
		tears.color_ramp = ramp
		tears.position = Vector2(ex, -28)
		anchor.add_child(tears)

	# The anti-medal: a personal rain cloud drops in and just... stays.
	var cloud := TextureRect.new()
	cloud.texture = g._tex["raincloud"]
	cloud.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cloud.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cloud.size = Vector2(190, 130)
	cloud.position = Vector2(-95, -620)
	cloud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor.add_child(cloud)
	var tw: Tween = cloud.create_tween()
	tw.tween_property(cloud, "position:y", -338.0, 1.0) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		if not is_instance_valid(cloud) or not is_instance_valid(anchor):
			return
		# It starts to rain. Of course it does.
		var rain := CPUParticles2D.new()
		rain.amount = 26
		rain.lifetime = 0.55
		rain.local_coords = false
		rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		rain.emission_rect_extents = Vector2(80, 4)
		rain.direction = Vector2.DOWN
		rain.spread = 4.0
		rain.gravity = Vector2(0, 900)
		rain.initial_velocity_min = 220.0
		rain.initial_velocity_max = 330.0
		rain.scale_amount_min = 2.2
		rain.scale_amount_max = 3.4
		var rramp := Gradient.new()
		rramp.set_color(0, Color(0.62, 0.78, 0.92, 0.8))
		rramp.set_color(1, Color(0.62, 0.78, 0.92, 0.1))
		rain.color_ramp = rramp
		rain.position = Vector2(0, -230)
		anchor.add_child(rain)
		var hover := cloud.create_tween().set_loops()
		hover.tween_property(cloud, "position:y", -346.0, 1.2) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		hover.tween_property(cloud, "position:y", -338.0, 1.2) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT))

	var text: Label = g._make_label("TIME UP — DEFEAT..." if timeout else "DEFEAT...",
		44, Color("9aa4c0"), true, 4)
	text.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	text.grow_horizontal = Control.GROW_DIRECTION_BOTH
	text.offset_top = 150.0
	text.offset_bottom = 210.0
	text.modulate.a = 0.0
	_root.add_child(text)
	var tw2: Tween = text.create_tween()
	tw2.tween_interval(0.5)
	tw2.tween_property(text, "modulate:a", 1.0, 0.4)
	var hint: Label = g._make_label("R retry  ·  Q or ENTER menu",
		16, g.COL_DIM, false, 2)
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint.offset_top = 220.0
	hint.offset_bottom = 250.0
	_root.add_child(hint)
	Sfx.play("womp")


## Nobody wins (v6.3): mutual KO or the clock ran out. The fallen
## line up on their backs, the word says the rest. Auto-cleared by
## the next round (main calls hide() in _start_round).
func show_draw(timeout: bool) -> void:
	hide()
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g._hud.add_child(_root)
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.12, 0.14, 0.94)  # neutral gray — no winner's tint
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bg)
	var anchor := Control.new()
	anchor.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(anchor)
	# The fallen, side by side, flat on their backs.
	var n: int = g.players.size()
	for i in n:
		var b := TextureRect.new()
		b.texture = BomberArt.texture("front", 0, g._player_col(i))
		b.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		b.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		b.size = Vector2(110, 131)
		b.pivot_offset = b.size * 0.5
		b.rotation = PI * 0.5 if i % 2 == 0 else -PI * 0.5
		b.position = Vector2(-n * 70 + i * 140 + 15, -110.0)
		b.modulate = Color(0.75, 0.75, 0.78)
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		anchor.add_child(b)
	var text: Label = g._make_label(
		"TIME UP — DRAW" if timeout else "DRAW — NOBODY WINS",
		42, Color("c9ccd4"), true, 4)
	text.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	text.grow_horizontal = Control.GROW_DIRECTION_BOTH
	text.offset_top = 60.0
	text.offset_bottom = 120.0
	_root.add_child(text)
	var sub: Label = g._make_label(
		"the clock claims everyone" if timeout
		else "a perfectly mutual arrangement", 16, g.COL_DIM, false, 2)
	sub.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	sub.grow_horizontal = Control.GROW_DIRECTION_BOTH
	sub.offset_top = 126.0
	sub.offset_bottom = 156.0
	_root.add_child(sub)
	Sfx.play("die")


func hide() -> void:
	if _root != null and is_instance_valid(_root):
		_root.queue_free()
	_root = null
