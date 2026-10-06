extends SceneTree
## Headless tests for Arena (generation + blast rays). Run with:
##   godot --headless --script res://tests/logic_test.gd

var failures := 0
var checks := 0
## Every check must actually RUN: a GDScript runtime error only aborts
## the test function it hits, and _init used to sail on to "ALL PASSED"
## with the rest of that function silently skipped. Bump when adding.
const EXPECTED_CHECKS := 26


func _init() -> void:
	_test_generation()
	_test_densities()
	_test_blast()
	_test_burn()
	print("---")
	if checks != EXPECTED_CHECKS:
		print("RAN %d OF %d CHECKS — a test function aborted early" % [checks, EXPECTED_CHECKS])
		quit(1)
	elif failures == 0:
		print("ALL %d CHECKS PASSED" % checks)
		quit(0)
	else:
		print("%d/%d CHECKS FAILED" % [failures, checks])
		quit(1)


func check(cond: bool, what: String) -> void:
	checks += 1
	if cond:
		print("  PASS  %s" % what)
	else:
		failures += 1
		print("  FAIL  %s" % what)


func _rng(seed_v: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	return r


func _test_generation() -> void:
	print("generation:")
	var a := Arena.new()
	a.generate(15, 13, 0.75, 0.25, 0.2, _rng(1))
	check(a.w == 15 and a.h == 13, "requested size kept")
	var a2 := Arena.new()
	a2.generate(14, 12, 0.75, 0.25, 0.2, _rng(1))
	check(a2.w == 13 and a2.h == 11, "even sizes forced odd")

	var border_ok := true
	for x in a.w:
		if a.cell(x, 0) != Arena.WALL or a.cell(x, a.h - 1) != Arena.WALL:
			border_ok = false
	for y in a.h:
		if a.cell(0, y) != Arena.WALL or a.cell(a.w - 1, y) != Arena.WALL:
			border_ok = false
	check(border_ok, "border is all walls")

	var pillars_ok := true
	for y in range(2, a.h - 1, 2):
		for x in range(2, a.w - 1, 2):
			if a.cell(x, y) != Arena.WALL:
				pillars_ok = false
	check(pillars_ok, "pillars at every even/even cell")

	var spawns := Arena.spawn_cells(a.w, a.h)
	check(spawns[0] == Vector2i(1, 1) and spawns[1] == Vector2i(13, 11),
		"P1/P2 diagonal corners")
	var clear_ok := true
	for s in spawns:
		if a.cell(s.x, s.y) != Arena.FLOOR:
			clear_ok = false
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = s + d
			if q.x > 0 and q.x < a.w - 1 and q.y > 0 and q.y < a.h - 1:
				if a.cell(q.x, q.y) == Arena.BRICK:
					clear_ok = false
	check(clear_ok, "spawn corners and their corridors are clear")

	var items_under_bricks := true
	for c: Vector2i in a.hidden:
		if a.cell(c.x, c.y) != Arena.BRICK:
			items_under_bricks = false
	check(items_under_bricks, "hidden items only under bricks")


func _test_densities() -> void:
	print("densities:")
	# Statistical sanity over a big arena: densities land near requested.
	var a := Arena.new()
	a.generate(21, 17, 0.8, 0.3, 0.5, _rng(7))
	var bricks := 0
	var eligible := 0
	for y in a.h:
		for x in a.w:
			if a.cell(x, y) != Arena.WALL:
				eligible += 1
				if a.cell(x, y) == Arena.BRICK:
					bricks += 1
	var brick_frac := float(bricks) / eligible
	check(brick_frac > 0.55 and brick_frac < 0.95,
		"brick fill near requested 0.8 (got %.2f of eligible+spawn-clear)" % brick_frac)
	var item_frac := float(a.hidden.size()) / bricks
	check(item_frac > 0.15 and item_frac < 0.45,
		"item share near requested 0.3 (got %.2f)" % item_frac)
	var skulls := 0
	for c: Vector2i in a.hidden:
		if a.hidden[c] == Arena.ITEM_SKULL or a.hidden[c] == Arena.ITEM_NASTY:
			skulls += 1
	var skull_frac := float(skulls) / maxi(a.hidden.size(), 1)
	check(skull_frac > 0.25 and skull_frac < 0.75,
		"dangerous share (skull+nasty) near requested 0.5 (got %.2f)" % skull_frac)
	var zero := Arena.new()
	zero.generate(15, 13, 0.75, 0.0, 0.5, _rng(3))
	check(zero.hidden.is_empty(), "bonus density 0 hides nothing")


func _test_blast() -> void:
	print("blast rays:")
	var a := Arena.new()
	a.generate(15, 13, 0.0, 0.0, 0.0, _rng(1))  # no bricks: open corridors
	# From (1,1), flame 2: right along row 1 and down column 1 are open.
	var res := a.blast(Vector2i(1, 1), 2, {}, {})
	var flames: Array = res["flames"]
	check(flames.has(Vector2i(1, 1)) and flames.has(Vector2i(3, 1))
		and flames.has(Vector2i(1, 3)),
		"open rays reach full flame length")
	check(not flames.has(Vector2i(0, 1)) and not flames.has(Vector2i(1, 0)),
		"border walls stop rays")
	check(not flames.has(Vector2i(2, 2)), "flames are a cross, not a square")

	# A brick stops the ray and is reported.
	var b := Arena.new()
	b.generate(15, 13, 0.0, 0.0, 0.0, _rng(1))
	b._put(3, 1, Arena.BRICK)
	var res2 := b.blast(Vector2i(1, 1), 4, {}, {})
	check((res2["bricks"] as Array).has(Vector2i(3, 1)), "brick in path burns")
	check(not (res2["flames"] as Array).has(Vector2i(3, 1))
		and not (res2["flames"] as Array).has(Vector2i(4, 1)),
		"ray stops at the brick")

	# A bomb chains and stops the ray; an item burns and stops the ray.
	var res3 := b.blast(Vector2i(1, 5), 4, {Vector2i(1, 7): true}, {Vector2i(3, 5): true})
	check((res3["chains"] as Array).has(Vector2i(1, 7)), "bomb in path chains")
	check(not (res3["flames"] as Array).has(Vector2i(1, 8)), "ray stops at chained bomb")
	check((res3["items"] as Array).has(Vector2i(3, 5)), "ground item in path burns")
	check(not (res3["flames"] as Array).has(Vector2i(4, 5)), "ray stops at the item")

	# Shield (v11.7): a brick burned earlier in the same instant still
	# stops a chained ray — and isn't reported for burning twice.
	var res4 := a.blast(Vector2i(1, 1), 4, {}, {}, {}, {Vector2i(3, 1): true})
	check((res4["flames"] as Array).has(Vector2i(2, 1))
		and not (res4["flames"] as Array).has(Vector2i(3, 1))
		and not (res4["flames"] as Array).has(Vector2i(4, 1)),
		"a shield cell stops the ray like a brick")
	check(not (res4["bricks"] as Array).has(Vector2i(3, 1)),
		"a shield cell is not burned twice")


func _test_burn() -> void:
	print("burn:")
	var a := Arena.new()
	a.generate(15, 13, 0.0, 0.0, 0.0, _rng(1))
	a._put(5, 1, Arena.BRICK)
	a.hidden[Vector2i(5, 1)] = Arena.ITEM_FIRE
	var item := a.burn(Vector2i(5, 1))
	check(item == Arena.ITEM_FIRE, "burn reveals the hidden item")
	check(a.cell(5, 1) == Arena.FLOOR, "burned brick becomes floor")
	check(a.burn(Vector2i(5, 1)) == Arena.ITEM_NONE, "burning floor is a no-op")
	check(a.burn(Vector2i(0, 0)) == Arena.ITEM_NONE, "burning a wall is a no-op")
