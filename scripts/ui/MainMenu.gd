extends Control
## Menu principal : image de fond (côte 2060) en lent travelling, logo,
## fil bleu animé, jouer / continuer, aperçu de restauration,
## état du serveur (océan partagé).
## (Retirés à la demande : « CHOOSE A SHORE », « JURY DEMO MODE » et le
##  texte de pied de page. Le mode jury reste accessible par ?demo=1 / J.)

signal play_story
signal continue_game
signal play_level(level_id: String)
signal open_preview

var _bg: TextureRect
var _thread: Line2D
var _thread2: Line2D
var _status: Label
var _t: float = 0.0


func _ready() -> void:
	theme = UiKit.theme()
	UiKit.full_rect(self)
	var clip := UiKit.full_rect(Control.new())
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(clip)
	_bg = TextureRect.new()
	_bg.texture = load("res://assets/ui/menu_bg.jpg")
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	UiKit.full_rect(_bg)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(_bg)
	_bg.resized.connect(func(): _bg.pivot_offset = _bg.size * 0.5)
	var zoom := create_tween().set_loops()
	zoom.tween_property(_bg, "scale", Vector2(1.12, 1.12), 22.0).set_trans(Tween.TRANS_SINE)
	zoom.tween_property(_bg, "scale", Vector2(1.0, 1.0), 22.0).set_trans(Tween.TRANS_SINE)

	var shade := UiKit.full_rect(ColorRect.new()) as ColorRect
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
void fragment() {
	float l = smoothstep(0.75, 0.0, UV.x) * 0.75;
	float b = smoothstep(0.55, 1.0, UV.y) * 0.6;
	COLOR = vec4(0.01, 0.03, 0.06, clamp(l + b, 0.0, 0.88));
}
"""
	sm.shader = sh
	shade.material = sm
	add_child(shade)

	_thread = Line2D.new()
	_thread.width = 3.0
	_thread.default_color = Color(0.45, 0.85, 1.0, 0.9)
	_thread.antialiased = true
	add_child(_thread)
	_thread2 = Line2D.new()
	_thread2.width = 12.0
	_thread2.default_color = Color(0.3, 0.75, 1.0, 0.18)
	_thread2.antialiased = true
	add_child(_thread2)

	var col := UiKit.vbox(14)
	UiKit.place(col, Vector2(0, 0.5), Vector2(70, 0), 1, 0)
	add_child(col)
	var logo := UiKit.tex("res://assets/ui/logo.png", Vector2(620, 230))
	col.add_child(logo)
	var tag := UiKit.label("Tunisia, 2060. Three shores. Five bins. One last blue thread.", 20, UiKit.MUTED, "bold")
	col.add_child(tag)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 10)
	col.add_child(sp)
	var first: Button = null
	if GameState.has_profile() and GameState.has_progress():
		var nxt: Dictionary = GameData.level(GameState.next_level())
		var b_cont := UiKit.button("CONTINUE  ·  %s" % String(nxt.get("title", "")), UiKit.TEAL, 26, 360)
		b_cont.pressed.connect(func(): continue_game.emit())
		col.add_child(b_cont)
		first = b_cont
	var b_play := UiKit.button("PLAY THE STORY" if first == null else "NEW STORY", UiKit.TEAL if first == null else Color(0.35, 0.55, 0.9), 26 if first == null else 22, 360)
	b_play.pressed.connect(func(): play_story.emit())
	col.add_child(b_play)
	if first == null:
		first = b_play
	var b_prev := UiKit.button("RESTORATION PREVIEW", Color(0.3, 0.7, 0.55), 22, 360)
	b_prev.pressed.connect(func(): open_preview.emit())
	col.add_child(b_prev)
	first.grab_focus.call_deferred()

	_status = UiKit.label("", 15, UiKit.MUTED, "bold")
	UiKit.place(_status, Vector2(0, 1), Vector2(70, -30), 1, -1)
	add_child(_status)


func _toggle_demo() -> void:
	GameState.demo_mode = not GameState.demo_mode


func _process(delta: float) -> void:
	_t += delta
	var w: float = size.x
	var pts := PackedVector2Array()
	for i in 80:
		var x: float = w * float(i) / 79.0
		var y: float = size.y * 0.82 + sin(x * 0.012 + _t * 1.2) * 14.0 + sin(x * 0.031 - _t * 0.7) * 6.0
		pts.append(Vector2(x, y))
	_thread.points = pts
	_thread2.points = pts
	var os = OnlineService
	var t := "Shared ocean (server): "
	if os.ocean_percent >= 0.0:
		t += "%d%%  ·  %d players  ·  %s" % [int(round(os.ocean_percent)), int(os.stats.get("players", 0)), "online" if os.online else "offline"]
	else:
		t += "connecting..." if os.is_configured() else "not configured"
	_status.text = t


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		if e.physical_keycode == KEY_J:
			_toggle_demo()
