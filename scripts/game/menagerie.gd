class_name Menagerie
extends RefCounted
## The extended monster roster (v6.8): thirteen newcomers on top of the
## classic seven, with per-type abilities and three MULTI-TILE serpents
## that drag their bodies snake-game style. main.gd's destination
## walker still moves every head; this module owns everything that
## makes each type special — states, timers, steering goals, touch and
## flame rules, and the serpent body-follow.
##
## STORY-MODE READY: TIER ranks every type 1 (fodder) to 5 (boss). A
## future story mode can build waves straight from `by_tier()` — the
## spawn logic, art and behaviours all key off the type string alone.
##
## THE ROSTER (tier · ability):
##   balloon   1  drifts (classic)
##   slime     1  splits into two quick minis when burned
##   snail     1  slow, paints goo that slows players
##   chomper   2  smells players, hunts in bursts (classic)
##   bees      2  jittery (classic)
##   frog      2  hops OVER walls every few seconds
##   mole      2  burrows, pops up next to a player
##   saw       2  lane charger (classic)
##   ghost     3  brick-walker (classic)
##   elemental 3  lane fireballs (classic)
##   freezer   3  touch FREEZES instead of kills
##   thief     3  beelines for revealed power-ups and eats them
##   muncher   3  swallows ticking bombs, then digests slowly
##   snake     3  4 segments; body hits chop it shorter, head kills it
##   mimic     4  disguised as THIS ARENA'S brick until you come close
##   warlock   4  summons fresh monsters (two per warlock)
##   bull      4  telegraphed line charge, stunned on impact
##   centipede 4  6 segments, armored body — only the head burns
##   dragon    5  5 segments, armored, 3 hits to kill, breathes fire
##   bomber    5  the planner mini-boss (BomberBrain)
##
## `g` is the battle scene (scripts/main.gd).

const TIER := {
	"balloon": 1, "slime": 1, "snail": 1,
	"chomper": 2, "bees": 2, "frog": 2, "mole": 2, "saw": 2,
	"ghost": 3, "elemental": 3, "freezer": 3, "thief": 3, "muncher": 3,
	"snake": 3,
	"mimic": 4, "warlock": 4, "bull": 4, "centipede": 4,
	"dragon": 5, "bomber": 5,
}

## Serpent bodies: segment count INCLUDING head, and the sprite names.
const SERPENTS := {
	"snake": {"len": 4, "body": "snake_body", "tail": "snake_tail"},
	"centipede": {"len": 6, "body": "centi_body", "tail": "centi_body"},
	"dragon": {"len": 5, "body": "dragon_body", "tail": "dragon_tail"},
}
const SEG_SPACING := 0.85   # cells between serpent segments
const TRACK_STEP := 0.12    # min cells between recorded head samples

var g  # the battle scene (scripts/main.gd)


func _init(scene) -> void:
	g = scene


static func by_tier(tier: int) -> Array[String]:
	var out: Array[String] = []
	for t: String in TIER:
		if TIER[t] == tier:
			out.append(t)
	return out


func is_serpent(e: Monster) -> bool:
	return SERPENTS.has(e.type)


# ------------------------------------------------------------- spawning ----

## Type-specific birth setup; called by main right after _new_monster.
func on_spawn(e: Monster) -> void:
	match e.type:
		"dragon":
			e.hp = 3
			e.special_t = g.rng.randf_range(3.0, 5.0)  # first fire breath
		"warlock":
			e.special_t = g.rng.randf_range(8.0, 12.0)
		"frog":
			e.special_t = g.rng.randf_range(2.5, 4.5)
		"mole":
			e.special_t = g.rng.randf_range(4.0, 7.0)
		"mimic":
			# Born in costume: this arena's own brick, tile-sized.
			e.mode = "disguised"
			var tex: Texture2D = TileArt.brick(g._skin)
			e.node.texture = tex
			e.node.scale = Vector2.ONE * (g.cell_px / tex.get_width())
	if is_serpent(e):
		var info: Dictionary = SERPENTS[e.type]
		e.track = [e.pos]
		for i in int(info["len"]) - 1:
			var seg := Sprite2D.new()
			var tex_name: String = info["tail"] if i == int(info["len"]) - 2 \
				else info["body"]
			seg.texture = g._tex[tex_name]
			# Body shrinks gently toward the tail.
			seg.scale = Vector2.ONE * (g.cell_px / 64.0) * (0.98 - 0.06 * i)
			seg.position = g._to_px(e.pos)
			seg.z_index = -1 - i  # head draws over neck, neck over torso...
			g._entities_root.add_child(seg)
			e.body.append(seg)


## Mid-round removal (flame death, pressure crush): free the parts the
## entity owns beyond its head sprite. Round rebuilds sweep the whole
## entities root, so this is only for deaths DURING play.
func free_parts(e: Monster) -> void:
	for seg: Sprite2D in e.body:
		if is_instance_valid(seg):
			seg.queue_free()
	e.body.clear()


# ------------------------------------------------------------- movement ----

## Cells per second, honoring the type's current state.
func speed(e: Monster) -> float:
	match e.type:
		"slime":
			return 2.2 if e.kind == "mini" else 1.2
		"snail":
			return 0.8
		"frog":
			return 1.6
		"mole":
			return 1.6
		"thief":
			return 2.2
		"freezer":
			return 1.9
		"muncher":
			return 0.9 if e.mode == "digest" else 1.8
		"mimic":
			return 2.6  # only ever walks awake
		"warlock":
			return 1.5
		"bull":
			return 5.0 if e.mode == "charge" else 1.6
		"snake":
			return 2.0
		"centipede":
			return 2.6
		"dragon":
			return 1.7
	return -1.0  # not ours — main keeps its classic value


## Per-frame specials BEFORE the destination walker. Returns false when
## the walker must be skipped this frame (the type is doing its own
## thing: burrowed, mid-hop, in costume, winding up or stunned).
func pre_walk(e: Monster, delta: float) -> bool:
	e.special_t -= delta
	e.birth_grace = maxf(e.birth_grace - delta, 0.0)
	match e.type:
		"snail":
			# Fresh goo on every cell the snail slides across.
			g.goo[Vector2i(e.pos.round())] = g._clock + 6.0  # game seconds (v11.7)
		"frog":
			return _frog(e, delta)
		"mole":
			return _mole(e, delta)
		"thief":
			_thief_eat(e)
		"muncher":
			_muncher(e)
		"mimic":
			return _mimic(e)
		"warlock":
			_warlock(e)
		"bull":
			return _bull(e, delta)
		"dragon":
			if e.special_t <= 0.0 and e.mode != "hurt":
				e.special_t = g.rng.randf_range(3.5, 6.0)
				var dirv: Vector2i = e.dir
				if dirv == Vector2i.ZERO:
					var prey: Vector2i = g._nearest_player_cell(e.pos)
					var dv := Vector2(prey) - e.pos
					dirv = Vector2i(signi(int(dv.x * 10.0)), 0) \
						if absf(dv.x) > absf(dv.y) \
						else Vector2i(0, signi(int(dv.y * 10.0)))
					if dirv == Vector2i.ZERO:
						dirv = Vector2i(1, 0)
				g._spawn_fireball(e.pos, dirv, e)  # voices "spit" itself
	if e.mode == "hurt":  # dragon i-frames: flash, keep walking
		e.node.modulate.a = 0.5 + 0.4 * sin(e.anim_t * 30.0)
		if e.special_t <= 0.0:
			e.mode = ""
			e.node.modulate.a = 1.0
	return true


## Steering goal for the hunters with agendas. ZERO = let the default
## walker wander. Greedy step: neighbor that shrinks manhattan distance
## to the target — arcade-brained on purpose (BFS perfection is the
## boss's shtick).
func steer(e: Monster, cur: Vector2i) -> Vector2i:
	var target := Vector2i(-99, -99)
	match e.type:
		"thief":
			target = _nearest_item(cur)
		"muncher":
			if e.mode != "digest":
				target = _nearest_bomb(cur)
		"mimic":
			if e.mode == "":
				target = g._nearest_player_cell(Vector2(cur))
		"snake", "centipede", "dragon":
			# Serpents stalk lazily: bias toward the prey 60% of arrivals.
			if g.rng.randf() < 0.6:
				target = g._nearest_player_cell(Vector2(cur))
	if target == Vector2i(-99, -99):
		return Vector2i.ZERO
	var best := Vector2i.ZERO
	var best_d := absi(target.x - cur.x) + absi(target.y - cur.y)
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var q := cur + d
		if not g._enemy_passable(q) and not (q == target and may_enter_bomb(e, q)):
			continue
		if _own_segment_cell(e, q):
			continue  # a serpent must not bite itself
		var dd := absi(target.x - q.x) + absi(target.y - q.y)
		if dd < best_d:
			best_d = dd
			best = d
	return best


## AFTER the walker: serpent bodies follow the head's recorded track.
func post_move(e: Monster, _delta: float) -> void:
	if not is_serpent(e):
		return
	if e.track.is_empty() \
			or (e.track[0] as Vector2).distance_to(e.pos) >= TRACK_STEP:
		e.track.push_front(e.pos)
		var cap := int((e.body.size() + 2) * SEG_SPACING / TRACK_STEP) + 8
		if e.track.size() > cap:
			e.track.resize(cap)
	for i in e.body.size():
		var seg := e.body[i] as Sprite2D
		if not is_instance_valid(seg):
			continue
		seg.position = g._to_px(_along_track(e, (i + 1) * SEG_SPACING))


## Walk the recorded polyline back `dist` cells from the head.
func _along_track(e: Monster, dist: float) -> Vector2:
	var walked := 0.0
	for i in e.track.size() - 1:
		var a: Vector2 = e.track[i]
		var b: Vector2 = e.track[i + 1]
		var leg := a.distance_to(b)
		if walked + leg >= dist:
			return a.lerp(b, (dist - walked) / maxf(leg, 0.0001))
		walked += leg
	return e.track.back() if not e.track.is_empty() else e.pos


func _own_segment_cell(e: Monster, c: Vector2i) -> bool:
	if not is_serpent(e):
		return false
	for seg: Sprite2D in e.body:
		if is_instance_valid(seg) \
				and Vector2i((g._from_px(seg.position)).round()) == c:
			return true
	return false


# ---------------------------------------------------- type state machines --

func _frog(e: Monster, delta: float) -> bool:
	if e.mode == "air":
		# Sail over whatever is below; land on schedule.
		e.pos = e.pos.move_toward(Vector2(e.dest), 4.5 * delta)
		var t := clampf(e.pos.distance_to(Vector2(e.dest)) / 2.0, 0.0, 1.0)
		e.node.scale = Vector2.ONE * (g.cell_px / 64.0) * (1.06 + 0.5 * sin(t * PI))
		if e.pos.is_equal_approx(Vector2(e.dest)):
			e.mode = ""
			e.dir = Vector2i.ZERO
			e.node.scale = Vector2.ONE * (g.cell_px / 64.0) * 1.06
			# No landing sound (v7.2): a hop every ~3 s made the long
			# "womp" trombone play nearly nonstop — the arc is the cue.
		return false
	if e.special_t <= 0.0:
		e.special_t = g.rng.randf_range(2.5, 4.5)
		var cur := Vector2i(e.pos.round())
		var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0),
			Vector2i(0, 1), Vector2i(0, -1)]
		dirs.shuffle()
		for d in dirs:
			var land := cur + d * 2
			# The point of the hop: the cell BETWEEN may be anything.
			if g._enemy_passable(land):
				e.mode = "air"
				e.dest = land
				e.pos = Vector2(cur)
				return false
	return true


func _mole(e: Monster, delta: float) -> bool:
	if e.mode == "burrow":
		e.node.modulate.a = 0.0  # underground: just the dirt kicked up
		if e.special_t <= 0.0:
			# Pop up near a player — that's the whole prank.
			var prey: Vector2i = g._nearest_player_cell(e.pos)
			var spots: Array[Vector2i] = []
			for dx in range(-3, 4):
				for dy in range(-3, 4):
					var c := prey + Vector2i(dx, dy)
					if g._enemy_passable(c) and (absi(dx) + absi(dy)) >= 1 \
							and not _near_player(c):
						spots.append(c)
			if not spots.is_empty():
				e.pos = Vector2(spots.pick_random())
			e.mode = ""
			e.dir = Vector2i.ZERO
			e.clear_dest()
			e.node.modulate.a = 1.0
			e.special_t = g.rng.randf_range(4.0, 7.0)
			g._fx.make_dirt_burst(g._to_px(e.pos), g.cell_px)  # visual cue only
		return false
	if e.special_t <= 0.0:
		e.mode = "burrow"
		e.special_t = 2.5
		g._fx.make_dirt_burst(g._to_px(e.pos), g.cell_px)
	return true


func _thief_eat(e: Monster) -> void:
	var c := Vector2i(e.pos.round())
	if g.ground_items.has(c) and e.pos.distance_to(Vector2(c)) < 0.3:
		g.ground_items.erase(c)
		if g.item_sprites.has(c):
			(g.item_sprites[c] as Sprite2D).queue_free()
			g.item_sprites.erase(c)
		Sfx.play("pickup_denied", 0.2)  # your loot, gone


## A hungry muncher may step ONTO a bomb — that is how it eats (v11.7:
## steer and the walker both treated bomb cells as walls, so munchers
## stalled one cell short of every bomb and the ability never fired).
func may_enter_bomb(e: Monster, c: Vector2i) -> bool:
	if e.type != "muncher" or e.mode == "digest" or g.arena.solid(c.x, c.y):
		return false
	for b: Dictionary in g.bombs:
		if (b["cell"] as Vector2i) == c and not b.has("slide"):
			return true
	return false


func _muncher(e: Monster) -> void:
	if e.mode == "digest":
		e.node.modulate = Color(1.4, 1.2, 1.6)  # glowing with a full belly
		if e.special_t <= 0.0:
			e.mode = ""
			e.node.modulate = Color.WHITE
		return
	var c := Vector2i(e.pos.round())
	for b: Dictionary in g.bombs:
		if (b["cell"] as Vector2i) == c and not b.has("slide"):
			g._defuse_bomb(b)
			e.mode = "digest"
			e.special_t = 4.0
			Sfx.play("womp", 0.4)
			break


func _mimic(e: Monster) -> bool:
	var near := 1e9
	for p: Bomber in g.players:
		if p.alive:
			near = minf(near, p.pos.distance_to(e.pos))
	if e.mode == "disguised":
		if near < 3.5:
			e.mode = ""
			e.node.texture = g._tex["mimic"]
			e.node.scale = Vector2.ONE * (g.cell_px / 64.0) * 1.06
			e.dir = Vector2i.ZERO
			e.clear_dest()
			Sfx.play("skull", 0.2)  # the brick has TEETH
		return false
	return true


func _warlock(e: Monster) -> void:
	# Two summons per warlock — enough to feel dangerous, no monster
	# printer. Fresh recruits come from tier 1-2 fodder.
	if e.special_t > 0.0 or e.stock >= 2:
		return
	e.special_t = g.rng.randf_range(9.0, 13.0)
	var cur := Vector2i(e.pos.round())
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if g._enemy_passable(cur + d) and not _near_player(cur + d):
			var kind: String = ["balloon", "slime", "bees"].pick_random()
			g._spawn_enemy_at(kind, cur + d)
			e.stock += 1
			var burst: CPUParticles2D = g._fx.make_burst(18, 0.5,
				g.cell_px * 0.4, g.cell_px * 1.6, g.cell_px * 0.05,
				g.cell_px * 0.1, Vector2.ZERO,
				[Color("8af0c8"), Color("4a2878"), Color(0.5, 0.9, 0.8, 0.0)])
			burst.position = g._to_px(Vector2(cur + d))
			g._flame_canvas.add_child(burst)
			Sfx.play("portal", 0.3)
			g._update_portal_state()  # a monster was born — door shuts
			break


## A monster must never APPEAR on top of a bomber (v11.7): the warlock's
## summon and the mole's pop-up only checked the terrain, so a spawn on
## the player's own cell — or within touch range mid-step — was an
## instant, unanswerable death.
func _near_player(c: Vector2i) -> bool:
	for p: Bomber in g.players:
		if p.alive and p.pos.distance_to(Vector2(c)) < 1.5:
			return true
	return false


func _bull(e: Monster, delta: float) -> bool:
	match e.mode:
		"telegraph":
			# The tell rides the sprite OFFSET (v11.7): main re-places
			# node.position right after pre_walk, so jittering position
			# was erased every frame — the wind-up never showed.
			var spr := e.node as Sprite2D
			spr.offset.x = g.rng.randf_range(-2.0, 2.0) / maxf(spr.scale.x, 0.01)
			if e.special_t <= 0.0:
				spr.offset = Vector2.ZERO
				e.mode = "charge"
			return false
		"charge":
			# Centre-to-centre, never past an open cell (v11.7): a flat
			# 5 c/s step could jump the 0.1-wide stop window on a slow
			# frame and tunnel through a wall — even off the grid, where
			# fire can't reach it and the solo portal never opens.
			var left := 5.0 * delta
			while left > 0.0:
				var cell := Vector2i(e.pos.round())
				var center := Vector2(cell)
				var target := center
				if (e.pos - center).dot(Vector2(e.dir)) >= -0.001:
					if not g._enemy_passable(cell + e.dir):
						e.mode = "stun"
						e.special_t = 1.5
						e.pos = center
						g._shake = minf(g._shake + 3.0, 14.0)
						Sfx.play("brick", 0.15)
						return false
					target = center + Vector2(e.dir)
				var step := minf(left, e.pos.distance_to(target))
				if step <= 0.0:
					break
				e.pos = e.pos.move_toward(target, step)
				left -= step
			return false
		"stun":
			e.node.rotation = sin(e.anim_t * 14.0) * 0.15
			if e.special_t <= 0.0:
				e.mode = ""
				e.node.rotation = 0.0
				e.dir = Vector2i.ZERO
				e.clear_dest()
			return false
	# Watching: a player on my row/column with a clear lane = red mist.
	var cur := Vector2i(e.pos.round())
	for p: Bomber in g.players:
		if not p.alive:
			continue
		var pc := Vector2i(p.pos.round())
		if pc.x != cur.x and pc.y != cur.y:
			continue
		var span := absi(pc.x - cur.x) + absi(pc.y - cur.y)
		if span < 2 or span > 6:
			continue
		var step := Vector2i(signi(pc.x - cur.x), signi(pc.y - cur.y))
		var clear := true
		for i in range(1, span):
			if not g._enemy_passable(cur + step * i):
				clear = false
				break
		if clear:
			e.mode = "telegraph"
			e.special_t = 0.6
			e.dir = step
			e.pos = Vector2(cur)
			return false
	return true


# --------------------------------------------------------- damage & touch --

## What touching this monster does to a player: "kill", "freeze" or ""
## (harmless right now). Serpent bodies are as deadly as their heads.
func touch_result(e: Monster, p: Bomber) -> String:
	if e.mode == "burrow" or e.mode == "air" or e.mode == "disguised":
		return ""
	var touching: bool = e.pos.distance_to(p.pos) < g.PLAYER_R + 0.3
	if not touching and is_serpent(e):
		for seg: Sprite2D in e.body:
			if is_instance_valid(seg) \
					and g._from_px(seg.position).distance_to(p.pos) < g.PLAYER_R + 0.25:
				touching = true
				break
	if not touching:
		return ""
	if e.type == "freezer":
		return "freeze" if p.freeze_immune_t <= 0.0 else ""
	return "kill"


## A flame pass over this monster. Returns true if it DIED (main frees
## the head and removes it); chops, armor and i-frames resolve here.
func flame_check(e: Monster) -> bool:
	if e.mode == "burrow" or e.mode == "air":
		return false  # underground / airborne: unreachable
	var head := Vector2i(e.pos.round())
	var head_hit: bool = g.flames.has(head)
	if is_serpent(e):
		if head_hit:
			return _serpent_head_hit(e)
		# Body hits: the snake gets CHOPPED; armored serpents shrug.
		if e.type == "snake":
			for i in e.body.size():
				var seg := e.body[i] as Sprite2D
				if is_instance_valid(seg) \
						and g.flames.has(Vector2i(g._from_px(seg.position).round())):
					_credit_kill(Vector2i(g._from_px(seg.position).round()))
					for j in range(e.body.size() - 1, i - 1, -1):
						var cut := e.body[j] as Sprite2D
						if is_instance_valid(cut):
							cut.queue_free()
						e.body.remove_at(j)
					Sfx.play("enemy_die", 0.2)
					break
		return false
	if not head_hit:
		return false
	if e.birth_grace > 0.0:
		return false  # newborn grace — not the parent's own blast (v10.4)
	if e.type == "slime" and e.kind != "mini":
		# The classic split: two angry minis where one slime stood.
		_credit_kill(head)
		for i in 2:
			var m: Monster = g._spawn_enemy_at("slime", head)
			m.kind = "mini"
			m.birth_grace = 0.6   # outlive the blast that made you (v10.4)
			m.node.scale = Vector2.ONE * (g.cell_px / 64.0) * 0.65
			m.pos = e.pos + Vector2(g.rng.randf_range(-0.3, 0.3),
				g.rng.randf_range(-0.3, 0.3))
		return true
	if e.type == "dragon":
		if e.mode == "hurt":
			return false  # i-frames
		e.hp -= 1
		_credit_kill(head)
		if e.hp > 0:
			e.mode = "hurt"
			e.special_t = 1.2
			Sfx.play("enemy_die", 0.4)
			return false
		return true
	_credit_kill(head)
	return true


func _serpent_head_hit(e: Monster) -> bool:
	if e.type == "dragon":
		if e.mode == "hurt":
			return false
		e.hp -= 1
		_credit_kill(Vector2i(e.pos.round()))
		if e.hp > 0:
			e.mode = "hurt"
			e.special_t = 1.2
			Sfx.play("enemy_die", 0.4)
			return false
	else:
		_credit_kill(Vector2i(e.pos.round()))
	free_parts(e)
	return true


func _credit_kill(cell: Vector2i) -> void:
	if not g.flames.has(cell):
		return
	var owner := int((g.flames[cell] as Dictionary).get("owner", -9))
	if owner >= 0:
		g.players[owner].stat_kills += 1


# ---------------------------------------------------------------- helpers --

func _nearest_item(cur: Vector2i) -> Vector2i:
	var best := Vector2i(-99, -99)
	var best_d := 99999
	for c: Vector2i in g.ground_items:
		var d := absi(c.x - cur.x) + absi(c.y - cur.y)
		if d < best_d:
			best_d = d
			best = c
	return best


func _nearest_bomb(cur: Vector2i) -> Vector2i:
	var best := Vector2i(-99, -99)
	var best_d := 99999
	for b: Dictionary in g.bombs:
		var c := b["cell"] as Vector2i
		var d := absi(c.x - cur.x) + absi(c.y - cur.y)
		if d < best_d:
			best_d = d
			best = c
	return best
