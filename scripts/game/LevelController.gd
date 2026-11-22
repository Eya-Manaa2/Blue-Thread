extends Node3D
## ============================================================
##  LevelController — un rivage jouable de BLUE THREAD: THE LAST BLUE
##  INTRO (dialogue) -> COLLECT (5 objets, oxygène, recharges)
##  -> TO_STATION -> SORT (tri bonus dans les 5 bacs) -> PUZZLE
##  (atelier de recyclage) -> REWARD -> RESULTS
## ============================================================

signal level_finished(result: Dictionary)
signal request_next
signal request_replay
signal request_menu

const LevelWorldScript := preload("res://scripts/world/LevelWorld.gd")
const BoyScript := preload("res://scripts/world/Boy.gd")
const StationScript := preload("res://scripts/world/FiveBinStation.gd")
const HUDScript := preload("res://scripts/ui/GameHUD.gd")
const DialogScript := preload("res://scripts/ui/StoryDialog.gd")
const PuzzleScript := preload("res://scripts/ui/RecyclingPuzzle.gd")
const ResultsScript := preload("res://scripts/ui/ResultsPanel.gd")
const ModalScript := preload("res://scripts/ui/Modal.gd")
const JoystickScript := preload("res://scripts/joystick.gd")
const BEAM_SHADER := preload("res://shaders/beam.gdshader")

enum Phase { INTRO, COLLECT, TO_STATION, SORT, PUZZLE, REWARD, RESULTS, DEAD }

const COLLECT_SPOTS := [Vector2(-28, 2.5), Vector2(-14, 10.0), Vector2(13, 3.0), Vector2(27, 9.0), Vector2(-5, 5.5)]
const REFILL_SPOTS := [Vector2(-21, 6.0), Vector2(20, 14.0), Vector2(7, 1.8)]

var level_id: String = "gabes"
var sfx: Node = null
var drives_audio: bool = true   # Main ne met pas à jour l'ambiance à notre place
var phase: int = Phase.INTRO
var lv: Dictionary = {}

# instances de scripts : non typées pour appeler leurs méthodes sans avertissement
var world
var boy
var station
var cam: Camera3D
var hud
var dialog
var puzzle
var results
var modal
var joystick

var collectibles: Array = []
var refills: Array = []
var start_pos: Vector3
var station_pos: Vector3
var _collected: int = 0
var _sorted: int = 0
var _steps: int = 0
var _sort_queue: Array = []
var _sort_item: String = ""
var _sort_node: Node3D = null
var _sort_start: int = 0
var _sort_busy: bool = false
var _combo: int = 0
var _reward_node: Node3D = null
var _cam_pos: Vector3
var _cam_look: Vector3
var _t: float = 0.0
var _air_warned: bool = false

var _sort_layer: CanvasLayer
var _sort_card: PanelContainer
var _sort_name: Label
var _sort_q: Label
var _tip_panel: PanelContainer
var _tip_title: Label
var _tip_text: Label
var _bin_buttons: Dictionary = {}


func _ready() -> void:
	lv = GameData.level(level_id)
	GameState.start_level(level_id)

	world = LevelWorldScript.new()
	add_child(world)
	world.configure_level(level_id)
	world.set_restoration_immediate(float(lv.r_from))
	if OnlineService.ocean_percent >= 0.0:
		world.set_ocean_progress(OnlineService.ocean_percent)

	station_pos = Vector3(0, world.height_at(0, 4), 4)
	station = StationScript.new()
	station.position = station_pos
	add_child(station)

	start_pos = Vector3(0, world.height_at(0, 12.5) + 0.3, 12.5)
	boy = BoyScript.new()
	boy.position = start_pos
	add_child(boy)
	if sfx != null:
		boy.on_step = Callable(sfx, "step")

	cam = Camera3D.new()
	cam.fov = 55.0
	cam.far = 600.0
	add_child(cam)
	cam.make_current()
	world.camera = cam
	_cam_pos = start_pos + Vector3(0, 3.2, 7.4)
	_cam_look = start_pos + Vector3(0, 1.1, -4)
	cam.global_position = _cam_pos + Vector3(0, 6, 10)
	cam.look_at(_cam_look)

	_spawn_collectibles()
	_spawn_refills()

	var jl := CanvasLayer.new()
	jl.layer = 4
	add_child(jl)
	joystick = JoystickScript.new()
	UiKit.full_rect(joystick)
	jl.add_child(joystick)
	boy.joystick = joystick

	hud = HUDScript.new()
	add_child(hud)
	hud.set_level(level_id)
	hud.pause_pressed.connect(_open_pause)
	dialog = DialogScript.new()
	add_child(dialog)
	puzzle = PuzzleScript.new()
	puzzle.sfx = sfx
	add_child(puzzle)
	puzzle.finished.connect(_on_puzzle_finished)
	puzzle.step_completed.connect(func(_id):
		_steps += 1
		_update_restoration())
	results = ResultsScript.new()
	add_child(results)
	results.continue_pressed.connect(func(): request_next.emit())
	results.replay_pressed.connect(func(): request_replay.emit())
	results.menu_pressed.connect(func(): request_menu.emit())
	modal = ModalScript.new()
	add_child(modal)
	_build_sort_ui()

	GameState.out_of_hearts.connect(_on_out_of_hearts)
	_set_phase(Phase.INTRO)
	hud.set_objective("Listen to Mima")
	var tw := create_tween()
	tw.tween_interval(0.9)
	tw.tween_callback(func(): dialog.show_lines(lv.intro, _start_collect))


func _exit_tree() -> void:
	if GameState.out_of_hearts.is_connected(_on_out_of_hearts):
		GameState.out_of_hearts.disconnect(_on_out_of_hearts)


func _set_phase(p: int) -> void:
	phase = p
	boy.input_enabled = p == Phase.COLLECT or p == Phase.TO_STATION
	_sort_layer.visible = p == Phase.SORT


# ================================================================ spawn
func _spot_pos(s: Vector2, shift: float) -> Vector3:
	var x: float = s.x + shift
	var z: float = world.shore_z(x) + s.y
	return Vector3(x, world.height_at(x, z), z)


func _spawn_collectibles() -> void:
	var col: Color = GameData.BINS[String(lv.material)].color
	var items: Array = lv.collect
	var shift: float = float(int(lv.index) * 3 - 3)
	for i in items.size():
		var p := _spot_pos(COLLECT_SPOTS[i % COLLECT_SPOTS.size()], shift)
		var root := Node3D.new()
		root.position = p
		add_child(root)
		var spin := Node3D.new()
		spin.position = Vector3(0, 0.7, 0)
		root.add_child(spin)
		var model := ItemFactory.build(String(items[i]))
		model.scale = Vector3.ONE * 1.6
		spin.add_child(model)
		var beam := MeshInstance3D.new()
		beam.mesh = Mats.cyl(0.32, 0.45, 9.0, 18)
		var bm := ShaderMaterial.new()
		bm.shader = BEAM_SHADER
		bm.set_shader_parameter("color", Color(col.r, col.g, col.b, 1.0).lightened(0.25))
		bm.set_shader_parameter("height", 9.0)
		beam.material_override = bm
		beam.position = Vector3(0, 4.5, 0)
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(beam)
		var ring := Mats.mi(Mats.torus(0.55, 0.65, 32), Mats.emissive(col.lightened(0.3), 2.5), Vector3(0, 0.05, 0), root)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var light := OmniLight3D.new()
		light.light_color = col.lightened(0.3)
		light.light_energy = 1.2
		light.omni_range = 3.5
		light.position = Vector3(0, 1.0, 0)
		root.add_child(light)
		collectibles.append({"root": root, "spin": spin, "id": String(items[i]), "taken": false, "phase": i * 1.3})


func _spawn_refills() -> void:
	var metal := Mats.mat(Color(0.8, 0.82, 0.85), 0.3, 0.85)
	var base_m := Mats.mat(Color(0.5, 0.5, 0.48), 0.95)
	for i in REFILL_SPOTS.size():
		var p := _spot_pos(REFILL_SPOTS[i], 0.0)
		var root := Node3D.new()
		root.position = p
		add_child(root)
		Mats.mi(Mats.cyl(0.7, 0.8, 0.25, 20), base_m, Vector3(0, 0.12, 0), root)
		for k in 3:
			var a: float = k * TAU / 3.0
			var tank := Node3D.new()
			tank.position = Vector3(cos(a) * 0.28, 0.75, sin(a) * 0.28)
			root.add_child(tank)
			Mats.mi(Mats.cyl(0.16, 0.16, 0.9, 16), metal, Vector3.ZERO, tank)
			Mats.mi(Mats.sphere(0.16), metal, Vector3(0, 0.45, 0), tank, Vector3.ZERO, Vector3(1, 0.6, 1))
			Mats.mi(Mats.cyl(0.165, 0.165, 0.12, 16), Mats.mat(Color(0.15, 0.5, 0.95), 0.5), Vector3(0, 0.1, 0), tank)
		var ring := Mats.mi(Mats.torus(0.85, 0.95, 32), Mats.emissive(Color(0.3, 0.8, 1.0), 3.0), Vector3(0, 0.05, 0), root)
		var light := OmniLight3D.new()
		light.light_color = Color(0.35, 0.8, 1.0)
		light.light_energy = 1.5
		light.omni_range = 4.0
		light.position = Vector3(0, 1.6, 0)
		root.add_child(light)
		var lbl := Mats.label3d("O2", 72, Color(0.6, 0.92, 1.0), root, Vector3(0, 2.0, 0))
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		refills.append({"root": root, "ring": ring, "light": light, "cool": 0.0})


# ================================================================ boucle
func _process(delta: float) -> void:
	_t += delta
	var bp: Vector3 = boy.global_position
	# limites du rivage
	if phase == Phase.COLLECT or phase == Phase.TO_STATION:
		var cx: float = clampf(bp.x, -42.0, 42.0)
		var cz: float = clampf(bp.z, world.shore_z(cx) - 1.2, 30.0)
		if cx != bp.x or cz != bp.z:
			boy.global_position = Vector3(cx, bp.y, cz)
			bp = boy.global_position
		if bp.y < -6.0:
			boy.global_position = start_pos
	boy.input_enabled = (phase == Phase.COLLECT or phase == Phase.TO_STATION) and not dialog.active and not modal.is_open

	for c in collectibles:
		if c.taken:
			continue
		var sp: Node3D = c.spin
		sp.rotation.y += delta * 1.4
		sp.position.y = 0.7 + sin(_t * 2.0 + float(c.phase)) * 0.15
		if phase == Phase.COLLECT and _flat_dist(bp, (c.root as Node3D).global_position) < 1.8:
			_take(c)

	for r in refills:
		r.cool = maxf(0.0, float(r.cool) - delta)
		var ring: Node3D = r.ring
		ring.rotation.y += delta
		(r.light as OmniLight3D).light_energy = 0.3 if float(r.cool) > 0.0 else 1.2 + sin(_t * 4.0) * 0.4
		if (phase == Phase.COLLECT or phase == Phase.TO_STATION) and float(r.cool) <= 0.0 and GameState.air < 92.0:
			if _flat_dist(bp, (r.root as Node3D).global_position) < 2.0:
				r.cool = 8.0
				GameState.refill_air()
				boy.set_air_warning(false)
				_air_warned = false
				hud.toast("AIR REFILLED", Color(0.5, 0.9, 1.0))
				if sfx != null:
					sfx.whoosh()

	if (phase == Phase.COLLECT or phase == Phase.TO_STATION) and not dialog.active and not modal.is_open:
		if GameState.drain_air(delta):
			_out_of_air()
		elif GameState.air < 25.0 and not _air_warned:
			_air_warned = true
			boy.set_air_warning(true)
			hud.toast("LOW AIR! Find a blue O2 station", UiKit.BAD)

	# objectif + flèche
	match phase:
		Phase.COLLECT:
			var target: Node3D = null
			var best := 1e9
			for c in collectibles:
				if not c.taken:
					var d := _flat_dist(bp, (c.root as Node3D).global_position)
					if d < best:
						best = d
						target = c.root
			if target != null:
				hud.set_arrow(_screen_angle(bp, target.global_position))
		Phase.TO_STATION:
			hud.set_arrow(_screen_angle(bp, station_pos))
			if _flat_dist(bp, station_pos + Vector3(0, 0, 1.6)) < 3.2:
				_start_sort()
		_:
			hud.set_arrow(NAN)

	if _sort_node != null:
		_sort_node.rotation.y += delta * 1.2

	_update_camera(delta)
	if sfx != null and sfx.has_method("update"):
		sfx.update(GameState.local_restoration / 100.0, 0.0, bp, delta)


func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _screen_angle(from: Vector3, to: Vector3) -> float:
	var d := to - from
	return atan2(d.x, -d.z)


func _update_camera(delta: float) -> void:
	var bp: Vector3 = boy.global_position
	var tp: Vector3
	var tl: Vector3
	match phase:
		Phase.SORT, Phase.PUZZLE:
			tp = station_pos + Vector3(0.0, 2.5, 5.6)
			tl = station_pos + Vector3(0.0, 1.2, 0.0)
		Phase.REWARD, Phase.RESULTS:
			var a: float = _t * 0.25
			var c: Vector3 = station_pos + Vector3(0, 1.6, 2.2)
			tp = c + Vector3(sin(a) * 4.5, 1.4, cos(a) * 4.5)
			tl = c
		_:
			tp = bp + Vector3(0, 3.2, 7.4)
			tl = bp + Vector3(0, 1.1, -4.0)
	var k: float = 1.0 - exp(-3.5 * delta)
	_cam_pos = _cam_pos.lerp(tp, k)
	_cam_look = _cam_look.lerp(tl, k)
	cam.global_position = cam.global_position.lerp(_cam_pos, 1.0 - exp(-6.0 * delta))
	cam.look_at(_cam_look)


func _update_restoration() -> void:
	var n_sort: int = maxi(1, (lv.sort as Array).size())
	var n_steps: int = maxi(1, (lv.steps as Array).size())
	var frac: float = 0.4 * float(_collected) / 5.0 + 0.3 * float(_sorted) / float(n_sort) + 0.3 * float(_steps) / float(n_steps)
	var p: float = float(lv.r_from) + (float(lv.r_to) - float(lv.r_from)) * frac * 0.85
	GameState.set_local_restoration(p)
	world.set_local_restoration(p)


# ================================================================ collecte
func _start_collect() -> void:
	_set_phase(Phase.COLLECT)
	hud.set_objective("Collect %s   0 / 5" % lv.material_label)
	hud.toast("WASD / arrows / joystick to move", UiKit.MUTED)


func _take(c: Dictionary) -> void:
	c.taken = true
	_collected += 1
	GameState.collect(String(c.id))
	_update_restoration()
	if sfx != null:
		sfx.pickup()
	var it: Dictionary = GameData.item(String(c.id))
	hud.toast("+%d  %s" % [GameState.PTS_COLLECT, it.get("label", "")], Color(1.0, 0.86, 0.4))
	var root: Node3D = c.root
	var spin: Node3D = c.spin
	for ch in root.get_children():
		if ch != spin:
			ch.queue_free()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(spin, "global_position", boy.global_position + Vector3(0, 1.3, 0.3), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(spin, "scale", Vector3.ONE * 0.1, 0.35)
	tw.chain().tween_callback(root.queue_free)
	if _collected >= collectibles.size():
		_set_phase(Phase.INTRO)
		hud.set_objective("Go to the SORT STATION")
		var tw2 := create_tween()
		tw2.tween_interval(0.6)
		tw2.tween_callback(func():
			dialog.show_lines(lv.to_station, func():
				_set_phase(Phase.TO_STATION)
				hud.set_objective("Go to the SORT STATION")))
	else:
		hud.set_objective("Collect %s   %d / 5" % [lv.material_label, _collected])


func _out_of_air() -> void:
	hud.toast("OUT OF AIR!", UiKit.BAD, true)
	GameState.lose_heart("air")
	if GameState.hearts > 0 or GameState.demo_mode:
		boy.global_position = start_pos
		boy.velocity = Vector3.ZERO
		GameState.refill_air()
		boy.set_air_warning(false)
		_air_warned = false


func _on_out_of_hearts() -> void:
	if phase == Phase.DEAD:
		return
	_set_phase(Phase.DEAD)
	get_tree().paused = true
	modal.open("OUT OF HEARTS", "The shore needs you, Yassine. Breathe, and try again.",
		[["TRY AGAIN", _retry, UiKit.TEAL], ["MAIN MENU", _to_menu, Color(0.6, 0.6, 0.7)]], UiKit.BAD)


# ================================================================ tri
func _build_sort_ui() -> void:
	_sort_layer = CanvasLayer.new()
	_sort_layer.layer = 6
	add_child(_sort_layer)
	var root := UiKit.full_rect(Control.new())
	root.theme = UiKit.theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sort_layer.add_child(root)
	_sort_card = UiKit.panel(Color(0.03, 0.05, 0.08, 0.85), 22, Color(1, 1, 1, 0.15))
	_sort_card.custom_minimum_size = Vector2(460, 0)
	UiKit.place(_sort_card, Vector2(0.5, 0), Vector2(0, 96), 0, 1)
	root.add_child(_sort_card)
	var v := UiKit.vbox(4)
	_sort_card.add_child(v)
	_sort_name = UiKit.label("", 32, UiKit.PAPER, "black")
	_sort_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_sort_name)
	_sort_q = UiKit.label("Which bin?  Tap a bin or press 1-5", 16, UiKit.MUTED, "bold")
	_sort_q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_sort_q)

	_tip_panel = UiKit.panel(Color(0.25, 0.04, 0.05, 0.92), 20, UiKit.BAD)
	_tip_panel.custom_minimum_size = Vector2(560, 0)
	UiKit.place(_tip_panel, Vector2(0.5, 0.42), Vector2.ZERO, 0, 0)
	root.add_child(_tip_panel)
	var tv := UiKit.vbox(6)
	_tip_panel.add_child(tv)
	_tip_title = UiKit.label("WRONG BIN  -5", 30, UiKit.BAD, "black")
	_tip_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tv.add_child(_tip_title)
	_tip_text = UiKit.label("", 19, UiKit.PAPER, "regular")
	_tip_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_text.custom_minimum_size = Vector2(520, 0)
	_tip_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tv.add_child(_tip_text)
	_tip_panel.visible = false

	var row := UiKit.hbox(12)
	UiKit.place(row, Vector2(0.5, 1), Vector2(0, -18), 0, -1)
	root.add_child(row)
	var order: Array = GameData.BIN_ORDER
	for i in order.size():
		var id: String = order[i]
		var info: Dictionary = GameData.BINS[id]
		var c: Color = info.color
		var b := Button.new()
		b.custom_minimum_size = Vector2(150, 118)
		b.focus_mode = Control.FOCUS_NONE
		var n := UiKit.style(Color(c.r, c.g, c.b, 0.88), 18, c.lightened(0.35), 2, true)
		var h := UiKit.style(c.lightened(0.15), 18, Color(1, 1, 1), 4, true)
		b.add_theme_stylebox_override("normal", n)
		b.add_theme_stylebox_override("hover", h)
		b.add_theme_stylebox_override("pressed", h)
		b.add_theme_stylebox_override("focus", n)
		var bv := UiKit.vbox(2)
		UiKit.full_rect(bv)
		bv.alignment = BoxContainer.ALIGNMENT_CENTER
		b.add_child(bv)
		var ic := UiKit.tex(String(info.icon), Vector2(0, 56))
		bv.add_child(ic)
		var l := UiKit.label("%d  %s" % [i + 1, info.label], 17, Color(1, 1, 1), "black")
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bv.add_child(l)
		b.pressed.connect(_choose_bin.bind(id))
		b.mouse_entered.connect(_hover_bin.bind(id))
		row.add_child(b)
		_bin_buttons[id] = b
	_sort_layer.visible = false


func _hover_bin(id: String) -> void:
	if phase == Phase.SORT:
		station.set_highlight(id)


func _start_sort() -> void:
	_set_phase(Phase.SORT)
	hud.set_objective("Sort the mixed pile  0 / %d" % (lv.sort as Array).size())
	boy.velocity = Vector3.ZERO
	var stand := station_pos + Vector3(4.4, 0, 1.2)
	stand.y = world.height_at(stand.x, stand.z) + 0.05
	var tw := create_tween()
	tw.tween_property(boy, "global_position", stand, 0.5)
	boy.visual.rotation.y = PI * 0.5
	_sort_queue = (lv.sort as Array).duplicate()
	_sort_queue.shuffle()
	_next_sort_item()


func _next_sort_item() -> void:
	_tip_panel.visible = false
	station.set_highlight("")
	if _sort_queue.is_empty():
		_sort_card.visible = false
		_set_phase(Phase.INTRO)
		_sort_layer.visible = false
		dialog.show_lines(lv.to_puzzle, _start_puzzle)
		return
	_sort_card.visible = true
	_sort_item = String(_sort_queue.pop_front())
	var it: Dictionary = GameData.item(_sort_item)
	_sort_name.text = String(it.get("label", _sort_item)).to_upper()
	_sort_node = ItemFactory.build(_sort_item)
	_sort_node.scale = Vector3.ONE * 0.01
	add_child(_sort_node)
	_sort_node.global_position = station_pos + Vector3(0, 1.8, 1.7)
	var tw := create_tween()
	tw.tween_property(_sort_node, "scale", Vector3.ONE * 2.0, 0.3).set_trans(Tween.TRANS_BACK)
	_sort_start = Time.get_ticks_msec()
	_sort_busy = false


func _choose_bin(bin_id: String) -> void:
	if phase != Phase.SORT or _sort_busy or _sort_node == null:
		return
	_sort_busy = true
	var ms: int = Time.get_ticks_msec() - _sort_start
	var res: Dictionary = GameState.sort_item(_sort_item, bin_id, ms)
	_sorted += 1
	_update_restoration()
	hud.set_objective("Sort the mixed pile  %d / %d" % [_sorted, (lv.sort as Array).size()])
	station.set_highlight(bin_id)
	station.open_lid(bin_id, true)
	var node := _sort_node
	_sort_node = null
	var target: Vector3 = station.bin_world_pos(bin_id)
	var tw := create_tween()
	tw.tween_property(node, "global_position", target + Vector3(0, 1.0, 0.2), 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "global_position", target + Vector3(0, -0.3, 0), 0.18).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(node, "scale", Vector3.ONE * 0.3, 0.18)
	tw.tween_callback(func():
		node.queue_free()
		station.open_lid(bin_id, false)
		station.flash(bin_id, bool(res.ok)))
	if bool(res.ok):
		_combo += 1
		if sfx != null:
			var shape: String = String(GameData.item(_sort_item).get("shape", ""))
			sfx.good(_combo, "paper" if shape in ["sheet", "box", "bag", "stack"] else ("can" if shape in ["can", "spray", "battery"] else "plastic"))
		hud.toast("+%d  CORRECT: %s" % [GameState.PTS_SORT_OK, GameData.BINS[bin_id].label], UiKit.GOOD)
		var tw2 := create_tween()
		tw2.tween_interval(0.75)
		tw2.tween_callback(_next_sort_item)
	else:
		_combo = 0
		if sfx != null:
			sfx.bad()
		var cb: String = String(res.correct_bin)
		_tip_title.text = "WRONG BIN  %d   ·   -1 HEART" % GameState.PTS_SORT_BAD
		_tip_text.text = "%s\nCorrect bin: %s" % [res.tip, GameData.BINS[cb].label]
		_tip_panel.visible = true
		var tw3 := create_tween()
		tw3.tween_interval(0.5)
		tw3.tween_callback(func(): station.set_highlight(cb))
		tw3.tween_interval(2.0)
		tw3.tween_callback(func():
			if phase == Phase.SORT:
				_next_sort_item())


# ================================================================ atelier
func _start_puzzle() -> void:
	_set_phase(Phase.PUZZLE)
	hud.set_objective("Recycle: give your %s a new life" % String(lv.material_label).to_lower())
	puzzle.run(level_id)


func _on_puzzle_finished() -> void:
	_set_phase(Phase.REWARD)
	hud.set_objective("New life!")
	var res: Dictionary = GameState.complete_level(level_id)
	world.set_local_restoration(float(lv.r_to))
	_reward_node = ItemFactory.build_reward(String(lv.reward))
	add_child(_reward_node)
	_reward_node.global_position = station_pos + Vector3(0, 1.2, 2.2)
	_reward_node.scale = Vector3.ONE * 0.01
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.5, 0.85, 1.0)
	glow.light_energy = 3.0
	glow.omni_range = 4.0
	glow.position = Vector3(0, 0.6, 0.6)
	_reward_node.add_child(glow)
	var tw := create_tween()
	tw.tween_property(_reward_node, "scale", Vector3.ONE * 1.5, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	if sfx != null:
		sfx.finale()
	hud.toast("NEW LIFE: %s" % lv.reward_label, Color(1.0, 0.86, 0.4), true)
	var spin := create_tween().set_loops()
	spin.tween_property(_reward_node, "rotation:y", TAU, 6.0).as_relative()
	var tw2 := create_tween()
	tw2.tween_interval(2.2)
	tw2.tween_callback(func():
		dialog.show_lines(lv.outro, func():
			_set_phase(Phase.RESULTS)
			var is_last: bool = int(lv.index) == GameData.LEVEL_ORDER.size() - 1
			results.show_results(res, level_id, is_last)
			level_finished.emit(res)))


# ================================================================ pause / jury
func _open_pause() -> void:
	if modal.is_open or phase == Phase.DEAD:
		return
	get_tree().paused = true
	modal.open("PAUSED", "Air, score and the shore wait for you.",
		[["RESUME", _resume, UiKit.TEAL], ["RESTART SHORE", _retry, Color(0.6, 0.6, 0.7)],
		 ["MAIN MENU", _to_menu, Color(0.6, 0.6, 0.7)]], UiKit.TEAL, _resume)


func _resume() -> void:
	get_tree().paused = false


func _retry() -> void:
	get_tree().paused = false
	request_replay.emit()


func _to_menu() -> void:
	get_tree().paused = false
	request_menu.emit()


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("pause"):
		_open_pause()
		get_viewport().set_input_as_handled()
		return
	if phase == Phase.SORT and e is InputEventKey and e.pressed and not e.echo:
		var idx: int = -1
		for k in [e.physical_keycode, e.keycode]:
			if k >= KEY_1 and k <= KEY_5:
				idx = k - KEY_1
			elif k >= KEY_KP_1 and k <= KEY_KP_5:
				idx = k - KEY_KP_1
		if idx < 0 and e.unicode >= 49 and e.unicode <= 53:
			idx = e.unicode - 49
		if idx >= 0:
			_choose_bin(GameData.BIN_ORDER[idx])
			get_viewport().set_input_as_handled()
			return
	if phase == Phase.SORT and e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var best := ""
		var bd := 95.0
		for id in GameData.BIN_ORDER:
			var sp: Vector2 = cam.unproject_position(station.bin_world_pos(id) - Vector3(0, 0.6, 0))
			var d: float = sp.distance_to(e.position)
			if d < bd:
				bd = d
				best = id
		if best != "":
			_choose_bin(best)
			get_viewport().set_input_as_handled()
	if e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_F2 and GameState.demo_mode:
		_demo_skip()


func _demo_skip() -> void:
	match phase:
		Phase.COLLECT:
			for c in collectibles:
				if not c.taken:
					_take(c)
		Phase.TO_STATION:
			_start_sort()
		Phase.SORT:
			if not _sort_busy and _sort_item != "":
				_choose_bin(String(GameData.item(_sort_item).bin))
		Phase.PUZZLE:
			puzzle.skip_step()
