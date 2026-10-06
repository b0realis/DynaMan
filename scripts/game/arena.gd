class_name Arena
extends RefCounted
## Arena — pure battle-grid logic, fully headless-testable: generation
## (border + pillar walls, density-driven bricks, spawn-corner clearing,
## hidden items) and blast-ray propagation. The scene (scripts/main.gd)
## owns everything that moves; this owns everything that is a cell.
##
## Cells: x right, y down, (0,0) top-left. w and h are odd; walls ring the
## border and stand at every (even, even) cell — the classic skeleton.

enum { FLOOR, WALL, BRICK }
enum { ITEM_BOMB, ITEM_FIRE, ITEM_SPEED, ITEM_SKULL, ITEM_KICK, ITEM_VEST,
	ITEM_WALLPASS, ITEM_NASTY }
const ITEM_NONE := -1

var w: int
var h: int
var _cells: PackedByteArray
## Hidden under bricks: Vector2i -> item id. Popped by burn().
var hidden: Dictionary = {}


## Player spawn corners, ordered so 2 players sit diagonal (max distance):
## P1 top-left, P2 bottom-right, P3 top-right, P4 bottom-left.
static func spawn_cells(width: int, height: int) -> Array[Vector2i]:
	return [Vector2i(1, 1), Vector2i(width - 2, height - 2),
		Vector2i(width - 2, 1), Vector2i(1, height - 2)]


func generate(width: int, height: int, brick_density: float,
		bonus_density: float, danger_share: float,
		rng: RandomNumberGenerator) -> void:
	w = width if width % 2 == 1 else width - 1
	h = height if height % 2 == 1 else height - 1
	_cells = PackedByteArray()
	_cells.resize(w * h)
	hidden = {}

	# Spawn protection: each corner plus its two corridor neighbors.
	var protected: Dictionary = {}
	for s in spawn_cells(w, h):
		protected[s] = true
		for d: Vector2i in DIRS:
			var q := s + d
			if q.x > 0 and q.x < w - 1 and q.y > 0 and q.y < h - 1:
				protected[q] = true

	for y in h:
		for x in w:
			var c := Vector2i(x, y)
			if x == 0 or y == 0 or x == w - 1 or y == h - 1 \
					or (x % 2 == 0 and y % 2 == 0):
				_put(x, y, WALL)
			elif not protected.has(c) and rng.randf() < brick_density:
				_put(x, y, BRICK)
				if rng.randf() < bonus_density:
					hidden[c] = _roll_item(danger_share, rng)


func _roll_item(danger_share: float, rng: RandomNumberGenerator) -> int:
	if rng.randf() < danger_share:
		# 70% plain curse skull, 30% the contagious green one.
		return ITEM_SKULL if rng.randf() < 0.7 else ITEM_NASTY
	var r := rng.randf()
	if r < 0.30:
		return ITEM_BOMB
	if r < 0.60:
		return ITEM_FIRE
	if r < 0.75:
		return ITEM_SPEED
	if r < 0.87:
		return ITEM_KICK
	if r < 0.95:
		return ITEM_VEST
	return ITEM_WALLPASS


func cell(x: int, y: int) -> int:
	if x < 0 or x >= w or y < 0 or y >= h:
		return WALL
	return _cells[x + y * w]


func _put(x: int, y: int, v: int) -> void:
	_cells[x + y * w] = v


func solid(x: int, y: int) -> bool:
	return cell(x, y) != FLOOR


## Burn a brick away; returns the item that was hiding under it (ITEM_NONE
## if none). No-op returning ITEM_NONE for non-brick cells.
func burn(c: Vector2i) -> int:
	if cell(c.x, c.y) != BRICK:
		return ITEM_NONE
	_put(c.x, c.y, FLOOR)
	var item: int = hidden.get(c, ITEM_NONE)
	hidden.erase(c)
	return item


## All FLOOR cells (for enemy spawning etc.).
func floor_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in h:
		for x in w:
			if cell(x, y) == FLOOR:
				out.append(Vector2i(x, y))
	return out


const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


## Sudden-death pressure (v4.5): the cell becomes solid WALL, whatever
## it held is gone. The caller handles crushing/sprites.
func harden(x: int, y: int) -> void:
	_put(x, y, WALL)


## Blast propagation from origin with the given flame length. Rays stop at
## walls; the first brick hit burns and stops the ray; a bomb in the path
## chains (and stops the ray); a revealed ground item burns (and stops).
## Pure: takes the other bombs' and ground items' cells, mutates nothing.
## Returns {"flames": [cells aflame], "bricks": [brick cells to burn],
## "chains": [bomb cells to detonate], "items": [ground items to burn]}.
## `burned` marks bricks to treat as already-gone floor — used by the
## AI danger model to fixpoint chain blasts (bomb A clears the brick
## that was containing bomb B's ray, so B reaches further once A pops).
## `shield` is the opposite, for the LIVE detonation: cells whose brick
## burned earlier in the same frame keep stopping rays (v11.7).
func blast(origin: Vector2i, flame_len: int, bomb_cells: Dictionary,
		item_cells: Dictionary, burned: Dictionary = {},
		shield: Dictionary = {}) -> Dictionary:
	var flames: Array[Vector2i] = [origin]
	var bricks: Array[Vector2i] = []
	var chains: Array[Vector2i] = []
	var items: Array[Vector2i] = []
	for d: Vector2i in DIRS:
		for i in range(1, flame_len + 1):
			var c := origin + d * i
			var v := cell(c.x, c.y)
			if v == WALL:
				break
			if shield.has(c):
				break  # burned by this same instant's blast: still a brick to us
			if v == BRICK and burned.has(c):
				flames.append(c)  # brick will be gone by then — ray carries on
				continue
			if v == BRICK:
				bricks.append(c)
				break
			if bomb_cells.has(c):
				chains.append(c)
				flames.append(c)
				break
			if item_cells.has(c):
				items.append(c)
				flames.append(c)
				break
			flames.append(c)
	return {"flames": flames, "bricks": bricks, "chains": chains, "items": items}
