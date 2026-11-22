extends CanvasLayer
## Fenêtre modale générique (pause, plus d'air, plus de cœurs).
## open(title, subtitle, [[texte, callable, couleur], ...])

var _root: Control
var is_open: bool = false
var _cancel: Callable


func _ready() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = UiKit.full_rect(Control.new())
	_root.theme = UiKit.theme()
	add_child(_root)
	_root.visible = false


func open(title: String, subtitle: String, buttons: Array, accent: Color = UiKit.TEAL, cancel: Callable = Callable()) -> void:
	_cancel = cancel
	for c in _root.get_children():
		c.queue_free()
	is_open = true
	_root.visible = true
	var dim := UiKit.full_rect(ColorRect.new()) as ColorRect
	dim.color = Color(0, 0.01, 0.03, 0.7)
	_root.add_child(dim)
	var p := UiKit.panel(Color(0.03, 0.06, 0.09, 0.96), 26, Color(accent.r, accent.g, accent.b, 0.5))
	p.custom_minimum_size = Vector2(560, 0)
	UiKit.place(p, Vector2(0.5, 0.5), Vector2.ZERO, 0, 0)
	_root.add_child(p)
	var v := UiKit.vbox(14)
	p.add_child(v)
	var t := UiKit.label(title, 40, accent, "black")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	if subtitle != "":
		var s := UiKit.label(subtitle, 19, UiKit.PAPER, "regular")
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		s.custom_minimum_size = Vector2(500, 0)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(s)
	var first: Button = null
	for b in buttons:
		var col: Color = b[2] if b.size() > 2 else UiKit.TEAL
		var btn := UiKit.button(String(b[0]), col, 22, 400)
		var cb: Callable = b[1]
		btn.pressed.connect(func():
			close()
			cb.call())
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(btn)
		if first == null:
			first = btn
	if first != null:
		first.grab_focus.call_deferred()


func close() -> void:
	is_open = false
	_root.visible = false


func _unhandled_input(e: InputEvent) -> void:
	if is_open and e.is_action_pressed("pause") and _cancel.is_valid():
		close()
		_cancel.call()
		get_viewport().set_input_as_handled()
