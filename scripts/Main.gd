extends Node3D
## ============================================================
##  Main — BLUE THREAD: THE LAST BLUE (point d'entrée : scenes/Main.tscn)
##  Menu -> profil (nom + avatar) -> intro (histoire illustrée) -> carte de
##  chapitre -> Gabès -> carte -> Skhira -> carte -> Sidi Mansour -> carte ->
##  fin avec Mima -> statistiques / rejouer.  CONTINUE reprend la sauvegarde.
##
##  Contrats d'équipe conservés :
##   A -> C : GameState.sort_completed(item_id, bin, ms) -> OnlineService.submit_sort_v2(+ niveau)
##   C -> B : OnlineService.global_progress_changed -> set_ocean_progress(percent) du décor
##  HUD réseau (Personne C) : toujours présent, replié en pastille.
##  Ancienne version de ce fichier : backups/Main_personC_v1.gd.txt
## ============================================================

const HUD_SCENE := "res://scenes/ui/HUD.tscn"
const MenuScript := preload("res://scripts/ui/MainMenu.gd")
const IntroScript := preload("res://scripts/ui/IntroVideo.gd")
const LevelScript := preload("res://scripts/game/LevelController.gd")
const EndingScript := preload("res://scripts/game/Ending.gd")
const PreviewScript := preload("res://scripts/game/RestorationPreview.gd")
const SfxScript := preload("res://scripts/sfx.gd")
const NetGuardScript := preload("res://scripts/ui/NetGuard.gd")
const ProfileScript := preload("res://scripts/ui/ProfileSetup.gd")
const BoyScript := preload("res://scripts/world/Boy.gd")
const CHAPTER_TIME := 3.6

var current: Node = null
var sfx: Node
var _transition: ColorRect
var _loading: Label
var _switching: bool = false
var _card_layer: CanvasLayer


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.02, 0.03, 0.05))
	sfx = SfxScript.new()
	sfx.world = self
	add_child(sfx)
	sfx.start_ambience()

	add_child((load(HUD_SCENE) as PackedScene).instantiate())
	# Jeu connecté : sans Internet, le jeu se bloque jusqu'au retour du réseau
	add_child(NetGuardScript.new())

	var tl := CanvasLayer.new()
	tl.layer = 40
	add_child(tl)
	_transition = UiKit.full_rect(ColorRect.new()) as ColorRect
	_transition.color = Color(0, 0, 0, 0)
	_transition.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tl.add_child(_transition)
	_loading = UiKit.label("LOADING THE SHORE...", 26, Color(0.6, 0.88, 1.0), "black")
	UiKit.place(_loading, Vector2(0.5, 0.5), Vector2.ZERO, 0, 0)
	_loading.visible = false
	tl.add_child(_loading)
	_card_layer = CanvasLayer.new()
	_card_layer.layer = 41
	add_child(_card_layer)

	GameState.sort_completed.connect(_on_sort_completed)
	OnlineService.global_progress_changed.connect(_on_global_progress)

	# Lien jury : ...index.html?demo=1 active directement le mode démo
	if OS.has_feature("web"):
		var q = JavaScriptBridge.eval("window.location.search", true)
		if typeof(q) == TYPE_STRING and String(q).contains("demo"):
			GameState.demo_mode = true
	_show_menu()


# ------------------------------------------------------------ écrans
## Écran noir + « chargement » affiché AVANT de construire la scène suivante
## (la construction procédurale d'un rivage prend quelques secondes).
func _switch(n: Node) -> void:
	if _switching:
		n.queue_free()
		return
	_switching = true
	get_tree().paused = false
	var old := current
	current = null
	_transition.color.a = 1.0
	_loading.visible = n is Node3D
	if old != null:
		old.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	current = n
	add_child(n)
	_loading.visible = false
	_switching = false
	var tw := create_tween()
	tw.tween_property(_transition, "color:a", 0.0, 0.45)


func _show_menu() -> void:
	var m := MenuScript.new()
	m.play_story.connect(_show_profile)
	m.continue_game.connect(_continue)
	m.play_level.connect(_start_level_direct)
	m.open_preview.connect(_show_preview)
	_switch(m)


func _show_profile() -> void:
	var p := ProfileScript.new()
	p.confirmed.connect(_on_profile_confirmed)
	p.back.connect(_show_menu)
	_switch(p)


func _on_profile_confirmed(player_name: String, avatar: int) -> void:
	GameState.set_profile(player_name, avatar)
	await _make_portrait()
	_start_story()


func _start_story() -> void:
	if not GameState.has_profile():
		_show_profile()
		return
	GameState.new_game()
	var intro := IntroScript.new()
	intro.sfx = sfx
	intro.finished.connect(func(): _chapter_then("gabes"))
	_switch(intro)


## CONTINUE : reprend au premier rivage non terminé (profil et progression conservés)
func _continue() -> void:
	if GameState.portrait == null:
		await _make_portrait()
	_chapter_then(GameState.next_level())


## Carte de chapitre (~3,6 s) : image, chapitre, réussite précédente ;
## le rivage suivant se construit derrière la carte.
func _chapter_then(level_id: String) -> void:
	var ch: Dictionary = GameData.CHAPTERS.get(level_id, {})
	if ch.is_empty():
		if level_id == "ending":
			_show_ending()
		else:
			_start_level(level_id)
		return
	for c in _card_layer.get_children():
		c.queue_free()
	var root := UiKit.full_rect(Control.new())
	root.theme = UiKit.theme()
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	_card_layer.add_child(root)
	var black := UiKit.full_rect(ColorRect.new()) as ColorRect
	black.color = Color(0, 0, 0)
	root.add_child(black)
	var clip := UiKit.full_rect(Control.new())
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(clip)
	var img := TextureRect.new()
	img.texture = load(String(ch.image))
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.full_rect(img)
	clip.add_child(img)
	var shade := UiKit.full_rect(ColorRect.new()) as ColorRect
	shade.color = Color(0.01, 0.03, 0.06, 0.45)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	var v := UiKit.vbox(8)
	UiKit.place(v, Vector2(0.5, 1), Vector2(0, -70), 0, -1)
	root.add_child(v)
	var k := UiKit.label(String(ch.kicker), 20, UiKit.TEAL, "black", 5)
	k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(k)
	var title: String = "THE LAST BLUE"
	if level_id != "ending":
		var lv: Dictionary = GameData.level(level_id)
		title = "%s  ·  %s" % [String(lv.title), String(lv.subtitle)]
	var t := UiKit.label(title, 46, UiKit.PAPER, "black", 7)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var a := UiKit.label(String(ch.achievement), 22, Color(1.0, 0.86, 0.5), "bold", 5)
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(a)
	root.modulate.a = 0.0
	img.pivot_offset = Vector2(640, 360)
	if sfx != null:
		sfx.milestone()
	var tw := create_tween()
	tw.tween_property(root, "modulate:a", 1.0, 0.7)
	tw.parallel().tween_property(img, "scale", Vector2(1.08, 1.08), CHAPTER_TIME + 0.8).set_trans(Tween.TRANS_SINE)
	await tw.finished
	var t0: int = Time.get_ticks_msec()
	if level_id == "ending":
		_show_ending()
	else:
		_start_level(level_id)
	while _switching:
		await get_tree().process_frame
	var left: float = CHAPTER_TIME - 0.7 - float(Time.get_ticks_msec() - t0) / 1000.0
	if left > 0.0:
		await get_tree().create_timer(left).timeout
	var out := create_tween()
	out.tween_property(root, "modulate:a", 0.0, 0.8)
	out.tween_callback(root.queue_free)


## Portrait du personnage choisi (gros plan rendu une fois) pour les dialogues.
func _make_portrait() -> void:
	if GameState.avatar_id < 0:
		return
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
	e.ambient_light_color = Color(0.75, 0.82, 0.9)
	e.ambient_light_energy = 0.7
	we.environment = e
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-30, 160, 0)
	sun.light_energy = 1.3
	vp.add_child(sun)
	var boy = BoyScript.new()
	boy.avatar_id = GameState.avatar_id
	boy.frozen = true
	boy.process_mode = Node.PROCESS_MODE_DISABLED
	vp.add_child(boy)
	var cam := Camera3D.new()
	cam.fov = 30.0
	vp.add_child(cam)
	cam.transform = Transform3D(Basis(), Vector3(0, 1.58, -1.3)).looking_at(Vector3(0, 1.5, 0), Vector3.UP)
	cam.current = true
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	if img != null and not img.is_empty():
		GameState.portrait = ImageTexture.create_from_image(img)
	vp.queue_free()


func _start_level_direct(level_id: String) -> void:
	GameState.new_game()
	var lv: Dictionary = GameData.level(level_id)
	# on considère les rivages précédents comme déjà restaurés
	for id in GameData.LEVEL_ORDER:
		if int(GameData.level(id).index) < int(lv.index):
			GameState.completed.append(id)
			GameState.rewards.append(String(GameData.level(id).reward))
	_start_level(level_id)


func _start_level(level_id: String) -> void:
	var lc := LevelScript.new()
	lc.level_id = level_id
	lc.sfx = sfx
	lc.level_finished.connect(_on_level_finished)
	lc.request_next.connect(_next_level.bind(level_id))
	lc.request_replay.connect(_replay.bind(level_id))
	lc.request_menu.connect(_show_menu)
	_switch(lc)


func _on_level_finished(_res: Dictionary) -> void:
	OnlineService.complete_level_v2(GameState.current_level)


func _next_level(level_id: String) -> void:
	var i: int = GameData.LEVEL_ORDER.find(level_id)
	GameState.save_game()
	if i + 1 < GameData.LEVEL_ORDER.size():
		_chapter_then(GameData.LEVEL_ORDER[i + 1])
	else:
		_chapter_then("ending")


func _replay(level_id: String) -> void:
	GameState.restart_level()
	_start_level(level_id)


func _show_ending() -> void:
	var e := EndingScript.new()
	e.sfx = sfx
	e.play_again.connect(_show_profile)
	e.to_menu.connect(_show_menu)
	e.to_preview.connect(_show_preview)
	_switch(e)


func _show_preview() -> void:
	var p := PreviewScript.new()
	p.back.connect(_show_menu)
	_switch(p)


# ------------------------------------------------------------ contrats
func _on_sort_completed(item_id: String, selected_bin: String, reaction_ms: int) -> void:
	var lvl: String = GameState.current_level if GameState.current_level != "" else "demo"
	OnlineService.submit_sort_v2(item_id, selected_bin, reaction_ms, lvl)


func _on_global_progress(percent: float) -> void:
	var target := _find_with_method(current, "set_ocean_progress")
	if target != null:
		target.call("set_ocean_progress", percent)


func _find_with_method(n: Node, method: String) -> Object:
	if n == null:
		return null
	if n.has_method(method):
		return n
	for c in n.get_children():
		var f := _find_with_method(c, method)
		if f != null:
			return f
	return null


func _process(delta: float) -> void:
	if current != null and not ("drives_audio" in current):
		sfx.update(0.0, 0.15, Vector3.ZERO, delta)
