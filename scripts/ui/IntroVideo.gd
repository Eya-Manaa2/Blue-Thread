extends Control
## Intro cinématique courte (~36 s), jouée AVANT le choix de l'avatar.
##  - Si res://assets/video/intro.ogv existe : lecture vidéo (VideoStreamPlayer, Theora).
##  - Sinon : plans illustrés (GameData.INTRO_SCENES) avec fondus « Ken Burns »,
##    sous-titres courts synchronisés, bandes cinéma et ambiance sonore par plan
##    (industrie, pas sur le sable, respiration, bip O2, piano, vagues, musique).
##  Le garçon y est « GRANDSON » (le petit-fils) ; Mima reste « MIMA ».
## Espace / Entrée / clic : plan suivant. Échap ou SKIP INTRO : passer
## (le jeu enchaîne alors sur le choix de l'avatar, jamais directement le niveau).
## (Aucune vidéo n'est générée par le projet : le fichier .ogv est optionnel.)

signal finished

const VIDEO_PATH := "res://assets/video/intro.ogv"

var sfx: Node = null
var drives_audio: bool = true   # Main ne met pas à jour l'ambiance à notre place
var _scenes: Array = []
var _i: int = -1
var _layers: Array = []
var _speaker: Label
var _line: Label
var _sub_box: Control
var _title: Label
var _dots: HBoxContainer
var _t: float = 0.0
var _shown: Dictionary = {}       # répliques déjà affichées dans le plan courant
var _video: VideoStreamPlayer
var _done: bool = false
var _line_i: int = 0              # prochaine réplique du plan
var _gap: float = 0.0             # petite pause après chaque phrase lue
var _voice: bool = false          # voix off disponible sur cet appareil
var _voice_poll: float = 0.0
var _voice_hint: Label


func _ready() -> void:
	theme = UiKit.theme()
	UiKit.full_rect(self)
	_voice = Voice.available()
	if sfx != null and sfx.has_method("set_music"):
		sfx.set_music(false)
	var black := UiKit.full_rect(ColorRect.new()) as ColorRect
	black.color = Color(0, 0, 0)
	add_child(black)
	if ResourceLoader.exists(VIDEO_PATH):
		_video = VideoStreamPlayer.new()
		UiKit.full_rect(_video)
		_video.expand = true
		_video.stream = load(VIDEO_PATH)
		add_child(_video)
		_video.finished.connect(_finish)
		_video.play()
	else:
		_scenes = GameData.INTRO_SCENES
		var clip := UiKit.full_rect(Control.new())
		clip.clip_contents = true
		clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(clip)
		for k in 2:
			var tr := TextureRect.new()
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			UiKit.full_rect(tr)
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tr.modulate.a = 0.0
			clip.add_child(tr)
			_layers.append(tr)
		for y in [0.0, 1.0]:
			var bar := ColorRect.new()
			bar.color = Color(0, 0, 0, 0.92)
			bar.anchor_left = 0.0
			bar.anchor_right = 1.0
			bar.anchor_top = y
			bar.anchor_bottom = y
			bar.offset_top = 0.0 if y == 0.0 else -86.0
			bar.offset_bottom = 70.0 if y == 0.0 else 0.0
			bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(bar)
		# sous-titre : nom de qui parle + une phrase courte
		var v := UiKit.vbox(4)
		v.custom_minimum_size = Vector2(1000, 0)
		UiKit.place(v, Vector2(0.5, 1), Vector2(0, -100), 0, -1)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(v)
		_sub_box = v
		_speaker = UiKit.label("", 20, Color(1.0, 0.82, 0.45), "black", 6)
		_speaker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(_speaker)
		_line = UiKit.label("", 28, Color(0.94, 0.97, 1.0), "regular", 6)
		_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_line.custom_minimum_size = Vector2(1000, 0)
		v.add_child(_line)
		# carte titre (texte anglais uniquement)
		_title = UiKit.label("", 60, Color(0.72, 0.92, 1.0), "black", 10)
		_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UiKit.place(_title, Vector2(0.5, 0.45), Vector2.ZERO, 0, 0)
		_title.modulate.a = 0.0
		_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_title)
		_dots = UiKit.hbox(10)
		UiKit.place(_dots, Vector2(0.5, 1), Vector2(0, -30), 0, -1)
		add_child(_dots)
		for k in _scenes.size():
			var d := UiKit.tex("res://assets/icons/dot.png", Vector2(10, 10))
			_dots.add_child(d)
		_next()
	var skip := UiKit.ghost_button("SKIP INTRO  (Esc)", 16)
	UiKit.place(skip, Vector2(1, 1), Vector2(-24, -24), -1, -1)
	skip.pressed.connect(_finish)
	add_child(skip)
	_voice_hint = UiKit.label("VOICE-OVER  ·  press V to mute", 14, Color(0.7, 0.85, 0.95, 0.75), "bold", 4)
	UiKit.place(_voice_hint, Vector2(0, 1), Vector2(24, -30), 1, -1)
	_voice_hint.visible = _voice
	add_child(_voice_hint)


func _next() -> void:
	_i += 1
	if _i >= _scenes.size():
		_finish()
		return
	_t = 0.0
	_shown.clear()
	_line_i = 0
	_gap = 0.0
	Voice.stop()
	var sd: Dictionary = _scenes[_i]
	var is_title: bool = bool(sd.get("title", false))
	var front: TextureRect = _layers[_i % 2]
	var back: TextureRect = _layers[(_i + 1) % 2]
	front.texture = load(String(sd.image))
	front.pivot_offset = size * Vector2(0.5 + (0.08 if _i % 2 == 0 else -0.08), 0.5)
	front.scale = Vector2(1.03, 1.03)
	front.move_to_front()
	var tw := create_tween().set_parallel(true)
	front.modulate = Color(1, 1, 1, 0)
	if is_title:
		tw.tween_property(front, "modulate", Color(0.38, 0.45, 0.56, 1.0), 1.0)
	else:
		tw.tween_property(front, "modulate:a", 1.0, 0.9)
	tw.tween_property(back, "modulate:a", 0.0, 0.9)
	tw.tween_property(front, "scale", Vector2(1.13, 1.13), float(sd.get("dur", 6.0)) + 1.0).set_trans(Tween.TRANS_SINE)
	# le sous-titre précédent s'efface
	var tf := create_tween()
	tf.tween_property(_sub_box, "modulate:a", 0.0, 0.25)
	for k in _dots.get_child_count():
		(_dots.get_child(k) as CanvasItem).modulate = Color(0.4, 0.85, 1.0) if k == _i else Color(1, 1, 1, 0.3)
	if sfx != null and sfx.has_method("intro_cue"):
		sfx.intro_cue(String(sd.get("sound", "")))


func _show_line(who: String, text: String) -> void:
	if who == "TITLE":
		_title.text = text
		Voice.say("NARRATOR", text)
		var tt := create_tween()
		tt.tween_property(_title, "modulate:a", 1.0, 1.0)
		return
	match who:
		"NARRATOR":
			_speaker.text = ""
		"GRANDSON":
			_speaker.text = "GRANDSON"
		_:
			_speaker.text = who
	UiKit.set_label_color(_speaker, UiKit.TEAL if who == "MIMA" else Color(1.0, 0.82, 0.45))
	_line.text = ("“%s”" % text) if who != "NARRATOR" else text
	_line.visible_ratio = 0.0
	Voice.say(who, text)
	_sub_box.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_sub_box, "modulate:a", 1.0, 0.3)
	tw.parallel().tween_property(_line, "visible_ratio", 1.0, clampf(text.length() * 0.035, 0.6, 2.2))


func _process(delta: float) -> void:
	if _done or _video != null or _i < 0 or _i >= _scenes.size():
		return
	_t += delta
	# les voix du navigateur se chargent parfois après le démarrage
	if not _voice and Voice.enabled:
		_voice_poll -= delta
		if _voice_poll <= 0.0:
			_voice_poll = 0.5
			_voice = Voice.available()
	if _voice_hint != null:
		_voice_hint.visible = _voice and Voice.enabled
	var sd: Dictionary = _scenes[_i]
	var lines: Array = sd.get("lines", [])
	# Avec la voix off : chaque phrase attend que la précédente soit lue,
	# et le plan attend la fin de la dernière phrase (+ courte pause).
	var talking: bool = _voice and Voice.enabled and Voice.speaking()
	if talking:
		_gap = 0.45
	else:
		_gap = maxf(0.0, _gap - delta)
	if _line_i < lines.size():
		var ln: Array = lines[_line_i]
		if _t >= float(ln[2]) and not talking and _gap <= 0.0:
			_line_i += 1
			_show_line(String(ln[0]), String(ln[1]))
			# temps de lecture minimum de la phrase (avec ou sans voix)
			_gap = clampf(String(ln[1]).length() * 0.055, 1.8, 4.5) if not _voice else 0.8
			return
	var min_dur: float = float(sd.get("dur", 6.0))
	var waiting: bool = _line_i < lines.size() or talking or _gap > 0.0
	if _t >= min_dur and (not waiting or _t > min_dur + 14.0):
		_next()
	if sfx != null:
		sfx.update(0.0, 0.2, Vector3.ZERO, delta)


func _finish() -> void:
	if _done:
		return
	_done = true
	Voice.stop()
	if sfx != null and sfx.has_method("set_music"):
		sfx.set_music(true)
	if _video != null:
		_video.stop()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func(): finished.emit())


func _unhandled_input(e: InputEvent) -> void:
	if _done:
		return
	if e.is_action_pressed("pause"):
		_finish()
		get_viewport().set_input_as_handled()
	elif e.is_action_pressed("interact") or (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
		if _video != null:
			_finish()
		else:
			_next()
		get_viewport().set_input_as_handled()
