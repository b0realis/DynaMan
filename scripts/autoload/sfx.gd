extends Node
## Sfx — procedural sound effects (autoload "Sfx"). Synth toolkit shared
## with sibling games (swept oscillators + filtered noise into
## 16-bit WAV, round-robin pool, pitch jitter); the recipes are DynaMan's.
##
## Names: "place","boom","brick","item","skull","die","win","count",
## "go","ui","pause","enemy_die","pickup_denied","kick","tick",
## "rattle","spit","portal_open","womp","portal","boom_hop". Unknown
## names warn once.

const RATE := 22050
const MASTER_DB := -8.0
const POOL_SIZE := 12
const BOOM_VOICES := 8  # reserved for booms (v11.6: brick crunches and
						# ticks can't steal them). One per CHAIN: its
						# beats cut each other, separate bombs overlap
						# in full — see boom_voice (v12.0)
const BOOM_SOUNDS := ["boom", "boom_hop"]   # what rides the boom voices
const HOP_LEN := 0.11      # the chain-hop "bo": the boom's first 110 ms…
const HOP_TAU := 0.055     # …falling away with this time constant

enum Wave { SINE, SQUARE, SAW, TRIANGLE }

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _boom_players: Array[AudioStreamPlayer] = []
var _next_player := 0
var _boom_started: Array[int] = []    # per boom voice: wall ms of its last start
var _boom_held_until: Array[int] = [] # per boom voice: a chain's claim (wall ms)
var _rng := RandomNumberGenerator.new()
var _warned: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 1991  # Dynablaster's year
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.volume_db = MASTER_DB
		add_child(p)
		_players.append(p)
	for i in BOOM_VOICES:
		var p := AudioStreamPlayer.new()
		p.volume_db = MASTER_DB
		add_child(p)
		_boom_players.append(p)
		_boom_started.append(0)
		_boom_held_until.append(0)
	_build_all()


## pitch_base shifts the whole sound (1.0 = as built); pitch_var
## jitters around that. Booms ride their own reserved voices (a fresh
## one each — chains use boom_voice + play_boom); everything else
## prefers a FREE voice and only steals (round-robin) when all are
## busy — stealing used to be unconditional, which is why in-game
## never sounded like the renders.
func play(sound_name: String, pitch_var := 0.06, pitch_base := 1.0) -> void:
	if BOOM_SOUNDS.has(sound_name):
		play_boom(boom_voice(), sound_name, pitch_var, pitch_base)
		return
	if _can_play(sound_name):
		_start(_pick_voice(), sound_name, pitch_var, pitch_base)


## A boom voice for one CHAIN (v12.0): a free one, else the one that
## started longest ago. `hold_s` claims it for the chain's remaining
## beats, so the gap between two of them can't hand it to another bomb.
## Every beat of the chain then plays on this voice and CUTS the last —
## like the single sample channel of the 1991 original, which is the
## whole trick of its chain sound: every bomb but the last is heard
## only as its attack, "bo bo bo bo bo BOOM". Separate bombs get
## separate voices and ring out in full, overlapping or not. (v11.6
## layered EVERY boom: six 2.4 s tails swelled into one clipping
## rumble; v11.9 made ALL booms one voice: unrelated bombs clipped
## each other to a tick.)
func boom_voice(hold_s := 0.0) -> int:
	var now := Time.get_ticks_msec()
	var pick := -1
	for i in _boom_players.size():
		if not _boom_players[i].playing and now >= _boom_held_until[i]:
			pick = i
			break
	if pick < 0:
		pick = 0
		for i in _boom_players.size():
			if _boom_started[i] < _boom_started[pick]:
				pick = i
	_boom_held_until[pick] = now + int(hold_s * 1000.0) + 150
	return pick


## Start a boom sound on a chain's voice, cutting whatever that voice
## was playing. The restart is immediate — the AudioServer ramps the
## old playback out itself (no click), where a Tween "fade" could only
## step once per frame and landed 1-2 frames late (v12.0). `hold_s`
## keeps the voice claimed until the chain's next beat (v12.1: beats
## now come one blast at a time, so each renews the claim).
func play_boom(voice: int, sound_name: String, pitch_var := 0.06,
		pitch_base := 1.0, hold_s := 0.0) -> void:
	var v := clampi(voice, 0, _boom_players.size() - 1)
	_boom_held_until[v] = maxi(_boom_held_until[v],
		Time.get_ticks_msec() + int(hold_s * 1000.0) + 150)
	if not _can_play(sound_name):
		return
	_boom_started[v] = Time.get_ticks_msec()
	_start(_boom_players[v], sound_name, pitch_var, pitch_base)


## Keep a chain's voice claimed `secs` from now (main renews it every
## frame while the chain has lit bombs — pauses included).
func hold_voice(voice: int, secs: float) -> void:
	var v := clampi(voice, 0, _boom_players.size() - 1)
	_boom_held_until[v] = maxi(_boom_held_until[v],
		Time.get_ticks_msec() + int(secs * 1000.0))


func _can_play(sound_name: String) -> bool:
	if not _streams.has(sound_name):
		if not _warned.has(sound_name):
			_warned[sound_name] = true
			push_warning("Sfx: unknown sound '%s'" % sound_name)
		return false
	return Settings.sfx_on and Settings.sfx_volume > 0.001


func _start(p: AudioStreamPlayer, sound_name: String, pitch_var: float,
		pitch_base: float) -> void:
	p.stop()
	p.stream = _streams[sound_name]
	p.volume_db = MASTER_DB + linear_to_db(maxf(Settings.sfx_volume, 0.001))
	p.pitch_scale = maxf(0.05, pitch_base + _rng.randf_range(-pitch_var, pitch_var))
	p.play()


func _pick_voice() -> AudioStreamPlayer:
	for i in _players.size():
		var idx := (_next_player + i) % _players.size()
		if not _players[idx].playing:
			_next_player = (idx + 1) % _players.size()
			return _players[idx]
	var steal := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	return steal


# ------------------------------------------------------------- recipes ------

func _build_all() -> void:
	# place: soft plop — bomb set down.
	_streams["place"] = _to_stream(_mix([
		_tone(0.09, 340.0, 180.0, Wave.SINE, 26.0, 0.7),
		_noise_hiss(0.04, 60.0, 1200.0, 400.0, 0.25),
	]))
	# boom: the star of the show, the CANNON (v10.9 contest winner;
	# v11.4 tuned a touch LOWER — every partial ×0.92, per the player's
	# ear): taiko DNA, no square anywhere — a 74→22 Hz drop with a slow
	# decay, a delayed second thump for mass, a long dark rumble, and
	# the biggest room in the game.
	var boom_f := _reverb(_mix([
		_tone(1.0, 74.0, 22.0, Wave.SINE, 4.0, 1.25),
		_tone(0.25, 148.0, 50.0, Wave.SINE, 11.0, 0.35),
		_tone(0.03, 258.0, 129.0, Wave.TRIANGLE, 60.0, 0.22),
		_noise_hiss(0.4, 8.0, 645.0, 120.0, 0.55),
		_delayed(_tone(0.6, 55.0, 20.0, Wave.SINE, 5.0, 0.75), 0.13),
		_noise_hiss(1.1, 2.8, 240.0, 46.0, 0.5),
	]), 0.55, 0.32)
	var boom_gain := _norm_gain(boom_f)
	_streams["boom"] = _to_stream(boom_f, boom_gain)
	# boom_hop (v11.9): the chain-hop "bo", cut from the boom ITSELF —
	# the same samples at the same gain, so the same attack and timbre,
	# no crack (the v10.5-v11.3 boom_chain crack stays retired). Plain
	# truncation wasn't enough: the cannon decays slowly, so a boom
	# chopped at 120 ms gave the next attack only ~3 dB of contrast;
	# with the 55 ms fall each hop lands 15-35 dB clear of the one
	# before — a syllable, not a smear.
	_streams["boom_hop"] = _to_stream(_hop_cut(boom_f), boom_gain)
	# brick: dry crunch of a soft block bursting.
	_streams["brick"] = _to_stream(_mix([
		_noise_hiss(0.16, 20.0, 2400.0, 500.0, 0.6),
		_tone(0.1, 200.0, 90.0, Wave.TRIANGLE, 22.0, 0.4),
	]))
	# item: bright pickup ding.
	_streams["item"] = _to_stream(_mix([
		_tone(0.09, 880.0, 880.0, Wave.SQUARE, 16.0, 0.3),
		_delayed(_tone(0.16, 1320.0, 1320.0, Wave.TRIANGLE, 10.0, 0.4), 0.07),
	]))
	# skull: queasy dissonant warble — you picked up trouble.
	_streams["skull"] = _to_stream(_mix([
		_tone(0.4, 300.0, 210.0, Wave.SAW, 6.0, 0.35),
		_tone(0.4, 315.0, 195.0, Wave.SAW, 6.0, 0.35),
	]))
	# die: sad downward spiral.
	_streams["die"] = _to_stream(_mix([
		_tone(0.55, 620.0, 90.0, Wave.SQUARE, 5.0, 0.4),
		_tone(0.55, 310.0, 45.0, Wave.SINE, 5.0, 0.4),
	]))
	# enemy_die: quick pop + squeak.
	_streams["enemy_die"] = _to_stream(_mix([
		_tone(0.12, 500.0, 900.0, Wave.SINE, 16.0, 0.45),
		_noise_hiss(0.08, 35.0, 2000.0, 600.0, 0.3),
	]))
	# win: rising fanfare.
	_streams["win"] = _to_stream(_mix([
		_tone(0.14, 523.0, 523.0, Wave.SQUARE, 8.0, 0.35),
		_delayed(_tone(0.14, 659.0, 659.0, Wave.SQUARE, 8.0, 0.35), 0.11),
		_delayed(_tone(0.14, 784.0, 784.0, Wave.SQUARE, 8.0, 0.35), 0.22),
		_delayed(_tone(0.4, 1047.0, 1047.0, Wave.TRIANGLE, 5.0, 0.5), 0.33),
	]))
	# count / go: countdown blips (go = brighter, higher).
	_streams["count"] = _to_stream(
		_tone(0.09, 440.0, 440.0, Wave.SQUARE, 22.0, 0.4))
	_streams["go"] = _to_stream(_mix([
		_tone(0.2, 880.0, 880.0, Wave.SQUARE, 10.0, 0.45),
		_tone(0.2, 1320.0, 1320.0, Wave.SINE, 12.0, 0.25),
	]))
	# ui / pause.
	_streams["ui"] = _to_stream(
		_tone(0.06, 700.0, 990.0, Wave.SINE, 30.0, 0.4))
	_streams["pause"] = _to_stream(_mix([
		_tone(0.07, 500.0, 500.0, Wave.SINE, 26.0, 0.4),
		_delayed(_tone(0.09, 375.0, 375.0, Wave.SINE, 22.0, 0.4), 0.09),
	]))
	# pickup_denied: flat buzz (reserved for cursed no-bomb attempts).
	_streams["pickup_denied"] = _to_stream(
		_tone(0.12, 160.0, 140.0, Wave.SQUARE, 18.0, 0.3))
	# kick: hollow punt — low thock plus a short air whoosh.
	_streams["kick"] = _to_stream(_mix([
		_tone(0.1, 240.0, 130.0, Wave.SINE, 24.0, 0.8),
		_noise_hiss(0.12, 16.0, 500.0, 2200.0, 0.35),
	]))
	# tick: tiny woodblock click — the bomb's final-second heartbeat.
	_streams["tick"] = _to_stream(
		_tone(0.035, 1900.0, 1400.0, Wave.SQUARE, 70.0, 0.22))
	# rattle: a pill bottle given a good shake — a fistful of tiny
	# capsule clicks and one hollow knock (the MEDICINE CABINET's door).
	_streams["rattle"] = _to_stream(_mix([
		_noise_hiss(0.03, 40.0, 3000.0, 1800.0, 0.5),
		_delayed(_noise_hiss(0.025, 45.0, 2600.0, 1500.0, 0.45), 0.05),
		_delayed(_noise_hiss(0.03, 40.0, 3200.0, 1900.0, 0.5), 0.09),
		_delayed(_noise_hiss(0.025, 45.0, 2800.0, 1600.0, 0.4), 0.16),
		_delayed(_noise_hiss(0.035, 38.0, 3000.0, 1700.0, 0.55), 0.21),
		_delayed(_tone(0.06, 380.0, 260.0, Wave.TRIANGLE, 35.0, 0.25), 0.24),
	]))
	# spit: the fire elemental's fireball leaving the nozzle.
	_streams["spit"] = _to_stream(_mix([
		_tone(0.16, 620.0, 240.0, Wave.SAW, 14.0, 0.4),
		_noise_hiss(0.14, 12.0, 2600.0, 700.0, 0.35),
	]))
	# portal_open: the exit wakes up — warm rising shimmer.
	_streams["portal_open"] = _to_stream(_mix([
		_tone(0.5, 220.0, 660.0, Wave.SINE, 5.0, 0.4),
		_delayed(_tone(0.4, 440.0, 1320.0, Wave.TRIANGLE, 6.0, 0.3), 0.1),
		_noise_hiss(0.45, 6.0, 900.0, 3200.0, 0.15),
	]))
	# womp: the sad trombone — three descending steps, then the slide.
	_streams["womp"] = _to_stream(_mix([
		_tone(0.26, 233.0, 233.0, Wave.SAW, 7.0, 0.28),
		_delayed(_tone(0.26, 220.0, 220.0, Wave.SAW, 7.0, 0.28), 0.3),
		_delayed(_tone(0.26, 208.0, 208.0, Wave.SAW, 7.0, 0.28), 0.6),
		_delayed(_tone(0.8, 196.0, 147.0, Wave.SAW, 3.0, 0.3), 0.9),
	]))
	# portal: the whoosh of being whisked away through the exit.
	_streams["portal"] = _to_stream(_mix([
		_tone(0.9, 300.0, 1800.0, Wave.SINE, 3.2, 0.4),
		_tone(0.9, 150.0, 900.0, Wave.TRIANGLE, 3.2, 0.3),
		_noise_hiss(0.7, 4.0, 600.0, 4200.0, 0.3),
		_delayed(_tone(0.35, 1047.0, 2093.0, Wave.SINE, 8.0, 0.3), 0.55),
	]))


# ------------------------------------------------------- synth toolkit ------
# (shared with a sibling game's sfx.gd)

## Oscillator with an exponential frequency sweep f0→f1 (Hz) and an
## attack→exponential-decay envelope. decay = exp() falloff rate (bigger =
## shorter); attack = linear fade-in seconds (kills clicks).
func _tone(dur: float, f0: float, f1: float, wave: Wave, decay: float,
		amp := 1.0, attack := 0.004) -> PackedFloat32Array:
	var n := maxi(int(dur * RATE), 1)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	var ratio := f1 / f0
	for i in n:
		var t := float(i) / RATE
		phase += f0 * pow(ratio, t / dur) / RATE
		var cycle := fposmod(phase, 1.0)
		var s: float
		match wave:
			Wave.SINE:
				s = sin(TAU * phase)
			Wave.SQUARE:
				s = 1.0 if cycle < 0.5 else -1.0
			Wave.SAW:
				s = 2.0 * cycle - 1.0
			_:
				s = 4.0 * absf(cycle - 0.5) - 1.0  # TRIANGLE
		out[i] = s * amp * minf(t / attack, 1.0) * exp(-decay * t)
	return out


## White noise through a one-pole lowpass whose cutoff sweeps cut0→cut1.
func _noise_hiss(dur: float, decay: float, cut0: float, cut1: float,
		amp := 1.0, attack := 0.003) -> PackedFloat32Array:
	var n := maxi(int(dur * RATE), 1)
	var out := PackedFloat32Array()
	out.resize(n)
	var y := 0.0
	for i in n:
		var t := float(i) / RATE
		var cut := lerpf(cut0, cut1, t / dur)
		var a := clampf(TAU * cut / RATE, 0.0, 1.0)
		y += a * (_rng.randf_range(-1.0, 1.0) - y)
		out[i] = y * 2.2 * amp * minf(t / attack, 1.0) * exp(-decay * t)
	return out


## Sum sample buffers; short parts get a ~5 ms tail fade.
func _mix(parts: Array) -> PackedFloat32Array:
	var n := 0
	for part: PackedFloat32Array in parts:
		n = maxi(n, part.size())
	var out := PackedFloat32Array()
	out.resize(n)
	var fade := int(0.005 * RATE)
	for part: PackedFloat32Array in parts:
		var pn := part.size()
		var tail := mini(fade, pn) if pn < n else 0
		for i in pn:
			var v := part[i]
			if i >= pn - tail:
				v *= float(pn - 1 - i) / tail
			out[i] += v
	return out


## Mini Schroeder reverb: three damped feedback combs at mutually
## inharmonic delays (31/41/53 ms), RT60 ≈ tail seconds, wet mixed
## under the dry signal. Offline at build time — zero runtime cost.
func _reverb(x: PackedFloat32Array, tail := 0.35, wet := 0.3) -> PackedFloat32Array:
	var delays := [683, 904, 1169]
	var n := x.size() + int(tail * 2.5 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in x.size():
		out[i] = x[i]
	for d: int in delays:
		var g := pow(0.001, float(d) / RATE / tail)
		var buf := PackedFloat32Array()
		buf.resize(n)
		var lp := 0.0
		for i in n:
			var dry := x[i] if i < x.size() else 0.0
			var fb: float = buf[i - d] if i >= d else 0.0
			lp += 0.4 * (fb - lp)   # darken the tail a little every pass
			buf[i] = dry + g * lp
		for i in n:
			out[i] += (buf[i] - (x[i] if i < x.size() else 0.0)) * (wet / 3.0)
	return out


## Prepend silence — for arpeggios and staggered layers.
func _delayed(samples: PackedFloat32Array, sec: float) -> PackedFloat32Array:
	var pad := PackedFloat32Array()
	pad.resize(maxi(int(sec * RATE), 0))
	pad.append_array(samples)
	return pad


## The first HOP_LEN of a boom's float samples, falling away with
## HOP_TAU (_to_stream adds the usual edge fades).
func _hop_cut(boom: PackedFloat32Array) -> PackedFloat32Array:
	var n := mini(int(HOP_LEN * RATE), boom.size())
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = boom[i] * exp(-float(i) / RATE / HOP_TAU)
	return out


## The gain _to_stream normalises a buffer with (peak to 0.95).
func _norm_gain(samples: PackedFloat32Array) -> float:
	var peak := 0.0
	for i in samples.size():
		peak = maxf(peak, absf(samples[i]))
	return 1.0 if peak <= 0.95 else 0.95 / peak


## Float samples → 16-bit mono AudioStreamWAV with edge fades. `gain`
## < 0 = normalise this buffer; pass one explicitly to match another
## sound's level (boom_hop rides the boom's gain).
func _to_stream(samples: PackedFloat32Array, gain := -1.0) -> AudioStreamWAV:
	var n := samples.size()
	if gain < 0.0:
		gain = _norm_gain(samples)
	var fade_in := mini(int(0.002 * RATE), n)
	var fade_out := mini(int(0.012 * RATE), n)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		var v := samples[i] * gain
		if i < fade_in:
			v *= float(i) / fade_in
		if i >= n - fade_out:
			v *= float(n - 1 - i) / fade_out
		bytes.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	return wav
