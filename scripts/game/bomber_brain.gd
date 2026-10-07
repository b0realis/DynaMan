class_name BomberBrain
extends RefCounted
## The bomber AI planner, extracted from main.gd in v4.5 so it lives
## (and can be tuned) in one place. Two clients share the toolkit:
##   - decide()    — the mini-boss MONSTER (portal punishment, v4.0+)
##   - drive_bot() — bot PLAYERS filling battle slots (v4.6): solo
##     opponents and the zero-human demo mode both run on it.
##
## WHAT IT IS — a per-decision grid planner, called by main's enemy
## destination-walker every time the boss arrives at a cell center (or
## stands still). Priorities, in order:
##   1. Standing in a blast zone → BFS sprint to the nearest safe cell
##      (predicted bomb rays are crossable — you can outrun a fuse —
##      but cells actually ON FIRE are lava and block the search).
##   2. Kill shot: the nearest player sits inside the blast a bomb at
##      the current cell would make → drop it, IF a verified escape
##      out of that future blast exists.
##   3. Summon: below Settings.max_bosses with the exit portal
##      revealed, a boss whose committed coin-flip said "summon" bombs
##      the doorway — the portal answers with a colleague.
##   4. Walk: toward the prey if reachable; otherwise MINE — commit to
##      the brick-adjacent cell nearest the prey and tunnel from there
##      (commitment matters: distance ties flip with the walker's own
##      position, and re-picking each arrival caused eternal marching).
##   5. Truly caged → after 8 s of futile glaring, light the fuse
##      anyway and go out with a bang (usually opening the cage).
##
## HOW IT TALKS TO THE SCENE — `g` is the battle scene (scripts/
## main.gd). The brain reads g.arena / g.bombs / g.flames / g.enemies
## / g.players / g.ground_items and portal state, and acts through
## g._spawn_bomb(). It never touches nodes directly.
##
## TUNING — ESCAPE_MAX must respect the runner: the boss moves at
## ~2.4 cells/s against a 2.8 s fuse, so trusting sprints longer than
## 5 cells is suicide (learned the hard way; see docs/DESIGN.md).

const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0),
	Vector2i(0, 1), Vector2i(0, -1)]
const ESCAPE_MAX := 5      # longest sprint the BOSS can trust (2.4 c/s)
const DESPERATION_S := 8.0 # caged this long → kamikaze

var g  # the battle scene (scripts/main.gd)


func _init(scene) -> void:
	g = scene


## One planning pass for boss `e` standing at cell `cur`. Sets e.dir
## (the destination-walker commits it to e.dest) and may place a
## bomb through the scene.
func decide(e: Monster, cur: Vector2i) -> void:
	var pass_cb := func(q: Vector2i) -> bool: return g._enemy_passable(q)
	var danger: Dictionary = g._danger_cells()
	# 1. In a blast zone: sprint out.
	if danger.has(cur):
		e.dir = escape_dir(cur, danger, pass_cb)
		return
	var reach := bfs(cur, danger, pass_cb)
	var prey: Vector2i = g._nearest_player_cell(Vector2(cur))
	var can_bomb: bool = e.bombs_out < e.bombs_max
	# Walk target: the prey if reachable. Otherwise MINE toward them:
	# only brick-adjacent cells make progress possible (a "closest to
	# prey" spot sealed by solid walls is a trap the old brain idled in).
	var goal := prey
	# Below the boss cap with the doorway revealed? Reinforcements are
	# on the table: bombing the portal calls a colleague out of it.
	var want_summon: bool = g._portal_spr != null \
		and g._boss_count() < Settings.max_bosses
	if not reach.has(prey):
		# Walled off from the prey: flip a coin — 50/50 between marching
		# to the doorway for reinforcements and mining bricks. The flip
		# is COMMITTED until the resulting bomb is placed; re-rolling
		# every arrival would flip-flop the march forever.
		var can_summon: bool = want_summon and reach.has(g.portal_cell)
		var intent := e.intent
		if intent == "summon" and not can_summon:
			intent = ""  # cap reached or door gone — re-decide
		if intent.is_empty():
			intent = "summon" if can_summon and g.rng.randf() < 0.5 else "mine"
			e.intent = intent
		if intent == "summon":
			goal = g.portal_cell
			e.goal = goal
		else:
			goal = _mining_goal(e, cur, prey, reach)
	else:
		e.goal = Monster.NO_GOAL
		e.intent = ""
	# 2. Bomb when the prey (or, on a committed summon intent, the
	# DOORWAY) is in blast range, or to tunnel onward when this is as
	# close as the bricks allow — but only with a verified escape.
	if can_bomb:
		var res: Dictionary = g.arena.blast(cur, e.flame, g._bomb_cells(),
			g.ground_items)
		var kill_shot: bool = (res["flames"] as Array).has(prey)
		var summon: bool = want_summon \
			and e.intent == "summon" \
			and (res["flames"] as Array).has(g.portal_cell)
		var tunnel: bool = goal == cur and not (res["bricks"] as Array).is_empty()
		if kill_shot or summon or tunnel:
			var esc := bomb_escape(cur, e.flame, danger, pass_cb,
				ESCAPE_MAX)
			if esc != Vector2i.ZERO \
					and g._spawn_bomb(cur, -1, e, e.col, e.flame):
				e.bombs_out = e.bombs_out + 1
				e.desper_t = -1.0
				e.intent = ""  # job done — next wall, next coin flip
				g._danger_frame = -1  # fresh bomb must enter the danger map
				e.dir = esc      # leave along the verified escape route
				return
			elif tunnel:
				# Caged with no survivable bomb — which is also the normal
				# half-second while its last blast's flames still block the
				# lanes, so desperation is measured in SECONDS, and the
				# clock must survive position bounces (an earlier version
				# reset it whenever the walker drifted off the mining
				# cell, so a caged boss paced forever). After 8 s truly
				# stuck, a mini-boss doesn't rot behind bricks: it lights
				# the fuse anyway and goes out with a bang — usually
				# blowing the cage open in the process.
				var now: float = g._clock  # game time: a pause mustn't count (v11.7)
				if e.desper_t < 0.0:
					e.desper_t = now
				if now - e.desper_t > DESPERATION_S \
						and g._spawn_bomb(cur, -1, e, e.col, e.flame):
					e.bombs_out = e.bombs_out + 1
					# The 8 s grace starts over (v11.7): it used to stay
					# spent, so every later caged half-second — even its
					# own flames clearing — was another unverified bomb.
					e.desper_t = -1.0
					e.intent = ""
					g._danger_frame = -1
					var away: Array[Vector2i] = []
					for d in DIRS:
						if g._enemy_passable(cur + d):
							away.append(d)
					e.dir = away.pick_random() if not away.is_empty() \
						else Vector2i.ZERO
					return
				# Hold the mining spot and glare at the wall — strolling
				# away would look aimless (and used to reset the clock).
				e.dir = Vector2i.ZERO
				return
	# 3. March on the goal; stroll when there's nowhere to march.
	if goal != cur and reach.has(goal):
		e.dir = (reach[goal] as Dictionary)["first"]
	else:
		var opts: Array[Vector2i] = []
		for d in DIRS:
			if g._enemy_passable(cur + d) and not danger.has(cur + d):
				opts.append(d)
		e.dir = opts.pick_random() if not opts.is_empty() else Vector2i.ZERO


## BFS flood over cells the walker can safely reach (passable via
## pass_cb, not in `hazard`). Returns {cell: {"d": steps, "first":
## first step from the start}} — follow "first" to walk the path.
func bfs(from: Vector2i, hazard: Dictionary, pass_cb: Callable) -> Dictionary:
	var out := {from: {"d": 0, "first": Vector2i.ZERO}}
	var queue: Array[Vector2i] = [from]
	var qi := 0
	while qi < queue.size():
		var c := queue[qi]
		qi += 1
		var info: Dictionary = out[c]
		for d in DIRS:
			var q := c + d
			if out.has(q) or hazard.has(q) or not pass_cb.call(q):
				continue
			out[q] = {"d": int(info["d"]) + 1,
				"first": d if c == from else info["first"]}
			queue.append(q)
	return out


## Already standing in a blast zone: BFS to the NEAREST safe cell.
## Predicted blast RAYS may be crossed (outrun the fuse); cells that
## are actually ON FIRE right now kill on contact and are walls here.
func escape_dir(cur: Vector2i, danger: Dictionary, pass_cb: Callable) -> Vector2i:
	var imminent: Dictionary = g._imminent_cells()
	var first := {cur: Vector2i.ZERO}
	var queue: Array[Vector2i] = [cur]
	var qi := 0
	while qi < queue.size():
		var c := queue[qi]
		qi += 1
		if not danger.has(c):
			return first[c]
		for d in DIRS:
			var q := c + d
			# Rays firing within IMMINENT_S are lava too (v12.2): a lit
			# chain link can't be outrun.
			if not first.has(q) and pass_cb.call(q) and not g.flames.has(q) \
					and not imminent.has(q):
				first[q] = d if c == cur else first[c]
				queue.append(q)
	return Vector2i.ZERO  # nowhere to run — hold and pray


## Would-I-survive check for bombing cur: add the bomb's own blast to
## the danger map and find a short sprint to a cell safe in that
## after-world. ZERO = suicide, so don't place. `max_steps` must match
## the runner's speed against the fuse (see header).
func bomb_escape(cur: Vector2i, flame_len: int, danger: Dictionary,
		pass_cb: Callable, max_steps: int) -> Vector2i:
	var sim := danger.duplicate()
	# Same model as main's danger map: other bombs are see-through (a
	# chain fires through them) and the bricks it burns are deadly (a
	# wall-pass runner "escaping" into its own brick died there).
	var res: Dictionary = g.arena.blast(cur, flame_len, {}, g.ground_items)
	for c: Vector2i in (res["flames"] as Array) + (res["bricks"] as Array):
		sim[c] = true
	var imminent: Dictionary = g._imminent_cells()
	var first := {cur: Vector2i.ZERO}
	var dist := {cur: 0}
	var queue: Array[Vector2i] = [cur]
	var qi := 0
	while qi < queue.size():
		var c := queue[qi]
		qi += 1
		if not sim.has(c):
			return (first[c] as Vector2i) if int(dist[c]) <= max_steps \
				else Vector2i.ZERO
		for d in DIRS:
			var q := c + d
			# Live flames are lava, not transit (see escape_dir).
			if not first.has(q) and pass_cb.call(q) and not g.flames.has(q) \
					and not imminent.has(q):
				first[q] = d if c == cur else first[c]
				dist[q] = int(dist[c]) + 1
				queue.append(q)
	return Vector2i.ZERO


## Mining target: COMMIT to a brick-adjacent spot until reached or
## invalidated — the best-cell pick has distance ties whose winner
## shifts with the walker's own position, and re-picking on every
## arrival made the boss march between tied goals forever.
func _mining_goal(e: Monster, cur: Vector2i, prey: Vector2i,
		reach: Dictionary) -> Vector2i:
	var kept: Vector2i = e.goal
	if reach.has(kept) and kept != cur and _touches_brick(kept):
		return kept
	var goal := cur
	var best_m := 99999
	var best_d := 99999
	for rc: Vector2i in reach:
		if not _touches_brick(rc):
			continue
		var m := absi(rc.x - prey.x) + absi(rc.y - prey.y)
		var rd := int((reach[rc] as Dictionary)["d"])
		if m < best_m or (m == best_m and rd < best_d):
			best_m = m
			best_d = rd
			goal = rc
	e.goal = goal
	return goal


func _touches_brick(c: Vector2i) -> bool:
	for d in DIRS:
		if g.arena.cell(c.x + d.x, c.y + d.y) == Arena.BRICK:
			return true
	return false


# ---------------------------------------------------------- bot players ----

const BOT_REPLAN_S := 0.14 # seconds between planning passes
var bot_trace := false     # dev knob (tests/bot_debug.gd): trace bot 0
const BOT_ESCAPE_MAX := 6  # players sprint 3.4+ c/s vs the 2.8 s fuse
const BOT_LOOT_MAX := 6    # only detour for loot this many steps away


## One steering pass for bot player `p` (called every frame from the
## play tick; internally rate-limited by BOT_REPLAN_S). Writes
## p.bot_dir (consumed by _move_player in place of keyboard input) and
## latches p.bot_bomb (consumed by _place_bomb_input like a keypress).
##
## Priorities mirror the boss but from a player's seat:
##   1. In a blast zone → sprint out (predicted rays crossable,
##      live fire is lava).
##   2. Kill shot: a rival OR a monster inside the blast a bomb here
##      would make → drop it, with a verified escape.
##   3. Loot: a nearby non-skull power-up → grab it.
##   4. March on the nearest rival; if bricks wall them off, commit to
##      a mining spot (p.bot_goal) and tunnel — bomb when standing on
##      the committed spot.
##   5. Nothing to do → keep strolling; re-roll only when blocked.
func drive_bot(p: Bomber, delta: float) -> void:
	p.bot_t -= delta
	if p.bot_t > 0.0:
		return
	# += keeps each bot's stagger (seeded in _start_round), = re-synced
	# them all onto the same frame (v12.6). Skill throttle (v10.2).
	p.bot_t = maxf(p.bot_t + BOT_REPLAN_S * g.bot_replan_mult(), 0.0)
	var cur := Vector2i(p.pos.round())
	var pass_cb := func(q: Vector2i) -> bool: return g._passable(q, p.i)
	var danger: Dictionary = g._danger_cells()
	# 1. Standing in a blast zone: nothing else matters.
	if danger.has(cur):
		p.bot_dir = Vector2(escape_dir(cur, danger, pass_cb))
		if bot_trace and p.i == 0:
			print("T flee cur=%s dir=%s" % [cur, p.bot_dir])
		return
	if bot_trace and p.i == 0:
		print("T safe cur=%s goal=%s" % [cur, p.bot_goal])
	# Monsters kill on touch, so their cell (and where they're headed)
	# counts as hazard for WALKING — never worth crossing voluntarily.
	var haz := danger.duplicate()
	for e: Monster in g.enemies:
		haz[Vector2i(e.pos.round())] = true
		if e.has_dest():
			haz[Vector2i(e.dest)] = true
	var reach := bfs(cur, haz, pass_cb)
	var victim := _bot_victim(p, reach)
	var can_bomb: bool = p.bombs_out < p.bombs_max \
		and p.curse != g.Curse.NO_BOMBS
	# 2. Kill shot — on a rival, a monster, or the committed tunnel spot.
	if can_bomb:
		var res: Dictionary = g.arena.blast(cur, p.flame, g._bomb_cells(),
			g.ground_items)
		var flames: Array = res["flames"]
		var shot := victim != Bomber.NO_GOAL and flames.has(victim)
		if not shot:
			# ANY rival in range is a shot, not just the planned victim
			# (the victim pick can flip to a farther bomber while a
			# closer one stands in the blast).
			for q: Bomber in g.players:
				if q.i != p.i and q.alive \
						and not (p.team >= 0 and q.team == p.team) \
						and flames.has(Vector2i(q.pos.round())):
					shot = true
					break
		if not shot:
			for e: Monster in g.enemies:
				if flames.has(Vector2i(e.pos.round())):
					shot = true
					break
		var tunnel: bool = cur == p.bot_goal \
			and not (res["bricks"] as Array).is_empty()
		# Never into a TEAMMATE (v11.8): "teammate bots hunt only the
		# enemy" — but a partner standing in the blast died anyway.
		for q: Bomber in g.players:
			if q.i != p.i and q.alive and p.team >= 0 and q.team == p.team \
					and flames.has(Vector2i(q.pos.round())):
				shot = false
				tunnel = false
				# …and drop the dig spot (v12.2): two teammates committed
				# to the same cell vetoed each other forever, frozen.
				p.bot_goal = Bomber.NO_GOAL
				break
		if (shot or tunnel) and g.rng.randf() <= g.bot_bomb_chance():
			var esc := bomb_escape(cur, p.flame, danger, pass_cb,
				_bot_escape_max(p))
			if esc != Vector2i.ZERO:
				p.bot_bomb = true       # _place_bomb_input consumes this
				p.bot_bomb_cell = cur   # bomb THE PLANNED CELL (see Bomber)
				p.bot_goal = Bomber.NO_GOAL
				p.bot_dir = Vector2(esc) # leave along the verified route
				return
			elif tunnel:
				# The committed spot became a death trap (a rival's bomb
				# reshaped the map) — drop the commitment and re-pick
				# instead of glaring at the wall until it clears.
				p.bot_goal = Bomber.NO_GOAL
	# 3. Loot within reach: nearest non-skull item is worth a detour.
	var loot := _bot_loot(reach)
	if loot != Bomber.NO_GOAL:
		_bot_march(p, cur, loot, reach, haz)
		return
	# 4. The rival: walk up if reachable, tunnel toward them if not.
	if victim != Bomber.NO_GOAL:
		if reach.has(victim):
			p.bot_goal = Bomber.NO_GOAL
			_bot_march(p, cur, victim, reach, haz)
			return
		var goal := _bot_mining_goal(p, cur, victim, reach)
		if goal != cur:
			_bot_march(p, cur, goal, reach, haz)
			return
		p.bot_dir = Vector2.ZERO  # standing ON the spot; bomb next pass
		return
	# 5. Stroll: keep the current heading while it stays safe.
	var keep := Vector2i(p.bot_dir)
	if keep != Vector2i.ZERO and pass_cb.call(cur + keep) \
			and not haz.has(cur + keep):
		return
	var opts: Array[Vector2i] = []
	for d in DIRS:
		if pass_cb.call(cur + d) and not haz.has(cur + d):
			opts.append(d)
	p.bot_dir = Vector2(opts.pick_random()) if not opts.is_empty() \
		else Vector2.ZERO


## Would a bomb at `c` catch a living teammate where they stand now?
func _blast_hits_teammate(p: Bomber, c: Vector2i) -> bool:
	if p.team < 0:
		return false
	var hit: Array = g.arena.blast(c, p.flame, g._bomb_cells(), g.ground_items)["flames"]
	for q: Bomber in g.players:
		if q.i != p.i and q.alive and q.team == p.team \
				and hit.has(Vector2i(q.pos.round())):
			return true
	return false


## Longest escape sprint this bot can trust against the 2.8 s fuse:
## about two cells per cell-per-second of speed, capped at
## BOT_ESCAPE_MAX. A SLOW-cursed bot (1.6 c/s) used to plan the full
## 6-step sprint and die in it.
func _bot_escape_max(p: Bomber) -> int:
	var slow: bool = p.curse == g.Curse.SLOW or p.curse == g.Curse.REV_SLOW
	var spd: float = 1.6 if slow else p.speed
	if g.goo.has(Vector2i(p.pos.round())):
		spd *= 0.55   # wading through snail goo (v12.6) — same factor as _move_player
	return clampi(int(spd * 2.0), 2, BOT_ESCAPE_MAX)


## Walk one step along the BFS route to `goal` — but never step INTO a
## hazard cell while standing in a safe one (outrunning a fuse is for
## escapes, not errands).
func _bot_march(p: Bomber, cur: Vector2i, goal: Vector2i,
		reach: Dictionary, haz: Dictionary) -> void:
	if not reach.has(goal) or goal == cur:
		p.bot_dir = Vector2.ZERO
		return
	var first: Vector2i = (reach[goal] as Dictionary)["first"]
	p.bot_dir = Vector2.ZERO if haz.has(cur + first) else Vector2(first)


## Nearest OTHER living player by walking distance (unreachable rivals
## still count — someone has to tunnel to them; ties break by fewer
## steps, then by manhattan distance so the pick is stable).
func _bot_victim(p: Bomber, reach: Dictionary) -> Vector2i:
	var best := Bomber.NO_GOAL
	var best_key := Vector2i(99999, 99999)  # (reachable? steps : 9000+manhattan)
	for q: Bomber in g.players:
		if q.i == p.i or not q.alive:
			continue
		if p.team >= 0 and q.team == p.team:
			continue   # teammates are not prey (v10.2)
		var c := Vector2i(q.pos.round())
		var key := Vector2i(int((reach[c] as Dictionary)["d"]), 0) \
			if reach.has(c) \
			else Vector2i(9000 + absi(c.x - Vector2i(p.pos.round()).x)
				+ absi(c.y - Vector2i(p.pos.round()).y), 1)
		if key < best_key:
			best_key = key
			best = c
	return best


## Nearest reachable non-skull ground item, if it's close enough to be
## worth leaving the main plan for. Both skulls are curses — the green
## NASTY one too (bots used to detour to pick it up).
func _bot_loot(reach: Dictionary) -> Vector2i:
	var best := Bomber.NO_GOAL
	var best_d := BOT_LOOT_MAX + 1
	for c: Vector2i in g.ground_items:
		var it := int(g.ground_items[c])
		if it == Arena.ITEM_SKULL or it == Arena.ITEM_NASTY:
			continue
		if reach.has(c) and int((reach[c] as Dictionary)["d"]) < best_d:
			best_d = int((reach[c] as Dictionary)["d"])
			best = c
	return best


## The bot's committed tunnel spot toward an unreachable rival — same
## commitment rule as the boss's _mining_goal (re-picking every pass
## marches between distance ties forever), kept per-player in
## p.bot_goal instead of the Monster fields.
##
## One rule the boss doesn't have: only commit to spots where the bomb
## is SURVIVABLE. A spawn-corner pocket is brick-adjacent and closest,
## but a bomb there can cover the whole pocket — the first probe run
## had two bots frozen in their corners glaring at walls, because the
## tunnel branch (rightly) refused the suicide bomb forever. Testing
## the escape at commit time makes them walk to the far end of the
## pocket, where the blast leaves a corridor to run back into.
func _bot_mining_goal(p: Bomber, cur: Vector2i, prey: Vector2i,
		reach: Dictionary) -> Vector2i:
	var kept: Vector2i = p.bot_goal
	if reach.has(kept) and _touches_brick(kept):
		return kept
	var danger: Dictionary = g._danger_cells()
	var pass_cb := func(q: Vector2i) -> bool: return g._passable(q, p.i)
	# Rank every brick-adjacent reachable cell by (progress toward the
	# prey, then steps), and commit to the best SURVIVABLE one.
	var ranked: Array[Vector2i] = []
	for rc: Vector2i in reach:
		if _touches_brick(rc):
			ranked.append(rc)
	ranked.sort_custom(func(x: Vector2i, y: Vector2i) -> bool:
		var mx := absi(x.x - prey.x) + absi(x.y - prey.y)
		var my := absi(y.x - prey.x) + absi(y.y - prey.y)
		if mx != my:
			return mx < my
		return int((reach[x] as Dictionary)["d"]) < int((reach[y] as Dictionary)["d"]))
	for rc in ranked:
		if _blast_hits_teammate(p, rc):
			continue   # a spot whose bomb would take your partner is no spot
		if bomb_escape(rc, p.flame, danger, pass_cb, _bot_escape_max(p)) \
				!= Vector2i.ZERO:
			p.bot_goal = rc
			return rc
	p.bot_goal = Bomber.NO_GOAL
	return cur  # nowhere survivable — hold; the arena will change
