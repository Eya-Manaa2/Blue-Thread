class_name Mats
## Petite boîte à outils 3D procédurale : matériaux mis en cache, formes,
## roches déformées par bruit, tubes annelés (tuyau du masque).

static var _cache: Dictionary = {}
static var _font_black: FontFile
static var _font_bold: FontFile


static func mat(c: Color, rough: float = 0.8, metal: float = 0.0, rim: float = 0.0) -> StandardMaterial3D:
	var key := "m%s_%.2f_%.2f_%.2f" % [c.to_html(), rough, metal, rim]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if rim > 0.0:
		m.rim_enabled = true
		m.rim = rim
		m.rim_tint = 0.3
	if c.a < 0.999:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cache[key] = m
	return m


static func glass(c: Color) -> StandardMaterial3D:
	var key := "g" + c.to_html()
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.08
	m.metallic = 0.1
	m.metallic_specular = 0.9
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.rim_enabled = true
	m.rim = 0.6
	_cache[key] = m
	return m


static func emissive(c: Color, energy: float = 2.0) -> StandardMaterial3D:
	var key := "e%s_%.2f" % [c.to_html(), energy]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	_cache[key] = m
	return m


static func unshaded(c: Color, additive: bool = false, tex: Texture2D = null) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_receive_shadows = true
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	if tex != null:
		m.albedo_texture = tex
	return m


static func font_black() -> FontFile:
	if _font_black == null:
		_font_black = load("res://assets/fonts/FiraSans-Black.ttf")
	return _font_black


static func font_bold() -> FontFile:
	if _font_bold == null:
		_font_bold = load("res://assets/fonts/FiraSans-Bold.ttf")
	return _font_bold


# ------------------------------------------------------------------ shapes
static func box(s: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = s
	return b


static func sphere(r: float, h: float = -1.0, seg: int = 24) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0 if h < 0.0 else h
	s.radial_segments = seg
	s.rings = maxi(8, seg / 2)
	return s


static func capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = maxf(h, r * 2.0 + 0.001)
	c.radial_segments = 20
	c.rings = 6
	return c


static func cyl(top: float, bottom: float, h: float, seg: int = 20) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return c


static func torus(inner: float, outer: float, seg: int = 24) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = seg
	t.ring_segments = 10
	return t


static func mi(mesh: Mesh, m: Material, pos: Vector3, parent: Node, rot_deg: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = m
	n.position = pos
	n.rotation_degrees = rot_deg
	n.scale = scl
	parent.add_child(n)
	return n


static func label3d(text: String, size: int, col: Color, parent: Node, pos: Vector3, black: bool = true) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = font_black() if black else font_bold()
	l.font_size = size
	l.pixel_size = 0.004
	l.modulate = col
	l.outline_size = 0
	l.position = pos
	l.shaded = false
	l.double_sided = false
	parent.add_child(l)
	return l


## Boîte évasée (bac à roulettes, coque de bateau…) avec normales plates.
static func tapered_box(bottom: Vector2, top: Vector2, h: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var b := [Vector3(-bottom.x, 0, -bottom.y), Vector3(bottom.x, 0, -bottom.y), Vector3(bottom.x, 0, bottom.y), Vector3(-bottom.x, 0, bottom.y)]
	var t := [Vector3(-top.x, h, -top.y), Vector3(top.x, h, -top.y), Vector3(top.x, h, top.y), Vector3(-top.x, h, top.y)]
	for i in 4:
		var j := (i + 1) % 4
		_quad(st, b[i], b[j], t[j], t[i])
	_quad(st, t[0], t[1], t[2], t[3])
	_quad(st, b[3], b[2], b[1], b[0])
	st.generate_normals()
	return st.commit()


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	# a,b,c,d donnés dans le sens horaire vu de l'extérieur (faces avant Godot)
	st.add_vertex(a); st.add_vertex(b); st.add_vertex(c)
	st.add_vertex(a); st.add_vertex(c); st.add_vertex(d)


## Roche lisse déformée par bruit.
static func rock(radius: float, seed_v: int, squash: float = 0.7) -> ArrayMesh:
	var key := "rock_%d" % seed_v
	if _cache.has(key):
		return _cache[key]
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 18
	sm.rings = 10
	var arr: Array = sm.get_mesh_arrays()
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var n := FastNoiseLite.new()
	n.seed = seed_v
	n.frequency = 1.3
	for i in verts.size():
		var v: Vector3 = verts[i]
		var d: float = 1.0 + 0.32 * n.get_noise_3dv(v * 1.0) + 0.12 * n.get_noise_3dv(v * 3.1)
		v = v * d
		v.y *= squash
		if v.y < -0.25:
			v.y = -0.25 + (v.y + 0.25) * 0.3
		verts[i] = v
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = null
	arr[Mesh.ARRAY_TANGENT] = null
	var tmp := ArrayMesh.new()
	tmp.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var st := SurfaceTool.new()
	st.create_from(tmp, 0)
	st.generate_normals()
	var out: ArrayMesh = st.commit()
	_cache[key] = out
	return out


## Tube le long d'une suite de points ; ribbed = annelé (tuyau de masque à gaz).
static func tube(pts: PackedVector3Array, radius: float, sides: int = 10, ribbed: bool = false) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array = []
	var up := Vector3.UP
	for i in pts.size():
		var t: Vector3
		if i == 0:
			t = (pts[1] - pts[0]).normalized()
		elif i == pts.size() - 1:
			t = (pts[i] - pts[i - 1]).normalized()
		else:
			t = (pts[i + 1] - pts[i - 1]).normalized()
		if absf(t.dot(up)) > 0.95:
			up = Vector3.RIGHT
		var side: Vector3 = t.cross(up).normalized()
		var nup: Vector3 = side.cross(t).normalized()
		up = nup
		var r: float = radius
		if ribbed:
			r = radius * (1.0 + 0.18 * sin(float(i) * 2.2))
		var ring: Array = []
		for s in sides:
			var a: float = TAU * float(s) / float(sides)
			ring.append(pts[i] + (side * cos(a) + nup * sin(a)) * r)
		rings.append(ring)
	for i in rings.size() - 1:
		for s in sides:
			var s2 := (s + 1) % sides
			_quad(st, rings[i][s], rings[i][s2], rings[i + 1][s2], rings[i + 1][s])
	st.generate_normals()
	return st.commit()


static func bezier(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, n: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in n + 1:
		var t: float = float(i) / float(n)
		var u: float = 1.0 - t
		out.append(p0 * u * u * u + p1 * 3.0 * u * u * t + p2 * 3.0 * u * t * t + p3 * t * t * t)
	return out
