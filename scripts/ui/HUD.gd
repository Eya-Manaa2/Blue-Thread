extends CanvasLayer
## ============================================================
##  HUD réseau — Personne C (repliable pour ne pas gêner le jeu)
##  Pastille en haut à droite : état + océan global. Clic ou N : détails.
##  Détails : dernière synchro (en direct), océan global, aller-retour
##  HTTP, file d'attente, session. Tab : statistiques serveur.
##  F9 : « 5G vérifiée » (seulement après vérification réelle du réseau).
##  Police incluse (Fira Sans) : plus de carrés à la place des symboles sur le web.
## ============================================================

var _pill: Button
var _dot: Panel
var _pill_lbl: Label
var _card: PanelContainer
var _status: Label
var _sync: Label
var _ocean_lbl: Label
var _ocean_bar: ProgressBar
var _rtt: Label
var _net: Label
var _session: Label
var _stats_panel: PanelContainer
var _stats_lbl: Label
var _toast: Label
var _toast_id: int = 0


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiKit.theme()
	add_child(root)

	# Pastille repliée
	_pill = Button.new()
	_pill.focus_mode = Control.FOCUS_NONE
	_pill.add_theme_stylebox_override("normal", UiKit.style(Color(0.03, 0.06, 0.1, 0.8), 20, Color(1, 1, 1, 0.15), 1, false))
	_pill.add_theme_stylebox_override("hover", UiKit.style(Color(0.05, 0.1, 0.16, 0.9), 20, Color(1, 1, 1, 0.35), 1, false))
	_pill.add_theme_stylebox_override("pressed", UiKit.style(Color(0.05, 0.1, 0.16, 0.9), 20, Color(1, 1, 1, 0.35), 1, false))
	_pill.add_theme_stylebox_override("focus", UiKit.style(Color(0.03, 0.06, 0.1, 0.8), 20, Color(1, 1, 1, 0.15), 1, false))
	_pill.custom_minimum_size = Vector2(250, 42)
	UiKit.place(_pill, Vector2(1, 0), Vector2(-14, 14), -1, 1)
	root.add_child(_pill)
	var ph := UiKit.hbox(10)
	UiKit.full_rect(ph)
	ph.offset_left = 14
	ph.offset_right = -10
	ph.alignment = BoxContainer.ALIGNMENT_BEGIN
	_pill.add_child(ph)
	_dot = Panel.new()
	_dot.custom_minimum_size = Vector2(14, 14)
	_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ph.add_child(_dot)
	_pill_lbl = UiKit.label("", 15, UiKit.PAPER, "bold")
	_pill_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ph.add_child(_pill_lbl)
	_pill.pressed.connect(_toggle_card)

	# Carte détaillée (sous la pastille)
	_card = UiKit.panel(Color(0.04, 0.07, 0.12, 0.88), 14)
	_card.custom_minimum_size = Vector2(330, 0)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.place(_card, Vector2(1, 0), Vector2(-14, 64), -1, 1)
	root.add_child(_card)
	var v := UiKit.vbox(4)
	_card.add_child(v)
	_status = _label(v, "", 19, Color(1, 1, 1), "black")
	_sync = _label(v, "", 15, Color(0.85, 0.9, 1))
	_ocean_lbl = _label(v, "", 17, Color(0.55, 0.85, 1), "bold")
	_ocean_bar = ProgressBar.new()
	_ocean_bar.min_value = 0
	_ocean_bar.max_value = 100
	_ocean_bar.show_percentage = false
	_ocean_bar.custom_minimum_size = Vector2(0, 12)
	var bg := UiKit.style(Color(0, 0, 0, 0.5), 6, Color(0, 0, 0, 0), 0, false)
	var fill := UiKit.style(Color(0.1, 0.6, 0.95), 6, Color(0, 0, 0, 0), 0, false)
	for sb in [bg, fill]:
		sb.content_margin_top = 0
		sb.content_margin_bottom = 0
		sb.content_margin_left = 0
		sb.content_margin_right = 0
	_ocean_bar.add_theme_stylebox_override("background", bg)
	_ocean_bar.add_theme_stylebox_override("fill", fill)
	_ocean_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_ocean_bar)
	_rtt = _label(v, "", 15, Color(0.85, 0.9, 1))
	_net = _label(v, "", 15, Color(0.6, 1.0, 0.6))
	_session = _label(v, "", 12, Color(1, 1, 1, 0.5))
	_label(v, "N: hide  ·  Tab: server stats", 12, Color(1, 1, 1, 0.45))
	_card.visible = false

	# Statistiques serveur (Tab)
	_stats_panel = UiKit.panel(Color(0.04, 0.07, 0.12, 0.92), 14)
	_stats_panel.custom_minimum_size = Vector2(330, 0)
	_stats_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.place(_stats_panel, Vector2(1, 0), Vector2(-360, 64), -1, 1)
	root.add_child(_stats_panel)
	_stats_lbl = _label(_stats_panel, "", 15, Color(1, 1, 1))
	_stats_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stats_lbl.custom_minimum_size = Vector2(300, 0)
	_stats_panel.visible = false

	# Confirmation serveur d'un tri (petite ligne sous la pastille)
	_toast = _label(root, "", 14, Color(1, 1, 1), "bold")
	UiKit.place(_toast, Vector2(1, 0), Vector2(-16, 60), -1, 1)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	OnlineService.connection_changed.connect(_on_conn)
	OnlineService.stats_updated.connect(_on_stats)
	OnlineService.sort_result.connect(_on_sort_result)
	_refresh()


func _label(parent: Control, text: String, size: int, col: Color, weight: String = "regular") -> Label:
	var l := UiKit.label(text, size, col, weight)
	parent.add_child(l)
	return l


func _dot_color(c: Color) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(7)
	s.anti_aliasing = true
	_dot.add_theme_stylebox_override("panel", s)


func _toggle_card() -> void:
	_card.visible = not _card.visible
	if not _card.visible:
		_stats_panel.visible = false
	_toast.visible = not _card.visible
	_refresh()


func _on_conn(_o: bool) -> void:
	_refresh()


func _on_stats(_s: Dictionary) -> void:
	_refresh()


func _process(_delta: float) -> void:
	if not _card.visible:
		return
	var s: float = OnlineService.seconds_since_sync()
	if s < 0.0:
		_sync.text = "Last sync: never"
	else:
		_sync.text = "Last sync: %.1f s ago" % s
		UiKit.set_label_color(_sync, Color(1, 0.75, 0.3) if (s > 8.0 and OnlineService.online) else Color(0.85, 0.9, 1))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		var k: InputEventKey = event
		if k.keycode == KEY_TAB:
			if not _card.visible:
				_toggle_card()
			_stats_panel.visible = not _stats_panel.visible
			_refresh()
			get_viewport().set_input_as_handled()
		elif k.keycode == KEY_N:
			_toggle_card()
		elif k.keycode == KEY_F9:
			OnlineService.verified_5g = not OnlineService.verified_5g
			_refresh()


func _refresh() -> void:
	var os = OnlineService
	var state_txt := ""
	var col := Color(1, 0.4, 0.35)
	if not os.is_configured():
		state_txt = "NOT CONFIGURED"
		col = Color(1, 0.7, 0.2)
	elif os.online:
		state_txt = "ONLINE"
		col = Color(0.35, 1, 0.45)
	else:
		state_txt = "OFFLINE"
	_dot_color(col)
	var ocean_txt := "--"
	if os.ocean_percent >= 0.0:
		ocean_txt = "%d%%" % int(round(os.ocean_percent))
	_pill_lbl.text = "%s  ·  Shared ocean %s" % [state_txt, ocean_txt]
	_status.text = state_txt if state_txt != "OFFLINE" else "OFFLINE (shared progress paused)"
	UiKit.set_label_color(_status, col)

	if os.ocean_percent >= 0.0:
		_ocean_lbl.text = "Shared ocean (all players): %d%%" % int(round(os.ocean_percent))
		_ocean_bar.value = os.ocean_percent
	else:
		_ocean_lbl.text = "Shared ocean: unavailable"
		_ocean_bar.value = 0

	_rtt.text = ("HTTP round trip: %d ms" % os.rtt_ms) if os.rtt_ms >= 0 else "HTTP round trip: --"
	if os.pending_count() > 0:
		_rtt.text += "  ·  %d queued" % os.pending_count()
	# Ne jamais écrire « 5G » sans vérification réelle
	_net.text = "Network: 5G verified (mobile hotspot)" if os.verified_5g else ""
	_net.visible = os.verified_5g
	_session.text = "Session: %s  ·  schema %s" % [os.session_id, "v2" if os.schema_v2 else "v1"]

	var st: Dictionary = os.stats
	if st.is_empty():
		_stats_lbl.text = "LIVE STATS\n\nNo data received from the server yet."
		if os.last_error != "":
			_stats_lbl.text += "\n\n" + os.last_error
		return
	var t: String = "LIVE STATS (Supabase)\n\n"
	t += "Sorts recorded: %d\n" % int(st.get("total_events", 0))
	t += "Correct: %d  ·  Wrong: %d\n" % [int(st.get("correct_events", 0)), int(st.get("wrong_events", 0))]
	t += "Accuracy: %s%%\n" % str(st.get("accuracy", 0))
	if st.has("levels_completed"):
		t += "Shores completed: %d\n" % int(st.get("levels_completed", 0))
	t += "Players (sessions): %d\n" % int(st.get("players", 0))
	t += "Avg reaction time: %d ms\n" % int(st.get("avg_reaction_ms", 0))
	var errs = st.get("errors_by_material", {})
	if errs is Dictionary and not (errs as Dictionary).is_empty():
		t += "\nHardest materials:\n"
		for k in (errs as Dictionary).keys():
			t += "  - %s: %d error(s)\n" % [str(k), int(errs[k])]
	_stats_lbl.text = t


func _on_sort_result(item_id: String, is_correct: bool, correct_bin: String) -> void:
	if is_correct:
		_show_toast("Server: sort confirmed (%s)" % item_id, Color(0.5, 1, 0.6))
	else:
		_show_toast("Server: %s belongs in %s" % [item_id, correct_bin.to_upper()], Color(1, 0.6, 0.5))


func _show_toast(text: String, col: Color) -> void:
	_toast_id += 1
	var my_id: int = _toast_id
	_toast.text = text
	UiKit.set_label_color(_toast, col)
	await get_tree().create_timer(2.5, true, false, true).timeout
	if my_id == _toast_id:
		_toast.text = ""
