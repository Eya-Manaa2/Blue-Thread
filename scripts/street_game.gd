extends Node3D
## ============================================================
##  BLUE THREAD — الخيط الأزرق
##  Sidi Bou Saïd, 2100. Trie les déchets pour rendre ses couleurs
##  à la ville et prouver à Jedda que la mer était bleue.
##
##  Tout le niveau est construit par code (aucun modèle 3D externe).
## ============================================================

const PlayerScript = preload("res://scripts/player.gd")
const JoystickScript = preload("res://scripts/joystick.gd")
const SfxScript = preload("res://scripts/sfx.gd")

# ---------- Réglages faciles à modifier ----------
const GOAL := 30                 # bons tris nécessaires pour finir
const MAX_STACK := 6             # taille max de la pile sur le dos
const START_TRASH := 24          # déchets au départ
const CHEHILI_EVERY := 45.0      # secondes entre deux rafales de Chehili
const STREET_HALF := 4.0         # demi-largeur de la rue
const STREET_START := 6.0
const STREET_END := -74.0
const TERRACE_END := -79.0

const CAT_NAMES := ["PLASTIQUE & MÉTAL", "PAPIER & CARTON", "VERRE", "ORGANIQUE"]
const CAT_SHORT := ["PLASTIQUE", "PAPIER", "VERRE", "ORGANIQUE"]
const CAT_COLORS := [Color(1.0, 0.8, 0.1), Color(0.15, 0.45, 0.95), Color(0.2, 0.72, 0.3), Color(0.5, 0.32, 0.16)]

# cat : 0 plastique & métal, 1 papier, 2 verre, 3 organique
const TRASH_TYPES := [
	{"name": "Bouteille en plastique", "cat": 0, "shape": "bottle", "fact": "Le plastique PET recyclé devient du fil polyester... comme le fil bleu de Jedda."},
	{"name": "Canette", "cat": 0, "shape": "can", "fact": "L'aluminium se recycle à l'infini sans perdre sa qualité."},
	{"name": "Sac plastique", "cat": 0, "shape": "bag", "fact": "Un sac plastique met des centaines d'années à disparaître dans la nature."},
	{"name": "Journal", "cat": 1, "shape": "paper", "fact": "Le papier peut être recyclé plusieurs fois avant que ses fibres ne s'usent."},
	{"name": "Carton", "cat": 1, "shape": "box", "fact": "Un carton aplati prend moins de place et se recycle facilement."},
	{"name": "Bocal de harissa", "cat": 2, "shape": "jar", "fact": "Le verre se recycle à l'infini : ton bocal de harissa peut redevenir un bocal !"},
	{"name": "Bouteille en verre", "cat": 2, "shape": "glass", "fact": "Recycler le verre économise du sable et de l'énergie."},
	{"name": "Peau d'orange maltaise", "cat": 3, "shape": "peel", "fact": "Les épluchures deviennent du compost qui nourrit les jardins."},
	{"name": "Noyaux de dattes", "cat": 3, "shape": "dates", "fact": "Les déchets organiques font plus de la moitié de nos poubelles : compostons-les !"},
	# Objets rares (déclenchent un flashback)
	{"name": "Bouteille de 2026", "cat": 0, "shape": "bottle", "fact": "Même une seule bouteille compte."},
	{"name": "Bocal de 2026", "cat": 2, "shape": "jar", "fact": "Le verre ne disparaît jamais tout seul."},
]
const RARE_BOTTLE := 9
const RARE_JAR := 10

const FLASHBACKS := {
	9: "21 novembre 2026, plage de La Marsa.\nQuelqu'un jette cette bouteille, « juste une fois ».\n\n74 ans plus tard, elle est arrivée jusqu'ici.",
	10: "Été 2026, Nabeul.\nUn bocal vide finit dans la nature au lieu du bac vert.\n\nLe verre ne disparaît jamais tout seul...",
}

const COMBO_WORDS := {2: "Behi !", 3: "Behi barcha !", 5: "Ya3tik essa7a !", 7: "Tbarkallah 3lik !", 10: "Rak m3allem !"}

enum Cam { FOLLOW, CINE }

# ---------- État ----------
var rng := RandomNumberGenerator.new()
var player = null
var joystick = null
var sfx = null
var camera: Camera3D
var cam_mode: int = Cam.CINE
var cine_look: Vector3 = Vector3.ZERO
var cam_offset: Vector3 = Vector3(0, 3.8, 6.2)
var shake: float = 0.0

var playing: bool = false
var game_over: bool = false
var time_now: float = 0.0
var score: int = 0
var combo: int = 0
var best_combo: int = 0
var correct: int = 0
var threads: int = 0
var throw_cooldown: float = 0.0
var target_bin_idx: int = -1
var chehili_timer: float = 0.0
var chehili_amount: float = 0.0
var milestones_done: Array = []

var restore_target: float = 0.0
var restore_display: float = 0.0
var sea_bonus: float = 0.0

var trash_items: Array = []   # Dictionary : node, type, rare, ready_at, phase
var stack: Array = []
var bins: Array = []          # Dictionary : node, cat, pos, top, out_dir
var stations: Array = []      # Vector3
var mounds: Array = []        # Dictionary : node, th, done
var blooms: Array = []        # Dictionary : node, th, done  (fleurs, chats)

var palette: Array = []       # matériaux qui reprennent leurs couleurs
var lantern_mat: StandardMaterial3D
var sea_mat: ShaderMaterial
var env: Environment
var sky_mat: ProceduralSkyMaterial
var sun: DirectionalLight3D
var sand: CPUParticles3D

var thread_mesh: ImmediateMesh
var thread_mat: StandardMaterial3D
var thread_mode: int = 0      # 0 = guide, 1 = finale
var thread_finale_k: float = 0.0
var jedda_pos: Vector3 = Vector3(-1.6, 1.0, -76.6)
var loom_pos: Vector3 = Vector3(0.2, 1.2, -77.2)
var spool: MeshInstance3D

# ---------- Interface ----------
var ui_font: SystemFont
var ui_root: Control
var lbl_score: Label
var lbl_combo_small: Label
var lbl_next: Label
var lbl_thread: Label
var lbl_stack: Label
var bar: ProgressBar
var lbl_bar: Label
var lbl_combo: Label
var fact_panel: PanelContainer
var fact_title: Label
var fact_text: Label
var banner: Label
var say_panel: PanelContainer
var say_name: Label
var say_text: Label
var title_big: Label
var title_sub: Label
var flash_rect: ColorRect
var flash_text: Label
var end_box: VBoxContainer
var btn_throw: Button
var _fact_id: int = 0
var _banner_id: int = 0
var _skip_line: bool = false
var _skip_all: bool = false
var in_intro: bool = false


# ============================================================
#  DÉMARRAGE
# ============================================================
func _ready() -> void:
	rng.seed = 2100
	_setup_input()
	sfx = SfxScript.new()
	add_child(sfx)
	_build_environment()
	_build_ground_and_walls()
	_build_street()
	_build_terrace_and_sea()
	_build_bins()
	_build_npcs()
	_build_mounds()
	_build_thread()
	_spawn_player()
	player.on_step = sfx.step
	sfx.start_ambience()
	_build_ui()
	_spawn_initial_trash()
	_apply_restore(0.0)
	_run_intro()


func _setup_input() -> void:
	_add_keys("move_left", [KEY_A, KEY_LEFT])
	_add_keys("move_right", [KEY_D, KEY_RIGHT])
	_add_keys("move_up", [KEY_W, KEY_UP])
	_add_keys("move_down", [KEY_S, KEY_DOWN])
	_add_keys("throw", [KEY_SPACE, KEY_E])
	_add_keys("skip", [KEY_ENTER, KEY_KP_ENTER])
	_add_keys("skip_all", [KEY_ESCAPE])


func _add_keys(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		# physical_keycode : ZQSD fonctionne aussi sur clavier AZERTY
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


# ============================================================
#  OUTILS DE CONSTRUCTION
# ============================================================
func _mat(c: Color, rough: float = 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


## Matériau qui passe du gris (monde pollué) à sa vraie couleur
## quand la restauration va de a à b.
func _pal(grey: Color, col: Color, a: float, b: float, rough: float = 0.9) -> StandardMaterial3D:
	var m := _mat(grey, rough)
	palette.append({"mat": m, "grey": grey, "color": col, "a": a, "b": b})
	return m


func _glass(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.05
	m.metallic_specular = 0.9
	return m


func _unshaded(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.vertex_color_use_as_albedo = true
	return m


func _add(mesh: Mesh, m: Material, pos: Vector3, parent: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	var p: Node = parent if parent != null else self
	p.add_child(mi)
	return mi


func _box(size: Vector3, pos: Vector3, m: Material, parent: Node = null) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	return _add(bm, m, pos, parent)


func _cyl(r: float, h: float, pos: Vector3, m: Material, parent: Node = null, top_r: float = -1.0) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.bottom_radius = r
	cm.top_radius = r if top_r < 0.0 else top_r
	cm.height = h
	cm.radial_segments = 16
	return _add(cm, m, pos, parent)


func _sphere(r: float, pos: Vector3, m: Material, parent: Node = null, hemi: bool = false) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r if hemi else r * 2.0
	sm.is_hemisphere = hemi
	sm.radial_segments = 20
	sm.rings = 10
	return _add(sm, m, pos, parent)


func _capsule(r: float, h: float, pos: Vector3, m: Material, parent: Node = null) -> MeshInstance3D:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	return _add(c, m, pos, parent)


func _wall(size: Vector3, pos: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	add_child(body)


func _label3d(text: String, pos: Vector3, size: int, col: Color, parent: Node = null) -> Label3D:
	var l := Label3D.new()
	l.text = text
	if ui_font != null:
		l.font = ui_font
	l.font_size = size
	l.pixel_size = 0.006
	l.modulate = col
	l.outline_size = 12
	l.outline_modulate = Color(0, 0, 0, 0.85)
	l.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	l.position = pos
	var p: Node = parent if parent != null else self
	p.add_child(l)
	return l


# ============================================================
#  MONDE
# ============================================================
func _build_environment() -> void:
	ui_font = SystemFont.new()
	ui_font.font_names = PackedStringArray(["Segoe UI", "Arial", "Tahoma", "Noto Sans", "Sans-Serif"])

	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sun_angle_max = 20.0
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.05
	env.fog_enabled = true
	env.fog_sun_scatter = 0.25
	# Rendu « film d'animation » (Forward+ ; ignoré automatiquement sur mobile)
	env.ssao_enabled = true
	env.ssao_radius = 1.5
	env.ssao_intensity = 2.5
	env.ssil_enabled = true
	env.ssil_intensity = 1.2
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_strength = 1.1
	env.glow_bloom = 0.12
	env.glow_hdr_threshold = 0.85
	env.adjustment_enabled = true
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-34, -62, 0)   # soleil bas : lumière dorée de fin d'après-midi
	sun.shadow_enabled = true
	sun.light_angular_distance = 1.2              # ombres douces
	sun.shadow_blur = 1.5
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)

	camera = Camera3D.new()
	camera.fov = 62.0
	camera.far = 1500.0
	add_child(camera)
	camera.make_current()

	# Particules de sable pour le Chehili (attachées à la caméra)
	sand = CPUParticles3D.new()
	sand.emitting = false
	sand.amount = 350
	sand.lifetime = 1.4
	sand.local_coords = false
	sand.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	sand.emission_box_extents = Vector3(4, 5, 8)
	sand.position = Vector3(-12, 0, -9)
	sand.direction = Vector3(1, 0.05, 0)
	sand.spread = 12.0
	sand.gravity = Vector3.ZERO
	sand.initial_velocity_min = 14.0
	sand.initial_velocity_max = 22.0
	sand.scale_amount_min = 0.5
	sand.scale_amount_max = 1.5
	var grain := BoxMesh.new()
	grain.size = Vector3(0.08, 0.03, 0.03)
	grain.material = _unshaded(Color(0.85, 0.7, 0.45))
	sand.mesh = grain
	sand.color = Color(0.9, 0.75, 0.5)
	camera.add_child(sand)


func _build_ground_and_walls() -> void:
	# Sol en pavés (texture de bruit « cellulaire »)
	var ground_mat := _pal(Color(0.5, 0.47, 0.44), Color(0.92, 0.68, 0.5), 0.0, 0.7)
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.frequency = 0.025
	noise.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	var tex := NoiseTexture2D.new()
	tex.width = 512
	tex.height = 512
	tex.seamless = true
	tex.noise = noise
	var grad := Gradient.new()
	grad.set_color(0, Color(0.45, 0.42, 0.4))
	grad.set_color(1, Color(1, 1, 1))
	tex.color_ramp = grad
	ground_mat.albedo_texture = tex
	ground_mat.uv1_scale = Vector3(3, 30, 1)
	var ntex := NoiseTexture2D.new()
	ntex.width = 512
	ntex.height = 512
	ntex.seamless = true
	ntex.as_normal_map = true
	ntex.bump_strength = 6.0
	ntex.noise = noise
	ground_mat.normal_enabled = true
	ground_mat.normal_texture = ntex

	var length: float = STREET_START - TERRACE_END + 4.0
	var pm := PlaneMesh.new()
	pm.size = Vector2(STREET_HALF * 2.0 + 2.0, length)
	_add(pm, ground_mat, Vector3(0, 0, (STREET_START + TERRACE_END) * 0.5))
	_wall(Vector3(40, 1, length + 10), Vector3(0, -0.5, (STREET_START + TERRACE_END) * 0.5))

	# Murs invisibles (bords de la rue, début, terrasse)
	var zc: float = (STREET_START + TERRACE_END) * 0.5
	_wall(Vector3(0.4, 6, length + 4), Vector3(-STREET_HALF - 0.2, 3, zc))
	_wall(Vector3(0.4, 6, length + 4), Vector3(STREET_HALF + 0.2, 3, zc))
	_wall(Vector3(STREET_HALF * 2.0 + 2, 6, 0.4), Vector3(0, 3, STREET_START + 0.5))
	_wall(Vector3(STREET_HALF * 2.0 + 2, 6, 0.4), Vector3(0, 3, TERRACE_END + 0.6))


func _plastered(m: StandardMaterial3D, tex: Texture2D) -> StandardMaterial3D:
	m.albedo_texture = tex
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(0.35, 0.35, 0.35)
	return m


func _build_street() -> void:
	# Enduit à la chaux : légère texture sur les murs
	var plaster := NoiseTexture2D.new()
	var pn := FastNoiseLite.new()
	pn.frequency = 0.02
	pn.fractal_octaves = 5
	plaster.noise = pn
	plaster.seamless = true
	plaster.width = 256
	plaster.height = 256
	var pg := Gradient.new()
	pg.set_color(0, Color(0.82, 0.8, 0.78))
	pg.set_color(1, Color(1, 1, 1))
	plaster.color_ramp = pg

	var walls: Array = [
		_plastered(_pal(Color(0.55, 0.52, 0.48), Color(0.99, 0.92, 0.8), 0.0, 0.55), plaster),
		_plastered(_pal(Color(0.52, 0.49, 0.46), Color(0.98, 0.84, 0.7), 0.0, 0.55), plaster),
		_plastered(_pal(Color(0.56, 0.54, 0.52), Color(0.98, 0.97, 0.94), 0.0, 0.55), plaster),
	]
	lantern_mat = _mat(Color(1.0, 0.85, 0.55), 0.4)
	lantern_mat.emission_enabled = true
	lantern_mat.emission = Color(1.0, 0.72, 0.3)
	lantern_mat.emission_energy_multiplier = 0.0
	var kit := {
		"blue": _pal(Color(0.36, 0.37, 0.4), Color(0.08, 0.38, 0.78), 0.12, 0.35, 0.55),
		"blue_light": _pal(Color(0.4, 0.41, 0.43), Color(0.25, 0.58, 0.88), 0.15, 0.4, 0.4),
		"iron": _pal(Color(0.25, 0.26, 0.28), Color(0.1, 0.25, 0.52), 0.12, 0.35, 0.4),
		"stone": _pal(Color(0.42, 0.4, 0.38), Color(0.85, 0.74, 0.6), 0.05, 0.6),
		"wood": _pal(Color(0.35, 0.32, 0.3), Color(0.62, 0.33, 0.18), 0.1, 0.5, 0.7),
		"plant": _pal(Color(0.38, 0.38, 0.35), Color(0.3, 0.62, 0.2), 0.3, 0.6, 0.8),
		"plant_dark": _pal(Color(0.32, 0.32, 0.3), Color(0.12, 0.42, 0.15), 0.3, 0.6, 0.8),
		"pot": _pal(Color(0.42, 0.39, 0.36), Color(0.82, 0.42, 0.22), 0.3, 0.55),
		"fabric_a": _pal(Color(0.4, 0.38, 0.37), Color(0.85, 0.15, 0.18), 0.3, 0.6),
		"fabric_b": _pal(Color(0.42, 0.41, 0.4), Color(0.15, 0.3, 0.7), 0.3, 0.6),
		"flower": _mat(Color(0.95, 0.2, 0.6), 0.7),
		"jasmine": _mat(Color(1, 1, 0.97), 0.7),
	}

	for side in [-1, 1]:
		var z: float = STREET_START
		while z > STREET_END + 2.0:
			var w: float = rng.randf_range(6.0, 9.0)
			var h: float = rng.randf_range(5.0, 8.5)
			var d: float = 7.0
			var cz: float = z - w * 0.5
			var cx: float = side * (STREET_HALF + d * 0.5)
			var wm: StandardMaterial3D = walls[rng.randi_range(0, walls.size() - 1)]
			_build_house(cx, cz, side, w, h, d, wm, kit)
			z -= w
		# Deuxième rangée de toits pour donner l'impression d'une ville
		var z2: float = STREET_START
		while z2 > STREET_END:
			var w2: float = rng.randf_range(7.0, 11.0)
			var h2: float = rng.randf_range(7.0, 12.0)
			var wm2: StandardMaterial3D = walls[rng.randi_range(0, walls.size() - 1)]
			_box(Vector3(8, h2, w2), Vector3(side * (STREET_HALF + 11.0), h2 * 0.5, z2 - w2 * 0.5), wm2)
			if rng.randf() < 0.35:
				_sphere(1.6, Vector3(side * (STREET_HALF + 11.0), h2, z2 - w2 * 0.5), walls[2], null, true)
			z2 -= w2

	# Maison qui ferme la rue au début, avec une grande porte bleue
	var blue: Material = kit["blue"]
	_box(Vector3(16, 9, 6), Vector3(0, 4.5, STREET_START + 3.5), walls[0])
	_box(Vector3(1.8, 3.0, 0.2), Vector3(0, 1.5, STREET_START + 0.45), blue)
	var arch := _cyl(0.9, 0.2, Vector3(0, 3.0, STREET_START + 0.45), blue)
	arch.rotation_degrees = Vector3(90, 0, 0)


func _build_house(cx: float, cz: float, side: int, w: float, h: float, d: float, wm: Material, kit: Dictionary) -> void:
	var blue: Material = kit["blue"]
	var blue_light: Material = kit["blue_light"]
	var iron: Material = kit["iron"]
	var stone: Material = kit["stone"]
	var wood: Material = kit["wood"]
	var plant: Material = kit["plant"]
	var plant_dark: Material = kit["plant_dark"]
	var pot: Material = kit["pot"]
	var fabric_a: Material = kit["fabric_a"]
	var fabric_b: Material = kit["fabric_b"]

	_box(Vector3(d, h, w), Vector3(cx, h * 0.5, cz), wm)
	var fx: float = side * STREET_HALF        # façade côté rue
	var inward: float = -side                  # direction vers la rue

	# Soubassement en pierre
	_box(Vector3(0.12, 0.55, w), Vector3(fx + inward * 0.04, 0.275, cz), stone)
	# Corniche + poutres en bois qui dépassent sous le toit
	_box(Vector3(d + 0.3, 0.22, w + 0.3), Vector3(cx, h + 0.11, cz), wm)
	var n_beams: int = int(w / 0.9)
	for i in n_beams:
		var bz: float = cz - w * 0.5 + 0.45 + float(i) * (w - 0.9) / maxf(float(n_beams - 1), 1.0)
		_box(Vector3(0.45, 0.14, 0.14), Vector3(fx + inward * 0.2, h - 0.12, bz), wood)

	# Porte bleue en arc, encadrement en pierre, clous, marche
	var dz: float = cz + rng.randf_range(-w * 0.25, w * 0.25)
	_box(Vector3(0.14, 2.75, 1.65), Vector3(fx + inward * 0.01, 1.37, dz), stone)
	var arch_frame := _cyl(0.82, 0.14, Vector3(fx + inward * 0.01, 2.3, dz), stone)
	arch_frame.rotation_degrees = Vector3(0, 0, 90)
	_box(Vector3(0.2, 2.3, 1.3), Vector3(fx + inward * 0.03, 1.15, dz), blue)
	var arch := _cyl(0.65, 0.2, Vector3(fx + inward * 0.03, 2.3, dz), blue)
	arch.rotation_degrees = Vector3(0, 0, 90)
	_box(Vector3(0.7, 0.2, 1.9), Vector3(fx + inward * 0.35, 0.1, dz), stone)
	var stud_mat := _mat(Color(0.12, 0.12, 0.15), 0.35)
	for i in 4:
		for j in 3:
			_sphere(0.035, Vector3(fx + inward * 0.14, 0.5 + i * 0.5, dz - 0.4 + j * 0.4), stud_mat)

	# Lanterne murale en fer forgé
	var lz: float = dz + 1.1
	_box(Vector3(0.35, 0.04, 0.04), Vector3(fx + inward * 0.17, 2.75, lz), iron)
	_box(Vector3(0.2, 0.3, 0.2), Vector3(fx + inward * 0.32, 2.58, lz), lantern_mat)
	_cyl(0.16, 0.1, Vector3(fx + inward * 0.32, 2.78, lz), iron, null, 0.02)

	# Fenêtres en arc avec grille de fer forgé, balcons en bois
	var floors: Array = [3.7]
	if h > 7.0:
		floors.append(6.2)
	for fy in floors:
		var n_win: int = 2 if w > 7.5 else 1
		for k in n_win:
			var wz: float = cz + (k - (n_win - 1) * 0.5) * (w * 0.4)
			_box(Vector3(0.12, 1.25, 0.9), Vector3(fx + inward * 0.02, fy, wz), blue_light)
			var wa := _cyl(0.45, 0.12, Vector3(fx + inward * 0.02, fy + 0.62, wz), blue_light)
			wa.rotation_degrees = Vector3(0, 0, 90)
			for b in 4:
				_box(Vector3(0.04, 1.5, 0.04), Vector3(fx + inward * 0.1, fy + 0.1, wz - 0.33 + b * 0.22), iron)
			_box(Vector3(0.04, 0.04, 0.9), Vector3(fx + inward * 0.1, fy - 0.3, wz), iron)
			_box(Vector3(0.04, 0.04, 0.9), Vector3(fx + inward * 0.1, fy + 0.4, wz), iron)
			_box(Vector3(0.22, 0.1, 1.1), Vector3(fx + inward * 0.06, fy - 0.68, wz), stone)
			if rng.randf() < 0.5:
				var by: float = fy - 0.75
				_box(Vector3(1.0, 0.14, 2.0), Vector3(fx + inward * 0.5, by, wz), wood)
				for c in 3:
					_box(Vector3(0.9, 0.25, 0.14), Vector3(fx + inward * 0.45, by - 0.18, wz - 0.8 + c * 0.8), wood)
				_box(Vector3(0.05, 0.05, 2.0), Vector3(fx + inward * 0.97, by + 0.75, wz), iron)
				_box(Vector3(0.05, 0.05, 2.0), Vector3(fx + inward * 0.97, by + 0.12, wz), iron)
				for b in 9:
					_box(Vector3(0.03, 0.65, 0.03), Vector3(fx + inward * 0.97, by + 0.43, wz - 0.9 + b * 0.225), iron)
				_box(Vector3(0.95, 0.05, 0.05), Vector3(fx + inward * 0.5, by + 0.75, wz - 1.0), iron)
				_box(Vector3(0.95, 0.05, 0.05), Vector3(fx + inward * 0.5, by + 0.75, wz + 1.0), iron)
				if rng.randf() < 0.55:
					# Couverture rayée qui sèche sur la rambarde
					for s in 5:
						var fm: Material = fabric_a if s % 2 == 0 else fabric_b
						_box(Vector3(0.03, 0.95, 0.15), Vector3(fx + inward * 1.0, by + 0.32, wz + 0.1 + s * 0.15), fm)
				# Pots de fleurs sur le balcon
				_cyl(0.13, 0.22, Vector3(fx + inward * 0.5, by + 0.18, wz - 0.6), pot, null, 0.16)
				_sphere(0.2, Vector3(fx + inward * 0.5, by + 0.42, wz - 0.6), plant)

	# Lierre qui tombe du toit
	if rng.randf() < 0.55:
		var iz: float = cz + rng.randf_range(-w * 0.4, w * 0.4)
		var length: float = rng.randf_range(1.5, 3.5)
		for i in rng.randi_range(12, 20):
			var t: float = rng.randf()
			var lm: Material = plant if rng.randf() < 0.5 else plant_dark
			_sphere(rng.randf_range(0.14, 0.26) * (1.0 - t * 0.5), Vector3(fx + inward * 0.12, h - t * length, iz + rng.randf_range(-0.6, 0.6) * (1.0 - t * 0.6)), lm)

	# Dôme sur certains toits
	if rng.randf() < 0.3:
		_sphere(1.3, Vector3(cx, h + 0.2, cz), wm, null, true)

	# Pots et plantes devant la porte
	if rng.randf() < 0.75:
		var pz: float = dz + 1.35
		_cyl(0.26, 0.48, Vector3(fx + inward * 0.45, 0.24, pz), pot, null, 0.33)
		_sphere(0.36, Vector3(fx + inward * 0.45, 0.7, pz), plant)
		if rng.randf() < 0.6:
			var pz2: float = dz - 1.3
			_cyl(0.2, 0.36, Vector3(fx + inward * 0.4, 0.18, pz2), pot, null, 0.25)
			_capsule(0.1, 0.6, Vector3(fx + inward * 0.4, 0.62, pz2), plant_dark)
			_capsule(0.07, 0.4, Vector3(fx + inward * 0.4 + 0.08, 0.6, pz2 + 0.1), plant_dark)

	# Bougainvillier / jasmin (apparaît quand la ville refleurit)
	if rng.randf() < 0.6:
		var cluster := Node3D.new()
		cluster.position = Vector3(fx + inward * 0.25, rng.randf_range(2.8, h - 0.6), cz + rng.randf_range(-w * 0.35, w * 0.35))
		add_child(cluster)
		var fmat: Material = kit["flower"] if rng.randf() < 0.7 else kit["jasmine"]
		for i in rng.randi_range(8, 14):
			_sphere(rng.randf_range(0.14, 0.28), Vector3(rng.randf_range(-0.15, 0.15), rng.randf_range(-1.0, 0.5), rng.randf_range(-1.0, 1.0)), fmat, cluster)
		cluster.scale = Vector3(0.01, 0.01, 0.01)
		cluster.visible = false
		blooms.append({"node": cluster, "th": rng.randf_range(0.42, 0.62), "done": false})


func _build_terrace_and_sea() -> void:
	var wall_a := _pal(Color(0.42, 0.40, 0.38), Color(0.97, 0.96, 0.93), 0.0, 0.55)
	var blue := _pal(Color(0.30, 0.31, 0.33), Color(0.03, 0.32, 0.78), 0.12, 0.35, 0.6)
	var rock := _pal(Color(0.3, 0.28, 0.26), Color(0.62, 0.48, 0.34), 0.0, 0.8)
	var hill := _pal(Color(0.32, 0.31, 0.3), Color(0.45, 0.5, 0.62), 0.3, 1.0)

	# Muret blanc et rambarde bleue au bord de la falaise
	_box(Vector3(STREET_HALF * 2.0 + 2, 0.9, 0.4), Vector3(0, 0.45, TERRACE_END + 0.6), wall_a)
	_box(Vector3(STREET_HALF * 2.0 + 2, 0.12, 0.5), Vector3(0, 0.95, TERRACE_END + 0.6), blue)
	# Falaise
	_box(Vector3(400, 10, 8), Vector3(0, -5.0, TERRACE_END - 3.2), rock)

	# Mer (shader avec vagues)
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
uniform vec4 water_color : source_color = vec4(0.35, 0.33, 0.30, 1.0);
uniform vec4 deep_color : source_color = vec4(0.25, 0.24, 0.22, 1.0);
void vertex() {
	float w = sin(VERTEX.x * 0.08 + TIME * 1.1) * 0.35 + cos(VERTEX.z * 0.11 + TIME * 0.8) * 0.3;
	VERTEX.y += w;
}
void fragment() {
	float f = sin(UV.x * 260.0 + TIME * 1.4) * sin(UV.y * 220.0 - TIME * 1.1) * 0.5 + 0.5;
	ALBEDO = mix(deep_color.rgb, water_color.rgb, 0.55 + 0.35 * f);
	ROUGHNESS = 0.12;
	METALLIC = 0.15;
	SPECULAR = 0.8;
}
"""
	sea_mat = ShaderMaterial.new()
	sea_mat.shader = sh
	var sea := PlaneMesh.new()
	sea.size = Vector2(1000, 800)
	sea.subdivide_width = 80
	sea.subdivide_depth = 80
	_add(sea, sea_mat, Vector3(0, -7.0, TERRACE_END - 400.0))

	# Bou Kornine, la montagne aux deux cornes, de l'autre côté du golfe de Tunis
	_cyl(85, 70, Vector3(-190, 28, -470), hill, null, 2.0)
	_cyl(65, 55, Vector3(-120, 20.5, -490), hill, null, 2.0)


func _build_bins() -> void:
	stations = [Vector3(-STREET_HALF + 0.9, 0, -22.0), Vector3(STREET_HALF - 0.9, 0, -50.0)]
	var offsets: Array = [-2.25, -0.75, 0.75, 2.25]
	var black := _mat(Color(0.04, 0.04, 0.04))
	var rubber := _mat(Color(0.08, 0.08, 0.08), 0.6)
	for s in stations.size():
		var st: Vector3 = stations[s]
		var side: float = -1.0 if st.x < 0.0 else 1.0
		for c in 4:
			var pos := Vector3(side * (STREET_HALF - 0.65), 0, st.z + float(offsets[c]))
			var root := Node3D.new()
			root.position = pos
			add_child(root)
			var col: Color = CAT_COLORS[c]
			var body_m := _mat(col, 0.4)
			var dark_m := _mat(col.darkened(0.18), 0.4)
			# Poubelle à roulettes : cuve, couvercle, poignée, roues
			_box(Vector3(0.82, 1.0, 0.78), Vector3(0, 0.6, 0), body_m, root)
			_box(Vector3(0.86, 0.08, 0.82), Vector3(0, 0.14, 0), dark_m, root)
			_box(Vector3(0.94, 0.1, 0.88), Vector3(0, 1.14, 0), dark_m, root)
			_box(Vector3(0.6, 0.02, 0.6), Vector3(0, 1.2, 0), black, root)
			_box(Vector3(0.07, 0.07, 0.62), Vector3(side * 0.47, 1.06, 0), dark_m, root)
			for wz in [-0.3, 0.3]:
				var wheel := _cyl(0.13, 0.08, Vector3(side * 0.33, 0.13, wz), rubber, root)
				wheel.rotation_degrees = Vector3(90, 0, 0)
			# Nom imprimé sur la face avant
			var front := Label3D.new()
			front.text = String(CAT_SHORT[c])
			if ui_font != null:
				front.font = ui_font
			front.font_size = 34
			front.pixel_size = 0.005
			front.outline_size = 8
			front.outline_modulate = col.darkened(0.5)
			front.modulate = Color(1, 1, 1)
			front.position = Vector3(-side * 0.42, 0.7, 0)
			front.rotation_degrees = Vector3(0, -side * 90.0, 0)
			root.add_child(front)
			_label3d(String(CAT_NAMES[c]).replace(" & ", "\n& "), Vector3(0, 2.0, 0), 30, col.lightened(0.4), root)
			# Collision
			var body := StaticBody3D.new()
			var cs := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = Vector3(0.9, 1.2, 0.9)
			cs.shape = shape
			cs.position = Vector3(0, 0.6, 0)
			body.add_child(cs)
			root.add_child(body)
			# Anneau lumineux quand le bac est visé
			var ring_mat := _unshaded(Color(col.r, col.g, col.b, 0.75))
			ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			var ring := _cyl(0.85, 0.03, Vector3(0, 0.02, 0), ring_mat, root)
			ring.visible = false
			bins.append({"node": root, "cat": c, "pos": pos, "top": pos + Vector3(0, 1.35, 0), "out_dir": Vector3(-side, 0, 0), "ring": ring})


func _build_person(pos: Vector3, body_col: Color, head_wear: String, seated: bool) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	var skin := _mat(Color(0.85, 0.66, 0.5))
	var body := _mat(body_col)
	var y0: float = 0.0 if not seated else -0.35
	_capsule(0.28, 1.0, Vector3(0, y0 + 0.95, 0), body, root)
	_sphere(0.23, Vector3(0, y0 + 1.6, 0), skin, root)
	if head_wear == "chechia":
		# Chéchia rouge
		_cyl(0.2, 0.18, Vector3(0, y0 + 1.82, 0), _mat(Color(0.75, 0.08, 0.1)), root, 0.17)
	elif head_wear == "sefsari":
		# Sefsari blanc qui couvre la tête
		var veil := _sphere(0.27, Vector3(0, y0 + 1.66, 0.03), _mat(Color(0.96, 0.95, 0.9)), root)
		veil.scale = Vector3(1.0, 1.05, 1.0)
		_capsule(0.33, 1.1, Vector3(0, y0 + 1.05, 0.04), _mat(Color(0.96, 0.95, 0.9)), root)
	return root


func _build_npcs() -> void:
	# Am Hédi, le barbech, avec sa charrette
	var hedi := _build_person(Vector3(2.6, 0, -3.0), Color(0.2, 0.3, 0.55), "chechia", false)
	hedi.rotation_degrees = Vector3(0, -70, 0)
	_label3d("Am Hédi, le barbech", Vector3(2.6, 2.35, -3.0), 36, Color(1, 0.9, 0.6))
	var wood := _mat(Color(0.5, 0.32, 0.18))
	_box(Vector3(0.9, 0.5, 1.4), Vector3(2.9, 0.75, -4.6), wood)
	var wheel_mat := _mat(Color(0.15, 0.15, 0.15))
	for zz in [-4.1, -5.1]:
		var wh := _cyl(0.28, 0.08, Vector3(3.38, 0.28, zz), wheel_mat)
		wh.rotation_degrees = Vector3(0, 0, 90)
	var bottle_mat := _mat(Color(0.55, 0.8, 1.0), 0.2)
	for i in 4:
		var b := _cyl(0.1, 0.4, Vector3(2.7 + i * 0.13, 1.1, -4.6 + rng.randf_range(-0.4, 0.4)), bottle_mat)
		b.rotation_degrees = Vector3(rng.randf_range(-30, 30), 0, rng.randf_range(-30, 30))

	# Jedda Zohra sur la terrasse, assise près de son métier à tisser
	var wall_a := _mat(Color(0.9, 0.9, 0.88))
	_box(Vector3(1.6, 0.45, 0.6), Vector3(-1.6, 0.22, -77.3), wall_a)
	var jedda := _build_person(Vector3(-1.6, 0.45, -77.2), Color(0.96, 0.95, 0.9), "sefsari", true)
	jedda.rotation_degrees = Vector3(0, 180, 0)
	_label3d("Jedda Zohra", Vector3(-1.6, 2.3, -77.2), 36, Color(1, 0.9, 0.6))
	# Métier à tisser + bobine de fil bleu qui grossit
	_box(Vector3(0.08, 1.6, 0.08), Vector3(-0.3, 0.8, -77.4), wood)
	_box(Vector3(0.08, 1.6, 0.08), Vector3(0.7, 0.8, -77.4), wood)
	_box(Vector3(1.1, 0.08, 0.08), Vector3(0.2, 1.6, -77.4), wood)
	_box(Vector3(0.9, 1.0, 0.03), Vector3(0.2, 0.95, -77.4), _mat(Color(0.75, 0.2, 0.15)))
	spool = _cyl(0.12, 0.3, Vector3(0.2, 1.75, -77.4), _mat(Color(0.1, 0.45, 0.95), 0.4))
	spool.rotation_degrees = Vector3(0, 0, 90)

	# Les chats de Sidi Bou Saïd (reviennent à 75 %)
	var cat_cols: Array = [Color(0.9, 0.55, 0.2), Color(0.95, 0.95, 0.95), Color(0.3, 0.3, 0.32)]
	var cat_pos: Array = [Vector3(-3.4, 0.0, -9.0), Vector3(3.3, 0.0, -38.0), Vector3(-3.3, 0.0, -63.0)]
	for i in 3:
		var cat := Node3D.new()
		cat.position = cat_pos[i]
		add_child(cat)
		var cm := _mat(cat_cols[i])
		var cat_body := _capsule(0.16, 0.5, Vector3(0, 0.22, 0), cm, cat)
		cat_body.rotation_degrees = Vector3(90, 0, 0)
		_sphere(0.14, Vector3(0, 0.42, -0.22), cm, cat)
		_cyl(0.05, 0.12, Vector3(-0.07, 0.56, -0.22), cm, cat, 0.0)
		_cyl(0.05, 0.12, Vector3(0.07, 0.56, -0.22), cm, cat, 0.0)
		var tail := _capsule(0.03, 0.4, Vector3(0, 0.35, 0.3), cm, cat)
		tail.rotation_degrees = Vector3(-40, 0, 0)
		cat.rotation_degrees = Vector3(0, rng.randf_range(0, 360), 0)
		cat.scale = Vector3(0.01, 0.01, 0.01)
		cat.visible = false
		blooms.append({"node": cat, "th": 0.75, "done": false, "kind": "cat"})


func _build_mounds() -> void:
	var greys: Array = [Color(0.28, 0.27, 0.25), Color(0.33, 0.31, 0.29), Color(0.24, 0.24, 0.24), Color(0.38, 0.34, 0.3)]
	var mats: Array = []
	for g in greys:
		mats.append(_mat(g, 1.0))
	# Petits tas le long des murs
	var z: float = -4.0
	var i: int = 0
	while z > STREET_END + 4.0:
		var side: float = -1.0 if i % 2 == 0 else 1.0
		_make_mound(Vector3(side * (STREET_HALF - 0.7), 0, z + rng.randf_range(-1.5, 1.5)), rng.randf_range(0.8, 1.3), mats, rng.randf_range(0.08, 0.85))
		z -= rng.randf_range(4.0, 6.5)
		i += 1
	# La grande montagne de déchets qui cache la mer
	for k in 5:
		_make_mound(Vector3(rng.randf_range(-3.0, 3.0), 0, -74.0 + rng.randf_range(-1.5, 1.5)), rng.randf_range(2.0, 3.2), mats, 0.9 + k * 0.015)


func _make_mound(pos: Vector3, size: float, mats: Array, th: float) -> void:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	for k in rng.randi_range(7, 11):
		var m: Material = mats[rng.randi_range(0, mats.size() - 1)]
		var lump := _sphere(rng.randf_range(0.25, 0.55) * size, Vector3(rng.randf_range(-0.6, 0.6) * size, rng.randf_range(0.0, 0.5) * size, rng.randf_range(-0.6, 0.6) * size), m, root)
		lump.scale = Vector3(1.0, rng.randf_range(0.5, 0.9), 1.0)
	for k in 3:
		var bx := _box(Vector3(0.4, 0.3, 0.35) * size, Vector3(rng.randf_range(-0.5, 0.5) * size, 0.5 * size, rng.randf_range(-0.5, 0.5) * size), mats[0], root)
		bx.rotation_degrees = Vector3(rng.randf_range(0, 40), rng.randf_range(0, 90), rng.randf_range(0, 40))
	mounds.append({"node": root, "th": th, "done": false})


# ============================================================
#  DÉCHETS
# ============================================================
func _make_trash_model(type_idx: int, rare: bool) -> Node3D:
	var root := Node3D.new()
	var model := Node3D.new()
	root.add_child(model)
	var shape: String = TRASH_TYPES[type_idx]["shape"]
	var gold := _mat(Color(1.0, 0.8, 0.2), 0.25)
	if rare:
		gold.emission_enabled = true
		gold.emission = Color(1.0, 0.7, 0.2)
		gold.emission_energy_multiplier = 1.2
	match shape:
		"bottle":
			var m: Material = gold if rare else _glass(Color(0.6, 0.85, 1.0, 0.55))
			var b := _cyl(0.12, 0.42, Vector3(0, 0.12, 0), m, model)
			b.rotation_degrees = Vector3(0, 0, 90)
			var cap := _cyl(0.05, 0.08, Vector3(0.25, 0.12, 0), _mat(Color(0.1, 0.35, 0.9)), model)
			cap.rotation_degrees = Vector3(0, 0, 90)
		"can":
			var c := _cyl(0.1, 0.24, Vector3(0, 0.1, 0), _mat(Color(0.85, 0.1, 0.12), 0.3), model)
			c.rotation_degrees = Vector3(0, 0, 90)
		"bag":
			var s := _sphere(0.24, Vector3(0, 0.16, 0), _mat(Color(0.95, 0.95, 0.92), 0.6), model)
			s.scale = Vector3(1.2, 0.7, 1.0)
		"paper":
			var p := _box(Vector3(0.46, 0.05, 0.34), Vector3(0, 0.04, 0), _mat(Color(0.82, 0.82, 0.78)), model)
			p.rotation_degrees = Vector3(0, 20, 6)
			_box(Vector3(0.3, 0.052, 0.04), Vector3(0, 0.05, -0.08), _mat(Color(0.2, 0.2, 0.2)), model)
		"box":
			_box(Vector3(0.42, 0.3, 0.36), Vector3(0, 0.15, 0), _mat(Color(0.62, 0.45, 0.28)), model)
		"jar":
			var m2: Material = gold if rare else _mat(Color(0.8, 0.15, 0.08), 0.2)
			_cyl(0.13, 0.26, Vector3(0, 0.13, 0), m2, model)
			_cyl(0.135, 0.05, Vector3(0, 0.28, 0), _mat(Color(0.85, 0.75, 0.3), 0.3), model)
		"glass":
			var g := _cyl(0.1, 0.4, Vector3(0, 0.1, 0), _glass(Color(0.15, 0.65, 0.3, 0.7)), model)
			g.rotation_degrees = Vector3(0, 0, 90)
			var neck := _cyl(0.04, 0.14, Vector3(0.26, 0.1, 0), _mat(Color(0.15, 0.6, 0.25), 0.1), model)
			neck.rotation_degrees = Vector3(0, 0, 90)
		"peel":
			for i in 3:
				var pe := _sphere(0.11, Vector3(rng.randf_range(-0.12, 0.12), 0.05, rng.randf_range(-0.12, 0.12)), _mat(Color(1.0, 0.55, 0.1)), model)
				pe.scale = Vector3(1.0, 0.35, 1.0)
		"dates":
			for i in 5:
				var dt := _capsule(0.04, 0.14, Vector3(rng.randf_range(-0.12, 0.12), 0.04, rng.randf_range(-0.12, 0.12)), _mat(Color(0.35, 0.18, 0.08), 0.4), model)
				dt.rotation_degrees = Vector3(90, rng.randf_range(0, 180), 0)
	# Petit halo au sol pour bien voir les déchets dans la ville grise
	var halo_m := _unshaded(Color(1, 1, 1, 0.35) if not rare else Color(1, 0.8, 0.3, 0.6))
	halo_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cyl(0.38, 0.01, Vector3(0, 0.01, 0), halo_m, root)
	return root


func _spawn_trash(type_idx: int, pos: Vector3, rare: bool = false, drop_from_sky: bool = false) -> void:
	var node := _make_trash_model(type_idx, rare)
	add_child(node)
	node.position = pos
	var item := {"node": node, "type": type_idx, "rare": rare, "ready_at": time_now, "phase": rng.randf() * TAU}
	if drop_from_sky:
		node.position = pos + Vector3(-6, 9, 0)
		item["ready_at"] = time_now + 0.9
		var tw := create_tween()
		tw.tween_property(node, "position", pos, 0.8).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	trash_items.append(item)


func _random_street_pos(zmin: float, zmax: float) -> Vector3:
	for attempt in 30:
		var p := Vector3(rng.randf_range(-STREET_HALF + 0.8, STREET_HALF - 0.8), 0.02, rng.randf_range(zmin, zmax))
		var ok: bool = true
		for b in bins:
			var bp: Vector3 = b["pos"]
			if Vector2(bp.x - p.x, bp.z - p.z).length() < 1.8:
				ok = false
				break
		if ok:
			return p
	return Vector3(0, 0.02, (zmin + zmax) * 0.5)


func _spawn_initial_trash() -> void:
	for i in START_TRASH:
		var z: float = lerpf(-3.0, -70.0, float(i) / float(START_TRASH - 1)) + rng.randf_range(-1.5, 1.5)
		_spawn_trash(rng.randi_range(0, 8), _random_street_pos(z - 1.0, z + 1.0))
	_spawn_trash(RARE_BOTTLE, _random_street_pos(-42.0, -38.0), true)
	_spawn_trash(RARE_JAR, _random_street_pos(-68.0, -64.0), true)


func _ensure_trash() -> void:
	var needed: int = GOAL - correct
	var available: int = trash_items.size() + stack.size()
	if available < mini(needed, 8):
		for i in 5:
			_spawn_trash(rng.randi_range(0, 8), _random_street_pos(-70.0, -3.0), false, true)


# ============================================================
#  JOUEUR & CAMÉRA
# ============================================================
func _spawn_player() -> void:
	player = PlayerScript.new()
	add_child(player)
	player.global_position = Vector3(0, 0.1, -1.0)
	player.visual.rotation.y = 0.0


func _process(delta: float) -> void:
	time_now += delta
	throw_cooldown = maxf(throw_cooldown - delta, 0.0)

	# Restauration progressive (la couleur revient en vague)
	restore_display = move_toward(restore_display, restore_target, delta * 0.22)
	_apply_restore(restore_display)
	sfx.update(restore_display, chehili_amount, player.global_position, delta)

	# Animation des déchets au sol
	for t in trash_items:
		if time_now < float(t["ready_at"]):
			continue
		var n: Node3D = t["node"]
		var model: Node3D = n.get_child(0)
		model.rotation.y += delta * 0.8
		model.position.y = 0.06 + sin(time_now * 2.5 + float(t["phase"])) * 0.05

	if playing:
		_try_pickup()
		_update_target_bin()
		chehili_timer -= delta
		if chehili_timer <= 0.0:
			chehili_timer = CHEHILI_EVERY
			_chehili()

	_update_camera(delta)
	_update_thread()

	# Bobine de Jedda : grossit avec le fil récolté
	if spool != null:
		var target_h: float = 1.0 + float(threads) * 0.35
		spool.scale.y = lerpf(spool.scale.y, target_h, delta * 4.0)
		spool.rotate_object_local(Vector3.UP, delta * 2.0)


func _update_camera(delta: float) -> void:
	shake = maxf(shake - delta * 2.5, 0.0)
	if cam_mode == Cam.FOLLOW:
		var target: Vector3 = player.global_position + cam_offset
		target.z = minf(target.z, STREET_START - 0.8)   # ne jamais entrer dans la maison du début
		camera.global_position = camera.global_position.lerp(target, 1.0 - exp(-4.0 * delta))
		camera.look_at(player.global_position + Vector3(0, 1.3, -3.5), Vector3.UP)
	else:
		camera.look_at(cine_look, Vector3.UP)
	camera.h_offset = rng.randf_range(-1.0, 1.0) * shake * 0.25
	camera.v_offset = rng.randf_range(-1.0, 1.0) * shake * 0.25


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("throw") and playing:
		_throw()
	if event.is_action_pressed("skip"):
		_skip_line = true
	if event.is_action_pressed("skip_all") and in_intro:
		_skip_all = true
	if event is InputEventMouseButton and event.is_pressed():
		_skip_line = true


# ============================================================
#  RAMASSER & LANCER
# ============================================================
func _try_pickup() -> void:
	if stack.size() >= MAX_STACK:
		return
	var pp: Vector3 = player.global_position
	for i in range(trash_items.size() - 1, -1, -1):
		var t: Dictionary = trash_items[i]
		if time_now < float(t["ready_at"]):
			continue
		var n: Node3D = t["node"]
		if Vector2(n.global_position.x - pp.x, n.global_position.z - pp.z).length() < 1.3:
			trash_items.remove_at(i)
			_add_to_stack(t)
			if stack.size() >= MAX_STACK:
				_banner("Ta pile est pleine ! Va trier au bon bac.", 2.0)
				break


func _add_to_stack(t: Dictionary) -> void:
	var n: Node3D = t["node"]
	var sr: Node3D = player.stack_root
	n.reparent(sr)
	var idx: int = stack.size()
	stack.append(t)
	var model: Node3D = n.get_child(0)
	model.position = Vector3.ZERO
	if n.get_child_count() > 1:
		var halo: Node3D = n.get_child(1)
		halo.visible = false   # cacher le halo
	var tw := create_tween()
	tw.tween_property(n, "position", Vector3(0, idx * 0.36, 0), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(n, "rotation", Vector3(0, rng.randf_range(-0.4, 0.4), 0), 0.25)
	tw.parallel().tween_property(n, "scale", Vector3(0.85, 0.85, 0.85), 0.25)
	sfx.pickup()
	_update_hud()
	if t["rare"]:
		_flashback(int(t["type"]))


func _nearest_bin(max_dist: float):
	var pp: Vector3 = player.global_position
	var best = null
	var best_d: float = max_dist
	for b in bins:
		var bp: Vector3 = b["pos"]
		var d: float = Vector2(bp.x - pp.x, bp.z - pp.z).length()
		if d < best_d:
			best_d = d
			best = b
	return best


## Le bac visé s'éclaire et le bouton dit où part le déchet
func _update_target_bin() -> void:
	var pp: Vector3 = player.global_position
	var best: int = -1
	var best_d: float = 2.8
	for i in bins.size():
		var bp: Vector3 = bins[i]["pos"]
		var d: float = Vector2(bp.x - pp.x, bp.z - pp.z).length()
		if d < best_d:
			best_d = d
			best = i
	if best != target_bin_idx:
		if target_bin_idx >= 0:
			var old_ring: Node3D = bins[target_bin_idx]["ring"]
			old_ring.visible = false
		target_bin_idx = best
		if best >= 0:
			var new_ring: Node3D = bins[best]["ring"]
			new_ring.visible = true
			btn_throw.text = "LANCER → " + String(CAT_SHORT[int(bins[best]["cat"])])
		else:
			btn_throw.text = "LANCER"
	if target_bin_idx >= 0:
		var r: Node3D = bins[target_bin_idx]["ring"]
		var k: float = 1.0 + 0.12 * sin(time_now * 8.0)
		r.scale = Vector3(k, 1.0, k)


func _arc(a: Vector3, b: Vector3, k: float, h: float) -> Vector3:
	return a.lerp(b, k) + Vector3(0, 4.0 * h * k * (1.0 - k), 0)


func _throw() -> void:
	if stack.is_empty() or throw_cooldown > 0.0:
		return
	var bin = _nearest_bin(2.8)
	if bin == null:
		_banner("Approche-toi d'un bac pour lancer !", 1.6)
		return
	throw_cooldown = 0.18
	var t: Dictionary = stack.pop_back()
	var n: Node3D = t["node"]
	n.reparent(self)
	var start: Vector3 = n.global_position
	var end_pos: Vector3 = bin["top"]
	sfx.whoosh()
	var tw := create_tween()
	tw.tween_method(func(k: float): n.global_position = _arc(start, end_pos, k, 1.4), 0.0, 1.0, 0.38)
	tw.parallel().tween_property(n, "rotation", n.rotation + Vector3(4, 2, 0), 0.38)
	tw.tween_callback(func(): _resolve_throw(t, bin))
	_update_hud()


func _resolve_throw(t: Dictionary, bin: Dictionary) -> void:
	var n: Node3D = t["node"]
	var tp: Dictionary = TRASH_TYPES[int(t["type"])]
	var top: Vector3 = bin["top"]
	if int(tp["cat"]) == int(bin["cat"]):
		n.queue_free()
		correct += 1
		combo += 1
		best_combo = maxi(best_combo, combo)
		var pts: int = 10 * mini(combo, 5)
		if t["rare"]:
			pts += 50
		score += pts
		if String(tp["shape"]) == "bottle":
			threads += 1
		_float_text("+%d" % pts, top + Vector3(0, 0.5, 0), Color(1, 0.88, 0.25))
		_burst(top, CAT_COLORS[int(bin["cat"])], 45)
		_burst(top, Color(1, 0.9, 0.4), 20)
		_bounce(bin["node"])
		_flash_light(top + Vector3(0, 0.6, 0), Color(1.0, 0.82, 0.4))
		sfx.good(combo, String(tp["shape"]))
		_combo_word()
		_set_restore(float(correct) / float(GOAL))
		_ensure_trash()
		_update_hud()
		if correct >= GOAL and not game_over:
			_finale()
	else:
		combo = 0
		sfx.bad()
		shake = 0.8
		_wobble(bin["node"])
		var out_dir: Vector3 = bin["out_dir"]
		var out: Vector3 = top + out_dir * 1.8 + Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.6, 0.6))
		out.y = 0.02
		t["ready_at"] = time_now + 1.2
		if n.get_child_count() > 1:
			var halo: Node3D = n.get_child(1)
			halo.visible = true
		var tw := create_tween()
		tw.tween_method(func(k: float): n.global_position = _arc(top, out, k, 1.0), 0.0, 1.0, 0.45)
		tw.parallel().tween_property(n, "scale", Vector3.ONE, 0.45)
		tw.parallel().tween_property(n, "rotation", Vector3.ZERO, 0.45)
		trash_items.append(t)
		_show_fact("Oups ! « %s » va dans le bac %s." % [tp["name"], CAT_NAMES[int(tp["cat"])]], String(tp["fact"]))
		_update_hud()


# ============================================================
#  RESTAURATION DES COULEURS
# ============================================================
func _set_restore(r: float) -> void:
	restore_target = clampf(r, 0.0, 1.0)
	var steps: Array = [[0.25, "Les portes bleues de Sidi Bou Saïd reviennent !"],
		[0.5, "Le jasmin et les bougainvilliers refleurissent !"],
		[0.75, "Les chats de Sidi Bou Saïd sont de retour !"]]
	for s in steps:
		var th: float = s[0]
		if restore_target >= th and not milestones_done.has(th):
			milestones_done.append(th)
			_banner(String(s[1]), 3.0)
			sfx.milestone()


func _apply_restore(r: float) -> void:
	for e in palette:
		var a: float = e["a"]
		var b: float = e["b"]
		var f: float = clampf((r - a) / (b - a), 0.0, 1.0)
		f = f * f * (3.0 - 2.0 * f)
		var g: Color = e["grey"]
		var c: Color = e["color"]
		var em: StandardMaterial3D = e["mat"]
		em.albedo_color = g.lerp(c, f)

	var ch: float = chehili_amount
	var sand_col := Color(0.8, 0.62, 0.38)
	sky_mat.sky_top_color = Color(0.5, 0.48, 0.45).lerp(Color(0.22, 0.48, 0.88), r).lerp(sand_col, ch * 0.7)
	sky_mat.sky_horizon_color = Color(0.62, 0.58, 0.53).lerp(Color(0.98, 0.82, 0.62), r).lerp(sand_col, ch * 0.8)
	sky_mat.ground_horizon_color = sky_mat.sky_horizon_color
	sky_mat.ground_bottom_color = Color(0.35, 0.33, 0.3).lerp(Color(0.45, 0.4, 0.35), r)
	sun.light_color = Color(0.85, 0.82, 0.78).lerp(Color(1.0, 0.84, 0.62), r)
	sun.light_energy = lerpf(1.0, 1.9, r)
	env.adjustment_saturation = lerpf(0.6, 1.15, r)
	env.adjustment_brightness = lerpf(0.94, 1.03, r)
	env.fog_light_color = Color(0.6, 0.57, 0.52).lerp(Color(0.98, 0.88, 0.75), r).lerp(sand_col, ch)
	env.fog_density = lerpf(0.014, 0.0018, r) + ch * 0.03

	var sea_f: float = clampf(r * 0.4 + sea_bonus, 0.0, 1.0)
	sea_mat.set_shader_parameter("water_color", Color(0.35, 0.33, 0.30).lerp(Color(0.05, 0.62, 0.85), sea_f))
	sea_mat.set_shader_parameter("deep_color", Color(0.25, 0.24, 0.22).lerp(Color(0.0, 0.25, 0.6), sea_f))
	lantern_mat.emission_energy_multiplier = clampf((r - 0.8) / 0.2, 0.0, 1.0) * 2.5

	# Les tas de déchets fondent
	for m in mounds:
		if not m["done"] and r >= float(m["th"]):
			m["done"] = true
			var node: Node3D = m["node"]
			_burst(node.global_position + Vector3(0, 0.5, 0), Color(0.6, 0.58, 0.55), 25)
			sfx.pop()
			var tw := create_tween()
			tw.tween_property(node, "scale", Vector3(0.01, 0.01, 0.01), 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			tw.tween_callback(node.hide)
	# Les fleurs et les chats apparaissent
	for bl in blooms:
		if not bl["done"] and r >= float(bl["th"]):
			bl["done"] = true
			var bn: Node3D = bl["node"]
			bn.visible = true
			if String(bl.get("kind", "flower")) == "cat":
				sfx.meow(bn.global_position + Vector3(0, 0.4, 0))
			var tw2 := create_tween()
			tw2.tween_property(bn, "scale", Vector3.ONE, 0.9).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


# ============================================================
#  LE FIL BLEU (guide, comme le vent de Ghost of Tsushima)
# ============================================================
func _build_thread() -> void:
	thread_mesh = ImmediateMesh.new()
	thread_mat = StandardMaterial3D.new()
	thread_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	thread_mat.vertex_color_use_as_albedo = true
	thread_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	thread_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.mesh = thread_mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _thread_target() -> Vector3:
	var pp: Vector3 = player.global_position
	if stack.size() >= MAX_STACK or (stack.size() > 0 and trash_items.is_empty()):
		var best: Vector3 = stations[0]
		for s in stations:
			var sv: Vector3 = s
			if sv.distance_to(pp) < best.distance_to(pp):
				best = sv
		return best + Vector3(0, 0.3, 0)
	var best_t: Vector3 = stations[0]
	var best_d: float = 99999.0
	for t in trash_items:
		if time_now < float(t["ready_at"]):
			continue
		var n: Node3D = t["node"]
		var d: float = n.global_position.distance_to(pp)
		if d < best_d:
			best_d = d
			best_t = n.global_position
	return best_t


func _update_thread() -> void:
	thread_mesh.clear_surfaces()
	var a: Vector3
	var b: Vector3
	if thread_mode == 1:
		a = loom_pos
		b = loom_pos.lerp(Vector3(0, -4.0, -260.0), thread_finale_k)
	elif playing:
		a = player.global_position + Vector3(0, 1.0, 0)
		b = _thread_target() + Vector3(0, 0.4, 0)
	else:
		return
	var length: float = a.distance_to(b)
	if length < 1.2:
		return
	var segs: int = clampi(int(length * 2.0), 8, 90)
	var lift: float = minf(length * 0.15, 3.0)
	var pts: Array = []
	for i in segs + 1:
		var k: float = float(i) / float(segs)
		var p: Vector3 = a.lerp(b, k)
		p.y += sin(k * PI) * lift
		p.x += sin(k * 12.0 - time_now * 4.0) * 0.18 * sin(k * PI)
		p.y += cos(k * 9.0 - time_now * 3.0) * 0.1 * sin(k * PI)
		pts.append(p)
	var cam_pos: Vector3 = camera.global_position
	var width: float = 0.07 if thread_mode == 0 else 0.25
	thread_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, thread_mat)
	for i in pts.size():
		var p: Vector3 = pts[i]
		var nxt: Vector3 = pts[mini(i + 1, pts.size() - 1)]
		var prv: Vector3 = pts[maxi(i - 1, 0)]
		var tangent: Vector3 = (nxt - prv).normalized()
		var view: Vector3 = (cam_pos - p).normalized()
		var side: Vector3 = tangent.cross(view).normalized() * width
		var k: float = float(i) / float(pts.size() - 1)
		var alpha: float = (0.55 + 0.45 * sin(k * 25.0 - time_now * 7.0)) * clampf(k * 6.0, 0.0, 1.0) * clampf((1.0 - k) * 6.0, 0.0, 1.0)
		var col := Color(0.25, 0.65, 1.0, alpha)
		thread_mesh.surface_set_color(col)
		thread_mesh.surface_add_vertex(p + side)
		thread_mesh.surface_set_color(col)
		thread_mesh.surface_add_vertex(p - side)
	thread_mesh.surface_end()


# ============================================================
#  LE CHEHILI (vent chaud du sud)
# ============================================================
func _chehili() -> void:
	_banner("Le Chehili se lève ! Le vent du sud ramène des déchets...", 3.0)
	sfx.wind()
	sand.emitting = true
	var tw := create_tween()
	tw.tween_property(self, "chehili_amount", 1.0, 1.2)
	await get_tree().create_timer(1.2).timeout
	if game_over:
		return
	shake = 0.6
	var pp: Vector3 = player.global_position
	for i in 5:
		var z: float = clampf(pp.z + rng.randf_range(-10.0, 6.0), -70.0, -2.0)
		_spawn_trash(rng.randi_range(0, 8), _random_street_pos(z - 1.0, z + 1.0), false, true)
	# Le vent arrache le déchet du haut de la pile
	if stack.size() >= 2:
		var t: Dictionary = stack.pop_back()
		var n: Node3D = t["node"]
		n.reparent(self)
		var start: Vector3 = n.global_position
		var land: Vector3 = _random_street_pos(pp.z - 3.0, pp.z + 1.0)
		t["ready_at"] = time_now + 1.0
		var tw2 := create_tween()
		tw2.tween_method(func(k: float): n.global_position = _arc(start, land, k, 2.0), 0.0, 1.0, 0.7)
		tw2.parallel().tween_property(n, "scale", Vector3.ONE, 0.7)
		trash_items.append(t)
		if n.get_child_count() > 1:
			var halo2: Node3D = n.get_child(1)
			halo2.visible = true
		_update_hud()
	await get_tree().create_timer(3.5).timeout
	sand.emitting = false
	var tw3 := create_tween()
	tw3.tween_property(self, "chehili_amount", 0.0, 2.0)


# ============================================================
#  EFFETS (particules, textes, rebonds)
# ============================================================
func _burst(pos: Vector3, col: Color, amount: int) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = 0.9
	var sm := SphereMesh.new()
	sm.radius = 0.06
	sm.height = 0.12
	sm.radial_segments = 6
	sm.rings = 3
	sm.material = _unshaded(Color(1, 1, 1))
	p.mesh = sm
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 6.5
	p.gravity = Vector3(0, -12, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	p.color = col
	p.position = pos
	add_child(p)
	p.emitting = true
	get_tree().create_timer(2.0).timeout.connect(p.queue_free)


func _float_text(text: String, pos: Vector3, col: Color) -> void:
	var l := _label3d(text, pos, 150, col)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.outline_size = 34
	l.outline_modulate = Color(0.85, 0.35, 0.05)
	l.scale = Vector3(0.3, 0.3, 0.3)
	var tw := create_tween()
	tw.tween_property(l, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position", pos + Vector3(0, 1.4, 0), 0.8)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.8).set_delay(0.25)
	tw.tween_callback(l.queue_free)


## Éclair de lumière dorée au-dessus du bac
func _flash_light(pos: Vector3, col: Color) -> void:
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = 7.0
	l.omni_range = 5.5
	l.position = pos
	add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "light_energy", 0.0, 0.7)
	tw.tween_callback(l.queue_free)


func _bounce(node: Node3D) -> void:
	node.scale = Vector3(1.15, 0.75, 1.15)
	var tw := create_tween()
	tw.tween_property(node, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _wobble(node: Node3D) -> void:
	var tw := create_tween()
	for i in 4:
		tw.tween_property(node, "rotation_degrees:y", 12.0 if i % 2 == 0 else -12.0, 0.06)
	tw.tween_property(node, "rotation_degrees:y", 0.0, 0.06)


func _combo_word() -> void:
	var word: String = ""
	for k in COMBO_WORDS.keys():
		if combo >= int(k):
			word = COMBO_WORDS[k]
	if word == "":
		return
	lbl_combo.text = word
	lbl_combo.modulate.a = 1.0
	lbl_combo.scale = Vector2(0.4, 0.4)
	var tw := create_tween()
	tw.tween_property(lbl_combo, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.6)
	tw.tween_property(lbl_combo, "modulate:a", 0.0, 0.4)


# ============================================================
#  INTERFACE
# ============================================================
func _style(bg: Color, radius: int = 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s


func _rect(c: Control, al: float, at: float, ar: float, ab: float, ol: float, ot: float, orr: float, ob: float) -> void:
	c.anchor_left = al
	c.anchor_top = at
	c.anchor_right = ar
	c.anchor_bottom = ab
	c.offset_left = ol
	c.offset_top = ot
	c.offset_right = orr
	c.offset_bottom = ob


func _ui_label(text: String, size: int, col: Color, parent: Control, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui_root = Control.new()
	_rect(ui_root, 0, 0, 1, 1, 0, 0, 0, 0)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font = ui_font
	theme.default_font_size = 22
	ui_root.theme = theme
	layer.add_child(ui_root)

	# Haut gauche : score + prochain déchet
	lbl_score = _ui_label("Score : 0", 30, Color(1, 1, 1), ui_root)
	_rect(lbl_score, 0, 0, 0, 0, 24, 14, 420, 54)
	lbl_combo_small = _ui_label("", 22, Color(1, 0.85, 0.3), ui_root)
	_rect(lbl_combo_small, 0, 0, 0, 0, 24, 52, 420, 82)
	lbl_next = _ui_label("", 22, Color(0.85, 0.95, 1.0), ui_root)
	_rect(lbl_next, 0, 0, 0, 0, 24, 84, 520, 114)

	# Haut centre : barre de couleur de la ville
	lbl_bar = _ui_label("Couleurs de Sidi Bou Saïd : 0 %", 20, Color(1, 1, 1), ui_root, HORIZONTAL_ALIGNMENT_CENTER)
	_rect(lbl_bar, 0.5, 0, 0.5, 0, -260, 10, 260, 38)
	bar = ProgressBar.new()
	bar.min_value = 0
	bar.max_value = GOAL
	bar.value = 0
	bar.show_percentage = false
	var bar_bg := _style(Color(0, 0, 0, 0.45), 10)
	var bar_fill := _style(Color(0.1, 0.55, 0.98), 10)
	for sb in [bar_bg, bar_fill]:
		sb.content_margin_left = 0
		sb.content_margin_right = 0
		sb.content_margin_top = 0
		sb.content_margin_bottom = 0
	bar.add_theme_stylebox_override("background", bar_bg)
	bar.add_theme_stylebox_override("fill", bar_fill)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(bar)
	_rect(bar, 0.5, 0, 0.5, 0, -230, 42, 230, 62)

	# Haut droite : fil bleu + pile
	lbl_thread = _ui_label("Fil bleu : 0", 26, Color(0.45, 0.75, 1.0), ui_root, HORIZONTAL_ALIGNMENT_RIGHT)
	_rect(lbl_thread, 1, 0, 1, 0, -340, 14, -24, 50)
	lbl_stack = _ui_label("Pile : 0/%d" % MAX_STACK, 22, Color(1, 1, 1), ui_root, HORIZONTAL_ALIGNMENT_RIGHT)
	_rect(lbl_stack, 1, 0, 1, 0, -340, 52, -24, 82)

	# Mot de combo en darija
	lbl_combo = _ui_label("", 68, Color(1, 0.85, 0.2), ui_root, HORIZONTAL_ALIGNMENT_CENTER)
	lbl_combo.add_theme_constant_override("outline_size", 16)
	_rect(lbl_combo, 0.5, 0.48, 0.5, 0.48, -400, -50, 400, 50)
	lbl_combo.pivot_offset = Vector2(400, 50)
	lbl_combo.modulate.a = 0.0

	# Bandeau d'annonce
	banner = _ui_label("", 30, Color(1, 1, 1), ui_root, HORIZONTAL_ALIGNMENT_CENTER)
	_rect(banner, 0, 0.36, 1, 0.36, 0, -24, 0, 24)
	banner.modulate.a = 0.0

	# Carte « le savais-tu ? » après une erreur
	fact_panel = PanelContainer.new()
	fact_panel.add_theme_stylebox_override("panel", _style(Color(0.08, 0.1, 0.18, 0.88)))
	fact_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(fact_panel)
	_rect(fact_panel, 0.5, 0, 0.5, 0, -380, 90, 380, 200)
	var fv := VBoxContainer.new()
	fact_panel.add_child(fv)
	fact_title = _ui_label("", 24, Color(1, 0.55, 0.45), fv)
	fact_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fact_text = _ui_label("", 21, Color(0.95, 0.95, 1.0), fv)
	fact_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fact_panel.visible = false

	# Boîte de dialogue
	say_panel = PanelContainer.new()
	say_panel.add_theme_stylebox_override("panel", _style(Color(0.05, 0.07, 0.12, 0.85)))
	say_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(say_panel)
	_rect(say_panel, 0, 1, 0, 1, 24, -175, 900, -30)
	var sv := VBoxContainer.new()
	say_panel.add_child(sv)
	say_name = _ui_label("", 24, Color(1, 0.82, 0.4), sv)
	say_text = _ui_label("", 24, Color(1, 1, 1), sv)
	say_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	say_panel.visible = false

	# Bouton LANCER
	btn_throw = Button.new()
	btn_throw.text = "LANCER"
	btn_throw.focus_mode = Control.FOCUS_NONE
	btn_throw.add_theme_font_size_override("font_size", 28)
	btn_throw.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	btn_throw.add_theme_stylebox_override("normal", _style(Color(1, 0.8, 0.15), 40))
	btn_throw.add_theme_stylebox_override("hover", _style(Color(1, 0.86, 0.3), 40))
	btn_throw.add_theme_stylebox_override("pressed", _style(Color(0.9, 0.65, 0.1), 40))
	ui_root.add_child(btn_throw)
	_rect(btn_throw, 1, 1, 1, 1, -330, -150, -36, -46)
	btn_throw.pressed.connect(_on_throw_pressed)
	var hint := _ui_label("Déplacer : ZQSD / flèches   •   Lancer : Espace", 16, Color(1, 1, 1, 0.7), ui_root, HORIZONTAL_ALIGNMENT_RIGHT)
	_rect(hint, 1, 1, 1, 1, -620, -36, -36, -10)
	btn_throw.visible = false

	# Titres (intro, fin)
	title_big = _ui_label("", 110, Color(1, 1, 1), ui_root, HORIZONTAL_ALIGNMENT_CENTER)
	title_big.add_theme_constant_override("outline_size", 18)
	_rect(title_big, 0, 0.32, 1, 0.32, 0, -80, 0, 80)
	title_sub = _ui_label("", 34, Color(0.9, 0.95, 1), ui_root, HORIZONTAL_ALIGNMENT_CENTER)
	_rect(title_sub, 0, 0.32, 1, 0.32, 0, 70, 0, 120)

	# Flashback sépia
	flash_rect = ColorRect.new()
	flash_rect.color = Color(0.32, 0.22, 0.1, 0.0)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(flash_rect)
	_rect(flash_rect, 0, 0, 1, 1, 0, 0, 0, 0)
	flash_text = _ui_label("", 32, Color(1, 0.95, 0.85), flash_rect, HORIZONTAL_ALIGNMENT_CENTER)
	flash_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	flash_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_rect(flash_text, 0.1, 0.2, 0.9, 0.8, 0, 0, 0, 0)
	flash_text.modulate.a = 0.0

	# Joystick tactile
	joystick = JoystickScript.new()
	ui_root.add_child(joystick)
	_rect(joystick, 0, 0, 1, 1, 0, 0, 0, 0)
	player.joystick = joystick


func _on_throw_pressed() -> void:
	if playing:
		_throw()


func _update_hud() -> void:
	lbl_score.text = "Score : %d" % score
	lbl_combo_small.text = ("Combo x%d" % combo) if combo >= 2 else ""
	lbl_thread.text = "Fil bleu : %d" % threads
	lbl_stack.text = "Pile : %d/%d" % [stack.size(), MAX_STACK]
	if stack.is_empty():
		lbl_next.text = "Ramasse les déchets !"
	else:
		var top: Dictionary = stack.back()
		lbl_next.text = "À lancer : " + String(TRASH_TYPES[int(top["type"])]["name"])
	var pct: int = int(round(float(correct) / float(GOAL) * 100.0))
	lbl_bar.text = "Couleurs de Sidi Bou Saïd : %d %%" % mini(pct, 100)
	var tw := create_tween()
	tw.tween_property(bar, "value", float(mini(correct, GOAL)), 0.3)


func _banner(text: String, dur: float) -> void:
	_banner_id += 1
	var my_id: int = _banner_id
	banner.text = text
	banner.modulate.a = 1.0
	await get_tree().create_timer(dur).timeout
	if my_id == _banner_id:
		var tw := create_tween()
		tw.tween_property(banner, "modulate:a", 0.0, 0.4)


func _show_fact(title: String, text: String) -> void:
	_fact_id += 1
	var my_id: int = _fact_id
	fact_title.text = title
	fact_text.text = "Le savais-tu ? " + text
	fact_panel.visible = true
	await get_tree().create_timer(4.0).timeout
	if my_id == _fact_id:
		fact_panel.visible = false


func _say(who: String, text: String) -> void:
	say_name.text = who
	say_text.text = text
	say_panel.visible = true


func _hide_say() -> void:
	say_panel.visible = false


func _wait(sec: float) -> void:
	var t: float = 0.0
	_skip_line = false
	while t < sec and not _skip_line and not _skip_all:
		await get_tree().process_frame
		t += get_process_delta_time()


# ============================================================
#  INTRO (bande-annonce dans le moteur)
# ============================================================
func _run_intro() -> void:
	in_intro = true
	playing = false
	player.input_enabled = false
	cam_mode = Cam.CINE
	camera.global_position = Vector3(10, 12, -125)
	cine_look = Vector3(0, 4, -62)
	_update_hud()
	var tw := create_tween()
	tw.tween_property(camera, "global_position", Vector3(7, 26, -40), 9.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(self, "cine_look", Vector3(0, 0, -18), 9.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	title_big.text = "2100"
	title_sub.text = "Sidi Bou Saïd, Tunisie"
	await _wait(3.5)
	title_big.text = ""
	title_sub.text = ""
	_say("Jedda Zohra", "Kén el bhar azra9, ya wlidi... Autrefois, la mer était bleue.")
	await _wait(4.0)
	_say("Yassine", "Personne ne te croit, Jedda. Mais moi, je vais le prouver !")
	await _wait(3.5)

	tw.kill()
	cam_mode = Cam.FOLLOW
	_skip_all = false
	in_intro = false
	playing = true
	player.input_enabled = true
	btn_throw.visible = true
	chehili_timer = CHEHILI_EVERY

	_say("Am Hédi, le barbech", "Ya Yassine ! Ramasse les déchets : ils s'empilent sur ton dos.")
	await _wait(3.5)
	_say("Am Hédi, le barbech", "Approche-toi du bon bac, puis appuie sur LANCER (Espace).")
	await _wait(3.5)
	_say("Am Hédi, le barbech", "Jaune : plastique & métal • Bleu : papier • Vert : verre • Marron : organique.")
	await _wait(5.0)
	_say("Am Hédi, le barbech", "Chaque bon geste rend ses couleurs à notre ville. Suis le fil bleu !")
	await _wait(3.5)
	_hide_say()


# ============================================================
#  FLASHBACK (objet rare)
# ============================================================
func _flashback(type_idx: int) -> void:
	var was_playing: bool = playing
	playing = false
	player.input_enabled = false
	flash_text.text = String(FLASHBACKS.get(type_idx, ""))
	var tw := create_tween()
	tw.tween_property(flash_rect, "color:a", 0.82, 0.5)
	tw.parallel().tween_property(flash_text, "modulate:a", 1.0, 0.8)
	sfx.flashback()
	await get_tree().create_timer(5.0).timeout
	var tw2 := create_tween()
	tw2.tween_property(flash_rect, "color:a", 0.0, 0.6)
	tw2.parallel().tween_property(flash_text, "modulate:a", 0.0, 0.4)
	if not game_over and was_playing:
		playing = true
		player.input_enabled = true


# ============================================================
#  FINALE
# ============================================================
func _finale() -> void:
	game_over = true
	playing = false
	player.input_enabled = false
	btn_throw.visible = false
	fact_panel.visible = false
	_set_restore(1.0)
	await get_tree().create_timer(0.8).timeout
	_banner("La ville a retrouvé ses couleurs !", 3.0)
	sfx.milestone()

	cam_mode = Cam.CINE
	cine_look = jedda_pos
	var tw := create_tween()
	tw.tween_property(camera, "global_position", Vector3(4.5, 4.0, -70.5), 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_say("Jedda Zohra", "Yassine... tu as tissé le fil bleu.")
	await get_tree().create_timer(3.2).timeout

	thread_mode = 1
	var tw2 := create_tween()
	tw2.tween_property(self, "thread_finale_k", 1.0, 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw2.parallel().tween_property(self, "cine_look", Vector3(0, -4, -200), 3.0)
	tw2.parallel().tween_property(camera, "global_position", Vector3(0, 14, -66), 4.0).set_trans(Tween.TRANS_SINE)
	tw2.tween_property(self, "sea_bonus", 1.0, 3.5)
	await get_tree().create_timer(3.0).timeout
	sfx.finale()
	await get_tree().create_timer(1.5).timeout
	_say("Jedda Zohra", "Chouf ya wlidi... el bhar azra9. La mer est bleue.")
	await get_tree().create_timer(4.5).timeout
	_hide_say()
	_show_end()


func _show_end() -> void:
	end_box = VBoxContainer.new()
	end_box.alignment = BoxContainer.ALIGNMENT_CENTER
	ui_root.add_child(end_box)
	_rect(end_box, 0.5, 0.5, 0.5, 0.5, -420, -230, 420, 230)
	var t1 := _ui_label("BLUE THREAD", 96, Color(1, 1, 1), end_box, HORIZONTAL_ALIGNMENT_CENTER)
	t1.add_theme_constant_override("outline_size", 18)
	_ui_label("الخيط الأزرق", 60, Color(0.45, 0.75, 1.0), end_box, HORIZONTAL_ALIGNMENT_CENTER)
	_ui_label("Score : %d    •    Meilleur combo : x%d" % [score, best_combo], 30, Color(1, 0.88, 0.3), end_box, HORIZONTAL_ALIGNMENT_CENTER)
	_ui_label("Chaque déchet bien trié rapproche la mer de son bleu.", 26, Color(1, 1, 1), end_box, HORIZONTAL_ALIGNMENT_CENTER)
	var again := Button.new()
	again.text = "Rejouer"
	again.focus_mode = Control.FOCUS_NONE
	again.add_theme_font_size_override("font_size", 30)
	again.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	again.add_theme_stylebox_override("normal", _style(Color(1, 0.8, 0.15), 30))
	again.add_theme_stylebox_override("hover", _style(Color(1, 0.86, 0.3), 30))
	again.custom_minimum_size = Vector2(240, 64)
	again.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	end_box.add_child(again)
	again.pressed.connect(func(): get_tree().reload_current_scene())
	end_box.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(end_box, "modulate:a", 1.0, 1.0)
