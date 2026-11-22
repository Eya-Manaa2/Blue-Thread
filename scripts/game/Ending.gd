extends Node3D
## Fin — la récompense émotionnelle de toute l'aventure, sur le rivage
## final restauré (Sidi Mansour à 100 %, histoire locale).
##  Plan 1 : la caméra glisse au-dessus de la côte : mer bleue, plantes, ciel clair.
##  Plan 2 : Mima s'avance jusqu'à la terrasse, regarde la mer — « The blue... it's back. »
##  Plan 3 : le petit-fils (l'avatar choisi) la rejoint, le fil bleu à la main,
##           retire son masque — « I kept my promise, Mima. »
##  Plan 4 : gros plan : Mima le regarde, sourit, lui prend la main —
##           « You didn't just bring back the sea... you brought back hope. »
##  Plan 5 : la caméra passe derrière eux vers la mer (vagues, oiseaux) ;
##           « BLUE THREAD — THE LAST BLUE » / « Every small action can begin a brighter future. »
## Puis statistiques et rejouer.

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
var _t: float = 0.0
var _base: Vector3
var _ui: CanvasLayer
var _look: Vector3
var _cam_tw: Tween
var _thread_ball: Node3D


func _ready() -> void:
	world = LevelWorldScript.new()
	add_child(world)
	world.configure_level("sidi_mansour")
	world.set_restoration_immediate(100.0)
	_base = Vector3(-6.0, world.height_at(-6.0, 8.0), 8.0)

	# terrasse en bois sur la dune, garde-corps face à la mer
	var wood := Mats.mat(Color(0.55, 0.40, 0.26), 0.85)
	var wood_dk := Mats.mat(Color(0.40, 0.28, 0.18), 0.9)
	Mats.mi(Mats.box(Vector3(6.0, 0.18, 4.2)), wood, _base + Vector3(0, 0.0, 0.6), self)
	for k in 12:
		Mats.mi(Mats.box(Vector3(0.02, 0.185, 4.2)), wood_dk, _base + Vector3(-2.75 + k * 0.5, 0.005, 0.6), self)
	for sx in [-2.9, 2.9]:
		for sz in [-1.4, 2.6]:
			Mats.mi(Mats.cyl(0.08, 0.1, 1.6, 8), wood_dk, _base + Vector3(sx, -0.6, sz), self)
	for k in 7:
		Mats.mi(Mats.box(Vector3(0.07, 1.0, 0.07)), wood_dk, _base + Vector3(-2.85 + k * 0.95, 0.55, -1.45), self)
	Mats.mi(Mats.box(Vector3(5.9, 0.08, 0.12)), wood, _base + Vector3(0, 1.05, -1.45), self)
	Mats.mi(Mats.box(Vector3(5.9, 0.05, 0.08)), wood, _base + Vector3(0, 0.6, -1.45), self)
	# petite table avec les trois récompenses de l'aventure
	Mats.mi(Mats.cyl(0.4, 0.4, 0.05, 20), wood, _base + Vector3(2.0, 0.75, 1.0), self)
	Mats.mi(Mats.cyl(0.05, 0.08, 0.7, 8), wood_dk, _base + Vector3(2.0, 0.4, 1.0), self)
	var gifts := ["notebook", "sweater", "planter"]
	for i in gifts.size():
		var g: Node3D = ItemFactory.build_reward(gifts[i])
		add_child(g)
		g.scale = Vector3.ONE * 0.4
		g.global_position = _base + Vector3(1.8 + i * 0.2, 0.78, 0.9 + (i % 2) * 0.2)
	# pots de fleurs sur la terrasse
	for k in 3:
		var pot := Node3D.new()
		Mats.mi(Mats.cyl(0.16, 0.12, 0.25, 12), Mats.mat(Color(0.72, 0.38, 0.22), 0.8), Vector3(0, 0.12, 0), pot)
		Mats.mi(Mats.sphere(0.2, -1.0, 12), Mats.mat(Color(0.20, 0.56, 0.18), 0.8), Vector3(0, 0.34, 0), pot)
		for j in 5:
			Mats.mi(Mats.sphere(0.045, -1.0, 8), Mats.mat([Color(0.95, 0.35, 0.5), Color(0.98, 0.85, 0.2), Color(0.95, 0.95, 0.95)][k], 0.6), Vector3(cos(j * 1.3) * 0.14, 0.45, sin(j * 1.3) * 0.14), pot)
		add_child(pot)
		pot.global_position = _base + Vector3(-2.6 + k * 0.35, 0.09, 2.3)

	grandma = GrandmaScript.new()
	add_child(grandma)
	grandma.global_position = _base + Vector3(-0.6, 0.09, 1.6)

	boy = BoyScript.new()
	add_child(boy)
	boy.frozen = true
	boy.global_position = _base + Vector3(3.6, 0.15, 0.6)
	boy.visual.rotation.y = PI * 0.5
	# le fil bleu dans la main du petit-fils
	_thread_ball = Node3D.new()
	boy.visual.add_child(_thread_ball)
	_thread_ball.position = Vector3(0.33, 0.62, -0.18)
	Mats.mi(Mats.sphere(0.07, -1.0, 14), Mats.emissive(Color(0.25, 0.6, 1.0), 2.2), Vector3.ZERO, _thread_ball)
	var tp := Mats.bezier(Vector3(0, 0, 0), Vector3(0.05, -0.15, -0.05), Vector3(-0.02, -0.3, 0.0), Vector3(0.04, -0.42, -0.02), 12)
	Mats.mi(Mats.tube(tp, 0.006, 5), Mats.emissive(Color(0.3, 0.7, 1.0), 3.0), Vector3.ZERO, _thread_ball)

	cam = Camera3D.new()
	cam.fov = 50.0
	cam.far = 600.0
	add_child(cam)
	cam.make_current()
	world.camera = cam
	cam.global_position = Vector3(-30, 11, -24)
	_look = Vector3(-6, 0.5, -12)
	cam.look_at(_look)

	dialog = DialogScript.new()
	dialog.radio_mode = false     # Mima est là, en personne
	add_child(dialog)
	_make_mima_portrait()

	var fade := CanvasLayer.new()
	fade.layer = 30
	add_child(fade)
	var black := UiKit.full_rect(ColorRect.new()) as ColorRect
	black.color = Color(0, 0, 0)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.add_child(black)
	var tw := create_tween()
	tw.tween_property(black, "color:a", 0.0, 1.6)
	tw.tween_callback(fade.queue_free)
	if sfx != null:
		if sfx.has_method("set_level"):
			sfx.set_level("sidi_mansour")
		if sfx.has_method("restore"):
			sfx.restore()
	_shot1()


func _process(delta: float) -> void:
	_t += delta
	cam.look_at(_look)
	if sfx != null:
		sfx.update(1.0, 0.0, cam.global_position, delta)


## Déplacement de caméra doux (position + point regardé)
func _move_cam(pos: Vector3, look: Vector3, dur: float) -> Tween:
	if _cam_tw != null and _cam_tw.is_valid():
		_cam_tw.kill()
	_cam_tw = create_tween().set_parallel(true)
	_cam_tw.tween_property(cam, "global_position", pos, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_cam_tw.tween_property(self, "_look", look, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return _cam_tw


func _head(n: Node3D) -> Vector3:
	return n.global_position + Vector3(0, 1.45, 0)


# ---- Plan 1 : survol du rivage restauré
func _shot1() -> void:
	var tw := create_tween()
	tw.tween_interval(0.2)
	tw.tween_callback(func(): _move_cam(Vector3(8, 5.5, -6), Vector3(-4, 0.8, -14), 3.2))
	tw.tween_interval(3.3)
	tw.tween_callback(func(): _move_cam(_base + Vector3(3.5, 2.6, 6.5), _base + Vector3(-0.4, 1.2, -0.5), 2.8))
	tw.tween_interval(2.6)
	tw.tween_callback(_shot2)


# ---- Plan 2 : Mima voit la mer
func _shot2() -> void:
	var walk := create_tween()
	walk.tween_property(grandma, "global_position", _base + Vector3(-0.6, 0.09, -0.85), 2.6).set_trans(Tween.TRANS_SINE)
	grandma.look_at_point(Vector3(-6, 0.5, -30))
	_move_cam(_base + Vector3(-2.3, 1.75, -2.9), _base + Vector3(-0.6, 1.45, -0.9), 3.0)
	var tw := create_tween()
	tw.tween_interval(2.4)
	tw.tween_callback(func(): grandma.wonder(true))
	tw.tween_interval(0.8)
	tw.tween_callback(func(): dialog.show_lines([GameData.ENDING[0]], _shot3))


# ---- Plan 3 : le petit-fils la rejoint, le fil bleu à la main
func _shot3() -> void:
	var walk := create_tween()
	boy.velocity = Vector3.ZERO
	walk.tween_property(boy, "global_position", _base + Vector3(0.25, 0.15, -0.8), 1.8).set_trans(Tween.TRANS_SINE)
	walk.tween_callback(func():
		boy.visual.rotation.y = 0.0
		boy.remove_mask())
	_move_cam(_base + Vector3(-1.3, 1.6, -3.7), _base + Vector3(-0.15, 1.35, -0.85), 2.4)
	var tw := create_tween()
	tw.tween_interval(2.8)
	tw.tween_callback(func(): dialog.show_lines([GameData.ENDING[1]], _shot4))


# ---- Plan 4 : gros plan émotion, elle lui prend la main
func _shot4() -> void:
	grandma.look_at_point(_head(boy) - Vector3(0, 0.2, 0))
	grandma.wonder(false)
	grandma.smile(true)
	grandma.hold_hand(true)
	_move_cam(_base + Vector3(1.05, 1.6, -2.45), _base + Vector3(-0.5, 1.48, -0.85), 2.2)
	if sfx != null and sfx.has_method("hopeful"):
		sfx.hopeful()
	var tw := create_tween()
	tw.tween_interval(2.2)
	tw.tween_callback(func(): dialog.show_lines([GameData.ENDING[2]], _shot5))


# ---- Plan 5 : derrière eux, vers la mer bleue
func _shot5() -> void:
	grandma.look_at_point(Vector3(-6, 0.5, -30))
	_move_cam(_base + Vector3(-0.2, 2.0, 2.6), Vector3(-6, 0.6, -40), 4.0)
	if sfx != null and sfx.has_method("finale"):
		sfx.finale()
	var tw := create_tween()
	tw.tween_interval(3.6)
	tw.tween_callback(_final_card)


## Portrait de Mima pour la boîte de dialogue (rendu une fois)
func _make_mima_portrait() -> void:
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.size = Vector2i(256, 256)
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(vp)
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.08, 0.2, 0.28)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.8, 0.82, 0.88)
	e.ambient_light_energy = 0.75
	we.environment = e
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-25, 160, 0)
	sun.light_energy = 1.2
	vp.add_child(sun)
	var g = GrandmaScript.new()
	g.process_mode = Node.PROCESS_MODE_DISABLED
	vp.add_child(g)
	var c := Camera3D.new()
	c.fov = 30.0
	vp.add_child(c)
	c.transform = Transform3D(Basis(), Vector3(0, 1.5, -1.05)).looking_at(Vector3(0, 1.48, 0), Vector3.UP)
	c.current = true
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	if img != null and not img.is_empty() and dialog != null:
		dialog.mima_portrait = ImageTexture.create_from_image(img)
	vp.queue_free()


## Carte finale, plein écran (~4,5 s ; clic pour passer)
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
	var t := UiKit.label(GameData.FINAL_TITLE, 52, Color(0.72, 0.92, 1.0), "black", 10)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var l := UiKit.label(GameData.FINAL_CARD, 28, UiKit.PAPER, "bold", 6)
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
	tw.tween_property(bg, "color:a", 0.55, 1.2)
	tw.parallel().tween_property(v, "modulate:a", 1.0, 1.2)
	tw.tween_interval(3.6)
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
