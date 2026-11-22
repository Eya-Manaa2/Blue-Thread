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

var _pool: Array = []
var _pool_i: int = 0
var _bird_timer: float = 3.0
var _gull_timer: float = 6.0


func _ready() -> void:
	rng.seed = 77
	world = get_parent() as Node3D
	for i in 12:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
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


func _play(stream: AudioStream, vol_db: float = 0.0, pitch: float = 1.0) -> void:
	var p: AudioStreamPlayer = _pool[_pool_i]
	_pool_i = (_pool_i + 1) % _pool.size()
	p.stream = stream
	p.volume_db = vol_db
	p.pitch_scale = pitch
	p.play()


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
	s_ocean = _gen_ocean()
	s_wind = _gen_wind()
	s_flies = _gen_flies()
	s_leaves = _gen_leaves()
	s_cicadas = _gen_cicadas()
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
	s_gust = _gen_gust()
	s_wave = _gen_wave()


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
		lp += (w - lp) * (0.03 + 0.25 * env)
		lp2 += (w - lp2) * 0.4
		b[i] = lp * env * 1.5 + (w - lp2) * env * 0.4
	return _to_wav(_norm(b, 0.9), rate, false)


# ============================================================
#  AMBIANCE QUI ÉVOLUE AVEC LA VILLE
# ============================================================
func start_ambience() -> void:
	amb_wind = _make_loop_player(s_wind)
	amb_flies = _make_loop_player(s_flies)
	amb_leaves = _make_loop_player(s_leaves)
	amb_cicadas = _make_loop_player(s_cicadas)
	_set_vol(amb_leaves, 0.0)
	_set_vol(amb_cicadas, 0.0)
	if world != null:
		amb_ocean = AudioStreamPlayer3D.new()
		amb_ocean.stream = s_ocean
		amb_ocean.unit_size = 30.0
		amb_ocean.max_distance = 400.0
		world.add_child(amb_ocean)
		amb_ocean.global_position = Vector3(0, -3, -92)
		amb_ocean.play()
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
	_set_vol(amb_wind, 0.12 + 0.5 * (1.0 - r) + 0.9 * ch)
	amb_wind.pitch_scale = 1.0 + 0.35 * ch
	_set_vol(amb_flies, 0.25 * pow(1.0 - r, 2.0))
	_set_vol(amb_leaves, 0.45 * _smooth(0.25, 0.7, r))
	_set_vol(amb_cicadas, 0.28 * _smooth(0.45, 0.85, r))
	if amb_ocean != null:
		amb_ocean.volume_db = linear_to_db(0.45 + 0.55 * r) + 6.0

	# Les moineaux reviennent sur les toits
	if r > 0.12:
		_bird_timer -= delta
		if _bird_timer <= 0.0:
			_bird_timer = lerpf(5.0, 0.7, r) * rng.randf_range(0.6, 1.4)
			var pos: Vector3 = ppos + Vector3(rng.randf_range(-7.0, 7.0), rng.randf_range(4.0, 8.0), rng.randf_range(-12.0, 6.0))
			_play_3d(s_chirps[rng.randi_range(0, s_chirps.size() - 1)], pos, -4.0, rng.randf_range(0.85, 1.2), 6.0)
	# Les mouettes au-dessus de la mer
	if r > 0.55:
		_gull_timer -= delta
		if _gull_timer <= 0.0:
			_gull_timer = rng.randf_range(5.0, 11.0)
			var gpos := Vector3(rng.randf_range(-25.0, 25.0), 14.0, -95.0 + rng.randf_range(-15.0, 10.0))
			_play_3d(s_gull, gpos, 2.0, rng.randf_range(0.9, 1.1), 20.0)


# ============================================================
#  BRUITAGES APPELÉS PAR LE JEU
# ============================================================
func pickup() -> void:
	_play(s_plastic, -9.0, rng.randf_range(1.2, 1.5))


func whoosh() -> void:
	_play(s_whoosh, -6.0, rng.randf_range(0.9, 1.15))


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
	_play(s, 0.0, rng.randf_range(0.92, 1.08))
	_play(s_ting, -12.0, 1.0 + float(mini(combo, 10)) * 0.04)


func bad() -> void:
	_play(s_bonk, -1.0)


func pop() -> void:
	_play(s_puff, -6.0, rng.randf_range(0.8, 1.2))


func step() -> void:
	_play(s_steps[rng.randi_range(0, s_steps.size() - 1)], -16.0, rng.randf_range(0.85, 1.15))


func wind() -> void:
	_play(s_gust, 0.0)
	_later(0.7, func(): _play(s_gust, -3.0, 0.8))


## Palier : une volée d'oiseaux et une brise dans les feuilles
func milestone() -> void:
	_play(s_gust, -10.0, 1.3)
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var base: Vector3 = cam.global_position
	for i in 4:
		var pos: Vector3 = base + Vector3(rng.randf_range(-6.0, 6.0), rng.randf_range(2.0, 5.0), rng.randf_range(-10.0, -2.0))
		var snd: AudioStream = s_chirps[i % s_chirps.size()]
		_later(i * 0.18, func(): _play_3d(snd, pos, 0.0, rng.randf_range(0.9, 1.2), 8.0))


func flashback() -> void:
	_play(s_gust, -4.0, 0.6)
	_play(s_wave, -8.0, 0.8)


func meow(pos: Vector3) -> void:
	_play_3d(s_meow, pos, 0.0, rng.randf_range(0.9, 1.15), 6.0)


## Finale : la mer se brise et les mouettes arrivent
func finale() -> void:
	_play(s_wave, 0.0)
	_later(1.2, func(): _play(s_wave, -4.0, 0.9))
	for i in 5:
		var gpos := Vector3(rng.randf_range(-15.0, 15.0), 12.0, -85.0 + rng.randf_range(-10.0, 5.0))
		_later(0.4 + i * 0.5, func(): _play_3d(s_gull, gpos, 4.0, rng.randf_range(0.9, 1.15), 25.0))
