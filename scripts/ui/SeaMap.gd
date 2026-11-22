extends Control
## Carte marine entre deux rivages (golfe de Gabès, stylisé).
## Un petit bateau quitte le port du rivage terminé et rejoint le suivant ;
## derrière lui la mer s'éclaircit peu à peu (des cercles bleus qui « sortent »
## de l'eau), les nappes de pollution qu'il frôle disparaissent, et toute la
## mer bleuit lentement. Le SCORE du rivage décide la distance parcourue :
## plus il est élevé, plus la route s'écarte vers le large et nettoie de mer.
## Le sillage est gardé dans la sauvegarde (GameState.sea_trail).
## Clic / Espace : aller directement à la fin du trajet.

signal finished

const BASE := Vector2(1280, 720)
const PORTS := {
	"sidi_mansour": Vector2(596, 142),
	"skhira": Vector2(516, 362),
	"gabes": Vector2(422, 548),
}
const PORT_NAMES := {"sidi_mansour": "SIDI MANSOUR", "skhira": "SKHIRA", "gabes": "GABÈS"}
const COAST := [Vector2(548, 0), Vector2(572, 70), Vector2(600, 140), Vector2(640, 186),
	Vector2(612, 248), Vector2(560, 300), Vector2(520, 360), Vector2(476, 432),
	Vector2(436, 500), Vector2(420, 548), Vector2(452, 606), Vector2(540, 646),
	Vector2(640, 688), Vector2(690, 720)]
const VOYAGE_TIME := 5.2
const KM_PER_PX := 0.11

var from_id: String = "gabes"
var to_id: String = "skhira"
var level_score: int = 0
var sfx: Node = null
var drives_audio: bool = true

var _p: Array = []            # points de la route (repère 1280x720)
var _len: float = 0.0         # longueur totale (px)
var _t: float = 0.0
var _k: float = 0.0           # avancement 0..1
var _trail_old: Array = []    # sillages des trajets précédents
var _trail_new: Array = []    # [position, instant d'apparition]
var _blotches: Array = []     # nappes de pollution [pos, rayon, nettoyée(0..1)]
var _r_from: float = 0.0
var _r_to: float = 0.33
var _done: bool = false
var _ending: bool = false
var _font: Font
var _s_cache: float = 1.0
var _off_cache: Vector2 = Vector2.ZERO
var _info: Label
var _title: Label


func _ready() -> void:
	theme = UiKit.theme()
	UiKit.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = UiKit.font("bold")
	_ending = to_id == "ending"
	var lv_from: Dictionary = GameData.level(from_id)
	_r_from = float(lv_from.get("r_from", 0.0)) / 100.0
	_r_to = float(lv_from.get("r_to", 33.0)) / 100.0
	_trail_old = GameState.sea_trail.duplicate()
	_build_route()
	var rng := RandomNumberGenerator.new()
	rng.seed = 2060
	for i in 70:
		var pos := Vector2(rng.randf_range(470, 1260), rng.randf_range(20, 700))
		if pos.x < _coast_x(pos.y) + 30.0:
			continue
		var cleared: float = 0.0
		for q in _trail_old:
			if (q as Vector2).distance_to(pos) < 46.0:
				cleared = 1.0
				break
		_blotches.append([pos, rng.randf_range(10.0, 26.0), cleared])

	# cartouche du haut (même style que l'interface)
	var top := UiKit.panel(Color(0.03, 0.05, 0.08, 0.8), 20, Color(0.4, 0.8, 1.0, 0.3))
	UiKit.place(top, Vector2(0.5, 0), Vector2(0, 18), 0, 1)
	add_child(top)
	var v := UiKit.vbox(2)
	top.add_child(v)
	var kick := UiKit.label("VOYAGE ACROSS THE GULF", 14, UiKit.TEAL, "black")
	kick.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(kick)
	var dest: String = "THE OPEN SEA" if _ending else String(PORT_NAMES.get(to_id, to_id))
	_title = UiKit.label("%s  →  %s" % [String(PORT_NAMES.get(from_id, from_id)), dest], 28, UiKit.PAPER, "black")
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_title)
	_info = UiKit.label("", 17, Color(1.0, 0.86, 0.5), "bold")
	UiKit.place(_info, Vector2(0.5, 1), Vector2(0, -34), 0, -1)
	add_child(_info)
	var hint := UiKit.label("Tap to skip", 13, UiKit.MUTED, "bold")
	UiKit.place(hint, Vector2(1, 1), Vector2(-24, -14), -1, -1)
	add_child(hint)
	if sfx != null and sfx.has_method("boat"):
		sfx.boat()


func _coast_x(y: float) -> float:
	for i in COAST.size() - 1:
		var a: Vector2 = COAST[i]
		var b: Vector2 = COAST[i + 1]
		if y >= a.y and y <= b.y:
			return lerpf(a.x, b.x, (y - a.y) / maxf(0.001, b.y - a.y))
	return 700.0


## Route de Bézier : l'écart vers le large dépend du score du rivage.
func _build_route() -> void:
	var bulge: float = clampf(70.0 + float(level_score) * 0.62, 70.0, 380.0)
	var a: Vector2 = PORTS.get(from_id, PORTS.gabes) + Vector2(42, 0)
	var p1: Vector2
	var p2: Vector2
	var b: Vector2
	if _ending:
		b = a + Vector2(10, 46)
		p1 = a + Vector2(bulge * 1.4, -110)
		p2 = a + Vector2(bulge * 1.4, 170)
	else:
		b = PORTS.get(to_id, PORTS.skhira) + Vector2(42, 0)
		var dy: float = b.y - a.y
		p1 = a + Vector2(bulge, dy * 0.15)
		p2 = b + Vector2(bulge, -dy * 0.15)
	_p.clear()
	var n := 120
	for i in n + 1:
		var t: float = float(i) / n
		var u: float = 1.0 - t
		var q: Vector2 = a * u * u * u + p1 * 3.0 * u * u * t + p2 * 3.0 * u * t * t + b * t * t * t
		q.x = clampf(q.x, _coast_x(q.y) + 24.0, BASE.x - 30.0)
		_p.append(q)
	_len = 0.0
	for i in range(1, _p.size()):
		_len += (_p[i] as Vector2).distance_to(_p[i - 1])


func _point_at(k: float) -> Vector2:
	var f: float = clampf(k, 0.0, 1.0) * float(_p.size() - 1)
	var i: int = int(f)
	if i >= _p.size() - 1:
		return _p[_p.size() - 1]
	return (_p[i] as Vector2).lerp(_p[i + 1], f - float(i))


func _process(delta: float) -> void:
	_t += delta
	if _done:
		return
	var prev: float = _k
	_k = clampf(_t / VOYAGE_TIME, 0.0, 1.0)
	_k = _k * _k * (3.0 - 2.0 * _k)
	# sillage : un point tous les ~10 px
	var pos := _point_at(_k)
	if _trail_new.is_empty() or (_trail_new[_trail_new.size() - 1][0] as Vector2).distance_to(pos) > 10.0:
		_trail_new.append([pos, _t])
	for bl in _blotches:
		if float(bl[2]) < 1.0 and (bl[0] as Vector2).distance_to(pos) < 50.0:
			bl[2] = minf(1.0, float(bl[2]) + delta * 2.5)
	var km: float = _len * _k * KM_PER_PX
	_info.text = "Shore score %d  →  %.1f km of sea cleared" % [level_score, km]
	if prev < 1.0 and _k >= 1.0:
		_arrive()
	queue_redraw()


func _arrive() -> void:
	_done = true
	for e in _trail_new:
		GameState.sea_trail.append(e[0])
	while GameState.sea_trail.size() > 900:
		GameState.sea_trail.pop_front()
	GameState.save_game()
	if sfx != null and sfx.has_method("hopeful"):
		sfx.hopeful()
	var tw := create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(self, "modulate:a", 0.0, 0.6)
	tw.tween_callback(func(): finished.emit())


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and not _done:
		_t = VOYAGE_TIME


func _unhandled_input(e: InputEvent) -> void:
	if not _done and (e.is_action_pressed("interact") or e.is_action_pressed("pause")):
		_t = VOYAGE_TIME
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ dessin
func _draw() -> void:
	var sc: Vector2 = size / BASE
	var s: float = minf(sc.x, sc.y)
	var off: Vector2 = (size - BASE * s) * 0.5
	_s_cache = s
	_off_cache = off
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.04, 0.07))
	draw_set_transform(off, 0.0, Vector2(s, s))
	var r: float = lerpf(_r_from, _r_to, _k)
	# mer : brune et terne au début, de plus en plus bleue
	var sea := Color(0.17, 0.16, 0.12).lerp(Color(0.07, 0.34, 0.58), r)
	draw_rect(Rect2(Vector2.ZERO, BASE), sea)
	for i in 6:   # bandes de profondeur
		var c := sea.darkened(0.06 * i)
		var x0: float = 760.0 + i * 90.0
		draw_rect(Rect2(Vector2(x0, 0), Vector2(BASE.x - x0, BASE.y)), Color(c.r, c.g, c.b, 0.35))
	# nappes de pollution (s'effacent quand le bateau passe)
	for bl in _blotches:
		var a: float = (1.0 - float(bl[2])) * (1.0 - r * 0.7)
		if a > 0.02:
			# nappe d'huile irrégulière (ellipses superposées)
			var c0: Vector2 = bl[0]
			var rr: float = float(bl[1])
			draw_set_transform(_off_cache + c0 * _s_cache, 0.4, Vector2(_s_cache * 1.6, _s_cache * 0.8))
			draw_circle(Vector2.ZERO, rr, Color(0.07, 0.06, 0.04, 0.42 * a))
			draw_circle(Vector2(rr * 0.4, rr * 0.2), rr * 0.6, Color(0.06, 0.05, 0.03, 0.35 * a))
			draw_circle(Vector2(-rr * 0.2, -rr * 0.1), rr * 0.35, Color(0.30, 0.22, 0.35, 0.12 * a))
			draw_set_transform(_off_cache, 0.0, Vector2(_s_cache, _s_cache))
	# eau éclaircie des voyages précédents
	for q in _trail_old:
		_draw_clear(q, 1.0)
	# nouveau sillage : chaque cercle « sort » de l'eau et grandit
	for e in _trail_new:
		var age: float = _t - float(e[1])
		_draw_clear(e[0], clampf(age / 0.9, 0.0, 1.0))
		if age < 1.6:
			var rr: float = 8.0 + age * 34.0
			draw_arc(e[0], rr, 0.0, TAU, 28, Color(0.7, 0.95, 1.0, 0.35 * (1.0 - age / 1.6)), 2.0, true)
	# terre
	var land := PackedVector2Array(COAST)
	land.append(Vector2(0, 720))
	land.append(Vector2(0, 0))
	draw_colored_polygon(land, Color(0.36, 0.30, 0.22).lerp(Color(0.40, 0.42, 0.24), r))
	draw_polyline(PackedVector2Array(COAST), Color(0.85, 0.75, 0.55, 0.8), 3.0, true)
	# îles : Kerkennah et Djerba
	_draw_island(Vector2(990, 186), Vector2(46, 18), r)
	_draw_island(Vector2(1032, 216), Vector2(22, 10), r)
	_draw_island(Vector2(760, 650), Vector2(80, 48), r)
	draw_string(_font, Vector2(722, 705), "DJERBA", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.45))
	draw_string(_font, Vector2(958, 160), "KERKENNAH", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.45))
	# route prévue (pointillés)
	for i in range(0, _p.size() - 1, 3):
		draw_line(_p[i], _p[i + 1], Color(1, 1, 1, 0.25), 2.0, true)
	# ports
	for id in PORTS:
		var pp: Vector2 = PORTS[id]
		var active: bool = id == from_id or id == to_id
		draw_circle(pp, 9.0 if active else 6.0, Color(1.0, 0.82, 0.45) if active else Color(0.8, 0.8, 0.8))
		draw_circle(pp, 4.0, Color(0.05, 0.08, 0.12))
		draw_string(_font, pp + Vector2(-150, 6), String(PORT_NAMES[id]), HORIZONTAL_ALIGNMENT_RIGHT, 135, 18, Color(1, 1, 1, 0.9 if active else 0.55))
	# bateau
	var bp := _point_at(_k)
	var ahead := _point_at(minf(1.0, _k + 0.01))
	var ang: float = (ahead - bp).angle() if ahead.distance_to(bp) > 0.01 else 0.0
	_draw_boat(bp, ang)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_clear(p: Vector2, k: float) -> void:
	if k <= 0.0:
		return
	var rad: float = 38.0 * k
	draw_circle(p, rad, Color(0.10, 0.48, 0.80, 0.22 * k))
	draw_circle(p, rad * 0.7, Color(0.14, 0.62, 0.86, 0.22 * k))
	draw_circle(p, rad * 0.4, Color(0.30, 0.80, 0.92, 0.18 * k))


func _draw_island(c: Vector2, rr: Vector2, r: float) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a: float = TAU * i / 24.0
		pts.append(c + Vector2(cos(a) * rr.x * (1.0 + 0.12 * sin(a * 3.0)), sin(a) * rr.y))
	draw_colored_polygon(pts, Color(0.36, 0.30, 0.22).lerp(Color(0.40, 0.42, 0.24), r))


func _draw_boat(p: Vector2, ang: float) -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var sc: Vector2 = size / BASE
	var s: float = minf(sc.x, sc.y)
	var off: Vector2 = (size - BASE * s) * 0.5
	var xf := Transform2D(ang, off + p * s).scaled_local(Vector2(s, s) * 1.6)
	draw_set_transform_matrix(xf)
	# sillage en V
	for k in 3:
		var w: float = 6.0 + k * 6.0
		draw_line(Vector2(-12 - k * 9, 0), Vector2(-24 - k * 12, -w), Color(1, 1, 1, 0.5 - k * 0.14), 1.5, true)
		draw_line(Vector2(-12 - k * 9, 0), Vector2(-24 - k * 12, w), Color(1, 1, 1, 0.5 - k * 0.14), 1.5, true)
	# coque (barque de pêche blanche et bleue)
	var hull := PackedVector2Array([Vector2(-14, -6), Vector2(10, -6), Vector2(18, 0), Vector2(10, 6), Vector2(-14, 6)])
	draw_colored_polygon(hull, Color(0.95, 0.95, 0.92))
	draw_polyline(PackedVector2Array([Vector2(-14, -6), Vector2(10, -6), Vector2(18, 0), Vector2(10, 6), Vector2(-14, 6), Vector2(-14, -6)]), Color(0.10, 0.38, 0.75), 2.0, true)
	draw_circle(Vector2(0, 0), 2.5, Color(0.6, 0.4, 0.2))
	# voile (vue de dessus, gonflée)
	draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(-10, -12), Vector2(6, -9)]), Color(0.98, 0.96, 0.88, 0.95))
	draw_set_transform(off, 0.0, Vector2(s, s))
