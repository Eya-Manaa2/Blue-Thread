extends Node3D
## Station de tri : exactement 5 bacs à roulettes (d'après BINS_REFERENCE_Five_bins.jpg)
## PAPER bleu · TEXTILE violet · PET jaune · RESIDUAL anthracite · SPECIAL rouge.
## Chaque bac : corps évasé, couvercle articulé, poignée, roues, nervures,
## icône blanche, étiquette, anneau lumineux de surbrillance.

signal bin_clicked(bin_id: String)

const SPACING := 1.35

var bins: Dictionary = {}        # id -> {root, lid, ring, light, body_mat}
var _highlight: String = ""
var _t: float = 0.0
var _pivot: Node3D


## Les façades sont modélisées vers -Z puis tournées : en jeu elles regardent +Z
## (vers la caméra) et PAPER est à gauche, comme sur la référence.
func _ready() -> void:
	_pivot = Node3D.new()
	_pivot.rotation_degrees.y = 180.0
	add_child(_pivot)
	var slab := Mats.mat(Color(0.56, 0.55, 0.52), 0.95)
	Mats.mi(Mats.box(Vector3(SPACING * 5 + 0.8, 0.25, 1.9)), slab, Vector3(0, 0.12, 0), _pivot)
	Mats.mi(Mats.box(Vector3(SPACING * 5 + 1.0, 0.06, 2.05)), Mats.mat(Color(0.45, 0.44, 0.42), 0.95), Vector3(0, 0.02, 0), _pivot)
	var order: Array = GameData.BIN_ORDER
	for i in order.size():
		var id: String = order[i]
		var x: float = (2.0 - float(i)) * SPACING
		_build_bin(id, Vector3(x, 0.25, 0))
	# panneau d'information
	var sign_root := Node3D.new()
	sign_root.position = Vector3(-SPACING * 2.5 - 0.9, 0, 0.3)
	_pivot.add_child(sign_root)
	sign_root.rotation_degrees.y = 180.0
	Mats.mi(Mats.cyl(0.04, 0.04, 2.2, 8), Mats.mat(Color(0.3, 0.3, 0.32), 0.5, 0.7), Vector3(0, 1.1, 0), sign_root)
	Mats.mi(Mats.box(Vector3(0.9, 0.6, 0.05)), Mats.mat(Color(0.08, 0.32, 0.55), 0.6), Vector3(0, 2.0, 0), sign_root)
	var lbl := Mats.label3d("SORT\nSTATION", 46, Color(0.95, 0.97, 1.0), sign_root, Vector3(0, 2.0, 0.03))
	lbl.pixel_size = 0.0035


func _build_bin(id: String, pos: Vector3) -> void:
	var info: Dictionary = GameData.BINS[id]
	var col: Color = info.color
	var root := Node3D.new()
	root.name = id
	root.position = pos
	_pivot.add_child(root)
	var body_m := Mats.mat(col, 0.55, 0.0, 0.2).duplicate() as StandardMaterial3D
	var dark_m := Mats.mat(col.darkened(0.25), 0.6)
	var black := Mats.mat(Color(0.08, 0.08, 0.09), 0.7)
	# corps évasé
	Mats.mi(Mats.tapered_box(Vector2(0.4, 0.42), Vector2(0.5, 0.52), 1.18), body_m, Vector3(0, 0.08, 0), root)
	# nervures verticales en façade
	for k in 4:
		Mats.mi(Mats.box(Vector3(0.05, 0.16, 0.04)), dark_m, Vector3(-0.3 + k * 0.2, 1.12, -0.505), root)
	Mats.mi(Mats.box(Vector3(1.02, 0.07, 1.06)), dark_m, Vector3(0, 1.2, 0), root)
	# roues et essieu à l'arrière
	for sx in [-1.0, 1.0]:
		Mats.mi(Mats.cyl(0.11, 0.11, 0.07, 16), black, Vector3(0.38 * sx, 0.11, 0.42), root, Vector3(0, 0, 90))
	Mats.mi(Mats.cyl(0.025, 0.025, 0.8, 8), Mats.mat(Color(0.4, 0.4, 0.42), 0.4, 0.8), Vector3(0, 0.11, 0.42), root, Vector3(0, 0, 90))
	# couvercle articulé (pivot à la charnière arrière)
	var lid := Node3D.new()
	lid.position = Vector3(0, 1.25, 0.53)
	root.add_child(lid)
	Mats.mi(Mats.box(Vector3(1.06, 0.07, 1.1)), body_m, Vector3(0, 0.0, -0.55), lid)
	Mats.mi(Mats.box(Vector3(1.0, 0.05, 0.12)), dark_m, Vector3(0, 0.05, -0.98), lid)
	Mats.mi(Mats.box(Vector3(0.3, 0.04, 0.06)), dark_m, Vector3(0, 0.06, -1.08), lid)
	Mats.mi(Mats.cyl(0.04, 0.04, 1.0, 10), dark_m, Vector3(0, 0.0, 0.02), lid, Vector3(0, 0, 90))
	# poignée arrière
	Mats.mi(Mats.box(Vector3(0.8, 0.05, 0.05)), dark_m, Vector3(0, 1.18, 0.6), root)
	# icône + étiquette (blanches, comme sur la référence)
	var icon := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.48, 0.48)
	icon.mesh = q
	var im := Mats.unshaded(Color(0.97, 0.97, 0.95, 1.0), false, load(String(info.icon)))
	icon.material_override = im
	icon.position = Vector3(0, 0.72, -0.488)
	icon.rotation_degrees = Vector3(0, 180, 0)
	icon.rotation_degrees.x = -4.8
	root.add_child(icon)
	var lbl := Mats.label3d(String(info.label), 64 if String(info.label).length() < 7 else 52, Color(0.97, 0.97, 0.95), root, Vector3(0, 0.36, -0.462))
	lbl.rotation_degrees = Vector3(-4.8, 180, 0)
	lbl.pixel_size = 0.0032
	# anneau de surbrillance au sol + lumière colorée
	var ring := Mats.mi(Mats.torus(0.62, 0.7, 32), Mats.emissive(col.lightened(0.3), 3.0), Vector3(0, 0.02, -0.15), root)
	ring.visible = false
	var light := OmniLight3D.new()
	light.light_color = col.lightened(0.2)
	light.light_energy = 0.0
	light.omni_range = 3.0
	light.position = Vector3(0, 1.6, -0.9)
	root.add_child(light)
	bins[id] = {"root": root, "lid": lid, "ring": ring, "light": light, "body_mat": body_m, "base": col}


func bin_world_pos(id: String) -> Vector3:
	if not bins.has(id):
		return global_position
	return (bins[id].root as Node3D).global_position + Vector3(0, 1.3, 0)


func set_highlight(id: String) -> void:
	_highlight = id
	for k in bins.keys():
		var b: Dictionary = bins[k]
		(b.ring as Node3D).visible = k == id


func open_lid(id: String, open: bool = true) -> void:
	if not bins.has(id):
		return
	var lid: Node3D = bins[id].lid
	var tw := create_tween()
	tw.tween_property(lid, "rotation_degrees:x", 105.0 if open else 0.0, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func flash(id: String, ok: bool) -> void:
	if not bins.has(id):
		return
	var b: Dictionary = bins[id]
	var m: StandardMaterial3D = b.body_mat
	m.emission_enabled = true
	m.emission = Color(0.3, 1.0, 0.5) if ok else Color(1.0, 0.15, 0.1)
	m.emission_energy_multiplier = 1.6
	var tw := create_tween()
	tw.tween_property(m, "emission_energy_multiplier", 0.0, 0.6)
	tw.tween_callback(func(): m.emission_enabled = false)
	var root: Node3D = b.root
	var tw2 := create_tween()
	tw2.tween_property(root, "scale", Vector3(1.08, 0.92, 1.08), 0.08)
	tw2.tween_property(root, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_t += delta
	for k in bins.keys():
		var b: Dictionary = bins[k]
		var light: OmniLight3D = b.light
		var target: float = (1.6 + sin(_t * 5.0) * 0.5) if k == _highlight else 0.0
		light.light_energy = lerpf(light.light_energy, target, 1.0 - exp(-10.0 * delta))
		if k == _highlight:
			(b.ring as Node3D).rotation.y += delta * 1.5
