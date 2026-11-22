extends Node3D
## Fin : Gabès restaurée à 100 %, terrasse blanche aux portes bleues.
## Le gardien (l'avatar choisi) rejoint Mima en personne, retire son masque,
## offre le cahier, le pull et la jardinière, puis :
##   MIMA « Oh, my child... I remember this blue. »
##   JOUEUR « I kept my promise, Mima. »
##   MIMA « And you gave the world a reason to hope again. »
## Mima confie le dernier fil bleu ; carte finale
## « One promise. Three shores. A future to restore. » ; statistiques.

signal play_again
signal to_menu
signal to_preview

const LevelWorldScript := preload("res://scripts/world/LevelWorld.gd")
const BoyScript := preload("res://scripts/world/Boy.gd")
const GrandmaScript := preload("res://scripts/world/Grandma.gd")
const DialogScript := preload("res://scripts/ui/StoryDialog.gd")

var sfx: Node = null
var drives_audio: bool = true
var world
var boy
var grandma
var dialog
var cam: Camera3D
var _stick := FakeStick.new()
var _walking: bool = false
var _t: float = 0.0
var _base: Vector3
var _ui: CanvasLayer
var _thread_node: MeshInstance3D


class FakeStick extends RefCounted:
	var output: Vector2 = Vector2.ZERO


func _ready() -> void:
	world = LevelWorldScript.new()
	add_child(world)
	world.configure_level("gabes")
	world.set_restoration_immediate(100.0)
	_base = Vector3(0, world.height_at(0, 6), 6)

	# terrasse : dallage, muret blanc, porte bleue, bougainvillier
	var tiles := Mats.mat(Color(0.82, 0.74, 0.62), 0.8)
	var white := Mats.mat(Color(0.96, 0.95, 0.92), 0.85)
	var blue := Mats.mat(Color(0.08, 0.35, 0.72), 0.55)
	Mats.mi(Mats.box(Vector3(9, 0.3, 6)), tiles, _base + Vector3(0, -0.05, 0.5), self)
	Mats.mi(Mats.box(Vector3(0.5, 3.4, 6)), white, _base + Vector3(-4.3, 1.6, 0.5), self)
	Mats.mi(Mats.box(Vector3(0.12, 2.3, 1.2)), blue, _base + Vector3(-4.0, 1.25, 1.2), self)
	Mats.mi(Mats.cyl(0.6, 0.6, 0.12, 20), blue, _base + Vector3(-4.0, 2.4, 1.2), self, Vector3(0, 0, 90))
	for k in 18:
		var p := _base + Vector3(-4.0 + randf_range(-0.2, 0.25), 2.6 + randf_range(-0.6, 0.9), randf_range(-2.4, 3.4))
		Mats.mi(Mats.sphere(randf_range(0.18, 0.32)), Mats.mat(Color(0.86, 0.16, 0.5), 0.7, 0.0, 0.2), p, self)
	Mats.mi(Mats.box(Vector3(9, 0.6, 0.3)), white, _base + Vector3(0, 0.3, -2.4), self)
	# petite table
	var wood := Mats.mat(Color(0.45, 0.3, 0.18), 0.8)
	Mats.mi(Mats.cyl(0.45, 0.45, 0.05, 20), wood, _base + Vector3(-0.5, 0.72, -0.8), self)
	Mats.mi(Mats.cyl(0.05, 0.08, 0.7, 8), wood, _base + Vector3(-0.5, 0.36, -0.8), self)

	grandma = GrandmaScript.new()
	grandma.position = _base + Vector3(-2.0, 0.1, 0.2)
	grandma.rotation_degrees.y = -90.0
	add_child(grandma)

	boy = BoyScript.new()
	boy.position = _base + Vector3(6.5, 0.4, 0.8)
	add_child(boy)
	boy.joystick = _stick
	if sfx != null:
		boy.on_step = Callable(sfx, "step")

	cam = Camera3D.new()
	cam.fov = 50.0
	cam.far = 600.0
	add_child(cam)
	cam.make_current()
	world.camera = cam
	cam.global_position = _base + Vector3(2.5, 2.2, 8.0)
	cam.look_at(_base + Vector3(-0.5, 1.2, -1.0))

	dialog = DialogScript.new()
	dialog.radio_mode = false     # Mima est là, en personne
	add_child(dialog)

	var fade := CanvasLayer.new()
	fade.layer = 30
	add_child(fade)
	var black := UiKit.full_rect(ColorRect.new()) as ColorRect
	black.color = Color(0, 0, 0)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.add_child(black)
	var tw := create_tween()
	tw.tween_property(black, "color:a", 0.0, 1.6)
	tw.tween_callback(func():
		fade.queue_free()
		_walking = true
		boy.input_enabled = true)
	if sfx != null:
		sfx.finale()


func _process(delta: float) -> void:
	_t += delta
	if _walking:
		_stick.output = Vector2(-1.0, -0.08)
		if boy.global_position.x <= _base.x + 0.1:
			_walking = false
			_stick.output = Vector2.ZERO
			boy.input_enabled = false
			boy.visual.rotation.y = PI * 0.5
			var tw := create_tween()
			tw.tween_interval(0.6)
			tw.tween_callback(_mask_off)
	var target := _base + Vector3(2.5 - sin(_t * 0.08) * 1.2, 2.2, 8.0 - _t * 0.04)
	cam.global_position = cam.global_position.lerp(target, 1.0 - exp(-1.5 * delta))
	cam.look_at(_base + Vector3(-0.6, 1.2, -1.0))
	if sfx != null:
		sfx.update(1.0, 0.0, boy.global_position, delta)


func _mask_off() -> void:
	boy.remove_mask()
	var gifts := ["notebook", "sweater", "planter"]
	for i in gifts.size():
		var g: Node3D = ItemFactory.build_reward(gifts[i])
		add_child(g)
		g.global_position = boy.global_position + Vector3(0, 1.0, 0)
		g.scale = Vector3.ONE * 0.01
		var dest := _base + Vector3(-0.75 + i * 0.25, 0.76, -0.95 + (i % 2) * 0.3)
		var tw := create_tween()
		tw.tween_interval(1.0 + i * 0.5)
		tw.tween_property(g, "scale", Vector3.ONE * 0.45, 0.3)
		tw.tween_property(g, "global_position", dest, 0.6).set_trans(Tween.TRANS_SINE)
	var tw2 := create_tween()
	tw2.tween_interval(3.2)
	tw2.tween_callback(func(): dialog.show_lines(GameData.ENDING, _give_thread))


func _give_thread() -> void:
	# le fil bleu lumineux relie la pelote de Mima à la main de Yassine
	var a: Vector3 = grandma.global_position + Vector3(0.3, 0.74, 0)
	var b: Vector3 = boy.global_position + Vector3(-0.3, 0.6, 0)
	var pts := Mats.bezier(a, a + Vector3(0.6, -0.4, 0.2), b + Vector3(-0.6, -0.3, 0.2), b, 30)
	_thread_node = Mats.mi(Mats.tube(pts, 0.012, 6), Mats.emissive(Color(0.3, 0.7, 1.0), 4.0), Vector3.ZERO, self)
	if sfx != null:
		sfx.milestone()
	var tw := create_tween()
	tw.tween_interval(2.5)
	tw.tween_callback(_final_card)


## Carte finale, plein écran, ~4 s (clic pour passer)
func _final_card() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var root := UiKit.full_rect(Control.new())
	root.theme = UiKit.theme()
	layer.add_child(root)
	var bg := UiKit.full_rect(ColorRect.new()) as ColorRect
	bg.color = Color(0.01, 0.03, 0.06, 0.0)
	root.add_child(bg)
	var v := UiKit.vbox(16)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	UiKit.place(v, Vector2(0.5, 0.5), Vector2.ZERO, 0, 0)
	root.add_child(v)
	var logo := UiKit.tex("res://assets/ui/logo_official.png", Vector2(460, 210))
	v.add_child(logo)
	var l := UiKit.label(GameData.FINAL_CARD, 34, UiKit.PAPER, "black", 6)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	v.modulate.a = 0.0
	var done := [false]
	var close := func():
		if done[0]:
			return
		done[0] = true
		var t2 := create_tween()
		t2.tween_property(root, "modulate:a", 0.0, 0.8)
		t2.tween_callback(layer.queue_free)
		t2.tween_callback(_show_stats)
	bg.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			close.call())
	var tw := create_tween()
	tw.tween_property(bg, "color:a", 0.92, 1.0)
	tw.tween_property(v, "modulate:a", 1.0, 0.8)
	tw.tween_interval(3.2)
	tw.tween_callback(close)


func _show_stats() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 9
	add_child(_ui)
	var root := UiKit.full_rect(Control.new())
	root.theme = UiKit.theme()
	_ui.add_child(root)
	var p := UiKit.panel(Color(0.03, 0.06, 0.09, 0.9), 28, Color(0.4, 0.85, 1.0, 0.4))
	p.custom_minimum_size = Vector2(760, 0)
	UiKit.place(p, Vector2(1, 0.5), Vector2(-40, 0), -1, 0)
	root.add_child(p)
	var v := UiKit.vbox(10)
	p.add_child(v)
	v.add_child(UiKit.label("THE LAST BLUE IS SAVED", 38, UiKit.TEAL, "black"))
	v.add_child(UiKit.label("Gabès, Skhira and Sidi Mansour are breathing again.", 18, UiKit.MUTED, "bold"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 4)
	v.add_child(grid)
	var st: Dictionary = GameState.stats
	var rows := [
		["Total score", str(GameState.score)],
		["Sorting accuracy", "%d%%" % int(round(GameState.accuracy()))],
		["Correct / wrong sorts", "%d / %d" % [int(st.correct), int(st.wrong)]],
		["Objects collected", str(int(st.collected))],
		["Recycling steps", str(int(st.steps))],
		["Hearts lost", str(int(st.hearts_lost))],
		["Play time", "%d min %02d s" % [int(GameState.play_seconds()) / 60, int(GameState.play_seconds()) % 60]],
		["Story restoration", "%d%%" % int(round(GameState.local_restoration))],
	]
	for r in rows:
		grid.add_child(UiKit.label(String(r[0]), 18, UiKit.MUTED, "bold"))
		grid.add_child(UiKit.label(String(r[1]), 20, UiKit.PAPER, "black"))
	var rw := UiKit.hbox(10)
	v.add_child(rw)
	rw.add_child(UiKit.label("New lives:", 18, UiKit.MUTED, "bold"))
	for id in ["notebook", "sweater", "planter"]:
		var info: Dictionary = GameData.REWARDS[id]
		var chip := UiKit.panel(Color(info.color.r, info.color.g, info.color.b, 0.35), 12, info.color)
		chip.add_child(UiKit.label(String(info.label), 15, UiKit.PAPER, "bold"))
		rw.add_child(chip)
	var g := "offline"
	if OnlineService.ocean_percent >= 0.0:
		g = "%d%% restored by %d players" % [int(round(OnlineService.ocean_percent)), int(OnlineService.stats.get("players", 0))]
	v.add_child(UiKit.label("Shared ocean on the server: " + g, 17, Color(0.6, 0.88, 1.0), "bold"))
	var btns := UiKit.hbox(12)
	v.add_child(btns)
	var b1 := UiKit.button("PLAY AGAIN", UiKit.TEAL, 20, 220)
	b1.pressed.connect(func(): play_again.emit())
	btns.add_child(b1)
	var b2 := UiKit.button("PREVIEW", Color(0.3, 0.7, 0.55), 20, 170)
	b2.pressed.connect(func(): to_preview.emit())
	btns.add_child(b2)
	var b3 := UiKit.button("MENU", Color(0.6, 0.6, 0.7), 20, 150)
	b3.pressed.connect(func(): to_menu.emit())
	btns.add_child(b3)
	b1.grab_focus.call_deferred()
	p.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.6)
