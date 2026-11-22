extends Control
## Profil du joueur, avant l'histoire :
##  - « What should we call you? » : 2 à 20 caractères, lettres (accents
##    compris), espaces / apostrophes / tirets ; erreurs claires ; sauvegardé
##    en local (GameState.save_game, jamais envoyé au serveur).
##  - Six avatars 3D (même équipement, même squelette, même contrôleur) :
##    garçon peau foncée, garçon peau claire, fille rousse, fille blonde,
##    fille avec foulard, fille aux cheveux bouclés.
##  - START n'est actif qu'avec un nom valide ET un avatar choisi.
## confirmed(name, avatar) : Main enregistre le profil et génère le portrait.

signal confirmed(player_name: String, avatar: int)
signal back

const BoyScript := preload("res://scripts/world/Boy.gd")
const CARD := Vector2(158, 190)

var _name_edit: LineEdit
var _error: Label
var _start: Button
var _cards: Array = []          # [{panel, vp, boy, cam, style_n, style_s}]
var _selected: int = -1
var _t: float = 0.0
var _busy: bool = false


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
	_name_edit.placeholder_text = "Your name"
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
	_error = UiKit.label(" ", 16, UiKit.BAD, "bold")
	_error.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_error)

	var pick := UiKit.label("Choose your keeper", 20, UiKit.MUTED, "bold")
	pick.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(pick)
	var row := UiKit.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	for av in GameData.AVATARS:
		row.add_child(_make_card(int(av.id)))

	var btns := UiKit.hbox(18)
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(btns)
	var b_back := UiKit.button("BACK", Color(0.6, 0.6, 0.7), 20, 180)
	b_back.pressed.connect(func(): back.emit())
	btns.add_child(b_back)
	_start = UiKit.button("START", UiKit.TEAL, 26, 300)
	_start.pressed.connect(_try_start)
	btns.add_child(_start)

	# profil déjà enregistré : on le propose
	if GameState.player_name != "":
		_name_edit.text = GameState.player_name
	if GameState.avatar_id >= 0:
		_select(GameState.avatar_id)
	_refresh()
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
	panel.custom_minimum_size = Vector2(CARD.x + 16, CARD.y + 62)
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

	var l1 := UiKit.label(String(av.label).to_upper(), 17, UiKit.PAPER, "black")
	l1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l1)
	var l2 := UiKit.label(String(av.detail), 14, UiKit.MUTED, "bold")
	l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l2)
	_cards.append({"panel": panel, "vp": vp, "boy": boy, "cam": cam, "n": n, "s": sel})
	return panel


## Clavier : flèches gauche / droite ou touches 1 à 6 pour choisir l'avatar
func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed and not e.echo):
		return
	var k: int = e.physical_keycode
	if k >= KEY_1 and k <= KEY_6:
		_select(k - KEY_1)
	elif k == KEY_RIGHT and not _name_edit.has_focus():
		_select((maxi(_selected, -1) + 1) % _cards.size())
	elif k == KEY_LEFT and not _name_edit.has_focus():
		_select((_selected - 1 + _cards.size()) % _cards.size() if _selected >= 0 else 0)
	else:
		return
	get_viewport().set_input_as_handled()


func _select(id: int) -> void:
	if id < 0 or id >= _cards.size():
		return
	_selected = id
	for i in _cards.size():
		var c: Dictionary = _cards[i]
		var on: bool = i == id
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
	var res: Dictionary = GameState.validate_name(raw)
	if raw.strip_edges() == "":
		_error.text = " "
	elif not bool(res.ok):
		_error.text = String(res.error)
	elif _selected < 0:
		_error.text = " "
	else:
		_error.text = " "
	_start.disabled = not bool(res.ok) or _selected < 0 or _busy
	_start.modulate.a = 1.0 if not _start.disabled else 0.45


func _try_start() -> void:
	var res: Dictionary = GameState.validate_name(_name_edit.text)
	if not bool(res.ok):
		_error.text = String(res.error) if _name_edit.text.strip_edges() != "" else "Please enter your name."
		return
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
		var boy: Node3D = _cards[_selected].boy
		boy.rotation.y = sin(_t * 0.9) * 0.6
