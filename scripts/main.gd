extends Node2D
## Main — the DynaMan battle scene (scenes/main.tscn). 1-4 local bombers,
## a menagerie of enemies, last one standing (or solo: clear + escape).
## Everything is built in code.
##
## WHO OWNS WHAT (v4.5 modular split):
##   - Arena (scripts/game/arena.gd)        — pure grid logic, headless-
##     testable: generation, blast rays, items. No nodes, no engine.
##   - BomberBrain (scripts/game/bomber_brain.gd) — the mini-boss AI
##     planner. Reads this scene through its `g` reference, acts via
##     _spawn_bomb.
##   - BlastFx (scripts/fx/blast_fx.gd)     — the explosion particle
##     system (flash/fireball/arm fires/embers/smoke).
##   - Ceremonies (scripts/ui/ceremonies.gd) — victory & defeat splash
##     screens.
##   - This file — the state machine (COUNTDOWN/PLAY/ROUND_END/
##     BATTLE_END/PAUSE/EXIT), input, player movement, enemies, bombs &
##     flames, portal, sudden death, HUD, and the canvas-drawn glow.
##
## VOCABULARY (settled in v4.7, player's call): one arena = a ROUND
## (round_num, round_t, ROUND_END); first to Settings.wins_target round
## wins takes the BATTLE (BATTLE_END). The strip under the HUD is
## BATTLE POINT — one round win from the whole thing.
##
## Positions are in CELL coordinates (floats, cell centers at integers);
## _to_px converts to screen. Movement is the classic Bomberman glide:
## one axis at a time, cross-axis easing to the corridor center, corner
## assist near pillar openings.

const HUD_H := 72.0
# Round wins to take the battle come from Settings.wins_target/win_margin.
# Round length comes from Settings.round_time (battle setup slider).
const BOMB_FUSE := 2.8
const FLAME_S := 0.45
## Chain reactions PROPAGATE (v12.1): a bomb caught in a blast doesn't
## go off in the same frame — its fuse drops to CHAIN_GAP, so a row
## ripples bomb by bomb (like Dynablaster) and each one plays its own
## beat as it pops: "bo bo bo bo bo BOOM", in sync with the picture.
const CHAIN_GAP := 0.11   # fuses count down per frame: 7 frames ≈ 117 ms at 60 fps
## A brick keeps stopping rays while it BURNS (v12.1; per-frame since
## v11.7): a chain partner going off a beat later must not fly through
## the brick its trigger just burned and torch the item it revealed.
const SHIELD_S := FLAME_S
## Rays of bombs going off sooner than this can't be outrun (see
## _imminent_cells): bots path around them like live fire.
const IMMINENT_S := 0.25
const CURSE_S := 8.0
const BASE_SPEED := 3.4          # cells/second
const SPEED_STEP := 0.5
const SPEED_MAX := 6.4
const ENEMY_SPEED := 1.8
## Enemy spawn table: chance an enemy slot rolls the rare hunter.
const CHOMPER_P := 0.25
const CHOMPER_CHASE_SPEED := 2.7
const CHOMPER_SENSE := 3.5       # cells; closer than this wakes the hunt
const FIREBALL_SPEED := 5.0      # elemental projectile, cells/second
const PLAYER_R := 0.42           # kill radius vs enemies, cells

const COL_BG := Color("101a38")
const COL_HUD := Color("0c1430")
const COL_TEXT := Color("e8e0cc")
const COL_DIM := Color("8b8fa3")
const COL_GOLD := Color("f2c94c")
const ITEM_SPRITES := ["item_bomb", "item_fire", "item_speed", "item_skull",
	"item_kick", "item_vest", "item_wallpass", "item_nasty"]
const CURSE_NAMES := ["REVERSED!", "SLOW!", "NO BOMBS!", "AUTO-BOMB!",
	"SLUGGISH + REVERSED!"]
## First three come from the purple skull; the last two only from the
## green (contagious) one.
enum Curse { REVERSE, SLOW, NO_BOMBS, AUTO_BOMB, REV_SLOW }
const KICK_SPEED := 7.0          # kicked bomb slide, cells/second
const VEST_S := 10.0             # fireproof vest duration
const NASTY_S := 12.0            # green-skull infection duration
## Bomber sprite: 64×76 template, drawn ~1.6 cells tall (big head pokes
## above its row, classic proportions), feet anchored near the cell floor.
const BOMBER_H_CELLS := 1.6
const WALK_FRAME_S := 0.13

enum State { COUNTDOWN, PLAY, ROUND_END, BATTLE_END, PAUSE, EXIT }

var arena := Arena.new()
var state := State.COUNTDOWN
var rng := RandomNumberGenerator.new()

var cell_px := 44.0
var origin := Vector2.ZERO       # top-left px of cell (0,0)

## players[i]: pos Vector2, alive, wins, bombs_max, bombs_out, flame,
## speed, curse (-1 none), curse_t, node, spr, curse_spr, human index i.
var players: Array[Bomber] = []
var _humans := 0  # of which the first _humans are at the keys (v4.6)
## bombs: {cell Vector2i, t, owner, node, walkers: Array[int]}
var bombs: Array = []
## flame cells: Vector2i -> expiry (Time msec / 1000.0)
var flames: Dictionary = {}
## revealed items on the ground: Vector2i -> item id; sprites separate.
var ground_items: Dictionary = {}
var item_sprites: Dictionary = {}
## enemies: {pos Vector2, dir Vector2i, node} + per-type extras
var enemies: Array[Monster] = []
## elemental projectiles: {pos Vector2, dir Vector2i, trail node}
var fireballs: Array = []
var brick_sprites: Dictionary = {}

var round_num := 0
var round_t := 150.0
var _count_t := 0.0
var _count_step := 0
var _end_t := 0.0
## The round-end ceremony waits CER_DELAY so the deciding blast and the
## loser's spin are SEEN first (v12.6: the card covered them that frame).
const CER_DELAY := 0.9
var _cer_pending := Callable()
var _cer_at := 0.0
## "GO!" hands over control at once and fades from the banner a beat later.
var _go_hide_at := 0.0

var _tiles_root: Node2D
var _entities_root: Node2D
var _flame_canvas: Node2D
var _goo_canvas: Node2D
var _field_layer: CanvasLayer
var _glow_canvas: Node2D
## Expanding shockwave rings: {"px": Vector2, "born": float, "col": Color}.
var _rings: Array = []
## Game clock (seconds): advances with the (time-scaled) frame delta in
## every state but PAUSE. Flames, rings and goo are stamped with it —
## they used to run on the wall clock, so pausing let fire burn out
## behind the pause screen and the SEDATIVE (time_scale 0.5) halved the
## fire window while everything else slowed down.
var _clock := 0.0
## Per-seat input action names, built once (formatting "p%d_up" for
## every Input call, every player, every frame was pure churn).
var _acts: Array = []
## Bricks (and ground items) burned in the last SHIELD_S: cell ->
## expiry on _clock. They still stop rays (see _detonate, SHIELD_S).
var _shield: Dictionary = {}
var _bomb_map: Dictionary = {}     # see _bomb_cells
var _bomb_map_frame := -1
## Bricks still BURNING: cell -> expiry on _clock. Solid to everyone —
## a burning block is no hiding place (v12.2: the cell turned floor at
## once while every ray stopped short of it, a 0.45 s fireproof hole).
var _burning: Dictionary = {}
## Bricks mid-burn: cell -> {"spr": the brick sprite, "base": its scale,
## "item": the hidden item's sprite or null} — animated by _tick_burns.
var _burn_fx: Dictionary = {}
## Cell -> the chain whose blast burned the brick there: that chain's
## later blasts spare the item (or doorway) it uncovered, however long
## it ripples (v12.2: past SHIELD_S, a 5th link torched it).
var _revealed: Dictionary = {}
## When this battle entered BATTLE_END (on _clock) — see the pad START.
var _battle_end_at := 0.0
## Bumped by every _start_round and never reset (a rematch restarts
## round_num at 1, so round_num can't tell "this round" from "the same
## round number after R" — a pending portal boss leaked across).
var _round_serial := 0
## This battle halved Engine.time_scale for the SEDATIVE bottle.
var _sedated := false
## The configured arena was too big for a shared screen this round.
var _size_clamped := false
var _field: Control
var _hud: CanvasLayer
var _chips: Array = []
var _timer_label: Label
var _round_label: Label
var _banner: Label
var _sub_banner: Label
var _pause_panel: PanelContainer
var _pause_sync := Callable()   # re-reads Settings into the pause quick options
var _teams_note := false        # teams requested but the roster isn't four
var _hint_had_danger := false   # blast-hint repaint gate (v10.4)
var _fireball_gone := false     # one glow-cleanup frame after the last hit
var _medicated := false     # any MEDICINE CABINET bottle open this round —
							# the HUD wears the Rx badge (v11.0)
var _rx_label: Label
var _timer_shown := -1          # last second painted on the clock
var _last_tick_ms := 0          # global tick-SFX rate cap
var _win_focused := true        # tracked focus (headless never loses it)
var _tex: Dictionary = {}
var _shake := 0.0
## State the current pause came from (PLAY or COUNTDOWN) — resuming
## returns there so a paused countdown keeps counting.
var _paused_from := State.PLAY

## Hurry-up / sudden death (v4.5).
const HURRY_S := 30.0            # red pulsing clock + urgent music below this
const PRESSURE_START_S := 45.0   # pressure blocks start this far from 0:00
const PRESSURE_STEP_S := 0.55    # seconds between falling pressure blocks
var _pressure_order: Array[Vector2i] = []  # inward spiral, built per round
## Snail goo: cell -> expiry on the game clock (_clock, seconds).
## Players wading through move at 55%.
var goo: Dictionary = {}
var _skin := "classic"  # active tile skin, decided each round (v4.9)
var _pressure_next := 0
var _pressure_accum := 0.0
## Enemies the spawner could NOT place (crowded arena) — countdown note.
var _enemy_shortfall := 0
var _battlepoint_label: Label
var _help_overlay: Control  # hold H (v6.1): high-contrast quick help
var _help_mode: Label       # its goal line, re-texted per round
## Follow-camera state (solo arenas larger than the screen).
var _scroll_mode := false
var _cam := Vector2.ZERO
## Solo exit portal (v3.9): hidden under a random brick; opens once the
## last monster dies; stepping through plays the escape and wins.
var portal_cell := Vector2i(-99, -99)
var _portal_spr: Sprite2D
var _portal_fx: CPUParticles2D
var _portal_open := false
var _exiting := false

## The extracted modules (see the header). Each holds a reference back
## to this scene and is created once in _ready.
var _brain: BomberBrain
var _fx: BlastFx
var _cer: Ceremonies
var _men: Menagerie  # the extended monster roster (v6.8)


func _ready() -> void:
	for n in range(1, 5):
		var d := {}
		for a: String in ["up", "down", "left", "right", "bomb"]:
			d[a] = StringName("p%d_%s" % [n, a])
		_acts.append(d)
	rng.randomize()
	# The battle scene runs through a tree PAUSE (input, HUD, pause card);
	# its world layers are pausable (see _build_layers / _process).
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	get_viewport().size_changed.connect(_on_viewport_resized)
	_brain = BomberBrain.new(self)
	_fx = BlastFx.new(self)
	_cer = Ceremonies.new(self)
	_men = Menagerie.new(self)
	for tex_name in ["wall", "brick", "bomb", "balloon", "balloon_blink",
			"slime", "snail", "frog", "mole", "thief", "freezer", "muncher",
			"mimic", "warlock", "bull", "snake_head", "snake_body",
			"snake_tail", "centi_head", "centi_body", "dragon_head",
			"dragon_body", "dragon_tail",
			"chomper_0", "chomper_1", "saw", "ghost", "bees", "elemental",
			"medal", "trophy", "portal", "raincloud"] + ITEM_SPRITES:
		_tex[tex_name] = load("res://assets/svg/%s.svg" % tex_name)
	# Humans take the first slots, bots (v4.6) fill the tail: solo may
	# invite up to 3, the zero-human DEMO fields 2-4 bots on their own.
	# One bomber total (no bots) = the classic solo arcade hunt: kill
	# every monster, then find the exit portal hidden under a brick.
	_humans = Settings.players
	var bots := 0
	if Settings.try_theme:
		# ARENA THEME MAKER test drive (v9.8): you plus one bot, wearing
		# the unsaved bench theme. Q returns to the maker.
		_humans = 1
		bots = 1
	elif Settings.attract_demo:
		# Menu-idle attract (v10.1): a full bot battle regardless of the
		# configured seats; ANY key or button brings the menu back.
		_humans = 0
		bots = Settings.demo_bots
	elif Story.active:
		# A story encounter is ALWAYS you alone against the pack — the
		# battle-setup roster (2+ humans, bot top-ups) must not leak in:
		# an idle second bomber dying would end every story fight as a
		# loss (v8.8 fix; the Blastalar binary has no setup screen at
		# all, and both binaries share dynaman.cfg).
		_humans = 1
	elif _humans == 1:
		bots = Settings.solo_bots
	elif _humans == 0:
		bots = Settings.demo_bots
	elif Settings.fill_bots and (_humans == 2 or _humans == 3):
		bots = 4 - _humans  # 2 humans → 2 bots, 3 humans → 1 bot
	for i in clampi(_humans + bots, 1, 4):
		var p := _new_player(i)
		p.bot = i >= _humans
		players.append(p)
	# Teams (v10.2): a 2v2 pairing needs exactly four bombers — anything
	# else falls back to free-for-all (the countdown says so).
	if Settings.team_mode > 0 and not Story.active and not Settings.try_theme:
		if players.size() == 4:
			for p: Bomber in players:
				p.team = Settings.team_of(p.i)
		elif players.size() > 1:
			_teams_note = true
	_build_layout()
	_build_hud()
	_start_round()


func _new_player(i: int) -> Bomber:
	# All per-round state lives in the Bomber class defaults; only the
	# slot and the tunable base speed are main's to set.
	return Bomber.new(i, BASE_SPEED)


## Shared enemy factory (regular spawns AND portal-punishment bosses):
## class defaults cover the fixed state, this seeds the randomized
## timers so a fresh pack doesn't blink and shoot in lockstep.
func _new_monster(etype: String, c: Vector2i, ecol: Color, spr: Sprite2D) -> Monster:
	var e := Monster.new()
	e.type = etype
	e.pos = Vector2(c)
	e.node = spr
	e.col = ecol
	e.anim_t = rng.randf()
	e.blink_t = rng.randf_range(1.0, 3.0)
	e.shoot_t = rng.randf_range(2.0, 4.0)
	return e


func _player_col(i: int) -> Color:
	return Settings.player_color(i)


func _pname(i: int) -> String:
	if players[i].bot:
		return "BOT %d" % (i + 1 - _humans)
	return "PLAYER %d" % (i + 1)


## v4.6: bots fill slots, so the MODE depends on the total head-count,
## not on Settings.players. One bomber total = the arcade portal hunt;
## two or more (any mix of humans and bots) = battle rules.
func _is_arcade() -> bool:
	return players.size() == 1


## Attract mode: nobody at the keys, the battle loops on its own.
func _is_demo() -> bool:
	return _humans == 0


## Seat-bot skill dials (v10.2): "hard" is the untouched planner brain.
func bot_replan_mult() -> float:
	match Settings.bot_skill:
		"easy":
			return 2.2
		"normal":
			return 1.4
	return 1.0


func bot_bomb_chance() -> float:
	match Settings.bot_skill:
		"easy":
			return 0.5
		"normal":
			return 0.8
	return 1.0


func _bot_speed_mult() -> float:
	match Settings.bot_skill:
		"easy":
			return 0.85
		"normal":
			return 0.95
	return 1.0


func _teams_on() -> bool:
	return players.size() == 4 and players[0].team >= 0


## The name a victory ceremony announces — the whole TEAM in 2v2.
func _victory_name(i: int) -> String:
	var p: Bomber = players[i]
	if _teams_on() and p.team >= 0:
		var names: Array[String] = []
		for q: Bomber in players:
			if q.team == p.team:
				names.append(_pname(q.i).replace("PLAYER ", "P"))
		return "TEAM %s" % " + ".join(names)
	return _pname(i)


# ------------------------------------------------------ revenge rim (v10.2) --
## The fallen ride the border wall and lob bombs back in — classic
## revenge carts. Rim bombers are dead for every round-end purpose;
## their bombs are real (owner-credited, flame 2, cooldown-gated).

const RIM_SPEED := 4.2       # cells/s along the border
const RIM_THROW_CD := 2.4    # seconds between lobs
const RIM_THROW_IN := 3      # preferred landing depth from the wall


## Fractional perimeter scalar -> grid position on the border ring.
func _rim_xy(t: float) -> Vector2:
	var w := arena.w
	var h := arena.h
	var L := float(2 * (w - 1) + 2 * (h - 1))
	var sc := fposmod(t, L)
	if sc < w - 1:
		return Vector2(sc, 0)
	sc -= w - 1
	if sc < h - 1:
		return Vector2(w - 1, sc)
	sc -= h - 1
	if sc < w - 1:
		return Vector2(w - 1 - sc, h - 1)
	sc -= w - 1
	return Vector2(0, h - 1 - sc)


func _enter_rim(p: Bomber) -> void:
	p.rim = true
	p.rim_cd = 1.2
	# Surface at the nearest point of the rail to where they fell.
	var best_t := 0.0
	var best_d := 1e9
	var L := 2 * (arena.w - 1) + 2 * (arena.h - 1)
	for sc in L:
		var d := _rim_xy(float(sc)).distance_to(p.pos)
		if d < best_d:
			best_d = d
			best_t = float(sc)
	p.rim_pos = best_t
	var spr := Sprite2D.new()
	spr.texture = BomberArt.texture("front", 0, _player_col(p.i))
	var full := Vector2.ONE * (cell_px * 1.25 / (76.0 * BomberArt.RASTER_SCALE))
	spr.modulate = Color(1, 1, 1, 0.92)
	spr.position = _to_px(_rim_xy(p.rim_pos))
	spr.scale = full * 0.2
	_entities_root.add_child(spr)
	var tw := spr.create_tween()
	tw.tween_property(spr, "scale", full, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	p.rim_node = spr


func _tick_rim(p: Bomber, delta: float) -> void:
	p.rim_cd = maxf(p.rim_cd - delta, 0.0)
	var dirv := Vector2.ZERO
	var lob := false
	if p.bot:
		p.bot_t -= delta
		if p.bot_t <= 0.0:
			p.bot_t = rng.randf_range(0.6, 1.4)
			p.bot_dir = [Vector2.LEFT, Vector2.RIGHT, Vector2.UP,
				Vector2.DOWN][rng.randi() % 4] if rng.randf() < 0.7 else Vector2.ZERO
		dirv = p.bot_dir
		# ~4% per 60 Hz frame, scaled to the real frame: the throw rate used
		# to double at 144 fps and halve at 30 (v12.6).
		if p.rim_cd <= 0.0 and rng.randf() < 1.0 - pow(0.96, delta * 60.0):
			var rc := _rim_xy(p.rim_pos)
			for q: Bomber in players:
				if q.alive and (p.team < 0 or q.team != p.team) \
						and (absf(q.pos.x - rc.x) < 0.6
							or absf(q.pos.y - rc.y) < 0.6):
					lob = true
					break
	else:
		dirv = Vector2(
			Input.get_action_strength("p%d_right" % (p.i + 1))
				- Input.get_action_strength("p%d_left" % (p.i + 1)),
			Input.get_action_strength("p%d_down" % (p.i + 1))
				- Input.get_action_strength("p%d_up" % (p.i + 1)))
		lob = Input.is_action_just_pressed("p%d_bomb" % (p.i + 1))
	if dirv.length() > 0.3:
		var L := float(2 * (arena.w - 1) + 2 * (arena.h - 1))
		var fwd := _rim_xy(p.rim_pos + 0.35) - _rim_xy(p.rim_pos - 0.35)
		if fwd != Vector2.ZERO:
			var along := fwd.normalized().dot(dirv.normalized())
			if absf(along) > 0.35:
				p.rim_pos = fposmod(p.rim_pos + signf(along) * RIM_SPEED * delta, L)
	if is_instance_valid(p.rim_node):
		p.rim_node.position = _to_px(_rim_xy(p.rim_pos))
	if lob and p.rim_cd <= 0.0:
		_rim_throw(p)


func _rim_throw(p: Bomber) -> void:
	var c := Vector2i(_rim_xy(p.rim_pos).round())
	var n := Vector2i.ZERO
	if c.y == 0:
		n = Vector2i(0, 1)
	elif c.y == arena.h - 1:
		n = Vector2i(0, -1)
	elif c.x == 0:
		n = Vector2i(1, 0)
	else:
		n = Vector2i(-1, 0)
	for dist: int in [RIM_THROW_IN, 2, 4, 1, 5, 6, 7, 8]:
		var target := c + n * dist
		# Corners: the edge normal keeps the target in the border band —
		# clamp into the inner rect so corner riders can throw (v10.3).
		target.x = clampi(target.x, 1, arena.w - 2)
		target.y = clampi(target.y, 1, arena.h - 2)
		if _spawn_bomb(target, p.i, null, _player_col(p.i), 2):
			p.rim_cd = RIM_THROW_CD
			p.stat_bombs += 1
			return


# ------------------------------------------------------------ round flow ----

func _start_round() -> void:
	_story_done = false
	round_num += 1
	_round_serial += 1
	_end_chains()    # a chain cut short by R / a new round still lands its BOOM
	_cer_pending = Callable()   # an impatient R skips a card not yet shown
	_go_hide_at = 0.0
	_rings.clear()   # last round's shockwaves and glow must not hang over the
	if _glow_canvas != null:   # new board through the countdown (v12.2)
		_glow_canvas.queue_redraw()
	_shield.clear()  # last round's burning bricks belong to another board
	_burning.clear()
	_burn_fx.clear()
	_revealed.clear()
	# The cabinet's dose card for this round (v11.0): the SEDATIVE bends
	# time itself, and any open bottle marks the round MEDICATED.
	_medicated = Settings.any_cheat()
	# Halve / restore relative to whatever the scale was, and only when
	# the dose CHANGES: v11.0 wrote 1.0 every round, silently resetting
	# the 2.5x the AI/bot/menagerie probes run at (they lost 60% of
	# their sim time — the "flaky" ai_probe).
	var sedate := Settings.cheat("sedative")
	if sedate != _sedated:
		Engine.time_scale *= 0.5 if sedate else 2.0
		_sedated = sedate
	if _rx_label != null:
		_rx_label.visible = _medicated
	# v4.9: "Random arena" rerolls the world every round; otherwise the
	# OPTIONS choice applies. Decided BEFORE the board is built.
	# Random draws from the player's chosen scope (v9.8): everything,
	# the shipped 50, or their own themes (which fall back to everything
	# while the register is empty).
	var pool := TileArt.all_skins()
	match Settings.arena_random_scope:
		"builtin":
			pool = Array(TileArt.SKINS)
		"mine":
			var mine := TileArt.user_ids()
			if not mine.is_empty():
				pool = mine
	_skin = (pool[rng.randi() % pool.size()]
		if Settings.arena_random else Settings.arena_skin)
	if Settings.try_theme:
		_skin = TileArt.BENCH_ID  # the maker's test drive wears the bench
	if Story.active:
		_skin = Story.skin  # the overworld terrain picked the wallpaper
	Music.set_mood(TileArt.mood(_skin))  # the world picks the tune (v6.6)
	round_t = float(Settings.round_time)
	_timer_label.text = "%d:%02d" % [int(round_t) / 60, int(round_t) % 60]
	# Fresh arena; power-ups reset every round, classic battle style.
	# Two or more bombers (humans OR bots) share one screen, so the arena
	# clamps to fit; only the solo hunt (one bomber) may go bigger — the
	# follow camera is arcade-only (see _layout_metrics).
	var aw := Settings.arena_w
	var ah := Settings.arena_h
	if Story.active:
		aw = 15
		ah = 13
	_size_clamped = false
	if players.size() > 1:
		aw = mini(aw, Settings.MULTI_MAX_W)
		ah = mini(ah, Settings.MULTI_MAX_H)
		_size_clamped = not Story.active and not Settings.try_theme \
			and (aw != Settings.arena_w or ah != Settings.arena_h)
	arena.generate(aw, ah, Settings.brick_density,
		Settings.bonus_density, Settings.danger_share, rng)
	_layout_metrics()
	bombs.clear()
	_bomb_map_frame = -1
	flames.clear()
	goo.clear()   # a rematch must not inherit last round's slick (v10.4)
	if _goo_canvas != null:
		_goo_canvas.queue_redraw()
	ground_items.clear()
	enemies.clear()
	for fb: Dictionary in fireballs:
		if is_instance_valid(fb["trail"]):
			(fb["trail"] as CPUParticles2D).queue_free()
	fireballs.clear()
	_rebuild_board()
	# X-RAY SPECS (v11.0): bricks hiding an item glow warm gold —
	# skulls included; the label did warn you.
	if Settings.cheat("xray"):
		for xc: Vector2i in arena.hidden:
			if brick_sprites.has(xc):
				(brick_sprites[xc] as Sprite2D).modulate = Color(1.4, 1.2, 0.7)
	var spawns := Arena.spawn_cells(arena.w, arena.h)
	for p: Bomber in players:
		p.alive = true
		p.bombs_max = 1
		p.bombs_out = 0
		p.flame = 2
		p.speed = BASE_SPEED * (_bot_speed_mult() if p.bot else 1.0)
		p.curse = -1
		p.kick = false
		p.vest_t = 0.0
		p.wallpass = false
		p.nasty = false
		p.nasty_immune_t = 0.0
		p.frozen_t = 0.0          # a freezer's grip dies with the round
		p.freeze_immune_t = 0.0
		p.bot_bomb = false        # stale bot plans too (v10.4)
		p.bot_bomb_cell = Vector2i(-99, -99)
		p.bot_goal = Bomber.NO_GOAL
		p.bot_dir = Vector2.ZERO
		# Staggered first plans (v12.6): every bot used to replan on the
		# SAME frame each 0.14 s — a periodic spike instead of a spread.
		p.bot_t = BomberBrain.BOT_REPLAN_S * bot_replan_mult() * float(p.i) / 4.0
		p.fx = {}  # aura nodes died with the old player node
		# THE MEDICINE CABINET (v11.0): battle-only, humans-only doses.
		if not p.bot:
			if Settings.cheat("deluxe"):
				p.bombs_max = 8
				p.flame = 10
				p.speed = SPEED_MAX
			if Settings.cheat("steel_toes"):
				p.kick = true
		if Story.active and p.i == 0:
			# The overworld's equipment arrives here (v7.3).
			p.bombs_max = 1 + Story.bonus("bombs")
			p.flame = 2 + Story.bonus("flame")
			p.speed = BASE_SPEED + 0.35 * Story.bonus("speed")
			p.kick = Story.has_kick()
		p.pos = Vector2(spawns[p.i])
		_spawn_player_node(p)
		# Every view of this seat now, during the countdown — turning for
		# the first time used to rasterize mid-play (v12.6). Pinned.
		BomberArt.prewarm(_player_col(p.i), Settings.bomb_style_for(p.i), true)
	# Keep monsters clear of the corners actually OCCUPIED: the four-corner
	# list starved small solo boards of legal spawn cells (v11.8).
	var occupied: Array[Vector2i] = []
	for p: Bomber in players:
		occupied.append(spawns[p.i])
	_spawn_enemies(occupied)
	_enemy_shortfall = (Story.pack.size() if Story.active
		else Settings.enemy_count) - enemies.size()
	_build_pressure_order()
	# Solo (v3.9): hide the exit portal under a random brick. Kill every
	# monster, blast the right brick, and step through to win.
	if _portal_spr != null and is_instance_valid(_portal_spr):
		_portal_spr.queue_free()
	if _portal_fx != null and is_instance_valid(_portal_fx):
		_portal_fx.queue_free()
	_portal_spr = null
	_portal_fx = null
	_portal_open = false
	_exiting = false
	portal_cell = Vector2i(-99, -99)
	if _is_arcade() and not Story.active:
		var bricks: Array[Vector2i] = []
		for y in arena.h:
			for x in arena.w:
				if arena.cell(x, y) == Arena.BRICK:
					bricks.append(Vector2i(x, y))
		if not bricks.is_empty():
			portal_cell = bricks.pick_random()
		else:
			# Not one brick to hide under (sparse tiny boards): the door
			# stands in the open, as far from you as the board allows. It
			# used to never appear — a cleared pack still lost on time.
			var best := -1
			for c: Vector2i in arena.floor_cells():
				var d := absi(c.x - spawns[0].x) + absi(c.y - spawns[0].y)
				if d > best:
					best = d
					portal_cell = c
			if best >= 0:
				_reveal_portal()
		_update_portal_state()  # enemy_count 0 → the door opens at once
	_flame_canvas.queue_redraw()
	_cer.hide()
	_refresh_hud()
	state = State.COUNTDOWN
	_count_t = 0.0
	_count_step = 0
	_banner.text = "3"
	# Restore gold — a draw recolors the banner dim and that used to
	# stick for every later countdown of the battle.
	_banner.add_theme_color_override("font_color", COL_GOLD)
	_banner.visible = true
	# Countdown footnote: honest about crowded arenas (the spawner
	# refuses spawns closer than 5 cells to a player, so dense setups
	# can deliver fewer enemies than the slider asked for).
	var notes: Array[String] = []
	if _size_clamped:
		# Setup allows big arenas for the solo hunt; say so when a shared
		# screen shrank it (it used to happen silently, v11.8).
		notes.append("arena %d×%d — shared screen" % [arena.w, arena.h])
	if _enemy_shortfall > 0:
		notes.append("arena crowded — %d of %d enemies placed" % [
			enemies.size(), enemies.size() + _enemy_shortfall])
	if _is_demo():
		notes.append("DEMO — bots only · Q for menu")
	if Settings.arena_random:
		# Random mode announces the round's world (v6.3) — the shuffle
		# should feel like a feature, not an accident.
		notes.append("arena: %s" % TileArt.label(_skin))
	if _teams_on():
		notes.append("TEAMS: %s" % Settings.TEAM_LABELS[Settings.team_mode])
	elif _teams_note:
		notes.append("teams need four bombers — free-for-all")
	if Settings.revenge_mode and players.size() > 1 and not Settings.try_theme:
		notes.append("REVENGE — the fallen bomb from the rim")
	_sub_banner.text = "  ·  ".join(notes)
	_sub_banner.visible = not notes.is_empty()
	_refresh_battle_point()
	if _help_mode != null:
		_help_mode.text = "GOAL: clear the whole pack — the world takes it from there" \
			if Story.active else \
			("GOAL: clear all monsters, then escape through the "
			+ "portal hidden under a brick — do NOT bomb the doorway!") \
			if _is_arcade() else \
			"GOAL: last bomber standing wins the round — first to %d round%s%s takes the battle" \
			% [Settings.wins_target, "" if Settings.wins_target == 1 else "s",
				" (by %d)" % Settings.win_margin if Settings.win_margin > 1 else ""]
	Music.urgent = false
	_timer_label.self_modulate = Color.WHITE
	_timer_shown = -1
	Sfx.play("count")
	if not _win_focused and not _is_demo():
		# Focus was lost during the previous round's ceremony (v10.3):
		# the fresh countdown must not play to an empty chair.
		_paused_from = state
		state = State.PAUSE
		_pause_sync.call()
		_pause_panel.visible = true


func _spawn_enemies(spawns: Array[Vector2i]) -> void:
	if Story.active:
		_spawn_story_pack(spawns)
		return
	var free := arena.floor_cells()
	var far: Array[Vector2i] = []
	for c in free:
		var ok := true
		for s in spawns:
			if absi(c.x - s.x) + absi(c.y - s.y) < 5:
				ok = false
				break
		if ok:
			far.append(c)
	# Prefer spawn cells with room to roam — a sealed brick pocket makes
	# an enemy look broken even though it's just walled in.
	var roomy: Array[Vector2i] = []
	var cramped: Array[Vector2i] = []
	for c in far:
		if _open_neighbors(c) >= 1:
			roomy.append(c)
		else:
			cramped.append(c)
	for i in Settings.enemy_count:
		var pool := roomy if not roomy.is_empty() else cramped
		if pool.is_empty():
			break
		var c := pool.pick_random() as Vector2i
		pool.erase(c)
		var etype := _roll_enemy_type()
		# Bomber mini-bosses spawn up to the Settings.max_bosses cap
		# (default 1); over-cap rolls deflate back to balloons, as do
		# cramped spawns (a 2-cell pocket makes every bomb verified
		# suicide — it would just pace its cage). Each boss dresses in
		# a random colour at spawn (bombs and flames too).
		if etype == "bomber" and (_boss_count() >= Settings.max_bosses
				or _open_neighbors(c) < 2):
			etype = "balloon"
		_spawn_enemy_at(etype, c)


## Story encounters (v7.1): the overworld pack, placed far from the
## player's corner. Same factory, same monsters — different master.
func _spawn_story_pack(spawns: Array[Vector2i]) -> void:
	var free := arena.floor_cells()
	var far: Array[Vector2i] = []
	for c in free:
		if absi(c.x - spawns[0].x) + absi(c.y - spawns[0].y) >= 6 \
				and _open_neighbors(c) >= 1:
			far.append(c)
	for etype: String in Story.pack:
		if far.is_empty():
			break
		var c := far.pick_random() as Vector2i
		far.erase(c)
		_spawn_enemy_at(etype, c)


## The single-enemy factory (v6.8, extracted so warlock summons, slime
## splits and probes can mint monsters too). Texture, stature, trail
## and the Menagerie's type-specific birth setup.
func _spawn_enemy_at(etype: String, c: Vector2i) -> Monster:
	var ecol := Color.WHITE
	if etype == "bomber":
		ecol = _random_boss_color()
		BomberArt.prewarm(ecol)   # all its views now, not on its first steps
	var spr := Sprite2D.new()
	spr.texture = _tex[{"balloon": "balloon", "chomper": "chomper_0",
		"saw": "saw", "ghost": "ghost", "bees": "bees",
		"elemental": "elemental", "slime": "slime", "snail": "snail",
		"frog": "frog", "mole": "mole", "thief": "thief",
		"freezer": "freezer", "muncher": "muncher", "mimic": "mimic",
		"warlock": "warlock", "bull": "bull", "snake": "snake_head",
		"centipede": "centi_head", "dragon": "dragon_head",
		}.get(etype, "balloon")] \
		if etype != "bomber" else BomberArt.texture("front", 0, ecol)
	if etype == "bomber":
		# Same stature as the players — it IS a bomberman (v4.2).
		spr.scale = Vector2.ONE * (cell_px * BOMBER_H_CELLS / (76.0 * BomberArt.RASTER_SCALE))
	else:
		spr.scale = Vector2.ONE * (cell_px / 64.0) * 1.06
	if etype == "ghost":
		spr.modulate.a = 0.8
	_entities_root.add_child(spr)
	var e := _new_monster(etype, c, ecol, spr)
	if etype == "chomper":
		# Golden dust trail while it prowls.
		var trail := CPUParticles2D.new()
		trail.amount = 12
		trail.lifetime = 0.45
		trail.local_coords = false
		trail.spread = 180.0
		trail.gravity = Vector2.ZERO
		trail.initial_velocity_min = cell_px * 0.05
		trail.initial_velocity_max = cell_px * 0.25
		trail.scale_amount_min = cell_px * 0.03
		trail.scale_amount_max = cell_px * 0.07
		var tramp := Gradient.new()
		tramp.set_color(0, Color(1.0, 0.85, 0.35, 0.8))
		tramp.set_color(1, Color(0.9, 0.6, 0.1, 0.0))
		trail.color_ramp = tramp
		# Parented to the world, not the (scaled, flipping) sprite —
		# particle sizes stay true; position follows in _move_enemies.
		_entities_root.add_child(trail)
		e.trail = trail
	spr.position = _to_px(e.pos)
	enemies.append(e)
	_men.on_spawn(e)
	return e


## Multiplayer keeps the classic pair; solo unlocks the full menagerie.
func _roll_enemy_type() -> String:
	if players.size() > 1:
		return "chomper" if rng.randf() < CHOMPER_P else "balloon"
	# Solo: the full 20-type menagerie, weighted so tier-1 fodder stays
	# common and the big serpents stay events (see Menagerie.TIER — a
	# future story mode can build waves from the same table).
	var table: Array = [
		["balloon", 12.0], ["slime", 8.0], ["snail", 7.0],
		["chomper", 8.0], ["bees", 7.0], ["frog", 6.0], ["mole", 6.0],
		["saw", 6.0],
		["ghost", 5.0], ["elemental", 5.0], ["freezer", 4.5],
		["thief", 4.5], ["muncher", 4.5], ["snake", 4.0],
		["mimic", 3.5], ["warlock", 3.0], ["bull", 3.0],
		["centipede", 2.5],
		["dragon", 1.5], ["bomber", 6.0],
	]
	var total := 0.0
	for row: Array in table:
		total += row[1]
	var r := rng.randf() * total
	for row: Array in table:
		r -= row[1]
		if r <= 0.0:
			return row[0]
	return "balloon"


func _spawn_player_node(p: Bomber) -> void:
	if p.node != null and is_instance_valid(p.node):
		p.node.queue_free()
	var node := Node2D.new()
	var spr := Sprite2D.new()
	node.add_child(spr)
	var curse_spr := Sprite2D.new()
	curse_spr.texture = _tex["item_skull"]
	curse_spr.scale = Vector2.ONE * (cell_px / 64.0) * 0.35
	curse_spr.position = Vector2(0, -cell_px * 1.32)
	curse_spr.visible = false
	node.add_child(curse_spr)
	if Settings.player_tags and players.size() > 1:
		# Optional seat tag (v10.0, OPTIONS): who's who when two players
		# picked near-twin colours. Rides the bomber, dies with it.
		var tag := Label.new()
		tag.text = (("P%d" % (p.i + 1)) if not p.bot \
			else ("B%d" % (p.i + 1 - _humans))) \
			+ (" A" if p.team == 0 else (" B" if p.team == 1 else ""))
		tag.add_theme_font_size_override("font_size", 12)
		tag.add_theme_color_override("font_color", Color.WHITE)
		tag.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		tag.add_theme_constant_override("outline_size", 6)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.custom_minimum_size = Vector2(44, 0)
		tag.position = Vector2(-22, -cell_px * 1.86)
		node.add_child(tag)
	_entities_root.add_child(node)
	node.position = _to_px(p.pos)
	p.node = node
	p.spr = spr
	p.curse_spr = curse_spr
	p.rim = false
	p.rim_cd = 0.0
	if is_instance_valid(p.rim_node):
		p.rim_node.queue_free()   # last round's revenge rig
	p.rim_node = null
	p.view = "front"
	p.flip = false
	p.frame = 0
	p.tex_key = ""
	_update_player_sprite(p)


## Apply the current view/frame texture (runtime-tinted via BomberArt)
## only when it actually changed.
func _update_player_sprite(p: Bomber) -> void:
	var key := "%s_%d_%s" % [p.view, p.frame, str(p.flip)]
	if key == p.tex_key:
		return
	p.tex_key = key
	var spr := p.spr as Sprite2D
	spr.texture = BomberArt.texture(p.view, p.frame, _player_col(p.i))
	spr.flip_h = p.flip
	# Template is 64×76 rasterized ×2; feet sit near the cell's floor.
	var target_h := cell_px * BOMBER_H_CELLS
	spr.scale = Vector2.ONE * (target_h / (76.0 * BomberArt.RASTER_SCALE))
	var base_y := cell_px * 0.5 - target_h * 0.5 + cell_px * 0.04
	p.spr_base_y = base_y
	spr.position = Vector2(0, base_y)


func _process(delta: float) -> void:
	# PAUSE freezes the WORLD (v12.6): flames, particles, burning bricks,
	# death spins and smoke used to play on behind the pause card — fire
	# burned out of sight yet stayed lethal on resume. The battle scene
	# itself keeps processing (input, HUD, the pause card); the four world
	# layers are pausable.
	var want_pause := state == State.PAUSE
	if get_tree().paused != want_pause:
		get_tree().paused = want_pause
	# A chain owns its Sfx voice until its last blast — renewed every
	# frame (PAUSE included) so a long pause can't hand it to a lone bomb
	# whose BOOM the chain's next beat would then cut (v12.2).
	for b: Dictionary in bombs:
		if b.has("chain"):
			Sfx.hold_voice(int(b["chain"]["voice"]), 0.3)
	# A hitch (shader compile, a new boss colour rasterizing) must not
	# move anything a whole cell unchecked: past 0.1 s the game slows
	# instead of tunnelling bombers through walls (v11.8).
	delta = minf(delta, 0.1)
	if state != State.PAUSE:
		_clock += delta
	if _help_overlay != null:
		var show_help := Input.is_action_pressed("help") and state != State.EXIT
		if show_help and not _help_overlay.visible:
			_help_overlay.move_to_front()  # ceremonies add their sheet later
		_help_overlay.visible = show_help
	match state:
		State.COUNTDOWN:
			_tick_countdown(delta)
		State.PLAY:
			_tick_play(delta)
		State.ROUND_END, State.BATTLE_END:
			_tick_chains(delta)  # a chain that ended the round still ripples out
			_tick_flames()
			if _cer_pending.is_valid() and _clock >= _cer_at:
				var show := _cer_pending
				_cer_pending = Callable()
				show.call()
			_end_t -= delta
			if state == State.ROUND_END and _end_t <= 0.0:
				_start_round()
			# Attract mode never stops: savour the trophy, then go again.
			elif state == State.BATTLE_END and _is_demo() and _end_t <= -6.0:
				_rematch()
		State.EXIT:
			_tick_chains(delta)
			_tick_flames()  # embers settle while the bomber spirals away
		State.PAUSE:
			pass
	# World offset = follow-camera (solo big arenas) + explosion shake.
	var shake_off := Vector2.ZERO
	if _shake > 0.0:
		_shake = maxf(_shake - delta * 30.0, 0.0)
		shake_off = Vector2(rng.randf_range(-_shake, _shake),
			rng.randf_range(-_shake, _shake))
	if _scroll_mode:
		var view := get_viewport().get_visible_rect().size
		var focus := _to_px(players[0].pos as Vector2)
		var want := focus - Vector2(view.x * 0.5, HUD_H + (view.y - HUD_H) * 0.5)
		want.x = clampf(want.x, 0.0, maxf(cell_px * arena.w + 24.0 - view.x, 0.0))
		want.y = clampf(want.y, 0.0,
			maxf(cell_px * arena.h + HUD_H + 20.0 - view.y, 0.0))
		_cam = _cam.lerp(want, 1.0 - exp(-delta * 6.0))
	var world_off := shake_off - _cam
	# The floor (checker + blast hint) shakes WITH the board — it used to
	# stand still while walls and bombers jittered over it (v12.6).
	_field.position = world_off
	_tiles_root.position = world_off
	_entities_root.position = world_off
	_flame_canvas.position = world_off
	_glow_canvas.position = world_off
	_goo_canvas.position = world_off


# ----------------------------------------------------------- sudden death ---
# Pressure blocks (v4.5, Settings.pressure_on, multiplayer only): once
# the clock crosses PRESSURE_START_S the arena starts closing — solid
# wall blocks slam down along an inward spiral, one every
# PRESSURE_STEP_S, crushing players (vest or not — this is stone, not
# fire), enemies, items, bricks, and squeezing bombs into detonation.
# The spiral is precomputed per round; sprites live in _tiles_root and
# are cleaned by the next _rebuild_board like everything else.

## Clockwise inward spiral over the inner cells, starting top-left.
func _build_pressure_order() -> void:
	_pressure_order.clear()
	_pressure_next = 0
	_pressure_accum = 0.0
	if not Settings.pressure_on or players.size() <= 1:
		return
	var x0 := 1
	var y0 := 1
	var x1 := arena.w - 2
	var y1 := arena.h - 2
	while x0 <= x1 and y0 <= y1:
		for x in range(x0, x1 + 1):
			_pressure_order.append(Vector2i(x, y0))
		for y in range(y0 + 1, y1 + 1):
			_pressure_order.append(Vector2i(x1, y))
		if y1 > y0:
			for x in range(x1 - 1, x0 - 1, -1):
				_pressure_order.append(Vector2i(x, y1))
		if x1 > x0:
			for y in range(y1 - 1, y0, -1):
				_pressure_order.append(Vector2i(x0, y))
		x0 += 1
		y0 += 1
		x1 -= 1
		y1 -= 1


func _tick_pressure(delta: float) -> void:
	_pressure_accum += delta
	while _pressure_accum >= PRESSURE_STEP_S \
			and _pressure_next < _pressure_order.size():
		_pressure_accum -= PRESSURE_STEP_S
		_drop_pressure_block(_pressure_order[_pressure_next])
		_pressure_next += 1


func _drop_pressure_block(c: Vector2i) -> void:
	if arena.cell(c.x, c.y) == Arena.WALL:
		return
	# Whatever occupied the cell is gone: brick, item, bomb (squeezed
	# bombs go off — chain rules apply), then the walls close.
	if brick_sprites.has(c):
		(brick_sprites[c] as Sprite2D).queue_free()
		brick_sprites.erase(c)
	if ground_items.has(c):
		ground_items.erase(c)
		if item_sprites.has(c):
			(item_sprites[c] as Sprite2D).queue_free()
			item_sprites.erase(c)
	for b: Dictionary in bombs.duplicate():
		if bombs.has(b) and b["cell"] == c:
			_detonate(b)
	arena.harden(c.x, c.y)
	for p: Bomber in players:
		if p.alive and Vector2i(p.pos.round()) == c:
			_kill_player(p)  # crushed — the vest is fireproof, not stone-proof
	for i in range(enemies.size() - 1, -1, -1):
		var e: Monster = enemies[i]
		if Vector2i(e.pos.round()) == c:
			if e.trail != null and is_instance_valid(e.trail):
				e.trail.queue_free()
			_men.free_parts(e)
			e.node.queue_free()
			enemies.remove_at(i)
			_update_portal_state()
	# The block itself: a wall tile (in the current skin) slamming down.
	var spr := Sprite2D.new()
	spr.texture = TileArt.wall(_skin)
	spr.scale = Vector2.ONE * (cell_px / spr.texture.get_width())
	spr.position = _to_px(Vector2(c))
	_tiles_root.add_child(spr)
	var target := spr.scale
	spr.scale = target * 1.5
	spr.modulate.a = 0.4
	var tw := spr.create_tween()
	tw.tween_property(spr, "scale", target, 0.14) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(spr, "modulate:a", 1.0, 0.14)
	Sfx.play("brick", 0.08)
	if Settings.screen_shake:
		_shake = minf(_shake + 1.5, 14.0)


## BATTLE POINT banner (v4.5, renamed v4.7): "one round win from
## taking the battle" is real
## under the deuce rule but used to be invisible — the HUD showed dots
## only. Recomputed at every round start.
func _refresh_battle_point() -> void:
	if _battlepoint_label == null:
		return
	var names: Array[String] = []
	for p: Bomber in players:
		var best_other := 0
		for q: Bomber in players:
			if q.i == p.i:
				continue
			if _teams_on() and q.team == p.team:
				continue   # a lockstep teammate is not a rival (v10.3)
			best_other = maxi(best_other, q.wins)
		if p.wins + 1 >= Settings.wins_target \
				and p.wins + 1 - best_other >= Settings.win_margin:
			names.append(_pname(p.i))
	_battlepoint_label.visible = players.size() > 1 and not names.is_empty()
	if _battlepoint_label.visible:
		_battlepoint_label.text = "BATTLE POINT — %s" % " & ".join(names)


## Random mini-boss colour, quantized to a coarse grid: every distinct
## colour rasterizes ~7 BomberArt textures that live for the session,
## so an unbounded random palette would leak texture memory steadily.
func _random_boss_color() -> Color:
	return Color.from_hsv(snappedf(rng.randf(), 1.0 / 24.0),
		snappedf(rng.randf_range(0.55, 0.85), 0.1),
		snappedf(rng.randf_range(0.75, 1.0), 0.1))


func _tick_countdown(delta: float) -> void:
	_count_t += delta
	var step := int(_count_t)
	if step != _count_step:
		_count_step = step
		match step:
			1, 2:
				_banner.text = str(3 - step)
				Sfx.play("count")
			3:
				# GO means go (v12.6): control starts WITH the word — it
				# used to follow a full second later, eating early bombs.
				_banner.text = "GO!"
				Sfx.play("go")
				_sub_banner.visible = false
				_go_hide_at = _clock + 0.6
				state = State.PLAY


func _tick_play(delta: float) -> void:
	if _go_hide_at > 0.0 and _clock >= _go_hide_at:
		_go_hide_at = 0.0
		if _banner.text == "GO!":
			_banner.visible = false
	round_t -= delta
	var secs := int(round_t)
	if secs != _timer_shown:
		_timer_shown = secs
		_timer_label.text = "%d:%02d" % [secs / 60, secs % 60]
	if Story.active and enemies.is_empty() and not _story_done and not _chain_live():
		_story_finish(true)  # pack cleared — the world takes it from here
		return
	if round_t <= 0.0:
		_finish_round(-2)  # timeout draw
		return
	# Hurry-up (v4.5): the last 30 s turn the clock red-and-pulsing and
	# push the generative music a step up — pressure you can hear.
	if round_t <= HURRY_S:
		Music.urgent = true
		var pulse := 0.55 + 0.45 * absf(sin(round_t * TAU * 0.9))
		_timer_label.self_modulate = Color(1.0, 1.0 - 0.65 * pulse, 1.0 - 0.65 * pulse)
	# Sudden death (v4.5, OPTIONS toggle, multiplayer): pressure blocks
	# spiral in from the border and crush whatever they land on.
	if Settings.pressure_on and players.size() > 1 \
			and round_t <= PRESSURE_START_S:
		_tick_pressure(delta)
	if Settings.blast_hint:
		# Repaint only while danger exists (plus one cleanup frame) —
		# the full-field redraw was the scene's biggest idle cost (v10.4).
		var danger_now := not bombs.is_empty() or not flames.is_empty()
		if danger_now or _hint_had_danger:
			_field.queue_redraw()
		_hint_had_danger = danger_now
	for p: Bomber in players:
		if p.alive:
			if p.bot:
				_brain.drive_bot(p, delta)
			_move_player(p, delta)
			_tick_status(p, delta)
		elif p.rim:
			_tick_rim(p, delta)
	_tick_bombs(delta)
	_tick_flames()
	if not goo.is_empty():
		for c: Vector2i in goo.keys():
			if float(goo[c]) < _clock:
				goo.erase(c)
				_goo_canvas.queue_redraw()
	_move_enemies(delta)
	_tick_fireballs(delta)
	_check_kills()
	# Solo: stepping into the open portal starts the escape.
	if _portal_open and _portal_spr != null and not _exiting \
			and players[0].alive \
			and Vector2i((players[0].pos as Vector2).round()) == portal_cell:
		_begin_exit(players[0])
		return
	_check_round_end()


# -------------------------------------------------------------- movement ----

func _input_vec(p: Bomber) -> Vector2:
	var acts: Dictionary = _acts[p.i]
	var v := Vector2.ZERO
	if Input.is_action_pressed(acts["up"]):
		v.y -= 1
	if Input.is_action_pressed(acts["down"]):
		v.y += 1
	if Input.is_action_pressed(acts["left"]):
		v.x -= 1
	if Input.is_action_pressed(acts["right"]):
		v.x += 1
	if p.curse == Curse.REVERSE or p.curse == Curse.REV_SLOW:
		v = -v
	return v


## Cell a player may occupy: floor (bricks too with wall-pass), and no
## bomb (unless they're still standing on it since placing).
func _passable(c: Vector2i, p_idx: int) -> bool:
	var v := arena.cell(c.x, c.y)
	if v == Arena.WALL or _is_burning(c):
		return false
	if v == Arena.BRICK and not players[p_idx].wallpass:
		return false
	var b: Variant = _bomb_cells().get(c)
	if b != null and not ((b as Dictionary)["walkers"] as Array).has(p_idx):
		return false
	return true


func _move_player(p: Bomber, delta: float) -> void:
	# Frozen solid (freezer touch, v6.8): no walking, no bombing — just
	# an icy tint and regret. Thaw restores the tint.
	if p.frozen_t > 0.0:
		p.frozen_t -= delta
		(p.spr as Sprite2D).self_modulate = Color(0.55, 0.8, 1.0)
		if p.frozen_t <= 0.0:
			(p.spr as Sprite2D).self_modulate = Color.WHITE
		return
	var iv := p.bot_dir if p.bot else _input_vec(p)
	if iv == Vector2.ZERO:
		p.move_dir = Vector2.ZERO
		p.frame = 0  # standing still
		# Sway and hop settle back to neutral when the run stops.
		var spr0 := p.spr as Sprite2D
		spr0.rotation = move_toward(spr0.rotation, 0.0, delta * 3.0)
		spr0.position.y = move_toward(spr0.position.y, p.spr_base_y as float,
			delta * cell_px)
		_update_player_sprite(p)
		_place_bomb_input(p)
		_pickup(p)  # loot under a STANDING player counts too (was move-only)
		return
	# One axis at a time; when both pressed, keep the current one.
	var axis_x := absf(iv.x) > 0.0
	if axis_x and absf(iv.y) > 0.0:
		if not p.bot:
			var acts: Dictionary = _acts[p.i]
			var sx := absf(Input.get_axis(acts["left"], acts["right"]))
			var sy := absf(Input.get_axis(acts["up"], acts["down"]))
			if p.move_dir == Vector2.ZERO:
				# From a standstill the STRONGER push wins (v11.8): a stick
				# pushed right but a little off-axis always went vertical.
				axis_x = sx >= sy
			else:
				# Moving, a CLEARLY stronger push on the other axis turns
				# (v12.6): with a stick held ~60° the old "keep the current
				# axis" ran you past every open junction. Two keys held =
				# equal strengths = no switch, as before.
				axis_x = p.move_dir.x != 0.0
				if axis_x and sy > sx + 0.2:
					axis_x = false
				elif not axis_x and sx > sy + 0.2:
					axis_x = true
		else:
			axis_x = p.move_dir.x != 0.0
		# Both held, the kept axis walled and the other open: take the
		# open one instead of grinding against the pillar.
		var here := Vector2i(p.pos.round())
		var ahead_x := here + Vector2i(int(signf(iv.x)), 0)
		var ahead_y := here + Vector2i(0, int(signf(iv.y)))
		if axis_x and not _passable(ahead_x, p.i) and _passable(ahead_y, p.i):
			axis_x = false
		elif not axis_x and not _passable(ahead_y, p.i) and _passable(ahead_x, p.i):
			axis_x = true
	var slow: bool = p.curse == Curse.SLOW or p.curse == Curse.REV_SLOW
	# Snail goo (v6.8): wading, not walking.
	var in_goo: bool = goo.has(Vector2i(p.pos.round()))
	var speed: float = 1.6 if slow else p.speed
	if in_goo:
		speed *= 0.55
	var step := speed * delta
	var pos: Vector2 = p.pos
	var cur := Vector2i(pos.round())
	var s := signf(iv.x) if axis_x else signf(iv.y)
	if axis_x:
		p.move_dir = Vector2(s, 0)
		var nxt := cur + Vector2i(int(s), 0)
		# STRICTLY short of the centre (v11.8): `(s > 0) == (pos.x < cur.x)`
		# read "at the centre" as short of it when moving LEFT — so the
		# kick and corner-assist branch below never ran going left/up.
		if _passable(nxt, p.i) or (s > 0 and pos.x < cur.x) or (s < 0 and pos.x > cur.x):
			# Ease onto the corridor center line.
			pos.y = move_toward(pos.y, roundf(pos.y), step)
			pos.x += s * step
			if not _passable(nxt, p.i):
				pos.x = minf(pos.x, float(cur.x)) if s > 0 else maxf(pos.x, float(cur.x))
		else:
			_try_kick(p, cur, nxt, absf(pos.y - roundf(pos.y)))
			# Corner assist: slide toward an open diagonal. The center
			# pull must NOT run here too — it used to undo the slide
			# exactly (net zero), freezing you on every pillar corner.
			# The slide passes THROUGH the side cell too (v11.8): checking
			# only the diagonal pulled you back into the bomb you had
			# just stepped off (or through a freshly dropped wall).
			var off := pos.y - roundf(pos.y)
			if off < -0.05 and _passable(cur + Vector2i(int(s), -1), p.i) \
					and _passable(cur + Vector2i(0, -1), p.i):
				pos.y -= step
			elif off > 0.05 and _passable(cur + Vector2i(int(s), 1), p.i) \
					and _passable(cur + Vector2i(0, 1), p.i):
				pos.y += step
			else:
				pos.y = move_toward(pos.y, roundf(pos.y), step)
	else:
		p.move_dir = Vector2(0, s)
		var nxt := cur + Vector2i(0, int(s))
		if _passable(nxt, p.i) or (s > 0 and pos.y < cur.y) or (s < 0 and pos.y > cur.y):
			pos.x = move_toward(pos.x, roundf(pos.x), step)
			pos.y += s * step
			if not _passable(nxt, p.i):
				pos.y = minf(pos.y, float(cur.y)) if s > 0 else maxf(pos.y, float(cur.y))
		else:
			_try_kick(p, cur, nxt, absf(pos.x - roundf(pos.x)))
			var off := pos.x - roundf(pos.x)
			if off < -0.05 and _passable(cur + Vector2i(-1, int(s)), p.i) \
					and _passable(cur + Vector2i(-1, 0), p.i):
				pos.x -= step
			elif off > 0.05 and _passable(cur + Vector2i(1, int(s)), p.i) \
					and _passable(cur + Vector2i(1, 0), p.i):
				pos.x += step
			else:
				pos.x = move_toward(pos.x, roundf(pos.x), step)
	p.pos = pos
	var node := p.node as Node2D
	node.position = _to_px(pos)
	# Directional walk animation: view by heading, two-frame stride.
	if axis_x:
		p.view = "side"
		p.flip = s < 0
	else:
		p.view = "front" if s > 0 else "back"
		p.flip = false
	p.anim_t += delta
	p.frame = int(p.anim_t / WALK_FRAME_S) % 2
	# The waddle: whole bomber (helmet included) rocks left-right, one
	# full sway per stride pair.
	# The run cycle: arm-swing frames (baked in the art) + a slight body
	# turn and a two-beat footfall hop per stride pair — weight, not bob.
	# Sprite update FIRST (it snaps position to base on texture swaps),
	# then the procedural motion goes on top.
	_update_player_sprite(p)
	var phase: float = p.anim_t * TAU / (WALK_FRAME_S * 4.0)
	var spr := p.spr as Sprite2D
	spr.rotation = sin(phase) * 0.055
	spr.position.y = (p.spr_base_y as float) - absf(sin(phase * 2.0)) * cell_px * 0.045
	_place_bomb_input(p)
	_pickup(p)


# --------------------------------------------------------------------- AI ---

## Cells that are lethal now or imminently: current flames plus the blast
## rays of every ticking bomb. Cached per frame (cheap, but called per AI).
var _danger_cache: Dictionary = {}
var _imminent_cache: Dictionary = {}   # see _imminent_cells
var _danger_frame := -1

func _danger_cells() -> Dictionary:
	var frame := Engine.get_process_frames()
	if frame == _danger_frame:
		return _danger_cache
	_danger_frame = frame
	_danger_cache = {}
	_imminent_cache = {}
	for c: Vector2i in flames:
		_danger_cache[c] = true
	# The prediction REPLAYS the blasts in detonation order (v12.2): each
	# pass picks the earliest bomb still waiting (its own fuse, or a beat
	# after a blast reaches it — CHAIN_GAP); its rays stop at bombs that
	# haven't gone off (lighting them), pass bombs already gone (a chained
	# bomb fires through its trigger's empty cell), stop at bricks still
	# burning (live _shield, or burnt in the replay less than SHIELD_S
	# before) and pass bricks/items burnt out by then. Burn-through and
	# timing feed each other, so passes repeat until stable (capped), and
	# every pass's reach counts — over-warning is safe, under-warning
	# kills bots. Brick cells count too: wall-pass campers die with them.
	# (v10.4 shared one burnt set — rays chewed through all brickwork;
	# v11.7-v12.1 let bombs vouch for each other or mistimed a lit bomb
	# hidden behind another.)
	var n := bombs.size()
	var te: Array[float] = []
	for b: Dictionary in bombs:
		te.append(float(b["t"]))
	var gone := {}   # brick/item cell -> {bomb index: true}
	for _pass in 6:
		var t2: Array[float] = []
		for b: Dictionary in bombs:
			t2.append(float(b["t"]))
		var done := {}
		var new_gone := {}
		for _k in n:
			var i := -1
			for j in n:
				if not done.has(j) and (i < 0 or t2[j] < t2[i]):
					i = j
			done[i] = true
			var waiting := {}
			for j in n:
				if not done.has(j):
					waiting[bombs[j]["cell"]] = true
			var b: Dictionary = bombs[i]
			var before := _gone_before(i, gone, t2)   # once, for bricks AND items
			var res: Dictionary = arena.blast(b["cell"], b["flame"], waiting,
				_items_left(before), before, _shield_at(t2[i]))
			for c: Vector2i in res["chains"]:
				for j in n:
					if not done.has(j) and bombs[j]["cell"] == c \
							and t2[i] + CHAIN_GAP < t2[j]:
						t2[j] = t2[i] + CHAIN_GAP   # lit: it pops a beat later
			for c: Vector2i in (res["flames"] as Array) + (res["bricks"] as Array):
				_danger_cache[c] = true
				if t2[i] <= IMMINENT_S:
					_imminent_cache[c] = true
			for c: Vector2i in (res["bricks"] as Array) + (res["items"] as Array):
				if not new_gone.has(c):
					new_gone[c] = {}
				new_gone[c][i] = true
		var stable := new_gone == gone and t2 == te
		gone = new_gone
		te = t2
		if stable:
			break
	return _danger_cache


## Rays of bombs going off within IMMINENT_S: no outrunning those (the
## brain's escape searches treat them like live fire, v12.2 — a lit
## chain link fires in CHAIN_GAP, and bots used to plan a sprint
## straight across its ray).
func _imminent_cells() -> Dictionary:
	_danger_cells()
	return _imminent_cache


## Live burning cells still blocking rays `t` seconds from now.
func _shield_at(t: float) -> Dictionary:
	var out := {}
	for c: Vector2i in _shield:
		if float(_shield[c]) > _clock + t:
			out[c] = true
	return out


## Cells in `gone` some other bomb has destroyed — and finished burning
## (SHIELD_S) — by the time bomb `i` goes off.
func _gone_before(i: int, gone: Dictionary, te: Array[float]) -> Dictionary:
	var out := {}
	for c: Vector2i in gone:
		for j: int in (gone[c] as Dictionary):
			if j != i and te[j] + SHIELD_S <= te[i]:
				out[c] = true
				break
	return out


## The ground items still lying there once the cells in `before` are gone.
func _items_left(before: Dictionary) -> Dictionary:
	if ground_items.is_empty() or before.is_empty():
		return ground_items
	var out := ground_items.duplicate()
	for c: Vector2i in before:
		out.erase(c)
	return out


func _place_bomb_input(p: Bomber) -> void:
	if p.bot:
		if not p.bot_bomb:
			return
		p.bot_bomb = false
	elif not Input.is_action_just_pressed(_acts[p.i]["bomb"]):
		return
	if p.curse == Curse.NO_BOMBS:
		if not p.bot:
			Sfx.play("pickup_denied")
		return
	# Bots bomb the cell they PLANNED at, never a re-round of a moving
	# position (see Bomber.bot_bomb_cell).
	_try_place_bomb(p, p.bot_bomb_cell if p.bot else Vector2i(-99, -99))


## Shared by keypresses and the AUTO-BOMB curse. Returns true if placed.
func _try_place_bomb(p: Bomber, at := Vector2i(-99, -99)) -> bool:
	if p.bombs_out >= p.bombs_max:
		return false
	# `at` (bots): the brain's planned cell. Default: where p stands.
	var c := at if at != Vector2i(-99, -99) else Vector2i(p.pos.round())
	if not _spawn_bomb(c, p.i, null, _player_col(p.i), p.flame):
		return false
	_danger_frame = -1  # same-frame planners must see this bomb (v10.4)
	p.bombs_out += 1
	p.stat_bombs += 1
	return true


## Muncher food (v6.8): a ticking bomb vanishes down a purple gullet.
## The owner gets the slot back — the bomb, they do not.
func _defuse_bomb(b: Dictionary) -> void:
	if b.has("chain"):   # a lit bomb eaten mid-chain no longer pending
		b["chain"]["pending"] = int(b["chain"]["pending"]) - 1
	if int(b["owner"]) >= 0:
		var o: Bomber = players[b["owner"]]
		o.bombs_out = maxi(o.bombs_out - 1, 0)
	elif b["owner_ref"] != null:
		var oref: Monster = b["owner_ref"]
		oref.bombs_out = maxi(oref.bombs_out - 1, 0)
	if is_instance_valid(b["node"]):
		(b["node"] as Sprite2D).queue_free()
	if is_instance_valid(b["spark"]):
		(b["spark"] as CPUParticles2D).queue_free()
	bombs.erase(b)
	_bomb_map_frame = -1


## The one true bomb factory: players pass their index, bomber ENEMIES
## pass owner -1 plus their own dict (for the bombs_out refund).
func _spawn_bomb(c: Vector2i, owner: int, owner_ref, col: Color, flame: int) -> bool:
	for b: Dictionary in bombs:
		if b["cell"] == c:
			return false
	if arena.solid(c.x, c.y) or _is_burning(c):
		return false
	# The centerpiece: an owner-tinted bomb that lives — spawn pop, an
	# accelerating heartbeat, sparking fuse, and a red panic blink at the
	# end. All driven per-frame in _tick_bombs.
	# Which costume this bomb wears is the OWNER's call (v8.9): each
	# seat may follow the global OPTIONS style or fly its own; monster
	# bombers (owner -1) follow the global. Snapshotted per bomb.
	var style := Settings.bomb_style_for(owner)
	var spr := Sprite2D.new()
	spr.texture = BomberArt.bomb_texture(col, style)
	# Sized so the black SPHERE spans the full cell (sphere is 46/64 of
	# the texture); bolt and spark poke into the row above, classic-style.
	var base := cell_px * 1.38 / (64.0 * BomberArt.RASTER_SCALE)
	spr.scale = Vector2.ONE * base
	spr.position = _bomb_px(Vector2(c))
	_entities_root.add_child(spr)
	# Fuse sparks — or, for the wickless potion (v6.0), lazy bubbles
	# rising through the liquid (the tick cranks speed_scale so the
	# brew boils harder as detonation nears).
	var spark := CPUParticles2D.new()
	var ramp := Gradient.new()
	if style == "potion":
		spark.amount = 10
		spark.lifetime = 0.9
		spark.local_coords = true   # rides the board under follow-cam / shake (v12.6)
		spark.direction = Vector2.UP
		spark.spread = 12.0
		spark.gravity = Vector2(0, -cell_px * 0.5)
		spark.initial_velocity_min = cell_px * 0.1
		spark.initial_velocity_max = cell_px * 0.25
		spark.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		spark.emission_rect_extents = Vector2(cell_px * 0.22, cell_px * 0.08)
		spark.scale_amount_min = cell_px * 0.03
		spark.scale_amount_max = cell_px * 0.06
		ramp.set_color(0, Color(col.lerp(Color.WHITE, 0.65), 0.0))
		ramp.add_point(0.3, Color(col.lerp(Color.WHITE, 0.7), 0.8))
		ramp.set_color(1, Color(col.lerp(Color.WHITE, 0.9), 0.0))
	else:
		spark.amount = 8
		spark.lifetime = 0.45
		spark.local_coords = true   # rides the board under follow-cam / shake (v12.6)
		spark.direction = Vector2.UP
		spark.spread = 55.0
		spark.gravity = Vector2(0, cell_px * 1.2)
		spark.initial_velocity_min = cell_px * 0.4
		spark.initial_velocity_max = cell_px * 1.0
		spark.scale_amount_min = cell_px * 0.025
		spark.scale_amount_max = cell_px * 0.055
		ramp.set_color(0, Color(1.0, 0.95, 0.6))
		ramp.add_point(0.5, col)
		ramp.set_color(1, Color(col.r, col.g, col.b, 0.0))
	spark.color_ramp = ramp
	spark.position = spr.position + _bomb_spark_off(style) * base * BomberArt.RASTER_SCALE
	spark.z_index = 1   # y-sorted entities: the fuse spark stays on top of its bomb
	_entities_root.add_child(spark)
	# Everyone currently on the cell may walk off it (owner included).
	var walkers: Array[int] = []
	for q: Bomber in players:
		if q.alive and Vector2i(q.pos.round()) == c:
			walkers.append(q.i)
	# Blast power and color are snapshotted at placement.
	_bomb_map_frame = -1
	bombs.append({"cell": c, "t": BOMB_FUSE, "owner": owner, "node": spr,
		"walkers": walkers, "phase": 0.0, "base": base, "pop": 0.22,
		"beat": 0, "spark": spark, "flame": flame, "col": col,
		"style": style, "owner_ref": owner_ref})
	Sfx.play("place")
	_danger_frame = -1  # every new bomb (rim throws too) enters the danger map now
	return true


func _pickup(p: Bomber) -> void:
	var c := Vector2i(p.pos.round())
	if not ground_items.has(c):
		return
	var item: int = ground_items[c]
	ground_items.erase(c)
	if item_sprites.has(c):
		(item_sprites[c] as Sprite2D).queue_free()
		item_sprites.erase(c)
	if item != Arena.ITEM_SKULL and item != Arena.ITEM_NASTY:
		p.stat_items += 1  # skulls are pickups, not power-ups
	match item:
		Arena.ITEM_BOMB:
			p.bombs_max = mini(p.bombs_max + 1, 8)
			Sfx.play("item")
		Arena.ITEM_FIRE:
			p.flame = mini(p.flame + 1, 10)
			Sfx.play("item")
		Arena.ITEM_SPEED:
			p.speed = minf(p.speed + SPEED_STEP, SPEED_MAX)
			Sfx.play("item")
		Arena.ITEM_SKULL:
			_apply_curse(p, rng.randi_range(Curse.REVERSE, Curse.NO_BOMBS),
				CURSE_S, false)
		Arena.ITEM_KICK:
			p.kick = true
			_popup("KICK!", COL_GOLD, _to_px(p.pos))
			Sfx.play("item")
		Arena.ITEM_VEST:
			p.vest_t = VEST_S
			_popup("FIREPROOF!", Color("ffb347"), _to_px(p.pos))
			Sfx.play("item")
		Arena.ITEM_WALLPASS:
			p.wallpass = true
			_popup("WALL PASS!", Color("9ad6ff"), _to_px(p.pos))
			Sfx.play("item")
		Arena.ITEM_NASTY:
			_apply_curse(p, rng.randi_range(Curse.AUTO_BOMB, Curse.REV_SLOW),
				NASTY_S, true)


## Curse a player (purple skull or green infection). The green one also
## marks them contagious — see the contagion pass in _check_kills.
func _apply_curse(p: Bomber, kind: int, duration: float, nasty: bool) -> void:
	p.curse = kind
	p.curse_t = duration
	p.nasty = nasty
	p.curse_spr.texture = _tex["item_nasty" if nasty else "item_skull"]
	p.curse_spr.visible = true
	_popup("INFECTED: " + CURSE_NAMES[kind] if nasty else CURSE_NAMES[kind],
		Color("7ade6a") if nasty else _player_col(p.i).lerp(Color.WHITE, 0.4),
		_to_px(p.pos))
	Sfx.play("skull")


## Per-frame status upkeep: curse timing (+AUTO-BOMB compulsion), vest
## timer, and the particle auras that trail each active effect.
func _tick_status(p: Bomber, delta: float) -> void:
	p.freeze_immune_t = maxf(p.freeze_immune_t - delta, 0.0)
	# SUGAR COATING (v11.0): the cabinet keeps every human's vest
	# eternally topped up — permanent shimmer, permanent fireproofing.
	if not p.bot and Settings.cheat("sugar"):
		p.vest_t = maxf(p.vest_t, 1.0)
	if p.vest_t > 0.0:
		p.vest_t -= delta
		# Golden shimmer on the suit while fireproof.
		p.spr.self_modulate = Color(1.0, 0.9, 0.55) \
			if int(Time.get_ticks_msec() / 120.0) % 2 == 0 else Color.WHITE
		if p.vest_t <= 0.0:
			p.spr.self_modulate = Color.WHITE
	if p.curse >= 0:
		p.curse_t -= delta
		var spr := p.curse_spr as Sprite2D
		spr.modulate.a = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.02)
		if p.curse == Curse.AUTO_BOMB:
			_try_place_bomb(p)  # the compulsion: bombs whenever possible
		if p.curse_t <= 0.0:
			p.curse = -1
			# Contagion grace: without this, two huddled players re-pass
			# the green skull the frame either timer expires — forever.
			if p.nasty:
				p.nasty_immune_t = 1.5
			p.nasty = false
			spr.visible = false
	if p.nasty_immune_t > 0.0:
		p.nasty_immune_t -= delta
	_ensure_fx(p, "curse", p.curse >= 0 and not p.nasty,
		[Color(0.75, 0.4, 0.95, 0.8), Color(0.4, 0.15, 0.55, 0.0)], 9, 0.09)
	_ensure_fx(p, "nasty", p.curse >= 0 and p.nasty,
		[Color(0.4, 0.9, 0.35, 0.85), Color(0.1, 0.35, 0.1, 0.0)], 18, 0.14)
	_ensure_fx(p, "vest", p.vest_t > 0.0,
		[Color(1.0, 0.85, 0.35, 0.9), Color(1.0, 0.6, 0.1, 0.0)], 8, 0.06)
	_ensure_fx(p, "wallpass", p.wallpass,
		[Color(0.65, 0.85, 1.0, 0.55), Color(0.5, 0.7, 1.0, 0.0)], 6, 0.07)


## Keep one continuous aura emitter per active effect on the player node.
## local_coords=false makes the particles hang in the world, so motion
## leaves a visible trail — the green infection smokes as you run.
func _ensure_fx(p: Bomber, key: String, active: bool, colors: Array,
		amount: int, size_frac: float) -> void:
	var fx := p.fx
	if active and not fx.has(key):
		var part := CPUParticles2D.new()
		part.amount = amount
		part.lifetime = 0.75
		part.local_coords = false
		part.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		part.emission_sphere_radius = cell_px * 0.3
		part.direction = Vector2.UP
		part.spread = 40.0
		part.gravity = Vector2(0, -cell_px * 0.8)
		part.initial_velocity_min = cell_px * 0.1
		part.initial_velocity_max = cell_px * 0.4
		part.scale_amount_min = cell_px * size_frac * 0.6
		part.scale_amount_max = cell_px * size_frac
		var ramp := Gradient.new()
		ramp.set_color(0, colors[0])
		ramp.set_color(1, colors[1])
		part.color_ramp = ramp
		p.node.add_child(part)
		fx[key] = part
	elif not active and fx.has(key):
		var part := fx[key] as CPUParticles2D
		if is_instance_valid(part):
			part.queue_free()
		fx.erase(key)


# ----------------------------------------------------------------- bombs ----

## Bump-to-kick: walking into a bomb (with the kick power-up, no second
## button) sends it sliding until it hits anything solid — or somebody.
func _try_kick(p: Bomber, cur: Vector2i, nxt: Vector2i, cross_off: float) -> void:
	if not p.kick or cross_off > 0.25:
		return
	for b: Dictionary in bombs:
		if b["cell"] == nxt and not b.has("slide"):
			# A wedged bomb doesn't budge — and must not "kick" 60 times a
			# second (the slide was cancelled next tick and re-armed, the
			# kick sound hogging the voice pool) (v11.8).
			if _kick_blocked(nxt + (nxt - cur), b):
				return
			b["slide"] = nxt - cur
			b["spos"] = Vector2(b["cell"] as Vector2i)
			Sfx.play("kick")
			return


## True if a sliding bomb must stop before entering cell c.
func _kick_blocked(c: Vector2i, self_bomb: Dictionary) -> bool:
	if arena.solid(c.x, c.y) or _is_burning(c):
		return true
	for b: Dictionary in bombs:
		if b == self_bomb:
			continue
		if b["cell"] == c:
			return true
		# Two sliders heading into each other must meet, not pass
		# through (each only claimed its next cell past the midpoint).
		if b.has("slide") and (b["cell"] as Vector2i) + (b["slide"] as Vector2i) == c:
			return true
	for p: Bomber in players:
		if p.alive and Vector2i(p.pos.round()) == c:
			return true
	for e: Monster in enemies:
		if e.mode == "burrow" or e.mode == "air":
			continue  # nothing there to bump — touch ignores them too
		# (A DISGUISED mimic still blocks: it is drawn as a brick, and a
		# bomb sliding through "a brick" gave the disguise away, v12.2.)
		if Vector2i(e.pos.round()) == c:
			return true
	return false


func _tick_bombs(delta: float) -> void:
	# Kicked bombs slide cell to cell; the fuse keeps burning en route.
	for b: Dictionary in bombs:
		if not b.has("slide"):
			continue
		var dirv := Vector2(b["slide"] as Vector2i)
		# Sub-stepped (v11.8): one long frame used to carry a bomb past
		# the cell it never checked — into a wall or brick.
		var left := KICK_SPEED * delta
		var cur := Vector2i((b["spos"] as Vector2).round())
		while left > 0.0 and b.has("slide"):
			var stp := minf(left, 0.45)
			left -= stp
			b["spos"] = (b["spos"] as Vector2) + dirv * stp
			cur = Vector2i((b["spos"] as Vector2).round())
			if b["cell"] != cur:
				b["cell"] = cur
				_bomb_map_frame = -1
			var past_center := ((b["spos"] as Vector2) - Vector2(cur)).dot(dirv) >= 0.0
			if past_center and _kick_blocked(cur + (b["slide"] as Vector2i), b):
				b["spos"] = Vector2(cur)
				b.erase("slide")
		(b["node"] as Sprite2D).position = _bomb_px(b["spos"] if b.has("slide") else Vector2(cur))
		(b["spark"] as CPUParticles2D).position = (b["node"] as Sprite2D).position \
			+ _bomb_spark_off(str(b["style"])) * (b["base"] as float) \
			* BomberArt.RASTER_SCALE

	# The living bomb: heartbeat that races as the fuse shortens, spawn
	# pop, and an overbright red panic blink (with ticking) near zero.
	for b: Dictionary in bombs:
		var t: float = b["t"]
		var urgency := clampf(1.4 / maxf(t, 0.18), 1.0, 8.0)
		b["phase"] = (b["phase"] as float) + delta * TAU * urgency
		var phase: float = b["phase"]
		var amp := 0.05 + 0.05 * (1.0 - clampf(t / BOMB_FUSE, 0.0, 1.0))
		var pop_extra := 0.0
		if b["pop"] > 0.0:
			b["pop"] = (b["pop"] as float) - delta
			var k: float = maxf(b["pop"], 0.0) / 0.22
			pop_extra = 0.45 * k * k  # lands with a squash
		var spr := b["node"] as Sprite2D
		spr.scale = Vector2.ONE * (b["base"] as float) \
			* (1.0 + amp * sin(phase) + pop_extra)
		match str(b["style"]):
			"dynamite":
				spr.rotation = 0.05 * sin(phase * 3.0)
			"naval":
				spr.rotation += delta * (0.5 + urgency * 0.3)
			"aviatic":
				spr.rotation = 0.12 * sin(phase * 0.5)
			"acme":
				spr.rotation = 0.08 * sin(phase)
			"potion":
				# Gentle slosh; the brew boils harder as time runs out,
				# and the cork gives up half a second before the boom.
				spr.rotation = 0.05 * sin(phase * 1.2)
				(b["spark"] as CPUParticles2D).speed_scale = urgency * 0.7
				if t < 0.5 and not b.has("uncorked"):
					b["uncorked"] = true
					_uncork_potion(b)
			_:
				pass  # classic: the heartbeat is the show
		if t < 0.9:
			var blink := 0.5 + 0.5 * sin(phase * 2.0)
			spr.modulate = Color(1.0 + 0.5 * blink, 1.0 - 0.35 * blink, 1.0 - 0.35 * blink)
		var beat := int(phase / TAU)
		if beat != b["beat"]:
			b["beat"] = beat
			if t < 1.5 and Time.get_ticks_msec() - _last_tick_ms >= 60:
				# A 20-bomb chain ticked 60-160x/s through the 10-voice
				# pool and stole the staggered BOOMs' voices (v10.4).
				_last_tick_ms = Time.get_ticks_msec()
				Sfx.play("tick", 0.03)
	# Walk-off: once you leave the cell you placed on, the bomb is solid.
	for b: Dictionary in bombs:
		var walkers := b["walkers"] as Array
		for i in range(walkers.size() - 1, -1, -1):
			var p: Bomber = players[walkers[i]]
			if Vector2i(p.pos.round()) != b["cell"]:
				walkers.remove_at(i)
	# A bomb touching fire that no blast has claimed goes off at once (one
	# kicked into flames, or placed onto a still-burning cell); a bomb a
	# blast's ray reached is CHAINED — it waits out its CHAIN_GAP fuse
	# even though that blast's fire covers its cell (see _detonate).
	# Collect first, detonate after: no per-frame array duplication.
	var to_blow: Array = []
	for b: Dictionary in bombs:
		b["t"] -= delta
		if b["t"] <= 0.0 or (flames.has(b["cell"]) and not b.has("chain")):
			to_blow.append(b)
	for b: Dictionary in to_blow:
		if bombs.has(b):  # may have been chain-detonated already
			_detonate(b)


## cell -> bomb, built once per frame and rebuilt the moment bombs
## change (_bomb_map_frame = -1 at every spawn/detonate/defuse/slide/
## clear). Path searches ask "is there a bomb here?" for every cell they
## touch: it used to loop over every bomb each time — 32 lookups per cell
## under DELUXE, per bot, per replan (v12.6). Read-only for callers.
func _bomb_cells() -> Dictionary:
	var f := Engine.get_process_frames()
	if f != _bomb_map_frame:
		_bomb_map_frame = f
		_bomb_map = {}
		for b: Dictionary in bombs:
			_bomb_map[b["cell"]] = b
	return _bomb_map


## One blast. Chain reactions PROPAGATE (v12.1): bombs this blast
## reaches are lit (_light) and go off CHAIN_GAP later, each playing its
## own beat on the chain's Sfx voice as it pops — "bo" while the chain
## has bombs to go, the full BOOM on the one that ends it. (v4-v12.0
## detonated the whole chain in ONE frame and staged only the sound,
## so every brick crunch landed at once and the picture never rippled.)
func _detonate(b: Dictionary) -> void:
	# The chain this blast belongs to: {"voice": Sfx boom voice, "pending":
	# bombs it has lit that haven't gone off yet}. No chain = a new root.
	var chain: Dictionary = b.get("chain", {})
	var is_root := chain.is_empty()
	if is_root:
		chain = {"voice": Sfx.boom_voice(), "pending": 0}
	else:
		chain["pending"] = int(chain["pending"]) - 1
	bombs.erase(b)
	_bomb_map_frame = -1
	(b["node"] as Sprite2D).queue_free()
	if is_instance_valid(b["spark"]):
		(b["spark"] as CPUParticles2D).queue_free()
	if b["owner"] >= 0:
		var owner: Bomber = players[b["owner"]]
		owner.bombs_out = maxi(owner.bombs_out - 1, 0)
	elif b["owner_ref"] != null:
		var oref: Monster = b["owner_ref"]
		oref.bombs_out = maxi(int(oref.bombs_out) - 1, 0)
	# Bricks still burning (SHIELD_S) stop rays: without this a chained
	# bomb's ray flew through the brick its trigger had just burned —
	# torching the item it revealed, or "bombing" a doorway the same
	# chain had only just uncovered.
	for c: Vector2i in _shield.keys():
		if float(_shield[c]) <= _clock:
			_shield.erase(c)
	var res := arena.blast(b["cell"], b["flame"], _bomb_cells(), ground_items,
		{}, _shield)
	for c: Vector2i in res["bricks"]:
		_shield[c] = _clock + SHIELD_S
		_burning[c] = _clock + SHIELD_S
		_revealed[c] = chain
	var now := _clock
	var col: Color = b["col"]
	# Battle stats (v6.3): bricks credit the bomb's owner; flames carry
	# the owner so kills can be attributed in _check_kills.
	if int(b["owner"]) >= 0:
		players[b["owner"]].stat_bricks += (res["bricks"] as Array).size()
	for c: Vector2i in res["flames"]:
		# born drives the swell; the per-cell random shape/phase keeps the
		# blast irregular — no two cells (or explosions) draw alike.
		flames[c] = {"t": now + FLAME_S, "col": col, "born": now,
			"owner": b["owner"],
			"rs": rng.randf_range(0.82, 1.18), "ph": rng.randf() * TAU,
			"rj": Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1))}
	_fx.spawn_blast(b["cell"], res["flames"], col)
	# Bombing the revealed doorway has consequences (v4.0): the portal
	# answers with a bomber mini-boss of its own.
	# Not after the round (a chain still rippling through a defeat must
	# not wake the door), and never for the chain that uncovered it.
	if _portal_spr != null and not _exiting and state == State.PLAY \
			and (res["flames"] as Array).has(portal_cell) \
			and not is_same(_revealed.get(portal_cell), chain):
		_portal_punish()
	for c: Vector2i in res["bricks"]:
		_burn_brick(c)
		# Wall-pass campers hiding INSIDE a brick die when it burns —
		# bricks stop the ray so they never counted as flame cells, and
		# brick-sheltering was a strictly dominant endgame exploit.
		# (The vest still saves them: it is fireproof, and this is fire.)
		# Only in play: a chain still rippling after the round ended
		# must not kill the winner during the ceremony.
		for p: Bomber in players:
			if state == State.PLAY and p.alive and p.vest_t <= 0.0 \
					and Vector2i(p.pos.round()) == c:
				_kill_player(p)
	# The blast burns revealed items — INCLUDING one directly under the
	# bomb (the rays-only check used to spare the origin cell).
	var burned_items: Array = res["items"]
	if ground_items.has(b["cell"]):
		burned_items = burned_items.duplicate()
		burned_items.append(b["cell"])
	# A chain spares the loot it uncovered itself, however long it runs.
	burned_items = burned_items.filter(func(c: Vector2i) -> bool:
		return not is_same(_revealed.get(c), chain))
	for c: Vector2i in res["items"]:
		_shield[c] = _clock + SHIELD_S  # a burning item stops rays too
	for c: Vector2i in burned_items:
		ground_items.erase(c)
		if item_sprites.has(c):
			(item_sprites[c] as Sprite2D).queue_free()
			item_sprites.erase(c)
	if Settings.screen_shake:
		_shake = minf(_shake + 7.0, 14.0)  # chains stack up to a real thump
	# Haptics track the screen shake: a blast within ~4 cells taps the
	# pad, scaled by how close it went off.
	for p: Bomber in players:
		if p.alive:
			var d := p.pos.distance_to(Vector2(b["cell"] as Vector2i))
			if d < 4.5:
				_rumble(p, 0.5 - d * 0.1, 0.25 - d * 0.05, 0.2)
	_rings.append({"px": _to_px(Vector2(b["cell"] as Vector2i)),
		"born": _clock, "col": col})
	_flame_canvas.queue_redraw()
	_glow_canvas.queue_redraw()
	# Light the next link: every bomb this blast reached joins its chain
	# and goes off CHAIN_GAP later (or sooner, if its own fuse is shorter)
	# — the ripple you see AND hear. A bomb already lit keeps its chain.
	for c: Vector2i in res["chains"]:
		for other: Dictionary in bombs:
			if other["cell"] != c:
				continue
			if not other.has("chain"):
				_light(other, chain, CHAIN_GAP)
			else:
				# Already lit (a FEVER slot seconds away, or another
				# chain's): fire reaching it still sets it off NEXT beat.
				other["t"] = minf(float(other["t"]), CHAIN_GAP)
	if is_root and Settings.cheat("fever"):
		# CHAIN FEVER (v11.0): sympathetic detonation — every bomb left
		# on the field joins this chain, one beat after another, so the
		# machine-gun rattle plays the whole arsenal.
		var k := 1
		for other: Dictionary in bombs:
			if not other.has("chain"):
				_light(other, chain, CHAIN_GAP * k)
				k += 1
	# This blast's own beat, NOW, on the chain's voice — so sound and
	# picture can't drift apart. While the chain still has bombs to go it
	# is the short hop ("bo"), and each beat cuts the last; the blast
	# that ends the chain (or a lone bomb) is the full BOOM.
	var more := int(chain["pending"]) > 0
	Sfx.play_boom(int(chain["voice"]), "boom_hop" if more else "boom", 0.06,
		1.0, CHAIN_GAP / maxf(Engine.time_scale, 0.05) if more else 0.0)


## A brick at `c` still burning (solid, see _burning)?
func _is_burning(c: Vector2i) -> bool:
	return _burning.has(c) and float(_burning[c]) > _clock


## Any chain still rippling? While one is, the round isn't decided.
func _chain_live() -> bool:
	for b: Dictionary in bombs:
		if b.has("chain"):
			return true
	return false


## A chain cut short (R, a new round, leaving the battle) still lands
## its final BOOM — once per chain, on its own voice. Its last real
## blast played the short hop, expecting more to come.
func _end_chains() -> void:
	var done := []
	for b: Dictionary in bombs:
		if b.has("chain") and not done.any(func(c) -> bool: return is_same(c, b["chain"])):
			done.append(b["chain"])
			Sfx.play_boom(int(b["chain"]["voice"]), "boom")


## Claim bomb `b` for `chain`: it goes off within `fuse` seconds.
func _light(b: Dictionary, chain: Dictionary, fuse: float) -> void:
	b["chain"] = chain
	chain["pending"] = int(chain["pending"]) + 1
	b["t"] = minf(float(b["t"]), fuse)


## Chained bombs keep counting down after the round ends (ROUND_END,
## BATTLE_END, EXIT) — a chain that won the round finishes its ripple
## instead of freezing mid-row. Unlit bombs stay frozen, as ever.
func _tick_chains(delta: float) -> void:
	var to_blow: Array = []
	for b: Dictionary in bombs:
		if b.has("chain"):
			b["t"] -= delta
			if b["t"] <= 0.0:
				to_blow.append(b)
	for b: Dictionary in to_blow:
		if bombs.has(b):
			_detonate(b)


func _burn_brick(c: Vector2i) -> void:
	var item := arena.burn(c)
	# The burn plays on the GAME clock for exactly as long as the cell
	# stays solid (_burning, SHIELD_S): it used to fade out in 0.3 s of
	# wall time — an invisible wall for the rest of the burn, and a fade
	# that finished behind the pause card (v12.6). See _tick_burns.
	var burn := {"spr": null, "base": Vector2.ONE, "item": null}
	if brick_sprites.has(c):
		var spr := brick_sprites[c] as Sprite2D
		brick_sprites.erase(c)
		burn["spr"] = spr
		burn["base"] = spr.scale
	_burn_fx[c] = burn
	Sfx.play("brick", 0.12)
	if c == portal_cell:
		if state == State.PLAY:   # not over a defeat ceremony (v12.2)
			_reveal_portal()
		return  # the portal claims the cell — no item on top of it
	if item != Arena.ITEM_NONE:
		ground_items[c] = item
		var spr := Sprite2D.new()
		spr.texture = _tex[ITEM_SPRITES[item]]
		spr.scale = Vector2.ONE * (cell_px / 64.0) * 0.82
		spr.position = _to_px(Vector2(c))
		spr.visible = false   # revealed when the brick has burnt away
		_tiles_root.add_child(spr)
		item_sprites[c] = spr
		burn["item"] = spr


## Burning bricks: glow, swell and fade on the game clock, then make way
## for whatever they were hiding.
func _tick_burns() -> void:
	for c: Vector2i in _burn_fx.keys():
		var b: Dictionary = _burn_fx[c]
		var k := clampf((float(_burning.get(c, 0.0)) - _clock) / SHIELD_S, 0.0, 1.0)
		var spr: Variant = b["spr"]
		if spr != null and is_instance_valid(spr):
			(spr as Sprite2D).modulate = Color.WHITE.lerp(Color(1, 0.5, 0.2, 0.0), 1.0 - k)
			(spr as Sprite2D).scale = (b["base"] as Vector2) * (1.0 + 0.2 * (1.0 - k))
		if k > 0.0:
			continue
		if spr != null and is_instance_valid(spr):
			(spr as Sprite2D).queue_free()
		var item: Variant = b["item"]
		if item != null and is_instance_valid(item):
			(item as Sprite2D).visible = true
		_burn_fx.erase(c)


func _tick_flames() -> void:
	if not _burn_fx.is_empty():
		_tick_burns()
	var now := _clock
	var expired: Array = []
	for c: Vector2i in flames:
		if flames[c]["t"] <= now:
			expired.append(c)
	for c: Vector2i in expired:
		flames.erase(c)
	if not expired.is_empty() or not flames.is_empty() \
			or not _rings.is_empty():
		_flame_canvas.queue_redraw()
		_glow_canvas.queue_redraw()


## Explosion signature color: the owner's pick, saturation-boosted so
## the blast unmistakably reads as THEIRS (pale picks stay pale — a
## white bomber's fire is white fire; near-black stays brooding).
func _vivid(col: Color) -> Color:
	return Color.from_hsv(col.h, minf(col.s * 1.4, 1.0),
		clampf(col.v * 1.1, 0.0, 1.0))


# --------------------------------------------------------------- enemies ----

func _move_enemies(delta: float) -> void:
	for e: Monster in enemies:
		var chomper: bool = e.type == "chomper"
		var speed := ENEMY_SPEED
		# Chomper temper: patrol until someone strays close, then hunt
		# them for 5 s, then lose interest and cool off for 3 s.
		if chomper:
			e.cool_t = maxf((e.cool_t as float) - delta, 0.0)
			if e.chase_t > 0.0:
				e.chase_t = (e.chase_t as float) - delta
				speed = CHOMPER_CHASE_SPEED
				if e.chase_t <= 0.0:
					e.cool_t = 3.0  # lets go
			elif e.cool_t <= 0.0:
				for p: Bomber in players:
					if p.alive and p.pos.distance_to(e.pos) < CHOMPER_SENSE:
						e.chase_t = 5.0
						break
		# Per-type movement personality.
		var etype: String = e.type
		match etype:
			"saw":
				speed = 3.4
			"ghost":
				speed = 1.4
			"bees":
				speed = 2.3
			"elemental":
				speed = 1.5
				_elemental_tick(e, delta)
			"bomber":
				speed = 2.4
			_:
				var msp := _men.speed(e)
				if msp > 0.0:
					speed = msp
		# Destination walker: enemies commit to a neighboring cell and
		# walk center-to-center, deciding anew only on ARRIVAL. (The old
		# "am I near a center?" check snapped them back every frame — the
		# per-frame step was smaller than the threshold, so they vibrated
		# in place forever. This is the classic fix.)
		var pos: Vector2 = e.pos
		# The Menagerie runs each type's state machine first; a false
		# return means the type is doing its own locomotion this frame
		# (burrowed, mid-hop, disguised, charging, stunned).
		if not _men.pre_walk(e, delta):
			pass
		elif e.dir == Vector2i.ZERO or not e.has_dest():
			# An idle mini-boss used to re-plan EVERY frame (BFS, mining
			# scan, escape check) while glaring at a wall — up to 8 s at a
			# time, per boss. Idle bosses think at most every 0.08 s (v12.6).
			e.think_t -= delta
			if e.type != "bomber" or e.think_t <= 0.0:
				_enemy_decide(e, Vector2i(pos.round()))
				if e.type == "bomber" and (e.dir == Vector2i.ZERO or not e.has_dest()):
					e.think_t = 0.08
		else:
			var dest: Vector2i = e.dest
			var dest_ok := _ghost_passable(dest) if etype == "ghost" \
				else _enemy_passable(dest) or _men.may_enter_bomb(e, dest)
			if not dest_ok and pos.distance_to(Vector2(dest)) > 0.55:
				# A bomb landed in our path before we crossed in — rethink.
				_enemy_decide(e, Vector2i(pos.round()))
			else:
				pos = pos.move_toward(Vector2(dest), speed * delta)
				e.pos = pos
				if pos.is_equal_approx(Vector2(dest)):
					e.pos = Vector2(dest)
					_enemy_decide(e, dest)
		pos = e.pos
		var dir: Vector2i = e.dir
		var node := e.node as Sprite2D
		node.position = _to_px(pos)
		e.anim_t = (e.anim_t as float) + delta
		# Per-type rendering personality.
		if etype == "saw":
			node.rotation += delta * 11.0
		elif etype == "ghost":
			node.modulate.a = 0.65 + 0.15 * sin((e.anim_t as float) * 2.4)
			node.position.y += sin((e.anim_t as float) * 3.0) * cell_px * 0.07
		elif etype == "bees":
			node.position += Vector2(sin((e.anim_t as float) * 23.0),
				cos((e.anim_t as float) * 19.0)) * cell_px * 0.05
			node.rotation = sin((e.anim_t as float) * 13.0) * 0.12
		elif etype == "elemental":
			var s := 1.06 + 0.05 * sin((e.anim_t as float) * 8.0)
			node.scale = Vector2.ONE * (cell_px / 64.0) * s
		elif etype == "bomber":
			_bomber_enemy_render(e, dir)
		_men.post_move(e, delta)  # serpent bodies follow the head
		if e.trail != null:
			var tr := e.trail as CPUParticles2D
			tr.emitting = dir != Vector2i.ZERO
			tr.position = node.position
		if chomper:
			# Chomp-chomp: mouth cycles fast on the hunt, lazy on patrol.
			var rate := 0.11 if e.chase_t > 0.0 else 0.22
			node.texture = _tex["chomper_0" if int((e.anim_t as float) / rate) % 2 == 0 else "chomper_1"]
			if dir.x != 0:
				node.flip_h = dir.x < 0
			node.position.y += sin((e.anim_t as float) * 9.0) * cell_px * 0.02
		elif etype == "balloon":
			# Balloon ONLY — this branch once said `else:` and stomped the
			# balloon texture onto every other enemy type (bombers became
			# tiny balloons: balloon art at the bomber-raster scale).
			# Drift-bob and the occasional blink.
			e.blink_t = (e.blink_t as float) - delta
			if e.blink_t <= 0.0:
				e.blink_t = rng.randf_range(1.6, 3.4)
				e.blink_hold = 0.15
			if e.blink_hold > 0.0:
				e.blink_hold = (e.blink_hold as float) - delta
				node.texture = _tex["balloon_blink"]
			else:
				node.texture = _tex["balloon"]
			node.position.y += sin((e.anim_t as float) * 4.0 + pos.x * 3.0) * cell_px * 0.05


func _nearest_player_cell(from: Vector2) -> Vector2i:
	var best := Vector2i.ZERO
	var best_d := 1e9
	for p: Bomber in players:
		if p.alive:
			var d := p.pos.distance_to(from)
			if d < best_d:
				best_d = d
				best = Vector2i(p.pos.round())
	return best


func _open_neighbors(c: Vector2i) -> int:
	var n := 0
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if arena.cell(c.x + d.x, c.y + d.y) == Arena.FLOOR:
			n += 1
	return n


## Ghosts drift through bricks; walls and bombs still stop them.
func _ghost_passable(c: Vector2i) -> bool:
	if arena.cell(c.x, c.y) == Arena.WALL:
		return false
	for b: Dictionary in bombs:
		if b["cell"] == c:
			return false
	return true


## Fire elemental: when its cooldown is up and a player stands on a clear
## straight line within range, it spits a fireball down that line.
func _elemental_tick(e: Monster, delta: float) -> void:
	e.shoot_t = (e.shoot_t as float) - delta
	if e.shoot_t > 0.0:
		return
	e.shoot_t = rng.randf_range(1.0, 1.8)  # recheck cadence when idle
	var ec := Vector2i(e.pos.round())
	for p: Bomber in players:
		if not p.alive:
			continue
		var pc := Vector2i(p.pos.round())
		if pc.x != ec.x and pc.y != ec.y:
			continue
		var dist := absi(pc.x - ec.x) + absi(pc.y - ec.y)
		if dist > 6 or dist == 0:
			continue
		var dirv := Vector2i(signi(pc.x - ec.x), signi(pc.y - ec.y))
		var clear := true
		for step in range(1, dist):
			var q := ec + dirv * step
			if arena.solid(q.x, q.y):
				clear = false
				break
		if clear:
			_spawn_fireball(Vector2(ec), dirv, e)
			e.shoot_t = rng.randf_range(2.6, 4.0)
			return


func _spawn_fireball(from: Vector2, dirv: Vector2i, _e: Monster) -> void:
	var trail := CPUParticles2D.new()
	trail.amount = 18
	trail.lifetime = 0.35
	trail.local_coords = false
	trail.spread = 180.0
	trail.gravity = Vector2(0, -cell_px * 0.6)
	trail.initial_velocity_min = cell_px * 0.1
	trail.initial_velocity_max = cell_px * 0.5
	trail.scale_amount_min = cell_px * 0.05
	trail.scale_amount_max = cell_px * 0.12
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.9, 0.5))
	ramp.add_point(0.5, Color(0.94, 0.41, 0.09))
	ramp.set_color(1, Color(0.4, 0.1, 0.02, 0.0))
	trail.color_ramp = ramp
	trail.position = _to_px(from)
	_flame_canvas.add_child(trail)
	fireballs.append({"pos": from, "dir": dirv, "trail": trail})
	Sfx.play("spit")


func _tick_fireballs(delta: float) -> void:
	for i in range(fireballs.size() - 1, -1, -1):
		var fb: Dictionary = fireballs[i]
		fb["pos"] = (fb["pos"] as Vector2) + Vector2(fb["dir"] as Vector2i) * FIREBALL_SPEED * delta
		var c := Vector2i((fb["pos"] as Vector2).round())
		var trail := fb["trail"] as CPUParticles2D
		# Fire touches bomb = boom, no exceptions — a fireball crossing a
		# bomb detonates it (and dies in the blast).
		var hit_bomb := false
		for b: Dictionary in bombs.duplicate():
			if bombs.has(b) and b["cell"] == c:
				_detonate(b)
				hit_bomb = true
				break
		if arena.solid(c.x, c.y) or hit_bomb:
			trail.emitting = false
			# Bound to the trail itself, not a lambda capturing it: the
			# connection dies with the node (a battle left mid-fireball
			# used to log "lambda capture was freed").
			get_tree().create_timer(0.5, false).timeout.connect(trail.queue_free)
			fireballs.remove_at(i)
			_fireball_gone = true
			continue
		trail.position = _to_px(fb["pos"] as Vector2)
		for p: Bomber in players:
			if p.alive and p.vest_t <= 0.0 \
					and p.pos.distance_to(fb["pos"] as Vector2) < 0.5:
				_kill_player(p)
	if _fireball_gone or not fireballs.is_empty():
		# The gone-flag clears the LAST fireball's corona — without it a
		# wall hit left the glow burned in until something else redrew.
		_fireball_gone = false
		_glow_canvas.queue_redraw()


## Arrival-time decision for every enemy type: pick the next cell (sets
## dir and dest). Called when an enemy reaches a cell center or is stuck.
func _enemy_decide(e: Monster, cur: Vector2i) -> void:
	var etype: String = e.type
	if etype == "bomber":
		_brain.decide(e, cur)
	else:
		# Types with an agenda (thief, muncher, woken mimic, stalking
		# serpents) get a greedy step toward their goal; ZERO = wander.
		var forced := _men.steer(e, cur)
		if forced != Vector2i.ZERO:
			e.dir = forced
			e.dest = cur + forced
			return
		var turn_chance := 0.2
		match etype:
			"saw":
				turn_chance = 0.0  # straight until blocked
			"ghost":
				turn_chance = 0.3
			"bees":
				turn_chance = 0.55
		var dir: Vector2i = e.dir
		var options: Array[Vector2i] = []
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q := cur + d
			var ok := _ghost_passable(q) if etype == "ghost" else _enemy_passable(q)
			if ok:
				options.append(d)
		if options.is_empty():
			dir = Vector2i.ZERO
		elif etype == "chomper" and e.chase_t > 0.0:
			# Hunt: close on the nearest living player; avoid flat
			# reversals when any other option exists.
			var prey := _nearest_player_cell(Vector2(cur))
			var best := options[0]
			var best_d := 99999
			for d in options:
				if d == -dir and options.size() > 1:
					continue
				var q2 := cur + d
				var dist := absi(q2.x - prey.x) + absi(q2.y - prey.y)
				if dist < best_d:
					best_d = dist
					best = d
			dir = best
		elif dir == Vector2i.ZERO or not options.has(dir) or rng.randf() < turn_chance:
			dir = options.pick_random()  # patrol: wander, take turns
		e.dir = dir
	# Commit the destination.
	if e.dir != Vector2i.ZERO:
		e.dest = cur + e.dir
	else:
		e.clear_dest()


## Boss sprite: directional bomber-art views (rendering stays in main —
## BomberBrain decides, this scene draws).
func _bomber_enemy_render(e: Monster, dir: Vector2i) -> void:
	var node := e.node as Sprite2D
	var view := "front"
	var flip := false
	if dir.x != 0:
		view = "side"
		flip = dir.x < 0
	elif dir.y < 0:
		view = "back"
	var frame := int((e.anim_t as float) / WALK_FRAME_S) % 2 if dir != Vector2i.ZERO else 0
	node.texture = BomberArt.texture(view, frame, e.col as Color)
	node.flip_h = flip


func _enemy_passable(c: Vector2i) -> bool:
	if arena.solid(c.x, c.y) or _is_burning(c):
		return false
	return not _bomb_cells().has(c)


# ------------------------------------------------------------ life & death --

func _check_kills() -> void:
	for p: Bomber in players:
		if not p.alive:
			continue
		var c := Vector2i(p.pos.round())
		if flames.has(c) and p.vest_t <= 0.0:  # the vest shrugs off fire
			var killer := int((flames[c] as Dictionary).get("owner", -9))
			if killer >= 0 and killer != p.i \
					and not (_teams_on() and players[killer].team == p.team):
				players[killer].stat_kills += 1  # friendly fire isn't a KO
			_kill_player(p)
			continue
		for e: Monster in enemies:
			if e.type == "bomber":
				continue  # bombers kill with bombs, not by touch
			match _men.touch_result(e, p):
				"kill":
					_kill_player(p)
					break
				"freeze":
					# The freezer's whole deal (v6.8): you live, but you
					# stand VERY still for a moment. Brief immunity after.
					p.frozen_t = 1.6
					p.freeze_immune_t = 4.0
					Sfx.play("skull", 0.35)
					_popup("FROZEN!", Color("9adcf8"), _to_px(p.pos))
					break
	# Contagion: a green-skulled player passes the infection by touch
	# (a vest blocks it — it seals the suit). The infectious set is
	# SNAPSHOTTED first so an infection can't chain through several
	# players within one frame, and freshly-cured players get a short
	# immunity window (see _tick_status) against instant re-infection.
	var infectious: Array = []
	for a: Bomber in players:
		if a.alive and a.nasty:
			infectious.append(a)
	for a: Bomber in infectious:
		for b: Bomber in players:
			if b.alive and not b.nasty and b.vest_t <= 0.0 \
					and b.nasty_immune_t <= 0.0 \
					and b.i != a.i \
					and a.pos.distance_to(b.pos) < 0.8:
				_apply_curse(b, a.curse, NASTY_S, true)
	for i in range(enemies.size() - 1, -1, -1):
		var e: Monster = enemies[i]
		# The Menagerie arbitrates: chops, armor, i-frames, splits — a
		# true return means this monster is DONE (kill already credited).
		if _men.flame_check(e):
			_men.free_parts(e)
			var node := e.node as Sprite2D
			var tw := node.create_tween()   # freezes with the world in PAUSE
			tw.tween_property(node, "scale", node.scale * 1.5, 0.2)
			tw.parallel().tween_property(node, "modulate:a", 0.0, 0.2)
			tw.tween_callback(node.queue_free)
			if e.trail != null and is_instance_valid(e.trail):
				e.trail.queue_free()  # world-parented
			enemies.remove_at(i)
			Sfx.play("enemy_die")
			_update_portal_state()  # last monster down → the door opens


var _story_done := false


## Story battle epilogue (v7.1): short banner, then Story carries the
## outcome back to the overworld. No rematch, no ceremonies — the
## world is waiting.
func _story_finish(won: bool) -> void:
	_story_done = true
	state = State.BATTLE_END
	_battle_end_at = _clock
	Music.urgent = false
	_banner.text = "PACK CLEARED!" if won else "DEFEAT..."
	_banner.add_theme_color_override("font_color",
		COL_GOLD if won else Color("c9ccd4"))
	_banner.visible = true
	Sfx.play("win" if won else "die")
	get_tree().create_timer(1.6).timeout.connect(func() -> void:
		Story.finish_battle(won))


## Gamepad rumble (v4.6). Device index == player slot (settings.gd
## registers pad N for player N+1). No-op for bots and empty sockets.
func _rumble(p: Bomber, weak: float, strong: float, dur: float) -> void:
	var dev := Settings.pad_live(p.i)   # the pad driving this seat right now (v12.6)
	if p.bot or not Input.get_connected_joypads().has(dev):
		return
	Input.start_joy_vibration(dev, weak, strong, dur)


func _kill_player(p: Bomber) -> void:
	p.alive = false
	Sfx.play("die")
	_rumble(p, 0.8, 1.0, 0.6)  # the big one — you just died
	var node := p.node as Node2D
	var tw := node.create_tween()   # freezes with the world in PAUSE
	tw.set_parallel(true)
	tw.tween_property(node, "rotation", TAU * 1.5, 0.7)
	tw.tween_property(node, "scale", Vector2.ZERO, 0.7) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(node.queue_free)
	if Settings.revenge_mode and players.size() > 1 \
			and not Story.active and not Settings.try_theme:
		_enter_rim(p)


## Round end. winner_idx: player index, -1 nobody (all dead), -2 timeout.
func _check_round_end() -> void:
	# A chain still rippling may yet catch the "survivor": decide once it
	# is done, so a chain that takes both of you is a DRAW again (v12.2 —
	# with propagation the first victim used to hand the other the round,
	# even standing in the next blast's fire).
	if _chain_live():
		return
	var alive: Array = players.filter(func(p: Bomber) -> bool: return p.alive)
	if players.size() == 1:
		# Solo: dying loses; WINNING takes more than a clear board — the
		# exit portal (under a brick, opens when the monsters are gone)
		# must be found and entered. See _begin_exit.
		if alive.is_empty():
			_finish_round(-1)
		return
	if alive.size() > 1:
		# Teams (v10.2): the round also ends when every survivor shares
		# a team — the TEAM took it.
		if _teams_on():
			var t0: int = (alive[0] as Bomber).team
			for a: Bomber in alive:
				if a.team != t0:
					return
			_finish_round((alive[0] as Bomber).i)
		return
	_finish_round(alive[0].i if alive.size() == 1 else -1)


# ------------------------------------------------------------ exit portal ---

func _reveal_portal() -> void:
	if _portal_spr != null:
		return
	_portal_spr = Sprite2D.new()
	_portal_spr.texture = _tex["portal"]
	_portal_spr.scale = Vector2.ONE * (cell_px / 64.0) * 1.02
	_portal_spr.position = _to_px(Vector2(portal_cell))
	_tiles_root.add_child(_portal_spr)
	_portal_spr.modulate = Color(0.55, 0.55, 0.62)  # asleep until cleared
	var pop := _portal_spr.scale
	_portal_spr.scale = pop * 0.3
	var tw := _portal_spr.create_tween()
	tw.tween_property(_portal_spr, "scale", pop, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play("item")
	_update_portal_state()


## The door wakes up only once every monster is dead — and slams shut
## again if a monster returns (portal punishment). Activation keys off
## "sparkles not yet running", NOT an open-flag edge — the flag can
## flip true before the door is even revealed (zero-enemy rounds).
func _update_portal_state() -> void:
	_portal_open = _is_arcade() and not Story.active and enemies.is_empty()
	if _portal_spr == null:
		return
	if not _portal_open:
		if _portal_fx != null and is_instance_valid(_portal_fx):
			_portal_fx.queue_free()  # sparkles die, door dims back to sleep
			_portal_fx = null
			var dim := _portal_spr.create_tween()
			dim.tween_property(_portal_spr, "modulate",
				Color(0.55, 0.55, 0.62), 0.3)
		return
	if _portal_fx != null:
		return
	Sfx.play("portal_open")
	var tw := _portal_spr.create_tween()
	tw.tween_property(_portal_spr, "modulate", Color(1.25, 1.25, 1.3), 0.4)
	# Teal sparkle column drifting out of the doorway.
	_portal_fx = CPUParticles2D.new()
	_portal_fx.amount = 14
	_portal_fx.lifetime = 0.9
	_portal_fx.local_coords = true   # stays on the door under follow-cam / shake (v12.6)
	_portal_fx.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_portal_fx.emission_sphere_radius = cell_px * 0.2
	_portal_fx.direction = Vector2.UP
	_portal_fx.spread = 26.0
	_portal_fx.gravity = Vector2(0, -cell_px * 0.8)
	_portal_fx.initial_velocity_min = cell_px * 0.15
	_portal_fx.initial_velocity_max = cell_px * 0.5
	_portal_fx.scale_amount_min = cell_px * 0.03
	_portal_fx.scale_amount_max = cell_px * 0.07
	var ramp := Gradient.new()
	ramp.set_color(0, Color("aef2fb"))
	ramp.set_color(1, Color(0.22, 0.82, 0.91, 0.0))
	_portal_fx.color_ramp = ramp
	_portal_fx.position = _portal_spr.position
	_tiles_root.add_child(_portal_fx)


## Portal punishment (v4.0): flame touched the doorway — after the
## blast clears, a bomber mini-boss in a random colour storms out of
## it (matching spawn burst), and the door slams shut until it's dead.
var _portal_punish_t := -10.0

func _boss_count() -> int:
	var n := 0
	for e: Monster in enemies:
		if e.type == "bomber":
			n += 1
	return n


func _portal_punish() -> void:
	if _boss_count() >= Settings.max_bosses:
		return  # the cap holds — the door absorbs the insult
	var now := _clock
	if now - _portal_punish_t < 1.0:
		return  # one boss per offense, not per overlapping flame
	_portal_punish_t = now
	Sfx.play("skull")
	var col := _random_boss_color()
	BomberArt.prewarm(col)   # ~0.8 s before it steps out (v12.6)
	_portal_emerge_retry(col, _round_serial)


## Emergence waits for a SAFE doorway: not just the offending blast —
## follow-up bombs (chained offenses, a summoning boss re-bombing) can
## cover the portal when the timer fires, and a boss stepping out into
## fire or onto a ticking bomb died instantly. Retry until clear.
func _portal_emerge_retry(col: Color, round_at: int) -> void:
	get_tree().create_timer(FLAME_S + 0.35).timeout.connect(func() -> void:
		# Cancel only when the offense is truly moot (new round, escape
		# in progress, round over, cap reached). A PAUSE must RE-ARM —
		# SceneTreeTimers keep ticking through our state-machine pause,
		# and returning here used to swallow the punishment silently.
		if _round_serial != round_at or _exiting \
				or state == State.ROUND_END or state == State.BATTLE_END \
				or _boss_count() >= Settings.max_bosses:
			return
		if state != State.PLAY \
				or _danger_cells().has(portal_cell) \
				or _bomb_cells().has(portal_cell):
			_portal_emerge_retry(col, round_at)
			return
		_spawn_portal_boss(col))


func _spawn_portal_boss(col: Color) -> void:
	var c := portal_cell
	var spr := Sprite2D.new()
	spr.texture = BomberArt.texture("front", 0, col)
	var target_s := Vector2.ONE * (cell_px * BOMBER_H_CELLS / (76.0 * BomberArt.RASTER_SCALE))
	spr.scale = target_s * 0.1
	spr.position = _to_px(Vector2(c))
	_entities_root.add_child(spr)
	var tw := spr.create_tween()
	tw.tween_property(spr, "scale", target_s, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	enemies.append(_new_monster("bomber", c, col, spr))
	# Spawn burst in the boss's colour — the door spits sparks with it.
	var burst := _fx.make_burst(26, 0.6, cell_px * 0.5, cell_px * 2.2,
		cell_px * 0.06, cell_px * 0.14, Vector2.ZERO,
		[Color.WHITE, col.lerp(Color.WHITE, 0.3), col,
			Color(col.r, col.g, col.b, 0.0)])
	burst.position = _to_px(Vector2(c))
	_flame_canvas.add_child(burst)
	Sfx.play("spit")
	_update_portal_state()  # a monster lives — the door shuts


## The escape: suck the bomber into the doorway, flash, then the win.
func _begin_exit(p: Bomber) -> void:
	_exiting = true
	state = State.EXIT
	Sfx.play("portal")
	var node := p.node as Node2D
	var target := _to_px(Vector2(portal_cell))
	var tw := create_tween()
	tw.tween_property(node, "position", target, 0.22) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(node, "rotation", TAU * 2.2, 1.0) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(node, "scale", Vector2.ZERO, 1.0) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		_rings.append({"px": target, "born": _clock,
			"col": Color("39d0e8")})
		_glow_canvas.queue_redraw()
		if _portal_spr != null and is_instance_valid(_portal_spr):
			var pw := _portal_spr.create_tween()
			pw.tween_property(_portal_spr, "scale", _portal_spr.scale * 1.25, 0.15)
			pw.tween_property(_portal_spr, "scale", _portal_spr.scale, 0.2))
	tw.tween_interval(0.55)
	tw.tween_callback(func() -> void: _finish_round(0))


## A round (one arena) ended. The BATTLE is over when someone reaches
## Settings.wins_target round wins AND leads the runner-up by at least
## Settings.win_margin — margin 2 keeps a tied rivalry going (deuce rule).
func _finish_round(winner_idx: int) -> void:
	if Story.active:
		_story_finish(false)  # solo end that wasn't a cleared pack = down
		return
	state = State.ROUND_END
	# A death ends the round, but the CARD waits CER_DELAY so the blast
	# and the spin play out; the portal escape already had its lead-in.
	var delay := 0.0 if _exiting else CER_DELAY
	_end_t = 3.4 + delay
	Music.urgent = false  # hurry-up pressure ends with the round
	if winner_idx >= 0:
		var p: Bomber = players[winner_idx]
		# Teams (v10.2): a team round win credits BOTH members, so the
		# series bookkeeping (target, margin, battle point) is unchanged.
		var winners: Array = [p]
		if _teams_on():
			winners = players.filter(func(q: Bomber) -> bool:
				return q.team == p.team)
		for w: Bomber in winners:
			w.wins += 1
		var best_other := 0
		for q: Bomber in players:
			if not winners.has(q):
				best_other = maxi(best_other, q.wins)
		var battle_over: bool = players.size() == 1 \
			or (p.wins >= Settings.wins_target
				and p.wins - best_other >= Settings.win_margin)
		if battle_over:
			state = State.BATTLE_END
			_battle_end_at = _clock
		_cer_pending = _cer.show_victory.bind(winner_idx, battle_over)
	else:
		if players.size() == 1:
			# Solo defeat gets a full ceremony too — the sad kind (v4.4).
			state = State.BATTLE_END
			_battle_end_at = _clock
			_cer_pending = _cer.show_defeat.bind(winner_idx == -2)
		else:
			# v6.3: draws get a small ceremony instead of a bare banner.
			_cer_pending = _cer.show_draw.bind(winner_idx == -2)
	_cer_at = _clock + delay
	_battle_end_at += delay   # the pad's START grace counts from the CARD
	_refresh_hud()


# ------------------------------------------------------------------ input ---

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	# The attract loop is furniture (v10.1): ANY key or pad button
	# hands the room back to whoever walked past.
	if Settings.attract_demo and event.is_pressed() \
			and (event is InputEventKey or event is InputEventJoypadButton):
		_to_menu()
		return
	# The configured zero-human DEMO promises "Q for menu" on its
	# countdown card, and the maker's TRY IT says "Q returns here" —
	# honour both in every state, not just paused.
	if (_is_demo() or Settings.try_theme) \
			and event.is_action_pressed("quit_to_menu") and state != State.EXIT:
		_to_menu()
		return
	# R (rematch) only where the README promises it: paused or after a
	# round/battle ended. It used to fire in EVERY state — one stray
	# press mid-battle wiped everyone's wins with no confirmation (and
	# restarting mid-exit-animation aborted tweens on freed nodes).
	if event.is_action_pressed("restart"):
		if Story.active:
			return  # story battles have no rematch — the world decides
		if state == State.ROUND_END:
			# Impatience is not a series reset (v11.5): R during the
			# round ceremony skips ahead to the NEXT round, tally
			# intact. It used to full-rematch here, so skipping the
			# 3.4 s ceremony silently wiped everyone's wins — "rounds
			# to win is not respected". Full rematch lives in PAUSE
			# and BATTLE_END, where resetting is what R means.
			Sfx.play("ui")
			_start_round()
			return
		if state == State.PAUSE or state == State.BATTLE_END:
			_rematch()
		return
	match state:
		State.PLAY, State.COUNTDOWN:
			if event.is_action_pressed("pause"):
				_paused_from = state  # resume must return HERE, not to PLAY
				state = State.PAUSE
				_pause_sync.call()
				_pause_panel.visible = true
				Sfx.play("pause")
		State.PAUSE:
			if event.is_action_pressed("pause"):
				# Resuming into PLAY from a countdown pause used to skip
				# the rest of the 3-2-1 and leave the banner stuck.
				state = _paused_from
				_pause_panel.visible = false
				Sfx.play("pause")
			elif event.is_action_pressed("quit_to_menu") \
					or event.is_action_pressed("menu_confirm"):
				if Story.active:
					# Fleeing counts as losing (the pack keeps your gold).
					_pause_panel.visible = false
					_story_finish(false)
				else:
					_to_menu()
		State.BATTLE_END:
			# A PAD's START too — how a pad-only couch moves on — but not
			# keyboard ESC, and not in the first moment: a reflex press as
			# the last rival fell skipped the trophy card (v12.2).
			var pad_start := event is InputEventJoypadButton \
				and event.is_action_pressed("pause") \
				and _clock - _battle_end_at > 0.8
			if event.is_action_pressed("quit_to_menu") \
					or event.is_action_pressed("menu_confirm") or pad_start:
				# A story epilogue owns its own exit: Story.finish_battle
				# is already on a timer, and _to_menu here would race it —
				# the player "reaches the menu", then the timer yanks them
				# into the overworld and (on a loss) eats a life (v8.8).
				if not Story.active:
					_to_menu()
		_:
			pass


func _rematch() -> void:
	for p: Bomber in players:
		p.wins = 0
		p.stat_bombs = 0
		p.stat_bricks = 0
		p.stat_kills = 0
		p.stat_items = 0
	round_num = 0
	_pause_panel.visible = false
	Sfx.play("ui")
	_start_round()


func _to_menu() -> void:
	Music.set_mood("classic")
	Music.urgent = false  # the autoload outlives this scene
	Settings.skip_splash_once = true
	get_tree().change_scene_to_file(Settings.menu_scene())


func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE:
		get_tree().paused = false   # never hand a paused tree to the menu
		_end_chains()   # quitting mid-chain still lands its BOOM
		if _sedated:  # the SEDATIVE must not follow us out
			Engine.time_scale *= 2.0
			_sedated = false
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_win_focused = true
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_win_focused = false
		# Alt-tab must not kill a run (v10.0): auto-pause live rounds.
		# The demo keeps rolling — attract mode is furniture.
		_auto_pause()


## Pause a live round on the player's behalf (alt-tab, a pad dropping
## out). The demo keeps rolling — attract mode is furniture.
func _auto_pause() -> void:
	if (state == State.PLAY or state == State.COUNTDOWN) and not _is_demo():
		_paused_from = state
		state = State.PAUSE
		_pause_sync.call()
		_pause_panel.visible = true
		Sfx.play("pause")


## A pad dropping out mid-round (flat battery, a cable) pauses the round
## instead of leaving its bomber to stand and die (v12.6). Settings has
## already re-resolved which pad drives which seat by now.
func _on_joy_connection_changed(_device: int, connected: bool) -> void:
	if not connected and _humans > 0:
		_auto_pause()


# ----------------------------------------------------------------- layout ---

func _layout_metrics() -> void:
	var view := get_viewport().get_visible_rect().size
	var fit := floorf(minf((view.x - 24.0) / arena.w,
		(view.y - HUD_H - 36.0) / arena.h))
	# Big solo arenas would shrink cells into illegibility — switch to a
	# fixed comfortable cell and scroll the camera with the human instead.
	_scroll_mode = _is_arcade() and fit < 44.0
	if _scroll_mode:
		cell_px = 48.0
		origin = Vector2(12.0, HUD_H + 10.0)
	else:
		cell_px = fit
		origin = Vector2((view.x - cell_px * arena.w) * 0.5,
			HUD_H + (view.y - HUD_H - cell_px * arena.h) * 0.5)
	_cam = Vector2.ZERO
	if _field != null:
		_field.position = Vector2.ZERO  # stale pan would offset the checker
	# A fresh layout: drop any mid-round resize fit (_on_viewport_resized).
	scale = Vector2.ONE
	position = Vector2.ZERO
	if _field_layer != null:
		_field_layer.transform = Transform2D.IDENTITY


## The window changed mid-round (F11, Alt+Enter, the pause card's
## Fullscreen box, a drag): the board was laid out for the OLD size and
## got cut off or sat off-centre until the next round (v12.6). Every
## world position derives from `origin` + `cell_px`, so one uniform
## scale-and-offset on the battle scene (and the floor's layer) re-fits
## it exactly; the next _start_round lays out natively again. Scrolling
## solo arenas follow the camera anyway.
func _on_viewport_resized() -> void:
	if arena == null or _scroll_mode or cell_px <= 0.0:
		return
	var view := get_viewport().get_visible_rect().size
	var fit := floorf(minf((view.x - 24.0) / arena.w,
		(view.y - HUD_H - 36.0) / arena.h))
	if fit <= 0.0:
		return
	var new_origin := Vector2((view.x - fit * arena.w) * 0.5,
		HUD_H + (view.y - HUD_H - fit * arena.h) * 0.5)
	var k := fit / cell_px
	scale = Vector2(k, k)
	position = new_origin - origin * k
	if _field_layer != null:
		_field_layer.transform = Transform2D(0.0, scale, 0.0, position)


## The potion's party trick (v6.0): swap to the uncorked bottle and
## launch the cork skyward with a spin. Purely visual — the fuse
## keeps its own schedule.
func _uncork_potion(b: Dictionary) -> void:
	var spr := b["node"] as Sprite2D
	spr.texture = BomberArt.texture("bomb_potion_open", -1, b["col"])
	var cork := Sprite2D.new()
	cork.texture = BomberArt.texture("bomb_potion_cork", -1, b["col"])
	cork.scale = spr.scale
	cork.position = spr.position + Vector2(0, -30) * (b["base"] as float) \
		* BomberArt.RASTER_SCALE
	_entities_root.add_child(cork)
	var tw := cork.create_tween()
	tw.set_parallel(true)
	tw.tween_property(cork, "position:y", cork.position.y - cell_px * 1.3, 0.45) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(cork, "position:x", cork.position.x + cell_px * 0.35, 0.45)
	tw.tween_property(cork, "rotation", 3.5, 0.45)
	tw.tween_property(cork, "modulate:a", 0.0, 0.45) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(cork.queue_free)
	Sfx.play("spit", 0.15)


## Where each bomb style's fuse tip sits in TEXTURE space — the spark
## emitter parks there (offsets in unscaled 64-canvas pixels).
func _bomb_spark_off(style: String) -> Vector2:
	match style:
		"dynamite":
			return Vector2(9, -30)
		"naval":
			return Vector2(12, -26)
		"aviatic":
			return Vector2(23, -26)
		"acme":
			return Vector2(8, -32)
		"potion":
			return Vector2(0, 8)  # bubbles rise from inside the bulb
		_:
			return Vector2(12, -30)


## Bomb sprite anchor: shifted up so the sphere (whose center sits below
## the texture middle) is centered on the cell — base on the cell floor,
## top free to overlap the row above.
func _bomb_px(cell_pos: Vector2) -> Vector2:
	return _to_px(cell_pos) + Vector2(0, -cell_px * 0.12)


func _to_px(cell_pos: Vector2) -> Vector2:
	return origin + (cell_pos + Vector2(0.5, 0.5)) * cell_px


func _from_px(px: Vector2) -> Vector2:
	return (px - origin) / cell_px - Vector2(0.5, 0.5)


func _build_layout() -> void:
	var bg := ColorRect.new()
	bg.color = COL_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -10
	bg_layer.add_child(bg)
	add_child(bg_layer)

	_field = Control.new()
	_field.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_field.draw.connect(_draw_field)
	_field_layer = CanvasLayer.new()
	_field_layer.layer = -5
	_field_layer.add_child(_field)
	add_child(_field_layer)

	_tiles_root = Node2D.new()
	add_child(_tiles_root)
	# Snail goo lies ON the floor, under everyone (v12.6: it was painted
	# on the flame layer, over the bombers' bodies).
	_goo_canvas = Node2D.new()
	_goo_canvas.draw.connect(_draw_goo)
	add_child(_goo_canvas)
	_entities_root = Node2D.new()
	# Depth by feet (v12.6): draw order was creation order, so every bomb
	# hid the helmet of a bomber standing in the row below it.
	_entities_root.y_sort_enabled = true
	add_child(_entities_root)
	_flame_canvas = Node2D.new()
	_flame_canvas.draw.connect(_draw_flames)
	add_child(_flame_canvas)
	# Additive layer on top: white-hot cores and shockwave rings BLOOM
	# over the field instead of just painting on it.
	_glow_canvas = Node2D.new()
	var glow_mat := CanvasItemMaterial.new()
	glow_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow_canvas.material = glow_mat
	_glow_canvas.draw.connect(_draw_glow)
	add_child(_glow_canvas)
	for world: Node in [_tiles_root, _goo_canvas, _entities_root, _flame_canvas, _glow_canvas]:
		world.process_mode = Node.PROCESS_MODE_PAUSABLE   # frozen by PAUSE


## Two-tone checker under the whole arena, colours from the skin
## (classic: the original greens).
func _draw_field() -> void:
	var fc: Array = TileArt.floors(_skin)
	for y in arena.h:
		for x in arena.w:
			var col: Color = fc[0] if (x + y) % 2 == 0 else fc[1]
			_field.draw_rect(Rect2(origin + Vector2(x, y) * cell_px,
				Vector2(cell_px + 1, cell_px + 1)), col)
	# Blast-range hint (v6.3, OPTIONS toggle): every cell a ticking bomb
	# will reach pulses faintly red — the beginner's "not here" map.
	# Drawn on the FIELD layer, so walls and bricks still cover their
	# cells: only the walkable danger glows.
	if Settings.blast_hint and state == State.PLAY:
		var pulse := 0.20 + 0.08 * sin(Time.get_ticks_msec() / 1000.0 * TAU * 1.6)
		for c: Vector2i in _danger_cells():
			_field.draw_rect(Rect2(origin + Vector2(c) * cell_px,
				Vector2(cell_px + 1, cell_px + 1)),
				Color(1.0, 0.25, 0.15, pulse))


func _rebuild_board() -> void:
	for spr: Sprite2D in brick_sprites.values():
		spr.queue_free()
	brick_sprites.clear()
	for spr: Sprite2D in item_sprites.values():
		spr.queue_free()
	item_sprites.clear()
	for child in _tiles_root.get_children():
		child.queue_free()
	for child in _entities_root.get_children():
		child.queue_free()
	# Tiles come from the selected skin (v4.8) — scale by TEXTURE width,
	# not a fixed 64: classic imports at 64 px, TileArt skins raster at 128.
	var wall_tex := TileArt.wall(_skin)
	var brick_tex := TileArt.brick(_skin)
	# All walls first, then all bricks (v12.6): row-by-row interleaving
	# alternated textures every few sprites and broke the draw batching
	# (hundreds of draw calls on big boards — felt on a Pi). Tiles never
	# overlap, so the picture is identical.
	for want: int in [Arena.WALL, Arena.BRICK]:
		var tex := wall_tex if want == Arena.WALL else brick_tex
		for y in arena.h:
			for x in arena.w:
				if arena.cell(x, y) != want:
					continue
				var spr := Sprite2D.new()
				spr.texture = tex
				spr.scale = Vector2.ONE * (cell_px / tex.get_width())
				spr.position = _to_px(Vector2(x, y))
				_tiles_root.add_child(spr)
				if want == Arena.BRICK:
					brick_sprites[Vector2i(x, y)] = spr
	_field.queue_redraw()


## Flames, base layer: blobby circles that WHOOMP open, merge with their
## neighbors, and COOL — born as near-white flash, grading into the
## owner's tint as they age, collapsing dark at death. The white cores
## and shockwaves live on the additive glow layer above.
## Snail goo: puddles on the floor, under every entity.
func _draw_goo() -> void:
	for c: Vector2i in goo:
		var center := _to_px(Vector2(c))
		_goo_canvas.draw_circle(center, cell_px * 0.34,
			Color(0.62, 0.75, 0.35, 0.4))
		_goo_canvas.draw_circle(center + Vector2(cell_px * 0.18, cell_px * 0.1),
			cell_px * 0.14, Color(0.7, 0.82, 0.42, 0.35))


func _draw_flames() -> void:
	var now := _clock
	for c: Vector2i in flames:
		var f: Dictionary = flames[c]
		var life: float = clampf((f["t"] - now) / FLAME_S, 0.0, 1.0)
		var age: float = now - f["born"]
		var col: Color = f["col"]
		var center := _to_px(Vector2(c))
		# Irregular under-glow: per-cell random size/offset/phase (rolled
		# at ignition) so the footprint never reads as tiled circles —
		# the fire itself is particles now, this just marks lethal ground.
		var grow := 1.0 - pow(1.0 - minf(age / 0.12, 1.0), 3.0)
		var rs: float = f["rs"]
		var ph: float = f["ph"]
		var boil := 1.0 + 0.1 * sin(now * 34.0 + ph)
		var r := cell_px * 0.52 * grow * (0.7 + 0.3 * life) * rs * boil
		var jit: Vector2 = (f["rj"] as Vector2) * cell_px * 0.12
		# Fast cool-down: white-hot for a blink, then the owner's color
		# owns the ground (v3.8 — the tint used to drown in white).
		var whiteness := clampf(1.0 - age * 7.5, 0.0, 1.0)
		var vivid := _vivid(col)
		var body := vivid.lerp(Color(1.0, 0.98, 0.94), 0.06 + 0.74 * whiteness)
		body.a = 0.72 * life + 0.08
		var edge := vivid.darkened(0.3)
		edge.a = 0.55 * life + 0.12
		_flame_canvas.draw_circle(center + jit, r * 1.12, edge)
		_flame_canvas.draw_circle(center + jit * 0.4, r * 0.85, body)
		_flame_canvas.draw_circle(center - jit * 0.8,
			r * (0.4 + 0.12 * sin(now * 46.0 + ph * 2.0)), body.lightened(0.15))


## Additive glow layer: wandering white-hot cores in every flame cell and
## an expanding tinted shockwave ring per detonation — the bloom that
## makes the blast feel like light, not paint.
func _draw_glow() -> void:
	var now := _clock
	for c: Vector2i in flames:
		var f: Dictionary = flames[c]
		var life: float = clampf((f["t"] - now) / FLAME_S, 0.0, 1.0)
		var age: float = now - f["born"]
		var col: Color = f["col"]
		var center := _to_px(Vector2(c))
		var grow := 1.0 - pow(1.0 - minf(age / 0.12, 1.0), 3.0)
		var rs2: float = f["rs"]
		var ph2: float = f["ph"]
		var r := cell_px * 0.52 * grow * (0.7 + 0.3 * life) * rs2
		var wobble := Vector2(sin(now * 33.0 + ph2), cos(now * 27.0 + ph2 * 1.7)) \
			* r * 0.2
		# Additive bloom, owner-colored (v3.8): a big saturated halo, a
		# solid vivid heart, and a small white core that dies fast — the
		# light itself carries the player's color now.
		var vivid := _vivid(col)
		var halo := vivid.lerp(Color.WHITE, 0.10)
		halo.a = 0.42 * life
		_glow_canvas.draw_circle(center + (f["rj"] as Vector2) * cell_px * 0.08,
			r * 1.15, halo)
		var heart := vivid.lerp(Color.WHITE, 0.30)
		heart.a = 0.38 * life
		_glow_canvas.draw_circle(center + wobble * 0.5, r * 0.72, heart)
		var core := Color(1.0, 0.98, 0.88,
			(0.55 + 0.35 * life) * life * clampf(1.0 - age * 3.2, 0.0, 1.0))
		_glow_canvas.draw_circle(center + wobble,
			r * (0.30 + 0.08 * sin(now * 52.0 + ph2)), core)
	# Elemental fireballs: white-hot core with an orange corona.
	for fb: Dictionary in fireballs:
		var px := _to_px(fb["pos"] as Vector2)
		var wob := 1.0 + 0.15 * sin(now * 40.0 + px.x)
		_glow_canvas.draw_circle(px, cell_px * 0.3 * wob, Color(0.94, 0.41, 0.09, 0.5))
		_glow_canvas.draw_circle(px, cell_px * 0.18 * wob, Color(1.0, 0.85, 0.4, 0.9))
		_glow_canvas.draw_circle(px, cell_px * 0.09, Color(1.0, 0.98, 0.85))
	# Shockwave rings.
	for i in range(_rings.size() - 1, -1, -1):
		var ring: Dictionary = _rings[i]
		var age: float = now - ring["born"]
		if age > 0.32:
			_rings.remove_at(i)
			continue
		var k := age / 0.32
		var radius := cell_px * (0.4 + 2.6 * (1.0 - pow(1.0 - k, 2.5)))
		# The blast signature: a fat ring in the OWNER'S color chased by
		# a thin white leading edge (was 70% white — anonymous).
		var rcol := _vivid(ring["col"] as Color).lerp(Color.WHITE, 0.12)
		rcol.a = (1.0 - k) * 0.9
		_glow_canvas.draw_arc(ring["px"], radius, 0, TAU, 48, rcol,
			maxf(cell_px * 0.16 * (1.0 - k), 1.5), true)
		var lead := Color(1, 1, 1, (1.0 - k) * 0.5)
		_glow_canvas.draw_arc(ring["px"], radius + cell_px * 0.09 * (1.0 - k),
			0, TAU, 48, lead, maxf(cell_px * 0.04 * (1.0 - k), 1.0), true)


# -------------------------------------------------------------------- HUD ---

func _build_hud() -> void:
	_hud = CanvasLayer.new()
	add_child(_hud)
	var bar := ColorRect.new()
	bar.color = COL_HUD
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = HUD_H
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(bar)

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	row.offset_left = 20.0
	row.offset_right = -20.0
	row.offset_top = 10.0
	row.offset_bottom = HUD_H - 10.0
	row.add_theme_constant_override("separation", 26)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(row)

	for p: Bomber in players:
		var chip := HBoxContainer.new()
		chip.add_theme_constant_override("separation", 8)
		var swatch := ColorRect.new()
		swatch.color = _player_col(p.i)
		swatch.custom_minimum_size = Vector2(22, 22)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		chip.add_child(swatch)
		var lbl := _make_label(("B%d" % (p.i + 1 - _humans) if p.bot
			else "P%d" % (p.i + 1))
			+ ("·A" if p.team == 0 else ("·B" if p.team == 1 else "")),
			20, COL_TEXT, true, 1)
		chip.add_child(lbl)
		var wins := _make_label("", 20, COL_GOLD, true, 2)
		chip.add_child(wins)
		row.add_child(chip)
		_chips.append(wins)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	# The help hint sits far right, beside the round counter (v6.3.1) —
	# dead center read as a title, not a hint.
	var hhint := _make_label("H · help    ", 13,
		Color(COL_DIM.r, COL_DIM.g, COL_DIM.b, 0.8), false, 1)
	hhint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(hhint)
	_round_label = _make_label("ROUND 1", 16, COL_DIM, true, 2)
	row.add_child(_round_label)
	_timer_label = _make_label("2:30", 30, COL_TEXT, true, 2)
	row.add_child(_timer_label)

	# BATTLE POINT strip just under the HUD bar (v4.5) — filled in by
	# _refresh_battle_point at each round start.
	_battlepoint_label = _make_label("", 15, COL_GOLD, true, 3)
	_battlepoint_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_battlepoint_label.offset_top = HUD_H + 4.0
	_battlepoint_label.offset_bottom = HUD_H + 26.0
	_battlepoint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_battlepoint_label.visible = false
	_hud.add_child(_battlepoint_label)

	# Rx badge (v11.0): while any MEDICINE CABINET bottle is open the
	# round is openly MEDICATED — honesty is the price of the candy.
	_rx_label = _make_label("Rx MEDICATED", 13, Color(0.62, 0.95, 0.78), true, 2)
	_rx_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_rx_label.offset_left = -200.0
	_rx_label.offset_right = -12.0
	_rx_label.offset_top = HUD_H + 4.0
	_rx_label.offset_bottom = HUD_H + 24.0
	_rx_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_rx_label.visible = false
	_hud.add_child(_rx_label)

	_banner = _make_label("3", 64, COL_GOLD, true, 6)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.grow_vertical = Control.GROW_DIRECTION_BOTH
	_hud.add_child(_banner)
	_sub_banner = _make_label("", 18, COL_TEXT, false, 2)
	_sub_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_sub_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_sub_banner.grow_vertical = Control.GROW_DIRECTION_BOTH
	_sub_banner.offset_top = 60.0
	_sub_banner.offset_bottom = 100.0
	_sub_banner.visible = false
	_hud.add_child(_sub_banner)

	_pause_panel = PanelContainer.new()
	_pause_panel.visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.08, 0.19, 0.94)
	sb.border_color = Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.35)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 40.0
	sb.content_margin_right = 40.0
	sb.content_margin_top = 24.0
	sb.content_margin_bottom = 24.0
	_pause_panel.add_theme_stylebox_override("panel", sb)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(center)
	center.add_child(_pause_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	_pause_panel.add_child(vb)
	vb.add_child(_make_label("PAUSED", 30, COL_GOLD, true, 6))
	# Story fights have no rematch, and leaving one is a flight (a lost
	# life) — say so; ENTER quits too, so it's on the card (v11.7).
	# The pad names follow OPTIONS → CONTROLS remaps (v12.6).
	var p_res := Settings.pad_system_name("pause")
	var p_rem := Settings.pad_system_name("restart")
	var p_quit := Settings.pad_system_name("quit_to_menu")
	vb.add_child(_make_label(("ESC / %s resume  ·  Q / ENTER / %s flee (counts as a loss)"
		% [p_res, p_quit]) if Story.active else
		("ESC / %s resume  ·  R / %s rematch  ·  Q / ENTER / %s quit to menu"
		% [p_res, p_rem, p_quit]), 15, COL_TEXT, false, 1))
	# Quick options (v10.0): the fixes people need MID-battle — ringing
	# ears, a shaking screen, the window mode — without quitting to the
	# menu. Values re-sync every time the panel shows (F11 exists now).
	vb.add_child(HSeparator.new())
	var sync_calls: Array = []
	for a: Array in [["Music", "music_on", "music_volume"],
			["Sound FX", "sfx_on", "sfx_volume"]]:
		var qrow := HBoxContainer.new()
		qrow.add_theme_constant_override("separation", 10)
		vb.add_child(qrow)
		var cb := CheckBox.new()
		# Mouse-only quick options (v11.8): once clicked, a focusable
		# control swallowed ENTER (quit) and SPACE as ui_accept.
		cb.focus_mode = Control.FOCUS_NONE
		cb.text = a[0]
		cb.add_theme_font_size_override("font_size", 14)
		cb.custom_minimum_size = Vector2(120, 0)
		var prop: String = a[1]
		cb.toggled.connect(func(on: bool) -> void: Settings.set(prop, on))
		qrow.add_child(cb)
		var sl := HSlider.new()
		sl.focus_mode = Control.FOCUS_NONE
		sl.min_value = 0.0
		sl.max_value = 1.0
		sl.step = 0.05
		sl.custom_minimum_size = Vector2(150, 24)
		sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var vprop: String = a[2]
		sl.value_changed.connect(func(v: float) -> void: Settings.set(vprop, v))
		qrow.add_child(sl)
		sync_calls.append(func() -> void:
			cb.set_pressed_no_signal(Settings.get(prop))
			sl.set_value_no_signal(Settings.get(vprop)))
	var trow := HBoxContainer.new()
	trow.add_theme_constant_override("separation", 16)
	vb.add_child(trow)
	for t: Array in [["Camera shake", "screen_shake"],
			["Fullscreen", "fullscreen"]]:
		var tcb := CheckBox.new()
		tcb.focus_mode = Control.FOCUS_NONE
		tcb.text = t[0]
		tcb.add_theme_font_size_override("font_size", 14)
		var tprop: String = t[1]
		tcb.toggled.connect(func(on: bool) -> void: Settings.set(tprop, on))
		trow.add_child(tcb)
		sync_calls.append(func() -> void:
			tcb.set_pressed_no_signal(Settings.get(tprop)))
	_pause_sync = func() -> void:
		for c: Callable in sync_calls:
			c.call()
	_pause_sync.call()
	# F11 mid-pause must not leave a stale checkbox on screen (v10.3).
	Settings.changed.connect(func() -> void:
		if _pause_panel != null and _pause_panel.visible:
			_pause_sync.call())

	_build_help_overlay()


## Hold-H quick help (v6.1): a HIGH-CONTRAST card — active players'
## controls, the system keys, the full power-up legend with real
## icons, and the round's goal. Visible only while H is held, so it
## can afford to be big; the game keeps running underneath (peeking
## mid-battle is a legitimate tactical risk).
func _build_help_overlay() -> void:
	_help_overlay = Control.new()
	_help_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_help_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_help_overlay.visible = false
	_hud.add_child(_help_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.06, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_help_overlay.add_child(dim)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.11, 0.96)
	style.set_corner_radius_all(12)
	style.set_border_width_all(2)
	style.border_color = COL_GOLD
	style.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_help_overlay.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)
	vb.add_child(_make_label("QUICK HELP", 24, COL_GOLD, true, 4))
	# All FOUR control schemes (v6.2, player request): the slots in
	# this battle shine, the rest stay listed but dimmed — so you know
	# the keys before handing a friend the corner of the keyboard.
	for i in 4:
		var active: bool = i < _humans
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		vb.add_child(row)
		var chip := ColorRect.new()
		chip.color = _player_col(i) if active \
			else Color(_player_col(i), 0.35)
		chip.custom_minimum_size = Vector2(18, 18)
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(chip)
		# The seat's bomb, in its costume and tint (v9.0) — mid-melee you
		# can see at a glance who throws what. Styles are menu-set, so
		# the build-time texture stays true all battle.
		var bomb_ic := TextureRect.new()
		bomb_ic.texture = BomberArt.bomb_texture(_player_col(i),
			Settings.bomb_style_for(i))
		bomb_ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bomb_ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		bomb_ic.custom_minimum_size = Vector2(24, 24)
		bomb_ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bomb_ic.modulate = Color.WHITE if active else Color(1, 1, 1, 0.35)
		row.add_child(bomb_ic)
		var suffix := ""
		if not active:
			suffix = "   — bot" if i < players.size() else "   — open seat"
		row.add_child(_make_label("P%d   %s   (or %s)%s"
			% [i + 1, Settings.player_key_text(i), Settings.pad_text(i), suffix],
			17, Color.WHITE if active else COL_DIM, false, 1))
	if _is_demo():
		vb.add_child(_make_label("all bots — sit back and enjoy the show",
			17, Color.WHITE, false, 1))
	vb.add_child(_make_label(
		"ESC/%s pause  ·  R/%s rematch (paused / battle over) · next round (round over)  ·  Q/%s quit (paused / battle over)"
			% [Settings.pad_system_name("pause"), Settings.pad_system_name("restart"),
				Settings.pad_system_name("quit_to_menu")],
		15, COL_TEXT, false, 1))
	vb.add_child(_spacer_ctl(6))
	# Power-up legend, real icons.
	var legend: Array = [
		["item_bomb", "+1 bomb out at once"], ["item_fire", "longer blast"],
		["item_speed", "run faster"], ["item_kick", "kick bombs"],
		["item_vest", "flame-proof vest (fire only!)"],
		["item_wallpass", "walk through bricks"],
		["item_skull", "SKULL: random curse"],
		["item_nasty", "NASTY SKULL: contagious — tag someone!"],
	]
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 26)
	grid.add_theme_constant_override("v_separation", 4)
	var center_wrap := HBoxContainer.new()
	center_wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	center_wrap.add_child(grid)
	vb.add_child(center_wrap)
	for entry: Array in legend:
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 8)
		var icon := TextureRect.new()
		icon.texture = _tex[entry[0]]
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(24, 24)
		cell.add_child(icon)
		cell.add_child(_make_label(entry[1], 15, Color.WHITE, false, 1))
		grid.add_child(cell)
	vb.add_child(_spacer_ctl(6))
	_help_mode = _make_label("", 16, COL_GOLD, false, 2)
	_help_mode.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_help_mode.custom_minimum_size = Vector2(560, 0)
	_help_mode.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_help_mode)


func _spacer_ctl(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _refresh_hud() -> void:
	for i in _chips.size():
		var wins: int = players[i].wins
		(_chips[i] as Label).text = "●".repeat(wins) + "○".repeat(
			maxi(Settings.wins_target - wins, 0)) if players.size() > 1 else ""
	_round_label.text = "ROUND %d" % round_num


## Floating text at a board position (curses, etc.).
func _popup(text: String, color: Color, at_px: Vector2) -> void:
	var lbl := _make_label(text, 22, color, true, 2)
	# at_px is WORLD space; the HUD isn't — subtract the follow-cam
	# (big solo arenas showed "KICK!" a screen away from you, v11.8).
	lbl.position = transform * (at_px - _cam) + Vector2(-60, -50)
	lbl.size = Vector2(120, 30)
	_hud.add_child(lbl)
	var tw := create_tween()
	tw.tween_property(lbl, "position:y", lbl.position.y - 30.0, 0.9)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.9) \
		.set_ease(Tween.EASE_IN)
	tw.tween_callback(lbl.queue_free)


func _make_label(text: String, size_px: int, color: Color, bold: bool,
		letter_spacing: int) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", size_px)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
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
