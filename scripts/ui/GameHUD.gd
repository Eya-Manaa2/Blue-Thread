extends CanvasLayer
## HUD de jeu : lieu, cœurs (images), score, jauge d'oxygène, objectif +
## flèche de direction, restauration locale (histoire) ET océan global (serveur)
## affichés séparément, toasts, vignette d'alerte, bouton pause, badge jury.

signal pause_pressed
signal action_pressed

var _root: Control
var _title: Label
var _sub: Label
var _hearts: Array = []
var _score: Label
var _air_gauge: Gauge
var _air_lbl: Label
var _obj_lbl: Label
var _timer_lbl: Label
var _name_lbl: Label
var _obj_panel: PanelContainer
var _arrow: Arrow
var _rest_gauge: Gauge
var _rest_lbl: Label
var _global_lbl: Label
var _toast_box: VBoxContainer
var _vignette: ColorRect
var _vig_mat: ShaderMaterial
var _demo_badge: PanelContainer
var _action_btn: Button
var _accent: Color = UiKit.RUST
var _low_air: bool = false
var _t: float = 0.0
var _hurt: float = 0.0
var _dark: float = 0.0

const VIGNETTE := """
shader_type canvas_item;
uniform vec4 tint : source_color = vec4(1.0, 0.1, 0.1, 1.0);
uniform float amount = 0.0;
void fragment() {
	vec2 uv = UV - 0.5;
	float v = smoothstep(0.25, 0.75, length(uv * vec2(1.0, 0.85)));
	COLOR = vec4(tint.rgb, v * amount);
}
"""


class Gauge extends Control:
	var value: float = 1.0
	var color: Color = Color(0.3, 0.8, 1.0)
	var back: Color = Color(0, 0, 0, 0.45)
	var pulse: float = 0.0
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_style_box(_sb(back, 9), r)
		var w: float = maxf(0.0, size.x * clampf(value, 0.0, 1.0))
		if w > 2.0:
			var c: Color = color.lerp(Color(1, 1, 1), pulse * 0.35)
			draw_style_box(_sb(c, 9), Rect2(Vector2.ZERO, Vector2(w, size.y)))
			draw_style_box(_sb(Color(1, 1, 1, 0.22), 9), Rect2(Vector2(2, 2), Vector2(maxf(0.0, w - 4.0), size.y * 0.38)))
	func _sb(c: Color, rad: int) -> StyleBoxFlat:
		var s := StyleBoxFlat.new()
		s.bg_color = c
		s.set_corner_radius_all(rad)
		s.anti_aliasing = true
		return s


class Arrow extends Control:
	var angle: float = 0.0
	var color: Color = Color(1, 1, 1)
	func _draw() -> void:
		var c := size * 0.5
		var pts := PackedVector2Array([Vector2(0, -14), Vector2(10, 10), Vector2(0, 4), Vector2(-10, 10)])
		var out := PackedVector2Array()
		for p in pts:
			out.append(c + p.rotated(angle))
		draw_colored_polygon(out, color)


class PauseIcon extends Control:
	func _draw() -> void:
		draw_rect(Rect2(size * 0.5 + Vector2(-9, -11), Vector2(6, 22)), Color(1, 1, 1))
		draw_rect(Rect2(size * 0.5 + Vector2(3, -11), Vector2(6, 22)), Color(1, 1, 1))


func _ready() -> void:
	layer = 5
	_root = UiKit.full_rect(Control.new())
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UiKit.theme()
	add_child(_root)

	_vignette = UiKit.full_rect(ColorRect.new()) as ColorRect
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vig_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = VIGNETTE
	_vig_mat.shader = sh
	_vignette.material = _vig_mat
	_root.add_child(_vignette)

	# ---- carte en haut à gauche : lieu, cœurs, score
	var card := UiKit.panel(Color(0.03, 0.05, 0.08, 0.72), 18)
	card.position = Vector2(18, 16)
	_root.add_child(card)
	var v := UiKit.vbox(6)
	card.add_child(v)
	_title = UiKit.label("GABÈS", 30, UiKit.PAPER, "black")
	v.add_child(_title)
	_sub = UiKit.label("The seaside oasis · 2060", 15, UiKit.MUTED, "bold")
	v.add_child(_sub)
	_name_lbl = UiKit.label("", 15, Color(1.0, 0.82, 0.45), "black")
	v.add_child(_name_lbl)
	var row := UiKit.hbox(6)
	v.add_child(row)
	for i in GameState.MAX_HEARTS:
		var h := UiKit.tex("res://assets/icons/heart.png", Vector2(34, 34))
		h.pivot_offset = Vector2(17, 17)
		row.add_child(h)
		_hearts.append(h)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(16, 0)
	row.add_child(spacer)
	_score = UiKit.label("0", 28, Color(1.0, 0.86, 0.4), "black")
	row.add_child(_score)
	var pts := UiKit.label("PTS", 14, UiKit.MUTED, "bold")
	pts.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(pts)
	var air_row := UiKit.hbox(8)
	v.add_child(air_row)
	air_row.add_child(UiKit.tex("res://assets/icons/o2.png", Vector2(30, 30)))
	_air_gauge = Gauge.new()
	_air_gauge.custom_minimum_size = Vector2(170, 18)
	_air_gauge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	air_row.add_child(_air_gauge)
	_air_lbl = UiKit.label("AIR 100%", 15, UiKit.PAPER, "bold")
	air_row.add_child(_air_lbl)

	# ---- objectif en haut au centre + flèche
	_obj_panel = UiKit.panel(Color(0.03, 0.05, 0.08, 0.72), 22)
	_obj_panel.custom_minimum_size = Vector2(400, 0)
	UiKit.place(_obj_panel, Vector2(0.5, 0), Vector2(0, 16), 0, 1)
	_root.add_child(_obj_panel)
	var oh := UiKit.hbox(12)
	_obj_panel.add_child(oh)
	_arrow = Arrow.new()
	_arrow.custom_minimum_size = Vector2(32, 32)
	oh.add_child(_arrow)
	_obj_lbl = UiKit.label("Collect PAPER  0 / 5", 22, UiKit.PAPER, "bold")
	_obj_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_obj_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	oh.add_child(_obj_lbl)
	_timer_lbl = UiKit.label("", 22, UiKit.PAPER, "black")
	_timer_lbl.visible = false
	oh.add_child(_timer_lbl)

	# ---- restauration locale + océan global (deux valeurs distinctes)
	var rc := UiKit.panel(Color(0.03, 0.05, 0.08, 0.72), 18)
	UiKit.place(rc, Vector2(0, 1), Vector2(18, -18), 1, -1)
	_root.add_child(rc)
	var rv := UiKit.vbox(5)
	rc.add_child(rv)
	_rest_lbl = UiKit.label("SHORE RESTORED  0%", 16, UiKit.PAPER, "black")
	rv.add_child(_rest_lbl)
	_rest_gauge = Gauge.new()
	_rest_gauge.custom_minimum_size = Vector2(260, 12)
	rv.add_child(_rest_gauge)
	_global_lbl = UiKit.label("Shared ocean (server): --", 13, UiKit.MUTED, "bold")
	rv.add_child(_global_lbl)

	# ---- toasts
	_toast_box = UiKit.vbox(6)
	_toast_box.custom_minimum_size = Vector2(500, 0)
	UiKit.place(_toast_box, Vector2(0.5, 0.36), Vector2.ZERO, 0, 1)
	_toast_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_root.add_child(_toast_box)

	# ---- pause (en bas à droite pour ne pas gêner le HUD réseau en haut à droite)
	var pb := Button.new()
	pb.custom_minimum_size = Vector2(56, 56)
	pb.add_theme_stylebox_override("normal", UiKit.style(Color(0, 0, 0, 0.5), 28, Color(1, 1, 1, 0.25), 1, false))
	pb.add_theme_stylebox_override("hover", UiKit.style(Color(0, 0, 0, 0.7), 28, Color(1, 1, 1, 0.5), 1, false))
	pb.add_theme_stylebox_override("pressed", UiKit.style(Color(0, 0, 0, 0.8), 28, Color(1, 1, 1, 0.5), 1, false))
	pb.add_theme_stylebox_override("focus", UiKit.style(Color(0, 0, 0, 0.5), 28, Color(1, 1, 1, 0.25), 1, false))
	UiKit.place(pb, Vector2(1, 1), Vector2(-20, -20), -1, -1)
	pb.focus_mode = Control.FOCUS_NONE
	var pi := PauseIcon.new()
	UiKit.full_rect(pi)
	pi.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pb.add_child(pi)
	pb.pressed.connect(func(): pause_pressed.emit())
	_root.add_child(pb)

	# ---- bouton d'action tactile
	_action_btn = UiKit.button("ACTION", UiKit.TEAL, 20, 150)
	UiKit.place(_action_btn, Vector2(1, 1), Vector2(-96, -20), -1, -1)
	_action_btn.visible = false
	_action_btn.focus_mode = Control.FOCUS_NONE
	_action_btn.pressed.connect(func(): action_pressed.emit())
	_root.add_child(_action_btn)

	# ---- badge jury
	_demo_badge = UiKit.panel(Color(0.55, 0.12, 0.6, 0.85), 14)
	UiKit.place(_demo_badge, Vector2(0.5, 1), Vector2(0, -20), 0, -1)
	var dl := UiKit.label("JURY DEMO  ·  F2 skips the current phase", 15, Color(1, 1, 1), "bold")
	_demo_badge.add_child(dl)
	_demo_badge.visible = false
	_root.add_child(_demo_badge)

	GameState.score_changed.connect(_on_score)
	GameState.hearts_changed.connect(_on_hearts)
	GameState.air_changed.connect(_on_air)
	GameState.restoration_changed.connect(_on_restoration)
	GameState.heart_lost.connect(_on_heart_lost)
	_on_score(GameState.score, 0, "")
	_on_hearts(GameState.hearts)
	_on_air(GameState.air)
	_on_restoration(GameState.local_restoration)


func set_level(level_id: String) -> void:
	var lv: Dictionary = GameData.level(level_id)
	_title.text = String(lv.get("title", ""))
	_sub.text = "%s · %s" % [lv.get("subtitle", ""), lv.get("year", "2060")]
	_demo_badge.visible = GameState.demo_mode
	_name_lbl.text = "KEEPER: " + GameState.display_name().to_upper()


## Chronomètre de collecte (NAN = masqué)
func set_timer(seconds: float, warn: bool = false) -> void:
	_timer_lbl.visible = not is_nan(seconds)
	if _timer_lbl.visible:
		var t: int = int(ceil(maxf(0.0, seconds)))
		_timer_lbl.text = "%d:%02d" % [t / 60, t % 60]
		UiKit.set_label_color(_timer_lbl, UiKit.BAD if warn else UiKit.PAPER)


func flash_timer_penalty() -> void:
	_timer_lbl.pivot_offset = _timer_lbl.size * 0.5
	var tw := create_tween()
	tw.tween_property(_timer_lbl, "scale", Vector2(1.5, 1.5), 0.08)
	tw.tween_property(_timer_lbl, "scale", Vector2.ONE, 0.3)


## Vignette sombre (scène de mort) : 0..1
func set_dark_vignette(amount: float) -> void:
	_vig_mat.set_shader_parameter("tint", Color(0, 0, 0, 1) if amount > 0.0 else Color(1.0, 0.1, 0.1, 1))
	_dark = amount


func set_objective(text: String) -> void:
	_obj_lbl.text = text
	var tw := create_tween()
	_obj_panel.pivot_offset = _obj_panel.size * 0.5
	tw.tween_property(_obj_panel, "scale", Vector2(1.08, 1.08), 0.1)
	tw.tween_property(_obj_panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)


## angle écran (radians, 0 = vers le haut) ; NAN = masquer la flèche
func set_arrow(angle: float) -> void:
	_arrow.visible = not is_nan(angle)
	if _arrow.visible:
		_arrow.angle = angle
		_arrow.queue_redraw()


func set_action(text: String) -> void:
	_action_btn.visible = text != ""
	if text != "":
		_action_btn.text = text


func toast(text: String, col: Color = UiKit.PAPER, big: bool = false) -> void:
	var p := UiKit.panel(Color(0.02, 0.04, 0.07, 0.8), 16, Color(col.r, col.g, col.b, 0.5))
	var l := UiKit.label(text, 26 if big else 20, col, "black")
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_toast_box.add_child(p)
	p.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.15)
	tw.tween_interval(1.6 if not big else 2.4)
	tw.tween_property(p, "modulate:a", 0.0, 0.35)
	tw.tween_callback(p.queue_free)
	while _toast_box.get_child_count() > 3:
		_toast_box.get_child(0).queue_free()
		break


## Avertissement éducatif (objet piège) : titre + explication courte
func toast_tip(title: String, body: String, col: Color = UiKit.BAD) -> void:
	var p := UiKit.panel(Color(0.02, 0.04, 0.07, 0.88), 16, Color(col.r, col.g, col.b, 0.6))
	var v := UiKit.vbox(4)
	p.add_child(v)
	var t := UiKit.label(title, 22, col, "black")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var b := UiKit.label(body, 17, UiKit.PAPER, "regular")
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(520, 0)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(b)
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_toast_box.add_child(p)
	p.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.15)
	tw.tween_interval(3.2)
	tw.tween_property(p, "modulate:a", 0.0, 0.35)
	tw.tween_callback(p.queue_free)
	while _toast_box.get_child_count() > 3:
		_toast_box.get_child(0).queue_free()
		break


func _on_heart_lost(_reason: String) -> void:
	_hurt = 1.0


func _on_score(score: int, delta: int, _reason: String) -> void:
	_score.text = str(score)
	if delta != 0:
		_score.pivot_offset = _score.size * 0.5
		var tw := create_tween()
		tw.tween_property(_score, "scale", Vector2(1.3, 1.3), 0.08)
		tw.tween_property(_score, "scale", Vector2.ONE, 0.2)


func _on_hearts(h: int) -> void:
	for i in _hearts.size():
		var t: TextureRect = _hearts[i]
		var full: bool = i < h
		var path := "res://assets/icons/heart.png" if full else "res://assets/icons/heart_empty.png"
		if t.texture.resource_path != path:
			t.texture = load(path)
			var tw := create_tween()
			tw.tween_property(t, "scale", Vector2(1.5, 1.5), 0.1)
			tw.tween_property(t, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BOUNCE)


func _on_air(a: float) -> void:
	_air_gauge.value = a / GameState.MAX_AIR
	_low_air = a < 25.0
	_air_gauge.color = Color(1.0, 0.3, 0.25) if _low_air else Color(0.35, 0.85, 1.0)
	_air_lbl.text = "AIR %d%%" % int(round(a))
	_air_gauge.queue_redraw()


func _on_restoration(p: float) -> void:
	_accent = UiKit.accent(p)
	_rest_lbl.text = "SHORE RESTORED  %d%%" % int(round(p))
	_rest_gauge.value = p / 100.0
	_rest_gauge.color = _accent
	_rest_gauge.queue_redraw()
	_arrow.color = _accent


func _process(delta: float) -> void:
	_t += delta
	_hurt = maxf(0.0, _hurt - delta * 1.6)
	var low: float = (0.35 + 0.25 * sin(_t * 6.0)) if _low_air else 0.0
	_vig_mat.set_shader_parameter("amount", _dark if _dark > 0.0 else maxf(low, _hurt * 0.8))
	_air_gauge.pulse = (0.5 + 0.5 * sin(_t * 8.0)) if _low_air else 0.0
	if _low_air:
		_air_gauge.queue_redraw()
	if OnlineService.ocean_percent >= 0.0:
		_global_lbl.text = "Shared ocean (server, all players): %d%%" % int(round(OnlineService.ocean_percent))
	else:
		_global_lbl.text = "Shared ocean (server): offline"
