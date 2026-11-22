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
var global_ocean: float = 0.0    # 0..1 (serveur)
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
var low_end: bool = OS.has_feature("web_android") or OS.has_feature("web_ios") or OS.has_feature("mobile")

const TINTS := {
	"gabes": {"sky_top": Color(0.33, 0.27, 0.24), "sky_hor": Color(0.86, 0.58, 0.34), "fog": Color(0.66, 0.48, 0.32),
		"sun": Color(1.0, 0.62, 0.34), "sand": Color(0.56, 0.50, 0.43), "wet": Color(0.30, 0.27, 0.23), "pol": Color(0.47, 0.47, 0.46)},
	"skhira": {"sky_top": Color(0.27, 0.24, 0.30), "sky_hor": Color(0.78, 0.55, 0.50), "fog": Color(0.56, 0.46, 0.48),
		"sun": Color(1.0, 0.66, 0.48), "sand": Color(0.64, 0.54, 0.42), "wet": Color(0.33, 0.28, 0.22), "pol": Color(0.18, 0.17, 0.18)},
	"sidi_mansour": {"sky_top": Color(0.38, 0.34, 0.26), "sky_hor": Color(0.90, 0.72, 0.44), "fog": Color(0.74, 0.62, 0.44),
		"sun": Color(1.0, 0.78, 0.50), "sand": Color(0.78, 0.66, 0.48), "wet": Color(0.42, 0.34, 0.24), "pol": Color(0.26, 0.24, 0.22)},
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
	pm.subdivide_width = 150
	pm.subdivide_depth = 80
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
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.85
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.glow_enabled = not low_end
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
	sun.shadow_enabled = not low_end
	sun.directional_shadow_max_distance = 55.0
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
	p.amount = 10 if low_end else 22
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


func _chimney(pos: Vector3, h: float, rad: float, threshold: float) -> void:
	var red := Mats.mat(Color(0.62, 0.20, 0.14), 0.85)
	var white := Mats.mat(Color(0.82, 0.78, 0.72), 0.85)
	var bands := 6
	for i in bands:
		var bh: float = h / bands
		var rr: float = rad * (1.0 - 0.18 * float(i) / bands)
		Mats.mi(Mats.cyl(rr * 0.97, rr, bh, 16), red if i % 2 == 0 else white, pos + Vector3(0, bh * (i + 0.5), 0), self)
	_smoke(pos + Vector3(0, h + 1.0, 0), rad * 1.2, threshold)


func _build_far_industry() -> void:
	var rust := Mats.mat(Color(0.42, 0.28, 0.20), 0.9, 0.3)
	var steel := Mats.mat(Color(0.40, 0.38, 0.36), 0.7, 0.5)
	var side: float = -1.0 if level_id != "skhira" else 1.0
	var base := Vector3(-58.0 * side, 0, -46.0)
	# jetée + complexe chimique
	Mats.mi(Mats.box(Vector3(46, 2.2, 22)), Mats.mat(Color(0.36, 0.32, 0.28), 0.95), base + Vector3(0, 0.6, 0), self)
	_chimney(base + Vector3(-8, 1.7, -4), 26.0, 1.3, 0.55)
	_chimney(base + Vector3(-3, 1.7, -6), 22.0, 1.1, 0.75)
	_chimney(base + Vector3(10, 1.7, 2), 18.0, 1.0, 0.9)
	for k in 5:
		var tp := base + Vector3(-14 + k * 6.5, 1.7, 4 + (k % 2) * 3)
		var th: float = 7.0 + (k * 3 % 5)
		Mats.mi(Mats.cyl(1.4, 1.5, th, 14), rust if k % 2 else steel, tp + Vector3(0, th * 0.5, 0), self)
		Mats.mi(Mats.sphere(1.5, 1.4), steel, tp + Vector3(0, th, 0), self)
		Mats.mi(Mats.cyl(0.25, 0.25, th + 3, 8), rust, tp + Vector3(1.6, (th + 3) * 0.5, 0), self)
	Mats.mi(Mats.box(Vector3(30, 0.5, 0.5)), rust, base + Vector3(0, 8.5, 6), self)
	Mats.mi(Mats.box(Vector3(30, 0.5, 0.5)), rust, base + Vector3(0, 5.5, 8), self)
	# promontoire opposé (collines) pour fermer la baie
	var hill := Mats.mat(Color(0.48, 0.40, 0.32), 0.95)
	for k in 6:
		Mats.mi(Mats.rock(1.0, 400 + k, 0.45), hill, Vector3(60.0 * side + k * 9.0 * side, -1.0, -70.0 - k * 6.0), self, Vector3(0, k * 40, 0), Vector3(14, 9 + k, 12))


func _build_dust() -> void:
	_dust = CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.08, 0.08)
	_dust_mat = Mats.unshaded(Color(0.85, 0.7, 0.5, 0.55), false, load("res://assets/icons/glow.png"))
	_dust_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	q.material = _dust_mat
	_dust.mesh = q
	_dust.amount = 35 if low_end else 90
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
	if tipped:
		n.rotation_degrees = Vector3(90, _rng.randf_range(0, 360), 0)
		_place(n, x, z, 0.4)
	else:
		n.rotation_degrees.y = _rng.randf_range(0, 360)
		_place(n, x, z, -0.05)


func _rock(x: float, z: float, s: float) -> void:
	var m := Mats.mat(Color(0.34, 0.31, 0.28).lerp(Color(_tint.sand), 0.25), 0.9)
	var n := Mats.mi(Mats.rock(1.0, _rng.randi_range(1, 30), 0.65), m, Vector3.ZERO, self, Vector3(0, _rng.randf_range(0, 360), 0), Vector3(s, s, s) * _rng.randf_range(0.8, 1.2))
	n.position = Vector3(x, height_at(x, z) - s * 0.15, z)


func _driftwood(x: float, z: float) -> void:
	var m := Mats.mat(Color(0.52, 0.45, 0.38), 0.95)
	var n := Node3D.new()
	Mats.mi(Mats.capsule(0.12, 2.4), m, Vector3.ZERO, n, Vector3(0, 0, 90))
	Mats.mi(Mats.capsule(0.07, 0.9), m, Vector3(0.5, 0.25, 0), n, Vector3(0, 0, 35))
	n.rotation_degrees.y = _rng.randf_range(0, 360)
	_place(n, x, z, 0.08)


func _net(x: float, z: float) -> void:
	var m := Mats.mat(Color(0.22, 0.42, 0.36, 0.92), 0.95)
	var n := Node3D.new()
	for k in 5:
		Mats.mi(Mats.sphere(0.6), m, Vector3(k * 0.45 - 0.9, 0.05, sin(k * 1.3) * 0.4), n, Vector3.ZERO, Vector3(1.2, 0.18, 0.9))
	Mats.mi(Mats.sphere(0.12), Mats.mat(Color(0.95, 0.55, 0.15), 0.5), Vector3(0.9, 0.15, 0.3), n)
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
	_place(n, x, z, -0.1)
	_dead_trees.append([n, threshold])


func _palm(x: float, z: float, threshold: float) -> void:
	var trunk_m := Mats.mat(Color(0.48, 0.38, 0.27), 0.9)
	var frond_m := Mats.mat(Color(0.24, 0.48, 0.18), 0.75, 0.0, 0.2)
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
	_place(n, x, z, -0.1)
	n.scale = Vector3.ONE * 0.01
	_green.append([n, threshold, _rng.randf_range(0.85, 1.15)])


func _olive(x: float, z: float, threshold: float) -> void:
	var trunk_m := Mats.mat(Color(0.40, 0.34, 0.27), 0.95)
	var leaf_m := Mats.mat(Color(0.45, 0.55, 0.36), 0.8, 0.0, 0.25)
	var n := Node3D.new()
	Mats.mi(Mats.cyl(0.16, 0.26, 1.6, 9), trunk_m, Vector3(0, 0.8, 0), n, Vector3(0, 0, 6))
	for k in 6:
		var a := k * 1.05
		Mats.mi(Mats.sphere(0.85), leaf_m, Vector3(cos(a) * 0.8, 2.0 + (k % 3) * 0.35, sin(a) * 0.8), n, Vector3.ZERO, Vector3(1, 0.7, 1))
	Mats.mi(Mats.sphere(1.0), leaf_m, Vector3(0, 2.5, 0), n, Vector3.ZERO, Vector3(1, 0.7, 1))
	_place(n, x, z, -0.1)
	n.scale = Vector3.ONE * 0.01
	_green.append([n, threshold, _rng.randf_range(0.85, 1.2)])


func _house(x: float, z: float, w: float, h: float, door: bool = true) -> void:
	var white := Mats.mat(Color(0.95, 0.94, 0.90), 0.85)
	var blue := Mats.mat(Color(0.10, 0.36, 0.72), 0.6)
	var n := Node3D.new()
	Mats.mi(Mats.box(Vector3(w, h, w * 0.8)), white, Vector3(0, h * 0.5, 0), n)
	Mats.mi(Mats.box(Vector3(w + 0.15, 0.18, w * 0.8 + 0.15)), white, Vector3(0, h + 0.09, 0), n)
	if door:
		Mats.mi(Mats.box(Vector3(0.9, 1.9, 0.08)), blue, Vector3(0, 0.95, w * 0.4 + 0.02), n)
		Mats.mi(Mats.cyl(0.45, 0.45, 0.08, 16), blue, Vector3(0, 1.9, w * 0.4 + 0.02), n, Vector3(90, 0, 0), Vector3(1, 1, 1))
	Mats.mi(Mats.box(Vector3(0.7, 0.8, 0.08)), blue, Vector3(w * 0.28, h * 0.6, w * 0.4 + 0.02), n)
	_place(n, x, z, -0.2)


func _build_common_props() -> void:
	for i in 14:
		var x := _rng.randf_range(-44, 44)
		var z := shore_z(x) + _rng.randf_range(-1.0, 18.0)
		if absf(x) < 7.0 and z > 2.0 and z < 15.0:
			continue
		_rock(x, z, _rng.randf_range(0.5, 1.4))
	for i in 7:
		var x := _rng.randf_range(-38, 38)
		var z := shore_z(x) + _rng.randf_range(2.0, 16.0)
		if absf(x) < 6.0 and z < 15.0:
			x += 9.0
		_barrel(x, z, i % 3 == 0)
	for i in 6:
		var x := _rng.randf_range(-40, 40)
		_driftwood(x, shore_z(x) + _rng.randf_range(0.5, 5.0))
	for i in 3:
		var x := _rng.randf_range(-35, 35)
		_net(x, shore_z(x) + _rng.randf_range(0.5, 6.0))
	for i in 4:
		var x := _rng.randf_range(-40, 40)
		_tire(x, shore_z(x) + _rng.randf_range(1.0, 12.0))
	for i in 7:
		var x := _rng.randf_range(-42, 42)
		_dead_tree(x, shore_z(x) + _rng.randf_range(12.0, 26.0), 0.35 + i * 0.06)


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
	# oasis : palmiers qui reverdissent, maisons blanches au fond
	for i in 12:
		var x := -36.0 + i * 6.5 + _rng.randf_range(-2, 2)
		_palm(x, shore_z(x) + _rng.randf_range(14.0, 24.0), 0.08 + i * 0.05)
	_house(-14, 30, 4.0, 3.2)
	_house(-8, 31, 3.0, 2.6)
	_house(12, 30, 3.5, 3.0)


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
	# conteneurs colorés
	var cols := [Color(0.70, 0.18, 0.14), Color(0.12, 0.38, 0.62), Color(0.80, 0.55, 0.12), Color(0.20, 0.50, 0.35)]
	for k in 7:
		var cx2 := 26.0 + (k % 3) * 2.6
		var cz := 18.0 + (k / 3) * 6.5
		var cont := Mats.mi(Mats.box(Vector3(2.4, 2.5, 6.0)), Mats.mat(cols[k % 4], 0.75, 0.35), Vector3.ZERO, self)
		cont.position = Vector3(cx2, height_at(cx2, cz) + 1.2 + (2.5 if k == 6 else 0.0), cz)
	# balles de textiles et tas de vêtements
	var tcol := [Color(0.75, 0.3, 0.4), Color(0.3, 0.45, 0.75), Color(0.85, 0.75, 0.3), Color(0.4, 0.65, 0.45), Color(0.6, 0.35, 0.7)]
	for k in 10:
		var bx := _rng.randf_range(-24, 20)
		var bz := shore_z(bx) + _rng.randf_range(2.5, 14.0)
		if absf(bx) < 7.0 and bz < 15.0:
			continue
		var heap := Node3D.new()
		for j in 5:
			Mats.mi(Mats.sphere(0.45), Mats.mat(tcol[(k + j) % 5], 0.95), Vector3(_rng.randf_range(-0.5, 0.5), 0.15 + j * 0.12, _rng.randf_range(-0.5, 0.5)), heap, Vector3.ZERO, Vector3(1.3, 0.45, 1.1))
		_place(heap, bx, bz, 0.0)
	# épave rouillée dans l'eau
	var wreck := Node3D.new()
	wreck.position = Vector3(10, -1.2, -16)
	wreck.rotation_degrees = Vector3(8, -25, -14)
	add_child(wreck)
	Mats.mi(Mats.tapered_box(Vector2(2.0, 7.0), Vector2(3.0, 9.0), 3.4), rust, Vector3.ZERO, wreck)
	Mats.mi(Mats.box(Vector3(4, 2.5, 4)), Mats.mat(Color(0.5, 0.45, 0.4), 0.9, 0.3), Vector3(0, 4.4, 3), wreck)
	Mats.mi(Mats.cyl(0.5, 0.6, 4, 12), rust, Vector3(0, 6.5, 3), wreck)
	_house(-6, 32, 4.0, 3.0)
	for i in 6:
		var x := 8.0 + i * 5.0
		_palm(x, shore_z(x) + _rng.randf_range(18.0, 26.0), 0.25 + i * 0.07)


func _build_sidi_mansour() -> void:
	# marabout blanc à coupole sur un promontoire
	var white := Mats.mat(Color(0.96, 0.95, 0.91), 0.85)
	var mx := 26.0
	var mz := shore_z(mx) + 6.0
	var mar := Node3D.new()
	Mats.mi(Mats.box(Vector3(5, 3.2, 5)), white, Vector3(0, 1.6, 0), mar)
	Mats.mi(Mats.cyl(2.0, 2.2, 0.8, 24), white, Vector3(0, 3.6, 0), mar)
	Mats.mi(Mats.sphere(2.0, 2.4, 28), white, Vector3(0, 4.1, 0), mar)
	Mats.mi(Mats.cyl(0.05, 0.05, 1.0, 6), Mats.mat(Color(0.7, 0.6, 0.3), 0.4, 0.8), Vector3(0, 5.8, 0), mar)
	Mats.mi(Mats.box(Vector3(1.1, 2.0, 0.1)), Mats.mat(Color(0.12, 0.45, 0.42), 0.6), Vector3(0, 1.0, 2.52), mar)
	mar.rotation_degrees.y = -20
	_place(mar, mx, mz, -0.2)
	# barques (flouka) échouées
	for k in 3:
		var bx := -20.0 + k * 9.0
		var boat := Node3D.new()
		var hull_col: Color = [Color(0.12, 0.40, 0.75), Color(0.92, 0.92, 0.88), Color(0.80, 0.20, 0.16)][k]
		Mats.mi(Mats.tapered_box(Vector2(0.5, 2.0), Vector2(0.95, 2.6), 0.9), Mats.mat(hull_col, 0.7), Vector3.ZERO, boat)
		Mats.mi(Mats.box(Vector3(1.95, 0.12, 5.25)), Mats.mat(Color(0.92, 0.85, 0.6), 0.8), Vector3(0, 0.9, 0), boat)
		Mats.mi(Mats.cyl(0.05, 0.06, 3.0, 6), Mats.mat(Color(0.45, 0.35, 0.25), 0.9), Vector3(0, 2.3, -0.6), boat)
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
	# maisons blanches aux portes bleues (Sfax)
	_house(-18, 30, 4.2, 3.3)
	_house(-11, 31.5, 3.2, 2.8)
	_house(-3, 32, 4.5, 3.6)
	_house(6, 31, 3.0, 2.6)
	for i in 8:
		var x := -34.0 + i * 9.0
		_olive(x, shore_z(x) + _rng.randf_range(12.0, 22.0), 0.15 + i * 0.07)


func _build_vegetation() -> void:
	# touffes d'herbe (deux quads croisés) qui poussent avec la restauration
	var tuft := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for a in [0.0, PI * 0.5]:
		var dx := cos(a) * 0.35
		var dz := sin(a) * 0.35
		var v := [Vector3(-dx, 0, -dz), Vector3(dx, 0, dz), Vector3(dx * 0.4, 0.6, dz * 0.4), Vector3(-dx * 0.4, 0.6, -dz * 0.4)]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_normal(Vector3.UP)
			st.add_vertex(v[idx])
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
	var gm := Mats.mat(Color(0.38, 0.58, 0.22), 0.8)
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
	r = lerpf(r, r_target, 1.0 - exp(-1.6 * delta))
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
	if camera != null and matte != null:
		var cp: Vector3 = camera.global_position
		matte.position.x = cp.x
		matte.position.z = cp.z - 205.0
		if _dust != null:
			_dust.position = Vector3(cp.x, cp.y - 1.0, cp.z - 8.0)


func _apply(force: bool) -> void:
	if env == null:
		return
	var t: Dictionary = _tint
	var clean_top := Color(0.16, 0.42, 0.82)
	var clean_hor := Color(0.66, 0.82, 0.94)
	var k: float = smoothstep(0.0, 1.0, r)
	sky_mat.sky_top_color = Color(t.sky_top).lerp(clean_top, k)
	sky_mat.sky_horizon_color = Color(t.sky_hor).lerp(clean_hor, k)
	sky_mat.ground_horizon_color = sky_mat.sky_horizon_color
	sky_mat.ground_bottom_color = Color(0.2, 0.17, 0.14).lerp(Color(0.1, 0.3, 0.45), k)
	sky_mat.sky_energy_multiplier = lerpf(0.9, 1.05, k)
	env.fog_light_color = Color(t.fog).lerp(Color(0.72, 0.84, 0.94), k)
	env.fog_density = lerpf(0.0095, 0.0028, k)
	env.adjustment_saturation = lerpf(0.82, 1.12, k)
	env.adjustment_contrast = lerpf(1.08, 1.04, k)
	sun.light_color = Color(t.sun).lerp(Color(1.0, 0.96, 0.88), k)
	sun.light_energy = lerpf(1.15, 1.45, k)
	sun.rotation_degrees.x = lerpf(-14.0, -38.0, k)
	sea_mat.set_shader_parameter("restoration", k)
	sea_mat.set_shader_parameter("sky_col", sky_mat.sky_horizon_color)
	terrain_mat.set_shader_parameter("restoration", k)
	if matte_mat != null:
		var a: float = 1.0 - smoothstep(0.45, 0.92, r)
		matte_mat.albedo_color = Color(1, 1, 1, a).lerp(Color(1.0, 1.0, 1.0, a), k)
		matte.visible = a > 0.01
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
		n2.scale = Vector3.ONE * maxf(0.001, grow)
		n2.visible = grow > 0.01
	if _dust_mat != null:
		_dust_mat.albedo_color = Color(0.85, 0.7, 0.5, 0.5 * (1.0 - k))
	if _grass != null and (force or absf(_grass_r - r) > 0.02):
		_grass_r = r
		var mm: MultiMesh = _grass.multimesh
		for i in _grass_xf.size():
			var e: Array = _grass_xf[i]
			var s2: float = smoothstep(0.25 + float(e[2]) * 0.5, 0.45 + float(e[2]) * 0.5, r)
			var b: Basis = e[0]
			mm.set_instance_transform(i, Transform3D(b.scaled(Vector3.ONE * maxf(0.001, s2 * 1.3)), e[1]))
