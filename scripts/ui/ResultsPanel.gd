extends CanvasLayer
## Écran de fin de niveau : étoiles, score détaillé, récompense, restauration
## locale (animée de r_from à r_to) et valeur GLOBALE serveur, fait éducatif.

signal continue_pressed
signal replay_pressed
signal menu_pressed

var _root: Control


func _ready() -> void:
	layer = 9
	_root = UiKit.full_rect(Control.new())
	_root.theme = UiKit.theme()
	add_child(_root)
	_root.visible = false


func show_results(res: Dictionary, level_id: String, is_last: bool) -> void:
	for c in _root.get_children():
		c.queue_free()
	_root.visible = true
	var lv: Dictionary = GameData.level(level_id)
	var dim := UiKit.full_rect(ColorRect.new()) as ColorRect
	dim.color = Color(0, 0.02, 0.05, 0.55)
	_root.add_child(dim)
	var panel := UiKit.panel(Color(0.03, 0.06, 0.09, 0.94), 28, Color(0.4, 0.8, 1.0, 0.35))
	panel.custom_minimum_size = Vector2(820, 0)
	UiKit.place(panel, Vector2(0.5, 0.5), Vector2.ZERO, 0, 0)
	_root.add_child(panel)
	var v := UiKit.vbox(12)
	panel.add_child(v)
	var head := UiKit.label("%s  RESTORED" % lv.get("title", ""), 40, UiKit.PAPER, "black")
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(head)
	var stars := UiKit.hbox(14)
	stars.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(stars)
	var n_stars: int = int(res.get("stars", 1))
	for i in 3:
		var s := UiKit.tex("res://assets/icons/star.png" if i < n_stars else "res://assets/icons/star_empty.png", Vector2(64, 64))
		s.pivot_offset = Vector2(32, 32)
		s.scale = Vector2.ZERO
		stars.add_child(s)
		var tw := create_tween()
		tw.tween_interval(0.25 + i * 0.22)
		tw.tween_property(s, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK)
	var reward := UiKit.label("Reward: %s" % lv.get("reward_label", ""), 22, Color(1.0, 0.86, 0.4), "black")
	reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(reward)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 26)
	grid.add_theme_constant_override("v_separation", 6)
	v.add_child(grid)
	var rows := [
		["Collected", "%d / 5" % int(res.get("collected", 0))],
		["Correct sorts", str(int(res.get("correct", 0)))],
		["Wrong sorts", str(int(res.get("wrong", 0)))],
		["Recycling steps", str(int(res.get("steps", 0)))],
		["Hearts left", "%d / %d" % [int(res.get("hearts", 0)), GameState.MAX_HEARTS]],
		["Time", "%d s" % int(res.get("seconds", 0))],
		["Level score", str(int(res.get("score", 0)))],
		["Total score", str(int(res.get("total_score", 0)))],
	]
	for r in rows:
		grid.add_child(UiKit.label(String(r[0]), 18, UiKit.MUTED, "bold"))
		var val := UiKit.label(String(r[1]), 20, UiKit.PAPER, "black")
		grid.add_child(val)

	# restauration locale animée + valeur globale distincte
	var rl := UiKit.label("Story restoration", 16, UiKit.MUTED, "bold")
	v.add_child(rl)
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 100
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 22)
	var bg := UiKit.style(Color(0, 0, 0, 0.5), 11, Color(0, 0, 0, 0), 0, false)
	var fill := UiKit.style(UiKit.accent(float(lv.get("r_to", 0))), 11, Color(0, 0, 0, 0), 0, false)
	bg.content_margin_top = 0
	bg.content_margin_bottom = 0
	fill.content_margin_top = 0
	fill.content_margin_bottom = 0
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	bar.value = float(lv.get("r_from", 0))
	v.add_child(bar)
	var rv := UiKit.label("%d%%  ->  %d%%" % [int(lv.get("r_from", 0)), int(lv.get("r_to", 0))], 18, UiKit.accent(float(lv.get("r_to", 0))), "black")
	v.add_child(rv)
	var tw2 := create_tween()
	tw2.tween_interval(0.6)
	tw2.tween_property(bar, "value", float(lv.get("r_to", 0)), 1.4).set_trans(Tween.TRANS_CUBIC)
	var g := "offline"
	if OnlineService.ocean_percent >= 0.0:
		g = "%d%%  (%d players)" % [int(round(OnlineService.ocean_percent)), int(OnlineService.stats.get("players", 0))]
	v.add_child(UiKit.label("Shared ocean on the server (all players): " + g, 16, UiKit.MUTED, "bold"))

	var fact := UiKit.panel(Color(0.08, 0.2, 0.28, 0.8), 16, Color(0.4, 0.9, 1.0, 0.4))
	var fl := UiKit.label("DID YOU KNOW?  " + String(lv.get("fact", "")), 17, UiKit.PAPER, "regular")
	fl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fl.custom_minimum_size = Vector2(740, 0)
	fact.add_child(fl)
	v.add_child(fact)

	var btns := UiKit.hbox(14)
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(btns)
	var cont := UiKit.button("SEE MIMA" if is_last else "NEXT SHORE", UiKit.TEAL, 22, 240)
	cont.pressed.connect(_emit_and_close.bind(continue_pressed))
	btns.add_child(cont)
	var rep := UiKit.button("REPLAY", Color(0.6, 0.6, 0.7), 20, 170)
	rep.pressed.connect(_emit_and_close.bind(replay_pressed))
	btns.add_child(rep)
	var men := UiKit.button("MENU", Color(0.6, 0.6, 0.7), 20, 150)
	men.pressed.connect(_emit_and_close.bind(menu_pressed))
	btns.add_child(men)
	cont.grab_focus.call_deferred()
	panel.modulate.a = 0.0
	var tw3 := create_tween()
	tw3.tween_property(panel, "modulate:a", 1.0, 0.3)


func _emit_and_close(sig: Signal) -> void:
	_close()
	sig.emit()


func _close() -> void:
	_root.visible = false
