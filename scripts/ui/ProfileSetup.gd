extends Control
## Profil du joueur, avant l'histoire :
##  - « What should we call you? » : 2 à 20 caractères, lettres (accents
##    compris), espaces / apostrophes / tirets ; erreurs claires ; sauvegardé
##    en local (GameState.save_game, jamais envoyé au serveur).
##  - Six avatars 3D (même équipement, même squelette, même contrôleur) :
##    garçon peau foncée, garçon peau claire, fille rousse, fille blonde,
##    fille avec foulard, fille aux cheveux bouclés.
##  - Le nom est FACULTATIF (vide -> « Keeper ») : on ne peut jamais rester
##    bloqué ici. Le champ commence toujours vide.
##  - Téléphones / tablettes : le navigateur n'ouvre pas le clavier du
##    téléphone dans un jeu Godot web -> clavier à l'écran intégré (A-Z,
##    espace, effacer, OK) qui s'ouvre quand on touche le champ du nom.
## confirmed(name, avatar) : Main enregistre le profil et génère le portrait.

signal confirmed(player_name: String, avatar: int)
signal back

const BoyScript := preload("res://scripts/world/Boy.gd")
const CARD := Vector2(140, 200)

var _name_edit: LineEdit
var _error: Label
var _start: Button
var _cards: Array = []          # [{panel, vp, boy, cam, style_n, style_s}]
var _selected: int = -1
var _t: float = 0.0
var _busy: bool = false
var _touch: bool = false
var _kb: Control = null
const DEFAULT_NAME := "Keeper"


func _ready() -> void:
	theme = UiKit.theme()
	UiKit.full_rect(self)
	var bg := TextureRect.new()
	bg.texture = load("res://assets/ui/menu_bg.jpg")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.full_rect(bg)
	add_child(bg)
	var shade := UiKit.full_rect(ColorRect.new()) as ColorRect
	shade.color = Color(0.01, 0.03, 0.06, 0.72)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var col := UiKit.vbox(12)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	UiKit.place(col, Vector2(0.5, 0.5), Vector2.ZERO, 0, 0)
	add_child(col)

	var title := UiKit.label("WHO WILL KEEP THE PROMISE?", 34, UiKit.PAPER, "black")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	var q := UiKit.label("What should we call you?", 22, Color(1.0, 0.82, 0.45), "bold")
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(q)
	_name_edit = LineEdit.new()
	_touch = DisplayServer.is_touchscreen_available() or OS.has_feature("web_android") or OS.has_feature("web_ios") or OS.has_feature("mobile")
	_name_edit.placeholder_text = "Tap to type your name" if _touch else "Your name (optional)"
	_name_edit.max_length = 24
	_name_edit.custom_minimum_size = Vector2(440, 54)
	_name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_edit.add_theme_font_override("font", UiKit.font("bold"))
	_name_edit.add_theme_font_size_override("font_size", 24)
	_name_edit.add_theme_color_override("font_color", UiKit.PAPER)
	_name_edit.add_theme_stylebox_override("normal", UiKit.style(Color(0.03, 0.06, 0.09, 0.92), 14, Color(1, 1, 1, 0.25), 2, false))
	_name_edit.add_theme_stylebox_override("focus", UiKit.style(Color(0.03, 0.06, 0.09, 0.95), 14, UiKit.TEAL, 3, false))
	_name_edit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_name_edit.text_changed.connect(func(_t2: String): _refresh())
	_name_edit.text_submitted.connect(func(_t2: String): _try_start())
	col.add_child(_name_edit)
	if _touch:
		_name_edit.virtual_keyboard_enabled = false
		_name_edit.gui_input.connect(func(e: InputEvent):
			if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
				_show_kb())
	_error = UiKit.label(" ", 16, UiKit.BAD, "bold")
	_error.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_error)

	var pick := UiKit.label("Choose your keeper", 20, UiKit.MUTED, "bold")
	pick.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(pick)
	var row := UiKit.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	for id in GameData.AVATAR_ORDER:
		row.add_child(_make_card(int(id)))

	var btns := UiKit.hbox(18)
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(btns)
	var b_back := UiKit.button("BACK", Color(0.6, 0.6, 0.7), 20, 180)
	b_back.pressed.connect(func(): back.emit())
	btns.add_child(b_back)
	_start = UiKit.button("START", UiKit.TEAL, 26, 300)
	_start.pressed.connect(_try_start)
	btns.add_child(_start)

	# Nouveau joueur : champ du nom TOUJOURS vide (avant, le nom du joueur
	# précédent — ex. « Nour » — restait écrit). L'avatar est présélectionné
	# pour que START soit tout de suite utilisable.
	_name_edit.text = ""
	_select(GameState.avatar_id if GameState.avatar_id >= 0 else 0)
	_refresh()
	if not _touch:
		_name_edit.grab_focus.call_deferred()


func _make_card(id: int) -> Control:
	var av: Dictionary = GameData.avatar(id)
	var n := UiKit.style(Color(0.03, 0.06, 0.09, 0.85), 18, Color(1, 1, 1, 0.14), 2, false)
	var sel := UiKit.style(Color(0.05, 0.14, 0.2, 0.95), 18, Color(0.45, 0.9, 1.0), 4, false)
	for sb in [n, sel]:
		(sb as StyleBoxFlat).content_margin_left = 8
		(sb as StyleBoxFlat).content_margin_right = 8
		(sb as StyleBoxFlat).content_margin_top = 8
		(sb as StyleBoxFlat).content_margin_bottom = 8
	sel.shadow_color = Color(0.35, 0.85, 1.0, 0.55)
	sel.shadow_size = 16
	# carte = bouton (clic souris / toucher fiables), contenu non cliquable
	var panel := Button.new()
	panel.custom_minimum_size = Vector2(CARD.x + 16, CARD.y + 16)
	panel.focus_mode = Control.FOCUS_NONE
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		panel.add_theme_stylebox_override(st, n)
	panel.pressed.connect(_select.bind(id))
	var v := UiKit.vbox(2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.position = Vector2(8, 8)
	panel.add_child(v)

	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.custom_minimum_size = CARD
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(svc)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.size = Vector2i(CARD)
	vp.msaa_3d = Viewport.MSAA_2X
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	svc.add_child(vp)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.82, 0.9)
	e.ambient_light_energy = 0.7
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 160, 0)
	sun.light_energy = 1.3
	sun.light_color = Color(1.0, 0.92, 0.8)
	vp.add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, -20, 0)
	rim.light_energy = 0.6
	rim.light_color = Color(0.5, 0.8, 1.0)
	vp.add_child(rim)
	var boy = BoyScript.new()
	boy.avatar_id = id
	boy.frozen = true
	boy.process_mode = Node.PROCESS_MODE_DISABLED   # pas de physique dans l'aperçu
	vp.add_child(boy)
	var cam := Camera3D.new()
	cam.fov = 34.0
	vp.add_child(cam)
	# (le nœud n'est pas encore dans l'arbre : pas de look_at ici)
	cam.transform = Transform3D(Basis(), Vector3(0, 1.05, -3.7)).looking_at(Vector3(0, 0.95, 0), Vector3.UP)
	cam.current = true

	# (22/11) plus aucune étiquette (garçon / fille / couleur de peau...) :
	# seulement les avatars
	_cards.append({"id": id, "panel": panel, "vp": vp, "boy": boy, "cam": cam, "n": n, "s": sel})
	return panel


## Clavier : flèches gauche / droite ou touches 1 à 7 (ordre affiché)
func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed and not e.echo):
		return
	var k: int = e.physical_keycode
	var order: Array = GameData.AVATAR_ORDER
	var pos: int = order.find(_selected)
	if k >= KEY_1 and k < KEY_1 + order.size() and not _name_edit.has_focus():
		_select(int(order[k - KEY_1]))
	elif k == KEY_RIGHT and not _name_edit.has_focus():
		_select(int(order[(pos + 1) % order.size()]))
	elif k == KEY_LEFT and not _name_edit.has_focus():
		_select(int(order[(pos - 1 + order.size()) % order.size()]) if pos >= 0 else int(order[0]))
	else:
		return
	get_viewport().set_input_as_handled()


func _card(id: int) -> Dictionary:
	for c in _cards:
		if int(c.id) == id:
			return c
	return {}


func _select(id: int) -> void:
	if _card(id).is_empty():
		return
	_selected = id
	for i in _cards.size():
		var c: Dictionary = _cards[i]
		var on: bool = int(c.id) == id
		var btn: Button = c.panel
		for st in ["normal", "hover", "pressed", "focus", "disabled"]:
			btn.add_theme_stylebox_override(st, c.s if on else c.n)
		var vp: SubViewport = c.vp
		var boy: Node3D = c.boy
		if not on:
			boy.rotation.y = 0.0
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_ONCE
	_refresh()


func _refresh() -> void:
	var raw: String = _name_edit.text
	var empty: bool = raw.strip_edges() == ""
	var res: Dictionary = GameState.validate_name(raw)
	if empty:
		_error.text = " "
	elif not bool(res.ok):
		_error.text = String(res.error)
	else:
		_error.text = " "
	_start.disabled = (not empty and not bool(res.ok)) or _selected < 0 or _busy
	_start.modulate.a = 1.0 if not _start.disabled else 0.45


func _try_start() -> void:
	var raw: String = _name_edit.text
	if raw.strip_edges() == "":
		raw = DEFAULT_NAME          # nom facultatif : jamais bloqué
	var res: Dictionary = GameState.validate_name(raw)
	if not bool(res.ok):
		_error.text = String(res.error)
		return
	_hide_kb()
	if _selected < 0:
		_error.text = "Choose one of the six keepers."
		UiKit.set_label_color(_error, Color(1.0, 0.82, 0.45))
		return
	if _busy:
		return
	_busy = true
	_refresh()
	confirmed.emit(String(res.name), _selected)


func _process(delta: float) -> void:
	_t += delta
	if _selected >= 0 and not _busy:
		var boy: Node3D = _card(_selected).boy
		boy.rotation.y = sin(_t * 0.9) * 0.6


# ------------------------------------------------------------ clavier à l'écran
func _show_kb() -> void:
	if _kb != null:
		_kb.visible = true
		return
	_kb = PanelContainer.new()
	_kb.add_theme_stylebox_override("panel", UiKit.style(Color(0.02, 0.05, 0.08, 0.97), 18, Color(0.4, 0.85, 1.0, 0.5), 2, false))
	_kb.anchor_left = 0.0
	_kb.anchor_right = 1.0
	_kb.anchor_top = 1.0
	_kb.anchor_bottom = 1.0
	_kb.offset_top = -330.0
	_kb.offset_left = 12.0
	_kb.offset_right = -12.0
	_kb.offset_bottom = -8.0
	add_child(_kb)
	var v := UiKit.vbox(8)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	_kb.add_child(v)
	for row in ["QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM'-"]:
		var h := UiKit.hbox(8)
		h.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_child(h)
		for ch in row:
			h.add_child(_kb_key(ch, ch, 96))
	var last := UiKit.hbox(8)
	last.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(last)
	last.add_child(_kb_key("DELETE", "<", 200))
	last.add_child(_kb_key("SPACE", " ", 360))
	last.add_child(_kb_key("OK", "OK", 220))


func _kb_key(label: String, value: String, w: int) -> Button:
	var b := UiKit.button(label, UiKit.TEAL if value == "OK" else Color(0.25, 0.4, 0.5), 26, w)
	b.custom_minimum_size = Vector2(w, 64)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(_kb_press.bind(value))
	return b


func _kb_press(value: String) -> void:
	var t: String = _name_edit.text
	match value:
		"OK":
			_hide_kb()
			return
		"<":
			t = t.substr(0, maxi(0, t.length() - 1))
		_:
			if t.length() >= 20:
				return
			var c: String = value
			# Majuscule au début de chaque mot, minuscules ensuite
			if t == "" or t.ends_with(" ") or t.ends_with("-"):
				c = c.to_upper()
			else:
				c = c.to_lower()
			t += c
	_name_edit.text = t
	_name_edit.caret_column = t.length()
	_refresh()


func _hide_kb() -> void:
	if _kb != null:
		_kb.visible = false
	_name_edit.release_focus()
