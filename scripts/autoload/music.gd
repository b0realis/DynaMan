extends Node
## Music — generative background (autoload "Music"). Same engine as
## a sibling game's: one synthesized pad note, replayed at scale ratios via
## pitch_scale — but tuned upbeat for a battle game: MAJOR pentatonic,
## quicker notes, a bouncier shorter pad, and a walking bass note.
## Gated by Settings.music_on / music_volume.

const PAD_RATE := 11025
const PAD_DUR := 2.2
const BASE_HZ := 262.0           # C4 root
const MUSIC_DB := -17.0
const POOL_SIZE := 8

## Skin moods (v6.6): the same generative engine, re-tuned per arena
## family. Each mood is a scale (pitch ratios vs the C4 pad), a note
## pace, and a base transposition — small numbers, big atmosphere.
##   classic  C-major pentatonic, the original bounce
##   dark     minor pentatonic a minor third down, slower — lava and lairs
##   cozy     major up high, quick light notes — candy and gardens
##   zen      pentatonic + soft 4th, long silences — temples and ponds
##   desert   phrygian colour (flat 2nd) — sand, bazaars, buccaneers
##   aquatic  lydian shimmer (raised 4th), unhurried — under and on water
##   jazz     dorian lounge, walking pace — the casino wants you relaxed
const MOODS := {
	"classic": {"ratios": [0.5, 0.561, 0.63, 0.749, 0.841,
		1.0, 1.122, 1.26, 1.498, 1.682, 2.0],
		"gap": Vector2(0.9, 1.9), "base": 1.0},
	"dark": {"ratios": [0.5, 0.594, 0.667, 0.749, 0.89,
		1.0, 1.189, 1.335, 1.498, 1.782, 2.0],
		"gap": Vector2(1.2, 2.4), "base": 0.841},
	"cozy": {"ratios": [0.63, 0.749, 0.841, 1.0, 1.122,
		1.26, 1.498, 1.682, 1.888, 2.0],
		"gap": Vector2(0.7, 1.5), "base": 1.189},
	"zen": {"ratios": [0.5, 0.561, 0.667, 0.749, 0.841,
		1.0, 1.122, 1.335, 1.498, 1.682, 2.0],
		"gap": Vector2(1.8, 3.4), "base": 1.0},
	"desert": {"ratios": [0.5, 0.53, 0.63, 0.667, 0.749,
		0.794, 0.944, 1.0, 1.06, 1.26, 1.498],
		"gap": Vector2(1.0, 2.1), "base": 1.0},
	"aquatic": {"ratios": [0.5, 0.561, 0.63, 0.707, 0.749,
		0.841, 0.944, 1.0, 1.122, 1.414, 1.498],
		"gap": Vector2(1.4, 2.6), "base": 1.0},
	"jazz": {"ratios": [0.5, 0.561, 0.594, 0.667, 0.749,
		0.841, 0.891, 1.0, 1.122, 1.189, 1.498],
		"gap": Vector2(0.6, 1.7), "base": 0.944},
}
const BASS_GAP := Vector2(7.0, 13.0)

var _mood := "classic"


## Switch mood (main calls this at round start with the arena skin's
## mood; the menu resets to classic). Safe mid-melody: the note index
## just re-clamps into the new scale.
func set_mood(m: String) -> void:
	if not MOODS.has(m):
		m = "classic"
	if m == _mood:
		return
	_mood = m
	_note_i = clampi(_note_i, 1,
		(MOODS[_mood]["ratios"] as Array).size() - 1)

var _players: Array[AudioStreamPlayer] = []
var _pad: AudioStreamWAV
var _rng := RandomNumberGenerator.new()
var _note_wait := 0.6
var _bass_wait := 0.1
var _note_i := 5


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_pad = _build_pad()
	Settings.changed.connect(_apply_volume)


## Hurry-up hook (v4.5): main flips this in a round's final stretch.
## Notes come roughly twice as fast and a whole step higher — audible
## pressure without needing a second track.
var urgent := false


func _process(delta: float) -> void:
	if not Settings.music_on or Settings.music_volume <= 0.001:
		return
	_note_wait -= delta
	_bass_wait -= delta
	var mood: Dictionary = MOODS[_mood]
	var ratios: Array = mood["ratios"]
	var base: float = mood["base"]
	if _bass_wait <= 0.0:
		_bass_wait = _rng.randf_range(BASS_GAP.x, BASS_GAP.y)
		_play(0.5 * base, 1.5)
	if _note_wait <= 0.0:
		_note_wait = _rng.randf_range((mood["gap"] as Vector2).x,
			(mood["gap"] as Vector2).y) * (0.45 if urgent else 1.0)
		_note_i = clampi(_note_i + _rng.randi_range(-2, 2), 1, ratios.size() - 1)
		_play(float(ratios[_note_i]) * base * (1.125 if urgent else 1.0),
			_rng.randf_range(-4.0, 0.0))


func _play(pitch: float, db_offset: float) -> void:
	var player: AudioStreamPlayer = null
	for p in _players:
		if not p.playing:
			player = p
			break
	if player == null:
		return
	player.stream = _pad
	player.pitch_scale = pitch
	player.set_meta("db_offset", db_offset)  # kept for _apply_volume
	player.volume_db = _db() + db_offset
	player.play()


func _apply_volume() -> void:
	if not Settings.music_on or Settings.music_volume <= 0.001:
		for p in _players:
			p.stop()
		return
	for p in _players:
		if p.playing:   # keep each note's own accent (and the bass lift)
			p.volume_db = _db() + float(p.get_meta("db_offset", 0.0))


func _db() -> float:
	return MUSIC_DB + linear_to_db(maxf(Settings.music_volume, 0.001))


## Bouncier pad than a sibling game's: quicker attack, a triangle body over
## the detuned sines, shorter tail.
func _build_pad() -> AudioStreamWAV:
	var n := int(PAD_DUR * PAD_RATE)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		var t := float(i) / PAD_RATE
		var w := TAU * BASE_HZ * t
		var cycle := fposmod(BASE_HZ * t, 1.0)
		var s := sin(w) * 0.4 + sin(w * 1.006) * 0.24 \
			+ (4.0 * absf(cycle - 0.5) - 1.0) * 0.18 + sin(w * 2.0) * 0.1
		var env := minf(t / 0.35, 1.0) * minf((PAD_DUR - t) / 1.1, 1.0)
		bytes.encode_s16(i * 2, int(clampf(s * env * 0.55, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = PAD_RATE
	wav.stereo = false
	wav.data = bytes
	return wav
