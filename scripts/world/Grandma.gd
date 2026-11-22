extends Node3D
## Mima, la grand-mère : assise sur une chaise en bois, enveloppée dans un
## sefsari crème, foulard sur la tête, petites lunettes rondes, une pelote
## de laine bleue — « le dernier fil bleu » — sur les genoux.

var head: Node3D
var yarn: Node3D
var _t: float = 0.0


func _ready() -> void:
	var wood := Mats.mat(Color(0.45, 0.30, 0.18), 0.8)
	var sefsari := Mats.mat(Color(0.93, 0.89, 0.80), 0.95, 0.0, 0.2)
	var sefsari_sh := Mats.mat(Color(0.84, 0.79, 0.70), 0.95)
	var dress := Mats.mat(Color(0.55, 0.20, 0.22), 0.9)
	var skin := Mats.mat(Color(0.80, 0.60, 0.46), 0.6, 0.0, 0.15)
	var dark := Mats.mat(Color(0.12, 0.10, 0.09), 0.4)
	var metal := Mats.mat(Color(0.75, 0.65, 0.35), 0.3, 0.9)
	var blue := Mats.mat(Color(0.16, 0.48, 0.95), 0.85, 0.0, 0.35)

	# chaise
	Mats.mi(Mats.box(Vector3(0.62, 0.06, 0.58)), wood, Vector3(0, 0.48, 0), self)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			Mats.mi(Mats.box(Vector3(0.05, 0.48, 0.05)), wood, Vector3(0.27 * sx, 0.24, 0.25 * sz), self)
		Mats.mi(Mats.box(Vector3(0.05, 0.62, 0.05)), wood, Vector3(0.27 * sx, 0.8, 0.25), self)
	for k in 3:
		Mats.mi(Mats.box(Vector3(0.56, 0.05, 0.03)), wood, Vector3(0, 0.75 + k * 0.17, 0.26), self)

	# corps assis, enveloppé dans le sefsari
	Mats.mi(Mats.capsule(0.11, 0.42), dress, Vector3(-0.1, 0.52, -0.18), self, Vector3(90, 0, 0))
	Mats.mi(Mats.capsule(0.11, 0.42), dress, Vector3(0.1, 0.52, -0.18), self, Vector3(90, 0, 0))
	Mats.mi(Mats.capsule(0.08, 0.42), dress, Vector3(-0.1, 0.25, -0.36), self)
	Mats.mi(Mats.capsule(0.08, 0.42), dress, Vector3(0.1, 0.25, -0.36), self)
	Mats.mi(Mats.box(Vector3(0.12, 0.06, 0.2)), dark, Vector3(-0.1, 0.03, -0.42), self)
	Mats.mi(Mats.box(Vector3(0.12, 0.06, 0.2)), dark, Vector3(0.1, 0.03, -0.42), self)
	Mats.mi(Mats.capsule(0.25, 0.7), sefsari, Vector3(0, 0.88, 0.02), self, Vector3.ZERO, Vector3(1.0, 1.0, 0.85))
	Mats.mi(Mats.cyl(0.28, 0.36, 0.5, 20), sefsari_sh, Vector3(0, 0.62, -0.08), self, Vector3(-18, 0, 0))
	for sx in [-1.0, 1.0]:
		Mats.mi(Mats.capsule(0.075, 0.38), sefsari, Vector3(0.24 * sx, 0.86, -0.08), self, Vector3(-55, 0, 18 * sx))
		Mats.mi(Mats.sphere(0.06), skin, Vector3(0.12 * sx, 0.72, -0.27), self)

	# pelote bleue et fil qui pend
	yarn = Node3D.new()
	yarn.position = Vector3(0, 0.74, -0.3)
	add_child(yarn)
	Mats.mi(Mats.sphere(0.1), blue, Vector3.ZERO, yarn)
	for k in 3:
		Mats.mi(Mats.torus(0.095, 0.105), blue, Vector3.ZERO, yarn, Vector3(k * 60, k * 40, 0))
	var thread := Mats.bezier(Vector3(0.05, -0.05, -0.05), Vector3(0.2, -0.3, -0.15), Vector3(0.1, -0.5, -0.2), Vector3(0.3, -0.72, -0.25), 16)
	Mats.mi(Mats.tube(thread, 0.008, 5), Mats.emissive(Color(0.3, 0.65, 1.0), 1.5), Vector3.ZERO, yarn)

	# tête
	head = Node3D.new()
	head.position = Vector3(0, 1.3, -0.02)
	add_child(head)
	Mats.mi(Mats.sphere(0.2), skin, Vector3.ZERO, head)
	Mats.mi(Mats.sphere(0.035), skin, Vector3(0, -0.02, -0.2), head)
	for sx in [-1.0, 1.0]:
		var eye := Mats.bezier(Vector3(-0.035, 0.03, -0.185), Vector3(-0.012, 0.012, -0.195), Vector3(0.012, 0.012, -0.195), Vector3(0.035, 0.03, -0.185), 6)
		for i in eye.size():
			eye[i] = eye[i] + Vector3(0.075 * sx, 0, 0)
		Mats.mi(Mats.tube(eye, 0.006, 5), dark, Vector3.ZERO, head)
		Mats.mi(Mats.torus(0.038, 0.046), metal, Vector3(0.075 * sx, 0.025, -0.2), head, Vector3(90, 0, 0))
	Mats.mi(Mats.box(Vector3(0.05, 0.006, 0.006)), metal, Vector3(0, 0.03, -0.205), head)
	var smile := Mats.bezier(Vector3(-0.05, -0.08, -0.175), Vector3(-0.02, -0.105, -0.19), Vector3(0.02, -0.105, -0.19), Vector3(0.05, -0.08, -0.175), 8)
	Mats.mi(Mats.tube(smile, 0.007, 5), Mats.mat(Color(0.5, 0.25, 0.2), 0.6), Vector3.ZERO, head)
	# foulard + pan du sefsari sur la tête
	# (décalés vers l'arrière pour laisser le visage dégagé)
	Mats.mi(Mats.sphere(0.215), sefsari, Vector3(0, 0.06, 0.09), head, Vector3.ZERO, Vector3(1.08, 1.05, 1.0))
	Mats.mi(Mats.cyl(0.17, 0.3, 0.45, 18), sefsari, Vector3(0, -0.32, 0.08), head)
	Mats.mi(Mats.torus(0.17, 0.215), Mats.mat(Color(0.75, 0.2, 0.25), 0.8), Vector3(0, 0.1, 0.02), head, Vector3(70, 0, 0))


func _process(delta: float) -> void:
	_t += delta
	if head != null:
		head.rotation.y = sin(_t * 0.6) * 0.12
		head.rotation.x = sin(_t * 0.9) * 0.04
	if yarn != null:
		yarn.rotation.y += delta * 0.4
