extends Node3D
## Aperçu jury de la restauration : chaque rivage à 0 / 33 / 67 / 100 %.
## Montre aussi que la valeur LOCALE (histoire) et la valeur GLOBALE
## (serveur, tous les joueurs) sont deux choses distinctes.

signal back

const LevelWorldScript := preload("res://scripts/world/LevelWorld.gd")
const BoyScript := preload("res://scripts/world/Boy.gd")
const StationScript := preload("res://scripts/world/FiveBinStation.gd")

var world
var cam: Camera3D
var level_id: String = "gabes"
var stage: float = 0.0
var _t: float = 0.0
var _info: Label
var _holder: Node3D


func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = 55.0
	cam.far = 600.0
	add_child(cam)
	cam.make_current()
	_build_ui()
	_load(level_id)


func _load(id: String) -> void:
	level_id = id
	if _holder != null:
		_holder.queue_free()
	_holder = Node3D.new()
	add_child(_holder)
	world = LevelWorldScript.new()
	_holder.add_child(world)
	world.configure_level(id)
	world.camera = cam
	world.set_restoration_immediate(stage)
	if OnlineService.ocean_percent >= 0.0:
		world.set_ocean_progress(OnlineService.ocean_percent)
	var sp := Vector3(0, world.height_at(0, 4), 4)
	var st = StationScript.new()
	st.position = sp
	_holder.add_child(st)
	var boy = BoyScript.new()
	boy.position = sp + Vector3(4.4, 0.4, 1.2)
	_holder.add_child(boy)
	boy.visual.rotation.y = PI * 0.5
	_refresh()


func _set_stage(p: float) -> void:
	stage = p
	world.set_local_restoration(p)
	_refresh()


func _refresh() -> void:
	if _info == null:
		return
	var g := "offline"
	if OnlineService.ocean_percent >= 0.0:
		g = "%d%%" % int(round(OnlineService.ocean_percent))
	_info.text = "%s  ·  story restoration %d%%   |   shared ocean (server, separate value): %s" % [GameData.level(level_id).title, int(stage), g]


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 6
	add_child(layer)
	var root := UiKit.full_rect(Control.new())
	root.theme = UiKit.theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var p := UiKit.panel(Color(0.03, 0.05, 0.08, 0.82), 20)
	UiKit.place(p, Vector2(0.5, 1), Vector2(0, -18), 0, -1)
	root.add_child(p)
	var v := UiKit.vbox(10)
	p.add_child(v)
	_info = UiKit.label("", 17, UiKit.PAPER, "bold")
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_info)
	var row := UiKit.hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	for id in GameData.LEVEL_ORDER:
		var b := UiKit.button(String(GameData.level(id).title), GameData.BINS[String(GameData.level(id).material)].color, 18, 170)
		b.pressed.connect(func(): _load(id))
		row.add_child(b)
	var row2 := UiKit.hbox(10)
	row2.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row2)
	for pv in [0.0, 33.0, 67.0, 100.0]:
		var b2 := UiKit.button("%d%%" % int(pv), UiKit.accent(pv), 20, 120)
		b2.pressed.connect(func(): _set_stage(pv))
		row2.add_child(b2)
	var bk := UiKit.button("BACK", Color(0.6, 0.6, 0.7), 18, 120)
	bk.pressed.connect(func(): back.emit())
	row2.add_child(bk)
	var title := UiKit.label("RESTORATION PREVIEW", 26, UiKit.PAPER, "black", 6)
	UiKit.place(title, Vector2(0, 0), Vector2(24, 20), 1, 1)
	root.add_child(title)


func _process(delta: float) -> void:
	_t += delta
	var c := Vector3(0, 1.6, 2.0)
	if world != null:
		c.y += world.height_at(0, 4)
	cam.global_position = c + Vector3(sin(_t * 0.12) * 6.0, 2.4, 11.0 + cos(_t * 0.12) * 1.5)
	cam.look_at(c + Vector3(0, -0.2, -6.0))


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("pause"):
		back.emit()
