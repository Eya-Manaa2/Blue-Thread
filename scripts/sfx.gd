extends Node
## ============================================================
##  PAYSAGE SONORE — aucune musique, uniquement des sons naturels
##  et des bruits de matières, tous fabriqués par code au démarrage.
##
##  Ville polluée : vent lugubre, mouches, mer lointaine.
##  Ville restaurée : vagues, feuilles, moineaux, cigales, mouettes, chats.
## ============================================================

const HI := 22050
const MID := 16000
const LO := 11025

var world: Node3D
var rng := RandomNumberGenerator.new()

# Boucles d'ambiance
var amb_wind: AudioStreamPlayer
var amb_flies: AudioStreamPlayer
var amb_leaves: AudioStreamPlayer
var amb_cicadas: AudioStreamPlayer
var amb_ocean: AudioStreamPlayer3D
var amb_started: bool = false

# Sons ponctuels
var s_wind: AudioStreamWAV
var s_flies: AudioStreamWAV
var s_leaves: AudioStreamWAV
var s_cicadas: AudioStreamWAV
var s_ocean: AudioStreamWAV
var s_chirps: Array = []
var s_gull: AudioStreamWAV
var s_meow: AudioStreamWAV
var s_steps: Array = []
var s_glass: AudioStreamWAV
var s_metal: AudioStreamWAV
var s_plastic: AudioStreamWAV
var s_paper: AudioStreamWAV
var s_organic: AudioStreamWAV
var s_whoosh: AudioStreamWAV
var s_bonk: AudioStreamWAV
var s_ting: AudioStreamWAV
var s_puff: AudioStreamWAV
var s_gust: AudioStreamWAV
var s_wave: AudioStreamWAV
# --- ajouts : industrie, alarme, O2, respiration, carillons, machines, musique
var s_hum: AudioStreamWAV
var s_alarm: AudioStreamWAV
var s_beep: AudioStreamWAV
var s_breath: AudioStreamWAV
var s_creak: AudioStreamWAV
var s_chime: AudioStreamWAV
var s_fail: AudioStreamWAV
var s_hiss: AudioStreamWAV
var s_machine: AudioStreamWAV
var s_piano: AudioStreamWAV          # une note (Do5) jouée à différentes hauteurs
var s_pad_major: AudioStreamWAV
var s_pad_minor: AudioStreamWAV
var amb_hum: AudioStreamPlayer
var music: AudioStreamPlayer         # nappe musicale (fondus)
var _hum_level: float = 0.3
var _creak_timer: float = 9.0
var _beep_cool: float = 0.0
var level_id: String = ""
const C5 := 523.25

var _pool: Array = []
var _pool_i: int = 0
var _bird_timer: float = 3.0
## Petite musique d'ambiance douce (arpèges de piano, ses propres lecteurs
## pour ne jamais couper les bruitages).
var music_on: bool = true
var _mus_pool: Array = []
var _mus_pi: int = 0
var _mus_t: float = 1.5
var _mus_i: int = 0
const MUSIC_STEP := 0.82
# Do - La mineur - Fa - Sol, arpèges (demi-tons depuis Do5) ; -99 = silence
const MUSIC := [-12, -5, 0, -5, 4, -5, -99, -99,
	-15, -8, -3, -8, 0, -8, -99, -99,
	-19, -12, -7, -12, -3, -12, -99, -99,
	-17, -10, -5, -10, -1, 2, -99, -99]
var _gull_timer: float = 6.0


func _ready() -> void:
	rng.seed = 77
	world = get_parent() as Node3D
	for i in 12:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	for i in 4:
		var mp := AudioStreamPlayer.new()
		add_child(mp)
		_mus_pool.append(mp)
	_generate_all()


# ============================================================
#  OUTILS
# ============================================================
func _to_wav(b: PackedFloat32Array, rate: int, loop: bool) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(b.size() * 2)
	for i in b.size():
		data.encode_s16(i * 2, int(clampf(b[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = b.size()
	return w


func _norm(b: PackedFloat32Array, peak: float) -> PackedFloat32Array:
	var m: float = 0.0001
	for v in b:
		m = maxf(m, absf(v))
	var k: float = peak / m
	for i in b.size():
		b[i] = b[i] * k
	return b


## Fond enchaîné : la fin se fond dans le début pour une boucle sans coupure.
func _loop(b: PackedFloat32Array, fade: int) -> PackedFloat32Array:
	var length: int = b.size() - fade
	var out: PackedFloat32Array = b.slice(0, length)
	for i in fade:
		var k: float = float(i) / float(fade)
		out[i] = b[i] * k + b[length + i] * (1.0 - k)
	return out


func _new_buf(seconds: float, rate: int) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * rate))
	return b


func _smooth(a: float, b: float, x: float) -> float:
	var t: float = clampf((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _set_vol(p: Node, lin: float) -> void:
	p.set("volume_db", linear_to_db(maxf(lin, 0.0001)))


func _play(stream: AudioStream, vol_db: float = 0.0, pitch: float = 1.0) -> AudioStreamPlayer:
	var p: AudioStreamPlayer = _pool[_pool_i]
	_pool_i = (_pool_i + 1) % _pool.size()
	p.stream = stream
	p.volume_db = vol_db
	p.pitch_scale = pitch
	p.play()
	return p


## Joue un son en boucle pendant `sec` secondes puis l'éteint en fondu.
func _play_for(stream: AudioStream, vol_db: float, pitch: float, sec: float) -> void:
	var p := _play(stream, vol_db, pitch)
	var tw := create_tween()
	tw.tween_interval(maxf(0.0, sec - 0.8))
	tw.tween_property(p, "volume_db", -60.0, 0.8)
	tw.tween_callback(p.stop)


func _play_3d(stream: AudioStream, pos: Vector3, vol_db: float = 0.0, pitch: float = 1.0, unit: float = 8.0) -> void:
	if world == null or not is_inside_tree():
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.volume_db = vol_db
	p.pitch_scale = pitch
	p.unit_size = unit
	p.max_distance = 200.0
	world.add_child(p)
	p.global_position = pos
	p.play()
	p.finished.connect(p.queue_free)


func _later(sec: float, f: Callable) -> void:
	get_tree().create_timer(sec).timeout.connect(f)


# ============================================================
#  FABRICATION DES SONS
# ============================================================
func _generate_all() -> void:
	for i in 4:
		s_chirps.append(_gen_chirp())
	s_gull = _gen_gull()
	s_meow = _gen_meow()
	for i in 3:
		s_steps.append(_gen_step())
	s_glass = _gen_partials([2350.0, 3720.0, 5140.0, 6630.0], [1.0, 0.6, 0.4, 0.25], [6.0, 9.0, 12.0, 16.0], 0.7, true)
	s_metal = _gen_partials([540.0, 1230.0, 1990.0, 2870.0], [1.0, 0.7, 0.5, 0.3], [9.0, 12.0, 15.0, 20.0], 0.45, false)
	s_plastic = _gen_plastic()
	s_paper = _gen_paper()
	s_organic = _gen_organic()
	s_whoosh = _gen_whoosh()
	s_bonk = _gen_bonk()
	s_ting = _gen_ting()
	s_puff = _gen_puff()
	s_wave = _gen_wave()
	s_hum = _gen_hum()
	s_beep = _gen_beep()
	s_breath = _gen_breath()
	s_creak = _gen_creak()
	s_chime = _gen_chime()
	s_fail = _gen_fail()
	s_machine = _gen_machine()
	s_piano = _gen_piano()
	s_pad_major = _gen_pad([261.63, 329.63, 392.0, 523.25])
	s_pad_minor = _gen_pad([220.0, 261.63, 329.63, 440.0])


# --- Mer : vagues qui montent et se retirent, ressac écumeux ---
func _gen_ocean() -> AudioStreamWAV:
	var rate: int = LO
	var fade: int = rate
	var b := _new_buf(9.0, rate)
	var lp1: float = 0.0
	var lp2: float = 0.0
	var lp3: float = 0.0
	for i in b.size():
		var t: float = float(i) / rate
		var w: float = rng.randf_range(-1.0, 1.0)
		var env: float = pow(sin(fposmod(t / 4.0, 1.0) * PI), 3.0)
		var env2: float = pow(sin(fposmod((t + 1.3) / 4.0, 1.0) * PI), 6.0)
		lp1 += (w - lp1) * (0.015 + 0.12 * env)
		lp2 += (w - lp2) * 0.004
		lp3 += (w - lp3) * 0.35
		b[i] = lp1 * (0.4 + 1.6 * env) + lp2 * 3.0 + (w - lp3) * 0.25 * env2
	return _to_wav(_norm(_loop(b, fade), 0.8), rate, true)


# --- Vent : souffle grave qui siffle entre les maisons ---
func _gen_wind() -> AudioStreamWAV:
	var rate: int = LO
	var fade: int = rate / 2
	var b := _new_buf(6.5, rate)
	var low: float = 0.0
	var band: float = 0.0
	var low2: float = 0.0
	var band2: float = 0.0
	for i in b.size():
		var t: float = float(i) / rate
		var w: float = rng.randf_range(-1.0, 1.0)
		var fc: float = 380.0 + 200.0 * sin(TAU * t / 6.0) + 110.0 * sin(TAU * t / 2.0 + 1.0)
		var f: float = 2.0 * sin(PI * fc / rate)
		low += f * band
		var high: float = w - low - 0.18 * band
		band += f * high
		var fc2: float = 900.0 + 300.0 * sin(TAU * t / 3.0)
		var f2: float = 2.0 * sin(PI * fc2 / rate)
		low2 += f2 * band2
		var high2: float = w - low2 - 0.35 * band2
		band2 += f2 * high2
		var amp: float = 0.6 + 0.4 * sin(TAU * t / 3.0 + 0.5)
		b[i] = (band * 0.6 + band2 * 0.25) * amp
	return _to_wav(_norm(_loop(b, fade), 0.8), rate, true)


# --- Mouches autour des déchets ---
func _gen_flies() -> AudioStreamWAV:
	var rate: int = LO
	var fade: int = rate / 2
	var b := _new_buf(4.5, rate)
	var ph1: float = 0.0
	var ph2: float = 0.0
	var lp: float = 0.0
	for i in b.size():
		var t: float = float(i) / rate
		var f1: float = 205.0 + 12.0 * sin(TAU * t * 6.0) + 25.0 * sin(TAU * t / 2.0)
		var f2: float = 238.0 + 10.0 * sin(TAU * t * 7.0) + 30.0 * sin(TAU * t / 4.0 + 2.0)
		ph1 = fposmod(ph1 + f1 / rate, 1.0)
		ph2 = fposmod(ph2 + f2 / rate, 1.0)
		var s: float = (ph1 * 2.0 - 1.0) * (0.5 + 0.5 * sin(TAU * t / 4.0)) + (ph2 * 2.0 - 1.0) * (0.5 + 0.5 * sin(TAU * t / 2.0 + 1.0))
		lp += (s - lp) * 0.25
		b[i] = lp
	return _to_wav(_norm(_loop(b, fade), 0.7), rate, true)


# --- Feuilles qui bruissent dans le vent ---
func _gen_leaves() -> AudioStreamWAV:
	var rate: int = MID
	var fade: int = rate / 2
	var b := _new_buf(4.5, rate)
	var lp: float = 0.0
	var cr: float = 0.0
	for i in b.size():
		var t: float = float(i) / rate
		var w: float = rng.randf_range(-1.0, 1.0)
		lp += (w - lp) * 0.2
		var hp: float = w - lp
		var gust: float = 0.25 + 0.75 * pow(0.5 + 0.5 * sin(TAU * t / 4.0), 2.0) * (0.6 + 0.4 * sin(TAU * t * 0.75))
		cr *= 0.8
		if rng.randf() < 0.006 * gust:
			cr += rng.randf_range(-1.0, 1.0) * 2.5
		b[i] = hp * 0.5 * gust + cr * hp
	return _to_wav(_norm(_loop(b, fade), 0.7), rate, true)


# --- Cigales de l'été méditerranéen ---
func _gen_cicadas() -> AudioStreamWAV:
	var rate: int = HI
	var fade: int = rate / 4
	var b := _new_buf(4.25, rate)
	var lp: float = 0.0
	for i in b.size():
		var t: float = float(i) / rate
		var w: float = rng.randf_range(-1.0, 1.0)
		lp += (w - lp) * 0.5
		var hp: float = w - lp
		var pulse: float = pow(maxf(0.0, sin(TAU * 72.0 * t)), 3.0)
		var swell: float = 0.35 + 0.65 * pow(sin(PI * t / 4.0), 2.0)
		var c1: float = (sin(TAU * 4700.0 * t) * 0.6 + sin(TAU * 5300.0 * t) * 0.3 + hp * 0.5) * pulse * swell
		var pulse2: float = pow(maxf(0.0, sin(TAU * 64.0 * t + 1.0)), 3.0)
		var c2: float = (sin(TAU * 4100.0 * t) * 0.5 + hp * 0.3) * pulse2 * (1.0 - swell * 0.5)
		b[i] = c1 + c2 * 0.6
	return _to_wav(_norm(_loop(b, fade), 0.6), rate, true)


# --- Moineau : quelques notes qui glissent ---
func _gen_chirp() -> AudioStreamWAV:
	var rate: int = HI
	var b := _new_buf(0.8, rate)
	var pos: int = 0
	var ph: float = 0.0
	for n in rng.randi_range(2, 5):
		var nd: float = rng.randf_range(0.035, 0.08)
		var f0: float = rng.randf_range(2800.0, 4200.0)
		var f1: float = f0 + rng.randf_range(-1500.0, 1500.0)
		var ns: int = int(nd * rate)
		for j in ns:
			if pos + j >= b.size():
				break
			var k: float = float(j) / float(ns)
			var f: float = lerpf(f0, f1, k) + 300.0 * sin(TAU * k * 3.0)
			ph = fposmod(ph + f / rate, 1.0)
			b[pos + j] = sin(ph * TAU) * sin(k * PI)
		pos += ns + int(rng.randf_range(0.03, 0.07) * rate)
	return _to_wav(_norm(b, 0.7), rate, false)


# --- Mouette : deux cris « kiaou » ---
func _gen_gull() -> AudioStreamWAV:
	var rate: int = HI
	var b := _new_buf(1.0, rate)
	for start in [0.0, 0.45]:
		var s0: int = int(float(start) * rate)
		var ns: int = int(0.38 * rate)
		var ph: float = 0.0
		for j in ns:
			if s0 + j >= b.size():
				break
			var k: float = float(j) / float(ns)
			var t: float = float(j) / rate
			var f: float
			if k < 0.2:
				f = lerpf(700.0, 1450.0, k / 0.2)
			else:
				f = lerpf(1450.0, 650.0, (k - 0.2) / 0.8)
			f += 25.0 * sin(TAU * 28.0 * t)
			ph = fposmod(ph + f / rate, 1.0)
			var amp: float = pow(sin(k * PI), 0.6)
			var s: float = sin(ph * TAU) + 0.6 * sin(2.0 * ph * TAU) + 0.35 * sin(3.0 * ph * TAU) + 0.2 * sin(4.0 * ph * TAU)
			s += rng.randf_range(-0.15, 0.15)
			b[s0 + j] += s * amp
	return _to_wav(_norm(b, 0.75), rate, false)


# --- Miaulement de chat ---
func _gen_meow() -> AudioStreamWAV:
	var rate: int = HI
	var b := _new_buf(0.75, rate)
	var ph: float = 0.0
	for i in b.size():
		var k: float = float(i) / float(b.size())
		var t: float = float(i) / rate
		var f: float = 480.0 + 320.0 * sin(PI * minf(k * 1.4, 1.0)) - 120.0 * k + 8.0 * sin(TAU * 6.0 * t)
		ph = fposmod(ph + f / rate, 1.0)
		var op: float = sin(PI * k)
		var s: float = sin(ph * TAU) * 0.5 + sin(2.0 * ph * TAU) * (0.2 + 0.5 * op) + sin(3.0 * ph * TAU) * (0.1 + 0.4 * op) + sin(4.0 * ph * TAU) * 0.25 * op + sin(5.0 * ph * TAU) * 0.1 * op
		b[i] = s * pow(sin(PI * k), 0.5)
	return _to_wav(_norm(b, 0.7), rate, false)


# --- Pas sur les pavés ---
func _gen_step() -> AudioStreamWAV:
	var rate: int = HI
	var b := _new_buf(0.1, rate)
	var lp: float = 0.0
	var coef: float = rng.randf_range(0.18, 0.32)
	for i in b.size():
		var t: float = float(i) / rate
		var w: float = rng.randf_range(-1.0, 1.0)
		lp += (w - lp) * coef
		b[i] = lp * exp(-t * 55.0) * 1.5 + sin(TAU * 90.0 * t) * exp(-t * 60.0) * 0.6 + w * exp(-t * 300.0) * 0.3
	return _to_wav(_norm(b, 0.8), rate, false)


# --- Verre (tintement) / métal (clang) : modes de vibration qui s'éteignent ---
func _gen_partials(freqs: Array, amps: Array, decays: Array, dur: float, double_hit: bool) -> AudioStreamWAV:
	var rate: int = HI
	var b := _new_buf(dur, rate)
	var hits: Array = [[0.0, 1.0]]
	if double_hit:
		hits.append([0.09, 0.45])
	for h in hits:
		var off: int = int(float(h[0]) * rate)
		var g: float = h[1]
		for i in range(off, b.size()):
			var t: float = float(i - off) / rate
			var s: float = rng.randf_range(-1.0, 1.0) * exp(-t * 180.0) * 0.4
			for p in freqs.size():
				s += sin(TAU * float(freqs[p]) * t) * float(amps[p]) * exp(-t * float(decays[p]))
			b[i] += s * g
	return _to_wav(_norm(b, 0.8), rate, false)


# --- Plastique : froissement + choc creux ---
func _gen_plastic() -> AudioStreamWAV:
	var rate: int = HI
	var b := _new_buf(0.3, rate)
	var lp: float = 0.0
	var cr: float = 0.0
	for i in b.size():
		var t: float = float(i) / rate
		var w: float = rng.randf_range(-1.0, 1.0)
		lp += (w - lp) * 0.3
		cr *= 0.75
		if rng.randf() < 0.02:
			cr += rng.randf_range(-1.0, 1.0)
		b[i] = sin(TAU * 160.0 * t) * exp(-t * 35.0) * 0.7 + (w - lp) * cr * exp(-t * 10.0) * 2.0
	return _to_wav(_norm(b, 0.8), rate, false)


# --- Papier / carton : « poc » sourd ---
func _gen_paper() -> AudioStreamWAV:
	var rate: int = HI
	var b := _new_buf(0.25, rate)
	var lp: float = 0.0
	for i in b.size():
		var t: float = float(i) / rate
		var w: float = rng.randf_range(-1.0, 1.0)
		lp += (w - lp) * 0.15
		b[i] = lp * exp(-t * 25.0) * 2.0 + sin(TAU * 110.0 * t) * exp(-t * 30.0) * 0.6
	return _to_wav(_norm(b, 0.8), rate, false)


# --- Organique : « splotch » humide ---
func _gen_organic() -> AudioStreamWAV:
	var rate: int = HI
	var b := _new_buf(0.3, rate)
	var lp: float = 0.0
	for i in b.size():
		var t: float = float(i) / rate
		var k: float = float(i) / float(b.size())
		var w: float = rng.randf_range(-1.0, 1.0)
		lp += (w - lp) * lerpf(0.3, 0.03, k)
		b[i] = lp * exp(-t * 14.0) * 2.0 + sin(TAU * (90.0 - 40.0 * k) * t) * exp(-t * 20.0) * 0.6
	return _to_wav(_norm(b, 0.8), rate, false)


# --- Souffle du lancer ---
func _gen_whoosh() -> AudioStreamWAV:
	var rate: int = HI
	var b := _new_buf(0.28, rate)
	var low: float = 0.0
	var band: float = 0.0
	for i in b.size():
		var k: float = float(i) / float(b.size())
		var w: float = rng.randf_range(-1.0, 1.0)
		var f: float = 2.0 * sin(PI * lerpf(400.0, 1800.0, k) / rate)
		low += f * band
		var high: float = w - low - 0.5 * band
		band += f * high
		b[i] = band * sin(k * PI)
	return _to_wav(_norm(b, 0.6), rate, false)


# --- Erreur : le bac recrache (« bonk » sourd) ---
func _gen_bonk() -> AudioStreamWAV:
	var rate: int = HI
	var b := _new_buf(0.45, rate)
	var lp: float = 0.0
	for h in [[0.0, 170.0, 1.0], [0.12, 120.0, 0.8]]:
		var off: int = int(float(h[0]) * rate)
		var ph: float = 0.0
		for i in range(off, b.size()):
			var t: float = float(i - off) / rate
			var w: float = rng.randf_range(-1.0, 1.0)
			lp += (w - lp) * 0.08
			ph = fposmod(ph + float(h[1]) * exp(-t * 3.0) / rate, 1.0)
			b[i] += (sin(ph * TAU) * exp(-t * 14.0) + lp * exp(-t * 30.0) * 1.5) * float(h[2])
	return _to_wav(_norm(b, 0.8), rate, false)


# --- Petit tintement de réussite ---
func _gen_ting() -> AudioStreamWAV:
	var rate: int = HI
	var b := _new_buf(0.5, rate)
	for i in b.size():
		var t: float = float(i) / rate
		b[i] = sin(TAU * 2093.0 * t) * exp(-t * 7.0) + sin(TAU * 4186.0 * t) * 0.3 * exp(-t * 12.0)
	return _to_wav(_norm(b, 0.5), rate, false)


# --- Bouffée d'air (un tas de déchets disparaît) ---
func _gen_puff() -> AudioStreamWAV:
	var rate: int = HI
	var b := _new_buf(0.4, rate)
	var lp: float = 0.0
	for i in b.size():
		var k: float = float(i) / float(b.size())
		var w: float = rng.randf_range(-1.0, 1.0)
		lp += (w - lp) * 0.08
		b[i] = lp * pow(sin(k * PI), 2.0)
	return _to_wav(_norm(b, 0.7), rate, false)


# --- Rafale (Chehili) ---
func _gen_gust() -> AudioStreamWAV:
	var rate: int = LO
	var b := _new_buf(1.8, rate)
	var low: float = 0.0
	var band: float = 0.0
	for i in b.size():
		var k: float = float(i) / float(b.size())
		var w: float = rng.randf_range(-1.0, 1.0)
		var f: float = 2.0 * sin(PI * (300.0 + 450.0 * sin(k * PI)) / rate)
		low += f * band
		var high: float = w - low - 0.25 * band
		band += f * high
		b[i] = band * pow(sin(k * PI), 1.5)
	return _to_wav(_norm(b, 0.85), rate, false)


# --- Grosse vague qui se brise (finale) ---
func _gen_wave() -> AudioStreamWAV:
	var rate: int = LO
	var b := _new_buf(3.2, rate)
	var lp: float = 0.0
	var lp2: float = 0.0
	for i in b.size():
		var k: float = float(i) / float(b.size())
		var w: float = rng.randf_range(-1.0, 1.0)
		var env: float
		if k < 0.25:
			env = pow(k / 0.25, 2.0)
		else:
			env = exp(-(k - 0.25) * 4.0)
		lp += (w - lp) * (0.02 + 0.08 * env)
		lp2 += (lp - lp2) * 0.3
		b[i] = lp2 * env * 1.5     # vague sourde, sans souffle aigu
	return _to_wav(_norm(b, 0.9), rate, false)


# ============================================================
#  AJOUTS (22/11) : sons procéduraux originaux, aucun fichier externe
# ============================================================
# --- Bourdonnement industriel (boucle) : 50 Hz + harmoniques + souffle ---
func _gen_hum() -> AudioStreamWAV:
	var rate: int = LO
	var b := _new_buf(4.0, rate)
	var lp: float = 0.0
	for i in b.size():
		var t: float = float(i) / rate
		var w: float = rng.randf_range(-1.0, 1.0)
		lp += (w - lp) * 0.02
		var wob: float = 1.0 + 0.15 * sin(TAU * 0.25 * t)
		b[i] = (sin(TAU * 50.0 * t) * 0.5 + sin(TAU * 100.0 * t) * 0.3 + sin(TAU * 150.0 * t) * 0.12) * wob
	return _to_wav(_norm(_loop(b, 2000), 0.5), rate, true)


# --- Alarme lointaine : deux tons ---
func _gen_alarm() -> AudioStreamWAV:
	var rate: int = MID
	var b := _new_buf(1.2, rate)
	for i in b.size():
		var t: float = float(i) / rate
		var f: float = 660.0 if fmod(t, 0.6) < 0.3 else 520.0
		var env: float = minf(1.0, t * 20.0) * minf(1.0, (1.2 - t) * 8.0)
		b[i] = (sin(TAU * f * t) + 0.3 * sin(TAU * f * 2.0 * t)) * env
	return _to_wav(_norm(b, 0.35), rate, false)


# --- Bip du moniteur d'oxygène ---
func _gen_beep() -> AudioStreamWAV:
	var rate: int = MID
	var b := _new_buf(0.14, rate)
	for i in b.size():
		var t: float = float(i) / rate
		b[i] = sin(TAU * 1320.0 * t) * minf(1.0, t * 300.0) * minf(1.0, (0.14 - t) * 60.0)
	return _to_wav(_norm(b, 0.45), rate, false)


# --- Respiration dans le masque : inspiration + expiration ---
func _gen_breath() -> AudioStreamWAV:
	var rate: int = LO
	var b := _new_buf(2.6, rate)
	var low: float = 0.0
	var band: float = 0.0
	for i in b.size():
		var t: float = float(i) / rate
		var w: float = rng.randf_range(-1.0, 1.0)
		var env: float = 0.0
		if t < 1.0:
			env = sin(PI * t / 1.0)
		elif t > 1.2 and t < 2.5:
			env = 0.8 * sin(PI * (t - 1.2) / 1.3)
		var fc: float = 700.0 if t < 1.1 else 450.0
		var f: float = 2.0 * sin(PI * fc / rate)
		low += f * band
		var high: float = w - low - 0.6 * band
		band += f * high
		b[i] = band * env
	return _to_wav(_norm(b, 0.5), rate, false)


# --- Grincement de métal ---
func _gen_creak() -> AudioStreamWAV:
	var rate: int = MID
	var b := _new_buf(0.9, rate)
	var ph: float = 0.0
	for i in b.size():
		var t: float = float(i) / rate
		var f: float = 180.0 + 60.0 * sin(TAU * 1.3 * t) + rng.randf_range(-12.0, 12.0)
		ph = fposmod(ph + f / rate, 1.0)
		var saw: float = ph * 2.0 - 1.0
		b[i] = saw * sin(PI * t / 0.9) * (0.6 + 0.4 * sin(TAU * 23.0 * t))
	return _to_wav(_norm(b, 0.35), rate, false)


# --- Carillon agréable (objet utile) : Do-Mi-Sol ---
func _gen_chime() -> AudioStreamWAV:
	var rate: int = HI
	var b := _new_buf(0.7, rate)
	var notes := [[0.0, 1046.5], [0.07, 1318.5], [0.14, 1568.0]]
	for n in notes:
		var off: int = int(float(n[0]) * rate)
		for i in range(off, b.size()):
			var t: float = float(i - off) / rate
			b[i] += (sin(TAU * float(n[1]) * t) + 0.25 * sin(TAU * float(n[1]) * 2.0 * t)) * exp(-t * 6.0)
	return _to_wav(_norm(b, 0.45), rate, false)


# --- Échec court (objet inutile, mauvais choix) : deux tons descendants ---
func _gen_fail() -> AudioStreamWAV:
	var rate: int = MID
	var b := _new_buf(0.5, rate)
	for i in b.size():
		var t: float = float(i) / rate
		var f: float = 330.0 if t < 0.18 else 247.0
		var tt: float = t if t < 0.18 else t - 0.18
		var env: float = minf(1.0, tt * 80.0) * exp(-tt * (9.0 if t < 0.18 else 5.0))
		var sq: float = sign(sin(TAU * f * t)) * 0.35 + sin(TAU * f * t) * 0.65
		b[i] = sq * env
	return _to_wav(_norm(b, 0.5), rate, false)


# --- Recharge O2 : sifflement de pression qui monte ---
func _gen_hiss() -> AudioStreamWAV:
	var rate: int = HI
	var b := _new_buf(1.1, rate)
	var low: float = 0.0
	var band: float = 0.0
	for i in b.size():
		var t: float = float(i) / rate
		var w: float = rng.randf_range(-1.0, 1.0)
		var f: float = 2.0 * sin(PI * lerpf(2500.0, 6000.0, t / 1.1) / rate)
		low += f * band
		var high: float = w - low - 0.3 * band
		band += f * high
		var env: float = minf(1.0, t * 10.0) * minf(1.0, (1.1 - t) * 4.0)
		b[i] = band * env * 0.7 + sin(TAU * lerpf(300.0, 600.0, t / 1.1) * t) * 0.15 * env
	return _to_wav(_norm(b, 0.5), rate, false)


# --- Machine (étape de recyclage) : clac + vrombissement ---
func _gen_machine() -> AudioStreamWAV:
	var rate: int = MID
	var b := _new_buf(0.9, rate)
	var lp: float = 0.0
	var ph: float = 0.0
	for i in b.size():
		var t: float = float(i) / rate
		var w: float = rng.randf_range(-1.0, 1.0)
		lp += (w - lp) * 0.2
		var clank: float = lp * exp(-t * 25.0) * 1.5
		var f: float = lerpf(90.0, 220.0, minf(1.0, t / 0.6))
		ph = fposmod(ph + f / rate, 1.0)
		var whir: float = (ph * 2.0 - 1.0) * 0.35 * smoothstep(0.05, 0.25, t) * minf(1.0, (0.9 - t) * 5.0)
		b[i] = clank + whir
	return _to_wav(_norm(b, 0.55), rate, false)


# --- Note de piano douce (Do5), rejouée à d'autres hauteurs ---
func _gen_piano() -> AudioStreamWAV:
	var rate: int = HI
	var b := _new_buf(2.2, rate)
	for i in b.size():
		var t: float = float(i) / rate
		var env: float = minf(1.0, t * 200.0) * exp(-t * 2.2)
		b[i] = (sin(TAU * C5 * t) + 0.45 * sin(TAU * C5 * 2.0 * t) * exp(-t * 3.0) + 0.18 * sin(TAU * C5 * 3.0 * t) * exp(-t * 5.0)) * env
	return _to_wav(_norm(b, 0.5), rate, false)


# --- Nappe d'accord (musique d'ambiance), attaque et relâche lentes ---
func _gen_pad(freqs: Array) -> AudioStreamWAV:
	var rate: int = LO
	var dur: float = 5.0
	var b := _new_buf(dur, rate)
	for i in b.size():
		var t: float = float(i) / rate
		var env: float = smoothstep(0.0, 1.5, t) * smoothstep(dur, dur - 1.8, t)
		var v: float = 0.0
		for f in freqs:
			var ff: float = float(f)
			v += sin(TAU * ff * t + 0.4 * sin(TAU * 0.3 * t)) + 0.2 * sin(TAU * ff * 2.003 * t)
		b[i] = v * env
	return _to_wav(_norm(b, 0.4), rate, false)


func _music_tick(r: float, delta: float) -> void:
	if not music_on:
		return
	_mus_t -= delta
	if _mus_t > 0.0:
		return
	_mus_t += MUSIC_STEP
	var n: int = MUSIC[_mus_i % MUSIC.size()]
	_mus_i += 1
	if n <= -99:
		return
	var p: AudioStreamPlayer = _mus_pool[_mus_pi]
	_mus_pi = (_mus_pi + 1) % _mus_pool.size()
	p.stream = s_piano
	p.pitch_scale = pow(2.0, float(n) / 12.0)
	p.volume_db = lerpf(-25.0, -21.0, r)
	p.play()


## Coupe / relance la petite musique (l'intro a ses propres sons).
func set_music(on: bool) -> void:
	music_on = on
	if not on:
		for p in _mus_pool:
			(p as AudioStreamPlayer).stop()
	else:
		_mus_t = 1.0


func _note(semitones_from_c5: float, vol_db: float, delay: float) -> void:
	var pitch: float = pow(2.0, semitones_from_c5 / 12.0)
	if delay <= 0.0:
		_play(s_piano, vol_db, pitch)
	else:
		_later(delay, func(): _play(s_piano, vol_db, pitch))


func _pad(major: bool, vol_db: float) -> void:
	if music == null:
		music = AudioStreamPlayer.new()
		add_child(music)
	music.stream = s_pad_major if major else s_pad_minor
	music.volume_db = vol_db
	music.play()


# ============================================================
#  AMBIANCE QUI ÉVOLUE AVEC LA VILLE
# ============================================================
func start_ambience() -> void:
	# (22/11) AUCUNE boucle de bruit (vent, mouches, mer, feuillage, cigales) :
	# ces souffles continus étaient perçus comme un vent qui siffle.
	# Seul reste un ronronnement d'usine très bas, fait de notes pures.
	amb_hum = _make_loop_player(s_hum)
	_set_vol(amb_hum, 0.0)
	amb_started = true


func _make_loop_player(stream: AudioStream) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	add_child(p)
	p.play()
	return p


## Appelé à chaque image par main.gd
## r = restauration (0 à 1), ch = force du Chehili (0 à 1)
func update(r: float, ch: float, ppos: Vector3, delta: float) -> void:
	if not amb_started:
		return
	_music_tick(r, delta)
	# industrie : forte à Gabès, plus douce à Skhira, presque absente à Sidi Mansour
	if amb_hum != null:
		var hum_target: float = _hum_level * (1.0 - 0.9 * r)
		var cur: float = db_to_linear(amb_hum.volume_db)
		_set_vol(amb_hum, lerpf(cur, hum_target, 1.0 - exp(-2.0 * delta)))
	_beep_cool = maxf(0.0, _beep_cool - delta)
	if level_id == "gabes" and r < 0.6:
		_creak_timer -= delta
		if _creak_timer <= 0.0:
			_creak_timer = rng.randf_range(16.0, 28.0)
			var cpos: Vector3 = ppos + Vector3(rng.randf_range(-20.0, 20.0), 2.0, rng.randf_range(10.0, 25.0))
			_play_3d(s_creak, cpos, -18.0, rng.randf_range(0.8, 1.1), 10.0)

	# Les moineaux reviennent sur les toits
	if r > 0.12:
		_bird_timer -= delta
		if _bird_timer <= 0.0:
			_bird_timer = lerpf(9.0, 2.5, r) * rng.randf_range(0.7, 1.4)
			var pos: Vector3 = ppos + Vector3(rng.randf_range(-7.0, 7.0), rng.randf_range(4.0, 8.0), rng.randf_range(-12.0, 6.0))
			_play_3d(s_chirps[rng.randi_range(0, s_chirps.size() - 1)], pos, -14.0, rng.randf_range(0.85, 1.2), 6.0)
	# Les mouettes au-dessus de la mer
	if r > 0.55:
		_gull_timer -= delta
		if _gull_timer <= 0.0:
			_gull_timer = rng.randf_range(12.0, 22.0)
			var gpos := Vector3(rng.randf_range(-25.0, 25.0), 14.0, -95.0 + rng.randf_range(-15.0, 10.0))
			_play_3d(s_gull, gpos, -10.0, rng.randf_range(0.9, 1.1), 20.0)


# ============================================================
#  BRUITAGES APPELÉS PAR LE JEU
# ============================================================
func pickup() -> void:
	_play(s_plastic, -9.0, rng.randf_range(1.2, 1.5))


func whoosh() -> void:
	_play(s_whoosh, -16.0, rng.randf_range(0.8, 0.95))


## Bon tri : bruit de la matière qui tombe dans le bac + petit tintement
func good(combo: int, shape: String) -> void:
	var s: AudioStream = s_plastic
	match shape:
		"can":
			s = s_metal
		"jar", "glass":
			s = s_glass
		"paper", "box":
			s = s_paper
		"peel", "dates":
			s = s_organic
	_play(s, -5.0, rng.randf_range(0.92, 1.08))
	_play(s_ting, -14.0, 1.0 + float(mini(combo, 10)) * 0.04)


func bad() -> void:
	_play(s_bonk, -8.0)


func pop() -> void:
	_play(s_puff, -6.0, rng.randf_range(0.8, 1.2))


func step() -> void:
	_play(s_steps[rng.randi_range(0, s_steps.size() - 1)], -16.0, rng.randf_range(0.85, 1.15))


func wind() -> void:
	pass   # (22/11) bourrasques supprimées


## Palier : une volée d'oiseaux et une brise dans les feuilles
func milestone() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var base: Vector3 = cam.global_position
	for i in 4:
		var pos: Vector3 = base + Vector3(rng.randf_range(-6.0, 6.0), rng.randf_range(2.0, 5.0), rng.randf_range(-10.0, -2.0))
		var snd: AudioStream = s_chirps[i % s_chirps.size()]
		_later(i * 0.22, func(): _play_3d(snd, pos, -12.0, rng.randf_range(0.9, 1.2), 8.0))


func flashback() -> void:
	_play(s_wave, -12.0, 0.8)


func meow(pos: Vector3) -> void:
	_play_3d(s_meow, pos, 0.0, rng.randf_range(0.9, 1.15), 6.0)


## Finale : la mer se brise et les mouettes arrivent
func finale() -> void:
	_play(s_wave, -8.0)
	_later(1.2, func(): _play(s_wave, -11.0, 0.9))
	for i in 5:
		var gpos := Vector3(rng.randf_range(-15.0, 15.0), 12.0, -85.0 + rng.randf_range(-10.0, 5.0))
		_later(0.4 + i * 0.5, func(): _play_3d(s_gull, gpos, -8.0, rng.randf_range(0.9, 1.15), 25.0))


# ============================================================
#  BRUITAGES AJOUTÉS (22/11)
# ============================================================
## Ambiance propre à chaque rivage (appelé au chargement du niveau)
func set_level(id: String) -> void:
	level_id = id
	match id:
		"gabes":
			_hum_level = 0.1
		"skhira":
			_hum_level = 0.05
		"sidi_mansour":
			_hum_level = 0.015
		_:
			_hum_level = 0.0


## Objet utile ramassé : carillon agréable
func chime() -> void:
	_play(s_chime, -6.0, rng.randf_range(0.98, 1.04))
	if level_id == "skhira":
		_play(s_paper, -14.0, 0.7)       # tissu manipulé
	else:
		_play(s_plastic, -15.0, rng.randf_range(1.2, 1.5))


## Échec : objet inutile, mauvais bac
func fail() -> void:
	_play(s_fail, -9.0)


## Bip d'alerte d'oxygène (limité à un bip par seconde)
func low_air_beep() -> void:
	if _beep_cool > 0.0:
		return
	_beep_cool = 1.0
	_play(s_beep, -14.0)


## Recharge O2 : sifflement de pression puis respiration
func refill() -> void:
	_play(s_chime, -8.0, 0.9)
	_later(0.5, func(): _play(s_breath, -16.0, 1.1))


## Étape de recyclage réussie : transformation mécanique
func machine() -> void:
	_play(s_machine, -5.0, rng.randf_range(0.95, 1.05))


## Mort : respiration qui ralentit, accord mineur, notes lentes
func death() -> void:
	set_music(false)
	_later(8.0, func(): set_music(true))
	_play(s_breath, -12.0, 0.85)
	_later(2.4, func(): _play(s_breath, -16.0, 0.7))
	_pad(false, -12.0)
	_note(-3.0, -10.0, 1.2)      # La
	_note(-5.0, -11.0, 2.4)      # Sol
	_note(-9.0, -12.0, 3.6)      # Mi


## Rivage terminé : courte phrase pleine d'espoir
func hopeful() -> void:
	_pad(true, -12.0)
	_note(-12.0, -10.0, 0.0)
	_note(-8.0, -10.0, 0.25)
	_note(-5.0, -10.0, 0.5)
	_note(0.0, -9.0, 0.8)
	_note(4.0, -11.0, 1.2)


## Restauration de l'océan : nappe qui monte, vagues, oiseaux
func restore() -> void:
	_pad(true, -10.0)
	_play(s_wave, -8.0, 1.0)
	_later(1.5, func(): _play(s_wave, -10.0, 0.9))
	milestone()


## Petit bateau sur la carte : moteur doux + vagues
func boat() -> void:
	_play(s_wave, -12.0, 1.1)
	_play_for(s_hum, -20.0, 2.2, 5.0)


## Sons de l'intro cinématique, plan par plan
func intro_cue(kind: String) -> void:
	match kind:
		"industrial":
			_play_for(s_hum, -20.0, 1.0, 7.0)
			_play(s_wave, -14.0, 0.7)
			_pad(false, -18.0)
		"boy":
			for k in 4:
				_later(k * 0.45, func(): _play(s_steps[k % s_steps.size()], -10.0, 0.8))
			_later(0.3, func(): _play(s_breath, -15.0))
			_later(2.2, func(): _play(s_beep, -10.0))
			_later(2.6, func(): _play(s_beep, -10.0))
			_later(3.4, func(): _play(s_creak, -14.0, 0.8))
		"room":
			_note(-5.0, -13.0, 0.2)
			_note(-1.0, -13.0, 1.0)
			_note(2.0, -14.0, 1.8)
			_note(0.0, -14.0, 2.8)
		"flashback":
			_play(s_wave, -10.0, 1.0)
			_note(4.0, -12.0, 0.1)
			_note(7.0, -13.0, 0.9)
			_later(0.6, func(): _play(s_chirps[0], -12.0, 1.1))
		"promise":
			_pad(true, -12.0)
			_note(-12.0, -11.0, 0.3)
			_note(-5.0, -11.0, 0.9)
			_note(0.0, -10.0, 1.5)
			_note(4.0, -10.0, 2.2)
		"mission":
			_pad(true, -16.0)
			_note(-12.0, -14.0, 0.4)
			_note(-5.0, -14.0, 1.4)
			_note(0.0, -14.0, 2.4)
		"title":
			_note(7.0, -11.0, 0.1)
			_note(12.0, -12.0, 0.6)
			_play(s_wave, -14.0, 1.2)
