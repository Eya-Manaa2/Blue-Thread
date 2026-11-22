class_name UiKit
## Kit d'interface : polices Fira Sans (incluses, donc identiques sur le web),
## panneaux arrondis, boutons, palette qui passe de la rouille au turquoise
## avec la restauration. Aucun glyphe absent de la police n'est utilisé
## (pas de ●, ✔, ♥ : ce sont des images ou des formes dessinées).

const RUST := Color(0.95, 0.52, 0.22)
const TEAL := Color(0.18, 0.84, 0.92)
const INK := Color(0.04, 0.06, 0.09, 0.78)
const PAPER := Color(0.96, 0.97, 0.98)
const MUTED := Color(0.72, 0.78, 0.84)
const GOOD := Color(0.30, 0.86, 0.52)
const BAD := Color(1.0, 0.36, 0.34)

static var _fonts: Dictionary = {}


static func font(weight: String = "regular") -> FontFile:
	if not _fonts.has(weight):
		var path := "res://assets/fonts/FiraSans-Regular.ttf"
		if weight == "bold":
			path = "res://assets/fonts/FiraSans-Bold.ttf"
		elif weight == "black":
			path = "res://assets/fonts/FiraSans-Black.ttf"
		_fonts[weight] = load(path)
	return _fonts[weight]


## Couleur d'accent selon la restauration locale (0..100).
static func accent(percent: float) -> Color:
	return RUST.lerp(TEAL, smoothstep(0.0, 100.0, percent))


static func style(bg: Color, radius: int = 18, border: Color = Color(0, 0, 0, 0), border_w: int = 0, shadow: bool = true) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	if border_w > 0:
		s.border_color = border
		s.set_border_width_all(border_w)
	if shadow:
		s.shadow_color = Color(0, 0, 0, 0.35)
		s.shadow_size = 12
		s.shadow_offset = Vector2(0, 4)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	s.anti_aliasing = true
	return s


static func label(text: String, size: int, col: Color = PAPER, weight: String = "regular", outline: int = 0) -> Label:
	var l := Label.new()
	l.text = text
	var ls := LabelSettings.new()
	ls.font = font(weight)
	ls.font_size = size
	ls.font_color = col
	if outline > 0:
		ls.outline_size = outline
		ls.outline_color = Color(0, 0, 0, 0.55)
	ls.shadow_size = 2 if size >= 18 else 0
	ls.shadow_color = Color(0, 0, 0, 0.45)
	ls.shadow_offset = Vector2(0, 2)
	l.label_settings = ls
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func set_label_color(l: Label, col: Color) -> void:
	if l.label_settings != null:
		l.label_settings.font_color = col


static func button(text: String, accent_col: Color = TEAL, size: int = 24, min_w: float = 280.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, size * 2.3)
	b.add_theme_font_override("font", font("black"))
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", PAPER)
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_color_override("font_pressed_color", Color(0.9, 0.95, 1))
	b.add_theme_color_override("font_focus_color", Color(1, 1, 1))
	var n := style(Color(accent_col.r * 0.55, accent_col.g * 0.55, accent_col.b * 0.55, 0.88), 16, accent_col, 2, true)
	var h := style(Color(accent_col.r * 0.75, accent_col.g * 0.75, accent_col.b * 0.75, 0.95), 16, accent_col.lightened(0.3), 3, true)
	var p := style(Color(accent_col.r * 0.4, accent_col.g * 0.4, accent_col.b * 0.4, 1.0), 16, accent_col, 3, false)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("focus", h)
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_entered.connect(func():
		var tw := b.create_tween()
		tw.tween_property(b, "scale", Vector2(1.03, 1.03), 0.08))
	b.mouse_exited.connect(func():
		var tw := b.create_tween()
		tw.tween_property(b, "scale", Vector2.ONE, 0.1))
	b.resized.connect(func(): b.pivot_offset = b.size * 0.5)
	return b


static func ghost_button(text: String, size: int = 18) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", font("bold"))
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", MUTED)
	b.add_theme_color_override("font_hover_color", PAPER)
	var s := style(Color(0, 0, 0, 0.35), 12, Color(1, 1, 1, 0.18), 1, false)
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	b.add_theme_stylebox_override("normal", s)
	b.add_theme_stylebox_override("hover", style(Color(0, 0, 0, 0.55), 12, Color(1, 1, 1, 0.4), 1, false))
	b.add_theme_stylebox_override("pressed", s)
	b.add_theme_stylebox_override("focus", s)
	return b


static func tex(path: String, size: Vector2 = Vector2.ZERO) -> TextureRect:
	var t := TextureRect.new()
	t.texture = load(path)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if size != Vector2.ZERO:
		t.custom_minimum_size = size
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


static func panel(bg: Color = INK, radius: int = 20, border: Color = Color(1, 1, 1, 0.08)) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", style(bg, radius, border, 1, true))
	return p


static func full_rect(c: Control) -> Control:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c


## Place un contrôle sur un point d'ancrage (0..1) avec un décalage en pixels.
## grow : -1 = vers la gauche/le haut, 0 = centré, 1 = vers la droite/le bas.
static func place(c: Control, anchor: Vector2, offset: Vector2, grow_h: int = 1, grow_v: int = 1) -> Control:
	c.anchor_left = anchor.x
	c.anchor_right = anchor.x
	c.anchor_top = anchor.y
	c.anchor_bottom = anchor.y
	c.offset_left = offset.x
	c.offset_right = offset.x
	c.offset_top = offset.y
	c.offset_bottom = offset.y
	var gm := {-1: Control.GROW_DIRECTION_BEGIN, 0: Control.GROW_DIRECTION_BOTH, 1: Control.GROW_DIRECTION_END}
	c.grow_horizontal = gm[grow_h]
	c.grow_vertical = gm[grow_v]
	return c


static func theme() -> Theme:
	var t := Theme.new()
	t.default_font = font("regular")
	t.default_font_size = 18
	return t


static func vbox(sep: int = 10) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v


static func hbox(sep: int = 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return h
