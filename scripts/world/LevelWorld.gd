extends Node3D
## ============================================================
##  LevelWorld — décor 3D d'un niveau + restauration progressive.
##  API (contrat avec Main / LevelController / RestorationPreview) :
##    configure_level(level_id)
##    set_local_restoration(percent)   0..100 (histoire)
##    set_ocean_progress(percent)      0..100 (valeur GLOBALE serveur : écume / mouettes au large)
##    height_at(x, z) / shore_z(x)
##  Les trois « skins » : Gabès (oasis + phosphogypse), Skhira (port,
##  textiles), Sidi Mansour (plage de bouteilles, marabout, flouka).
## ============================================================

const SEA_SHADER := preload("res://shaders/sea.gdshader")
const TERRAIN_SHADER := preload("res://shaders/terrain.gdshader")

var level_id: String = "gabes"
var phase: float = 0.0
var r: float = 0.0               # restauration affichée (0..1), lissée
var r_target: float = 0.0
var _rate: float = 1.6             # vitesse de lissage de la restauration
var _celebrate: bool = false       # fin de rivage : étincelles sur les plantes qui poussent
var _sparkles_live: int = 0
var global_ocean: float = 0.0    # 0..1 (serveur)
var desaturate: float = 0.0      # 0..1 : scène de mort (couleurs qui s'éteignent)
var camera: Camera3D = null      # donné par le contrôleur (pour le fond peint)

var env: Environment
var sky_mat: ProceduralSkyMaterial
var sun: DirectionalLight3D
var sea_mat: ShaderMaterial
var terrain_mat: ShaderMaterial
var matte: MeshInstance3D
var matte_mat: StandardMaterial3D
var _smokes: Array = []          # [CPUParticles3D, seuil]
var _dead_trees: Array = []
var _green: Array = []           # [Node3D, seuil, scale]
var _floating: Array = []        # [Node3D, base, phase, seuil]
var _gulls: Array = []
var _grass: MultiMeshInstance3D
var _grass_xf: Array = []
var _grass_r: float = -1.0
var _dust: CPUParticles3D
var _dust_mat: StandardMaterial3D
var _t: float = 0.0
var _noise := FastNoiseLite.new()
var _rng := RandomNumberGenerator.new()
var _tint: Dictionary = {}
## Téléphone (navigateur Android / iOS) : version allégée pour garder un bon framerate.
var _applied_r: float = -1.0
var _applied_desat: float = 0.0
var low_end: bool = OS.has_feature("web_android") or OS.has_feature("web_ios") or OS.has_feature("mobile")
## Version navigateur (itch.io) : rendu allégé pour rester fluide sur un
## portable de jury (pas de glow, ombres en une seule passe, mer moins dense).
var web: bool = OS.has_feature("web")

const TINTS := {
	"gabes": {"sky_top": Color(0.33, 0.27, 0.24), "sky_hor": Color(0.86, 0.58, 0.34), "fog": Color(0.66, 0.48, 0.32),
		"sun": Color(1.0, 0.62, 0.34), "sand": Color(0.56, 0.50, 0.43), "wet": Color(0.30, 0.27, 0.23), "pol": Color(0.47, 0.47, 0.46)},
	"skhira": {"sky_top": Color(0.27, 0.24, 0.30), "sky_hor": Color(0.78, 0.55, 0.50), "fog": Color(0.56, 0.46, 0.48),
		"sun": Color(1.0, 0.66, 0.48), "sand": Color(0.64, 0.54, 0.42), "wet": Color(0.33, 0.28, 0.22), "pol": Color(0.18, 0.17, 0.18)},
	"sidi_mansour": {"sky_top": Color(0.38, 0.34, 0.26), "sky_hor": Color(0.90, 0.72, 0.44), "fog": Color(0.74, 0.62, 0.44),
		"sun": Color(1.0, 0.78, 0.50), "sand": Color(0.66, 0.55, 0.40), "wet": Color(0.42, 0.34, 0.24), "pol": Color(0.26, 0.24, 0.22)},
}


func configure_level(id: String) -> void:
	level_id = id if TINTS.has(id) else "gabes"
	_tint = TINTS[level_id]
	phase = {"gabes": 0.0, "skhira": 1.7, "sidi_mansour": 3.4}[level_id]
	_rng.seed = hash(level_id)
	_noise.seed = hash(level_id) % 1000
	_noise.frequency = 0.045
	for c in get_children():
		c.queue_free()
	_smokes.clear(); _dead_trees.clear(); _green.clear(); _floating.clear(); _gulls.clear(); _grass_xf.clear()
	_build_environment()
	_build_terrain()
	_build_sea()
	_build_matte()
	_build_far_industry()
	_build_common_props()
	match level_id:
		"gabes": _build_gabes()
		"skhira": _build_skhira()
		"sidi_mansour": _build_sidi_mansour()
	_build_vegetation()
	_build_floating_trash()
	_build_gulls()
	_build_dust()
	_apply(true)


func set_local_restoration(percent: float) -> void:
	r_target = clampf(percent / 100.0, 0.0, 1.0)


func set_restoration_immediate(percent: float) -> void:
	r_target = clampf(percent / 100.0, 0.0, 1.0)
	r = r_target
	_apply(true)


## Valeur globale (serveur) : n'agit que sur le large, jamais sur l'histoire locale.
func set_ocean_progress(percent: float) -> void:
	global_ocean = clampf(percent / 100.0, 0.0, 1.0)


# ================================================================== terrain
func shore_z(x: float) -> float:
	return -1.5 + 2.2 * sin(x * 0.06 + phase) + 1.0 * sin(x * 0.17)


func height_at(x: float, z: float) -> float:
	var d: float = z - shore_z(x)
	if d < 0.0:
		return maxf(d * 0.16, -4.0)
	var dune: float = _noise.get_noise_2d(x, z) * (0.35 + 0.9 * smoothstep(6.0, 30.0, d))
	return d * 0.055 + smoothstep(16.0, 44.0, d) * 3.2 + dune * smoothstep(0.0, 5.0, d)


func _build_terrain() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := 1.25
	var nx := 116
	var nz := 64
	var x0 := -72.0
	var z0 := -26.0
	var pn := FastNoiseLite.new()
	pn.seed = 77 + int(phase * 10.0)
	pn.frequency = 0.08
	for iz in nz:
		for ix in nx:
			var x: float = x0 + ix * step
			var z: float = z0 + iz * step
			var d: float = z - shore_z(x)
			var wet: float = 1.0 - smoothstep(-0.5, 3.0, d)
			var grass: float = smoothstep(5.0, 12.0, d) * smoothstep(-0.1, 0.35, pn.get_noise_2d(x * 0.7, z * 0.7))
			var pol: float = smoothstep(-0.05, 0.3, pn.get_noise_2d(x + 300.0, z)) * (0.55 + 0.45 * (1.0 - smoothstep(4.0, 20.0, d)))
			st.set_color(Color(wet, grass, pol))
			st.set_uv(Vector2(x, z) * 0.1)
			st.add_vertex(Vector3(x, height_at(x, z), z))
	for iz in nz - 1:
		for ix in nx - 1:
			var a := iz * nx + ix
			var b := a + 1
			var c := a + nx
			var dd := c + 1
			st.add_index(a); st.add_index(b); st.add_index(dd)
			st.add_index(a); st.add_index(dd); st.add_index(c)
	st.generate_normals()
	var mesh: ArrayMesh = st.commit()
	terrain_mat = ShaderMaterial.new()
	terrain_mat.shader = TERRAIN_SHADER
	terrain_mat.set_shader_parameter("sand_col", _tint.sand)
	terrain_mat.set_shader_parameter("wet_col", _tint.wet)
	terrain_mat.set_shader_parameter("pol_col", _tint.pol)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = terrain_mat
	add_child(mi)
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	col.shape = mesh.create_trimesh_shape()
	body.add_child(col)
	add_child(body)


func _build_sea() -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(460, 240)
	pm.subdivide_width = 90 if (web or low_end) else 150
	pm.subdivide_depth = 48 if (web or low_end) else 80
	sea_mat = ShaderMaterial.new()
	sea_mat.shader = SEA_SHADER
	sea_mat.set_shader_parameter("phase", phase)
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = sea_mat
	mi.position = Vector3(0, -0.05, -112)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


# ================================================================== ambiance
func _build_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sun_angle_max = 25.0
	sky_mat.sun_curve = 0.08
	var sky := Sky.new()
	sky.sky_material = sky_mat
	# le ciel ne sert qu'à l'éclairage ambiant : petite carte = mises à jour bon marché
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.85
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.glow_enabled = not (low_end or web)
	env.glow_intensity = 0.45
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.15
	env.fog_enabled = true
	env.fog_sky_affect = 0.2
	env.adjustment_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	# navigateur : pas d'ombres temps réel (elles doublaient le dessin de la
	# scène) ; les personnages ont une ombre ronde à la place (Mats.blob)
	sun.shadow_enabled = not (low_end or web)
	# 4 passes d'ombre par défaut : on passe à 1 (web) ou 2 (bureau)
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL if web else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 34.0 if web else 45.0
	# soleil bas, face à la caméra (contre-jour doré comme les images de référence)
	sun.rotation_degrees = Vector3(-14, 145.0 if level_id == "skhira" else -145.0, 0)
	add_child(sun)
	# lumière de remplissage douce depuis la caméra (lisibilité du personnage)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25, 15, 0)
	fill.light_energy = 0.35
	fill.light_color = Color(0.7, 0.8, 1.0)
	add_child(fill)


func _build_matte() -> void:
	var lv: Dictionary = GameData.level(level_id)
	var tex: Texture2D = load(String(lv.get("matte", "res://assets/ui/matte_gabes.png")))
	matte_mat = Mats.unshaded(Color(1, 1, 1, 1), false, tex)
	matte_mat.set("disable_fog", true)
	matte_mat.render_priority = -10
	matte_mat.no_depth_test = false
	var q := QuadMesh.new()
	var w := 540.0
	q.size = Vector2(w, w * float(tex.get_height()) / float(tex.get_width()))
	matte = MeshInstance3D.new()
	matte.mesh = q
	matte.material_override = matte_mat
	matte.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	matte.position = Vector3(0, q.size.y * 0.5 - 18.0, -205)
	add_child(matte)


func _smoke(pos: Vector3, scale_f: float, threshold: float, col: Color = Color(0.16, 0.14, 0.13)) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/icons/smoke.png")
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.disable_receive_shadows = true
	q.material = m
	p.mesh = q
	p.amount = 10 if (low_end or web) else 22
	p.lifetime = 10.0
	p.preprocess = 10.0
	p.direction = Vector3(0.25, 1, 0)
	p.spread = 10.0
	p.initial_velocity_min = 1.6 * scale_f
	p.initial_velocity_max = 2.6 * scale_f
	p.gravity = Vector3(0.45, 0.12, 0.1) * scale_f
	p.scale_amount_min = 3.0 * scale_f
	p.scale_amount_max = 5.0 * scale_f
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.35))
	curve.add_point(Vector2(1, 1.6))
	p.scale_amount_curve = curve
	p.angle_min = 0.0
	p.angle_max = 360.0
	var g := Gradient.new()
	g.set_color(0, Color(col.r, col.g, col.b, 0.0))
	g.set_color(1, Color(col.r * 1.4, col.g * 1.4, col.b * 1.4, 0.0))
	g.add_point(0.12, Color(col.r, col.g, col.b, 0.85))
	g.add_point(0.6, Color(col.r * 1.2, col.g * 1.2, col.b * 1.2, 0.45))
	p.color_ramp = g
	p.position = pos
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	_smokes.append([p, threshold])
	return p


func _chimney(pos: Vector3, h: float, rad: float, threshold: float, parent: Node3D = null) -> void:
	if parent == null:
		parent = self
	var red := Mats.mat(Color(0.62, 0.20, 0.14), 0.85)
	var white := Mats.mat(Color(0.82, 0.78, 0.72), 0.85)
	var bands := 6
	for i in bands:
		var bh: float = h / bands
		var rr: float = rad * (1.0 - 0.18 * float(i) / bands)
		Mats.mi(Mats.cyl(rr * 0.97, rr, bh, 16), red if i % 2 == 0 else white, pos + Vector3(0, bh * (i + 0.5), 0), parent)
	_smoke(pos + Vector3(0, h + 1.0, 0), rad * 1.2, threshold)


func _build_far_industry() -> void:
	var rust := Mats.mat(Color(0.42, 0.28, 0.20), 0.9, 0.3)
	var steel := Mats.mat(Color(0.40, 0.38, 0.36), 0.7, 0.5)
	var side: float = -1.0 if level_id != "skhira" else 1.0
	var base := Vector3(-58.0 * side, 0, -46.0)
	var ind := Node3D.new()
	ind.name = "FarIndustry"
	add_child(ind)
	# jetée + complexe chimique
	Mats.mi(Mats.box(Vector3(46, 2.2, 22)), Mats.mat(Color(0.36, 0.32, 0.28), 0.95), base + Vector3(0, 0.6, 0), ind)
	_chimney(base + Vector3(-8, 1.7, -4), 26.0, 1.3, 0.55, ind)
	_chimney(base + Vector3(-3, 1.7, -6), 22.0, 1.1, 0.75, ind)
	_chimney(base + Vector3(10, 1.7, 2), 18.0, 1.0, 0.9, ind)
	for k in 5:
		var tp := base + Vector3(-14 + k * 6.5, 1.7, 4 + (k % 2) * 3)
		var th: float = 7.0 + (k * 3 % 5)
		Mats.mi(Mats.cyl(1.4, 1.5, th, 14), rust if k % 2 else steel, tp + Vector3(0, th * 0.5, 0), ind)
		Mats.mi(Mats.sphere(1.5, 1.4), steel, tp + Vector3(0, th, 0), ind)
		Mats.mi(Mats.cyl(0.25, 0.25, th + 3, 8), rust, tp + Vector3(1.6, (th + 3) * 0.5, 0), ind)
	Mats.mi(Mats.box(Vector3(30, 0.5, 0.5)), rust, base + Vector3(0, 8.5, 6), ind)
	Mats.mi(Mats.box(Vector3(30, 0.5, 0.5)), rust, base + Vector3(0, 5.5, 8), ind)
	# promontoire opposé (collines) pour fermer la baie
	var hill := Mats.mat(Color(0.48, 0.40, 0.32), 0.95)
	for k in 6:
		Mats.mi(Mats.rock(1.0, 400 + k, 0.45), hill, Vector3(60.0 * side + k * 9.0 * side, -1.0, -70.0 - k * 6.0), ind, Vector3(0, k * 40, 0), Vector3(14, 9 + k, 12))
	Mats.merge(ind)


func _build_dust() -> void:
	_dust = CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.08, 0.08)
	_dust_mat = Mats.unshaded(Color(0.85, 0.7, 0.5, 0.55), false, load("res://assets/icons/glow.png"))
	_dust_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	q.material = _dust_mat
	_dust.mesh = q
	_dust.amount = 35 if (low_end or web) else 90
	_dust.lifetime = 8.0
	_dust.preprocess = 8.0
	_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_dust.emission_box_extents = Vector3(14, 4, 12)
	_dust.direction = Vector3(1, 0.1, 0)
	_dust.spread = 40.0
	_dust.initial_velocity_min = 0.3
	_dust.initial_velocity_max = 0.9
	_dust.gravity = Vector3.ZERO
	_dust.position = Vector3(0, 2.5, 6)
	add_child(_dust)


# ================================================================== props
func _place(n: Node3D, x: float, z: float, yoff: float = 0.0) -> Node3D:
	n.position = Vector3(x, height_at(x, z) + yoff, z)
	add_child(n)
	return n


func _barrel(x: float, z: float, tipped: bool) -> void:
	var n := Node3D.new()
	var rust := Mats.mat(Color(0.48, 0.24, 0.13), 0.9, 0.4)
	var rust2 := Mats.mat(Color(0.33, 0.17, 0.10), 0.9, 0.4)
	Mats.mi(Mats.cyl(0.42, 0.42, 1.2, 18), rust, Vector3(0, 0.6, 0), n)
	for y in [0.15, 0.6, 1.05]:
		Mats.mi(Mats.cyl(0.435, 0.435, 0.06, 18), rust2, Vector3(0, y, 0), n)
	Mats.merge(n)
	if tipped:
		n.rotation_degrees = Vector3(90, _rng.randf_range(0, 360), 0)
		_place(n, x, z, 0.4)
	else:
		n.rotation_degrees.y = _rng.randf_range(0, 360)
		_place(n, x, z, -0.05)


## Obstacles PHYSIQUES (StaticBody3D + collision simple) : le joueur s'arrête,
## glisse le long ou contourne. Placés loin des points importants.
func add_obstacles(keep_clear: Array) -> void:
	var placed: Array = []
	var tries := 0
	var n_barrels := 0
	while n_barrels < 12 and tries < 400:
		tries += 1
		var x := _rng.randf_range(-36, 36)
		var z := shore_z(x) + _rng.randf_range(1.5, 20.0)
		var p := Vector3(x, 0, z)
		var ok := true
		# une branche (jusqu'à 4,4 m) dépasse de son centre : marge plus grande
		var clear_r: float = 3.6
		for k in keep_clear:
			var kp: Vector3 = k
			if Vector2(kp.x - x, kp.z - z).length() < clear_r:
				ok = false
				break
		# couloir libre entre le départ et la station de tri
		if absf(x) < 3.5 and z > 2.0 and z < 16.0:
			ok = false
		for q in placed:
			var qp: Vector3 = q
			if Vector2(qp.x - x, qp.z - z).length() < 4.2:
				ok = false
				break
		if not ok:
			continue
		placed.append(p)
		_physical_barrel(x, z, n_barrels % 3 == 2)
		n_barrels += 1


func _physical_barrel(x: float, z: float, tipped: bool) -> void:
	var body := StaticBody3D.new()
	body.name = "Barrel"
	var vis := Node3D.new()
	body.add_child(vis)
	var rust := Mats.mat(Color(0.48, 0.24, 0.13), 0.9, 0.4)
	var rust2 := Mats.mat(Color(0.33, 0.17, 0.10), 0.9, 0.4)
	Mats.mi(Mats.cyl(0.42, 0.42, 1.2, 18), rust, Vector3(0, 0.6, 0), vis)
	for y in [0.15, 0.6, 1.05]:
		Mats.mi(Mats.cyl(0.435, 0.435, 0.06, 18), rust2, Vector3(0, y, 0), vis)
	Mats.merge(vis)
	var col := CollisionShape3D.new()
	var cs := CylinderShape3D.new()
	cs.radius = 0.44
	cs.height = 1.2
	col.shape = cs
	col.position = Vector3(0, 0.6, 0)
	body.add_child(col)
	if tipped:
		var yaw := _rng.randf_range(0, 360)
		vis.rotation_degrees = Vector3(90, 0, 0)
		vis.position = Vector3(0, 0.42, -0.6)
		col.rotation_degrees = Vector3(90, 0, 0)
		col.position = Vector3(0, 0.42, 0)
		body.rotation_degrees.y = yaw
	else:
		body.rotation_degrees.y = _rng.randf_range(0, 360)
	_place(body, x, z, -0.05)


func _rock(x: float, z: float, s: float) -> void:
	var m := Mats.mat(Color(0.34, 0.31, 0.28).lerp(Color(_tint.sand), 0.25), 0.9)
	var n := Mats.mi(Mats.rock(1.0, _rng.randi_range(1, 30), 0.65), m, Vector3.ZERO, self, Vector3(0, _rng.randf_range(0, 360), 0), Vector3(s, s, s) * _rng.randf_range(0.8, 1.2))
	n.position = Vector3(x, height_at(x, z) - s * 0.15, z)


func _net(x: float, z: float) -> void:
	var m := Mats.mat(Color(0.22, 0.42, 0.36, 0.92), 0.95)
	var n := Node3D.new()
	for k in 5:
		Mats.mi(Mats.sphere(0.6), m, Vector3(k * 0.45 - 0.9, 0.05, sin(k * 1.3) * 0.4), n, Vector3.ZERO, Vector3(1.2, 0.18, 0.9))
	Mats.mi(Mats.sphere(0.12), Mats.mat(Color(0.95, 0.55, 0.15), 0.5), Vector3(0.9, 0.15, 0.3), n)
	Mats.merge(n, false)
	n.rotation_degrees.y = _rng.randf_range(0, 360)
	_place(n, x, z, 0.0)


func _tire(x: float, z: float) -> void:
	var n := Mats.mi(Mats.torus(0.25, 0.48), Mats.mat(Color(0.08, 0.08, 0.08), 0.85), Vector3.ZERO, self, Vector3(_rng.randf_range(-20, 20), 0, 0))
	n.position = Vector3(x, height_at(x, z) + 0.1, z)


func _dead_tree(x: float, z: float, threshold: float) -> void:
	var m := Mats.mat(Color(0.25, 0.20, 0.16), 0.95)
	var n := Node3D.new()
	var h := _rng.randf_range(3.0, 4.6)
	Mats.mi(Mats.cyl(0.08, 0.2, h, 8), m, Vector3(0, h * 0.5, 0), n)
	for k in 5:
		var br := Node3D.new()
		br.position = Vector3(0, h * (0.45 + k * 0.11), 0)
		br.rotation_degrees = Vector3(_rng.randf_range(35, 60), k * 72 + _rng.randf_range(-15, 15), 0)
		var bl := _rng.randf_range(0.9, 1.6)
		Mats.mi(Mats.cyl(0.02, 0.06, bl, 6), m, Vector3(0, bl * 0.5, 0), br)
		n.add_child(br)
	Mats.merge(n)
	_place(n, x, z, -0.1)
	_dead_trees.append([n, threshold])


func _palm(x: float, z: float, threshold: float) -> void:
	var trunk_m := Mats.mat(Color(0.48, 0.38, 0.27), 0.9)
	var frond_m := Mats.mat(Color(0.16, 0.56, 0.16), 0.7, 0.0, 0.25)
	var n := Node3D.new()
	var h := _rng.randf_range(4.5, 6.5)
	var lean := _rng.randf_range(-8, 8)
	var tr := Node3D.new()
	tr.rotation_degrees = Vector3(lean, 0, lean * 0.6)
	n.add_child(tr)
	var segs := 8
	for i in segs:
		Mats.mi(Mats.cyl(0.16 - i * 0.006, 0.19 - i * 0.006, h / segs * 1.02, 10), trunk_m, Vector3(0, h / segs * (i + 0.5), 0), tr)
	var crown := Node3D.new()
	crown.position = Vector3(0, h, 0)
	tr.add_child(crown)
	for k in 9:
		var f := Node3D.new()
		f.rotation_degrees = Vector3(0, k * 40.0 + _rng.randf_range(-8, 8), 0)
		crown.add_child(f)
		var arc := Node3D.new()
		arc.rotation_degrees = Vector3(-_rng.randf_range(15, 35), 0, 0)
		f.add_child(arc)
		for s in 4:
			Mats.mi(Mats.box(Vector3(0.55 - s * 0.1, 0.03, 0.75)), frond_m, Vector3(0, -s * s * 0.06, -0.35 - s * 0.68), arc, Vector3(-s * 10, 0, 0))
	Mats.mi(Mats.sphere(0.28), Mats.mat(Color(0.55, 0.32, 0.12), 0.7), Vector3(0, -0.15, 0), crown)
	Mats.merge(n)
	_place(n, x, z, -0.1)
	n.scale = Vector3.ONE * 0.01
	_green.append([n, threshold, _rng.randf_range(0.85, 1.15)])


func _olive(x: float, z: float, threshold: float) -> void:
	var trunk_m := Mats.mat(Color(0.40, 0.34, 0.27), 0.95)
	var leaf_m := Mats.mat(Color(0.30, 0.58, 0.24), 0.8, 0.0, 0.25)
	var n := Node3D.new()
	Mats.mi(Mats.cyl(0.16, 0.26, 1.6, 9), trunk_m, Vector3(0, 0.8, 0), n, Vector3(0, 0, 6))
	for k in 6:
		var a := k * 1.05
		Mats.mi(Mats.sphere(0.85), leaf_m, Vector3(cos(a) * 0.8, 2.0 + (k % 3) * 0.35, sin(a) * 0.8), n, Vector3.ZERO, Vector3(1, 0.7, 1))
	Mats.mi(Mats.sphere(1.0), leaf_m, Vector3(0, 2.5, 0), n, Vector3.ZERO, Vector3(1, 0.7, 1))
	Mats.merge(n)
	_place(n, x, z, -0.1)
	n.scale = Vector3.ONE * 0.01
	_green.append([n, threshold, _rng.randf_range(0.85, 1.2)])


## Buisson : grappe de boules de feuillage, plusieurs verts
func _shrub(x: float, z: float, threshold: float) -> void:
	var greens := [Color(0.18, 0.52, 0.16), Color(0.26, 0.60, 0.20), Color(0.34, 0.62, 0.22), Color(0.14, 0.46, 0.22)]
	var m := Mats.mat(greens[_rng.randi_range(0, greens.size() - 1)], 0.85, 0.0, 0.2)
	var n := Node3D.new()
	var count := _rng.randi_range(3, 5)
	for k in count:
		var a: float = TAU * k / count + _rng.randf_range(-0.3, 0.3)
		var rr: float = _rng.randf_range(0.28, 0.48)
		Mats.mi(Mats.sphere(rr, -1.0, 12), m, Vector3(cos(a) * 0.32, rr * 0.8, sin(a) * 0.32), n, Vector3.ZERO, Vector3(1, 0.85, 1))
	Mats.mi(Mats.sphere(0.42, -1.0, 12), m, Vector3(0, 0.55, 0), n)
	Mats.merge(n)
	_place(n, x, z, -0.05)
	n.scale = Vector3.ONE * 0.01
	_green.append([n, threshold, _rng.randf_range(0.8, 1.3)])


## Petites fleurs (tiges + corolles) qui sortent du sol à la fin
func _flowers(x: float, z: float, threshold: float) -> void:
	var cols := [Color(0.95, 0.85, 0.20), Color(0.95, 0.40, 0.55), Color(0.70, 0.45, 0.95), Color(0.98, 0.98, 0.95), Color(0.98, 0.55, 0.20)]
	var stem := Mats.mat(Color(0.22, 0.55, 0.18), 0.8)
	var head := Mats.mat(cols[_rng.randi_range(0, cols.size() - 1)], 0.6, 0.0, 0.3)
	var n := Node3D.new()
	for k in _rng.randi_range(3, 4):
		var off := Vector3(_rng.randf_range(-0.3, 0.3), 0, _rng.randf_range(-0.3, 0.3))
		var h: float = _rng.randf_range(0.22, 0.4)
		Mats.mi(Mats.cyl(0.012, 0.016, h, 5), stem, off + Vector3(0, h * 0.5, 0), n)
		Mats.mi(Mats.sphere(0.055, -1.0, 8), head, off + Vector3(0, h + 0.02, 0), n, Vector3.ZERO, Vector3(1, 0.55, 1))
	Mats.merge(n, false)
	_place(n, x, z, -0.02)
	n.scale = Vector3.ONE * 0.01
	_green.append([n, threshold, _rng.randf_range(0.9, 1.4)])


## Fin de rivage : la restauration se joue lentement (plantes en décalé,
## étincelles quand une plante sort de terre).
func play_restoration(percent: float) -> void:
	_rate = 0.42
	_celebrate = true
	set_local_restoration(percent)


func _sparkle(pos: Vector3) -> void:
	if _sparkles_live > 14:
		return
	_sparkles_live += 1
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.12, 0.12)
	var pm := Mats.unshaded(Color(0.7, 1.0, 0.6, 0.9), true)
	pm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	q.material = pm
	p.mesh = q
	p.amount = 10
	p.one_shot = true
	p.explosiveness = 0.85
	p.lifetime = 1.2
	p.direction = Vector3.UP
	p.spread = 60.0
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 1.8
	p.gravity = Vector3(0, -0.6, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	add_child(p)
	p.global_position = pos + Vector3(0, 0.5, 0)
	p.emitting = true
	get_tree().create_timer(1.6).timeout.connect(func():
		_sparkles_live -= 1
		p.queue_free())


func _build_common_props() -> void:
	for i in 14:
		var x := _rng.randf_range(-44, 44)
		var z := shore_z(x) + _rng.randf_range(-1.0, 18.0)
		if absf(x) < 7.0 and z > 2.0 and z < 15.0:
			continue
		_rock(x, z, _rng.randf_range(0.5, 1.4))
	# (bois flottés retirés : ils ressemblaient aux branches tombées supprimées)
	for i in 3:
		var x := _rng.randf_range(-35, 35)
		_net(x, shore_z(x) + _rng.randf_range(0.5, 6.0))
	for i in 4:
		var x := _rng.randf_range(-40, 40)
		_tire(x, shore_z(x) + _rng.randf_range(1.0, 12.0))
	for i in 7:
		var x := _rng.randf_range(-42, 42)
		_dead_tree(x, shore_z(x) + _rng.randf_range(12.0, 26.0), 0.35 + i * 0.06)
	# buissons et fleurs : ils repoussent avec la restauration (seuils étalés)
	for i in (8 if low_end else 16):
		var x := _rng.randf_range(-40, 40)
		var z := shore_z(x) + _rng.randf_range(7.0, 26.0)
		if absf(x) < 6.0 and z < 15.0:
			continue
		_shrub(x, z, _rng.randf_range(0.28, 0.95))
	for i in (6 if low_end else 16):
		var x := _rng.randf_range(-38, 38)
		var z := shore_z(x) + _rng.randf_range(6.0, 24.0)
		if absf(x) < 5.0 and z < 15.0:
			continue
		_flowers(x, z, _rng.randf_range(0.5, 0.98))


func _build_gabes() -> void:
	# Phosphogypse : tas gris + conduite de rejet qui crache dans la mer
	var gyps := Mats.mat(Color(0.62, 0.62, 0.60), 0.95)
	for k in 4:
		Mats.mi(Mats.rock(1.0, 200 + k, 0.4), gyps, Vector3(-30 + k * 5.0, height_at(-30 + k * 5.0, 24) - 0.5, 24 + k), self, Vector3(0, k * 50, 0), Vector3(5 + k, 3.2, 4.5))
	var pipe_m := Mats.mat(Color(0.38, 0.22, 0.14), 0.85, 0.4)
	var px := 22.0
	var pts := PackedVector3Array()
	for i in 10:
		var z := 16.0 - i * 3.2
		pts.append(Vector3(px, maxf(height_at(px, z), -0.6) + 0.55, z))
	Mats.mi(Mats.tube(pts, 0.55, 14), pipe_m, Vector3.ZERO, self)
	var outflow := _smoke(pts[pts.size() - 1] + Vector3(0, 0.3, -0.6), 0.5, 0.5, Color(0.28, 0.24, 0.16))
	outflow.direction = Vector3(0, 0.3, -1)
	outflow.gravity = Vector3(0, -1.5, -0.5)
	# oasis : palmiers qui reverdissent (maisons blanches retirées)
	for i in 12:
		var x := -36.0 + i * 6.5 + _rng.randf_range(-2, 2)
		_palm(x, shore_z(x) + _rng.randf_range(14.0, 24.0), 0.08 + i * 0.05)


func _build_skhira() -> void:
	var concrete := Mats.mat(Color(0.55, 0.53, 0.50), 0.95)
	var rust := Mats.mat(Color(0.45, 0.24, 0.14), 0.9, 0.4)
	# quai
	Mats.mi(Mats.box(Vector3(10, 1.2, 26)), concrete, Vector3(-30, -0.2, -10), self)
	# grues
	for k in 2:
		var cx := -33.0 + k * 6.0
		var cr := Node3D.new()
		cr.position = Vector3(cx, 0.4, -16.0 + k * 6.0)
		add_child(cr)
		var yel := Mats.mat(Color(0.85, 0.6, 0.15), 0.7, 0.3)
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				Mats.mi(Mats.box(Vector3(0.35, 12, 0.35)), yel, Vector3(sx * 1.4, 6, sz * 1.4), cr)
		Mats.mi(Mats.box(Vector3(3.4, 1.2, 3.4)), yel, Vector3(0, 12.4, 0), cr)
		Mats.mi(Mats.box(Vector3(0.6, 0.6, 16)), yel, Vector3(0, 13.2, -6), cr)
		Mats.mi(Mats.cyl(0.03, 0.03, 8, 4), Mats.mat(Color(0.1, 0.1, 0.1), 0.5), Vector3(0, 9.0, -11), cr)
		Mats.merge(cr)
	# conteneurs colorés
	var cols := [Color(0.70, 0.18, 0.14), Color(0.12, 0.38, 0.62), Color(0.80, 0.55, 0.12), Color(0.20, 0.50, 0.35)]
	for k in 7:
		var cx2 := 26.0 + (k % 3) * 2.6
		var cz := 18.0 + (k / 3) * 6.5
		var cont := Mats.mi(Mats.box(Vector3(2.4, 2.5, 6.0)), Mats.mat(cols[k % 4], 0.75, 0.35), Vector3.ZERO, self)
		cont.position = Vector3(cx2, height_at(cx2, cz) + 1.2 + (2.5 if k == 6 else 0.0), cz)
	# (tas de couleurs vives retirés : ils ressemblaient à des formes posées au hasard)
	# épave rouillée dans l'eau
	var wreck := Node3D.new()
	wreck.position = Vector3(10, -1.2, -16)
	wreck.rotation_degrees = Vector3(8, -25, -14)
	add_child(wreck)
	Mats.mi(Mats.tapered_box(Vector2(2.0, 7.0), Vector2(3.0, 9.0), 3.4), rust, Vector3.ZERO, wreck)
	Mats.mi(Mats.box(Vector3(4, 2.5, 4)), Mats.mat(Color(0.5, 0.45, 0.4), 0.9, 0.3), Vector3(0, 4.4, 3), wreck)
	Mats.mi(Mats.cyl(0.5, 0.6, 4, 12), rust, Vector3(0, 6.5, 3), wreck)
	Mats.merge(wreck)
	for i in 6:
		var x := 8.0 + i * 5.0
		_palm(x, shore_z(x) + _rng.randf_range(18.0, 26.0), 0.25 + i * 0.07)


func _build_sidi_mansour() -> void:
	# barques (flouka) échouées
	for k in 3:
		var bx := -20.0 + k * 9.0
		var boat := Node3D.new()
		var hull_col: Color = [Color(0.12, 0.40, 0.75), Color(0.92, 0.92, 0.88), Color(0.80, 0.20, 0.16)][k]
		Mats.mi(Mats.tapered_box(Vector2(0.5, 2.0), Vector2(0.95, 2.6), 0.9), Mats.mat(hull_col, 0.7), Vector3.ZERO, boat)
		Mats.mi(Mats.box(Vector3(1.95, 0.12, 5.25)), Mats.mat(Color(0.92, 0.85, 0.6), 0.8), Vector3(0, 0.9, 0), boat)
		Mats.mi(Mats.cyl(0.05, 0.06, 3.0, 6), Mats.mat(Color(0.45, 0.35, 0.25), 0.9), Vector3(0, 2.3, -0.6), boat)
		Mats.merge(boat)
		boat.rotation_degrees = Vector3(0, 70 + k * 25, 10 - k * 6)
		_place(boat, bx, shore_z(bx) + 2.5 + k, 0.1)
	# tapis de bouteilles
	var bottle_mesh := Mats.cyl(0.06, 0.06, 0.28, 8)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = bottle_mesh
	var n_bottles: int = 120 if low_end else 260
	mm.instance_count = n_bottles
	for i in n_bottles:
		var x := _rng.randf_range(-40, 40)
		var z := shore_z(x) + _rng.randf_range(-0.5, 9.0)
		var b := Basis(Vector3(0, 0, 1), PI * 0.5).rotated(Vector3.UP, _rng.randf_range(0, TAU))
		mm.set_instance_transform(i, Transform3D(b, Vector3(x, height_at(x, z) + 0.05, z)))
		mm.set_instance_color(i, [Color(0.6, 0.85, 1.0, 0.7), Color(0.5, 0.85, 0.55, 0.7), Color(0.95, 0.95, 0.98, 0.7)][i % 3])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var bm := Mats.glass(Color(1, 1, 1, 0.7))
	bm = bm.duplicate() as StandardMaterial3D
	bm.vertex_color_use_as_albedo = true
	mmi.material_override = bm
	mmi.name = "BottleCarpet"
	add_child(mmi)
	_floating.append([mmi, mmi.position, 0.0, 0.85])
	for i in 8:
		var x := -34.0 + i * 9.0
		_olive(x, shore_z(x) + _rng.randf_range(12.0, 22.0), 0.15 + i * 0.07)


func _build_vegetation() -> void:
	# touffes d'herbe (deux quads croisés) qui poussent avec la restauration
	var tuft := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# touffe de 7 brins fins et inclinés (au lieu de deux grands triangles)
	for k in 7:
		var a: float = TAU * k / 7.0 + 0.3
		var base := Vector3(cos(a) * 0.05, 0, sin(a) * 0.05)
		var side := Vector3(-sin(a), 0, cos(a)) * 0.025
		var h: float = 0.32 + 0.12 * float(k % 3)
		var tip := base + Vector3(cos(a) * 0.14, h, sin(a) * 0.14)
		for vtx in [base - side, base + side, tip]:
			st.set_normal(Vector3.UP)
			st.add_vertex(vtx)
	tuft = st.commit()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = tuft
	var n_grass: int = 140 if low_end else 420
	mm.instance_count = n_grass
	for i in n_grass:
		var x := _rng.randf_range(-60, 60)
		var z := shore_z(x) + _rng.randf_range(6.0, 34.0)
		var p := Vector3(x, height_at(x, z) - 0.05, z)
		var b := Basis(Vector3.UP, _rng.randf_range(0, TAU))
		_grass_xf.append([b, p, _rng.randf_range(0.0, 1.0)])
		mm.set_instance_transform(i, Transform3D(b.scaled(Vector3.ONE * 0.001), p))
	_grass = MultiMeshInstance3D.new()
	_grass.multimesh = mm
	var gm := Mats.mat(Color(0.26, 0.62, 0.18), 0.8)
	gm = gm.duplicate() as StandardMaterial3D
	gm.cull_mode = BaseMaterial3D.CULL_DISABLED
	_grass.material_override = gm
	_grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_grass)


func _build_floating_trash() -> void:
	var mats := [Mats.glass(Color(0.7, 0.9, 1.0, 0.7)), Mats.mat(Color(0.9, 0.9, 0.85), 0.8), Mats.mat(Color(0.2, 0.5, 0.8), 0.6), Mats.mat(Color(0.12, 0.12, 0.12), 0.7)]
	for i in 34:
		var x := _rng.randf_range(-45, 45)
		var z := shore_z(x) - _rng.randf_range(2.0, 26.0)
		var n: MeshInstance3D
		match i % 4:
			0: n = Mats.mi(Mats.cyl(0.08, 0.08, 0.32, 8), mats[0], Vector3.ZERO, self, Vector3(0, 0, 90))
			1: n = Mats.mi(Mats.box(Vector3(0.4, 0.05, 0.3)), mats[1], Vector3.ZERO, self)
			2: n = Mats.mi(Mats.sphere(0.2), mats[2], Vector3.ZERO, self, Vector3.ZERO, Vector3(1.2, 0.4, 1))
			_: n = Mats.mi(Mats.torus(0.15, 0.3), mats[3], Vector3.ZERO, self)
		n.position = Vector3(x, 0.05, z)
		n.rotation_degrees.y = _rng.randf_range(0, 360)
		_floating.append([n, n.position, _rng.randf_range(0, TAU), _rng.randf_range(0.2, 0.8)])


func _build_gulls() -> void:
	var m := Mats.mat(Color(0.95, 0.95, 0.95), 0.6)
	var tip := Mats.mat(Color(0.2, 0.2, 0.22), 0.6)
	for i in 7:
		var g := Node3D.new()
		Mats.mi(Mats.capsule(0.08, 0.4), m, Vector3.ZERO, g, Vector3(90, 0, 0))
		for sx in [-1.0, 1.0]:
			var w := Node3D.new()
			w.name = "WL" if sx < 0 else "WR"
			g.add_child(w)
			Mats.mi(Mats.box(Vector3(0.55, 0.02, 0.16)), m, Vector3(0.3 * sx, 0, 0), w)
			Mats.mi(Mats.box(Vector3(0.15, 0.021, 0.12)), tip, Vector3(0.6 * sx, 0, 0), w)
		add_child(g)
		g.visible = false
		_gulls.append([g, _rng.randf_range(0, TAU), _rng.randf_range(10, 22), _rng.randf_range(7, 12), Vector3(_rng.randf_range(-25, 25), 0, _rng.randf_range(-40, -15))])


# ================================================================== restauration
func _process(delta: float) -> void:
	_t += delta
	r = lerpf(r, r_target, 1.0 - exp(-_rate * delta))
	if _celebrate and absf(r - r_target) < 0.003:
		_celebrate = false
		_rate = 1.6
	_apply(false)
	# déchets flottants qui dansent puis disparaissent
	for f in _floating:
		var n: Node3D = f[0]
		var vis: bool = r < float(f[3])
		if n.visible != vis:
			n.visible = vis
		if vis and n is MeshInstance3D:
			var b: Vector3 = f[1]
			n.position.y = b.y + sin(_t * 1.3 + float(f[2])) * 0.12
	# mouettes (local OU global : le large reflète aussi l'océan partagé)
	var gull_level: float = maxf(r, global_ocean * 0.8)
	for i in _gulls.size():
		var g: Array = _gulls[i]
		var node: Node3D = g[0]
		node.visible = gull_level > 0.45 + i * 0.06
		if node.visible:
			var a: float = float(g[1]) + _t * 0.35
			var c: Vector3 = g[4]
			node.position = c + Vector3(cos(a) * float(g[2]), float(g[3]) + sin(_t + i) * 0.6, sin(a) * float(g[2]) * 0.6)
			node.rotation.y = -a
			var flap: float = sin(_t * 6.0 + i) * 0.5
			node.get_node("WL").rotation.z = flap
			node.get_node("WR").rotation.z = -flap
	if camera != null:
		var cam_p: Vector3 = camera.global_position
		for g in _green:
			var n3: Node3D = g[0]
			if n3.scale.x > 0.02:
				var near: bool = Vector2(n3.global_position.x - cam_p.x, n3.global_position.z - cam_p.z).length() < 6.5 and n3.global_position.z < cam_p.z + 1.0
				n3.visible = not near
		for d in _dead_trees:
			var n4: Node3D = d[0]
			if n4.scale.x > 0.02:
				var near2: bool = Vector2(n4.global_position.x - cam_p.x, n4.global_position.z - cam_p.z).length() < 7.5 and n4.global_position.z > cam_p.z - 9.0
				n4.visible = not near2
	if camera != null and matte != null:
		var cp: Vector3 = camera.global_position
		matte.position.x = cp.x
		matte.position.z = cp.z - 205.0
		if _dust != null:
			_dust.position = Vector3(cp.x, cp.y - 1.0, cp.z - 8.0)


func _apply(force: bool) -> void:
	if env == null:
		return
	# Ciel, brouillard, lumières et shaders : recalculés seulement quand la
	# restauration a vraiment bougé (changer le ciel à chaque image recalcule
	# son éclairage : c'était une grosse part du coût par image).
	var heavy: bool = force or absf(r - _applied_r) > 0.002 or absf(desaturate - _applied_desat) > 0.01
	if heavy:
		_applied_r = r
		_applied_desat = desaturate
		_apply_env()
	_apply_props(force)


func _apply_env() -> void:
	var t: Dictionary = _tint
	var clean_top := Color(0.14, 0.44, 0.88)
	var clean_hor := Color(0.62, 0.82, 0.96)
	var k: float = smoothstep(0.0, 1.0, r)
	sky_mat.sky_top_color = Color(t.sky_top).lerp(clean_top, k)
	sky_mat.sky_horizon_color = Color(t.sky_hor).lerp(clean_hor, k)
	sky_mat.ground_horizon_color = sky_mat.sky_horizon_color
	sky_mat.ground_bottom_color = Color(0.2, 0.17, 0.14).lerp(Color(0.1, 0.3, 0.45), k)
	sky_mat.sky_energy_multiplier = lerpf(0.9, 1.05, k)
	env.fog_light_color = Color(t.fog).lerp(Color(0.58, 0.72, 0.86), k)
	env.fog_density = lerpf(0.0095, 0.0016, k)
	env.adjustment_saturation = lerpf(0.82, 1.12, k) * (1.0 - 0.75 * desaturate)
	env.adjustment_contrast = lerpf(1.08, 1.04, k)
	sun.light_color = Color(t.sun).lerp(Color(1.0, 0.96, 0.88), k)
	sun.light_energy = lerpf(1.15, 1.0, k)
	env.tonemap_exposure = lerpf(1.0, 0.82, k)
	if env.glow_enabled:
		env.glow_intensity = lerpf(0.45, 0.2, k)
	env.ambient_light_energy = lerpf(0.85, 0.5, k)
	sun.rotation_degrees.x = lerpf(-14.0, -38.0, k)
	sea_mat.set_shader_parameter("restoration", k)
	sea_mat.set_shader_parameter("sky_col", sky_mat.sky_horizon_color)
	terrain_mat.set_shader_parameter("restoration", k)
	if matte_mat != null:
		# Skhira / Sidi Mansour : fond peint (côte en partie restaurée) toujours visible.
		# Gabès : fond pollué (usines fumantes) qui s'efface quand l'histoire atteint 100 %.
		var a: float = 1.0 - 0.75 * smoothstep(0.75, 1.0, r)
		if level_id == "gabes":
			a = 1.0 - 0.9 * smoothstep(0.55, 1.0, r)
		matte_mat.albedo_color = Color(0.92, 0.9, 0.88, a).lerp(Color(1.0, 1.0, 1.04, a), k)
	if _dust_mat != null:
		_dust_mat.albedo_color = Color(0.85, 0.7, 0.5, 0.5 * (1.0 - k))


func _apply_props(force: bool) -> void:
	for s in _smokes:
		var p: CPUParticles3D = s[0]
		p.emitting = r < float(s[1])
	for d in _dead_trees:
		var n: Node3D = d[0]
		var target: float = 1.0 - smoothstep(float(d[1]) - 0.1, float(d[1]) + 0.1, r)
		n.scale = Vector3.ONE * maxf(0.001, target)
		n.visible = target > 0.01
	for g in _green:
		var n2: Node3D = g[0]
		var grow: float = smoothstep(float(g[1]), float(g[1]) + 0.18, r) * float(g[2])
		if _celebrate and grow > 0.01 and n2.scale.x <= 0.011:
			_sparkle(n2.global_position)
		n2.scale = Vector3.ONE * maxf(0.001, grow)
		n2.visible = grow > 0.01
		if n2.visible:
			# feuillage qui ondule doucement au vent
			n2.rotation.z = sin(_t * 1.3 + n2.position.x * 0.7) * 0.035
	if _grass != null and (force or absf(_grass_r - r) > 0.02):
		_grass_r = r
		var mm: MultiMesh = _grass.multimesh
		for i in _grass_xf.size():
			var e: Array = _grass_xf[i]
			var s2: float = smoothstep(0.25 + float(e[2]) * 0.5, 0.45 + float(e[2]) * 0.5, r)
			var b: Basis = e[0]
			mm.set_instance_transform(i, Transform3D(b.scaled(Vector3.ONE * maxf(0.001, s2 * 1.1)), e[1]))
