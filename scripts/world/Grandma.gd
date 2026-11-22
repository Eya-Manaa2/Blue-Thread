extends Node3D
## Mima — grand-mère tunisienne, refaite pour la fin (même style « film
## d'animation » arrondi que le petit-fils, mêmes proportions).
##  - Visage : yeux expressifs (blanc, iris brun, pupille, reflet, paupières
##    qui clignent), sourcils gris, nez fin, rides douces (front, pattes
##    d'oie), bouche neutre / sourire. Aucun volume ajouté sur les joues.
##  - Foulard crème à bordure brodée bleue et rouge, mèches grises,
##    châle (sefsari) sur les épaules, longue robe bordeaux brodée, mains.
##  - Animations procédurales : respiration, clignements, tête qui suit une
##    cible (look_at_point), mains qui bougent un peu, sourire, prendre la main.
## Modèle 100 % procédural (aucun modèle riggé externe n'est utilisé).
## Elle regarde vers -Z, comme le personnage joueur.

var head: Node3D
var _torso: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _fore_l: Node3D
var _fore_r: Node3D
var _lids: Array = []
var _mouth_neutral: Node3D
var _mouth_smile: Node3D
var _brows: Array = []
var _t: float = 0.0
var _blink_t: float = 2.0
var _look_target: Variant = null      # Vector3 (monde) ou null
var _hold_hand: bool = false
var _hug: bool = false
var _smile: float = 0.0
var _smile_target: float = 0.0
var _wonder: float = 0.0              # yeux un peu plus ouverts (émerveillement)
var _wonder_target: float = 0.0


func _ready() -> void:
	var skin_c := Color(0.80, 0.60, 0.47)
	var skin := Mats.mat(skin_c, 0.55, 0.0, 0.2)
	var wrinkle := Mats.mat(skin_c.darkened(0.30), 0.7)
	var dress := Mats.mat(Color(0.46, 0.13, 0.18), 0.9, 0.0, 0.15)
	var dress_dk := Mats.mat(Color(0.34, 0.09, 0.13), 0.9)
	var gold := Mats.mat(Color(0.86, 0.68, 0.30), 0.4, 0.6)
	var shawl := Mats.mat(Color(0.66, 0.54, 0.42), 0.95, 0.0, 0.15)
	var shawl_dk := Mats.mat(Color(0.56, 0.45, 0.35), 0.95)
	var scarf := Mats.mat(Color(0.80, 0.74, 0.63), 0.92, 0.0, 0.15)
	var scarf_dk := Mats.mat(Color(0.70, 0.63, 0.52), 0.92)
	var emb_blue := Mats.mat(Color(0.12, 0.38, 0.74), 0.7)
	var emb_red := Mats.mat(Color(0.74, 0.16, 0.20), 0.7)
	var hair := Mats.mat(Color(0.82, 0.82, 0.80), 0.8)
	var shoe := Mats.mat(Color(0.22, 0.16, 0.12), 0.7)

	Mats.blob(self, 0.34)
	# --- robe longue (jebba) et chaussures
	Mats.mi(Mats.cyl(0.21, 0.30, 0.92, 24), dress, Vector3(0, 0.50, 0), self)
	Mats.mi(Mats.torus(0.285, 0.305, 32), gold, Vector3(0, 0.10, 0), self)
	Mats.mi(Mats.torus(0.27, 0.285, 32), emb_blue, Vector3(0, 0.15, 0), self)
	for k in 10:
		var a: float = TAU * k / 10.0
		Mats.mi(Mats.sphere(0.018, -1.0, 6), gold, Vector3(cos(a) * 0.29, 0.125, sin(a) * 0.29), self)
	for sx in [-1.0, 1.0]:
		Mats.mi(Mats.sphere(0.07, -1.0, 12), shoe, Vector3(0.09 * sx, 0.035, -0.12), self, Vector3.ZERO, Vector3(0.9, 0.55, 1.5))

	# --- buste (respire)
	_torso = Node3D.new()
	_torso.position = Vector3(0, 0.95, 0)
	add_child(_torso)
	Mats.mi(Mats.capsule(0.19, 0.55), dress, Vector3(0, 0.12, 0), _torso, Vector3.ZERO, Vector3(1.08, 1.0, 0.85))
	Mats.mi(Mats.box(Vector3(0.10, 0.22, 0.02)), dress_dk, Vector3(0, 0.12, -0.165), _torso)
	for k in 4:
		Mats.mi(Mats.sphere(0.012, -1.0, 6), gold, Vector3(0, 0.03 + k * 0.055, -0.175), _torso)
	# châle (sefsari) sur les épaules, qui tombe dans le dos
	Mats.mi(Mats.cyl(0.17, 0.27, 0.36, 24), shawl, Vector3(0, 0.22, 0.02), _torso)
	Mats.mi(Mats.cyl(0.26, 0.30, 0.55, 24), shawl_dk, Vector3(0, -0.12, 0.07), _torso, Vector3(-6, 0, 0), Vector3(1.0, 1.0, 0.7))
	Mats.mi(Mats.torus(0.255, 0.275, 32), emb_red, Vector3(0, 0.05, 0.02), _torso, Vector3.ZERO, Vector3(1.0, 1.0, 0.9))

	# --- bras (épaule -> coude -> main), pivots animables
	_arm_l = _make_arm(-1.0, shawl, skin, wrinkle)
	_arm_r = _make_arm(1.0, shawl, skin, wrinkle)
	_fore_l = _arm_l.get_node("Fore")
	_fore_r = _arm_r.get_node("Fore")

	# --- tête
	head = Node3D.new()
	head.position = Vector3(0, 0.52, -0.01)
	# (22/11) tête agrandie : même style « gros visage expressif » que le
	# petit-fils (son visage paraissait minuscule dans le foulard)
	head.scale = Vector3.ONE * 1.6
	_torso.add_child(head)
	Mats.mi(Mats.cyl(0.055, 0.065, 0.12, 12), skin, Vector3(0, -0.11, 0.01), head)
	Mats.mi(Mats.sphere(0.155, -1.0, 28), skin, Vector3(0, 0.03, 0), head, Vector3.ZERO, Vector3(0.95, 1.08, 0.98))
	# (22/11) aucun ajout sur les joues ni le menton : seulement son vieux
	# visage (ovale lisse, rides, nez, yeux, bouche).
	# nez fin, petit bout arrondi
	Mats.mi(Mats.capsule(0.017, 0.062), skin, Vector3(0, 0.018, -0.149), head, Vector3(16, 0, 0))
	Mats.mi(Mats.sphere(0.019, -1.0, 14), skin, Vector3(0, -0.008, -0.156), head, Vector3.ZERO, Vector3(1.15, 0.9, 0.9))
	# yeux expressifs
	for sx in [-1.0, 1.0]:
		var eye := Node3D.new()
		eye.position = Vector3(0.056 * sx, 0.045, -0.128)
		head.add_child(eye)
		Mats.mi(Mats.sphere(0.025, -1.0, 16), Mats.mat(Color(0.97, 0.95, 0.92), 0.3), Vector3.ZERO, eye, Vector3.ZERO, Vector3(1.2, 1.0, 0.62))
		Mats.mi(Mats.sphere(0.0145, -1.0, 14), Mats.mat(Color(0.40, 0.25, 0.13), 0.3), Vector3(0, -0.001, -0.0125), eye, Vector3.ZERO, Vector3(1, 1, 0.45))
		Mats.mi(Mats.sphere(0.007, -1.0, 10), Mats.mat(Color(0.03, 0.02, 0.02), 0.2), Vector3(0, -0.001, -0.0175), eye, Vector3.ZERO, Vector3(1, 1, 0.5))
		Mats.mi(Mats.sphere(0.0032, -1.0, 6), Mats.emissive(Color(1, 1, 1), 1.5), Vector3(0.0045, 0.005, -0.0205), eye)
		# paupière supérieure (cligne) + paupière inférieure un peu lourde
		var lid := Node3D.new()
		lid.position = Vector3(0, 0.022, 0)
		eye.add_child(lid)
		Mats.mi(Mats.sphere(0.027, -1.0, 14), skin, Vector3(0, -0.012, 0.002), lid, Vector3.ZERO, Vector3(1.25, 0.55, 0.85))
		lid.scale = Vector3(1, 0.35, 1)
		_lids.append(lid)
		Mats.mi(Mats.sphere(0.026, -1.0, 12), skin, Vector3(0, -0.02, 0.003), eye, Vector3.ZERO, Vector3(1.25, 0.35, 0.8))
		# sourcils gris, doux
		var bpts := Mats.bezier(Vector3(-0.026, 0.0, 0), Vector3(-0.01, 0.012, -0.004), Vector3(0.012, 0.012, -0.004), Vector3(0.028, 0.002, 0), 8)
		var brow := Node3D.new()
		brow.position = Vector3(0.056 * sx, 0.083, -0.135)
		head.add_child(brow)
		Mats.mi(Mats.tube(bpts, 0.0045, 5), hair, Vector3.ZERO, brow)
		_brows.append(brow)
		# pattes d'oie
		for k in 3:
			var cp := Mats.bezier(Vector3(0, 0, 0), Vector3(0.008 * sx, 0.002, 0.004), Vector3(0.016 * sx, 0.001, 0.008), Vector3(0.024 * sx, -0.004 + k * 0.006 - 0.004, 0.012), 5)
			Mats.mi(Mats.tube(cp, 0.0012, 4), wrinkle, Vector3(0.088 * sx, 0.04 + (k - 1) * 0.008, -0.104), head)
	# rides du front
	for k in 2:
		var fp := Mats.bezier(Vector3(-0.05, 0.11 + k * 0.016, -0.133 + k * 0.004), Vector3(-0.02, 0.116 + k * 0.016, -0.14), Vector3(0.02, 0.116 + k * 0.016, -0.14), Vector3(0.05, 0.11 + k * 0.016, -0.133 + k * 0.004), 10)
		Mats.mi(Mats.tube(fp, 0.0018, 4), wrinkle, Vector3.ZERO, head)
	# bouche : neutre (douce) et sourire (fin)
	var lip := Mats.mat(Color(0.62, 0.36, 0.33), 0.55)
	_mouth_neutral = Node3D.new()
	head.add_child(_mouth_neutral)
	var mn := Mats.bezier(Vector3(-0.028, -0.062, -0.142), Vector3(-0.01, -0.066, -0.149), Vector3(0.01, -0.066, -0.149), Vector3(0.028, -0.062, -0.142), 10)
	Mats.mi(Mats.tube(mn, 0.0045, 5), lip, Vector3.ZERO, _mouth_neutral)
	_mouth_smile = Node3D.new()
	head.add_child(_mouth_smile)
	var ms := Mats.bezier(Vector3(-0.034, -0.054, -0.139), Vector3(-0.015, -0.072, -0.149), Vector3(0.015, -0.072, -0.149), Vector3(0.034, -0.054, -0.139), 12)
	Mats.mi(Mats.tube(ms, 0.005, 6), lip, Vector3.ZERO, _mouth_smile)
	_mouth_smile.visible = false

	# --- foulard noué (laisse tout le visage dégagé) : il couvre le haut et
	# l'arrière de la tête, encadre les joues et se noue sous le menton.
	for sx in [-1.0, 1.0]:
		Mats.mi(Mats.capsule(0.012, 0.05), hair, Vector3(0.07 * sx, 0.115, -0.118), head, Vector3(0, 0, 60 * sx))
	Mats.mi(Mats.sphere(0.168, -1.0, 28), scarf, Vector3(0, 0.07, 0.06), head, Vector3.ZERO, Vector3(1.02, 1.0, 1.0))
	# bord du foulard sur le front, en arc (pas d'anneau autour du visage)
	var edge := Mats.bezier(Vector3(-0.13, 0.0, -0.06), Vector3(-0.08, 0.14, -0.13), Vector3(0.08, 0.14, -0.13), Vector3(0.13, 0.0, -0.06), 16)
	Mats.mi(Mats.tube(edge, 0.018, 8), scarf_dk, Vector3(0, 0.03, 0), head)
	for k in 7:
		var tt: float = float(k + 1) / 8.0
		var u: float = 1.0 - tt
		var ep: Vector3 = Vector3(-0.13, 0.0, -0.06) * u * u * u + Vector3(-0.08, 0.14, -0.13) * 3.0 * u * u * tt + Vector3(0.08, 0.14, -0.13) * 3.0 * u * tt * tt + Vector3(0.13, 0.0, -0.06) * tt * tt * tt
		Mats.mi(Mats.sphere(0.007, -1.0, 6), emb_red if k % 2 == 0 else emb_blue, ep + Vector3(0, 0.03, -0.015), head)
	# pans du foulard le long des joues jusqu'au nœud sous le menton
	for sx in [-1.0, 1.0]:
		var side := Mats.bezier(Vector3(0.13 * sx, 0.03, -0.05), Vector3(0.14 * sx, -0.05, -0.07), Vector3(0.10 * sx, -0.13, -0.07), Vector3(0.03 * sx, -0.16, -0.06), 12)
		Mats.mi(Mats.tube(side, 0.03, 8), scarf, Vector3.ZERO, head)
	Mats.mi(Mats.sphere(0.03, -1.0, 10), scarf_dk, Vector3(0, -0.17, -0.06), head)
	# le foulard tombe sur la nuque et les épaules
	Mats.mi(Mats.cyl(0.10, 0.20, 0.20, 24), scarf, Vector3(0, -0.15, 0.06), head)
	Mats.mi(Mats.torus(0.19, 0.205, 32), emb_blue, Vector3(0, -0.245, 0.06), head)


func _make_arm(sx: float, sleeve: Material, skin: Material, wrinkle: Material) -> Node3D:
	var arm := Node3D.new()
	arm.name = "ArmL" if sx < 0 else "ArmR"
	arm.position = Vector3(0.22 * sx, 0.30, 0.0)
	arm.rotation_degrees = Vector3(0, 0, 8 * sx)
	_torso.add_child(arm)
	Mats.mi(Mats.capsule(0.06, 0.32), sleeve, Vector3(0, -0.14, 0), arm)
	var fore := Node3D.new()
	fore.name = "Fore"
	fore.position = Vector3(0, -0.28, 0)
	fore.rotation_degrees = Vector3(40, 0, 0)
	arm.add_child(fore)
	Mats.mi(Mats.capsule(0.052, 0.28), sleeve, Vector3(0, -0.12, 0), fore)
	Mats.mi(Mats.cyl(0.056, 0.05, 0.04, 12), Mats.mat(Color(0.12, 0.38, 0.74), 0.7), Vector3(0, -0.25, 0), fore)
	# main : paume + doigts courts
	var hand := Node3D.new()
	hand.position = Vector3(0, -0.30, 0)
	fore.add_child(hand)
	Mats.mi(Mats.sphere(0.042, -1.0, 12), skin, Vector3.ZERO, hand, Vector3.ZERO, Vector3(0.85, 1.0, 0.55))
	for k in 4:
		Mats.mi(Mats.capsule(0.009, 0.05), skin, Vector3(-0.018 + k * 0.012, -0.045, -0.004), hand)
	Mats.mi(Mats.capsule(0.01, 0.04), skin, Vector3(0.03 * -sx, -0.015, -0.015), hand, Vector3(0, 0, 40 * sx))
	Mats.mi(Mats.box(Vector3(0.03, 0.002, 0.002)), wrinkle, Vector3(0, 0.01, -0.023), hand)
	return arm


## Regarder un point du monde (le petit-fils, la mer…) ; null = regard libre
func look_at_point(p: Variant) -> void:
	_look_target = p


func smile(on: bool = true) -> void:
	_smile_target = 1.0 if on else 0.0


func wonder(on: bool = true) -> void:
	_wonder_target = 1.0 if on else 0.0


## Donner la main droite à l'enfant placé à sa droite (côte à côte, fin)
func hold_hand(on: bool = true) -> void:
	_hold_hand = on


## Câlin : les deux bras entourent l'enfant placé face à elle
func hug(on: bool = true) -> void:
	_hug = on


func _process(delta: float) -> void:
	_t += delta
	# respiration douce
	if _torso != null:
		var b: float = 1.0 + sin(_t * 1.6) * 0.012
		_torso.scale = Vector3(b, 1.0 + sin(_t * 1.6) * 0.006, b)
	# clignements naturels (toutes les 2,5 à 5 s)
	_blink_t -= delta
	var lid_open: float = lerpf(0.35, 0.18, _wonder)
	var lid_y: float = lid_open
	if _blink_t < 0.0:
		var k: float = -_blink_t / 0.16
		lid_y = lerpf(lid_open, 1.05, sin(clampf(k, 0.0, 1.0) * PI))
		if _blink_t < -0.16:
			_blink_t = randf_range(2.5, 5.0)
	for lid in _lids:
		(lid as Node3D).scale.y = lid_y
	# sourire progressif ; sourcils qui se lèvent un peu
	_smile = move_toward(_smile, _smile_target, delta * 1.5)
	_wonder = move_toward(_wonder, _wonder_target, delta * 1.2)
	if _mouth_smile != null:
		_mouth_smile.visible = _smile > 0.5
		_mouth_neutral.visible = _smile <= 0.5
	for i in _brows.size():
		var br: Node3D = _brows[i]
		br.position.y = 0.083 + 0.008 * maxf(_wonder, _smile * 0.5)
	# tête : suit la cible, sinon petit mouvement naturel
	if head != null:
		var yaw: float = sin(_t * 0.5) * 0.08
		var pitch: float = sin(_t * 0.8) * 0.03
		if _look_target != null:
			var tp: Vector3 = _look_target
			var d: Vector3 = tp - head.global_position
			var local_d: Vector3 = global_transform.basis.inverse() * d
			yaw = clampf(atan2(-local_d.x, -local_d.z), -0.9, 0.9)
			pitch = clampf(atan2(local_d.y, Vector2(local_d.x, local_d.z).length()), -0.4, 0.3)
		head.rotation.y = lerp_angle(head.rotation.y, yaw, 1.0 - exp(-3.0 * delta))
		head.rotation.x = lerpf(head.rotation.x, pitch, 1.0 - exp(-3.0 * delta))
	# mains : légers mouvements, ou main tendue vers l'enfant
	if _arm_r != null:
		var k: float = 1.0 - exp(-3.0 * delta)
		var rx: float = 4.0 + sin(_t * 0.9) * 3.0
		var rz: float = 8.0
		var rf: float = 40.0 + sin(_t * 1.1) * 4.0
		var lx: float = 4.0 + sin(_t * 0.8 + 1.0) * 3.0
		var lz: float = -8.0
		var lf: float = 42.0 + sin(_t * 1.0 + 0.5) * 4.0
		if _hug:
			# bras levés vers l'avant puis refermés autour de l'enfant
			rx = 68.0; rz = -32.0; rf = 55.0
			lx = 68.0; lz = 32.0; lf = 55.0
		elif _hold_hand:
			rx = 14.0; rz = 24.0; rf = 12.0
		_arm_r.rotation_degrees.x = lerpf(_arm_r.rotation_degrees.x, rx, k)
		_arm_r.rotation_degrees.z = lerpf(_arm_r.rotation_degrees.z, rz, k)
		_fore_r.rotation_degrees.x = lerpf(_fore_r.rotation_degrees.x, rf, k)
		_arm_l.rotation_degrees.x = lerpf(_arm_l.rotation_degrees.x, lx, k)
		_arm_l.rotation_degrees.z = lerpf(_arm_l.rotation_degrees.z, lz, k)
		_fore_l.rotation_degrees.x = lerpf(_fore_l.rotation_degrees.x, lf, k)
