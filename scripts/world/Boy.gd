extends "res://scripts/player.gd"
## Yassine, « le gardien » (d'après CHARACTER_REFERENCE_Le_gardien.png) :
## cheveux châtains en bataille, masque à gaz à filtre jaune, tuyau annelé
## vers une bouteille O2 argent et jaune, veste beige, harnais jaune,
## gants, genouillères, bottes, montre connectée au poignet.
## Hérite du déplacement / de l'animation de marche de player.gd.

var avatar_id: int = -1          # -1 = avatar du profil (GameState.avatar_id)
var frozen: bool = false         # contrôles et animation de marche coupés (aperçu, mort, cinématique)
var head: Node3D
var mask_root: Node3D
var face_under_mask: Node3D
var wrist_screen: MeshInstance3D
var tank_light: MeshInstance3D
var _breath_t: float = 0.0
var _torso: Node3D


func _build_boy() -> void:
	if avatar_id < 0:
		avatar_id = GameState.avatar_id if GameState.avatar_id >= 0 else 1
	var av: Dictionary = GameData.avatar(avatar_id)
	var hair_c: Color = av.hair
	var skin := Mats.mat(av.skin, 0.55, 0.0, 0.2)
	var hair := Mats.mat(hair_c, 0.75, 0.0, 0.25)
	var hair_hi := Mats.mat(hair_c.lightened(0.18), 0.7, 0.0, 0.25)
	var jacket := Mats.mat(Color(0.64, 0.54, 0.40), 0.92, 0.0, 0.18)
	var jacket_lt := Mats.mat(Color(0.74, 0.65, 0.50), 0.92, 0.0, 0.18)
	var shirt := Mats.mat(Color(0.27, 0.22, 0.17), 0.95)
	var pants := Mats.mat(Color(0.33, 0.28, 0.20), 0.95, 0.0, 0.15)
	var pad := Mats.mat(Color(0.17, 0.17, 0.18), 0.55)
	var boot := Mats.mat(Color(0.36, 0.25, 0.16), 0.8, 0.0, 0.15)
	var sole := Mats.mat(Color(0.12, 0.10, 0.09), 0.9)
	var glove := Mats.mat(Color(0.19, 0.19, 0.20), 0.65)
	var yellow := Mats.mat(Color(0.95, 0.74, 0.14), 0.6)
	var strap := Mats.mat(Color(0.16, 0.15, 0.14), 0.8)
	var belt := Mats.mat(Color(0.30, 0.20, 0.12), 0.7)
	var metal := Mats.mat(Color(0.78, 0.80, 0.83), 0.28, 0.85)
	var dark_metal := Mats.mat(Color(0.25, 0.26, 0.28), 0.4, 0.7)
	var mask_m := Mats.mat(Color(0.20, 0.21, 0.22), 0.45, 0.1, 0.2)
	var white := Mats.mat(Color(0.98, 0.98, 0.97), 0.3)
	var iris := Mats.mat(Color(0.36, 0.22, 0.10), 0.3)
	var black := Mats.mat(Color(0.03, 0.02, 0.02), 0.2)
	var bag := Mats.mat(Color(0.30, 0.29, 0.22), 0.9)
	if String(av.get("outfit", "")) == "dengri":
		# dengri tunisien : veste et pantalon de travail bleu indigo
		jacket = Mats.mat(Color(0.15, 0.26, 0.52), 0.9, 0.0, 0.18)
		jacket_lt = Mats.mat(Color(0.24, 0.37, 0.64), 0.9, 0.0, 0.18)
		pants = Mats.mat(Color(0.12, 0.20, 0.42), 0.92, 0.0, 0.15)
		shirt = Mats.mat(Color(0.93, 0.92, 0.88), 0.9)

	# ---------------- jambes (pivot à la hanche)
	_leg_l = Node3D.new()
	_leg_l.position = Vector3(-0.11, 0.62, 0)
	visual.add_child(_leg_l)
	_leg_r = Node3D.new()
	_leg_r.position = Vector3(0.11, 0.62, 0)
	visual.add_child(_leg_r)
	for leg in [_leg_l, _leg_r]:
		var side: float = -1.0 if leg == _leg_l else 1.0
		Mats.mi(Mats.capsule(0.1, 0.52), pants, Vector3(0, -0.22, 0), leg)
		Mats.mi(Mats.box(Vector3(0.05, 0.13, 0.13)), pants, Vector3(0.1 * side, -0.12, -0.01), leg)
		Mats.mi(Mats.sphere(0.085), pad, Vector3(0, -0.27, -0.075), leg, Vector3.ZERO, Vector3(1.05, 1.15, 0.6))
		Mats.mi(Mats.cyl(0.105, 0.11, 0.17), boot, Vector3(0, -0.45, 0), leg)
		Mats.mi(Mats.capsule(0.095, 0.32), boot, Vector3(0, -0.53, -0.05), leg, Vector3(90, 0, 0), Vector3(1.05, 1, 0.8))
		Mats.mi(Mats.box(Vector3(0.2, 0.045, 0.34)), sole, Vector3(0, -0.6, -0.05), leg)
		for k in 3:
			Mats.mi(Mats.box(Vector3(0.12, 0.012, 0.012)), jacket_lt, Vector3(0, -0.43 - k * 0.04, -0.105), leg)

	# ---------------- torse
	_torso = Node3D.new()
	visual.add_child(_torso)
	Mats.mi(Mats.cyl(0.205, 0.205, 0.07), belt, Vector3(0, 0.66, 0), _torso)
	Mats.mi(Mats.box(Vector3(0.07, 0.05, 0.02)), metal, Vector3(0, 0.66, -0.21), _torso)
	Mats.mi(Mats.capsule(0.2, 0.52), shirt, Vector3(0, 0.88, 0), _torso)
	var jk := Mats.mi(Mats.capsule(0.218, 0.5), jacket, Vector3(0, 0.9, 0.012), _torso)
	jk.scale = Vector3(1.0, 1.0, 0.95)
	Mats.mi(Mats.box(Vector3(0.12, 0.36, 0.04)), shirt, Vector3(0, 0.9, -0.2), _torso)
	Mats.mi(Mats.torus(0.11, 0.19), jacket_lt, Vector3(0, 1.12, 0.01), _torso, Vector3.ZERO, Vector3(1, 0.7, 1))
	Mats.mi(Mats.sphere(0.13), jacket, Vector3(0, 1.13, 0.15), _torso, Vector3.ZERO, Vector3(1.3, 0.7, 0.8))
	for sx in [-1.0, 1.0]:
		Mats.mi(Mats.box(Vector3(0.09, 0.08, 0.03)), jacket_lt, Vector3(0.12 * sx, 0.78, -0.205), _torso)
		Mats.mi(Mats.box(Vector3(0.045, 0.42, 0.022)), yellow, Vector3(0.1 * sx, 0.96, -0.218), _torso, Vector3(0, 0, -6 * sx))
		Mats.mi(Mats.box(Vector3(0.045, 0.42, 0.022)), strap, Vector3(0.12 * sx, 0.95, 0.205), _torso)
	Mats.mi(Mats.box(Vector3(0.26, 0.04, 0.024)), yellow, Vector3(0, 1.0, -0.222), _torso)
	Mats.mi(Mats.box(Vector3(0.05, 0.05, 0.03)), metal, Vector3(0, 1.0, -0.232), _torso)

	# ---------------- sac + bouteille O2 + petite lumière
	Mats.mi(Mats.box(Vector3(0.3, 0.34, 0.12)), bag, Vector3(0, 0.93, 0.24), _torso)
	var tank := Node3D.new()
	tank.position = Vector3(-0.05, 0.98, 0.37)
	_torso.add_child(tank)
	Mats.mi(Mats.cyl(0.105, 0.105, 0.46), metal, Vector3.ZERO, tank)
	Mats.mi(Mats.sphere(0.105), metal, Vector3(0, 0.23, 0), tank, Vector3.ZERO, Vector3(1, 0.6, 1))
	Mats.mi(Mats.sphere(0.105), metal, Vector3(0, -0.23, 0), tank, Vector3.ZERO, Vector3(1, 0.5, 1))
	for y in [0.13, -0.14]:
		Mats.mi(Mats.cyl(0.108, 0.108, 0.045), yellow, Vector3(0, y, 0), tank)
	Mats.mi(Mats.cyl(0.03, 0.035, 0.09), dark_metal, Vector3(0, 0.32, 0), tank)
	Mats.mi(Mats.torus(0.02, 0.045), dark_metal, Vector3(0, 0.36, 0), tank)
	tank_light = Mats.mi(Mats.sphere(0.016), Mats.emissive(Color(0.3, 1.0, 0.75), 4.0), Vector3(0.06, 0.06, 0.088), tank)
	var o2 := Mats.label3d("O2", 34, Color(0.12, 0.13, 0.15), tank, Vector3(0, -0.02, 0.107))
	o2.pixel_size = 0.0028

	# ---------------- bras (pivot à l'épaule)
	_arm_l = Node3D.new()
	_arm_l.position = Vector3(-0.275, 1.07, 0)
	visual.add_child(_arm_l)
	_arm_r = Node3D.new()
	_arm_r.position = Vector3(0.275, 1.07, 0)
	visual.add_child(_arm_r)
	for arm in [_arm_l, _arm_r]:
		Mats.mi(Mats.sphere(0.085), jacket, Vector3(0, 0.0, 0), arm)
		Mats.mi(Mats.capsule(0.08, 0.3), jacket, Vector3(0, -0.13, 0), arm)
		Mats.mi(Mats.cyl(0.088, 0.088, 0.065), jacket_lt, Vector3(0, -0.27, 0), arm)
		Mats.mi(Mats.capsule(0.058, 0.2), skin, Vector3(0, -0.36, 0), arm)
		Mats.mi(Mats.cyl(0.066, 0.066, 0.06), glove, Vector3(0, -0.44, 0), arm)
		Mats.mi(Mats.sphere(0.074), glove, Vector3(0, -0.51, -0.005), arm, Vector3.ZERO, Vector3(0.95, 1.25, 0.85))
		Mats.mi(Mats.capsule(0.022, 0.08), glove, Vector3(0.03, -0.5, -0.06), arm, Vector3(30, 0, 0))
	# montre connectée (poignet gauche)
	Mats.mi(Mats.box(Vector3(0.09, 0.055, 0.1)), black, Vector3(-0.02, -0.42, -0.04), _arm_l)
	wrist_screen = Mats.mi(Mats.box(Vector3(0.012, 0.04, 0.075)), Mats.emissive(Color(0.25, 0.95, 1.0), 3.0), Vector3(-0.068, -0.42, -0.04), _arm_l)

	# ---------------- cou + tête
	Mats.mi(Mats.cyl(0.06, 0.065, 0.1), skin, Vector3(0, 1.17, 0), visual)
	head = Node3D.new()
	head.position = Vector3(0, 1.22, 0)
	visual.add_child(head)
	Mats.mi(Mats.sphere(0.3, -1.0, 32), skin, Vector3(0, 0.25, 0), head, Vector3.ZERO, Vector3(1.0, 1.02, 0.98))
	for sx in [-1.0, 1.0]:
		Mats.mi(Mats.sphere(0.062), skin, Vector3(0.29 * sx, 0.25, 0.02), head, Vector3.ZERO, Vector3(0.6, 1, 0.9))
		Mats.mi(Mats.sphere(0.066), white, Vector3(0.1 * sx, 0.31, -0.262), head, Vector3.ZERO, Vector3(1.0, 1.15, 0.55))
		Mats.mi(Mats.sphere(0.042), iris, Vector3(0.1 * sx, 0.305, -0.292), head, Vector3.ZERO, Vector3(1, 1.1, 0.5))
		Mats.mi(Mats.sphere(0.022), black, Vector3(0.1 * sx, 0.305, -0.31), head, Vector3.ZERO, Vector3(1, 1, 0.5))
		Mats.mi(Mats.sphere(0.011), white, Vector3(0.1 * sx + 0.014, 0.322, -0.322), head)
		Mats.mi(Mats.box(Vector3(0.105, 0.024, 0.03)), hair, Vector3(0.1 * sx, 0.395, -0.262), head, Vector3(0, 0, 9 * sx))

	# visage découvert (montré à la fin, quand l'air est redevenu pur)
	face_under_mask = Node3D.new()
	head.add_child(face_under_mask)
	Mats.mi(Mats.sphere(0.032), skin, Vector3(0, 0.235, -0.295), face_under_mask)
	var smile := Mats.bezier(Vector3(-0.06, 0.15, -0.272), Vector3(-0.03, 0.12, -0.29), Vector3(0.03, 0.12, -0.29), Vector3(0.06, 0.15, -0.272), 10)
	Mats.mi(Mats.tube(smile, 0.011, 6), Mats.mat(Color(0.45, 0.16, 0.14), 0.6), Vector3.ZERO, face_under_mask)
	face_under_mask.visible = false

	# masque à gaz
	mask_root = Node3D.new()
	head.add_child(mask_root)
	Mats.mi(Mats.sphere(0.165), mask_m, Vector3(0, 0.15, -0.235), mask_root, Vector3.ZERO, Vector3(1.05, 0.88, 0.85))
	Mats.mi(Mats.torus(0.12, 0.16), mask_m, Vector3(0, 0.16, -0.2), mask_root, Vector3(90, 0, 0), Vector3(1.05, 1, 0.9))
	Mats.mi(Mats.cyl(0.072, 0.075, 0.08), mask_m, Vector3(0, 0.12, -0.37), mask_root, Vector3(90, 0, 0))
	Mats.mi(Mats.torus(0.058, 0.08), yellow, Vector3(0, 0.12, -0.405), mask_root, Vector3(90, 0, 0))
	Mats.mi(Mats.cyl(0.048, 0.048, 0.02), dark_metal, Vector3(0, 0.12, -0.415), mask_root, Vector3(90, 0, 0))
	for sx in [-1.0, 1.0]:
		Mats.mi(Mats.cyl(0.05, 0.05, 0.06), mask_m, Vector3(0.16 * sx, 0.13, -0.29), mask_root, Vector3(0, 0, 90))
		Mats.mi(Mats.torus(0.04, 0.056), yellow, Vector3(0.19 * sx, 0.13, -0.29), mask_root, Vector3(0, 0, 90))
	Mats.mi(Mats.torus(0.295, 0.315), strap, Vector3(0, 0.22, 0.0), mask_root, Vector3(-12, 0, 0))
	var hose_pts := Mats.bezier(Vector3(-0.2, 1.35, -0.29), Vector3(-0.42, 1.25, -0.12),
		Vector3(-0.32, 1.52, 0.32), Vector3(-0.05, 1.34, 0.37), 34)
	for i in hose_pts.size():
		hose_pts[i] = hose_pts[i] - head.position
	Mats.mi(Mats.tube(hose_pts, 0.026, 10, true), Mats.mat(Color(0.10, 0.10, 0.11), 0.5), Vector3.ZERO, mask_root)

	_build_hair(String(av.style), hair, hair_hi, bool(av.girl))
	if bool(av.girl):
		for sx in [-1.0, 1.0]:
			for k in 3:
				Mats.mi(Mats.box(Vector3(0.012, 0.035, 0.01)), Mats.mat(Color(0.05, 0.03, 0.03), 0.5), Vector3(0.1 * sx + (k - 1) * 0.03 * sx + 0.03 * sx, 0.36, -0.29), head, Vector3(0, 0, -25 * sx + k * 12 * sx))
	_merge_parts()
	Mats.blob(self, 0.36)


## Fusion des pièces rigides (environ 120 appels de dessin -> une trentaine) :
## jambes, bras, torse, tête et masque bougent toujours séparément.
func _merge_parts() -> void:
	for n in [_leg_l, _leg_r, _arm_l, _arm_r, _torso, head, mask_root, face_under_mask, visual]:
		if n != null:
			Mats.merge_direct(n, [wrist_screen, tank_light])
	if tank_light != null and tank_light.get_parent() is Node3D:
		Mats.merge_direct(tank_light.get_parent() as Node3D, [tank_light])


## Coiffures des six avatars : même tête, même masque, même squelette.
func _build_hair(style: String, hair: Material, hair_hi: Material, girl: bool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2060 + avatar_id
	if style == "hijab":
		var hc: Color = GameData.avatar(avatar_id).hair
		var cloth: Material = Mats.mat(hc, 0.85, 0.0, 0.25)
		var cloth_hi: Material = Mats.mat(hc.lightened(0.15), 0.85, 0.0, 0.25)
		Mats.mi(Mats.sphere(0.335, -1.0, 28), cloth, Vector3(0, 0.29, 0.07), head, Vector3.ZERO, Vector3(1.05, 1.03, 1.0))
		Mats.mi(Mats.torus(0.24, 0.3), cloth_hi, Vector3(0, 0.26, -0.15), head, Vector3(78, 0, 0), Vector3(1.0, 1.0, 1.25))
		Mats.mi(Mats.cyl(0.2, 0.33, 0.42, 22), cloth, Vector3(0, -0.06, 0.04), head)
		return
	# calotte commune
	Mats.mi(Mats.sphere(0.318, -1.0, 28), hair, Vector3(0, 0.33, 0.035), head, Vector3.ZERO, Vector3(1.0, 0.86, 1.02))
	if style == "chechia":
		# chéchia tunisienne : bonnet de feutre rouge + gland noir
		var felt := Mats.mat(Color(0.74, 0.07, 0.08), 0.95, 0.0, 0.2)
		var felt_dk := Mats.mat(Color(0.58, 0.05, 0.06), 0.95)
		var silk := Mats.mat(Color(0.05, 0.04, 0.04), 0.6)
		var ch := Node3D.new()
		ch.position = Vector3(0, 0.575, 0.04)
		ch.rotation_degrees = Vector3(-7, 0, 3)
		head.add_child(ch)
		Mats.mi(Mats.cyl(0.235, 0.285, 0.22, 32), felt, Vector3.ZERO, ch)
		Mats.mi(Mats.cyl(0.236, 0.236, 0.012, 32), felt_dk, Vector3(0, 0.111, 0), ch)
		Mats.mi(Mats.torus(0.27, 0.295, 32), felt_dk, Vector3(0, -0.1, 0), ch)
		Mats.mi(Mats.cyl(0.03, 0.03, 0.025, 12), silk, Vector3(0, 0.12, 0), ch)
		var tassel := Mats.bezier(Vector3(0, 0.125, 0), Vector3(0.02, 0.17, 0.12), Vector3(0.05, 0.12, 0.22), Vector3(0.07, 0.0, 0.25), 12)
		Mats.mi(Mats.tube(tassel, 0.018, 6), silk, Vector3.ZERO, ch)
		Mats.merge(ch)
		# cheveux courts visibles sous la chéchia
		for sx in [-1.0, 1.0]:
			Mats.mi(Mats.sphere(0.09), hair, Vector3(0.26 * sx, 0.36, 0.06), head, Vector3.ZERO, Vector3(0.6, 1.0, 1.2))
		return
	if style == "short_curly" or style == "curly":
		var n: int = 46 if style == "curly" else 30
		var spread: float = 0.36 if style == "curly" else 0.31
		for i in n:
			var theta: float = rng.randf_range(0.0, TAU)
			var phi: float = rng.randf_range(0.0, 1.45 if style == "curly" else 1.2)
			var dir := Vector3(sin(phi) * cos(theta), cos(phi), sin(phi) * sin(theta))
			if dir.z < -0.6 and dir.y < 0.7:
				continue
			var p: Vector3 = Vector3(0, 0.33, 0.04) + dir * spread
			Mats.mi(Mats.sphere(rng.randf_range(0.06, 0.09) if style == "curly" else rng.randf_range(0.045, 0.065)), hair if i % 3 else hair_hi, p, head)
		if style == "curly":
			for k in 10:
				Mats.mi(Mats.sphere(rng.randf_range(0.07, 0.1)), hair, Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(0.0, 0.2), rng.randf_range(0.18, 0.32)), head)
		return
	# mèches en bataille (garçon) ou cheveux longs (fille)
	for i in 30:
		var theta2: float = rng.randf_range(0.0, TAU)
		var phi2: float = rng.randf_range(0.05, 1.25)
		var dir2 := Vector3(sin(phi2) * cos(theta2), cos(phi2), sin(phi2) * sin(theta2))
		if dir2.z < -0.55 and dir2.y < 0.75:
			continue    # dégager le visage
		var base: Vector3 = Vector3(0, 0.33, 0.035) + Vector3(dir2.x * 0.3, dir2.y * 0.26, dir2.z * 0.31)
		var out: Vector3 = (dir2 + Vector3(0, -0.15, 0.25) + Vector3(rng.randf_range(-0.3, 0.3), 0, rng.randf_range(-0.3, 0.3))).normalized()
		if girl:
			out = (dir2 * 0.4 + Vector3(0, -0.6, 0.2)).normalized()
		var tuft := Mats.mi(Mats.capsule(rng.randf_range(0.045, 0.07), rng.randf_range(0.16, 0.27)), hair if i % 3 else hair_hi, base, head)
		tuft.basis = Basis(Quaternion(Vector3.UP, out))
	# frange tombant sur le front
	for k in 6:
		var x: float = -0.17 + k * 0.07
		var t := Mats.mi(Mats.capsule(0.055, 0.22), hair if k % 2 else hair_hi, Vector3(x, 0.47, -0.2), head)
		t.basis = Basis(Quaternion(Vector3.UP, Vector3(x * 1.4, 0.35 if not girl else 0.15, -1.0).normalized()))
	if style == "long":
		# longue chevelure dans le dos et mèches sur les côtés
		Mats.mi(Mats.sphere(0.3), hair, Vector3(0, 0.08, 0.17), head, Vector3.ZERO, Vector3(1.05, 1.5, 0.62))
		Mats.mi(Mats.sphere(0.24), hair_hi, Vector3(0, -0.2, 0.2), head, Vector3.ZERO, Vector3(1.0, 1.3, 0.55))
		for sx in [-1.0, 1.0]:
			Mats.mi(Mats.capsule(0.07, 0.42), hair, Vector3(0.27 * sx, 0.1, -0.02), head, Vector3(0, 0, 8 * sx))


func _physics_process(delta: float) -> void:
	if frozen:
		return
	super(delta)


func _process(delta: float) -> void:
	_breath_t += delta
	if _torso != null:
		var b: float = 1.0 + sin(_breath_t * 2.2) * 0.012
		_torso.scale = Vector3(b, 1.0, b)
	if head != null and not frozen:
		head.rotation.x = sin(_breath_t * 1.1) * 0.03 - speed_factor * 0.08
	if wrist_screen != null:
		var mat := wrist_screen.material_override as StandardMaterial3D
		mat.emission_energy_multiplier = 2.5 + sin(_breath_t * 3.0) * 0.8
	if tank_light != null:
		tank_light.visible = fmod(_breath_t, 1.6) < 1.2


## Fin du jeu : l'air est redevenu respirable, Yassine retire son masque.
func remove_mask() -> void:
	face_under_mask.visible = true
	var tw := create_tween()
	tw.tween_property(mask_root, "position", Vector3(0, -0.4, -0.6), 0.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(mask_root, "scale", Vector3(0.01, 0.01, 0.01), 0.9)
	tw.tween_callback(func(): mask_root.visible = false)


## Mort par manque d'air : vacille, tombe à genoux puis s'effondre et reste au sol.
func collapse() -> Tween:
	frozen = true
	velocity = Vector3.ZERO
	var tw := create_tween()
	tw.tween_property(visual, "rotation:z", 0.18, 0.25).set_trans(Tween.TRANS_SINE)
	tw.tween_property(visual, "rotation:z", -0.16, 0.3).set_trans(Tween.TRANS_SINE)
	tw.tween_property(visual, "rotation:z", 0.08, 0.25).set_trans(Tween.TRANS_SINE)
	# à genoux
	tw.set_parallel(true)
	tw.tween_property(_leg_l, "rotation:x", 1.35, 0.5).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(_leg_r, "rotation:x", 1.25, 0.5).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(visual, "position:y", -0.36, 0.5).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(_arm_l, "rotation:x", -0.5, 0.5)
	tw.tween_property(_arm_r, "rotation:x", -0.7, 0.5)
	tw.tween_property(head, "rotation:x", 0.35, 0.5)
	tw.set_parallel(false)
	tw.tween_interval(0.45)
	# effondrement sur le côté
	tw.set_parallel(true)
	tw.tween_property(visual, "rotation:z", 1.42, 0.7).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(visual, "position:y", -0.12, 0.7)
	tw.tween_property(_arm_l, "rotation:x", -1.4, 0.7)
	tw.set_parallel(false)
	return tw


## Retour au point de contrôle : posture normale, contrôles réactivés.
func revive() -> void:
	visual.rotation = Vector3.ZERO
	visual.position = Vector3.ZERO
	for n in [_leg_l, _leg_r, _arm_l, _arm_r]:
		(n as Node3D).rotation = Vector3.ZERO
	head.rotation = Vector3.ZERO
	velocity = Vector3.ZERO
	frozen = false


func set_air_warning(low: bool) -> void:
	if tank_light != null:
		tank_light.material_override = Mats.emissive(Color(1.0, 0.25, 0.2) if low else Color(0.3, 1.0, 0.75), 4.0)
