extends Control
## Intro passable.
##  - Si res://assets/video/intro.ogv existe : lecture vidéo (VideoStreamPlayer, Theora).
##  - Sinon : diaporama « Ken Burns » à partir des images de référence, avec
##    sous-titres, bandes cinéma et points de progression.
## Espace / Entrée / clic : diapo suivante. Échap ou PASSER : tout passer.
## (Aucune vidéo n'est générée par le projet : le fichier .ogv est optionnel.)

signal finished

const VIDEO_PATH := "res://assets/video/intro.ogv"
const SLIDE_TIME := 5.5

var sfx: Node = null
var drives_audio: bool = true   # Main ne met pas à jour l'ambiance à notre place
var _slides: Array = []
var _i: int = -1
var _layers: Array = []
var _title: Label
var _sub: Label
var _dots: HBoxContainer
var _timer: float = 0.0
var _video: VideoStreamPlayer
var _done: bool = false


func _ready() -> void:
	theme = UiKit.theme()
	UiKit.full_rect(self)
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
		_slides = GameData.INTRO_SLIDES
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
		var v := UiKit.vbox(6)
		v.custom_minimum_size = Vector2(1000, 0)
		UiKit.place(v, Vector2(0.5, 1), Vector2(0, -104), 0, -1)
		add_child(v)
		_title = UiKit.label("", 40, UiKit.PAPER, "black", 6)
		_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(_title)
		_sub = UiKit.label("", 22, Color(0.85, 0.92, 1.0), "regular", 5)
		_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_sub.custom_minimum_size = Vector2(1000, 0)
		v.add_child(_sub)
		_dots = UiKit.hbox(10)
		UiKit.place(_dots, Vector2(0.5, 1), Vector2(0, -30), 0, -1)
		add_child(_dots)
		for k in _slides.size():
			var d := UiKit.tex("res://assets/icons/dot.png", Vector2(12, 12))
			_dots.add_child(d)
		_next()
	var skip := UiKit.ghost_button("SKIP INTRO  (Esc)", 16)
	UiKit.place(skip, Vector2(1, 1), Vector2(-24, -24), -1, -1)
	skip.pressed.connect(_finish)
	add_child(skip)


func _next() -> void:
	_i += 1
	if _i >= _slides.size():
		_finish()
		return
	_timer = 0.0
	var s: Dictionary = _slides[_i]
	var front: TextureRect = _layers[_i % 2]
	var back: TextureRect = _layers[(_i + 1) % 2]
	front.texture = load(String(s.image))
	front.pivot_offset = size * Vector2(0.5 + (0.12 if _i % 2 == 0 else -0.12), 0.5)
	front.scale = Vector2(1.04, 1.04)
	front.move_to_front()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(front, "modulate:a", 1.0, 1.0)
	tw.tween_property(back, "modulate:a", 0.0, 1.0)
	tw.tween_property(front, "scale", Vector2(1.16, 1.16), SLIDE_TIME + 1.5).set_trans(Tween.TRANS_SINE)
	_title.text = String(s.text)
	_sub.text = String(s.sub)
	_title.modulate.a = 0.0
	_sub.modulate.a = 0.0
	var tw2 := create_tween()
	tw2.tween_interval(0.5)
	tw2.tween_property(_title, "modulate:a", 1.0, 0.6)
	tw2.tween_property(_sub, "modulate:a", 1.0, 0.6)
	for k in _dots.get_child_count():
		(_dots.get_child(k) as CanvasItem).modulate = Color(0.4, 0.85, 1.0) if k == _i else Color(1, 1, 1, 0.3)
	if sfx != null:
		sfx.whoosh()


func _process(delta: float) -> void:
	if _done or _video != null:
		return
	_timer += delta
	if _timer >= SLIDE_TIME:
		_next()
	if sfx != null:
		sfx.update(0.0, 0.25, Vector3.ZERO, delta)


func _finish() -> void:
	if _done:
		return
	_done = true
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
