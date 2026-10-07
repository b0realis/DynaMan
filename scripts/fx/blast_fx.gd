class_name BlastFx
extends RefCounted
## The explosion particle system, extracted from main.gd in v4.5 so
## the juice can be tuned without wading through game logic.
##
## LAYERING (per detonation, all owner-tinted via g._vivid):
##   - a white FLASH pop at the origin (the only pure-white element),
##   - a heavy FIREBALL burst at the origin,
##   - per blast ARM: one continuous fire emitter whose emission
##     rectangle spans the whole arm, plus one directional ember burst
##     (v4.5 — this used to be per CELL: a flame-10 bomb spawned ~80
##     emitter nodes and ~85 timers, and 8-bomb chains approached 650
##     live CPU emitters in one frame; per-arm is ~10× cheaper for the
##     same look),
##   - SMOKE rising from the origin a beat later.
##
## The flame-cell ground glow and shockwave rings are NOT here — they
## are canvas drawing, not particles, and live in main's _draw_flames /
## _draw_glow.
##
## Timers are created with process_always = false, so a tree PAUSE
## freezes the effects' lifetimes with the particles (v12.6).
## `g` is the battle scene: this class reads g.cell_px / g._to_px /
## g._flame_canvas / g.FLAME_S and parents everything to the flame
## canvas so draw order stays consistent with the flames themselves.

var g  # the battle scene (scripts/main.gd)


func _init(scene) -> void:
	g = scene


## The full ceremony for one detonation. `cells` = every flame cell of
## the blast (origin included), `col` = the owner's colour.
func spawn_blast(origin: Vector2i, cells: Array, col: Color) -> void:
	var vivid: Color = g._vivid(col)
	var hot := vivid.lerp(Color.WHITE, 0.3)
	var dark := vivid.darkened(0.45)
	var cell_px: float = g.cell_px

	# White flash pop at the origin — pure light for the first instant.
	var flash := make_burst(7, 0.18, cell_px * 0.1, cell_px * 0.5,
		cell_px * 0.3, cell_px * 0.5, Vector2.ZERO,
		[Color(1, 1, 1), Color(1, 1, 0.95, 0.0)])
	flash.position = g._to_px(Vector2(origin))
	g._flame_canvas.add_child(flash)

	var fireball := make_burst(30, 0.55, cell_px * 0.4, cell_px * 1.6,
		cell_px * 0.18, cell_px * 0.36, Vector2.ZERO,
		[hot, vivid, vivid, Color(dark.r, dark.g, dark.b, 0.0)])
	fireball.position = g._to_px(Vector2(origin))
	g._flame_canvas.add_child(fireball)

	# Group the flame cells into the four ray arms; one emitter pair
	# per arm (see header for why not per cell).
	var arms := {Vector2i(1, 0): 0, Vector2i(-1, 0): 0,
		Vector2i(0, 1): 0, Vector2i(0, -1): 0}
	for c: Vector2i in cells:
		var d := c - origin
		if d == Vector2i.ZERO:
			continue
		var k := Vector2i(signi(d.x), signi(d.y))
		if arms.has(k):
			arms[k] = maxi(arms[k], absi(d.x) + absi(d.y))
	_arm_fire(origin, Vector2i.ZERO, 0, hot, vivid, dark)
	for k: Vector2i in arms:
		if arms[k] > 0:
			_arm_fire(origin, k, arms[k], hot, vivid, dark)

	# Smoke rises out of the fireball a beat later — the "heavy" tail.
	g.get_tree().create_timer(0.12, false).timeout.connect(func() -> void:
		# The battle may be gone by now (any key ends the attract demo):
		# check the scene itself before reaching through it.
		if not is_instance_valid(g) or not is_instance_valid(g._flame_canvas):
			return
		var smoke := make_burst(12, 1.0, cell_px * 0.15, cell_px * 0.6,
			cell_px * 0.18, cell_px * 0.3, Vector2(0, -cell_px * 1.4),
			[Color(0.25, 0.24, 0.3, 0.5), Color(0.18, 0.17, 0.22, 0.0)])
		smoke.position = g._to_px(Vector2(origin))
		g._flame_canvas.add_child(smoke))


## One blast arm's worth of fire: a single continuous burn emitter
## whose emission rectangle spans the arm (arm_len cells outward from
## origin along dirv; arm_len 0 = just the origin cell), plus one
## directional ember burst. Amounts scale with length, capped so a
## monster blast stays cheap.
func _arm_fire(origin: Vector2i, dirv: Vector2i, arm_len: int,
		hot: Color, vivid: Color, dark: Color) -> void:
	var cell_px: float = g.cell_px
	var mid := Vector2(origin) + Vector2(dirv) * (arm_len * 0.5)
	var fire := CPUParticles2D.new()
	fire.local_coords = true  # stays on its arm under follow-cam / shake
	fire.amount = mini(24 + 14 * arm_len, 80)
	fire.lifetime = 0.3
	fire.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	fire.emission_rect_extents = Vector2(
		(arm_len * 0.5 + 0.34) * cell_px if dirv.x != 0 else cell_px * 0.34,
		(arm_len * 0.5 + 0.34) * cell_px if dirv.y != 0 else cell_px * 0.34)
	fire.direction = Vector2.UP
	fire.spread = 80.0
	fire.gravity = Vector2(0, -cell_px * 1.6)  # fire rises
	fire.initial_velocity_min = cell_px * 0.2
	fire.initial_velocity_max = cell_px * 0.9
	fire.scale_amount_min = cell_px * 0.12
	fire.scale_amount_max = cell_px * 0.26
	var framp := Gradient.new()
	framp.set_color(0, hot)
	framp.add_point(0.15, vivid)
	framp.add_point(0.75, vivid.darkened(0.12))
	framp.set_color(1, Color(dark.r, dark.g, dark.b, 0.0))
	fire.color_ramp = framp
	fire.position = g._to_px(mid)
	g._flame_canvas.add_child(fire)
	# Bound methods, not lambdas capturing the node: the connection dies
	# with the emitter, so leaving the battle mid-blast no longer logs
	# "Lambda capture at index 0 was freed" per live emitter.
	g.get_tree().create_timer(g.FLAME_S * 0.75, false).timeout.connect(
		fire.set_emitting.bind(false))
	g.get_tree().create_timer(1.2, false).timeout.connect(fire.queue_free)
	if arm_len > 0:
		var embers := make_burst(mini(10 + 6 * arm_len, 40), 0.65,
			cell_px * 1.4, cell_px * 3.4, cell_px * 0.04, cell_px * 0.1,
			Vector2(0, cell_px * 2.2),
			[hot, vivid, vivid.darkened(0.2), Color(dark.r, dark.g, dark.b, 0.0)])
		embers.direction = Vector2(dirv)
		embers.spread = 26.0
		embers.position = g._to_px(Vector2(origin)
			+ Vector2(dirv) * maxf(arm_len * 0.5, 0.5))
		g._flame_canvas.add_child(embers)


## Mole dirt (v6.8): a little brown geyser where the digging happens.
func make_dirt_burst(px: Vector2, cell: float) -> void:
	var burst := make_burst(14, 0.45, cell * 0.3, cell * 1.2,
		cell * 0.04, cell * 0.09, Vector2(0, cell * 2.0),
		[Color("8a6a48"), Color("6b5138"), Color(0.4, 0.3, 0.2, 0.0)])
	burst.position = px
	g._flame_canvas.add_child(burst)


## One-shot radial CPUParticles2D burst, auto-freed after `lifetime`.
## colors = gradient stops, first and last pinned, middle spread evenly.
## Callers position it and add it to whatever canvas they like.
func make_burst(amount: int, lifetime: float, vel_min: float, vel_max: float,
		scale_min: float, scale_max: float, gravity: Vector2,
		colors: Array) -> CPUParticles2D:
	var part := CPUParticles2D.new()
	# Particles live in the canvas's space, so they ride the follow-cam
	# and the screen shake with the board (world-space ones slid off
	# their blast cell on big scrolling arenas).
	part.local_coords = true
	part.one_shot = true
	part.emitting = true
	part.amount = amount
	part.lifetime = lifetime
	part.explosiveness = 0.92
	part.direction = Vector2.ZERO
	part.spread = 180.0
	part.gravity = gravity
	part.initial_velocity_min = vel_min
	part.initial_velocity_max = vel_max
	part.scale_amount_min = scale_min
	part.scale_amount_max = scale_max
	part.damping_min = vel_max * 0.7
	part.damping_max = vel_max * 1.1
	var ramp := Gradient.new()
	ramp.set_color(0, colors[0])
	for i in range(1, colors.size() - 1):
		ramp.add_point(float(i) / (colors.size() - 1), colors[i])
	ramp.set_color(1, colors[colors.size() - 1])
	part.color_ramp = ramp
	g.get_tree().create_timer(lifetime + 0.5, false).timeout.connect(part.queue_free)
	return part
