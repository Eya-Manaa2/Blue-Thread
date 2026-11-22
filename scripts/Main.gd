extends Node3D
## ============================================================
##  Main — BLUE THREAD: THE LAST BLUE (point d'entrée : scenes/Main.tscn)
##  Menu -> intro (vidéo .ogv ou diaporama) -> Gabès -> Skhira ->
##  Sidi Mansour -> fin avec Mima -> statistiques / rejouer.
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

var current: Node = null
var sfx: Node
var _transition: ColorRect
var _loading: Label
var _switching: bool = false


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.02, 0.03, 0.05))
	sfx = SfxScript.new()
	sfx.world = self
	add_child(sfx)
	sfx.start_ambience()

	add_child((load(HUD_SCENE) as PackedScene).instantiate())

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
	m.play_story.connect(_start_story)
	m.play_level.connect(_start_level_direct)
	m.open_preview.connect(_show_preview)
	_switch(m)


func _start_story() -> void:
	GameState.new_game()
	var intro := IntroScript.new()
	intro.sfx = sfx
	intro.finished.connect(func(): _start_level("gabes"))
	_switch(intro)


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
	if i + 1 < GameData.LEVEL_ORDER.size():
		_start_level(GameData.LEVEL_ORDER[i + 1])
	else:
		_show_ending()


func _replay(level_id: String) -> void:
	GameState.restart_level()
	_start_level(level_id)


func _show_ending() -> void:
	var e := EndingScript.new()
	e.sfx = sfx
	e.play_again.connect(_start_story)
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
