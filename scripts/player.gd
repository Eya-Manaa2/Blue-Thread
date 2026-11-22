extends CharacterBody3D
## Yassine : déplacement, petite animation de marche et pile de déchets sur le dos.

const SPEED := 6.5
const GRAVITY := 20.0

var input_enabled: bool = false
var joystick = null          # donné par main.gd
var visual: Node3D
var stack_root: Node3D
var speed_factor: float = 0.0
var on_step: Callable          # bruit de pas, donné par main.gd
var _last_step: int = 0

var _leg_l: Node3D
var _leg_r: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _walk_t: float = 0.0


func _ready() -> void:
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.5
	col.shape = cap
	col.position = Vector3(0, 0.75, 0)
	add_child(col)

	visual = Node3D.new()
	add_child(visual)
	_build_boy()

	stack_root = Node3D.new()
	stack_root.position = Vector3(0, 1.15, 0.4)
	visual.add_child(stack_root)


func _mat(c: Color, rough: float = 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


func _add_mesh(mesh: Mesh, m: Material, pos: Vector3, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi


func _capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	return c


func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	return s


func _build_boy() -> void:
	var hoodie := _mat(Color(0.08, 0.72, 0.86), 0.75)
	var hoodie_dark := _mat(Color(0.05, 0.55, 0.68), 0.75)
	var jeans := _mat(Color(0.2, 0.3, 0.5), 0.85)
	var jeans_light := _mat(Color(0.35, 0.48, 0.7), 0.85)
	var skin := _mat(Color(0.96, 0.78, 0.62), 0.6)
	var hair := _mat(Color(0.45, 0.24, 0.1), 0.7)
	var shoe := _mat(Color(0.1, 0.62, 0.68), 0.5)
	var sole := _mat(Color(0.97, 0.97, 0.97), 0.6)
	var white := _mat(Color(1, 1, 1), 0.3)
	var black := _mat(Color(0.04, 0.03, 0.03), 0.2)

	# Jambes (pivot à la hanche pour la marche) — proportions « dessin animé »
	_leg_l = Node3D.new()
	_leg_l.position = Vector3(-0.11, 0.5, 0)
	visual.add_child(_leg_l)
	_leg_r = Node3D.new()
	_leg_r.position = Vector3(0.11, 0.5, 0)
	visual.add_child(_leg_r)
	for leg in [_leg_l, _leg_r]:
		_add_mesh(_capsule(0.095, 0.46), jeans, Vector3(0, -0.2, 0), leg)
		var cuff := CylinderMesh.new()
		cuff.top_radius = 0.105
		cuff.bottom_radius = 0.105
		cuff.height = 0.07
		_add_mesh(cuff, jeans_light, Vector3(0, -0.37, 0), leg)
		var shoe_mesh := BoxMesh.new()
		shoe_mesh.size = Vector3(0.17, 0.11, 0.3)
		_add_mesh(shoe_mesh, shoe, Vector3(0, -0.45, -0.04), leg)
		var sole_mesh := BoxMesh.new()
		sole_mesh.size = Vector3(0.18, 0.04, 0.31)
		_add_mesh(sole_mesh, sole, Vector3(0, -0.51, -0.04), leg)

	# Corps : sweat à capuche, poche, cordons
	_add_mesh(_capsule(0.24, 0.64), hoodie, Vector3(0, 0.8, 0), visual)
	var pocket := BoxMesh.new()
	pocket.size = Vector3(0.3, 0.13, 0.05)
	_add_mesh(pocket, hoodie_dark, Vector3(0, 0.7, -0.22), visual)
	var hood := _add_mesh(_sphere(0.2), hoodie_dark, Vector3(0, 1.06, 0.15), visual)
	hood.scale = Vector3(1.2, 0.7, 0.9)
	for sx in [-0.06, 0.06]:
		_add_mesh(_capsule(0.012, 0.18), white, Vector3(sx, 0.95, -0.23), visual)

	# Bras
	_arm_l = Node3D.new()
	_arm_l.position = Vector3(-0.29, 1.0, 0)
	visual.add_child(_arm_l)
	_arm_r = Node3D.new()
	_arm_r.position = Vector3(0.29, 1.0, 0)
	visual.add_child(_arm_r)
	for arm in [_arm_l, _arm_r]:
		_add_mesh(_capsule(0.075, 0.44), hoodie, Vector3(0, -0.18, 0), arm)
		_add_mesh(_sphere(0.075), skin, Vector3(0, -0.42, 0), arm)

	# Grosse tête, oreilles, yeux expressifs
	_add_mesh(_sphere(0.34), skin, Vector3(0, 1.42, 0), visual)
	_add_mesh(_sphere(0.07), skin, Vector3(-0.33, 1.42, 0.02), visual)
	_add_mesh(_sphere(0.07), skin, Vector3(0.33, 1.42, 0.02), visual)
	for ex in [-0.12, 0.12]:
		var eye := _add_mesh(_sphere(0.075), white, Vector3(ex, 1.45, -0.29), visual)
		eye.scale = Vector3(1.0, 1.15, 0.5)
		_add_mesh(_sphere(0.045), black, Vector3(ex, 1.44, -0.325), visual)
		_add_mesh(_sphere(0.014), white, Vector3(ex + 0.015, 1.46, -0.345), visual)
	_add_mesh(_sphere(0.03), skin, Vector3(0, 1.37, -0.335), visual)

	# Cheveux châtains avec une mèche en l'air
	var hair_main := _add_mesh(_sphere(0.36), hair, Vector3(0, 1.53, 0.05), visual)
	hair_main.scale = Vector3(1.0, 0.78, 1.05)
	var fringe := _add_mesh(_sphere(0.2), hair, Vector3(0.05, 1.68, -0.2), visual)
	fringe.scale = Vector3(1.4, 0.6, 0.9)
	var tuft := _add_mesh(_capsule(0.06, 0.3), hair, Vector3(0.02, 1.86, -0.08), visual)
	tuft.rotation_degrees = Vector3(-35, 0, 15)
	var tuft2 := _add_mesh(_capsule(0.05, 0.24), hair, Vector3(-0.08, 1.84, 0.0), visual)
	tuft2.rotation_degrees = Vector3(-20, 0, -25)


func _physics_process(delta: float) -> void:
	var dir: Vector2 = Vector2.ZERO
	if input_enabled:
		dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if joystick != null:
			var jo: Vector2 = joystick.output
			if jo.length() > 0.1:
				dir = jo
	if dir.length() > 1.0:
		dir = dir.normalized()

	var k: float = 1.0 - exp(-12.0 * delta)
	velocity.x = lerpf(velocity.x, dir.x * SPEED, k)
	velocity.z = lerpf(velocity.z, dir.y * SPEED, k)
	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()

	var hv := Vector2(velocity.x, velocity.z)
	speed_factor = clampf(hv.length() / SPEED, 0.0, 1.0)
	if hv.length() > 0.3:
		var target_yaw: float = atan2(-velocity.x, -velocity.z)
		visual.rotation.y = lerp_angle(visual.rotation.y, target_yaw, 1.0 - exp(-12.0 * delta))
		_walk_t += delta * (4.0 + 8.0 * speed_factor)
		var step_i: int = int(_walk_t / PI)
		if step_i != _last_step:
			_last_step = step_i
			if speed_factor > 0.3 and on_step.is_valid():
				on_step.call()

	var sw: float = sin(_walk_t) * speed_factor * 0.75
	_leg_l.rotation.x = sw
	_leg_r.rotation.x = -sw
	_arm_l.rotation.x = -sw * 0.8
	_arm_r.rotation.x = sw * 0.8
	visual.position.y = absf(sin(_walk_t)) * 0.07 * speed_factor

	# La pile oscille quand Yassine court
	var lean: float = speed_factor * 0.16 + sin(_walk_t * 2.0) * 0.05 * speed_factor
	stack_root.rotation.x = lerpf(stack_root.rotation.x, lean, 1.0 - exp(-8.0 * delta))
	stack_root.rotation.z = sin(_walk_t) * 0.06 * speed_factor
