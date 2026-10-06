class_name TileSvg
extends RefCounted
## The arena-skin ART LIBRARY (v4.9): every non-classic skin's wall and
## brick as a 64×64 SVG body, grouped by collection. TileArt owns the
## API, cache and floor colours; this file is only drawings.
##
## Colour theory notes per collection:
##   - "Beautiful" set leans on harmonies: complements (teal ocean vs
##     coral brick, purple grapes vs vine green), analogous runs
##     (sunset, autumn), and monochrome tonal steps (jade, rose).
##   - Pastels keep saturation low and value high; the accent is a
##     soft complementary (lilac walls / butter bricks).
##   - Art homages pick the movement's signature palette (De Stijl
##     primaries, Van Gogh's night blue + chrome yellow, Monet's pond,
##     Hokusai's prussian blue on washi).
##   - Fantasy locations go for one loud storytelling brick each.
## LEGIBILITY RULE (learned in v4.8): wall vs brick must read at a
## squint. Destructibles are brighter/busier; walls darker/calmer.
## Organic or object bricks skip the background rect — the floor shows
## through, so they sit ON the lawn instead of painting over it.


static func svg(skin: String, kind: String) -> String:
	var body: String = _BODIES.get(skin + "/" + kind, "")
	if body.is_empty():
		body = "<rect width=\"64\" height=\"64\" fill=\"#ff00ff\"/>"  # loud, not crashy
	return "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"64\" height=\"64\" viewBox=\"0 0 64 64\">" \
		+ body + "</svg>"


## Classic beveled block, five tints — the geometry every "classic"
## variant shares (and a few stone-family walls reuse).
static func _bevel(base: String, light: String, dark: String,
		inner: String, center: String) -> String:
	return ("<rect width=\"64\" height=\"64\" fill=\"%s\"/>"
		+ "<path d=\"M0 0 H64 L56 8 H8 L8 56 L0 64 Z\" fill=\"%s\"/>"
		+ "<path d=\"M64 0 V64 H0 L8 56 H56 V8 Z\" fill=\"%s\"/>"
		+ "<rect x=\"8\" y=\"8\" width=\"48\" height=\"48\" fill=\"%s\"/>"
		+ "<rect x=\"14\" y=\"14\" width=\"36\" height=\"36\" fill=\"%s\"/>"
		+ "<rect x=\"28\" y=\"28\" width=\"8\" height=\"8\" fill=\"%s\"/>") \
		% [base, light, dark, inner, base, center]


## The classic brick-courses layout, five tints (mortar, face, shade
## line, light edge, dark edge).
static func _bricks(mortar: String, face: String, shade: String,
		light_edge: String, dark_edge: String) -> String:
	return ("<rect width=\"64\" height=\"64\" fill=\"%s\"/>"
		+ "<g fill=\"%s\">"
		+ "<rect x=\"2\" y=\"2\" width=\"28\" height=\"12\"/><rect x=\"34\" y=\"2\" width=\"28\" height=\"12\"/>"
		+ "<rect x=\"2\" y=\"18\" width=\"12\" height=\"12\"/><rect x=\"18\" y=\"18\" width=\"28\" height=\"12\"/><rect x=\"50\" y=\"18\" width=\"12\" height=\"12\"/>"
		+ "<rect x=\"2\" y=\"34\" width=\"28\" height=\"12\"/><rect x=\"34\" y=\"34\" width=\"28\" height=\"12\"/>"
		+ "<rect x=\"2\" y=\"50\" width=\"12\" height=\"12\"/><rect x=\"18\" y=\"50\" width=\"28\" height=\"12\"/><rect x=\"50\" y=\"50\" width=\"12\" height=\"12\"/>"
		+ "</g><g fill=\"%s\">"
		+ "<rect x=\"2\" y=\"11\" width=\"28\" height=\"3\"/><rect x=\"34\" y=\"11\" width=\"28\" height=\"3\"/>"
		+ "<rect x=\"2\" y=\"27\" width=\"12\" height=\"3\"/><rect x=\"18\" y=\"27\" width=\"28\" height=\"3\"/><rect x=\"50\" y=\"27\" width=\"12\" height=\"3\"/>"
		+ "<rect x=\"2\" y=\"43\" width=\"28\" height=\"3\"/><rect x=\"34\" y=\"43\" width=\"28\" height=\"3\"/>"
		+ "<rect x=\"2\" y=\"59\" width=\"12\" height=\"3\"/><rect x=\"18\" y=\"59\" width=\"28\" height=\"3\"/><rect x=\"50\" y=\"59\" width=\"12\" height=\"3\"/>"
		+ "</g>"
		+ "<path d=\"M0 0 H64 V3 H3 V64 H0 Z\" fill=\"%s\"/>"
		+ "<path d=\"M64 0 V64 H0 L3 61 H61 V3 Z\" fill=\"%s\" opacity=\"0.55\"/>") \
		% [mortar, face, shade, light_edge, dark_edge]


## Three-blob bush (hedge family): body colour, top-light colour,
## deep-shadow colour, plus accent circles appended by the caller.
static func _bush(body_c: String, light_c: String, dark_c: String,
		accents: String) -> String:
	return ("<g fill=\"%s\">"
		+ "<circle cx=\"22\" cy=\"44\" r=\"13\"/><circle cx=\"44\" cy=\"45\" r=\"12\"/><circle cx=\"32\" cy=\"28\" r=\"13\"/>"
		+ "</g><g fill=\"%s\">"
		+ "<circle cx=\"18\" cy=\"38\" r=\"8\"/><circle cx=\"40\" cy=\"38\" r=\"8\"/><circle cx=\"30\" cy=\"21\" r=\"8\"/>"
		+ "</g><g fill=\"%s\">"
		+ "<circle cx=\"27\" cy=\"50\" r=\"6\"/><circle cx=\"38\" cy=\"30\" r=\"5\"/><circle cx=\"14\" cy=\"48\" r=\"5\"/>"
		+ "</g>%s") % [body_c, light_c, dark_c, accents]


# ------------------------- user-arena shape library (v9.1) -----------------
## Eight colour-parameterized templates the ARENA MAKER composes into
## bespoke skins. TileArt derives the tint set from the user's ONE base
## colour per element: {base, soft, shade, light, pale, dark, deep}.
## Organic shapes skip the background rect so the floor shows through
## (the house rule) — they sit ON the lawn instead of painting over it.

const USER_SHAPES := ["bevel", "bricks", "planks", "panel",
	"cobbles", "crate", "ice",
	"hexes", "shingles", "bamboo", "sandstone", "circuit", "weave",
	"stainedglass", "moai", "scales", "lattice",
	"boulder", "bush", "crystal", "puff",
	"barrel", "gear", "mushroom",
	"gem", "pumpkin", "shell", "cactus", "lantern", "statue", "egg",
	"chest"]
const USER_SHAPE_NAMES := {"bevel": "Beveled block", "bricks": "Brick courses",
	"planks": "Timber planks", "panel": "Riveted panel", "boulder": "Boulder",
	"bush": "Bush", "crystal": "Crystal", "puff": "Cloud puff",
	"cobbles": "Cobblestone", "crate": "Crossed crate", "ice": "Ice block",
	"barrel": "Barrel", "gear": "Cogwheel", "mushroom": "Toadstool",
	"hexes": "Honeycomb", "shingles": "Shingles", "bamboo": "Bamboo",
	"sandstone": "Sandstone", "circuit": "Circuit board",
	"weave": "Basket weave", "stainedglass": "Stained glass",
	"moai": "Moai wall", "scales": "Dragon scales",
	"lattice": "Trellis", "gem": "Cut gem", "pumpkin": "Pumpkin",
	"shell": "Seashell", "cactus": "Cactus", "lantern": "Lantern",
	"statue": "Stone head", "egg": "Dragon egg", "chest": "Treasure chest"}
# (Organic-ness is baked into each shape's own SVG — the drop shadows
# and missing background rects — so no lookup table is needed.)


static func user_shape(shape: String, c: Dictionary) -> String:
	if shape == "runestone":
		shape = "moai"   # v9.6: the slab retired; saved themes carry over
	match shape:
		"bevel":
			return _bevel(c.base, c.light, c.deep, c.soft, c.shade)
		"bricks":
			return _bricks(c.light, c.base, c.dark, c.pale, c.deep)
		"bush":
			return _bush(c.base, c.light, c.deep, "")
		"planks":
			return ("<rect width=\"64\" height=\"64\" fill=\"%s\"/>"
				+ "<g fill=\"%s\"><rect x=\"2\" y=\"2\" width=\"60\" height=\"18\" rx=\"2\"/>"
				+ "<rect x=\"2\" y=\"23\" width=\"60\" height=\"18\" rx=\"2\"/>"
				+ "<rect x=\"2\" y=\"44\" width=\"60\" height=\"18\" rx=\"2\"/></g>"
				+ "<g fill=\"%s\"><rect x=\"2\" y=\"2\" width=\"60\" height=\"4\" rx=\"2\"/>"
				+ "<rect x=\"2\" y=\"23\" width=\"60\" height=\"4\" rx=\"2\"/>"
				+ "<rect x=\"2\" y=\"44\" width=\"60\" height=\"4\" rx=\"2\"/></g>"
				+ "<g stroke=\"%s\" stroke-width=\"1.6\" fill=\"none\" opacity=\"0.7\">"
				+ "<path d=\"M8 12 H34 M42 14 H58\"/><path d=\"M6 33 H22 M30 35 H56\"/>"
				+ "<path d=\"M10 54 H30 M38 56 H58\"/></g>"
				+ "<g fill=\"%s\"><circle cx=\"7\" cy=\"11\" r=\"1.8\"/><circle cx=\"57\" cy=\"11\" r=\"1.8\"/>"
				+ "<circle cx=\"7\" cy=\"53\" r=\"1.8\"/><circle cx=\"57\" cy=\"53\" r=\"1.8\"/></g>") \
				% [c.deep, c.base, c.light, c.dark, c.deep]
		"panel":
			return ("<rect width=\"64\" height=\"64\" fill=\"%s\"/>"
				+ "<path d=\"M0 0 H64 L58 6 H6 L6 58 L0 64 Z\" fill=\"%s\"/>"
				+ "<path d=\"M64 0 V64 H0 L6 58 H58 V6 Z\" fill=\"%s\"/>"
				+ "<rect x=\"6\" y=\"6\" width=\"52\" height=\"52\" fill=\"%s\"/>"
				+ "<rect x=\"14\" y=\"28\" width=\"36\" height=\"8\" rx=\"3\" fill=\"%s\"/>"
				+ "<rect x=\"14\" y=\"28\" width=\"36\" height=\"3\" rx=\"1.5\" fill=\"%s\" opacity=\"0.5\"/>"
				+ "<g fill=\"%s\"><circle cx=\"12\" cy=\"12\" r=\"3\"/><circle cx=\"52\" cy=\"12\" r=\"3\"/>"
				+ "<circle cx=\"12\" cy=\"52\" r=\"3\"/><circle cx=\"52\" cy=\"52\" r=\"3\"/></g>") \
				% [c.base, c.light, c.deep, c.soft, c.dark, c.pale, c.shade]
		"boulder":
			return ("<ellipse cx=\"32\" cy=\"56\" rx=\"24\" ry=\"6\" fill=\"#000\" opacity=\"0.18\"/>"
				+ "<path d=\"M8 46 Q4 24 18 14 Q32 4 46 13 Q60 22 56 42 Q52 58 32 58 Q14 58 8 46 Z\" fill=\"%s\"/>"
				+ "<path d=\"M14 26 Q20 12 36 11 Q28 22 24 34 Q18 32 14 26 Z\" fill=\"%s\"/>"
				+ "<path d=\"M40 52 Q54 48 55 34 Q58 48 48 55 Q42 58 40 52 Z\" fill=\"%s\"/>"
				+ "<g stroke=\"%s\" stroke-width=\"2\" fill=\"none\" opacity=\"0.75\">"
				+ "<path d=\"M30 20 L38 32 L34 44\"/><path d=\"M20 40 L28 46\"/></g>") \
				% [c.base, c.light, c.deep, c.dark]
		"crystal":
			return ("<ellipse cx=\"32\" cy=\"57\" rx=\"22\" ry=\"5\" fill=\"#000\" opacity=\"0.18\"/>"
				+ "<path d=\"M18 58 L12 34 L24 16 L30 40 Z\" fill=\"%s\"/>"
				+ "<path d=\"M24 16 L30 40 L26 58 L18 58 Z\" fill=\"%s\" opacity=\"0.8\"/>"
				+ "<path d=\"M30 58 L26 26 L40 8 L48 34 L44 58 Z\" fill=\"%s\"/>"
				+ "<path d=\"M40 8 L48 34 L44 58 L38 58 Z\" fill=\"%s\"/>"
				+ "<path d=\"M40 8 L34 30 L38 58\" fill=\"none\" stroke=\"%s\" stroke-width=\"1.6\" opacity=\"0.7\"/>"
				+ "<circle cx=\"36\" cy=\"18\" r=\"2\" fill=\"#ffffff\" opacity=\"0.9\"/>"
				+ "<circle cx=\"20\" cy=\"30\" r=\"1.4\" fill=\"#ffffff\" opacity=\"0.7\"/>") \
				% [c.dark, c.deep, c.base, c.light, c.pale]
		"puff":
			return ("<ellipse cx=\"32\" cy=\"56\" rx=\"23\" ry=\"5\" fill=\"#000\" opacity=\"0.12\"/>"
				+ "<g fill=\"%s\"><circle cx=\"20\" cy=\"42\" r=\"13\"/><circle cx=\"44\" cy=\"42\" r=\"13\"/>"
				+ "<circle cx=\"32\" cy=\"30\" r=\"15\"/><rect x=\"12\" y=\"42\" width=\"40\" height=\"12\" rx=\"6\"/></g>"
				+ "<g fill=\"%s\"><circle cx=\"26\" cy=\"24\" r=\"8\"/><circle cx=\"16\" cy=\"38\" r=\"7\"/>"
				+ "<circle cx=\"40\" cy=\"28\" r=\"6\"/></g>"
				+ "<g fill=\"%s\" opacity=\"0.8\"><circle cx=\"46\" cy=\"48\" r=\"6\"/>"
				+ "<circle cx=\"30\" cy=\"50\" r=\"5\"/></g>") \
				% [c.base, c.light, c.shade]
		"cobbles":
			# Rounded stones bedded in deep mortar; each gets a top-left
			# glint and a bottom shade so the wall reads plump, not flat.
			var stones := ""
			for s: Array in [[12, 11, 11, 9], [35, 9, 12, 8], [55, 12, 9, 8],
					[9, 31, 9, 8], [30, 30, 12, 9], [52, 31, 10, 8],
					[13, 51, 11, 8], [36, 52, 11, 8], [56, 51, 8, 7]]:
				stones += ("<ellipse cx=\"%d\" cy=\"%d\" rx=\"%d\" ry=\"%d\" fill=\"%s\"/>"
					+ "<ellipse cx=\"%d\" cy=\"%d\" rx=\"%d\" ry=\"%d\" fill=\"%s\"/>"
					+ "<ellipse cx=\"%d\" cy=\"%d\" rx=\"%d\" ry=\"%d\" fill=\"%s\" opacity=\"0.85\"/>") \
					% [s[0], s[1] + 1, s[2], s[3], c.deep,
						s[0], s[1], s[2], s[3], c.base,
						s[0] - s[2] / 3, s[1] - s[3] / 3, s[2] / 2, s[3] / 2, c.light]
			return "<rect width=\"64\" height=\"64\" fill=\"%s\"/>" % c.deep + stones
		"crate":
			return ("<rect width=\"64\" height=\"64\" fill=\"%s\"/>"
				+ "<rect x=\"2\" y=\"2\" width=\"60\" height=\"60\" fill=\"%s\"/>"
				+ "<rect x=\"2\" y=\"2\" width=\"60\" height=\"7\" fill=\"%s\" opacity=\"0.7\"/>"
				+ "<rect x=\"2\" y=\"55\" width=\"60\" height=\"7\" fill=\"%s\" opacity=\"0.6\"/>"
				+ "<g transform=\"rotate(45 32 32)\"><rect x=\"-12\" y=\"26\" width=\"88\" height=\"12\" rx=\"3\" fill=\"%s\" stroke=\"%s\" stroke-width=\"2\"/></g>"
				+ "<g transform=\"rotate(-45 32 32)\"><rect x=\"-12\" y=\"26\" width=\"88\" height=\"12\" rx=\"3\" fill=\"%s\" stroke=\"%s\" stroke-width=\"2\"/></g>"
				+ "<rect x=\"2\" y=\"2\" width=\"60\" height=\"60\" fill=\"none\" stroke=\"%s\" stroke-width=\"5\"/>"
				+ "<g fill=\"%s\"><circle cx=\"8\" cy=\"8\" r=\"2.4\"/><circle cx=\"56\" cy=\"8\" r=\"2.4\"/>"
				+ "<circle cx=\"8\" cy=\"56\" r=\"2.4\"/><circle cx=\"56\" cy=\"56\" r=\"2.4\"/></g>") \
				% [c.deep, c.base, c.light, c.dark, c.soft, c.deep,
					c.soft, c.deep, c.dark, c.pale]
		"ice":
			return ("<rect width=\"64\" height=\"64\" fill=\"%s\"/>"
				+ "<rect x=\"3\" y=\"3\" width=\"58\" height=\"58\" rx=\"9\" fill=\"%s\"/>"
				+ "<rect x=\"6\" y=\"6\" width=\"52\" height=\"24\" rx=\"7\" fill=\"%s\" opacity=\"0.55\"/>"
				+ "<path d=\"M12 50 L26 30 L34 40 L46 18\" fill=\"none\" stroke=\"%s\" stroke-width=\"2.2\" opacity=\"0.8\"/>"
				+ "<path d=\"M40 54 Q52 48 56 36\" fill=\"none\" stroke=\"%s\" stroke-width=\"2\" opacity=\"0.6\"/>"
				+ "<circle cx=\"14\" cy=\"13\" r=\"4\" fill=\"#ffffff\" opacity=\"0.8\"/>"
				+ "<circle cx=\"22\" cy=\"10\" r=\"2\" fill=\"#ffffff\" opacity=\"0.7\"/>") \
				% [c.deep, c.base, c.light, c.pale, c.pale]
		"barrel":
			return ("<ellipse cx=\"32\" cy=\"58\" rx=\"21\" ry=\"5\" fill=\"#000\" opacity=\"0.18\"/>"
				+ "<path d=\"M14 12 Q8 32 14 54 Q32 60 50 54 Q56 32 50 12 Q32 6 14 12 Z\" fill=\"%s\"/>"
				+ "<path d=\"M20 10 Q15 32 20 56 M32 8 Q30 32 32 58 M44 10 Q49 32 44 56\" fill=\"none\" stroke=\"%s\" stroke-width=\"2\" opacity=\"0.8\"/>"
				+ "<path d=\"M14 12 Q24 15 32 15 Q40 15 50 12\" fill=\"none\" stroke=\"%s\" stroke-width=\"1.8\" opacity=\"0.7\"/>"
				+ "<path d=\"M11 22 Q32 28 53 22 L53 28 Q32 34 11 28 Z\" fill=\"%s\" stroke=\"%s\" stroke-width=\"1.6\"/>"
				+ "<path d=\"M11 42 Q32 48 53 42 L53 48 Q32 54 11 48 Z\" fill=\"%s\" stroke=\"%s\" stroke-width=\"1.6\"/>"
				+ "<path d=\"M14 12 Q18 30 16 50\" fill=\"none\" stroke=\"%s\" stroke-width=\"3\" opacity=\"0.45\"/>") \
				% [c.base, c.dark, c.light, c.pale, c.deep,
					c.pale, c.deep, c.light]
		"gear":
			var teeth := ""
			for a: int in [0, 45, 90, 135]:
				teeth += ("<g transform=\"rotate(%d 32 33)\">"
					+ "<rect x=\"27\" y=\"7\" width=\"10\" height=\"52\" rx=\"4\" fill=\"%s\"/></g>") \
					% [a, c.base]
			return ("<ellipse cx=\"32\" cy=\"58\" rx=\"22\" ry=\"5\" fill=\"#000\" opacity=\"0.16\"/>"
				+ teeth
				+ "<circle cx=\"32\" cy=\"33\" r=\"19\" fill=\"%s\"/>"
				+ "<circle cx=\"32\" cy=\"33\" r=\"13\" fill=\"%s\"/>"
				+ "<path d=\"M21 24 Q26 18 34 17\" fill=\"none\" stroke=\"%s\" stroke-width=\"2.4\" opacity=\"0.8\"/>"
				+ "<circle cx=\"32\" cy=\"33\" r=\"5\" fill=\"%s\"/>"
				+ "<g fill=\"%s\"><circle cx=\"32\" cy=\"23\" r=\"2\"/><circle cx=\"42\" cy=\"33\" r=\"2\"/>"
				+ "<circle cx=\"32\" cy=\"43\" r=\"2\"/><circle cx=\"22\" cy=\"33\" r=\"2\"/></g>") \
				% [c.base, c.soft, c.pale, c.deep, c.dark]
		"mushroom":
			return ("<ellipse cx=\"32\" cy=\"58\" rx=\"18\" ry=\"4\" fill=\"#000\" opacity=\"0.16\"/>"
				+ "<path d=\"M25 36 Q24 52 26 57 Q32 60 38 57 Q40 52 39 36 Z\" fill=\"%s\"/>"
				+ "<path d=\"M36 38 Q38 50 37 57\" fill=\"none\" stroke=\"%s\" stroke-width=\"2\" opacity=\"0.5\"/>"
				+ "<path d=\"M8 34 Q8 8 32 8 Q56 8 56 34 Q44 40 32 40 Q20 40 8 34 Z\" fill=\"%s\"/>"
				+ "<path d=\"M8 34 Q20 40 32 40 Q44 40 56 34 Q44 36 32 36 Q20 36 8 34 Z\" fill=\"%s\"/>"
				+ "<g fill=\"%s\"><ellipse cx=\"20\" cy=\"20\" rx=\"5\" ry=\"4\"/>"
				+ "<ellipse cx=\"38\" cy=\"14\" rx=\"4\" ry=\"3\"/>"
				+ "<ellipse cx=\"46\" cy=\"26\" rx=\"4\" ry=\"3.4\"/>"
				+ "<ellipse cx=\"30\" cy=\"28\" rx=\"3\" ry=\"2.6\"/></g>"
				+ "<path d=\"M14 16 Q20 10 30 9\" fill=\"none\" stroke=\"%s\" stroke-width=\"2.4\" opacity=\"0.7\"/>") \
				% [c.pale, c.dark, c.base, c.deep, c.pale, c.light]
		"hexes":
			# Honeycomb: offset hexagon courses in deep mortar, each cell
			# lit from above.
			var hx := ""
			for row: Array in [[0, -2], [1, 14], [0, 30], [1, 46], [0, 62]]:
				for i in 4:
					var cx: int = i * 22 + (11 if row[0] == 1 else 0) - 4
					var cy: int = row[1]
					hx += ("<polygon points=\"%d,%d %d,%d %d,%d %d,%d %d,%d %d,%d\" fill=\"%s\"/>"
						+ "<polygon points=\"%d,%d %d,%d %d,%d\" fill=\"%s\" opacity=\"0.7\"/>") \
						% [cx, cy + 5, cx + 9, cy, cx + 18, cy + 5,
							cx + 18, cy + 13, cx + 9, cy + 18, cx, cy + 13, c.base,
							cx + 2, cy + 5, cx + 9, cy + 1, cx + 16, cy + 5, c.light]
			return "<rect width=\"64\" height=\"64\" fill=\"%s\"/>" % c.deep + hx
		"shingles":
			var sh := ""
			for row in 4:
				for i in 5:
					var sx: int = i * 16 + (8 if row % 2 == 1 else 0) - 8
					var sy: int = row * 16
					sh += ("<path d=\"M%d %d h16 v10 a8 6 0 0 1 -16 0 Z\" fill=\"%s\"/>"
						+ "<path d=\"M%d %d h16 v3 h-16 Z\" fill=\"%s\" opacity=\"0.65\"/>"
						+ "<path d=\"M%d %d a8 6 0 0 1 -16 0\" fill=\"none\" stroke=\"%s\" stroke-width=\"1.6\"/>") \
						% [sx, sy, c.base, sx, sy, c.light,
							sx + 16, sy + 10, c.deep]
			return "<rect width=\"64\" height=\"64\" fill=\"%s\"/>" % c.dark + sh
		"bamboo":
			var bb := ""
			for i in 4:
				var bx: int = i * 16 + 2
				bb += ("<rect x=\"%d\" y=\"0\" width=\"12\" height=\"64\" rx=\"5\" fill=\"%s\"/>"
					+ "<rect x=\"%d\" y=\"0\" width=\"3.5\" height=\"64\" rx=\"1.7\" fill=\"%s\" opacity=\"0.7\"/>"
					+ "<g fill=\"%s\"><rect x=\"%d\" y=\"%d\" width=\"12\" height=\"3\" rx=\"1.5\"/>"
					+ "<rect x=\"%d\" y=\"%d\" width=\"12\" height=\"3\" rx=\"1.5\"/></g>") \
					% [bx, c.base, bx + 1, c.light, c.deep,
						bx, 12 + ((i * 13) % 18), bx, 40 + ((i * 7) % 14)]
			return "<rect width=\"64\" height=\"64\" fill=\"%s\"/>" % c.deep + bb \
				+ "<path d=\"M8 6 Q16 2 22 8 Q14 10 8 6 Z\" fill=\"%s\" opacity=\"0.8\"/>" % c.pale
		"sandstone":
			return ("<rect width=\"64\" height=\"64\" fill=\"%s\"/>"
				+ "<g fill=\"%s\"><rect x=\"2\" y=\"2\" width=\"29\" height=\"29\" rx=\"5\"/>"
				+ "<rect x=\"33\" y=\"33\" width=\"29\" height=\"29\" rx=\"5\"/></g>"
				+ "<g fill=\"%s\"><rect x=\"33\" y=\"2\" width=\"29\" height=\"29\" rx=\"5\"/>"
				+ "<rect x=\"2\" y=\"33\" width=\"29\" height=\"29\" rx=\"5\"/></g>"
				+ "<g fill=\"%s\" opacity=\"0.75\"><rect x=\"2\" y=\"2\" width=\"29\" height=\"6\" rx=\"3\"/>"
				+ "<rect x=\"33\" y=\"2\" width=\"29\" height=\"6\" rx=\"3\"/></g>"
				+ "<g fill=\"%s\" opacity=\"0.6\"><circle cx=\"12\" cy=\"18\" r=\"1.2\"/>"
				+ "<circle cx=\"22\" cy=\"24\" r=\"1\"/><circle cx=\"44\" cy=\"12\" r=\"1.2\"/>"
				+ "<circle cx=\"52\" cy=\"22\" r=\"1\"/><circle cx=\"14\" cy=\"46\" r=\"1\"/>"
				+ "<circle cx=\"24\" cy=\"54\" r=\"1.2\"/><circle cx=\"46\" cy=\"44\" r=\"1\"/>"
				+ "<circle cx=\"54\" cy=\"54\" r=\"1.2\"/></g>") \
				% [c.deep, c.base, c.soft, c.light, c.dark]
		"circuit":
			return ("<rect width=\"64\" height=\"64\" fill=\"%s\"/>"
				+ "<g fill=\"none\" stroke=\"%s\" stroke-width=\"2.4\">"
				+ "<path d=\"M6 6 H26 V20\"/><path d=\"M58 10 H42 V24\"/>"
				+ "<path d=\"M6 58 H20 V44\"/><path d=\"M58 54 H46 V42\"/>"
				+ "<path d=\"M6 32 H16\"/><path d=\"M48 32 H58\"/></g>"
				+ "<rect x=\"22\" y=\"24\" width=\"20\" height=\"18\" rx=\"3\" fill=\"%s\"/>"
				+ "<rect x=\"25\" y=\"27\" width=\"14\" height=\"5\" rx=\"2\" fill=\"%s\" opacity=\"0.7\"/>"
				+ "<g fill=\"%s\"><circle cx=\"6\" cy=\"6\" r=\"3\"/><circle cx=\"58\" cy=\"10\" r=\"3\"/>"
				+ "<circle cx=\"6\" cy=\"58\" r=\"3\"/><circle cx=\"58\" cy=\"54\" r=\"3\"/>"
				+ "<circle cx=\"6\" cy=\"32\" r=\"2.4\"/><circle cx=\"58\" cy=\"32\" r=\"2.4\"/></g>") \
				% [c.deep, c.base, c.soft, c.light, c.pale]
		"weave":
			var wv := ""
			for i in 2:
				var o: int = i * 32
				wv += ("<rect x=\"%d\" y=\"0\" width=\"14\" height=\"64\" rx=\"3\" fill=\"%s\"/>"
					+ "<rect x=\"0\" y=\"%d\" width=\"64\" height=\"14\" rx=\"3\" fill=\"%s\"/>"
					+ "<rect x=\"%d\" y=\"%d\" width=\"14\" height=\"14\" fill=\"%s\"/>") \
					% [o + 8, c.soft, o + 8, c.base, 40 - o, o + 8, c.soft]
			return ("<rect width=\"64\" height=\"64\" fill=\"%s\"/>" % c.deep) + wv \
				+ ("<g fill=\"%s\" opacity=\"0.5\"><rect x=\"8\" y=\"0\" width=\"3\" height=\"64\"/>"
				+ "<rect x=\"40\" y=\"0\" width=\"3\" height=\"64\"/>"
				+ "<rect x=\"0\" y=\"8\" width=\"64\" height=\"3\"/>"
				+ "<rect x=\"0\" y=\"40\" width=\"64\" height=\"3\"/></g>") % c.light
		"stainedglass":
			return ("<rect width=\"64\" height=\"64\" fill=\"%s\"/>"
				+ "<g stroke=\"%s\" stroke-width=\"4\" fill=\"none\">"
				+ "<path d=\"M32 -6 L70 32 L32 70 L-6 32 Z\"/>"
				+ "<path d=\"M32 -6 V70 M-6 32 H70\"/></g>"
				+ "<g opacity=\"0.9\"><polygon points=\"32,2 62,32 32,32\" fill=\"%s\"/>"
				+ "<polygon points=\"32,2 2,32 32,32\" fill=\"%s\"/>"
				+ "<polygon points=\"32,62 2,32 32,32\" fill=\"%s\"/>"
				+ "<polygon points=\"32,62 62,32 32,32\" fill=\"%s\"/></g>"
				+ "<g stroke=\"%s\" stroke-width=\"3\" fill=\"none\" opacity=\"0.9\">"
				+ "<path d=\"M32 2 L2 32 L32 62 L62 32 Z\"/></g>"
				+ "<circle cx=\"22\" cy=\"18\" r=\"3\" fill=\"#ffffff\" opacity=\"0.55\"/>"
				+ "<circle cx=\"46\" cy=\"40\" r=\"2\" fill=\"#ffffff\" opacity=\"0.45\"/>") \
				% [c.base, c.deep, c.light, c.soft, c.base, c.dark, c.deep]
		"moai":
			# A full-tile carved ancestor: heavy brow, sunken sockets, the
			# long proud nose, thin lips — Easter Island as masonry.
			return ("<rect width=\"64\" height=\"64\" fill=\"%s\"/>"
				+ "<rect x=\"2\" y=\"2\" width=\"60\" height=\"60\" rx=\"7\" fill=\"%s\"/>"
				+ "<rect x=\"2\" y=\"2\" width=\"60\" height=\"12\" rx=\"6\" fill=\"%s\" opacity=\"0.6\"/>"
				+ "<path d=\"M6 22 Q18 16 30 21 L30 26 Q18 22 6 27 Z\" fill=\"%s\"/>"
				+ "<path d=\"M34 21 Q46 16 58 22 L58 27 Q46 22 34 26 Z\" fill=\"%s\"/>"
				+ "<g fill=\"%s\"><ellipse cx=\"17\" cy=\"30\" rx=\"6\" ry=\"3.4\"/>"
				+ "<ellipse cx=\"47\" cy=\"30\" rx=\"6\" ry=\"3.4\"/></g>"
				+ "<path d=\"M28 22 L26 42 Q26 46 32 46 Q38 46 38 42 L36 22 Z\" fill=\"%s\"/>"
				+ "<path d=\"M28 22 L26 42 Q26 45 29 46 Q28 34 30 22 Z\" fill=\"%s\" opacity=\"0.7\"/>"
				+ "<g fill=\"%s\"><ellipse cx=\"29\" cy=\"44\" rx=\"2\" ry=\"1.4\"/>"
				+ "<ellipse cx=\"35\" cy=\"44\" rx=\"2\" ry=\"1.4\"/></g>"
				+ "<rect x=\"20\" y=\"51\" width=\"24\" height=\"3.4\" rx=\"1.7\" fill=\"%s\"/>"
				+ "<path d=\"M10 58 Q32 62 54 58\" fill=\"none\" stroke=\"%s\" stroke-width=\"2.4\" opacity=\"0.6\"/>") \
				% [c.deep, c.base, c.light, c.dark, c.dark, c.deep,
					c.soft, c.light, c.deep, c.dark, c.shade]
		"scales":
			var sc := ""
			for row in 4:
				for i in 5:
					var px: int = i * 16 + (8 if row % 2 == 1 else 0) - 8
					var py: int = row * 15
					sc += ("<path d=\"M%d %d q8 -6 16 0 q-2 14 -8 18 q-6 -4 -8 -18 Z\" fill=\"%s\" stroke=\"%s\" stroke-width=\"1.4\"/>"
						+ "<path d=\"M%d %d q8 -6 16 0 q-1 4 -2 6 q-6 -5 -12 0 q-1 -2 -2 -6 Z\" fill=\"%s\" opacity=\"0.7\"/>") \
						% [px, py + 4, c.base, c.deep, px, py + 4, c.light]
			return "<rect width=\"64\" height=\"64\" fill=\"%s\"/>" % c.dark + sc
		"lattice":
			return ("<rect width=\"64\" height=\"64\" fill=\"%s\"/>"
				+ "<g stroke=\"%s\" stroke-width=\"7\">"
				+ "<path d=\"M-8 24 L40 -8 M-8 56 L72 2 M8 72 L72 30 M40 72 L72 52\"/></g>"
				+ "<g stroke=\"%s\" stroke-width=\"7\">"
				+ "<path d=\"M24 -8 L72 24 M-8 8 L72 62 M-8 40 L28 66\"/></g>"
				+ "<g stroke=\"%s\" stroke-width=\"2\" opacity=\"0.6\">"
				+ "<path d=\"M24 -8 L72 24 M-8 8 L72 62 M-8 40 L28 66\"/></g>"
				+ "<g fill=\"%s\"><circle cx=\"16\" cy=\"16\" r=\"2\"/><circle cx=\"48\" cy=\"44\" r=\"2\"/>"
				+ "<circle cx=\"48\" cy=\"12\" r=\"2\"/><circle cx=\"14\" cy=\"46\" r=\"2\"/></g>") \
				% [c.pale, c.dark, c.base, c.light, c.deep]
		"gem":
			return ("<ellipse cx=\"32\" cy=\"57\" rx=\"20\" ry=\"5\" fill=\"#000\" opacity=\"0.18\"/>"
				+ "<polygon points=\"20,12 44,12 56,28 32,58 8,28\" fill=\"%s\"/>"
				+ "<polygon points=\"20,12 44,12 38,28 26,28\" fill=\"%s\"/>"
				+ "<polygon points=\"44,12 56,28 38,28\" fill=\"%s\"/>"
				+ "<polygon points=\"20,12 8,28 26,28\" fill=\"%s\"/>"
				+ "<polygon points=\"26,28 38,28 32,58\" fill=\"%s\" opacity=\"0.85\"/>"
				+ "<polygon points=\"8,28 26,28 32,58\" fill=\"%s\"/>"
				+ "<circle cx=\"27\" cy=\"18\" r=\"2.4\" fill=\"#ffffff\" opacity=\"0.9\"/>"
				+ "<circle cx=\"48\" cy=\"26\" r=\"1.6\" fill=\"#ffffff\" opacity=\"0.7\"/>") \
				% [c.base, c.light, c.soft, c.pale, c.soft, c.dark]
		"pumpkin":
			return ("<ellipse cx=\"32\" cy=\"57\" rx=\"22\" ry=\"5\" fill=\"#000\" opacity=\"0.16\"/>"
				+ "<rect x=\"29\" y=\"8\" width=\"7\" height=\"12\" rx=\"3\" fill=\"%s\"/>"
				+ "<path d=\"M36 12 Q46 8 50 14 Q42 16 36 14 Z\" fill=\"%s\" opacity=\"0.85\"/>"
				+ "<ellipse cx=\"32\" cy=\"38\" rx=\"26\" ry=\"20\" fill=\"%s\"/>"
				+ "<ellipse cx=\"32\" cy=\"38\" rx=\"10\" ry=\"20\" fill=\"%s\" opacity=\"0.55\"/>"
				+ "<g fill=\"none\" stroke=\"%s\" stroke-width=\"2\" opacity=\"0.7\">"
				+ "<path d=\"M18 22 Q12 38 18 54\"/><path d=\"M46 22 Q52 38 46 54\"/>"
				+ "<path d=\"M25 19 Q21 38 25 56\"/><path d=\"M39 19 Q43 38 39 56\"/></g>"
				+ "<path d=\"M16 26 Q24 20 32 20\" fill=\"none\" stroke=\"%s\" stroke-width=\"3\" opacity=\"0.7\"/>") \
				% [c.deep, c.dark, c.base, c.soft, c.dark, c.light]
		"shell":
			# A proper scallop (v9.6): ribbed fan spreading UP from the
			# hinge, a bumpy scalloped crown, and the little hinge ears.
			var tips := [[8, 34], [15, 19], [26, 11], [38, 11], [49, 19], [56, 34]]
			var petals := ""
			for i in 5:
				var a: Array = tips[i]
				var b: Array = tips[i + 1]
				var mx: float = (a[0] + b[0]) * 0.5
				var my: float = (a[1] + b[1]) * 0.5
				# Push the crown arc outward from the hinge (32,52).
				var ox := 32.0 + (mx - 32.0) * 1.28
				var oy := 52.0 + (my - 52.0) * 1.24
				petals += ("<path d=\"M32 52 L%d %d Q%.0f %.0f %d %d Z\" fill=\"%s\"/>"
					+ "<path d=\"M%d %d Q%.0f %.0f %d %d\" fill=\"none\" stroke=\"%s\" stroke-width=\"2\" opacity=\"0.85\"/>") \
					% [a[0], a[1], ox, oy, b[0], b[1],
						c.soft if i % 2 == 0 else c.base,
						a[0], a[1], ox, oy, b[0], b[1], c.light]
			var ribs := ""
			for t: Array in tips:
				ribs += "<path d=\"M32 52 L%d %d\" stroke=\"%s\" stroke-width=\"1.6\" opacity=\"0.6\" fill=\"none\"/>" \
					% [t[0], t[1], c.dark]
			return ("<ellipse cx=\"32\" cy=\"57\" rx=\"18\" ry=\"4\" fill=\"#000\" opacity=\"0.15\"/>"
				+ petals + ribs
				+ "<path d=\"M22 50 L42 50 L38 58 Q32 61 26 58 Z\" fill=\"%s\"/>" % c.base
				+ ("<g fill=\"%s\"><rect x=\"16\" y=\"46\" width=\"7\" height=\"6\" rx=\"2\"/>"
					+ "<rect x=\"41\" y=\"46\" width=\"7\" height=\"6\" rx=\"2\"/></g>") % c.deep
				+ "<path d=\"M26 58 Q32 61 38 58\" fill=\"none\" stroke=\"%s\" stroke-width=\"1.8\"/>" % c.deep)
		"cactus":
			return ("<ellipse cx=\"32\" cy=\"58\" rx=\"18\" ry=\"4\" fill=\"#000\" opacity=\"0.16\"/>"
				+ "<path d=\"M26 58 V22 Q26 12 32 12 Q38 12 38 22 V58 Z\" fill=\"%s\"/>"
				+ "<path d=\"M12 24 Q10 34 18 36 L18 44 Q18 48 26 46 L26 38 Q16 38 18 26 Z\" fill=\"%s\"/>"
				+ "<path d=\"M52 18 Q56 28 46 32 L46 40 Q46 44 38 42 L38 34 Q50 34 46 22 Z\" fill=\"%s\"/>"
				+ "<path d=\"M29 14 V56\" stroke=\"%s\" stroke-width=\"2\" opacity=\"0.6\" fill=\"none\"/>"
				+ "<g fill=\"%s\"><circle cx=\"26\" cy=\"20\" r=\"1\"/><circle cx=\"38\" cy=\"28\" r=\"1\"/>"
				+ "<circle cx=\"26\" cy=\"44\" r=\"1\"/><circle cx=\"38\" cy=\"50\" r=\"1\"/>"
				+ "<circle cx=\"15\" cy=\"30\" r=\"1\"/><circle cx=\"50\" cy=\"24\" r=\"1\"/></g>"
				+ "<circle cx=\"32\" cy=\"11\" r=\"3.4\" fill=\"%s\"/>"
				+ "<circle cx=\"32\" cy=\"11\" r=\"1.4\" fill=\"#ffffff\" opacity=\"0.8\"/>") \
				% [c.base, c.dark, c.dark, c.deep, c.pale, c.light]
		"lantern":
			return ("<ellipse cx=\"32\" cy=\"58\" rx=\"14\" ry=\"3.6\" fill=\"#000\" opacity=\"0.16\"/>"
				+ "<path d=\"M32 2 V8\" stroke=\"%s\" stroke-width=\"2.4\"/>"
				+ "<rect x=\"22\" y=\"7\" width=\"20\" height=\"5\" rx=\"2.4\" fill=\"%s\"/>"
				+ "<path d=\"M18 30 Q18 12 32 12 Q46 12 46 30 Q46 48 32 48 Q18 48 18 30 Z\" fill=\"%s\"/>"
				+ "<path d=\"M22 28 Q22 16 32 15 Q28 24 28 30 Q28 40 32 45 Q22 42 22 28 Z\" fill=\"%s\" opacity=\"0.8\"/>"
				+ "<g fill=\"none\" stroke=\"%s\" stroke-width=\"1.8\" opacity=\"0.65\">"
				+ "<path d=\"M18 24 Q32 20 46 24\"/><path d=\"M18 36 Q32 40 46 36\"/></g>"
				+ "<rect x=\"24\" y=\"46\" width=\"16\" height=\"5\" rx=\"2.4\" fill=\"%s\"/>"
				+ "<path d=\"M32 51 V56\" stroke=\"%s\" stroke-width=\"2\"/>"
				+ "<circle cx=\"32\" cy=\"58\" r=\"2.6\" fill=\"%s\"/>") \
				% [c.deep, c.dark, c.light, c.pale, c.base, c.dark,
					c.deep, c.base]
		"statue":
			return ("<ellipse cx=\"32\" cy=\"58\" rx=\"18\" ry=\"4.4\" fill=\"#000\" opacity=\"0.2\"/>"
				+ "<path d=\"M18 58 L16 22 Q16 8 32 8 Q48 8 48 22 L46 58 Z\" fill=\"%s\"/>"
				+ "<path d=\"M18 58 L16 22 Q16 10 26 8 Q22 30 24 58 Z\" fill=\"%s\"/>"
				+ "<path d=\"M14 26 Q22 22 30 26 M34 26 Q42 22 50 26\" fill=\"none\" stroke=\"%s\" stroke-width=\"4\"/>"
				+ "<path d=\"M30 26 Q28 40 30 44 Q32 47 36 44\" fill=\"none\" stroke=\"%s\" stroke-width=\"3.4\"/>"
				+ "<g fill=\"%s\"><ellipse cx=\"22\" cy=\"31\" rx=\"3.4\" ry=\"2.4\"/>"
				+ "<ellipse cx=\"42\" cy=\"31\" rx=\"3.4\" ry=\"2.4\"/></g>"
				+ "<path d=\"M26 52 Q32 55 38 52\" fill=\"none\" stroke=\"%s\" stroke-width=\"2.6\"/>") \
				% [c.base, c.light, c.dark, c.dark, c.deep, c.deep]
		"egg":
			return ("<ellipse cx=\"32\" cy=\"57\" rx=\"19\" ry=\"4.6\" fill=\"#000\" opacity=\"0.16\"/>"
				+ "<path d=\"M12 56 Q20 50 32 50 Q44 50 52 56 Q44 61 32 61 Q20 61 12 56 Z\" fill=\"%s\"/>"
				+ "<path d=\"M32 6 Q48 22 48 38 Q48 54 32 54 Q16 54 16 38 Q16 22 32 6 Z\" fill=\"%s\"/>"
				+ "<path d=\"M32 6 Q22 22 21 38 Q21 50 28 53 Q16 50 16 38 Q16 22 32 6 Z\" fill=\"%s\" opacity=\"0.75\"/>"
				+ "<g fill=\"%s\"><ellipse cx=\"36\" cy=\"22\" rx=\"3\" ry=\"4\"/>"
				+ "<ellipse cx=\"42\" cy=\"36\" rx=\"2.4\" ry=\"3.2\"/>"
				+ "<ellipse cx=\"28\" cy=\"40\" rx=\"2.6\" ry=\"3.4\"/>"
				+ "<ellipse cx=\"36\" cy=\"46\" rx=\"2\" ry=\"2.6\"/></g>"
				+ "<circle cx=\"27\" cy=\"18\" r=\"2\" fill=\"#ffffff\" opacity=\"0.7\"/>") \
				% [c.deep, c.base, c.light, c.dark]
		"chest":
			return ("<ellipse cx=\"32\" cy=\"58\" rx=\"22\" ry=\"4.6\" fill=\"#000\" opacity=\"0.18\"/>"
				+ "<path d=\"M10 28 Q10 12 32 12 Q54 12 54 28 L54 32 L10 32 Z\" fill=\"%s\"/>"
				+ "<path d=\"M10 28 Q10 14 24 12 Q18 20 18 32 L10 32 Z\" fill=\"%s\" opacity=\"0.8\"/>"
				+ "<rect x=\"10\" y=\"32\" width=\"44\" height=\"24\" rx=\"3\" fill=\"%s\"/>"
				+ "<rect x=\"10\" y=\"32\" width=\"44\" height=\"5\" fill=\"%s\" opacity=\"0.6\"/>"
				+ "<g fill=\"%s\"><rect x=\"16\" y=\"12\" width=\"6\" height=\"44\" rx=\"2\"/>"
				+ "<rect x=\"42\" y=\"12\" width=\"6\" height=\"44\" rx=\"2\"/></g>"
				+ "<rect x=\"27\" y=\"27\" width=\"10\" height=\"13\" rx=\"3\" fill=\"%s\"/>"
				+ "<circle cx=\"32\" cy=\"32\" r=\"2\" fill=\"%s\"/>"
				+ "<path d=\"M32 32 L32 36\" stroke=\"%s\" stroke-width=\"2\"/>") \
				% [c.base, c.light, c.dark, c.soft, c.pale, c.light,
					c.deep, c.deep]
	return "<rect width=\"64\" height=\"64\" fill=\"#ff00ff\"/>"


static var _BODIES := {
	# ================= CLASSIC VARIANTS =================
	"classic_colourful/wall": _bevel("#4a80d8", "#8fb6f0", "#2b4f96", "#5b8ee0", "#3a6cc0"),
	"classic_colourful/brick": _bricks("#ffe9c9", "#e84545", "#b82e2e", "#fff4e0", "#8a2020"),
	"classic_dark/wall": _bevel("#4a4e58", "#6a6f7c", "#2b2e36", "#52565f", "#3e424c"),
	"classic_dark/brick": _bricks("#4a3a34", "#8a4030", "#5f2c20", "#5a4840", "#3a1c14"),

	# ================= ACCESSIBILITY ====================
	# Eye relief (reworked v4.9): DARK muted greens — the whole board
	# sits in the calm middle of the value range, nothing glares.
	"eye_relief/wall": _bevel("#3d5142", "#4d6353", "#2c3c31", "#445a4a", "#35473a"),
	"eye_relief/brick": _bricks("#556a4e", "#6b7f5c", "#47593f", "#63775a", "#3b4c36"),
	"ultra_contrast/wall": """<rect width="64" height="64" fill="#000000"/>
<rect x="5" y="5" width="54" height="54" fill="none" stroke="#ffffff" stroke-width="4"/>
<rect x="26" y="26" width="12" height="12" fill="#ffffff"/>""",
	"ultra_contrast/brick": """<rect width="64" height="64" fill="#ffd400"/>
<g fill="#000000">
<path d="M0 0 L16 0 L0 16 Z"/><path d="M32 0 L48 0 L0 48 L0 32 Z"/>
<path d="M64 0 L64 16 L16 64 L0 64 Z"/><path d="M64 32 L64 48 L48 64 L32 64 Z"/>
</g>
<rect x="2" y="2" width="60" height="60" fill="none" stroke="#000000" stroke-width="4"/>""",

	# ================= WORLD TOUR (v4.8) ================
	"marble/wall": """<rect width="64" height="64" fill="#e8e6e0"/>
<path d="M0 0 H64 L56 8 H8 L8 56 L0 64 Z" fill="#f8f7f3"/>
<path d="M64 0 V64 H0 L8 56 H56 V8 Z" fill="#b8b4aa"/>
<rect x="8" y="8" width="48" height="48" fill="#e3e0d8"/>
<g fill="none" stroke="#b0aca0" stroke-width="1.6" opacity="0.6">
<path d="M12 44 Q24 30 20 12"/><path d="M30 56 Q42 40 52 34"/><path d="M40 10 Q36 22 48 26"/>
</g>""",
	"marble/brick": """<rect width="64" height="64" fill="#e9d5cc"/>
<path d="M0 0 H64 V4 H4 V64 H0 Z" fill="#f6e9e3"/>
<path d="M64 0 V64 H0 L4 60 H60 V4 Z" fill="#c0a396"/>
<g fill="none" stroke="#c9ab9e" stroke-width="1.6" opacity="0.7">
<path d="M8 20 Q22 26 28 14"/><path d="M50 8 Q44 28 56 36"/><path d="M14 52 Q30 44 26 58"/>
</g>
<path d="M34 2 L30 22 L38 34 L33 50" fill="none" stroke="#a8887a" stroke-width="2" opacity="0.8"/>""",
	"space_station/wall": """<rect width="64" height="64" fill="#566074"/>
<path d="M0 0 H64 L58 6 H6 L6 58 L0 64 Z" fill="#7c88a0"/>
<path d="M64 0 V64 H0 L6 58 H58 V6 Z" fill="#343b4a"/>
<rect x="10" y="10" width="44" height="44" fill="#4a5366" rx="3"/>
<g fill="#9aa4b8">
<circle cx="15" cy="15" r="2.5"/><circle cx="49" cy="15" r="2.5"/>
<circle cx="15" cy="49" r="2.5"/><circle cx="49" cy="49" r="2.5"/>
</g>
<rect x="14" y="28" width="36" height="8" fill="#3c4454" rx="2"/>
<rect x="17" y="31" width="12" height="2" fill="#57e6ff"/>
<rect x="35" y="31" width="4" height="2" fill="#57e6ff" opacity="0.6"/>""",
	"space_station/brick": """<rect x="2" y="2" width="60" height="60" fill="#c87a2e" rx="4"/>
<path d="M2 2 H62 L56 8 H8 L8 56 L2 62 Z" fill="#e09a4a"/>
<path d="M62 2 V62 H2 L8 56 H56 V8 Z" fill="#8a5220"/>
<path d="M8 46 h48 v10 h-48 Z" fill="#2a2a2a" opacity="0.85"/>
<g fill="#ffd400">
<path d="M10 56 L20 46 L26 46 L16 56 Z"/><path d="M28 56 L38 46 L44 46 L34 56 Z"/><path d="M46 56 L56 46 L56 52 L52 56 Z"/>
</g>
<rect x="22" y="14" width="20" height="6" fill="#8a5220" rx="3"/>
<rect x="12" y="26" width="40" height="3" fill="#a86428" opacity="0.8"/>""",
	"woods/wall": """<rect width="64" height="64" fill="#3b5531"/>
<ellipse cx="32" cy="36" rx="27" ry="24" fill="#6f7a68"/>
<path d="M10 28 Q20 8 40 12 Q58 16 56 34 Q50 22 34 20 Q16 20 10 28 Z" fill="#8f9a85"/>
<ellipse cx="32" cy="56" rx="26" ry="7" fill="#2c4023" opacity="0.7"/>
<g fill="#5d7a4a">
<circle cx="16" cy="40" r="6"/><circle cx="24" cy="48" r="5"/><circle cx="46" cy="24" r="5"/><circle cx="50" cy="44" r="4"/>
</g>
<g fill="#77985e" opacity="0.8">
<circle cx="14" cy="37" r="3"/><circle cx="44" cy="21" r="2.5"/><circle cx="48" cy="41" r="2"/>
</g>""",
	"woods/brick": """<g>
<circle cx="12" cy="47" r="12" fill="#7a5230"/><circle cx="12" cy="47" r="8.5" fill="#c89a68"/><circle cx="12" cy="47" r="5" fill="#b0804e" opacity="0.7"/><circle cx="12" cy="47" r="2" fill="#8a5f36"/>
<circle cx="34" cy="49" r="12" fill="#6f4a2a"/><circle cx="34" cy="49" r="8.5" fill="#c0925f"/><circle cx="34" cy="49" r="5" fill="#a87848" opacity="0.7"/><circle cx="34" cy="49" r="2" fill="#82582f"/>
<circle cx="55" cy="47" r="11" fill="#7a5230"/><circle cx="55" cy="47" r="8" fill="#cb9e6c"/><circle cx="55" cy="47" r="4.5" fill="#b0804e" opacity="0.7"/><circle cx="55" cy="47" r="1.8" fill="#8a5f36"/>
<circle cx="23" cy="27" r="12" fill="#82582f"/><circle cx="23" cy="27" r="8.5" fill="#d2a877"/><circle cx="23" cy="27" r="5" fill="#ba8a58" opacity="0.7"/><circle cx="23" cy="27" r="2" fill="#94663c"/>
<circle cx="45" cy="26" r="12" fill="#75502c"/><circle cx="45" cy="26" r="8.5" fill="#c89a68"/><circle cx="45" cy="26" r="5" fill="#ae7e4c" opacity="0.7"/><circle cx="45" cy="26" r="2" fill="#8a5f36"/>
</g>""",
	"forest/wall": """<rect width="64" height="64" fill="#24401e"/>
<rect x="26" y="40" width="12" height="24" fill="#4a3826"/>
<rect x="29" y="40" width="3" height="24" fill="#5f4a33"/>
<g fill="#2e5c2e">
<circle cx="16" cy="30" r="15"/><circle cx="46" cy="28" r="16"/><circle cx="32" cy="16" r="14"/>
</g>
<g fill="#3a7038">
<circle cx="14" cy="24" r="9"/><circle cx="42" cy="20" r="10"/><circle cx="30" cy="10" r="8"/><circle cx="54" cy="34" r="8"/>
</g>
<g fill="#4c8a45" opacity="0.9">
<circle cx="24" cy="14" r="5"/><circle cx="48" cy="16" r="4"/><circle cx="10" cy="20" r="4"/>
</g>""",
	"forest/brick": """<g fill="none" stroke="#3f8a3f" stroke-width="3">
<path d="M32 58 Q30 38 14 26"/><path d="M32 58 Q34 36 50 24"/><path d="M32 58 Q32 34 32 14"/>
</g>
<g fill="#4c9a44">
<ellipse cx="16" cy="27" rx="7" ry="4"/><ellipse cx="22" cy="35" rx="7" ry="4"/><ellipse cx="27" cy="44" rx="6" ry="4"/>
<ellipse cx="48" cy="26" rx="7" ry="4"/><ellipse cx="42" cy="34" rx="7" ry="4"/><ellipse cx="38" cy="43" rx="6" ry="4"/>
<ellipse cx="32" cy="16" rx="4" ry="7"/><ellipse cx="28" cy="26" rx="4" ry="6"/><ellipse cx="36" cy="27" rx="4" ry="6"/>
</g>
<g fill="#63b45a" opacity="0.85">
<ellipse cx="14" cy="24" rx="4" ry="2.5"/><ellipse cx="50" cy="23" rx="4" ry="2.5"/><ellipse cx="32" cy="12" rx="2.5" ry="4"/>
</g>""",
	"hedge/wall": """<rect x="0" y="8" width="64" height="56" fill="#1d4a1f"/>
<rect x="0" y="0" width="64" height="12" fill="#2c632e"/>
<rect x="0" y="10" width="64" height="3" fill="#153a17"/>
<g fill="#245526">
<circle cx="8" cy="24" r="5"/><circle cx="22" cy="30" r="6"/><circle cx="40" cy="24" r="5"/><circle cx="55" cy="30" r="5"/>
<circle cx="14" cy="44" r="6"/><circle cx="32" cy="48" r="6"/><circle cx="50" cy="44" r="5"/>
</g>
<g fill="#153a17">
<circle cx="16" cy="34" r="4"/><circle cx="34" cy="38" r="4"/><circle cx="52" cy="52" r="5"/><circle cx="8" cy="56" r="5"/>
</g>
<g fill="#387a3a" opacity="0.9">
<circle cx="10" cy="4" r="3"/><circle cx="26" cy="6" r="3.5"/><circle cx="44" cy="4" r="3"/><circle cx="58" cy="6" r="3"/>
</g>
<rect x="0" y="58" width="64" height="6" fill="#102e12"/>""",
	"hedge/brick": _bush("#3f8a3f", "#4fa04f", "#2e6b2e",
		"""<g fill="#63b463" opacity="0.9">
<circle cx="26" cy="16" r="4"/><circle cx="14" cy="34" r="4"/><circle cx="46" cy="34" r="4"/>
</g>"""),
	"garden/wall": """<rect x="2" y="20" width="60" height="42" fill="#e8e4da" rx="4"/>
<path d="M2 22 H62 L56 28 H8 L8 56 L2 62 Z" fill="#f6f3ec"/>
<path d="M62 22 V62 H2 L8 56 H56 V28 Z" fill="#bdb7a8"/>
<rect x="8" y="26" width="48" height="8" fill="#5a4230"/>
<g fill="none" stroke="#4c8a3c" stroke-width="2.5">
<path d="M16 26 Q15 16 12 12"/><path d="M32 26 Q32 14 32 9"/><path d="M48 26 Q49 16 52 12"/>
</g>
<circle cx="12" cy="10" r="6" fill="#e86ca0"/><circle cx="12" cy="10" r="2.4" fill="#ffd0e4"/>
<circle cx="32" cy="7" r="6" fill="#f0d048"/><circle cx="32" cy="7" r="2.4" fill="#fff0b0"/>
<circle cx="52" cy="10" r="6" fill="#e85454"/><circle cx="52" cy="10" r="2.4" fill="#ffc0b0"/>
<rect x="14" y="40" width="36" height="3" fill="#d5cfc2"/>""",
	"garden/brick": """<g fill="#4c9a44">
<circle cx="24" cy="42" r="13"/><circle cx="44" cy="42" r="12"/><circle cx="33" cy="27" r="12"/>
</g>
<g fill="#5cae52">
<circle cx="20" cy="35" r="8"/><circle cx="42" cy="34" r="7"/><circle cx="31" cy="20" r="7"/>
</g>
<circle cx="18" cy="44" r="5" fill="#ff88b8"/><circle cx="18" cy="44" r="2" fill="#fff0f6"/>
<circle cx="36" cy="49" r="5" fill="#ffd058"/><circle cx="36" cy="49" r="2" fill="#fff8dc"/>
<circle cx="48" cy="38" r="5" fill="#ff6868"/><circle cx="48" cy="38" r="2" fill="#ffe0d8"/>
<circle cx="30" cy="30" r="4.5" fill="#b088e8"/><circle cx="30" cy="30" r="1.8" fill="#f0e4ff"/>
<circle cx="42" cy="22" r="4" fill="#ff88b8"/><circle cx="42" cy="22" r="1.6" fill="#fff0f6"/>""",
	"mine/wall": """<rect width="64" height="64" fill="#3a342e"/>
<path d="M0 0 L30 6 L64 0 L58 30 L64 64 L34 58 L0 64 L6 32 Z" fill="#4c453c"/>
<path d="M12 14 L30 10 L26 26 L10 28 Z" fill="#575044"/>
<path d="M38 34 L54 30 L52 48 L36 50 Z" fill="#575044"/>
<path d="M14 40 L26 38 L24 52 L12 52 Z" fill="#2c2620"/>
<g fill="#f0c040">
<circle cx="20" cy="20" r="2.2"/><circle cx="45" cy="40" r="2.6"/><circle cx="49" cy="14" r="1.8"/><circle cx="16" cy="47" r="1.8"/><circle cx="33" cy="30" r="1.4"/>
</g>
<g fill="#ffe080" opacity="0.9">
<circle cx="19" cy="19" r="0.9"/><circle cx="44" cy="39" r="1"/><circle cx="48" cy="13" r="0.7"/>
</g>""",
	"mine/brick": """<rect x="4" y="8" width="56" height="52" fill="#55483a"/>
<path d="M4 8 H60 L56 14 H8 L8 56 L4 60 Z" fill="#665748"/>
<g fill="#8a6438">
<rect x="6" y="6" width="10" height="56"/><rect x="48" y="6" width="10" height="56"/>
<rect x="2" y="4" width="60" height="10"/>
</g>
<g fill="#a87c48">
<rect x="8" y="6" width="2.5" height="56"/><rect x="50" y="6" width="2.5" height="56"/><rect x="2" y="6" width="60" height="2.5"/>
</g>
<g fill="#6b4c28">
<rect x="12" y="6" width="2" height="56"/><rect x="54" y="6" width="2" height="56"/><rect x="2" y="10" width="60" height="2"/>
</g>
<circle cx="24" cy="34" r="3" fill="#3c332a"/><circle cx="38" cy="46" r="3.5" fill="#3c332a"/><circle cx="34" cy="26" r="2.5" fill="#3c332a"/>""",
	"desert/wall": """<rect width="64" height="64" fill="#d8b070"/>
<path d="M0 0 H64 L56 8 H8 L8 56 L0 64 Z" fill="#eccf96"/>
<path d="M64 0 V64 H0 L8 56 H56 V8 Z" fill="#a87c44"/>
<g fill="#c9a262">
<rect x="8" y="18" width="48" height="4"/><rect x="8" y="32" width="48" height="4"/><rect x="8" y="46" width="48" height="4"/>
</g>
<g fill="#b8905a" opacity="0.8">
<circle cx="18" cy="26" r="2"/><circle cx="44" cy="40" r="2.4"/><circle cx="30" cy="52" r="1.8"/><circle cx="50" cy="13" r="1.6"/>
</g>""",
	"desert/brick": """<rect x="2" y="2" width="60" height="60" fill="#c89058" rx="6"/>
<path d="M2 4 Q32 0 62 4 L58 10 Q32 6 6 10 Z" fill="#dca868"/>
<path d="M62 60 Q32 64 2 60 L6 54 Q32 58 58 54 Z" fill="#a06c38"/>
<g fill="none" stroke="#8a5c2c" stroke-width="2">
<path d="M14 10 L20 26 L12 40 L18 56"/><path d="M46 8 L40 22 L50 34 L44 50"/><path d="M20 26 L38 30"/>
</g>
<g fill="#e8cc90">
<rect x="26" y="16" width="5" height="1.6" rx="0.8"/><rect x="34" y="42" width="5" height="1.6" rx="0.8"/><rect x="18" y="48" width="4" height="1.4" rx="0.7"/><rect x="48" y="20" width="4" height="1.4" rx="0.7"/>
</g>""",
	"mountain/wall": """<rect width="64" height="64" fill="#7c8288"/>
<path d="M0 0 H64 L56 8 H8 L8 56 L0 64 Z" fill="#94999e"/>
<path d="M64 0 V64 H0 L8 56 H56 V8 Z" fill="#5f646a"/>
<path d="M8 8 L24 22 L38 12 L56 26 L56 8 Z" fill="#f0f4f8"/>
<path d="M8 8 L24 22 L18 26 L8 20 Z" fill="#dbe3ea"/>
<path d="M20 34 L34 30 L30 46 L16 48 Z" fill="#8b9096"/>
<path d="M38 36 L52 32 L50 50 L36 52 Z" fill="#6d7278"/>""",
	"mountain/brick": """<g>
<ellipse cx="32" cy="56" rx="26" ry="7" fill="#565d54" opacity="0.5"/>
<rect x="6" y="42" width="52" height="16" fill="#83898f" rx="7"/>
<rect x="6" y="42" width="52" height="5" fill="#9aa0a6" rx="2.5"/>
<rect x="12" y="28" width="40" height="16" fill="#6d7379" rx="7"/>
<rect x="12" y="28" width="40" height="5" fill="#83898f" rx="2.5"/>
<rect x="20" y="15" width="24" height="15" fill="#8f959b" rx="7"/>
<rect x="20" y="15" width="24" height="5" fill="#a6acb2" rx="2.5"/>
<circle cx="32" cy="9" r="6" fill="#7a8086"/><path d="M27 7 A6 6 0 0 1 37 7 L36 10 L28 10 Z" fill="#94999e"/>
</g>""",
	"volcano/wall": """<rect width="64" height="64" fill="#26221f"/>
<g fill="#332e2a">
<rect x="4" y="2" width="16" height="60"/><rect x="24" y="2" width="16" height="60"/><rect x="44" y="2" width="16" height="60"/>
</g>
<g fill="#3d3833">
<rect x="4" y="2" width="16" height="8"/><rect x="24" y="2" width="16" height="8"/><rect x="44" y="2" width="16" height="8"/>
</g>
<g fill="none" stroke="#ff7a20" stroke-width="1.8" opacity="0.9">
<path d="M20 10 L22 26 L20 44 L22 60"/><path d="M42 4 L40 20 L43 38 L41 56"/>
</g>
<path d="M20 24 L22 30" stroke="#ffc040" stroke-width="2.4" fill="none"/>
<path d="M41 36 L43 42" stroke="#ffc040" stroke-width="2.4" fill="none"/>""",
	"volcano/brick": """<rect x="2" y="2" width="60" height="60" fill="#352b24" rx="3"/>
<g fill="#443830">
<path d="M4 4 L28 6 L24 26 L6 28 Z"/><path d="M34 4 L60 6 L58 24 L32 24 Z"/>
<path d="M6 34 L26 32 L30 58 L6 58 Z"/><path d="M36 30 L58 30 L58 58 L38 56 Z"/>
</g>
<g fill="#544438">
<path d="M6 6 L26 8 L23 14 L8 14 Z"/><path d="M36 6 L58 8 L56 13 L34 12 Z"/>
</g>
<g fill="none" stroke="#ff6a10" stroke-width="2.6" opacity="0.95">
<path d="M30 4 L28 16 L33 28 L28 40 L31 58"/>
<path d="M4 30 L16 29 L33 28 L46 32 L60 29"/>
</g>
<g fill="none" stroke="#ffb030" stroke-width="1.2">
<path d="M29 12 L31 22"/><path d="M20 29 L30 28"/><path d="M33 28 L42 31"/>
</g>
<circle cx="33" cy="28" r="2.6" fill="#ffd060"/>
<g fill="#ff8830" opacity="0.8">
<circle cx="12" cy="46" r="1.3"/><circle cx="50" cy="14" r="1.3"/><circle cx="48" cy="48" r="1.5"/>
</g>""",

	# ================= BEAUTIFUL 15 (v4.9) ==============
	# ocean: analogous teals, complementary coral-sand brick.
	"ocean/wall": """<rect width="64" height="64" fill="#14324c"/>
<path d="M0 0 H64 L58 6 H6 L6 58 L0 64 Z" fill="#1d4668"/>
<path d="M64 0 V64 H0 L6 58 H58 V6 Z" fill="#0c2236"/>
<g fill="none" stroke="#2c6284" stroke-width="2.5">
<path d="M8 20 Q16 14 24 20 Q32 26 40 20 Q48 14 56 20"/>
<path d="M8 34 Q16 28 24 34 Q32 40 40 34 Q48 28 56 34"/>
<path d="M8 48 Q16 42 24 48 Q32 54 40 48 Q48 42 56 48"/>
</g>
<g fill="#7ac4d8" opacity="0.7">
<circle cx="24" cy="19" r="1.4"/><circle cx="40" cy="33" r="1.4"/><circle cx="24" cy="47" r="1.4"/>
</g>""",
	"ocean/brick": """<rect x="2" y="2" width="60" height="60" fill="#e0b48a" rx="5"/>
<path d="M2 4 Q32 0 62 4 L58 10 Q32 7 6 10 Z" fill="#f0cca6"/>
<path d="M62 60 Q32 64 2 60 L6 54 Q32 57 58 54 Z" fill="#b8885c"/>
<path d="M32 22 L36 32 L46 33 L38 40 L41 50 L32 44 L23 50 L26 40 L18 33 L28 32 Z" fill="#e88060"/>
<circle cx="32" cy="37" r="3" fill="#f8b090"/>
<path d="M12 16 A5 5 0 0 1 22 16 L17 24 Z" fill="#c88c60"/>
<path d="M46 52 A4 4 0 0 1 54 52 L50 58 Z" fill="#c88c60"/>""",
	# sunset: analogous warm bands over aubergine.
	"sunset/wall": """<rect width="64" height="64" fill="#3a2545"/>
<path d="M0 0 H64 L57 7 H7 L7 57 L0 64 Z" fill="#4e3260"/>
<path d="M64 0 V64 H0 L7 57 H57 V7 Z" fill="#281733"/>
<path d="M7 30 Q32 26 57 30 L57 44 Q32 40 7 44 Z" fill="#452b56"/>
<path d="M7 44 Q32 40 57 44 L57 57 L7 57 Z" fill="#40274e"/>
<path d="M7 22 Q32 18 57 22 L57 24 Q32 20 7 24 Z" fill="#e8a860" opacity="0.45"/>
<circle cx="20" cy="13" r="1.2" fill="#f0dcc8" opacity="0.7"/>
<circle cx="46" cy="11" r="0.9" fill="#f0dcc8" opacity="0.55"/>""",
	"sunset/brick": """<rect x="2" y="2" width="60" height="60" fill="#f2879a" rx="6"/>
<path d="M2 8 Q2 2 8 2 L56 2 Q62 2 62 8 L62 16 Q44 20 32 16 Q18 12 2 17 Z" fill="#ffd9a0"/>
<path d="M2 17 Q18 12 32 16 Q44 20 62 16 L62 30 Q46 34 32 30 Q16 26 2 31 Z" fill="#ffb27a"/>
<path d="M2 31 Q16 26 32 30 Q46 34 62 30 L62 44 Q44 48 30 44 Q16 40 2 45 Z" fill="#f78d88"/>
<path d="M2 45 Q16 40 30 44 Q44 48 62 44 L62 56 Q62 62 56 62 L8 62 Q2 62 2 56 Z" fill="#c76d9e"/>
<path d="M8 12 Q20 9 30 12" fill="none" stroke="#ffe9c4" stroke-width="2" opacity="0.8"/>
<path d="M34 24 Q46 21 56 24" fill="none" stroke="#ffd2ac" stroke-width="1.8" opacity="0.7"/>
<path d="M12 38 Q24 35 34 38" fill="none" stroke="#fcb0a4" stroke-width="1.8" opacity="0.7"/>
<path d="M2 56 Q2 62 8 62 L56 62 Q62 62 62 56 L62 52 Q32 58 2 52 Z" fill="#a85a8c" opacity="0.6"/>""",
	# sakura: plum bark against pink bloom clusters (translucent).
	"sakura/wall": """<rect width="64" height="64" fill="#4a3040"/>
<path d="M0 0 H64 L57 7 H7 L7 57 L0 64 Z" fill="#5c3e50"/>
<path d="M64 0 V64 H0 L7 57 H57 V7 Z" fill="#38222f"/>
<g fill="none" stroke="#654a58" stroke-width="3">
<path d="M14 56 Q20 38 16 14"/><path d="M32 58 Q34 36 30 10"/><path d="M50 56 Q46 34 50 12"/>
</g>
<g fill="#ffb8ce" opacity="0.9">
<circle cx="16" cy="13" r="3"/><circle cx="30" cy="9" r="3"/><circle cx="50" cy="11" r="3"/>
</g>""",
	"sakura/brick": _bush("#e88bb0", "#ffaac6", "#c86490",
		"""<g fill="#ffd2e2">
<circle cx="24" cy="24" r="4.5"/><circle cx="40" cy="35" r="4.5"/><circle cx="20" cy="42" r="4"/><circle cx="44" cy="22" r="3.5"/>
</g>
<g fill="#fff2f7">
<circle cx="24" cy="24" r="1.8"/><circle cx="40" cy="35" r="1.8"/><circle cx="20" cy="42" r="1.6"/>
</g>"""),
	# lavender: violet bundles on gray-violet fieldstone.
	"lavender/wall": """<rect width="64" height="64" fill="#6b6478"/>
<path d="M0 0 H64 L56 8 H8 L8 56 L0 64 Z" fill="#837b90"/>
<path d="M64 0 V64 H0 L8 56 H56 V8 Z" fill="#524c60"/>
<rect x="8" y="8" width="48" height="48" fill="#645d72"/>
<g fill="#575064">
<ellipse cx="22" cy="24" rx="10" ry="7"/><ellipse cx="44" cy="42" rx="11" ry="8"/>
</g>
<g fill="#736b82" opacity="0.9">
<ellipse cx="42" cy="20" rx="8" ry="6"/><ellipse cx="20" cy="46" rx="8" ry="6"/>
</g>""",
	"lavender/brick": """<g fill="none" stroke="#6b8a4a" stroke-width="2.2">
<path d="M20 58 Q22 42 18 28"/><path d="M32 58 Q32 40 32 24"/><path d="M44 58 Q42 42 46 28"/>
</g>
<g fill="#8a66c0">
<ellipse cx="18" cy="24" rx="5" ry="9"/><ellipse cx="32" cy="19" rx="5" ry="10"/><ellipse cx="46" cy="24" rx="5" ry="9"/>
</g>
<g fill="#a888d8">
<ellipse cx="17" cy="19" rx="3.4" ry="6"/><ellipse cx="31" cy="13" rx="3.4" ry="6.5"/><ellipse cx="45" cy="19" rx="3.4" ry="6"/>
</g>
<g fill="#c8b0ec" opacity="0.9">
<circle cx="17" cy="14" r="2.2"/><circle cx="31" cy="8" r="2.4"/><circle cx="45" cy="14" r="2.2"/>
</g>""",
	# autumn: walnut grain against a maple-leaf pile (translucent).
	"autumn/wall": """<rect width="64" height="64" fill="#4a3626"/>
<path d="M0 0 H64 L57 7 H7 L7 57 L0 64 Z" fill="#5c4430"/>
<path d="M64 0 V64 H0 L7 57 H57 V7 Z" fill="#38281c"/>
<g fill="none" stroke="#5f492f" stroke-width="2.5">
<path d="M12 12 Q34 16 52 12"/><path d="M12 22 Q30 27 52 22"/><path d="M12 33 Q36 37 52 33"/><path d="M12 44 Q30 48 52 44"/><path d="M12 53 Q34 56 52 53"/>
</g>
<ellipse cx="24" cy="28" rx="4" ry="6" fill="#38281c"/>
<ellipse cx="24" cy="28" rx="1.8" ry="3" fill="#5c4430"/>""",
	"autumn/brick": """<g fill="#e07030">
<path d="M18 40 L26 28 L34 40 L26 50 Z"/><path d="M38 26 L46 16 L54 28 L46 38 Z"/><path d="M10 24 L18 14 L26 26 L18 36 Z"/>
</g>
<g fill="#c84820">
<path d="M30 48 L40 38 L48 50 L38 58 Z"/><path d="M12 44 L20 36 L26 46 L18 54 Z"/>
</g>
<g fill="#f0a040">
<path d="M40 44 L48 36 L54 46 L46 52 Z"/><path d="M22 20 L28 12 L36 22 L28 30 Z"/>
</g>
<g fill="none" stroke="#8a4a18" stroke-width="1.3">
<path d="M26 30 L26 48"/><path d="M46 18 L46 36"/><path d="M18 16 L18 34"/>
</g>""",
	# nordic: birch calm with one dusty-blue woven panel.
	"nordic/wall": """<rect width="64" height="64" fill="#d8cfc0"/>
<path d="M0 0 H64 L57 7 H7 L7 57 L0 64 Z" fill="#e8e1d4"/>
<path d="M64 0 V64 H0 L7 57 H57 V7 Z" fill="#b8ad9a"/>
<g fill="#3f3a32">
<rect x="14" y="14" width="7" height="2.4" rx="1.2"/><rect x="40" y="20" width="9" height="2.4" rx="1.2"/>
<rect x="20" y="34" width="8" height="2.4" rx="1.2"/><rect x="44" y="44" width="7" height="2.4" rx="1.2"/>
<rect x="14" y="50" width="6" height="2.4" rx="1.2"/>
</g>
<rect x="30" y="8" width="3" height="48" fill="#c4b9a6"/>""",
	"nordic/brick": """<rect x="4" y="4" width="56" height="56" fill="#7a92a8" rx="5"/>
<path d="M4 6 H60 L54 12 H10 L10 54 L4 60 Z" fill="#93a9bc"/>
<path d="M60 4 V60 H4 L10 54 H54 V10 Z" fill="#5f7488"/>
<g fill="none" stroke="#e8eef2" stroke-width="2.6">
<path d="M32 16 L32 48"/><path d="M16 32 L48 32"/>
<path d="M21 21 L43 43"/><path d="M43 21 L21 43"/>
</g>
<circle cx="32" cy="32" r="4.5" fill="#e8eef2"/><circle cx="32" cy="32" r="2" fill="#7a92a8"/>""",
	# jade: monochrome green tonal steps, carved disc brick.
	"jade/wall": """<rect width="64" height="64" fill="#2e7a5a"/>
<path d="M0 0 H64 L56 8 H8 L8 56 L0 64 Z" fill="#3f9670"/>
<path d="M64 0 V64 H0 L8 56 H56 V8 Z" fill="#1f5c42"/>
<rect x="8" y="8" width="48" height="48" fill="#2a7052"/>
<g fill="none" stroke="#1f5c42" stroke-width="3">
<path d="M16 16 H48 V48 H16 Z"/><path d="M24 24 H40 V40 H24 Z"/>
</g>
<rect x="29" y="29" width="6" height="6" fill="#4faa80"/>""",
	"jade/brick": """<circle cx="32" cy="32" r="27" fill="#8ac4a4"/>
<circle cx="32" cy="32" r="27" fill="none" stroke="#5da888" stroke-width="3"/>
<circle cx="32" cy="32" r="10" fill="#5da888"/>
<circle cx="32" cy="32" r="6" fill="#bfe2d0"/>
<g fill="#aad8c0">
<circle cx="32" cy="14" r="3"/><circle cx="50" cy="32" r="3"/><circle cx="32" cy="50" r="3"/><circle cx="14" cy="32" r="3"/>
</g>
<path d="M12 20 A24 24 0 0 1 44 10" fill="none" stroke="#dff2e8" stroke-width="2.5" opacity="0.8"/>""",
	# terracotta: whitewash walls, three warm pots (translucent edges).
	"terracotta/wall": """<rect width="64" height="64" fill="#f0ebe0"/>
<path d="M0 0 H64 L57 7 H7 L7 57 L0 64 Z" fill="#faf7ef"/>
<path d="M64 0 V64 H0 L7 57 H57 V7 Z" fill="#cfc7b4"/>
<rect x="7" y="7" width="50" height="50" fill="#ebe5d8"/>
<rect x="12" y="46" width="40" height="4" fill="#3f6b8a" opacity="0.85"/>
<rect x="12" y="52" width="40" height="2" fill="#3f6b8a" opacity="0.5"/>
<circle cx="46" cy="20" r="6" fill="#e8dfcd"/>""",
	"terracotta/brick": """<path d="M14 26 L50 26 L46 58 L18 58 Z" fill="#c86844"/>
<path d="M14 26 L50 26 L49 34 L15 34 Z" fill="#da7d54"/>
<rect x="10" y="20" width="44" height="8" fill="#b85838" rx="3"/>
<rect x="10" y="20" width="44" height="3.5" fill="#da7d54" rx="1.7"/>
<path d="M22 34 L26 54" stroke="#a04c2c" stroke-width="2" fill="none"/>
<ellipse cx="32" cy="14" rx="4" ry="6" fill="#4c8a3c"/>
<ellipse cx="38" cy="12" rx="3.4" ry="5" fill="#5f9e4c"/>
<path d="M32 20 Q34 16 38 14" stroke="#3f7330" stroke-width="2" fill="none"/>""",
	# glacier: slate dark walls, semi-clear ice block brick.
	"glacier/wall": """<rect width="64" height="64" fill="#2c4258"/>
<path d="M0 0 H64 L57 7 H7 L7 57 L0 64 Z" fill="#3d566e"/>
<path d="M64 0 V64 H0 L7 57 H57 V7 Z" fill="#1e3042"/>
<path d="M10 50 L22 26 L30 40 L40 18 L54 50 Z" fill="#48657e"/>
<path d="M22 26 L30 40 L26 50 L14 50 Z" fill="#5a7890" opacity="0.8"/>
<path d="M40 18 L47 34 L34 50 L30 40 Z" fill="#93b4c8" opacity="0.55"/>""",
	"glacier/brick": """<g opacity="0.88">
<rect x="4" y="8" width="56" height="50" fill="#cfeaf4" rx="6"/>
<path d="M4 10 H60 L52 18 H12 L12 50 L4 58 Z" fill="#e8f6fb"/>
<path d="M60 8 V58 H4 L12 50 H52 V16 Z" fill="#9cc8dc"/>
<path d="M20 18 L34 32 L26 48" fill="none" stroke="#ffffff" stroke-width="2.4" opacity="0.8"/>
<path d="M42 20 L38 34 L48 44" fill="none" stroke="#b8dcea" stroke-width="2" opacity="0.9"/>
</g>""",
	# honey: chocolate walls, honeycomb brick (the bees approve).
	"honey/wall": """<rect width="64" height="64" fill="#4a2f1a"/>
<path d="M0 0 H64 L57 7 H7 L7 57 L0 64 Z" fill="#5e3d22"/>
<path d="M64 0 V64 H0 L7 57 H57 V7 Z" fill="#361f10"/>
<path d="M7 16 Q20 24 32 16 Q46 8 57 16 L57 24 Q44 16 32 24 Q18 32 7 24 Z" fill="#c87818" opacity="0.85"/>
<circle cx="20" cy="42" r="3" fill="#c87818" opacity="0.7"/>
<circle cx="42" cy="48" r="2.4" fill="#c87818" opacity="0.7"/>""",
	"honey/brick": """<rect x="2" y="2" width="60" height="60" fill="#c87818" rx="4"/>
<g fill="#f0b030">
<path d="M12 6 L24 6 L30 16 L24 26 L12 26 L6 16 Z"/>
<path d="M40 6 L52 6 L58 16 L52 26 L40 26 L34 16 Z"/>
<path d="M26 26 L38 26 L44 36 L38 46 L26 46 L20 36 Z"/>
<path d="M12 46 L24 46 L28 54 L24 60 L12 60 L8 54 Z"/>
<path d="M40 46 L52 46 L56 54 L52 60 L40 60 L36 54 Z"/>
</g>
<g fill="#ffd268">
<path d="M14 8 L22 8 L26 15 L22 22 L14 22 L10 15 Z" opacity="0.85"/>
</g>
<ellipse cx="45" cy="37" rx="5" ry="3.6" fill="#3a2a10"/>
<g fill="#f0c040">
<rect x="41.6" y="34.5" width="2.4" height="5.4" rx="1.2"/><rect x="45.6" y="34.5" width="2.4" height="5.4" rx="1.2"/>
</g>
<ellipse cx="49" cy="34" rx="2.6" ry="1.8" fill="#cfe4f0" opacity="0.9"/>""",
	# vineyard: winery stone, purple grapes vs vine-green floor.
	"vineyard/wall": """<rect width="64" height="64" fill="#8a8578"/>
<path d="M0 0 H64 L57 7 H7 L7 57 L0 64 Z" fill="#a09a8c"/>
<path d="M64 0 V64 H0 L7 57 H57 V7 Z" fill="#6e6a5e"/>
<g fill="#7d7768">
<rect x="7" y="7" width="24" height="16"/><rect x="35" y="7" width="22" height="16"/>
<rect x="7" y="27" width="15" height="14"/><rect x="26" y="27" width="31" height="14"/>
<rect x="7" y="45" width="26" height="12"/><rect x="37" y="45" width="20" height="12"/>
</g>
<path d="M20 57 Q32 40 44 57" fill="none" stroke="#5c584c" stroke-width="3"/>""",
	"vineyard/brick": """<path d="M32 8 Q40 12 42 20" fill="none" stroke="#6b8a3c" stroke-width="2.6"/>
<path d="M30 10 Q22 16 28 22 Q36 26 42 20 Q44 12 36 8 Q31 7 30 10 Z" fill="#7fa84c"/>
<g fill="#7a4a9a">
<circle cx="24" cy="28" r="6.5"/><circle cx="37" cy="28" r="6.5"/><circle cx="18" cy="38" r="6.5"/><circle cx="31" cy="39" r="6.5"/><circle cx="44" cy="38" r="6.5"/>
<circle cx="24" cy="49" r="6.5"/><circle cx="38" cy="49" r="6.5"/><circle cx="31" cy="58" r="6"/>
</g>
<g fill="#9a6cc0" opacity="0.9">
<circle cx="22" cy="26" r="2.6"/><circle cx="35" cy="26" r="2.6"/><circle cx="16" cy="36" r="2.6"/><circle cx="29" cy="37" r="2.6"/><circle cx="42" cy="36" r="2.6"/><circle cx="22" cy="47" r="2.6"/>
</g>""",
	# copper: verdigris plates vs polished copper (complements).
	"copper/wall": """<rect width="64" height="64" fill="#3f8a72"/>
<path d="M0 0 H64 L57 7 H7 L7 57 L0 64 Z" fill="#55a48a"/>
<path d="M64 0 V64 H0 L7 57 H57 V7 Z" fill="#2c6b56"/>
<g fill="#4c9a80" opacity="0.9">
<path d="M10 10 Q22 20 14 34 L10 34 Z"/><path d="M50 26 Q44 40 52 52 L54 52 Z"/>
</g>
<g fill="#b87333">
<circle cx="13" cy="13" r="2.6"/><circle cx="51" cy="13" r="2.6"/><circle cx="13" cy="51" r="2.6"/><circle cx="51" cy="51" r="2.6"/>
</g>
<path d="M22 44 Q32 36 44 42" fill="none" stroke="#2c6b56" stroke-width="2.4"/>""",
	"copper/brick": """<rect x="3" y="3" width="58" height="58" fill="#b87333" rx="5"/>
<path d="M3 5 H61 L53 13 H11 L11 51 L3 61 Z" fill="#d99a56"/>
<path d="M61 3 V61 H3 L11 53 H53 V11 Z" fill="#8a5424"/>
<path d="M14 48 Q28 20 50 14" fill="none" stroke="#f0c088" stroke-width="4" opacity="0.75"/>
<g fill="#8a5424">
<circle cx="16" cy="16" r="2.2"/><circle cx="48" cy="16" r="2.2"/><circle cx="16" cy="48" r="2.2"/><circle cx="48" cy="48" r="2.2"/>
</g>
<path d="M40 44 Q46 40 50 42" fill="none" stroke="#4c9a80" stroke-width="2" opacity="0.8"/>""",
	# midnight: navy and gold — the art-deco ballroom.
	"midnight/wall": """<rect width="64" height="64" fill="#232c4e"/>
<path d="M0 0 H64 L57 7 H7 L7 57 L0 64 Z" fill="#2f3a62"/>
<path d="M64 0 V64 H0 L7 57 H57 V7 Z" fill="#161d38"/>
<g fill="none" stroke="#d4af37" stroke-width="1.8">
<path d="M7 20 L20 7"/><path d="M7 30 L30 7"/><path d="M44 57 L57 44"/><path d="M34 57 L57 34"/>
</g>
<circle cx="32" cy="32" r="7" fill="none" stroke="#d4af37" stroke-width="1.8"/>
<circle cx="32" cy="32" r="2.2" fill="#d4af37"/>""",
	"midnight/brick": """<rect x="3" y="3" width="58" height="58" fill="#e8dcc0" rx="4"/>
<path d="M3 5 H61 L54 12 H10 L10 54 L3 61 Z" fill="#f6efdd"/>
<path d="M61 3 V61 H3 L10 54 H54 V10 Z" fill="#c4b492"/>
<g fill="none" stroke="#232c4e" stroke-width="2.2">
<path d="M32 52 L32 34"/><path d="M32 40 L18 22"/><path d="M32 40 L46 22"/><path d="M32 36 L24 18"/><path d="M32 36 L40 18"/><path d="M32 34 L32 14"/>
</g>
<g fill="#d4af37">
<circle cx="32" cy="12" r="3"/><circle cx="18" cy="20" r="2.4"/><circle cx="46" cy="20" r="2.4"/><circle cx="24" cy="16" r="2"/><circle cx="40" cy="16" r="2"/>
</g>""",
	# savanna: sunbaked mound walls, hay-bale bricks.
	"savanna/wall": """<rect width="64" height="64" fill="#a5763f"/>
<path d="M4 64 Q2 30 14 12 Q22 2 32 4 Q44 2 52 14 Q62 32 60 64 Z" fill="#b8894e"/>
<path d="M10 64 Q10 34 20 18 Q28 8 32 10 L32 64 Z" fill="#c99a5c" opacity="0.8"/>
<g fill="#8a5f30">
<ellipse cx="24" cy="34" rx="3" ry="5"/><ellipse cx="42" cy="26" rx="2.6" ry="4"/><ellipse cx="36" cy="48" rx="3" ry="4.5"/>
</g>
<path d="M0 58 H64 V64 H0 Z" fill="#8a5f30"/>""",
	"savanna/brick": """<rect x="6" y="14" width="52" height="42" fill="#d8b868" rx="6"/>
<path d="M6 16 H58 L52 22 H12 L12 50 L6 56 Z" fill="#eccf82"/>
<path d="M58 14 V56 H6 L12 50 H52 V20 Z" fill="#b0904a"/>
<g fill="none" stroke="#c0a054" stroke-width="1.6">
<path d="M12 22 H52"/><path d="M12 30 H52"/><path d="M12 38 H52"/><path d="M12 46 H52"/>
</g>
<rect x="20" y="14" width="4" height="42" fill="#8a6a30" opacity="0.75"/>
<rect x="40" y="14" width="4" height="42" fill="#8a6a30" opacity="0.75"/>
<path d="M50 10 Q54 6 58 8" fill="none" stroke="#c8a858" stroke-width="2"/>""",
	# rose: blush stone walls, faceted rose-quartz brick.
	"rose/wall": """<rect width="64" height="64" fill="#b89098"/>
<path d="M0 0 H64 L56 8 H8 L8 56 L0 64 Z" fill="#cfa9b0"/>
<path d="M64 0 V64 H0 L8 56 H56 V8 Z" fill="#96707a"/>
<rect x="8" y="8" width="48" height="48" fill="#b0888f"/>
<rect x="14" y="14" width="36" height="36" fill="#a8828a"/>
<circle cx="32" cy="32" r="5" fill="#96707a"/>
<circle cx="32" cy="32" r="2" fill="#cfa9b0"/>""",
	"rose/brick": """<g opacity="0.94">
<path d="M32 4 L52 18 L46 52 L18 52 L12 18 Z" fill="#e8b4c8"/>
<path d="M32 4 L52 18 L32 30 Z" fill="#f4ccd9"/>
<path d="M12 18 L32 30 L18 52 Z" fill="#d898b4"/>
<path d="M52 18 L46 52 L32 30 Z" fill="#cc88a8"/>
<path d="M32 30 L18 52 L46 52 Z" fill="#e0a4bc"/>
<path d="M32 4 L12 18 L32 30 Z" fill="#fadeE8"/>
<path d="M22 14 L32 8 L40 13" fill="none" stroke="#fff0f5" stroke-width="2" opacity="0.9"/>
</g>""",

	# ================= PASTEL 5 (v4.9) ==================
	"pastel_mint/wall": _bevel("#a0d8bc", "#c8ecd8", "#7cb89a", "#aedec6", "#8cc8aa"),
	"pastel_mint/brick": """<rect x="3" y="3" width="58" height="58" fill="#f0e8d0" rx="10"/>
<path d="M3 6 Q32 0 61 6 L56 13 Q32 8 8 13 Z" fill="#f8f2e0"/>
<path d="M61 58 Q32 64 3 58 L8 51 Q32 56 56 51 Z" fill="#d8cdb0"/>
<g fill="#7cc8a4">
<circle cx="20" cy="22" r="3.4"/><circle cx="40" cy="18" r="3"/><circle cx="30" cy="36" r="3.4"/><circle cx="46" cy="40" r="3"/><circle cx="18" cy="44" r="2.8"/><circle cx="36" cy="52" r="2.6"/>
</g>""",
	"pastel_peach/wall": _bevel("#f0b890", "#fad8b8", "#d09468", "#f4c49e", "#e0a87c"),
	"pastel_peach/brick": _bricks("#fdf1e2", "#f8c8a0", "#eaaa7c", "#fff8ee", "#d89468"),
	"pastel_sky/wall": """<rect width="64" height="64" fill="#a8cce8"/>
<path d="M0 0 H64 L57 7 H7 L7 57 L0 64 Z" fill="#c6e0f2"/>
<path d="M64 0 V64 H0 L7 57 H57 V7 Z" fill="#88aecc"/>
<g fill="#bcd8ee">
<circle cx="22" cy="30" r="8"/><circle cx="32" cy="26" r="10"/><circle cx="43" cy="31" r="8"/>
<rect x="16" y="30" width="33" height="8" rx="4"/>
</g>
<g fill="#d8ecf8">
<circle cx="24" cy="27" r="5"/><circle cx="33" cy="23" r="6"/>
</g>""",
	"pastel_sky/brick": """<g opacity="0.95">
<circle cx="18" cy="40" r="11" fill="#ffffff"/><circle cx="32" cy="34" r="14" fill="#ffffff"/><circle cx="47" cy="40" r="10" fill="#ffffff"/>
<rect x="12" y="40" width="42" height="11" rx="5.5" fill="#ffffff"/>
<circle cx="20" cy="36" r="7" fill="#f4fafe"/><circle cx="33" cy="29" r="8.5" fill="#f4fafe"/>
<path d="M12 49 Q32 55 54 49" fill="none" stroke="#c8dcec" stroke-width="3"/>
</g>""",
	"pastel_lilac/wall": _bevel("#b8a4d8", "#d5c8ea", "#9480b4", "#c2b0e0", "#a692c8"),
	"pastel_lilac/brick": """<rect x="3" y="3" width="58" height="58" fill="#f4e4a8" rx="8"/>
<path d="M3 5 H61 L54 12 H10 L10 54 L3 61 Z" fill="#faf0c6"/>
<path d="M61 3 V61 H3 L10 54 H54 V10 Z" fill="#d8c488"/>
<g fill="#e8d494">
<rect x="12" y="18" width="18" height="10" rx="5"/><rect x="34" y="18" width="18" height="10" rx="5"/>
<rect x="12" y="36" width="18" height="10" rx="5"/><rect x="34" y="36" width="18" height="10" rx="5"/>
</g>
<circle cx="47" cy="15" r="4" fill="#b8a4d8" opacity="0.85"/>""",
	"candy/wall": """<rect width="64" height="64" fill="#f8f0f2"/>
<path d="M0 0 H64 L57 7 H7 L7 57 L0 64 Z" fill="#fffafb"/>
<path d="M64 0 V64 H0 L7 57 H57 V7 Z" fill="#dcc8ce"/>
<circle cx="32" cy="32" r="20" fill="#ffffff"/>
<path d="M32 32 L32 12 A20 20 0 0 1 49 22 Z" fill="#f06292"/>
<path d="M32 32 L49 42 A20 20 0 0 1 32 52 Z" fill="#f06292"/>
<path d="M32 32 L15 42 A20 20 0 0 1 15 22 Z" fill="#f06292"/>
<circle cx="32" cy="32" r="20" fill="none" stroke="#e8b8c8" stroke-width="2"/>
<circle cx="32" cy="32" r="4" fill="#f8d0dc"/>""",
	"candy/brick": """<ellipse cx="32" cy="32" rx="17" ry="14" fill="#7addc8"/>
<ellipse cx="32" cy="29" rx="13" ry="9" fill="#a2ecdd" opacity="0.9"/>
<path d="M15 32 L4 22 L8 32 L4 42 Z" fill="#5cc4ae"/>
<path d="M49 32 L60 22 L56 32 L60 42 Z" fill="#5cc4ae"/>
<path d="M15 32 L4 22 L8 32 L4 42 Z" fill="none" stroke="#48b09a" stroke-width="1.4"/>
<path d="M49 32 L60 22 L56 32 L60 42 Z" fill="none" stroke="#48b09a" stroke-width="1.4"/>
<g fill="#f06292" opacity="0.9">
<rect x="24" y="21" width="4" height="22" rx="2" transform="rotate(18 26 32)"/>
<rect x="36" y="21" width="4" height="22" rx="2" transform="rotate(18 38 32)"/>
</g>
<ellipse cx="26" cy="26" rx="4" ry="2.6" fill="#e4fff8" opacity="0.9"/>""",

	# ================= ART HOMAGES 4 (v4.9) =============
	# Mondrian: wall anchored by RED, brick by YELLOW — telling them
	# apart is part of the composition.
	"mondrian/wall": """<rect width="64" height="64" fill="#f4f4f0"/>
<rect x="4" y="4" width="34" height="34" fill="#d40920"/>
<rect x="44" y="26" width="16" height="20" fill="#1356a2"/>
<rect x="12" y="46" width="18" height="14" fill="#f4f4f0"/>
<g fill="#111111">
<rect x="0" y="0" width="64" height="5"/><rect x="0" y="59" width="64" height="5"/>
<rect x="0" y="0" width="5" height="64"/><rect x="59" y="0" width="5" height="64"/>
<rect x="38" y="0" width="5" height="64"/><rect x="0" y="38" width="43" height="5"/>
<rect x="38" y="22" width="26" height="4"/><rect x="8" y="42" width="4" height="22"/><rect x="38" y="46" width="26" height="4"/>
</g>""",
	"mondrian/brick": """<rect width="64" height="64" fill="#f4f4f0"/>
<rect x="24" y="3" width="37" height="27" fill="#f7d842"/>
<rect x="3" y="34" width="18" height="27" fill="#f7d842"/>
<rect x="3" y="3" width="18" height="14" fill="#1356a2"/>
<rect x="42" y="44" width="19" height="17" fill="#d40920"/>
<g fill="#111111">
<rect x="0" y="0" width="64" height="3"/><rect x="0" y="61" width="64" height="3"/>
<rect x="0" y="0" width="3" height="64"/><rect x="61" y="0" width="3" height="64"/>
<rect x="21" y="0" width="4" height="64"/><rect x="0" y="17" width="25" height="4"/>
<rect x="21" y="30" width="43" height="4"/><rect x="38" y="30" width="4" height="34"/><rect x="0" y="42" width="25" height="3"/>
</g>""",
	# Van Gogh: swirling night wall, radiant star brick.
	"vangogh/wall": """<rect width="64" height="64" fill="#1e2d5c"/>
<g fill="none" stroke="#31437c" stroke-width="3.4">
<path d="M6 18 Q20 8 30 16 Q40 24 30 30 Q22 34 18 28"/>
<path d="M34 44 Q46 34 56 42 Q62 48 54 54 Q46 58 44 52"/>
<path d="M4 44 Q14 38 22 46 Q28 52 20 58"/>
</g>
<g fill="none" stroke="#4c6098" stroke-width="2">
<path d="M10 18 Q20 12 28 18 Q34 24 28 28"/>
<path d="M38 44 Q48 38 54 44 Q58 48 52 52"/>
</g>
<circle cx="50" cy="14" r="6" fill="#f5d867" opacity="0.9"/>
<circle cx="50" cy="14" r="9" fill="none" stroke="#c8a848" stroke-width="1.8" opacity="0.7"/>""",
	"vangogh/brick": """<rect width="64" height="64" fill="#273770"/>
<circle cx="32" cy="32" r="9" fill="#f5d867"/>
<circle cx="32" cy="32" r="4.5" fill="#fcf0b4"/>
<g fill="none" stroke="#e8c455" stroke-width="2.6">
<circle cx="32" cy="32" r="14"/><circle cx="32" cy="32" r="20"/>
</g>
<g fill="none" stroke="#b89838" stroke-width="1.8">
<circle cx="32" cy="32" r="17"/><circle cx="32" cy="32" r="24"/>
</g>
<g fill="none" stroke="#3a4c88" stroke-width="2.6">
<path d="M4 8 Q12 4 18 10"/><path d="M46 56 Q54 60 60 54"/><path d="M4 56 Q10 60 16 56"/><path d="M48 8 Q54 4 60 8"/>
</g>""",
	# Monet: soft stone bridge wall, lily pads on the pond.
	"monet/wall": """<rect width="64" height="64" fill="#a8b8a0"/>
<path d="M0 0 H64 L57 7 H7 L7 57 L0 64 Z" fill="#c0ccb6"/>
<path d="M64 0 V64 H0 L7 57 H57 V7 Z" fill="#8a9a84"/>
<path d="M7 46 Q32 20 57 46 L57 57 L7 57 Z" fill="#98a890"/>
<path d="M13 52 Q32 30 51 52 L51 57 L13 57 Z" fill="#7e8e78"/>
<g fill="#b4c4aa" opacity="0.85">
<circle cx="16" cy="16" r="3.4"/><circle cx="30" cy="12" r="3"/><circle cx="46" cy="17" r="3.4"/><circle cx="24" cy="24" r="2.6"/><circle cx="40" cy="26" r="2.6"/>
</g>""",
	"monet/brick": """<g opacity="0.95">
<ellipse cx="22" cy="42" rx="14" ry="8" fill="#5a9a6a"/>
<path d="M22 42 L36 38 L34 46 Z" fill="#4a8a5c"/>
<ellipse cx="45" cy="30" rx="12" ry="7" fill="#6aaa76"/>
<path d="M45 30 L56 26 L55 34 Z" fill="#5a9a6a"/>
<ellipse cx="20" cy="20" rx="10" ry="6" fill="#7ab884"/>
<circle cx="40" cy="48" r="6" fill="#f0a8c0"/>
<path d="M40 42 L43 48 L40 54 L37 48 Z" fill="#f8c8d8"/>
<path d="M34 48 L40 45 L46 48 L40 51 Z" fill="#fadce6"/>
<circle cx="40" cy="48" r="2" fill="#f6e88a"/>
</g>""",
	# Hokusai: prussian-blue wave band wall, breaking crest brick.
	"ukiyoe/wall": """<rect width="64" height="64" fill="#1f3a5c"/>
<path d="M0 40 Q10 26 22 32 Q16 38 20 42 Q28 30 40 34 Q34 42 38 46 Q46 34 58 38 L64 42 L64 64 L0 64 Z" fill="#2c5c8c"/>
<g fill="#e8ded0">
<circle cx="21" cy="31" r="1.8"/><circle cx="39" cy="33" r="1.8"/><circle cx="57" cy="37" r="1.8"/>
<circle cx="14" cy="36" r="1.2"/><circle cx="32" cy="38" r="1.2"/><circle cx="50" cy="42" r="1.2"/>
</g>
<rect x="0" y="0" width="64" height="8" fill="#16293f"/>
<rect x="0" y="56" width="64" height="8" fill="#16293f"/>""",
	"ukiyoe/brick": """<g opacity="0.97">
<path d="M6 54 Q4 30 18 18 Q34 6 50 14 Q58 18 58 26 Q50 22 46 26 Q54 28 52 36 Q44 32 40 36 Q48 40 44 48 Q36 44 32 48 Q38 52 34 58 L10 58 Q6 58 6 54 Z" fill="#2c5c8c"/>
<path d="M10 52 Q10 34 20 24 Q32 14 46 20" fill="none" stroke="#1f3a5c" stroke-width="3"/>
<g fill="#e8ded0">
<path d="M50 14 Q56 12 58 16 L54 18 Z"/><path d="M46 26 Q52 24 54 28 L50 30 Z"/><path d="M40 36 Q46 34 48 38 L44 40 Z"/><path d="M32 48 Q38 46 40 50 L36 52 Z"/>
<circle cx="52" cy="12" r="1.6"/><circle cx="56" cy="22" r="1.4"/><circle cx="50" cy="32" r="1.4"/><circle cx="46" cy="44" r="1.4"/>
</g>
</g>""",

	# ================= PLAYING CARDS 1 (v4.9) ===========
	"casino/wall": """<rect width="64" height="64" fill="#8a1f2b"/>
<ellipse cx="32" cy="50" rx="26" ry="9" fill="#6e1620"/>
<ellipse cx="32" cy="44" rx="26" ry="9" fill="#a32633"/>
<ellipse cx="32" cy="32" rx="26" ry="9" fill="#8a1f2b"/>
<ellipse cx="32" cy="26" rx="26" ry="9" fill="#b52c3a"/>
<ellipse cx="32" cy="16" rx="26" ry="9" fill="#c53240"/>
<ellipse cx="32" cy="16" rx="17" ry="5.6" fill="#d84250"/>
<g fill="#f0e8e0">
<rect x="8" y="12" width="7" height="4" rx="2" transform="rotate(-18 11 14)"/>
<rect x="49" y="12" width="7" height="4" rx="2" transform="rotate(18 53 14)"/>
<rect x="28" y="8" width="8" height="4" rx="2"/>
<ellipse cx="32" cy="16" rx="10" ry="3.2" opacity="0.5"/>
</g>""",
	"casino/brick": """<g>
<rect x="24" y="6" width="34" height="48" rx="5" fill="#e8e8ea" transform="rotate(9 41 30)"/>
<rect x="24" y="6" width="34" height="48" rx="5" fill="none" stroke="#b8b8c0" stroke-width="1.6" transform="rotate(9 41 30)"/>
<rect x="6" y="10" width="36" height="50" rx="5" fill="#ffffff"/>
<rect x="6" y="10" width="36" height="50" rx="5" fill="none" stroke="#c8c8d0" stroke-width="1.6"/>
<path d="M24 26 C20 20 12 22 12 29 C12 35 20 39 24 44 C28 39 36 35 36 29 C36 22 28 20 24 26 Z" fill="#d40920"/>
<path d="M10 14 C9 12.5 7 13 7 14.8 C7 16.3 9 17.3 10 18.5 C11 17.3 13 16.3 13 14.8 C13 13 11 12.5 10 14 Z" fill="#d40920"/>
<path d="M38 51 C37 49.5 35 50 35 51.8 C35 53.3 37 54.3 38 55.5 C39 54.3 41 53.3 41 51.8 C41 50 39 49.5 38 51 Z" fill="#d40920"/>
</g>""",

	# ================= FANTASY 10 (v4.9) ================
	"gingerbread/wall": """<rect width="64" height="64" fill="#5a3620"/>
<path d="M0 0 H64 L57 7 H7 L7 57 L0 64 Z" fill="#6e442a"/>
<path d="M64 0 V64 H0 L7 57 H57 V7 Z" fill="#452818"/>
<path d="M7 7 H57 L57 16 Q48 22 40 16 Q32 10 24 16 Q16 22 7 16 Z" fill="#f4f0e8"/>
<g fill="#f4f0e8">
<circle cx="18" cy="34" r="3"/><circle cx="34" cy="42" r="3"/><circle cx="48" cy="32" r="3"/><circle cx="24" cy="50" r="2.6"/>
</g>
<circle cx="40" cy="26" r="2.4" fill="#c83a4a"/>""",
	"gingerbread/brick": """<g>
<circle cx="32" cy="18" r="10" fill="#b06a34"/>
<path d="M22 26 Q18 30 14 40 L20 44 Q24 36 26 33 L26 48 Q26 56 30 58 L34 58 Q38 56 38 48 L38 33 Q40 36 44 44 L50 40 Q46 30 42 26 Q37 22 32 24 Q27 22 22 26 Z" fill="#b06a34"/>
<circle cx="32" cy="18" r="10" fill="none" stroke="#8a4c22" stroke-width="1.6"/>
<path d="M24 40 Q28 44 32 44 Q36 44 40 40" fill="none" stroke="#f4f0e8" stroke-width="2"/>
<circle cx="28" cy="16" r="1.6" fill="#3a2210"/><circle cx="36" cy="16" r="1.6" fill="#3a2210"/>
<path d="M28 21 Q32 24 36 21" fill="none" stroke="#f4f0e8" stroke-width="1.8"/>
<circle cx="32" cy="34" r="2" fill="#c83a4a"/><circle cx="32" cy="42" r="2" fill="#4a90c8"/>
<path d="M22 27 Q26 30 26 34" fill="none" stroke="#f4f0e8" stroke-width="1.6"/>
<path d="M42 27 Q38 30 38 34" fill="none" stroke="#f4f0e8" stroke-width="1.6"/>
</g>""",
	"atlantis/wall": """<rect width="64" height="64" fill="#173f4c"/>
<rect x="14" y="4" width="36" height="56" fill="#7a9a94"/>
<rect x="10" y="2" width="44" height="8" fill="#8faca4" rx="2"/>
<rect x="10" y="54" width="44" height="8" fill="#68867e" rx="2"/>
<g fill="#5f7d76">
<rect x="20" y="12" width="4" height="42"/><rect x="30" y="12" width="4" height="42"/><rect x="40" y="12" width="4" height="42"/>
</g>
<g fill="#e87a6a">
<circle cx="18" cy="40" r="4.5"/><circle cx="22" cy="45" r="3.4"/><circle cx="46" cy="22" r="4"/>
</g>
<g fill="#f0a090">
<circle cx="17" cy="38" r="2"/><circle cx="45" cy="20" r="1.8"/>
</g>
<circle cx="38" cy="8" r="1.6" fill="#bcdce4" opacity="0.8"/>""",
	"atlantis/brick": """<g fill="none" stroke="#3f8a5a" stroke-width="4">
<path d="M18 60 Q12 44 20 30 Q26 18 20 8"/>
<path d="M32 60 Q38 46 30 32 Q24 20 32 6"/>
<path d="M46 60 Q52 44 44 30 Q38 18 46 10"/>
</g>
<g fill="none" stroke="#5aaa72" stroke-width="2.4">
<path d="M18 52 Q14 42 20 32"/><path d="M32 50 Q36 40 30 30"/><path d="M46 52 Q50 42 44 32"/>
</g>
<g fill="#8fd4a8" opacity="0.85">
<ellipse cx="20" cy="26" rx="3.4" ry="5"/><ellipse cx="31" cy="18" rx="3" ry="4.5"/><ellipse cx="45" cy="24" rx="3.2" ry="5"/>
</g>
<g fill="#bcdce4" opacity="0.85">
<circle cx="26" cy="12" r="1.8"/><circle cx="40" cy="8" r="1.4"/><circle cx="52" cy="16" r="1.2"/>
</g>""",
	"moonbase/wall": """<rect width="64" height="64" fill="#3c4048"/>
<path d="M8 56 A24 24 0 0 1 56 56 Z" fill="#d8dce2"/>
<path d="M14 56 A18 18 0 0 1 40 40 Q30 44 26 56 Z" fill="#eef1f5"/>
<rect x="24" y="40" width="16" height="10" rx="3" fill="#2c5c74"/>
<rect x="26" y="42" width="8" height="3" rx="1.5" fill="#57c4e6"/>
<rect x="4" y="54" width="56" height="6" fill="#5a5f68"/>
<circle cx="50" cy="12" r="1.2" fill="#ffffff"/><circle cx="12" cy="16" r="1" fill="#ffffff"/><circle cx="30" cy="8" r="0.9" fill="#ffffff"/>
<rect x="43" y="30" width="3" height="14" fill="#9aa0a8"/>
<circle cx="44.5" cy="28" r="2.6" fill="#c83a3a"/>""",
	"moonbase/brick": """<g>
<path d="M12 52 Q6 44 10 32 Q12 20 24 14 Q36 8 48 16 Q58 24 56 38 Q54 50 42 55 Q26 60 12 52 Z" fill="#8a8f98"/>
<path d="M16 46 Q12 40 14 30 Q17 20 27 16 Q30 15 34 15 Q24 22 22 32 Q20 42 26 50 Q20 50 16 46 Z" fill="#a4a9b2"/>
<ellipse cx="38" cy="28" rx="7" ry="5.5" fill="#6e737c"/>
<ellipse cx="37" cy="27" rx="4" ry="3" fill="#5a5f68"/>
<ellipse cx="24" cy="40" rx="5" ry="4" fill="#6e737c"/>
<ellipse cx="45" cy="42" rx="4" ry="3.2" fill="#787d86"/>
<circle cx="30" cy="22" r="2" fill="#787d86"/>
</g>""",
	"crystal/wall": """<rect width="64" height="64" fill="#2c2438"/>
<path d="M0 0 H64 L57 7 H7 L7 57 L0 64 Z" fill="#3a3048"/>
<path d="M64 0 V64 H0 L7 57 H57 V7 Z" fill="#201a2c"/>
<g fill="#8a5cd0" opacity="0.9">
<path d="M14 57 L18 40 L24 57 Z"/><path d="M48 57 L52 44 L56 57 Z"/>
</g>
<g fill="#b088e8" opacity="0.9">
<path d="M20 57 L24 46 L28 57 Z"/><path d="M42 7 L46 18 L50 7 Z"/>
</g>
<circle cx="33" cy="30" r="2" fill="#d8bcf8" opacity="0.8"/>""",
	"crystal/brick": """<g>
<path d="M26 58 L18 30 L28 12 L34 34 Z" fill="#b088e8"/>
<path d="M28 12 L34 34 L40 18 Z" fill="#d8bcf8"/>
<path d="M18 30 L26 58 L20 56 L12 34 Z" fill="#8a5cd0"/>
<path d="M40 58 L36 36 L46 24 L50 44 Z" fill="#9a6cd8"/>
<path d="M46 24 L50 44 L54 30 Z" fill="#c8a4f0"/>
<path d="M40 58 L44 58 L52 46 L50 44 Z" fill="#7a4cc0"/>
<path d="M24 20 L28 14 L31 24" fill="none" stroke="#f0e4ff" stroke-width="1.8" opacity="0.9"/>
<circle cx="30" cy="40" r="1.6" fill="#f0e4ff" opacity="0.9"/>
</g>""",
	"mushroom/wall": """<rect width="64" height="64" fill="#2f4f44"/>
<path d="M18 64 L20 24 Q21 14 32 14 Q43 14 44 24 L46 64 Z" fill="#d8c8a8"/>
<path d="M22 64 L24 26 Q25 18 32 17 L32 64 Z" fill="#e8dcc0"/>
<path d="M18 30 Q32 36 46 30 L46 36 Q32 42 18 36 Z" fill="#b8a888"/>
<g fill="#c0b090">
<ellipse cx="27" cy="48" rx="3" ry="5"/><ellipse cx="38" cy="52" rx="2.6" ry="4"/>
</g>
<circle cx="14" cy="58" r="5" fill="#4c7a5c"/><circle cx="52" cy="60" r="4" fill="#4c7a5c"/>""",
	"mushroom/brick": """<g>
<rect x="26" y="34" width="12" height="22" rx="5" fill="#f0e4d0"/>
<path d="M26 40 Q32 44 38 40 L38 46 Q32 49 26 46 Z" fill="#d8c8b0"/>
<path d="M8 34 Q8 12 32 12 Q56 12 56 34 Q44 30 32 30 Q20 30 8 34 Z" fill="#d84848"/>
<path d="M12 28 Q14 16 28 13 Q20 18 18 28 Q15 28 12 28 Z" fill="#e86868"/>
<g fill="#fff4ec">
<circle cx="20" cy="22" r="4"/><circle cx="35" cy="17" r="4.5"/><circle cx="47" cy="24" r="3.6"/><circle cx="28" cy="27" r="2.6"/>
</g>
<path d="M8 34 Q20 30 32 30 Q44 30 56 34 Q44 36 32 36 Q20 36 8 34 Z" fill="#b03838"/>
</g>""",
	"clockwork/wall": """<rect width="64" height="64" fill="#6e5230"/>
<path d="M0 0 H64 L57 7 H7 L7 57 L0 64 Z" fill="#8a683c"/>
<path d="M64 0 V64 H0 L7 57 H57 V7 Z" fill="#523c22"/>
<g fill="#c8a040">
<path d="M32 12 L35 18 L41 15 L41 22 L48 22 L45 28 L51 31 L45 34 L48 40 L41 40 L41 47 L35 44 L32 50 L29 44 L23 47 L23 40 L16 40 L19 34 L13 31 L19 28 L16 22 L23 22 L23 15 L29 18 Z"/>
</g>
<circle cx="32" cy="31" r="10" fill="#8a683c"/>
<circle cx="32" cy="31" r="5" fill="#523c22"/>
<g fill="#a8823a">
<circle cx="12" cy="12" r="2.2"/><circle cx="52" cy="12" r="2.2"/><circle cx="12" cy="52" r="2.2"/><circle cx="52" cy="52" r="2.2"/>
</g>""",
	"clockwork/brick": """<circle cx="32" cy="32" r="27" fill="#c8a040"/>
<circle cx="32" cy="32" r="27" fill="none" stroke="#8a683c" stroke-width="3"/>
<circle cx="32" cy="32" r="21" fill="#f4ecd8"/>
<g fill="#3a3226">
<rect x="30.6" y="13" width="2.8" height="6"/><rect x="30.6" y="45" width="2.8" height="6"/>
<rect x="13" y="30.6" width="6" height="2.8"/><rect x="45" y="30.6" width="6" height="2.8"/>
<rect x="42" y="19" width="2.4" height="5" transform="rotate(45 43 21)"/><rect x="19" y="40" width="2.4" height="5" transform="rotate(45 20 42)"/>
<rect x="19" y="19" width="2.4" height="5" transform="rotate(-45 20 21)"/><rect x="42" y="40" width="2.4" height="5" transform="rotate(-45 43 42)"/>
</g>
<path d="M32 32 L32 20" stroke="#3a3226" stroke-width="3"/>
<path d="M32 32 L41 38" stroke="#3a3226" stroke-width="2.4"/>
<circle cx="32" cy="32" r="2.6" fill="#c04030"/>""",
	"haunted/wall": """<rect width="64" height="64" fill="#3f4548"/>
<path d="M0 0 H64 L57 7 H7 L7 57 L0 64 Z" fill="#4f5558"/>
<path d="M64 0 V64 H0 L7 57 H57 V7 Z" fill="#2f3538"/>
<path d="M7 7 H57 V18 H7 Z" fill="#474d50"/>
<path d="M26 30 L38 30 L38 50 L26 50 Z" fill="#22282a"/>
<path d="M26 30 Q32 24 38 30" fill="#22282a"/>
<g fill="#5c7a54" opacity="0.9">
<circle cx="12" cy="52" r="4"/><circle cx="18" cy="55" r="3"/><circle cx="52" cy="12" r="3.4"/><circle cx="47" cy="9" r="2.4"/>
</g>
<path d="M14 22 L20 28" stroke="#2f3538" stroke-width="1.8" fill="none"/>""",
	"haunted/brick": """<g>
<path d="M16 58 L16 24 Q16 10 32 10 Q48 10 48 24 L48 58 Z" fill="#9aa0a2"/>
<path d="M20 58 L20 25 Q20 14 32 13 L32 58 Z" fill="#b0b6b8"/>
<path d="M16 58 L48 58 L48 54 L16 54 Z" fill="#7e8486"/>
<g fill="#5f6567">
<rect x="25" y="24" width="14" height="3" rx="1.5"/><rect x="27" y="31" width="10" height="3" rx="1.5"/><rect x="28" y="38" width="8" height="2.4" rx="1.2"/>
</g>
<path d="M40 44 L44 48" stroke="#6e7476" stroke-width="1.6" fill="none"/>
<g fill="#4c7a44">
<ellipse cx="18" cy="57" rx="5" ry="3"/><ellipse cx="46" cy="57" rx="4" ry="2.6"/>
</g>
</g>""",
	"cloud/wall": """<rect width="64" height="64" fill="#88bce4"/>
<rect x="18" y="10" width="28" height="44" fill="#e8c860"/>
<rect x="22" y="10" width="8" height="44" fill="#f4dc88"/>
<rect x="12" y="4" width="40" height="10" rx="3" fill="#f4dc88"/>
<rect x="12" y="50" width="40" height="10" rx="3" fill="#d8b850"/>
<g fill="#ffffff" opacity="0.9">
<circle cx="12" cy="34" r="7"/><circle cx="20" cy="38" r="6"/><circle cx="52" cy="24" r="7"/><circle cx="45" cy="28" r="5"/>
</g>""",
	"cloud/brick": """<g opacity="0.96">
<circle cx="20" cy="38" r="12" fill="#ffffff"/>
<circle cx="34" cy="30" r="15" fill="#ffffff"/>
<circle cx="47" cy="39" r="10" fill="#ffffff"/>
<rect x="12" y="38" width="42" height="12" rx="6" fill="#ffffff"/>
<circle cx="22" cy="33" r="7" fill="#f2f8fe"/><circle cx="35" cy="24" r="9" fill="#f2f8fe"/>
<path d="M13 48 Q32 55 53 47" fill="none" stroke="#c4d8ea" stroke-width="3"/>
<circle cx="49" cy="20" r="2.2" fill="#f5d867"/><circle cx="14" cy="26" r="1.8" fill="#f5d867"/>
</g>""",
	"neon/wall": """<rect width="64" height="64" fill="#181a24"/>
<rect x="8" y="4" width="48" height="56" fill="#232636"/>
<g fill="#2e3244">
<rect x="14" y="10" width="10" height="8"/><rect x="28" y="10" width="10" height="8"/><rect x="42" y="10" width="8" height="8"/>
<rect x="14" y="24" width="10" height="8"/><rect x="28" y="24" width="10" height="8"/><rect x="42" y="24" width="8" height="8"/>
<rect x="14" y="38" width="10" height="8"/><rect x="28" y="38" width="10" height="8"/><rect x="42" y="38" width="8" height="8"/>
</g>
<g fill="#57e6ff">
<rect x="30" y="12" width="6" height="4"/><rect x="16" y="40" width="6" height="4"/>
</g>
<g fill="#ff4fd8">
<rect x="44" y="26" width="4" height="4"/><rect x="30" y="40" width="6" height="4"/>
</g>
<rect x="8" y="52" width="48" height="4" fill="#12141c"/>""",
	"neon/brick": """<rect x="6" y="10" width="52" height="44" rx="8" fill="#1c1428"/>
<rect x="6" y="10" width="52" height="44" rx="8" fill="none" stroke="#ff4fd8" stroke-width="3"/>
<rect x="10" y="14" width="44" height="36" rx="6" fill="none" stroke="#ff9aec" stroke-width="1.4" opacity="0.8"/>
<path d="M20 40 L26 24 L32 40 M22.5 34 L29.5 34" fill="none" stroke="#57e6ff" stroke-width="3"/>
<path d="M38 24 L38 40 M38 24 Q46 24 46 30 Q46 34 38 34 L46 40" fill="none" stroke="#57e6ff" stroke-width="3"/>
<circle cx="14" cy="18" r="1.6" fill="#ff9aec"/><circle cx="50" cy="46" r="1.6" fill="#9af2ff"/>""",
	"pirate/wall": """<rect width="64" height="64" fill="#4a3522"/>
<g fill="#5c4229">
<rect x="0" y="0" width="64" height="15"/><rect x="0" y="17" width="64" height="14"/><rect x="0" y="33" width="64" height="14"/><rect x="0" y="49" width="64" height="15"/>
</g>
<g fill="#3f2c1a">
<rect x="0" y="14" width="64" height="3"/><rect x="0" y="30" width="64" height="3"/><rect x="0" y="46" width="64" height="3"/>
</g>
<circle cx="32" cy="32" r="9" fill="#c8a040"/>
<circle cx="32" cy="32" r="6" fill="#2c5c74"/>
<g fill="#8a6a3c">
<circle cx="10" cy="8" r="1.6"/><circle cx="54" cy="8" r="1.6"/><circle cx="10" cy="56" r="1.6"/><circle cx="54" cy="56" r="1.6"/>
</g>""",
	"sea/wall": """<rect x="2" y="2" width="60" height="60" fill="#6b4a2e" rx="3"/>
<path d="M2 2 H62 L56 8 H8 L8 56 L2 62 Z" fill="#8a6238"/>
<path d="M62 2 V62 H2 L8 56 H56 V8 Z" fill="#4a3220"/>
<g fill="#5a3f26">
<rect x="10" y="10" width="44" height="6"/><rect x="10" y="29" width="44" height="6"/><rect x="10" y="48" width="44" height="6"/>
</g>
<g fill="#3a2818">
<rect x="18" y="10" width="4" height="44"/><rect x="42" y="10" width="4" height="44"/>
</g>
<g fill="#c8b088"><circle cx="14" cy="13" r="1.6"/><circle cx="50" cy="13" r="1.6"/><circle cx="14" cy="51" r="1.6"/><circle cx="50" cy="51" r="1.6"/></g>""",
	"sea/brick": """<ellipse cx="32" cy="58" rx="18" ry="3" fill="#000" opacity="0.2"/>
<path d="M14 12 Q10 32 14 54 Q32 60 50 54 Q54 32 50 12 Q32 6 14 12 Z" fill="#a5763f" stroke="#5a3f22" stroke-width="2.4"/>
<path d="M18 14 Q15 32 18 52 Q24 55 30 55 L30 11 Q23 12 18 14 Z" fill="#c0925a"/>
<g fill="#3f3a34"><rect x="10" y="18" width="44" height="5" rx="2.5"/><rect x="10" y="41" width="44" height="5" rx="2.5"/></g>
<g fill="#55504a"><rect x="10" y="18" width="44" height="2" rx="1"/><rect x="10" y="41" width="44" height="2" rx="1"/></g>
<path d="M24 12 L24 54 M32 11 L32 55 M40 12 L40 54" stroke="#7a5230" stroke-width="1.6" opacity="0.6"/>""",
	"pirate/brick": """<g>
<path d="M14 14 Q10 32 14 52 Q32 58 50 52 Q54 32 50 14 Q32 8 14 14 Z" fill="#a5763f"/>
<path d="M18 16 Q15 32 18 50 Q24 53 30 53 L30 12 Q23 13 18 16 Z" fill="#b8894e"/>
<g fill="#3f3a36">
<rect x="10" y="18" width="44" height="5" rx="2.5"/><rect x="10" y="42" width="44" height="5" rx="2.5"/>
</g>
<g fill="#55504c">
<rect x="10" y="18" width="44" height="2" rx="1"/><rect x="10" y="42" width="44" height="2" rx="1"/>
</g>
<g fill="none" stroke="#8a6234" stroke-width="1.6">
<path d="M24 12 L24 52"/><path d="M32 11 L32 53"/><path d="M42 12 L42 52"/>
</g>
</g>""",
}
