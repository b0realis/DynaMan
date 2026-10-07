extends Node
## Settings — battle setup, options, and the 4-player input map
## (autoload "Settings", first). Pattern shared with a sibling game: every
## option is a property whose setter applies immediately and schedules a
## debounced save to user://dynaman.cfg.
##
## Input: four keyboard clusters (docs/DESIGN.md) plus, for each player,
## the matching gamepad (device N-1): d-pad / left stick + button A.
## Registered in code so the help screen and the bindings stay one table.

signal changed

const SAVE_PATH := "user://dynaman.cfg"
const SECTION := "settings"
const SAVE_DEBOUNCE_S := 0.5


## The build split (v8.7): the BLASTALAR binary (custom feature
## "blastalar") is the story game — its front door is the Blastalar
## gate, and "back to menu" everywhere must return THERE, never to the
## battle menu it doesn't ship.
static func is_blastalar_build() -> bool:
	return OS.has_feature("blastalar")


static func menu_scene() -> String:
	return "res://scenes/blastalar_gate.tscn" if is_blastalar_build() \
		else "res://scenes/startup.tscn"

## DEFAULT keyboard clusters per player: [up, left, down, right, bomb].
## Since v10.0 these are only the factory setting — the live table is
## _player_keys (rebindable in OPTIONS → CONTROLS, persisted).
const PLAYER_KEYS := [
	[KEY_W, KEY_A, KEY_S, KEY_D, KEY_SPACE],
	[KEY_UP, KEY_LEFT, KEY_DOWN, KEY_RIGHT, KEY_CTRL],
	[KEY_I, KEY_J, KEY_K, KEY_L, KEY_O],
	[KEY_KP_8, KEY_KP_4, KEY_KP_5, KEY_KP_6, KEY_KP_0],
]
const KEY_SLOT_NAMES := ["Up", "Left", "Down", "Right", "Bomb"]
## Menu/system keys.
const SYSTEM_ACTIONS := {
	"pause": [KEY_ESCAPE],
	"restart": [KEY_R],
	"quit_to_menu": [KEY_Q],
	"menu_confirm": [KEY_ENTER, KEY_KP_ENTER],
	"help": [KEY_H],  # held in battle: the quick-help overlay (v6.1)
}

## GAMEPADS (v12.5) — all remappable in OPTIONS → CONTROLS, persisted:
## which pad drives each player (claimed by pressing a button on it),
## each player's bomb button, the shared system buttons (any pad), and
## the stick dead zone. A binding "code" is a JoyButton (0-20) or, for
## the analog triggers, PAD_TRIGGER + JoyAxis (LT/RT bomb like a button).
const PAD_TRIGGER := 100
const PAD_NONE := 1000   # a device number no pad ever has: "this seat has no pad"
const PAD_SYSTEM_DEFAULTS := {"pause": JOY_BUTTON_START,
	"quit_to_menu": JOY_BUTTON_BACK, "restart": JOY_BUTTON_Y}
const PAD_SYSTEM_NAMES := {"pause": "Pause", "quit_to_menu": "Quit to menu",
	"restart": "Rematch"}
const PAD_MOVE := [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_LEFT,
	JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_RIGHT]
const STICK_DEADZONE_RANGE := Vector2(0.05, 0.6)
const PAD_BUTTON_NAMES := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "BACK", JOY_BUTTON_GUIDE: "GUIDE", JOY_BUTTON_START: "START",
	JOY_BUTTON_LEFT_STICK: "L-STICK", JOY_BUTTON_RIGHT_STICK: "R-STICK",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_DPAD_UP: "D-UP", JOY_BUTTON_DPAD_DOWN: "D-DOWN",
	JOY_BUTTON_DPAD_LEFT: "D-LEFT", JOY_BUTTON_DPAD_RIGHT: "D-RIGHT",
	JOY_BUTTON_MISC1: "MISC", JOY_BUTTON_PADDLE1: "PADDLE 1",
	JOY_BUTTON_PADDLE2: "PADDLE 2", JOY_BUTTON_PADDLE3: "PADDLE 3",
	JOY_BUTTON_PADDLE4: "PADDLE 4", JOY_BUTTON_TOUCHPAD: "TOUCHPAD",
}


static func pad_code_name(code: int) -> String:
	if code == PAD_TRIGGER + JOY_AXIS_TRIGGER_LEFT:
		return "LT"
	if code == PAD_TRIGGER + JOY_AXIS_TRIGGER_RIGHT:
		return "RT"
	return PAD_BUTTON_NAMES.get(code, "BUTTON %d" % code)


static func _pad_code_ok(code: int) -> bool:
	return (code >= 0 and code < JOY_BUTTON_SDL_MAX and not PAD_MOVE.has(code)) \
		or code == PAD_TRIGGER + JOY_AXIS_TRIGGER_LEFT \
		or code == PAD_TRIGGER + JOY_AXIS_TRIGGER_RIGHT


func pad_device(p: int) -> int:
	return int(_pad_device[clampi(p, 0, 3)])


## The pad driving seat p right now: its claim if connected, else the
## seat-order fallback (v12.6). Rumble and the help texts use this.
func pad_live(p: int) -> int:
	return int(_pad_live[clampi(p, 0, 3)])


## Claims are device numbers, and Godot hands out the lowest free number
## to each pad as it connects — so a claim can point at a pad that isn't
## there (a Deck whose external pad was claimed as P1 woke up with its
## own controls driving P2 and P1 dead). Seats in order take their claim
## if it's connected and still free, else the lowest connected free pad.
## With no pads connected at all, the claims stand as they are.
func _resolve_live_pads() -> void:
	var connected := Input.get_connected_joypads()
	connected.sort()
	if connected.is_empty():
		_pad_live = _pad_device.duplicate()
		return
	var claims := {}
	for c: Variant in _pad_device:
		claims[int(c)] = true
	var taken := {}
	var live := [-1, -1, -1, -1]
	# Seat order wins: P1 is resolved first, so a solo player is never left
	# padless while a higher seat holds the only pad that's there.
	for p in 4:
		var c := int(_pad_device[p])
		if connected.has(c) and not taken.has(c):
			live[p] = c
			taken[c] = true
			continue
		var pick := -1
		for d: int in connected:          # a spare pad nobody claimed first…
			if not taken.has(d) and not claims.has(d):
				pick = d
				break
		if pick < 0:
			for d: int in connected:      # …else the lowest pad still free
				if not taken.has(d):
					pick = d
					break
		if pick >= 0:
			live[p] = pick
			taken[pick] = true
		elif not taken.has(c):
			live[p] = c                   # nothing left: absent stays absent
		else:
			live[p] = PAD_NONE + p        # never two seats on one pad
	_pad_live = live


func pad_bomb(p: int) -> int:
	return int(_pad_bomb[clampi(p, 0, 3)])


func pad_system(action: String) -> int:
	return int(_pad_system.get(action, PAD_SYSTEM_DEFAULTS.get(action, -1)))


## The pad `device` now drives player p; whoever had it takes p's old pad.
func claim_pad(p: int, device: int) -> void:
	p = clampi(p, 0, 3)
	var other := _pad_device.find(device)
	if other >= 0 and other != p:
		_pad_device[other] = _pad_device[p]
	_pad_device[p] = device
	_apply_pads()
	_save_and_notify()


## Player p's bomb button. "" on success, else the refusal to show.
func set_pad_bomb(p: int, code: int) -> String:
	if PAD_MOVE.has(code):
		return "the d-pad moves — pick another button"
	if not _pad_code_ok(code):
		return "that control can't be bound"
	for a: String in _pad_system:
		if int(_pad_system[a]) == code:
			return "%s is the %s button" % [pad_code_name(code), PAD_SYSTEM_NAMES[a]]
	_pad_bomb[clampi(p, 0, 3)] = code
	_apply_pads()
	_save_and_notify()
	return ""


## A system button (pause / quit_to_menu / restart), shared by every pad.
func set_pad_system(action: String, code: int) -> String:
	if not PAD_SYSTEM_DEFAULTS.has(action):
		return "unknown action"
	if PAD_MOVE.has(code):
		return "the d-pad moves — pick another button"
	# Triggers are analog: every motion event above the dead zone reads
	# as a fresh press, so PAUSE on RT flickered on and off (v12.6).
	if code >= PAD_TRIGGER:
		return "triggers can only bomb — pick a button"
	if not _pad_code_ok(code):
		return "that control can't be bound"
	for p in 4:
		if int(_pad_bomb[p]) == code:
			return "P%d bombs with %s" % [p + 1, pad_code_name(code)]
	for a: String in _pad_system:
		if a != action and int(_pad_system[a]) == code:
			return "%s already is %s" % [pad_code_name(code), PAD_SYSTEM_NAMES[a]]
	_pad_system[action] = code
	_apply_pads()
	_save_and_notify()
	return ""


## "pad 2 · A" — the help screens' gamepad half for player p.
func pad_text(p: int) -> String:
	if pad_live(p) >= PAD_NONE:
		return "no pad free"
	return "pad %d · %s" % [pad_live(p) + 1, pad_code_name(pad_bomb(p))]


## The shared system button for `action`, by name ("START").
func pad_system_name(action: String) -> String:
	return pad_code_name(pad_system(action))


func reset_pads() -> void:
	_pad_device = [0, 1, 2, 3]
	_pad_bomb = [JOY_BUTTON_A, JOY_BUTTON_A, JOY_BUTTON_A, JOY_BUTTON_A]
	_pad_system = PAD_SYSTEM_DEFAULTS.duplicate()
	_stick_deadzone = 0.2
	_apply_pads()
	_save_and_notify()


var stick_deadzone: float:
	get:
		return _stick_deadzone
	set(v):
		v = clampf(v, STICK_DEADZONE_RANGE.x, STICK_DEADZONE_RANGE.y)
		if is_equal_approx(v, _stick_deadzone):
			return
		_stick_deadzone = v
		_apply_pads()
		_save_and_notify()

## Battle setup ranges (min, max) — sliders in the setup panel clamp here.
## Sizes beyond MULTI_MAX_* need a scrolling camera and are therefore
## single-player-vs-AI only; multiplayer (shared screen) clamps to fit.
const ARENA_W_RANGE := Vector2i(9, 31)
const ARENA_H_RANGE := Vector2i(9, 25)
const MULTI_MAX_W := 21
const MULTI_MAX_H := 17
const ENEMY_RANGE := Vector2i(0, 12)
## Setup presets: name, w, h.
const PRESETS := [["Classic", 15, 13], ["Wide", 21, 11]]

## Default player tints (suit accents, bombs, flames, splash screens).
## Since v3.5 players may pick ANY color via the picker; this palette
## seeds the defaults and migrates old integer-index save files.
const PALETTE: Array[Color] = [Color("f2f2f6"), Color("3c3c48"),
	Color("d84040"), Color("4060d8"), Color("38b048"), Color("e8b020"),
	Color("f070a8"), Color("38b8c8")]

## HUMAN players. 0 is the demo / attract mode (v4.6): no one at the
## keys, `demo_bots` AI bombers battle each other on loop.
var players: int:
	get:
		return _players
	set(v):
		v = clampi(v, 0, 4)
		if v == _players:
			return
		_players = v
		_save_and_notify()

## Bots joining a ONE-human game (v4.6). 0 keeps the classic solo
## arcade hunt (portal under a brick); 1-3 turns solo into a battle
## against AI bombers driven by the mini-boss brain.
var solo_bots: int:
	get:
		return _solo_bots
	set(v):
		v = clampi(v, 0, 3)
		if v == _solo_bots:
			return
		_solo_bots = v
		_save_and_notify()

## Fill the empty seats in a 2- or 3-human battle with AI bombers (v7.6),
## bringing every game up to a full four. 2 humans → 2 bots, 3 humans → 1.
## Off by default; ignored for the 0/1-human modes (those have their own
## bot counts) and for full 4-human games.
var fill_bots: bool:
	get:
		return _fill_bots
	set(v):
		if v == _fill_bots:
			return
		_fill_bots = v
		_save_and_notify()

## Bots in the ZERO-human demo battle (v4.6). At least 2 — a demo of
## one bot pacing an empty arena is not much of a show.
var demo_bots: int:
	get:
		return _demo_bots
	set(v):
		v = clampi(v, 2, 4)
		if v == _demo_bots:
			return
		_demo_bots = v
		_save_and_notify()

## Arena dimensions, forced odd so the pillar pattern works.
var arena_w: int:
	get:
		return _arena_w
	set(v):
		v = _odd(clampi(v, ARENA_W_RANGE.x, ARENA_W_RANGE.y))
		if v == _arena_w:
			return
		_arena_w = v
		_save_and_notify()

var arena_h: int:
	get:
		return _arena_h
	set(v):
		v = _odd(clampi(v, ARENA_H_RANGE.x, ARENA_H_RANGE.y))
		if v == _arena_h:
			return
		_arena_h = v
		_save_and_notify()

## Fraction of eligible cells filled with soft bricks.
var brick_density: float:
	get:
		return _brick_density
	set(v):
		v = clampf(v, 0.1, 0.95)
		if is_equal_approx(v, _brick_density):
			return
		_brick_density = v
		_save_and_notify()

## Fraction of bricks hiding an item.
var bonus_density: float:
	get:
		return _bonus_density
	set(v):
		v = clampf(v, 0.0, 0.6)
		if is_equal_approx(v, _bonus_density):
			return
		_bonus_density = v
		_save_and_notify()

## Fraction of hidden items that are skulls (dangerous).
var danger_share: float:
	get:
		return _danger_share
	set(v):
		v = clampf(v, 0.0, 0.6)
		if is_equal_approx(v, _danger_share):
			return
		_danger_share = v
		_save_and_notify()

var enemy_count: int:
	get:
		return _enemy_count
	set(v):
		v = clampi(v, ENEMY_RANGE.x, ENEMY_RANGE.y)
		if v == _enemy_count:
			return
		_enemy_count = v
		_save_and_notify()

## Round wins needed to take the battle.
var wins_target: int:
	get:
		return _wins_target
	set(v):
		v = clampi(v, 1, 5)
		if v == _wins_target:
			return
		_wins_target = v
		_save_and_notify()

## Lead (in round wins) required on top of wins_target — with margin 2 a
## tied rivalry keeps playing until someone pulls two rounds ahead.
var win_margin: int:
	get:
		return _win_margin
	set(v):
		v = clampi(v, 1, 2)
		if v == _win_margin:
			return
		_win_margin = v
		_save_and_notify()

func player_color(i: int) -> Color:
	return _player_colors[clampi(i, 0, 3)]


## Per-seat bomb style (v8.9): "global" follows OPTIONS → Bomb style,
## anything else is that seat's own costume. Raw value, for the UI.
func player_bomb_style(i: int) -> String:
	return _player_bomb_styles[clampi(i, 0, 3)]


func set_player_bomb_style(i: int, style: String) -> void:
	if style != "global" and not BomberArt.BOMB_STYLES.has(style):
		style = "global"
	_player_bomb_styles[clampi(i, 0, 3)] = style
	_save_and_notify()


## ---- rebindable keyboard (v10.0) -------------------------------------
## The live key table, InputMap sync, and the rebind API. Keys are
## PHYSICAL keycodes (layout-independent), like the registration always
## used. Gamepads stay fixed: pad N drives player N.

func player_key(p: int, d: int) -> int:
	return int(_player_keys[clampi(p, 0, 3)][clampi(d, 0, 4)])


## Physical -> layout keycode for DISPLAY (falls back to the physical
## code under the headless server, which cannot map).
static func key_label_code(physical: int) -> int:
	if DisplayServer.get_name() == "headless":
		return physical
	# Keypad keys stay themselves: the layout mapper turns KP_8 into
	# "Up" — indistinguishable from the arrow cluster on screen.
	if OS.get_keycode_string(physical as Key).begins_with("Kp"):
		return physical
	var mapped := DisplayServer.keyboard_get_keycode_from_physical(physical as Key)
	return mapped if mapped != KEY_NONE else physical


## Which binding already uses `keycode`? "" = free.
func key_owner(keycode: int, skip_p: int, skip_d: int) -> String:
	for p in 4:
		for d in 5:
			if p == skip_p and d == skip_d:
				continue
			if int(_player_keys[p][d]) == keycode:
				return "P%d %s" % [p + 1, KEY_SLOT_NAMES[d]]
	return ""


func reserved_key(keycode: int) -> bool:
	if keycode == KEY_F11:
		return true   # the fullscreen hotkey (v10.3)
	for a: String in SYSTEM_ACTIONS:
		if (SYSTEM_ACTIONS[a] as Array).has(keycode):
			return true
	return false


## Bind. Returns "" on success, or the human-readable refusal.
func set_player_key(p: int, d: int, keycode: int) -> String:
	# Physical code only: the system actions are bound by physical
	# position, so the printed label is irrelevant to a clash — testing
	# it refused an AZERTY player's own default Left (physical A reads
	# "Q") and Dvorak's P3 defaults, with no way back but RESET.
	if reserved_key(keycode):
		return "that key is a system key (ESC/R/Q/H/Enter)"
	var owner := key_owner(keycode, p, d)
	if not owner.is_empty():
		return "already used by " + owner
	_player_keys[clampi(p, 0, 3)][clampi(d, 0, 4)] = keycode
	_apply_player_keys()
	_save_and_notify()
	return ""


func reset_player_keys() -> void:
	for p in 4:
		for d in 5:
			_player_keys[p][d] = PLAYER_KEYS[p][d]
	_apply_player_keys()
	_save_and_notify()


## The help screens' live one-liner ("W A S D  +  Space").
func player_key_text(p: int) -> String:
	var k: Array = _player_keys[clampi(p, 0, 3)]
	var names: Array = []
	for d in 5:
		names.append(OS.get_keycode_string(key_label_code(int(k[d]))))
	return "%s %s %s %s  +  %s" % names


## Swap the keyboard events of every p*_ action for the live table
## (joypad events stay put).
func _apply_player_keys() -> void:
	var dir_names := ["up", "left", "down", "right", "bomb"]
	for p in 4:
		for d in 5:
			var action := "p%d_%s" % [p + 1, dir_names[d]]
			for ev: InputEvent in InputMap.action_get_events(action):
				if ev is InputEventKey:
					InputMap.action_erase_event(action, ev)
			var key := InputEventKey.new()
			key.physical_keycode = _player_keys[p][d] as Key
			InputMap.action_add_event(action, key)


## Fullscreen hotkey (v10.0): F11 or Alt+Enter, anywhere, any binary.
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if k.keycode == KEY_F11 \
				or ((k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER)
					and k.alt_pressed):
			fullscreen = not fullscreen
			get_viewport().set_input_as_handled()


## The style a bomb OWNED BY seat i actually wears — monsters (owner
## -1) and the "global" seats follow the OPTIONS choice.
func bomb_style_for(i: int) -> String:
	if i < 0 or i > 3:
		return _bomb_style
	var s: String = _player_bomb_styles[i]
	return _bomb_style if s == "global" else s


## Any color goes (alpha forced opaque — no invisible bombers).
func set_player_color(i: int, col: Color) -> void:
	col.a = 1.0
	_player_colors[clampi(i, 0, 3)] = col
	_save_and_notify()


## Round timer, seconds (one arena).
var round_time: int:
	get:
		return _round_time
	set(v):
		v = clampi(v, 60, 300)
		if v == _round_time:
			return
		_round_time = v
		_save_and_notify()


## Max simultaneous bomber mini-bosses in single player (spawn rolls
## AND portal summons both respect this cap). Default 1; raise for spice.
var max_bosses: int:
	get:
		return _max_bosses
	set(v):
		v = clampi(v, 1, 5)
		if v == _max_bosses:
			return
		_max_bosses = v
		_save_and_notify()

var sfx_on: bool:
	get:
		return _sfx_on
	set(v):
		if v == _sfx_on:
			return
		_sfx_on = v
		_save_and_notify()

var sfx_volume: float:
	get:
		return _sfx_volume
	set(v):
		v = clampf(v, 0.0, 1.0)
		if is_equal_approx(v, _sfx_volume):
			return
		_sfx_volume = v
		_save_and_notify()

var music_on: bool:
	get:
		return _music_on
	set(v):
		if v == _music_on:
			return
		_music_on = v
		_save_and_notify()

var music_volume: float:
	get:
		return _music_volume
	set(v):
		v = clampf(v, 0.0, 1.0)
		if is_equal_approx(v, _music_volume):
			return
		_music_volume = v
		_save_and_notify()

## Little P1..P4 tags above the bombers (v10.0) — multiplayer only,
## for couches where two players picked near-twin colours. Off by
## default: the purists see nothing new.
var player_tags: bool:
	get:
		return _player_tags
	set(v):
		if v == _player_tags:
			return
		_player_tags = v
		_save_and_notify()

var fullscreen: bool:
	get:
		return _fullscreen
	set(v):
		if v == _fullscreen:
			return
		_fullscreen = v
		_apply_fullscreen()
		_save_and_notify()

## Sudden death (v4.5): in the last 45 s of a multiplayer round,
## pressure blocks spiral in from the border and crush everything.
## Off by default — it changes how endgames feel.
var pressure_on: bool:
	get:
		return _pressure_on
	set(v):
		if v == _pressure_on:
			return
		_pressure_on = v
		_save_and_notify()


## Arena tile skin (v4.8) — one of TileArt.SKINS. Walls, bricks and
## the floor checker all re-theme; applied at every board build.
var arena_skin: String:
	get:
		return _arena_skin
	set(v):
		if not TileArt.has_skin(v):
			v = "classic"
		if v == _arena_skin:
			return
		_arena_skin = v
		_save_and_notify()


## Bomb look (v5.1) — one of BomberArt.BOMB_STYLES. Pure cosmetics:
## fuse, blast and kick behave identically in every costume.
var bomb_style: String:
	get:
		return _bomb_style
	set(v):
		if not BomberArt.BOMB_STYLES.has(v):
			v = "classic"
		if v == _bomb_style:
			return
		_bomb_style = v
		_save_and_notify()


## ARENA THEME MAKER transients (v9.8) — never persisted. try_theme
## sends the next battle out wearing the UNSAVED bench recipe (see
## TileArt.BENCH_ID) and routes the return back into the maker;
## maker_edit_id and maker_locks carry the bench session across the
## scene change.
var try_theme := false
var maker_edit_id := ""
var maker_locks: Dictionary = {}
var attract_demo := false   # transient: this battle is the menu-idle
							# attract loop — any key returns to the menu
var maker_bench_raw: Dictionary = {}  # the bench recipe EXACTLY as the
							# user left it — TRY IT's legibility nudge
							# must not write back to the bench (v10.4)

## THE MEDICINE CABINET (v11.0) — transient, NEVER persisted: the magic
## word must be typed again every launch, and every bottle seals itself
## when the process ends. Cheats are DynaMan battle toys only — they
## sit out story battles and the attract demo.
var cabinet_unlocked := false        # typed PLACEBO (or the pad code)
var cheats: Dictionary = {}          # id -> true while the bottle is open


func cheat(id: String) -> bool:
	return not attract_demo and not Story.active \
		and bool(cheats.get(id, false))


func any_cheat() -> bool:
	for id: String in cheats:
		if cheat(id):
			return true
	return false

## Menu attract mode (v10.1): seconds of MENU idleness before the demo
## battle starts on its own, arcade-style. 0 = off (the default).
var attract_idle: int:
	get:
		return _attract_idle
	set(v):
		v = clampi(v, 0, 600)
		if v == _attract_idle:
			return
		_attract_idle = v
		_save_and_notify()

## What the Random-arena die draws from (v9.8): "all" (built-ins +
## your themes), "builtin" (the shipped 50), "mine" (your themes only;
## falls back to all while you have none).
var arena_random_scope: String:
	get:
		return _arena_random_scope
	set(v):
		if not ["all", "builtin", "mine"].has(v):
			v = "all"
		if v == _arena_random_scope:
			return
		_arena_random_scope = v
		_save_and_notify()

## Revenge (v10.2): the fallen ride the border rim and lob bombs back
## in — nobody waits out a multiplayer round on the couch.
var revenge_mode: bool:
	get:
		return _revenge_mode
	set(v):
		if v == _revenge_mode:
			return
		_revenge_mode = v
		_save_and_notify()

## Seat-bot skill (v10.2). "hard" is the classic planner brain, and the
## default — existing games feel identical.
var bot_skill: String:
	get:
		return _bot_skill
	set(v):
		if not ["easy", "normal", "hard"].has(v):
			v = "hard"
		if v == _bot_skill:
			return
		_bot_skill = v
		_save_and_notify()

## 2v2 pairing (v10.2): 0 = free-for-all; 1-3 = the three ways four
## bombers split into teams. Needs exactly four bombers in the round.
const TEAM_MASKS := [[0, 0, 1, 1], [0, 1, 0, 1], [0, 1, 1, 0]]
const TEAM_LABELS := ["Off", "P1+P2 vs P3+P4", "P1+P3 vs P2+P4",
	"P1+P4 vs P2+P3"]
var team_mode: int:
	get:
		return _team_mode
	set(v):
		v = clampi(v, 0, 3)
		if v == _team_mode:
			return
		_team_mode = v
		_save_and_notify()


func team_of(seat: int) -> int:
	if _team_mode <= 0:
		return -1
	return TEAM_MASKS[_team_mode - 1][clampi(seat, 0, 3)]


## Random arena skin (v4.9): every round redraws the world in a
## random tile skin — arena_skin is ignored while this is on.
var arena_random: bool:
	get:
		return _arena_random
	set(v):
		if v == _arena_random:
			return
		_arena_random = v
		_save_and_notify()


## Beginner aid (v6.3, default OFF): faint pulsing tiles mark every
## cell a ticking bomb will reach — where NOT to be standing.
var blast_hint: bool:
	get:
		return _blast_hint
	set(v):
		if v == _blast_hint:
			return
		_blast_hint = v
		_save_and_notify()


## Board kick on every explosion; off for motion-sensitive players.
var screen_shake: bool:
	get:
		return _screen_shake
	set(v):
		if v == _screen_shake:
			return
		_screen_shake = v
		_save_and_notify()

## One-shot: game scene sets it so the menu skips the studio splash.
var skip_splash_once := false

var _players := 2
var _solo_bots := 0
var _fill_bots := false
var _demo_bots := 4
var _arena_w := 15
var _arena_h := 13
var _brick_density := 0.75
var _bonus_density := 0.25
var _danger_share := 0.2
var _enemy_count := 3
var _wins_target := 3
var _win_margin := 1
var _round_time := 150
var _max_bosses := 1
var _player_colors: Array = [PALETTE[0], PALETTE[1], PALETTE[2], PALETTE[3]]
var _player_bomb_styles: Array = ["global", "global", "global", "global"]
var _sfx_on := true
var _sfx_volume := 0.8
var _music_on := true
var _music_volume := 0.5
var _fullscreen := false
var _player_tags := false
var _pad_device: Array = [0, 1, 2, 3]
## The pad ACTUALLY driving each seat right now (see _resolve_live_pads):
## the claimed one when it's connected, else a fallback — never saved.
var _pad_live: Array = [0, 1, 2, 3]
var _pad_bomb: Array = [JOY_BUTTON_A, JOY_BUTTON_A, JOY_BUTTON_A, JOY_BUTTON_A]
var _pad_system: Dictionary = PAD_SYSTEM_DEFAULTS.duplicate()
var _stick_deadzone := 0.2   # the engine's own default — same feel as before
var _player_keys: Array = [PLAYER_KEYS[0].duplicate(),
	PLAYER_KEYS[1].duplicate(), PLAYER_KEYS[2].duplicate(),
	PLAYER_KEYS[3].duplicate()]
var _screen_shake := true
var _arena_skin := "classic"
var _arena_random := false
var _arena_random_scope := "all"
var _attract_idle := 0
var _revenge_mode := false
var _bot_skill := "hard"
var _team_mode := 0
var _bomb_style := "classic"
var _blast_hint := false
var _pressure_on := false
var _save_timer: SceneTreeTimer


func _ready() -> void:
	# F11 / Alt+Enter must work while a battle's tree is paused (v12.6).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_actions()
	_register_ui_joypad()
	# Handhelds (v12.4): the Steam Deck launcher sets DYNAMAN_HANDHELD, so a
	# setting the player has never saved opens on the device's default —
	# full screen. A choice made in OPTIONS is saved and wins from then on.
	if not OS.get_environment("DYNAMAN_HANDHELD").is_empty():
		_fullscreen = true
	_load()
	# `--fullscreen` / `-f` on the command line wins over a saved "off"
	# (v12.6: _apply_fullscreen used to undo it at once).
	var args := OS.get_cmdline_args()
	if args.has("--fullscreen") or args.has("-f"):
		_fullscreen = true
	_apply_fullscreen()
	_fit_window_to_screen()
	# Pads come and go: re-resolve which pad drives which seat (v12.6).
	Input.joy_connection_changed.connect(func(_d: int, _c: bool) -> void:
		_apply_pads())


func _exit_tree() -> void:
	if _save_timer != null:
		_save()


## Make the MENUS fully gamepad-navigable (v6.5): the built-in ui_*
## actions get d-pad + left stick + A/B events from pad 0 if they
## don't have joypad events already. Any pad can drive the menu.
func _register_ui_joypad() -> void:
	var wire := {
		"ui_up": [JOY_BUTTON_DPAD_UP, JOY_AXIS_LEFT_Y, -1.0],
		"ui_down": [JOY_BUTTON_DPAD_DOWN, JOY_AXIS_LEFT_Y, 1.0],
		"ui_left": [JOY_BUTTON_DPAD_LEFT, JOY_AXIS_LEFT_X, -1.0],
		"ui_right": [JOY_BUTTON_DPAD_RIGHT, JOY_AXIS_LEFT_X, 1.0],
	}
	for action: String in wire:
		var has_joy := false
		for ev: InputEvent in InputMap.action_get_events(action):
			if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
				has_joy = true
				break
		if has_joy:
			continue
		var jb := InputEventJoypadButton.new()
		jb.device = -1
		jb.button_index = wire[action][0]
		InputMap.action_add_event(action, jb)
		var jm := InputEventJoypadMotion.new()
		jm.device = -1
		jm.axis = wire[action][1]
		jm.axis_value = wire[action][2]
		InputMap.action_add_event(action, jm)
	for pair: Array in [["ui_accept", JOY_BUTTON_A], ["ui_cancel", JOY_BUTTON_B]]:
		var has := false
		for ev: InputEvent in InputMap.action_get_events(pair[0]):
			if ev is InputEventJoypadButton:
				has = true
				break
		if not has:
			var b := InputEventJoypadButton.new()
			b.device = -1
			b.button_index = pair[1]
			InputMap.action_add_event(pair[0], b)


## "p1_up".."p4_bomb" plus system actions.
func _register_actions() -> void:
	var dir_names := ["up", "left", "down", "right", "bomb"]
	for p in 4:
		for d in 5:
			var action := "p%d_%s" % [p + 1, dir_names[d]]
			if not InputMap.has_action(action):
				InputMap.add_action(action)
			var key := InputEventKey.new()
			key.physical_keycode = _player_keys[p][d] as Key
			InputMap.action_add_event(action, key)
	for action: String in SYSTEM_ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for keycode: int in SYSTEM_ACTIONS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = keycode as Key
			InputMap.action_add_event(action, ev)
	_apply_pads()


## Rebuild every gamepad binding from the live tables (v12.5). Each
## player's pad (_pad_device) drives its d-pad + left stick (dead zone
## _stick_deadzone) and its bomb code; the system actions answer ANY pad
## (device -1) — a pad-only couch must be able to pause, quit and
## rematch (v11.8: START / BACK / Y by default).
func _apply_pads() -> void:
	_resolve_live_pads()
	var dir_names := ["up", "left", "down", "right", "bomb"]
	for p in 4:
		var dev := int(_pad_live[p])
		for d in 5:
			var action := "p%d_%s" % [p + 1, dir_names[d]]
			if not InputMap.has_action(action):
				continue
			_erase_pad_events(action)
			if d == 4:
				InputMap.action_add_event(action, _pad_event(int(_pad_bomb[p]), dev))
				InputMap.action_set_deadzone(action, 0.5)  # a trigger bombs at half-pull
				continue
			var pad := InputEventJoypadButton.new()
			pad.device = dev
			pad.button_index = PAD_MOVE[d] as JoyButton
			InputMap.action_add_event(action, pad)
			var stick := InputEventJoypadMotion.new()
			stick.device = dev
			stick.axis = JOY_AXIS_LEFT_Y if (d == 0 or d == 2) else JOY_AXIS_LEFT_X
			stick.axis_value = -1.0 if (d == 0 or d == 1) else 1.0
			InputMap.action_add_event(action, stick)
			InputMap.action_set_deadzone(action, _stick_deadzone)
	for action: String in PAD_SYSTEM_DEFAULTS:
		if InputMap.has_action(action):
			_erase_pad_events(action)
			InputMap.action_add_event(action, _pad_event(pad_system(action), -1))


func _erase_pad_events(action: String) -> void:
	for ev: InputEvent in InputMap.action_get_events(action):
		if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
			InputMap.action_erase_event(action, ev)


static func _pad_event(code: int, device: int) -> InputEvent:
	if code >= PAD_TRIGGER:
		var m := InputEventJoypadMotion.new()
		m.device = device
		m.axis = (code - PAD_TRIGGER) as JoyAxis
		m.axis_value = 1.0
		return m
	var b := InputEventJoypadButton.new()
	b.device = device
	b.button_index = code as JoyButton
	return b


func _odd(v: int) -> int:
	return v if v % 2 == 1 else v - 1


func _headless() -> bool:
	return DisplayServer.get_name() == "headless"


## A 1280x720 window on a smaller screen (an 800x480 Pi panel) used to
## open larger than the display: shrink it to fit, keeping 16:9, and
## centre it (v12.6). Full screen needs nothing.
func _fit_window_to_screen() -> void:
	if _headless() or _fullscreen:
		return
	var scr := DisplayServer.window_get_current_screen()
	var usable := DisplayServer.screen_get_usable_rect(scr)
	var win := DisplayServer.window_get_size()
	if usable.size.x <= 0 or (win.x <= usable.size.x and win.y <= usable.size.y):
		return
	var k := minf(float(usable.size.x) / win.x, float(usable.size.y) / win.y) * 0.95
	var fit := Vector2i(int(win.x * k), int(win.y * k))
	DisplayServer.window_set_size(fit)
	DisplayServer.window_set_position(usable.position + (usable.size - fit) / 2)


func _apply_fullscreen() -> void:
	if _headless():
		return
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if _fullscreen
		else DisplayServer.WINDOW_MODE_WINDOWED)


func _load() -> void:
	var cf := ConfigFile.new()
	var err := cf.load(SAVE_PATH)
	if err != OK:
		if FileAccess.file_exists(SAVE_PATH):
			# Unreadable (a power cut mid-write?): keep a copy before the
			# next save writes defaults over it (v12.6, as arenas.cfg does).
			DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE_PATH),
				ProjectSettings.globalize_path(SAVE_PATH + ".bak"))
		return
	_players = clampi(int(cf.get_value(SECTION, "players", _players)), 0, 4)
	_solo_bots = clampi(int(cf.get_value(SECTION, "solo_bots", _solo_bots)), 0, 3)
	_fill_bots = bool(cf.get_value(SECTION, "fill_bots", _fill_bots))
	_demo_bots = clampi(int(cf.get_value(SECTION, "demo_bots", _demo_bots)), 2, 4)
	_arena_w = _odd(clampi(int(cf.get_value(SECTION, "arena_w", _arena_w)),
		ARENA_W_RANGE.x, ARENA_W_RANGE.y))
	_arena_h = _odd(clampi(int(cf.get_value(SECTION, "arena_h", _arena_h)),
		ARENA_H_RANGE.x, ARENA_H_RANGE.y))
	_brick_density = clampf(float(cf.get_value(SECTION, "brick_density", _brick_density)), 0.1, 0.95)
	_bonus_density = clampf(float(cf.get_value(SECTION, "bonus_density", _bonus_density)), 0.0, 0.6)
	_danger_share = clampf(float(cf.get_value(SECTION, "danger_share", _danger_share)), 0.0, 0.6)
	_enemy_count = clampi(int(cf.get_value(SECTION, "enemy_count", _enemy_count)),
		ENEMY_RANGE.x, ENEMY_RANGE.y)
	_wins_target = clampi(int(cf.get_value(SECTION, "wins_target", _wins_target)), 1, 5)
	_win_margin = clampi(int(cf.get_value(SECTION, "win_margin", _win_margin)), 1, 2)
	_round_time = clampi(int(cf.get_value(SECTION, "round_time",
		cf.get_value(SECTION, "match_time", _round_time))), 60, 300)
	_max_bosses = clampi(int(cf.get_value(SECTION, "max_bosses", _max_bosses)), 1, 5)
	var cols: Array = Array(cf.get_value(SECTION, "player_colors", _player_colors))
	if cols.size() == 4:
		for i in 4:
			# Migration: pre-v3.5 saves stored palette indices.
			if cols[i] is Color:
				var c: Color = cols[i]
				c.a = 1.0  # set_player_color's rule: never a see-through bomber
				_player_colors[i] = c
			else:
				_player_colors[i] = PALETTE[clampi(int(cols[i]), 0, PALETTE.size() - 1)]
	_sfx_on = bool(cf.get_value(SECTION, "sfx_on", _sfx_on))
	_sfx_volume = clampf(float(cf.get_value(SECTION, "sfx_volume", _sfx_volume)), 0.0, 1.0)
	_music_on = bool(cf.get_value(SECTION, "music_on", _music_on))
	_music_volume = clampf(float(cf.get_value(SECTION, "music_volume", _music_volume)), 0.0, 1.0)
	_fullscreen = bool(cf.get_value(SECTION, "fullscreen", _fullscreen))
	_screen_shake = bool(cf.get_value(SECTION, "screen_shake", _screen_shake))
	_pressure_on = bool(cf.get_value(SECTION, "pressure_on", _pressure_on))
	_arena_skin = str(cf.get_value(SECTION, "arena_skin", _arena_skin))
	_arena_random = bool(cf.get_value(SECTION, "arena_random", _arena_random))
	_player_tags = bool(cf.get_value(SECTION, "player_tags", _player_tags))
	_attract_idle = clampi(int(cf.get_value(SECTION, "attract_idle", _attract_idle)), 0, 600)
	_revenge_mode = bool(cf.get_value(SECTION, "revenge_mode", _revenge_mode))
	_bot_skill = str(cf.get_value(SECTION, "bot_skill", _bot_skill))
	if not ["easy", "normal", "hard"].has(_bot_skill):
		_bot_skill = "hard"
	_team_mode = clampi(int(cf.get_value(SECTION, "team_mode", _team_mode)), 0, 3)
	var pk: Array = Array(cf.get_value(SECTION, "player_keys", []))
	if pk.size() == 4:
		var pk_ok := true
		for row in pk:
			if not (row is Array) or (row as Array).size() != 5:
				pk_ok = false
		if pk_ok:
			# The conflict-free invariant must hold ON LOAD too (v10.3):
			# garbage, reserved keys or twins in a hand-edited cfg would
			# ghost-drive two players at once. Corrupt = factory reset.
			var seen := {}
			for i in 4:
				for d in 5:
					var kc := int(pk[i][d])
					if kc <= 0 or reserved_key(kc) or seen.has(kc):
						pk_ok = false
					seen[kc] = true
		if pk_ok:
			for i in 4:
				for d in 5:
					_player_keys[i][d] = int(pk[i][d])
		else:
			for i in 4:
				for d in 5:
					_player_keys[i][d] = PLAYER_KEYS[i][d]
		_apply_player_keys()
	_load_pads(cf)
	_arena_random_scope = str(cf.get_value(SECTION, "arena_random_scope", _arena_random_scope))
	if not ["all", "builtin", "mine"].has(_arena_random_scope):
		_arena_random_scope = "all"
	var pbs: Array = Array(cf.get_value(SECTION, "player_bomb_styles",
		_player_bomb_styles))
	for i in mini(pbs.size(), 4):
		var ps := str(pbs[i])
		_player_bomb_styles[i] = ps if ps == "global" \
			or BomberArt.BOMB_STYLES.has(ps) else "global"
	_bomb_style = str(cf.get_value(SECTION, "bomb_style", _bomb_style))
	_blast_hint = bool(cf.get_value(SECTION, "blast_hint", _blast_hint))
	if not BomberArt.BOMB_STYLES.has(_bomb_style):
		_bomb_style = "classic"
	if not TileArt.has_skin(_arena_skin):
		_arena_skin = "classic"


## Gamepad tables from the cfg (v12.5). Each table is validated as a
## whole — a hand-edited twin pad, a d-pad bomb or a system clash falls
## back to the factory table rather than ghost-driving two players.
func _load_pads(cf: ConfigFile) -> void:
	var dev: Variant = cf.get_value(SECTION, "pad_device", [])
	if dev is Array and (dev as Array).size() == 4:
		var seen := {}
		var ok := true
		for v: Variant in dev:
			if not (v is int) or int(v) < 0 or int(v) > 15 or seen.has(int(v)):
				ok = false
			seen[int(v) if v is int else -1] = true
		if ok:
			_pad_device = (dev as Array).duplicate()
	var bombs: Variant = cf.get_value(SECTION, "pad_bomb", [])
	var sys: Variant = cf.get_value(SECTION, "pad_system", {})
	var nb: Array = _pad_bomb.duplicate()
	var ns: Dictionary = _pad_system.duplicate()
	if bombs is Array and (bombs as Array).size() == 4:
		for i in 4:
			var c: Variant = bombs[i]
			if c is int and _pad_code_ok(int(c)):
				nb[i] = int(c)
	if sys is Dictionary:
		for a: String in PAD_SYSTEM_DEFAULTS:
			var c: Variant = (sys as Dictionary).get(a, null)
			if c is int and _pad_code_ok(int(c)) and int(c) < PAD_TRIGGER:
				ns[a] = int(c)
	var clash := false
	var used := {}
	for a: String in ns:
		if used.has(int(ns[a])) or nb.has(int(ns[a])):
			clash = true
		used[int(ns[a])] = true
	if not clash:
		_pad_bomb = nb
		_pad_system = ns
	_stick_deadzone = clampf(float(cf.get_value(SECTION, "stick_deadzone", _stick_deadzone)),
		STICK_DEADZONE_RANGE.x, STICK_DEADZONE_RANGE.y)
	_apply_pads()


func _save() -> void:
	_save_timer = null
	# Start from the file on disk so keys THIS build doesn't know survive —
	# an older build sharing the folder used to erase a newer one's
	# settings on its first save (v12.6).
	var cf := ConfigFile.new()
	cf.load(SAVE_PATH)
	cf.set_value(SECTION, "players", _players)
	cf.set_value(SECTION, "arena_w", _arena_w)
	cf.set_value(SECTION, "arena_h", _arena_h)
	cf.set_value(SECTION, "brick_density", _brick_density)
	cf.set_value(SECTION, "bonus_density", _bonus_density)
	cf.set_value(SECTION, "danger_share", _danger_share)
	cf.set_value(SECTION, "enemy_count", _enemy_count)
	cf.set_value(SECTION, "wins_target", _wins_target)
	cf.set_value(SECTION, "win_margin", _win_margin)
	cf.set_value(SECTION, "round_time", _round_time)
	cf.set_value(SECTION, "max_bosses", _max_bosses)
	cf.set_value(SECTION, "player_colors", _player_colors)
	cf.set_value(SECTION, "sfx_on", _sfx_on)
	cf.set_value(SECTION, "sfx_volume", _sfx_volume)
	cf.set_value(SECTION, "music_on", _music_on)
	cf.set_value(SECTION, "music_volume", _music_volume)
	cf.set_value(SECTION, "fullscreen", _fullscreen)
	cf.set_value(SECTION, "screen_shake", _screen_shake)
	cf.set_value(SECTION, "pressure_on", _pressure_on)
	cf.set_value(SECTION, "arena_skin", _arena_skin)
	cf.set_value(SECTION, "arena_random", _arena_random)
	cf.set_value(SECTION, "arena_random_scope", _arena_random_scope)
	cf.set_value(SECTION, "player_tags", _player_tags)
	cf.set_value(SECTION, "attract_idle", _attract_idle)
	cf.set_value(SECTION, "revenge_mode", _revenge_mode)
	cf.set_value(SECTION, "bot_skill", _bot_skill)
	cf.set_value(SECTION, "team_mode", _team_mode)
	cf.set_value(SECTION, "player_keys", _player_keys)
	cf.set_value(SECTION, "pad_device", _pad_device)
	cf.set_value(SECTION, "pad_bomb", _pad_bomb)
	cf.set_value(SECTION, "pad_system", _pad_system)
	cf.set_value(SECTION, "stick_deadzone", _stick_deadzone)
	cf.set_value(SECTION, "bomb_style", _bomb_style)
	cf.set_value(SECTION, "player_bomb_styles", _player_bomb_styles)
	cf.set_value(SECTION, "blast_hint", _blast_hint)
	cf.set_value(SECTION, "solo_bots", _solo_bots)
	cf.set_value(SECTION, "fill_bots", _fill_bots)
	cf.set_value(SECTION, "demo_bots", _demo_bots)
	# Write beside, then swap in: a crash or power cut mid-write can no
	# longer leave a half-written dynaman.cfg behind (v12.6).
	var tmp := SAVE_PATH + ".tmp"
	var err := cf.save(tmp)
	if err == OK:
		err = DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp),
			ProjectSettings.globalize_path(SAVE_PATH))
	if err != OK:
		push_warning("Settings: could not save %s (error %d)" % [SAVE_PATH, err])


func _save_and_notify() -> void:
	if _save_timer == null:
		_save_timer = get_tree().create_timer(SAVE_DEBOUNCE_S)
		_save_timer.timeout.connect(_save)
	changed.emit()
