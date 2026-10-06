class_name BomberArt
extends RefCounted
## Runtime-tinted bomber sprites. The art lives as SVG *templates*
## (assets/bomber/*.svgt — big head, small body, after the classic look)
## with %COL%/%DARK% accent placeholders; textures are rasterized on
## demand for any chosen player color and cached. One art set serves any
## palette — the tint system costs no extra assets.
##
## Views: "front" (down), "back" (up), "side" (right; flip_h for left),
## frames 0/1 (walk cycle). Canvas is 64×76 px.

const RASTER_SCALE := 2.0  # svg rasterization scale (crisp at ~150 px tall)

static var _cache: Dictionary = {}
static var _templates: Dictionary = {}


## Bomb styles (v5.1): each is its own template with %COL% accents.
const BOMB_STYLES := ["classic", "dynamite", "naval", "aviatic", "acme", "potion"]
const BOMB_LABELS := {"classic": "Classic", "dynamite": "Dynamite trio",
	"naval": "Naval mine", "aviatic": "Aero fin", "acme": "ACME special",
	"potion": "Potion bottle"}


## The player-tinted battle bomb (team accents + tinged spark glow).
static func bomb_texture(col: Color, style := "classic") -> ImageTexture:
	if style == "classic" or not BOMB_STYLES.has(style):
		return texture("bomb", -1, col)
	return texture("bomb_" + style, -1, col)


static func texture(view: String, frame: int, col: Color) -> ImageTexture:
	var key := "%s_%d_%s" % [view, frame, col.to_html(false)]
	if _cache.has(key):
		return _cache[key]
	# frame -1 = frameless template (the bomb).
	var path := "res://assets/bomber/%s.svgt" % view if frame < 0 \
		else "res://assets/bomber/%s_%d.svgt" % [view, frame]
	if not _templates.has(path):
		var f := FileAccess.open(path, FileAccess.READ)
		_templates[path] = f.get_as_text() if f != null else ""
	var svg := (_templates[path] as String) \
		.replace("%COL%", "#" + col.to_html(false)) \
		.replace("%DARK%", "#" + col.darkened(0.35).to_html(false))
	var img := Image.new()
	if img.load_svg_from_string(svg, RASTER_SCALE) != OK:
		push_warning("BomberArt: failed to rasterize " + path)
		img = Image.create(64, 76, false, Image.FORMAT_RGBA8)
	var tex := ImageTexture.create_from_image(img)
	# Growth guard: random boss colours would otherwise accumulate ~7
	# rasterized textures per distinct colour for the whole session.
	# (Boss hues are also quantized main-side; this is the backstop.)
	if _cache.size() > 96:
		_cache.clear()
	_cache[key] = tex
	return tex
