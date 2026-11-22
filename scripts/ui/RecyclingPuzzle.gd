extends CanvasLayer
## Atelier de recyclage : une suite d'étapes interactives par niveau
## (types : scrub, spots, mash, hold_zone, timing — voir GameData).
## Chaque étape réussie = +15 points (GameState.step_done).

signal step_completed(step_id: String)
signal finished

const MACHINES := {"gabes": "OLD PAPER MILL  ·  GABÈS", "skhira": "FIBRE WORKSHOP  ·  SKHIRA", "sidi_mansour": "PET LAB  ·  SFAX"}

var level_id: String = ""
var steps: Array = []
var idx: int = 0
var active: bool = false
var sfx: Node = null

var _root: Control
var _panel: PanelContainer
var _machine: Label
var _chips: HBoxContainer
var _title: Label
var _verb: Label
var _hint: Label
var _stage: Stage
var _status: Label
var _stamp: Label


class Stage extends Control:
	var owner_p: Object
	var type: String = "scrub"
	var step_id: String = ""
	var goal: float = 1.0
	var progress: float = 0.0
	var c_from: Color = Color.WHITE
	var c_to: Color = Color.WHITE
	var done: bool = false
	var demo: bool = false
	var t: float = 0.0
	var _last: Vector2 = Vector2.ZERO
	var _drag: bool = false
	var _swirl: float = 0.0
	var _spots: Array = []
	var _hold: bool = false
	var _v: float = 0.0
	var _timer: float = 0.0
	var _cursor: float = 0.0
	var _dir: float = 1.0
	var _speed: float = 0.7
	var _zone: float = 0.5
	var _zone_w: float = 0.16
	var _hits: int = 0
	var _flash: float = 0.0
	var _flash_col: Color = Color.WHITE
	var _shake: float = 0.0
	var _rng := RandomNumberGenerator.new()
	var _flakes: Array = []

	func setup(step: Dictionary, is_demo: bool) -> void:
		type = String(step.type)
		step_id = String(step.id)
		goal = float(step.goal)
		c_from = step.from
		c_to = step.to
		demo = is_demo
		progress = 0.0
		done = false
		_v = 0.0
		_timer = 0.0
		_hits = 0
		_cursor = 0.0
		_speed = 0.62
		_zone_w = 0.26 if demo else 0.17
		_rng.randomize()
		_zone = _rng.randf_range(0.25, 0.75)
		_spots.clear()
		if type == "spots":
			var n: int = int(goal)
			if demo:
				n = maxi(3, n / 2)
			goal = float(n)
			for i in n:
				var a: float = _rng.randf_range(0, TAU)
				var rr: float = _rng.randf_range(0.15, 0.78)
				_spots.append({"p": Vector2(cos(a), sin(a)) * rr, "alive": true, "pop": 0.0, "kind": i % 3})
		queue_redraw()

	func center() -> Vector2:
		return Vector2(size.x * 0.42, size.y * 0.52)

	func radius() -> float:
		return minf(size.x, size.y) * 0.38

	func press(down: bool) -> void:
		if done:
			return
		match type:
			"mash":
				if down:
					progress = minf(1.0, progress + (0.15 if demo else 0.075))
					_flash = 0.6
					_flash_col = Color(1, 1, 1)
					for i in 4:
						_flakes.append([center() + Vector2(_rng.randf_range(-20, 20), 0), Vector2(_rng.randf_range(-120, 120), _rng.randf_range(-260, -120)), 0.0])
					_check()
			"hold_zone":
				_hold = down
			"timing":
				if down:
					if absf(_cursor - _zone) <= _zone_w * 0.5:
						_hits += 1
						_flash = 1.0
						_flash_col = Color(0.3, 1.0, 0.5)
						_zone = _rng.randf_range(0.2, 0.8)
						_speed *= 1.1
						progress = float(_hits) / goal
						if owner_p.sfx != null:
							owner_p.sfx.good(_hits, "paper")
						_check()
					else:
						_flash = 1.0
						_flash_col = Color(1.0, 0.3, 0.3)
						_shake = 0.3
						if owner_p.sfx != null:
							owner_p.sfx.bad()

	func _gui_input(e: InputEvent) -> void:
		if done:
			return
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			var mb: InputEventMouseButton = e
			_drag = mb.pressed
			_last = mb.position
			if type == "spots" and mb.pressed:
				_tap_spot(mb.position)
			elif type in ["mash", "hold_zone", "timing"]:
				press(mb.pressed)
			accept_event()
		elif e is InputEventMouseMotion and _drag and type == "scrub":
			var mm: InputEventMouseMotion = e
			var d: float = mm.position.distance_to(_last)
			_last = mm.position
			progress = minf(1.0, progress + d / (size.x * (2.6 if demo else 5.5)))
			_swirl += d * 0.012
			_check()
			accept_event()

	func _tap_spot(p: Vector2) -> void:
		var c := center()
		var r := radius()
		for s in _spots:
			if s.alive and (c + s.p * r).distance_to(p) < 34.0:
				s.alive = false
				s.pop = 1.0
				if owner_p.sfx != null:
					owner_p.sfx.pop()
				var left: int = 0
				for s2 in _spots:
					if s2.alive:
						left += 1
				progress = 1.0 - float(left) / float(_spots.size())
				_check()
				return

	func complete_now() -> void:
		progress = 1.0
		for s in _spots:
			s.alive = false
		_check()

	func _check() -> void:
		if progress >= 0.999 and not done:
			done = true
			progress = 1.0
			owner_p.call_deferred("_on_step_done")
		queue_redraw()

	func _process(delta: float) -> void:
		t += delta
		_flash = maxf(0.0, _flash - delta * 2.5)
		_shake = maxf(0.0, _shake - delta)
		for f in _flakes:
			f[2] += delta
			f[1].y += 600.0 * delta
			f[0] += f[1] * delta
		_flakes = _flakes.filter(func(f): return f[2] < 0.9)
		for s in _spots:
			s.pop = maxf(0.0, s.pop - delta * 3.0)
		if not done:
			match type:
				"mash":
					progress = maxf(0.0, progress - delta * (0.05 if demo else 0.1))
				"hold_zone":
					_v = clampf(_v + (0.55 if _hold else -0.45) * delta, 0.0, 1.0)
					if _v > 0.55 and _v < 0.82:
						_timer += delta
					elif _v >= 0.95:
						_timer = maxf(0.0, _timer - 1.0)
						_v = 0.4
						_shake = 0.4
						_flash = 1.0
						_flash_col = Color(1, 0.3, 0.3)
						if owner_p.sfx != null:
							owner_p.sfx.bad()
					progress = clampf(_timer / (goal * (0.6 if demo else 1.0)), 0.0, 1.0)
					_check()
				"timing":
					_cursor += _dir * _speed * delta
					if _cursor > 1.0:
						_cursor = 1.0
						_dir = -1.0
					elif _cursor < 0.0:
						_cursor = 0.0
						_dir = 1.0
		queue_redraw()

	func _draw() -> void:
		var off := Vector2(sin(t * 60.0) * 6.0 * _shake, 0)
		var c := center() + off
		var r := radius()
		var mat: Color = c_from.lerp(c_to, progress)
		draw_style_box(_sb(Color(0.0, 0.0, 0.0, 0.25), 22), Rect2(Vector2.ZERO, size))
		match type:
			"scrub":
				draw_circle(c, r + 14.0, Color(0.16, 0.18, 0.2))
				draw_circle(c, r, mat.darkened(0.15))
				for i in 7:
					var rr: float = r * (0.2 + i * 0.11)
					var a0: float = _swirl * (1.0 + i * 0.15) + i
					draw_arc(c, rr, a0, a0 + 2.2, 24, mat.lightened(0.25), 4.0, true)
				_ring(c, r + 22.0)
			"spots":
				draw_circle(c, r + 10.0, Color(0.16, 0.18, 0.2))
				draw_circle(c, r, mat)
				for k in 5:
					draw_arc(c, r * (0.3 + k * 0.14), t * 0.3 + k, t * 0.3 + k + 1.0, 18, mat.lightened(0.18), 3.0, true)
				for s in _spots:
					var p: Vector2 = c + s.p * r
					if s.alive:
						_draw_spot(p, int(s.kind))
					elif s.pop > 0.0:
						draw_arc(p, 30.0 * (1.5 - s.pop), 0, TAU, 20, Color(1, 1, 1, s.pop), 3.0, true)
				_ring(c, r + 22.0)
			"mash":
				draw_circle(c, r + 12.0, Color(0.2, 0.22, 0.25))
				draw_circle(c, r, Color(0.1, 0.11, 0.13))
				var spin: float = t * (2.0 + progress * 18.0)
				for k in 4:
					var a: float = spin + k * PI * 0.5
					draw_line(c, c + Vector2(cos(a), sin(a)) * r * 0.85, Color(0.75, 0.78, 0.82), 10.0, true)
				draw_circle(c, r * 0.16, Color(0.4, 0.42, 0.45))
				for f in _flakes:
					draw_rect(Rect2(f[0], Vector2(8, 5)), mat)
				_bar(Rect2(Vector2(c.x - r, c.y + r + 26.0), Vector2(r * 2.0, 18.0)), progress, mat.lightened(0.2))
			"hold_zone":
				draw_circle(c, r, Color(0.16, 0.18, 0.2))
				if step_id == "unravel":
					draw_circle(c + Vector2(-r * 0.35, 0), r * 0.55 * (1.0 - progress * 0.7), Color(0.38, 0.45, 0.78))
					draw_circle(c + Vector2(r * 0.45, 0), r * 0.18 + progress * r * 0.3, mat)
					draw_line(c + Vector2(-r * 0.1, 0), c + Vector2(r * 0.4, -r * 0.05), Color(0.5, 0.8, 1.0), 3.0 + 2.0 * _v, true)
				else:
					var heat: float = _v
					draw_circle(c, r * 0.8, Color(0.25, 0.2, 0.18).lerp(Color(1.0, 0.45, 0.1), heat * 0.8))
					for k in 10:
						var a2: float = t * 1.5 + k * 0.63
						draw_rect(Rect2(c + Vector2(cos(a2), sin(a2)) * r * 0.5 - Vector2(5, 3), Vector2(10, 6)), mat)
				var gx: float = size.x * 0.84
				var g := Rect2(Vector2(gx, size.y * 0.12), Vector2(38, size.y * 0.76))
				draw_style_box(_sb(Color(0, 0, 0, 0.5), 12), g)
				var zy0: float = g.position.y + g.size.y * (1.0 - 0.82)
				var zy1: float = g.position.y + g.size.y * (1.0 - 0.55)
				draw_rect(Rect2(Vector2(gx, zy0), Vector2(38, zy1 - zy0)), Color(0.3, 1.0, 0.5, 0.45))
				draw_rect(Rect2(Vector2(gx, g.position.y), Vector2(38, g.size.y * 0.05)), Color(1.0, 0.3, 0.3, 0.6))
				var vy: float = g.position.y + g.size.y * (1.0 - _v)
				draw_rect(Rect2(Vector2(gx - 8, vy - 4), Vector2(54, 8)), Color(1, 1, 1))
				_ring(c, r + 18.0)
			"timing":
				var top := Vector2(size.x * 0.5, size.y * 0.36) + off
				if step_id == "knit":
					var cross: float = 1.0 - absf(_cursor - _zone) * 2.0
					draw_line(top + Vector2(-90, 40), top + Vector2(40 * cross, -40), Color(0.85, 0.85, 0.9), 8.0, true)
					draw_line(top + Vector2(90, 40), top + Vector2(-40 * cross, -40), Color(0.85, 0.85, 0.9), 8.0, true)
					for k in _hits:
						draw_rect(Rect2(top + Vector2(-120 + k * 62, 70), Vector2(56, 22)), mat)
				elif step_id == "extrude":
					draw_rect(Rect2(top + Vector2(-60, -70), Vector2(120, 70)), Color(0.35, 0.37, 0.4))
					draw_line(top + Vector2(0, 0), top + Vector2(0, 30 + progress * 70.0), mat, 10.0, true)
				else:
					draw_circle(top + Vector2(0, -36), 36, Color(0.5, 0.52, 0.55))
					draw_circle(top + Vector2(0, 36), 36, Color(0.5, 0.52, 0.55))
					draw_rect(Rect2(top + Vector2(-200, -4), Vector2(400, 8)), mat)
				var tr := Rect2(Vector2(size.x * 0.1, size.y * 0.74), Vector2(size.x * 0.8, 30))
				draw_style_box(_sb(Color(0, 0, 0, 0.55), 15), tr)
				var zx: float = tr.position.x + tr.size.x * (_zone - _zone_w * 0.5)
				draw_style_box(_sb(Color(0.3, 1.0, 0.5, 0.55), 12), Rect2(Vector2(zx, tr.position.y), Vector2(tr.size.x * _zone_w, tr.size.y)))
				var cx: float = tr.position.x + tr.size.x * _cursor
				draw_rect(Rect2(Vector2(cx - 4, tr.position.y - 10), Vector2(8, tr.size.y + 20)), Color(1, 1, 1))
				for k in int(goal):
					draw_circle(Vector2(size.x * 0.5 - (goal - 1) * 18.0 + k * 36.0, size.y * 0.92), 10.0, Color(0.3, 1.0, 0.5) if k < _hits else Color(1, 1, 1, 0.25))
		if _flash > 0.0:
			draw_style_box(_sb(Color(_flash_col.r, _flash_col.g, _flash_col.b, _flash * 0.25), 22), Rect2(Vector2.ZERO, size))

	func _draw_spot(p: Vector2, kind: int) -> void:
		match step_id:
			"deink":
				draw_circle(p, 18.0, Color(0.12, 0.12, 0.16, 0.9))
				draw_circle(p + Vector2(-5, -6), 5.0, Color(1, 1, 1, 0.5))
			"inspect":
				if kind == 0:
					draw_circle(p, 16.0, Color(0.85, 0.8, 0.6))
					for q in [Vector2(-4, -4), Vector2(4, -4), Vector2(-4, 4), Vector2(4, 4)]:
						draw_circle(p + q, 2.5, Color(0.3, 0.25, 0.2))
				elif kind == 1:
					draw_rect(Rect2(p - Vector2(6, 22), Vector2(12, 44)), Color(0.7, 0.72, 0.75))
					for k in 6:
						draw_line(p + Vector2(-6, -18 + k * 7), p + Vector2(6, -18 + k * 7), Color(0.4, 0.4, 0.42), 2.0)
				else:
					draw_circle(p, 20.0, Color(0.35, 0.22, 0.12, 0.85))
					draw_circle(p + Vector2(12, 8), 10.0, Color(0.35, 0.22, 0.12, 0.85))
			_:
				if kind == 1:
					draw_rect(Rect2(p - Vector2(26, 12), Vector2(52, 24)), Color(0.9, 0.25, 0.25))
					draw_rect(Rect2(p - Vector2(18, 4), Vector2(36, 8)), Color(1, 1, 1, 0.8))
				else:
					draw_circle(p, 15.0, Color(0.15, 0.45, 0.9) if kind == 0 else Color(0.95, 0.75, 0.1))
					draw_arc(p, 15.0, 0, TAU, 16, Color(1, 1, 1, 0.5), 2.0, true)

	func _ring(c: Vector2, r: float) -> void:
		draw_arc(c, r, 0, TAU, 64, Color(1, 1, 1, 0.12), 8.0, true)
		if progress > 0.001:
			draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * progress, 64, c_to.lightened(0.3), 8.0, true)

	func _bar(rect: Rect2, v: float, col: Color) -> void:
		draw_style_box(_sb(Color(0, 0, 0, 0.5), 9), rect)
		if v > 0.01:
			draw_style_box(_sb(col, 9), Rect2(rect.position, Vector2(rect.size.x * v, rect.size.y)))

	func _sb(col: Color, rad: int) -> StyleBoxFlat:
		var s := StyleBoxFlat.new()
		s.bg_color = col
		s.set_corner_radius_all(rad)
		s.anti_aliasing = true
		return s


func _ready() -> void:
	layer = 7
	_root = UiKit.full_rect(Control.new())
	_root.theme = UiKit.theme()
	add_child(_root)
	var dim := UiKit.full_rect(ColorRect.new()) as ColorRect
	dim.color = Color(0.0, 0.02, 0.04, 0.6)
	_root.add_child(dim)
	_panel = UiKit.panel(Color(0.03, 0.06, 0.09, 0.94), 26, Color(0.4, 0.8, 1.0, 0.3))
	_panel.custom_minimum_size = Vector2(1000, 620)
	UiKit.place(_panel, Vector2(0.5, 0.5), Vector2.ZERO, 0, 0)
	_root.add_child(_panel)
	var v := UiKit.vbox(8)
	_panel.add_child(v)
	_machine = UiKit.label("", 15, UiKit.MUTED, "black")
	v.add_child(_machine)
	_chips = UiKit.hbox(8)
	v.add_child(_chips)
	var h := UiKit.hbox(24)
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(h)
	var left := UiKit.vbox(10)
	left.custom_minimum_size = Vector2(300, 0)
	h.add_child(left)
	_title = UiKit.label("", 40, UiKit.PAPER, "black")
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.custom_minimum_size = Vector2(300, 0)
	left.add_child(_title)
	_verb = UiKit.label("", 22, UiKit.TEAL, "bold")
	_verb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_verb.custom_minimum_size = Vector2(300, 0)
	left.add_child(_verb)
	_hint = UiKit.label("", 18, UiKit.MUTED, "regular")
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size = Vector2(300, 0)
	left.add_child(_hint)
	_status = UiKit.label("", 16, Color(1.0, 0.86, 0.4), "bold")
	left.add_child(_status)
	_stage = Stage.new()
	_stage.owner_p = self
	_stage.custom_minimum_size = Vector2(620, 480)
	_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stage.mouse_filter = Control.MOUSE_FILTER_STOP
	h.add_child(_stage)
	_stamp = UiKit.label("STEP COMPLETE  +15", 46, UiKit.GOOD, "black", 8)
	UiKit.place(_stamp, Vector2(0.5, 0.5), Vector2.ZERO, 0, 0)
	_stamp.visible = false
	_root.add_child(_stamp)
	_root.visible = false


func run(lv_id: String) -> void:
	level_id = lv_id
	steps = GameData.level(lv_id).get("steps", [])
	idx = 0
	active = true
	_root.visible = true
	_machine.text = MACHINES.get(lv_id, "RECYCLING WORKSHOP")
	_panel.modulate.a = 0.0
	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = Vector2(0.92, 0.92)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_panel, "modulate:a", 1.0, 0.25)
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK)
	_load_step()


func _load_step() -> void:
	var st: Dictionary = steps[idx]
	for c in _chips.get_children():
		c.queue_free()
	for i in steps.size():
		var s: Dictionary = steps[i]
		var chip := PanelContainer.new()
		var col: Color = UiKit.GOOD if i < idx else (UiKit.TEAL if i == idx else Color(1, 1, 1, 0.25))
		var sb := UiKit.style(Color(col.r, col.g, col.b, 0.22 if i != idx else 0.4), 12, col, 2, false)
		sb.content_margin_top = 4
		sb.content_margin_bottom = 4
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		chip.add_theme_stylebox_override("panel", sb)
		chip.add_child(UiKit.label("%d  %s" % [i + 1, s.title], 14, UiKit.PAPER, "black"))
		_chips.add_child(chip)
	_title.text = String(st.title)
	_verb.text = String(st.verb)
	_hint.text = String(st.hint)
	_status.text = "Step %d / %d   ·   +%d pts" % [idx + 1, steps.size(), GameState.PTS_STEP]
	_stage.setup(st, GameState.demo_mode)


func _on_step_done() -> void:
	var st: Dictionary = steps[idx]
	GameState.step_done(String(st.id))
	step_completed.emit(String(st.id))
	if sfx != null:
		sfx.milestone()
	_stamp.visible = true
	_stamp.pivot_offset = _stamp.size * 0.5
	_stamp.scale = Vector2(1.6, 1.6)
	_stamp.modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_stamp, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)
	tw.tween_property(_stamp, "modulate:a", 1.0, 0.15)
	tw.set_parallel(false)
	tw.tween_interval(0.75)
	tw.tween_property(_stamp, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func():
		_stamp.visible = false
		idx += 1
		if idx >= steps.size():
			_close()
		else:
			_load_step())


func _close() -> void:
	active = false
	var tw := create_tween()
	tw.tween_property(_panel, "modulate:a", 0.0, 0.25)
	tw.tween_callback(func():
		_root.visible = false
		finished.emit())


func skip_step() -> void:
	if active and not _stage.done:
		_stage.complete_now()


func _unhandled_input(e: InputEvent) -> void:
	if not active or _stage.done:
		return
	if e is InputEventKey and not e.echo and (e.physical_keycode == KEY_SPACE or e.physical_keycode == KEY_E or e.physical_keycode == KEY_ENTER):
		_stage.press(e.pressed)
		get_viewport().set_input_as_handled()
