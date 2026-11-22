extends CanvasLayer
## Dialogues : Mima parle par la radio de la montre de Yassine (portrait
## « onde radio » animé) ; Yassine a son portrait tiré de la référence.
## show_lines(lines, on_done) — lines = [["MIMA", "texte"], ...]
## Espace / Entrée / E / clic / toucher : accélère puis passe à la suite.
## (le toucher arrive comme un clic souris émulé : on ne le traite qu'une fois)

signal finished

var _root: Control
var _panel: PanelContainer
var _name: Label
var _text: Label
var _portrait_boy: TextureRect
var _portrait_radio: Radio
var _hint: Label
var _lines: Array = []
var _i: int = 0
var _on_done: Callable
var _typing: Tween
var active: bool = false
var radio_mode: bool = true      # Mima parle par la radio (false : en personne, à la fin)
var mima_portrait: Texture2D = null   # portrait de Mima (fin, en personne)


class Radio extends Control:
	var t: float = 0.0
	func _process(delta: float) -> void:
		t += delta
		queue_redraw()
	func _draw() -> void:
		var c := size * 0.5
		var r: float = minf(size.x, size.y) * 0.5
		draw_circle(c, r, Color(0.04, 0.16, 0.24))
		draw_arc(c, r - 2.0, 0.0, TAU, 48, Color(0.3, 0.85, 1.0, 0.9), 3.0, true)
		for i in 9:
			var x: float = c.x - r * 0.62 + i * r * 0.155
			var h: float = r * (0.12 + 0.5 * absf(sin(t * 7.0 + i * 0.9) * sin(t * 2.3 + i)))
			draw_line(Vector2(x, c.y - h), Vector2(x, c.y + h), Color(0.4, 0.92, 1.0), 4.0, true)


func _ready() -> void:
	layer = 8
	_root = UiKit.full_rect(Control.new())
	_root.theme = UiKit.theme()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_panel = UiKit.panel(Color(0.02, 0.04, 0.07, 0.88), 24, Color(0.4, 0.8, 1.0, 0.35))
	_panel.custom_minimum_size = Vector2(900, 0)
	UiKit.place(_panel, Vector2(0.5, 1), Vector2(0, -24), 0, -1)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_panel)
	var h := UiKit.hbox(22)
	_panel.add_child(h)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(120, 120)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(holder)
	_portrait_boy = UiKit.tex("res://assets/ui/boy_portrait.png")
	UiKit.full_rect(_portrait_boy)
	holder.add_child(_portrait_boy)
	_portrait_radio = Radio.new()
	UiKit.full_rect(_portrait_radio)
	_portrait_radio.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_portrait_radio)
	var v := UiKit.vbox(6)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	_name = UiKit.label("MIMA", 22, UiKit.TEAL, "black")
	v.add_child(_name)
	_text = UiKit.label("", 24, UiKit.PAPER, "regular")
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(700, 70)
	v.add_child(_text)
	_hint = UiKit.label("Space / tap to continue", 14, UiKit.MUTED, "bold")
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(_hint)
	_panel.gui_input.connect(_on_panel_input)
	_root.visible = false


func show_lines(lines: Array, on_done: Callable = Callable()) -> void:
	_lines = lines
	_i = 0
	_on_done = on_done
	active = true
	_root.visible = true
	_panel.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_panel, "modulate:a", 1.0, 0.2)
	_show_current()


func _show_current() -> void:
	var line: Array = _lines[_i]
	var who: String = String(line[0])
	var is_mima: bool = who == "MIMA"
	if is_mima:
		_name.text = "MIMA  ·  RADIO" if radio_mode else "MIMA"
	elif who == "PLAYER" or who == "YASSINE":
		_name.text = GameState.display_name().to_upper()
	else:
		_name.text = who
	UiKit.set_label_color(_name, UiKit.TEAL if is_mima else Color(1.0, 0.82, 0.45))
	var mima_face: bool = is_mima and not radio_mode and mima_portrait != null
	_portrait_boy.visible = not is_mima or mima_face
	_portrait_radio.visible = is_mima and not mima_face
	if mima_face:
		_portrait_boy.texture = mima_portrait
	elif not is_mima and GameState.portrait != null:
		_portrait_boy.texture = GameState.portrait
	_text.text = String(line[1]).replace("{name}", GameState.display_name())
	_text.visible_ratio = 0.0
	if _typing != null and _typing.is_valid():
		_typing.kill()
	_typing = create_tween()
	_typing.tween_property(_text, "visible_ratio", 1.0, maxf(0.6, _text.text.length() * 0.022))


func _advance() -> void:
	if not active:
		return
	if _text.visible_ratio < 1.0:
		if _typing != null and _typing.is_valid():
			_typing.kill()
		_text.visible_ratio = 1.0
		return
	_i += 1
	if _i >= _lines.size():
		active = false
		var tw := create_tween()
		tw.tween_property(_panel, "modulate:a", 0.0, 0.15)
		tw.tween_callback(func():
			_root.visible = false
			finished.emit()
			if _on_done.is_valid():
				_on_done.call())
		return
	_show_current()


func _on_panel_input(e: InputEvent) -> void:
	if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
		_advance()
		get_viewport().set_input_as_handled()


func _unhandled_input(e: InputEvent) -> void:
	if not active:
		return
	if e.is_action_pressed("interact"):
		_advance()
		get_viewport().set_input_as_handled()
	elif (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
		_advance()
		get_viewport().set_input_as_handled()
