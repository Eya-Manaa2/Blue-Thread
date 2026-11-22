extends Node3D
## ============================================================
##  LevelController — un rivage jouable de BLUE THREAD: THE LAST BLUE
##  INTRO (dialogue) -> COLLECT (5 objets utiles + objets pièges -5 s,
##  chronomètre, oxygène 1/s, recharges, obstacles physiques)
##  -> TO_STATION -> SORT (tri bonus dans les 5 bacs) -> WORKBENCH (les
##  objets réellement ramassés posés sur l'établi) -> PUZZLE (étapes de
##  recyclage) -> REWARD -> RESULTS.  Air à zéro -> DEAD (scène de mort,
##  reprise au point de contrôle).
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

enum Phase { INTRO, COLLECT, TO_STATION, SORT, WORKBENCH, PUZZLE, REWARD, RESULTS, DEAD }

const COLLECT_SPOTS := [Vector2(-28, 2.5), Vector2(-14, 10.0), Vector2(13, 3.0), Vector2(27, 9.0), Vector2(-5, 5.5)]
const REFILL_SPOTS := [Vector2(-21, 6.0), Vector2(20, 14.0), Vector2(7, 1.8)]
const DISTRACTOR_SPOTS := [Vector2(-21, 12.5), Vector2(5, 10.5), Vector2(22, 4.5), Vector2(-33, 8.0)]

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
var _useful_total: int = 5
var _time_left: float = 180.0
var _time_out_told: bool = false
var _death_active: bool = false     # verrou : la mort ne se déclenche qu'une fois
var _death_from: int = Phase.COLLECT
var _dead_k: float = 0.0
var _dead_cam_off := Vector3(1.7, 1.25, 2.3)
var bench_pos: Vector3
var _bench_items: Array = []        # Node3D posés sur l'établi

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

	bench_pos = Vector3(-8.5, world.height_at(-8.5, 7.0), 7.0)
	_build_workbench()

	_spawn_collectibles()
	_spawn_distractors()
	_spawn_refills()
	var keep: Array = [start_pos, station_pos, station_pos + Vector3(4.4, 0, 1.2), bench_pos, bench_pos + Vector3(2.1, 0, 0.3)]
	for c in collectibles:
		keep.append((c.root as Node3D).position)
	for r in refills:
		keep.append((r.root as Node3D).position)
	world.add_obstacles(keep)

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
	puzzle.step_completed.connect(_on_step_completed)
	puzzle.item_placed.connect(_on_item_placed)
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
	var items: Array = lv.collect
	_useful_total = items.size()
	var shift: float = float(int(lv.index) * 3 - 3)
	for i in items.size():
		_spawn_pickup(String(items[i]), _spot_pos(COLLECT_SPOTS[i % COLLECT_SPOTS.size()], shift), false, i)


## Objets pièges : visibles et nommés (étiquette 3D), ils ne comptent pas
## pour la recette et coûtent du temps.
func _spawn_distractors() -> void:
	var items: Array = lv.get("distractors", [])
	var shift: float = float(int(lv.index) * 2 - 2)
	for i in items.size():
		_spawn_pickup(String(items[i]), _spot_pos(DISTRACTOR_SPOTS[i % DISTRACTOR_SPOTS.size()], shift), true, i + 5)


func _spawn_pickup(id: String, p: Vector3, bad: bool, i: int) -> void:
	var col: Color = GameData.BINS[String(lv.material)].color
	var root := Node3D.new()
	root.position = p
	add_child(root)
	var spin := Node3D.new()
	spin.position = Vector3(0, 0.7, 0)
	root.add_child(spin)
	var model := ItemFactory.build(id)
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
	var tag := Mats.label3d(String(GameData.item(id).get("label", id)).to_upper(), 44, Color(1, 1, 1), root, Vector3(0, 1.9, 0), false)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.outline_size = 10
	tag.outline_modulate = Color(0, 0, 0, 0.8)
	tag.no_depth_test = false
	collectibles.append({"root": root, "spin": spin, "id": id, "taken": false, "phase": i * 1.3, "bad": bad, "tag": tag})


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
		var dist := _flat_dist(bp, (c.root as Node3D).global_position)
		(c.tag as Label3D).visible = dist < 14.0
		if phase == Phase.COLLECT and dist < 1.8:
			if bool(c.bad):
				_take_distractor(c)
			else:
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

	# oxygène : uniquement pendant l'exploration active (pas de dialogue, pas de menu)
	var exploring: bool = (phase == Phase.COLLECT or phase == Phase.TO_STATION) and not dialog.active and not modal.is_open and not _death_active
	if exploring:
		if GameState.drain_air(delta):
			_die()
		elif GameState.air < 25.0 and not _air_warned:
			_air_warned = true
			boy.set_air_warning(true)
			hud.toast("LOW AIR! Find a blue O2 station", UiKit.BAD)
	# chronomètre de collecte (en pause pendant dialogues / menus / mort)
	if exploring and phase == Phase.COLLECT:
		_time_left = maxf(0.0, _time_left - delta)
		hud.set_timer(_time_left, _time_left < 30.0)
		if _time_left <= 0.0 and not _time_out_told:
			_time_out_told = true
			hud.toast("TIME BONUS LOST — keep collecting", UiKit.BAD)
	# scène de mort : couleurs qui s'éteignent, vignette sombre
	if phase == Phase.DEAD:
		_dead_k = move_toward(_dead_k, 1.0, delta / 1.6)
		world.desaturate = _dead_k
		hud.set_dark_vignette(0.75 * _dead_k)

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
		Phase.SORT:
			tp = station_pos + Vector3(0.0, 2.5, 5.6)
			tl = station_pos + Vector3(0.0, 1.2, 0.0)
		Phase.WORKBENCH, Phase.PUZZLE:
			# l'établi à gauche de l'écran, le panneau d'étapes à droite
			tp = bench_pos + Vector3(1.3, 2.3, 3.6)
			tl = bench_pos + Vector3(1.1, 0.9, 0.0)
		Phase.DEAD:
			tp = bp + _dead_cam_off
			tl = bp + Vector3(0.0, 0.35, 0.0)
		Phase.REWARD, Phase.RESULTS:
			var a: float = _t * 0.25
			var c: Vector3 = bench_pos + Vector3(0, 1.4, 0.2)
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
	var frac: float = 0.4 * float(_collected) / float(maxi(1, _useful_total)) + 0.3 * float(_sorted) / float(n_sort) + 0.3 * float(_steps) / float(n_steps)
	var p: float = float(lv.r_from) + (float(lv.r_to) - float(lv.r_from)) * frac * 0.85
	GameState.set_local_restoration(p)
	world.set_local_restoration(p)


# ================================================================ collecte
func _start_collect() -> void:
	_set_phase(Phase.COLLECT)
	_time_left = GameData.COLLECT_TIME
	hud.set_timer(_time_left)
	hud.set_objective("Collect %s only   0 / %d" % [lv.material_label, _useful_total])
	hud.toast("WASD / arrows / joystick to move", UiKit.MUTED)
	hud.toast("Read the labels: wrong objects cost %d s" % int(GameData.DISTRACTOR_PENALTY), Color(1.0, 0.86, 0.4))


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
	if _collected >= _useful_total:
		_end_collection()
		_set_phase(Phase.INTRO)
		hud.set_objective("Go to the SORT STATION")
		var tw2 := create_tween()
		tw2.tween_interval(0.6)
		tw2.tween_callback(func():
			dialog.show_lines(lv.to_station, func():
				_set_phase(Phase.TO_STATION)
				hud.set_objective("Go to the SORT STATION")))
	else:
		hud.set_objective("Collect %s only   %d / %d" % [lv.material_label, _collected, _useful_total])


## Objet piège : ne compte pas, ne rejoint pas la recette, -5 s au chronomètre.
func _take_distractor(c: Dictionary) -> void:
	c.taken = true
	_time_left = maxf(0.0, _time_left - GameData.DISTRACTOR_PENALTY)
	hud.set_timer(_time_left, _time_left < 30.0)
	hud.flash_timer_penalty()
	GameState.distractor_picked()
	if sfx != null:
		sfx.bad()
	var it: Dictionary = GameData.item(String(c.id))
	var label: String = String(it.get("label", c.id))
	var why: String = String(it.get("tip", ""))
	if String(it.get("bin", "")) != "none":
		why = "%s is not %s: it cannot be part of this recipe." % [label, String(lv.material_label).to_lower()]
	hud.toast_tip("-%d s   ·   NOT %s: %s" % [int(GameData.DISTRACTOR_PENALTY), String(lv.material_label).to_upper(), label.to_upper()], why)
	var root: Node3D = c.root
	var tw := create_tween()
	tw.tween_property(root, "scale", Vector3.ONE * 0.01, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(root.queue_free)


func _end_collection() -> void:
	var bonus: int = int(_time_left / 3.0)
	hud.set_timer(NAN)
	if bonus > 0:
		GameState.add_score(bonus, "time_bonus")
		hud.toast("TIME BONUS  +%d" % bonus, Color(1.0, 0.86, 0.4))
	# les objets pièges restants disparaissent
	for c in collectibles:
		if not c.taken and bool(c.bad):
			c.taken = true
			var root: Node3D = c.root
			var tw := create_tween()
			tw.tween_property(root, "scale", Vector3.ONE * 0.01, 0.4)
			tw.tween_callback(root.queue_free)


# ================================================================ mort
## Air à zéro : un seul déclenchement, contrôles gelés, effondrement,
## caméra proche, désaturation, réplique, puis MISSION FAILED.
func _die() -> void:
	if _death_active:
		return
	_death_active = true
	_death_from = phase
	GameState.stats.deaths = int(GameState.stats.get("deaths", 0)) + 1
	_set_phase(Phase.DEAD)
	hud.set_arrow(NAN)
	boy.input_enabled = false
	boy.velocity = Vector3.ZERO
	boy.set_air_warning(true)
	if sfx != null:
		sfx.bad()
	_dead_cam_off = _pick_death_cam(boy.global_position)
	var tw: Tween = boy.collapse()
	tw.finished.connect(_death_line)


## Caméra proche de la scène de mort : premier angle sans obstacle entre
## la caméra et le personnage (rayon physique), pour qu'on le voie tomber.
func _pick_death_cam(bp: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	var from := bp + Vector3(0, 0.6, 0)
	for off in [Vector3(1.7, 1.25, 2.3), Vector3(-1.7, 1.25, 2.3), Vector3(0.0, 1.5, 2.6),
			Vector3(1.8, 1.4, -2.0), Vector3(-1.8, 1.4, -2.0), Vector3(0.0, 2.6, 1.2)]:
		var q := PhysicsRayQueryParameters3D.create(from, bp + (off as Vector3))
		q.exclude = [boy.get_rid()]
		if space.intersect_ray(q).is_empty():
			return off
	return Vector3(0.0, 2.6, 1.2)


func _death_line() -> void:
	var t := get_tree().create_timer(0.6)
	t.timeout.connect(func(): dialog.show_lines([["PLAYER", GameData.DEATH_LINE]], _mission_failed))


func _mission_failed() -> void:
	modal.open("MISSION FAILED", "Your promise is not over.",
		[["RETRY FROM CHECKPOINT", _retry_checkpoint, UiKit.TEAL], ["MAIN MENU", _to_menu, Color(0.6, 0.6, 0.7)]], UiKit.BAD)


## Point de contrôle = entrée du rivage, air plein ; les objets déjà
## ramassés, le profil et les rivages terminés sont conservés.
func _retry_checkpoint() -> void:
	get_tree().paused = false
	boy.revive()
	boy.global_position = start_pos
	boy.visual.rotation.y = 0.0
	GameState.refill_air()
	boy.set_air_warning(false)
	_air_warned = false
	_dead_k = 0.0
	world.desaturate = 0.0
	hud.set_dark_vignette(0.0)
	_cam_pos = start_pos + Vector3(0, 3.2, 7.4)
	_cam_look = start_pos + Vector3(0, 1.1, -4)
	cam.global_position = _cam_pos
	if _death_from == Phase.COLLECT:
		_time_left = GameData.COLLECT_TIME
		_time_out_told = false
		hud.set_timer(_time_left)
	_set_phase(_death_from)
	_death_active = false
	GameState.save_game()
	hud.toast("CHECKPOINT  ·  air refilled", Color(0.5, 0.9, 1.0))


func _on_out_of_hearts() -> void:
	if phase == Phase.DEAD:
		return
	_set_phase(Phase.DEAD)
	get_tree().paused = true
	modal.open("OUT OF HEARTS", "The shore needs you, %s. Breathe, and try again." % GameState.display_name(),
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
		dialog.show_lines(lv.to_puzzle, _start_workbench)
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
func _build_workbench() -> void:
	var bench := Node3D.new()
	bench.position = bench_pos
	add_child(bench)
	var wood := Mats.mat(Color(0.52, 0.38, 0.24), 0.85)
	var dark := Mats.mat(Color(0.30, 0.22, 0.15), 0.9)
	Mats.mi(Mats.box(Vector3(3.2, 0.12, 1.2)), wood, Vector3(0, 0.92, 0), bench)
	for sx in [-1.45, 1.45]:
		for sz in [-0.5, 0.5]:
			Mats.mi(Mats.box(Vector3(0.1, 0.9, 0.1)), dark, Vector3(sx, 0.45, sz), bench)
	Mats.mi(Mats.box(Vector3(3.0, 0.06, 1.0)), dark, Vector3(0, 0.25, 0), bench)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.86, 0.62)
	lamp.light_energy = 1.6
	lamp.omni_range = 4.5
	lamp.position = Vector3(0, 2.2, 0.8)
	bench.add_child(lamp)
	var sign := Mats.label3d("WORKBENCH", 70, Color(1.0, 0.86, 0.45), bench, Vector3(0, 1.9, -0.55))
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	# l'établi est un vrai meuble : on ne passe pas à travers
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(3.2, 1.0, 1.2)
	col.shape = bs
	col.position = Vector3(0, 0.5, 0)
	body.add_child(col)
	bench.add_child(body)


## Atelier : la caméra rejoint l'établi où apparaissent, un par un,
## les objets RÉELLEMENT ramassés sur ce rivage (GameState.inventory).
func _start_workbench() -> void:
	_set_phase(Phase.WORKBENCH)
	hud.set_objective("Your recovered %s" % String(lv.material_label).to_lower())
	boy.velocity = Vector3.ZERO
	var stand := bench_pos + Vector3(2.1, 0, 0.3)
	stand.y = world.height_at(stand.x, stand.z) + 0.05
	var tw := create_tween()
	tw.tween_property(boy, "global_position", stand, 1.2).set_trans(Tween.TRANS_SINE)
	boy.visual.rotation.y = PI * 0.5
	var inv: Array = GameState.level_inventory(level_id)
	if inv.is_empty():
		inv = (lv.collect as Array).duplicate()
	var n: int = inv.size()
	for i in n:
		var id: String = String(inv[i])
		var slot := Node3D.new()
		var x: float = -1.25 + 2.5 * (float(i) / float(maxi(1, n - 1)))
		slot.position = bench_pos + Vector3(x, 0.98, 0.15)
		add_child(slot)
		var model := ItemFactory.build(id)
		model.scale = Vector3.ONE * 0.01
		slot.add_child(model)
		var tag := Mats.label3d(String(GameData.item(id).get("label", id)), 30, Color(1, 1, 1), slot, Vector3(0, -0.02, 0.5), false)
		tag.rotation_degrees.x = -50
		tag.outline_size = 8
		tag.outline_modulate = Color(0, 0, 0, 0.85)
		tag.modulate.a = 0.0
		var rt := create_tween()
		rt.tween_interval(0.5 + i * 0.35)
		rt.tween_property(model, "scale", Vector3.ONE * 1.05, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		rt.parallel().tween_property(tag, "modulate:a", 1.0, 0.4)
		if sfx != null:
			rt.tween_callback(Callable(sfx, "pickup"))
		_bench_items.append(slot)
	var t2 := create_tween()
	t2.tween_interval(0.9 + n * 0.35)
	t2.tween_callback(func(): dialog.show_lines([["MIMA", GameData.WORKBENCH_LINE]], _start_puzzle))


func _start_puzzle() -> void:
	_set_phase(Phase.PUZZLE)
	hud.set_objective("Recycle: give your %s a new life" % String(lv.material_label).to_lower())
	var inv: Array = GameState.level_inventory(level_id)
	if inv.is_empty():
		inv = (lv.collect as Array).duplicate()
	puzzle.run(level_id, inv)


func _on_step_completed(_id: String) -> void:
	_steps += 1
	_update_restoration()
	# l'établi montre la transformation : les objets se tassent à chaque étape
	var n_steps: int = maxi(1, (lv.steps as Array).size())
	var k: float = 1.0 - 0.6 * float(_steps) / float(n_steps)
	for s in _bench_items:
		if not is_instance_valid(s):
			continue
		var node: Node3D = s
		var tw := create_tween()
		tw.tween_property(node, "scale", Vector3(1.0, k, 1.0), 0.35).set_trans(Tween.TRANS_SINE)


## Étape « poser dans la zone de travail » : l'objet correspondant saute.
func _on_item_placed(index: int) -> void:
	if index < 0 or index >= _bench_items.size():
		return
	if not is_instance_valid(_bench_items[index]):
		return
	var node: Node3D = _bench_items[index]
	var y0: float = node.position.y
	var tw := create_tween()
	tw.tween_property(node, "position:y", y0 + 0.35, 0.15).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "position:y", y0, 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func _on_puzzle_finished() -> void:
	_set_phase(Phase.REWARD)
	hud.set_objective("New life!")
	var res: Dictionary = GameState.complete_level(level_id)
	world.set_local_restoration(float(lv.r_to))
	for s in _bench_items:
		if not is_instance_valid(s):
			continue
		var node: Node3D = s
		var ft := create_tween()
		ft.tween_property(node, "scale", Vector3.ONE * 0.01, 0.4)
		ft.tween_callback(node.queue_free)
	_bench_items.clear()
	_reward_node = ItemFactory.build_reward(String(lv.reward))
	add_child(_reward_node)
	_reward_node.global_position = bench_pos + Vector3(0, 1.45, 0.1)
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
				if not c.taken and not bool(c.bad):
					_take(c)
		Phase.TO_STATION:
			_start_sort()
		Phase.SORT:
			if not _sort_busy and _sort_item != "":
				_choose_bin(String(GameData.item(_sort_item).bin))
		Phase.PUZZLE:
			puzzle.skip_step()
