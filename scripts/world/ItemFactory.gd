class_name ItemFactory
## Modèles 3D procéduraux des objets à trier et des récompenses.
## Chaque modèle est centré, posé autour de l'origine, taille ~0,3-0,5 m.


static func build(item_id: String) -> Node3D:
	var it: Dictionary = GameData.item(item_id)
	var root := Node3D.new()
	root.name = item_id
	var c: Color = it.get("color", Color.WHITE)
	var shape: String = String(it.get("shape", "box"))
	var m := Mats.mat(c, 0.8, 0.0, 0.15)
	match shape:
		"sheet":
			Mats.mi(Mats.box(Vector3(0.46, 0.03, 0.34)), m, Vector3.ZERO, root, Vector3(0, 0, 3))
			Mats.mi(Mats.box(Vector3(0.44, 0.03, 0.32)), Mats.mat(c.darkened(0.08), 0.85), Vector3(0.02, 0.03, 0.01), root, Vector3(0, 12, -2))
			var ink := Mats.mat(Color(0.2, 0.2, 0.22), 0.9)
			if item_id == "magazine":
				Mats.mi(Mats.box(Vector3(0.2, 0.005, 0.14)), Mats.mat(Color(0.95, 0.85, 0.3), 0.6), Vector3(-0.05, 0.05, -0.03), root, Vector3(0, 12, 0))
			for k in 4:
				Mats.mi(Mats.box(Vector3(0.3, 0.004, 0.018)), ink, Vector3(0.03, 0.047, -0.09 + k * 0.055), root, Vector3(0, 12, 0))
		"box":
			Mats.mi(Mats.box(Vector3(0.42, 0.3, 0.32)), m, Vector3(0, 0.15, 0), root)
			Mats.mi(Mats.box(Vector3(0.43, 0.012, 0.07)), Mats.mat(Color(0.86, 0.72, 0.45), 0.5), Vector3(0, 0.305, 0), root)
			if item_id == "egg_carton":
				for k in 3:
					Mats.mi(Mats.sphere(0.06), m, Vector3(-0.13 + k * 0.13, 0.32, 0), root, Vector3.ZERO, Vector3(1, 0.5, 1))
			else:
				Mats.mi(Mats.box(Vector3(0.2, 0.012, 0.32)), Mats.mat(c.lightened(0.08), 0.85), Vector3(-0.1, 0.31, 0), root, Vector3(0, 0, 18))
		"bag":
			Mats.mi(Mats.box(Vector3(0.3, 0.38, 0.18)), m, Vector3(0, 0.19, 0), root)
			Mats.mi(Mats.box(Vector3(0.31, 0.06, 0.19)), Mats.mat(c.darkened(0.12), 0.85), Vector3(0, 0.36, 0), root)
			Mats.mi(Mats.torus(0.06, 0.075), Mats.mat(c.darkened(0.25), 0.8), Vector3(0, 0.42, 0), root, Vector3(90, 0, 0), Vector3(1, 1, 1.6))
		"stack":
			for k in 5:
				Mats.mi(Mats.box(Vector3(0.36, 0.022, 0.26)), m, Vector3(0, 0.012 + k * 0.024, 0), root, Vector3(0, k * 7 - 14, 0))
		"tshirt", "sweater":
			var long := shape == "sweater"
			Mats.mi(Mats.box(Vector3(0.36, 0.42, 0.07)), m, Vector3(0, 0.21, 0), root)
			for sx in [-1.0, 1.0]:
				var sl := Mats.mi(Mats.box(Vector3(0.24 if long else 0.15, 0.12, 0.065)), m, Vector3(0.24 * sx if long else 0.22 * sx, 0.36 if not long else 0.3, 0), root)
				sl.rotation_degrees = Vector3(0, 0, -35.0 * sx if not long else -55.0 * sx)
			Mats.mi(Mats.torus(0.05, 0.075), Mats.mat(c.darkened(0.2), 0.9), Vector3(0, 0.42, 0), root, Vector3(90, 0, 0), Vector3(1, 1, 0.6))
			if long:
				for k in 3:
					Mats.mi(Mats.box(Vector3(0.37, 0.02, 0.075)), Mats.mat(c.lightened(0.15), 0.9), Vector3(0, 0.05 + k * 0.03, 0), root)
		"pants":
			Mats.mi(Mats.box(Vector3(0.34, 0.1, 0.08)), m, Vector3(0, 0.5, 0), root)
			for sx in [-1.0, 1.0]:
				Mats.mi(Mats.box(Vector3(0.15, 0.48, 0.075)), m, Vector3(0.09 * sx, 0.22, 0), root, Vector3(0, 0, 4 * sx))
			Mats.mi(Mats.box(Vector3(0.35, 0.02, 0.085)), Mats.mat(Color(0.75, 0.55, 0.2), 0.5), Vector3(0, 0.54, 0), root)
		"scarf":
			for k in 6:
				var stripe := Mats.mat(c if k % 2 == 0 else Color(0.9, 0.9, 0.95), 0.95)
				Mats.mi(Mats.box(Vector3(0.12, 0.05, 0.1)), stripe, Vector3(-0.3 + k * 0.12, 0.03 + absf(sin(k * 1.1)) * 0.06, sin(k * 0.9) * 0.08), root, Vector3(0, k * 14, 0))
		"sock":
			Mats.mi(Mats.capsule(0.06, 0.28), m, Vector3(0, 0.18, 0), root)
			Mats.mi(Mats.capsule(0.06, 0.2), m, Vector3(0, 0.05, -0.08), root, Vector3(90, 0, 0))
			Mats.mi(Mats.cyl(0.065, 0.065, 0.05), Mats.mat(Color(0.95, 0.95, 0.95), 0.9), Vector3(0, 0.3, 0), root)
		"cloth":
			Mats.mi(Mats.box(Vector3(0.5, 0.06, 0.36)), m, Vector3(0, 0.03, 0), root, Vector3(0, 0, 4))
			Mats.mi(Mats.box(Vector3(0.45, 0.06, 0.3)), Mats.mat(c.darkened(0.08), 0.95), Vector3(0.02, 0.08, 0.02), root, Vector3(0, 20, -3))
		"bottle":
			var g := Mats.glass(Color(c.r, c.g, c.b, 0.55))
			Mats.mi(Mats.cyl(0.075, 0.075, 0.3), g, Vector3(0, 0.15, 0), root)
			Mats.mi(Mats.cyl(0.03, 0.075, 0.1), g, Vector3(0, 0.35, 0), root)
			Mats.mi(Mats.cyl(0.026, 0.026, 0.05), g, Vector3(0, 0.42, 0), root)
			Mats.mi(Mats.cyl(0.03, 0.03, 0.035), Mats.mat(Color(0.15, 0.45, 0.9), 0.4), Vector3(0, 0.46, 0), root)
			Mats.mi(Mats.cyl(0.077, 0.077, 0.09), Mats.mat(c.darkened(0.15), 0.6), Vector3(0, 0.17, 0), root)
		"tray":
			var g2 := Mats.glass(Color(c.r, c.g, c.b, 0.5))
			Mats.mi(Mats.box(Vector3(0.38, 0.02, 0.26)), g2, Vector3(0, 0.01, 0), root)
			for sx in [-1.0, 1.0]:
				Mats.mi(Mats.box(Vector3(0.02, 0.07, 0.26)), g2, Vector3(0.19 * sx, 0.045, 0), root)
				Mats.mi(Mats.box(Vector3(0.38, 0.07, 0.02)), g2, Vector3(0, 0.045, 0.13 * sx), root)
		"jar":
			var g3 := Mats.glass(Color(c.r, c.g, c.b, 0.5))
			Mats.mi(Mats.cyl(0.11, 0.11, 0.22), g3, Vector3(0, 0.11, 0), root)
			Mats.mi(Mats.cyl(0.115, 0.115, 0.05), Mats.mat(Color(0.95, 0.35, 0.25), 0.5), Vector3(0, 0.245, 0), root)
		"pouch":
			Mats.mi(Mats.sphere(0.2), Mats.mat(c, 0.25, 0.9), Vector3(0, 0.08, 0), root, Vector3.ZERO, Vector3(1.0, 0.35, 1.3))
			Mats.mi(Mats.box(Vector3(0.34, 0.03, 0.1)), Mats.mat(Color(0.95, 0.45, 0.15), 0.5), Vector3(0, 0.12, 0), root)
		"pizza":
			Mats.mi(Mats.box(Vector3(0.48, 0.07, 0.48)), m, Vector3(0, 0.035, 0), root)
			var grease := Mats.mat(Color(0.42, 0.28, 0.12), 0.3)
			for k in 4:
				Mats.mi(Mats.sphere(0.06 + k * 0.012), grease, Vector3(-0.15 + k * 0.1, 0.07, sin(k * 1.7) * 0.12), root, Vector3.ZERO, Vector3(1, 0.08, 1))
		"butt":
			Mats.mi(Mats.cyl(0.03, 0.03, 0.12), Mats.mat(Color(0.96, 0.96, 0.94), 0.8), Vector3(0, 0.03, 0.06), root, Vector3(90, 0, 0))
			Mats.mi(Mats.cyl(0.032, 0.032, 0.08), Mats.mat(c, 0.8), Vector3(0, 0.03, -0.04), root, Vector3(90, 0, 0))
			root.scale = Vector3(1.8, 1.8, 1.8)
		"crumple":
			Mats.mi(Mats.rock(0.12, 31, 0.9), Mats.mat(c, 0.95), Vector3(0, 0.1, 0), root, Vector3.ZERO, Vector3(0.14, 0.14, 0.14))
		"mug":
			Mats.mi(Mats.cyl(0.09, 0.08, 0.18), m, Vector3(0, 0.09, 0), root)
			Mats.mi(Mats.torus(0.035, 0.06), m, Vector3(0.11, 0.1, 0), root, Vector3(90, 0, 0))
			Mats.mi(Mats.box(Vector3(0.08, 0.07, 0.02)), m, Vector3(-0.15, 0.03, 0.08), root, Vector3(20, 30, 50))
		"battery":
			Mats.mi(Mats.cyl(0.07, 0.07, 0.3), m, Vector3(0, 0.15, 0), root)
			Mats.mi(Mats.cyl(0.071, 0.071, 0.08), Mats.mat(Color(0.95, 0.6, 0.1), 0.4, 0.6), Vector3(0, 0.27, 0), root)
			Mats.mi(Mats.cyl(0.025, 0.025, 0.03), Mats.mat(Color(0.8, 0.8, 0.82), 0.3, 0.9), Vector3(0, 0.32, 0), root)
		"can":
			Mats.mi(Mats.cyl(0.13, 0.13, 0.26), Mats.mat(c, 0.35, 0.8), Vector3(0, 0.13, 0), root)
			Mats.mi(Mats.cyl(0.132, 0.132, 0.1), Mats.mat(Color(0.25, 0.55, 0.85), 0.6), Vector3(0, 0.14, 0), root)
			Mats.mi(Mats.torus(0.12, 0.13), Mats.mat(Color(0.4, 0.4, 0.42), 0.4, 0.8), Vector3(0, 0.3, 0), root, Vector3(90, 0, 0))
		"phone":
			Mats.mi(Mats.box(Vector3(0.16, 0.025, 0.32)), m, Vector3(0, 0.015, 0), root)
			Mats.mi(Mats.box(Vector3(0.14, 0.005, 0.28)), Mats.mat(Color(0.08, 0.12, 0.18), 0.1, 0.3), Vector3(0, 0.03, 0), root)
			Mats.mi(Mats.box(Vector3(0.07, 0.006, 0.12)), Mats.mat(Color(0.5, 0.55, 0.6), 0.2), Vector3(0.02, 0.034, 0.05), root, Vector3(0, 30, 0))
		"spray":
			Mats.mi(Mats.cyl(0.07, 0.07, 0.3), Mats.mat(c, 0.35, 0.6), Vector3(0, 0.15, 0), root)
			Mats.mi(Mats.sphere(0.07), Mats.mat(Color(0.85, 0.85, 0.88), 0.3, 0.8), Vector3(0, 0.3, 0), root, Vector3.ZERO, Vector3(1, 0.6, 1))
			Mats.mi(Mats.box(Vector3(0.04, 0.05, 0.04)), Mats.mat(Color(0.1, 0.1, 0.1), 0.5), Vector3(0, 0.36, 0), root)
		"blister":
			Mats.mi(Mats.box(Vector3(0.3, 0.015, 0.16)), Mats.mat(Color(0.82, 0.83, 0.86), 0.3, 0.8), Vector3.ZERO, root)
			for k in 8:
				Mats.mi(Mats.sphere(0.025), Mats.glass(Color(1, 1, 1, 0.6)), Vector3(-0.1 + (k % 4) * 0.066, 0.015, -0.04 + (k / 4) * 0.08), root, Vector3.ZERO, Vector3(1, 0.6, 1))
		"envelope":
			Mats.mi(Mats.box(Vector3(0.42, 0.025, 0.28)), m, Vector3(0, 0.012, 0), root)
			Mats.mi(Mats.box(Vector3(0.42, 0.026, 0.28)), Mats.mat(c.darkened(0.08), 0.85), Vector3(0.03, 0.04, -0.02), root, Vector3(0, 14, 0))
			Mats.mi(Mats.box(Vector3(0.06, 0.008, 0.06)), Mats.mat(Color(0.75, 0.2, 0.2), 0.6), Vector3(0.14, 0.06, -0.08), root, Vector3(0, 14, 0))
			for k in 3:
				Mats.mi(Mats.box(Vector3(0.22, 0.004, 0.012)), Mats.mat(Color(0.25, 0.25, 0.3), 0.9), Vector3(-0.02, 0.056, -0.02 + k * 0.04), root, Vector3(0, 14, 0))
		"hat":
			Mats.mi(Mats.sphere(0.17, -1.0, 20), m, Vector3(0, 0.08, 0), root, Vector3.ZERO, Vector3(1, 0.85, 1))
			Mats.mi(Mats.cyl(0.175, 0.175, 0.07, 20), Mats.mat(c.darkened(0.2), 0.95), Vector3(0, 0.04, 0), root)
			Mats.mi(Mats.sphere(0.07), Mats.mat(Color(0.95, 0.95, 0.92), 0.95), Vector3(0, 0.24, 0), root)
		"cardigan":
			Mats.mi(Mats.box(Vector3(0.36, 0.42, 0.07)), m, Vector3(0, 0.21, 0), root)
			for sx in [-1.0, 1.0]:
				Mats.mi(Mats.box(Vector3(0.24, 0.12, 0.065)), m, Vector3(0.26 * sx, 0.3, 0), root, Vector3(0, 0, -55 * sx))
			Mats.mi(Mats.box(Vector3(0.02, 0.42, 0.075)), Mats.mat(c.darkened(0.3), 0.9), Vector3(0, 0.21, 0), root)
			for k in 4:
				Mats.mi(Mats.cyl(0.018, 0.018, 0.012, 10), Mats.mat(Color(0.9, 0.85, 0.7), 0.4), Vector3(0.03, 0.08 + k * 0.09, -0.04), root, Vector3(90, 0, 0))
		"yarn":
			Mats.mi(Mats.sphere(0.13), m, Vector3(0, 0.13, 0), root)
			for k in 3:
				Mats.mi(Mats.torus(0.125, 0.135), m, Vector3(0, 0.13, 0), root, Vector3(k * 60, k * 40, 0))
			var tail := Mats.bezier(Vector3(0.1, 0.06, 0), Vector3(0.25, 0.0, 0.05), Vector3(0.3, 0.02, -0.12), Vector3(0.42, 0.01, -0.1), 10)
			Mats.mi(Mats.tube(tail, 0.01, 5), m, Vector3.ZERO, root)
		"drinkcan":
			Mats.mi(Mats.cyl(0.065, 0.065, 0.24, 18), Mats.mat(c, 0.3, 0.9), Vector3(0, 0.12, 0), root)
			Mats.mi(Mats.cyl(0.066, 0.066, 0.12, 18), Mats.mat(Color(0.85, 0.15, 0.15), 0.5), Vector3(0, 0.12, 0), root)
			Mats.mi(Mats.cyl(0.05, 0.065, 0.02, 18), Mats.mat(c, 0.3, 0.9), Vector3(0, 0.25, 0), root)
		"toy":
			Mats.mi(Mats.box(Vector3(0.34, 0.1, 0.18)), m, Vector3(0, 0.1, 0), root, Vector3(0, 0, 8))
			Mats.mi(Mats.box(Vector3(0.16, 0.08, 0.16)), Mats.mat(Color(0.2, 0.5, 0.9), 0.5), Vector3(-0.02, 0.19, 0), root)
			for p2 in [Vector3(-0.12, 0.05, 0.1), Vector3(0.12, 0.04, 0.1), Vector3(-0.12, 0.05, -0.1)]:
				Mats.mi(Mats.cyl(0.05, 0.05, 0.03, 12), Mats.mat(Color(0.08, 0.08, 0.08), 0.8), p2, root, Vector3(90, 0, 0))
			Mats.mi(Mats.cyl(0.05, 0.05, 0.03, 12), Mats.mat(Color(0.08, 0.08, 0.08), 0.8), Vector3(0.28, 0.02, -0.12), root, Vector3(20, 0, 70))
		"container":
			var cg := Mats.glass(Color(c.r, c.g, c.b, 0.6))
			Mats.mi(Mats.box(Vector3(0.32, 0.14, 0.24)), cg, Vector3(0, 0.07, 0), root)
			Mats.mi(Mats.box(Vector3(0.34, 0.025, 0.26)), Mats.mat(c, 0.5), Vector3(0.03, 0.16, 0.02), root, Vector3(0, 0, 12))
		"glassbottle":
			var gg := Mats.glass(Color(c.r, c.g, c.b, 0.75))
			Mats.mi(Mats.cyl(0.07, 0.07, 0.26, 16), gg, Vector3(0, 0.13, 0), root)
			Mats.mi(Mats.cyl(0.025, 0.07, 0.08, 16), gg, Vector3(0, 0.3, 0), root)
			Mats.mi(Mats.cyl(0.022, 0.022, 0.12, 12), gg, Vector3(0, 0.4, 0), root)
			Mats.mi(Mats.cyl(0.072, 0.072, 0.08, 16), Mats.mat(Color(0.95, 0.92, 0.8), 0.7), Vector3(0, 0.12, 0), root)
		"packaging":
			Mats.mi(Mats.box(Vector3(0.22, 0.3, 0.12)), m, Vector3(0, 0.15, 0), root)
			Mats.mi(Mats.box(Vector3(0.18, 0.12, 0.005)), Mats.mat(Color(0.9, 0.3, 0.2), 0.6), Vector3(0, 0.17, -0.062), root)
			Mats.mi(Mats.box(Vector3(0.22, 0.04, 0.12)), Mats.mat(c.lightened(0.1), 0.85), Vector3(0, 0.31, 0), root, Vector3(18, 0, 0))
		_:
			Mats.mi(Mats.box(Vector3(0.3, 0.3, 0.3)), m, Vector3(0, 0.15, 0), root)
	return root


static func build_reward(id: String) -> Node3D:
	var root := Node3D.new()
	match id:
		"notebook":
			Mats.mi(Mats.box(Vector3(0.5, 0.06, 0.66)), Mats.mat(Color(0.18, 0.45, 0.82), 0.6, 0.0, 0.3), Vector3(0, 0.03, 0), root)
			Mats.mi(Mats.box(Vector3(0.47, 0.05, 0.63)), Mats.mat(Color(0.96, 0.95, 0.9), 0.9), Vector3(0.012, 0.035, 0), root)
			Mats.mi(Mats.box(Vector3(0.5, 0.012, 0.66)), Mats.mat(Color(0.18, 0.45, 0.82), 0.6, 0.0, 0.3), Vector3(0, 0.066, 0), root)
			for k in 9:
				Mats.mi(Mats.torus(0.02, 0.03), Mats.mat(Color(0.8, 0.82, 0.85), 0.3, 0.9), Vector3(-0.25, 0.04, -0.28 + k * 0.07), root, Vector3(0, 0, 90))
			Mats.mi(Mats.box(Vector3(0.22, 0.004, 0.08)), Mats.mat(Color(0.96, 0.96, 0.96), 0.5), Vector3(0.05, 0.074, -0.15), root)
		"sweater":
			var blue := Mats.mat(Color(0.16, 0.46, 0.92), 0.95, 0.0, 0.35)
			var blue2 := Mats.mat(Color(0.30, 0.62, 1.0), 0.95, 0.0, 0.35)
			Mats.mi(Mats.box(Vector3(0.62, 0.7, 0.12)), blue, Vector3(0, 0.35, 0), root)
			for sx in [-1.0, 1.0]:
				Mats.mi(Mats.box(Vector3(0.18, 0.6, 0.11)), blue, Vector3(0.38 * sx, 0.36, 0), root, Vector3(0, 0, 12 * sx))
				Mats.mi(Mats.box(Vector3(0.19, 0.06, 0.12)), blue2, Vector3(0.43 * sx, 0.08, 0), root, Vector3(0, 0, 12 * sx))
			for k in 4:
				Mats.mi(Mats.box(Vector3(0.63, 0.03, 0.125)), blue2, Vector3(0, 0.04 + k * 0.04, 0), root)
			Mats.mi(Mats.box(Vector3(0.63, 0.05, 0.13)), Mats.mat(Color(0.96, 0.96, 1.0), 0.9), Vector3(0, 0.45, 0), root)
			Mats.mi(Mats.torus(0.09, 0.14), blue2, Vector3(0, 0.7, 0), root, Vector3(90, 0, 0), Vector3(1, 1, 0.7))
		"planter":
			var teal := Mats.mat(Color(0.18, 0.66, 0.62), 0.35, 0.0, 0.3)
			Mats.mi(Mats.cyl(0.3, 0.22, 0.42), teal, Vector3(0, 0.21, 0), root)
			Mats.mi(Mats.torus(0.27, 0.33), teal, Vector3(0, 0.42, 0), root)
			Mats.mi(Mats.cyl(0.27, 0.27, 0.04), Mats.mat(Color(0.30, 0.20, 0.12), 0.95), Vector3(0, 0.41, 0), root)
			Mats.mi(Mats.cyl(0.02, 0.03, 0.5), Mats.mat(Color(0.45, 0.35, 0.25), 0.9), Vector3(0, 0.66, 0), root)
			var leaf := Mats.mat(Color(0.42, 0.62, 0.32), 0.7, 0.0, 0.2)
			for k in 9:
				var a: float = k * 2.4
				var l := Mats.mi(Mats.sphere(0.1), leaf, Vector3(cos(a) * 0.12, 0.72 + k * 0.035, sin(a) * 0.12), root, Vector3(0, rad_to_deg(a), 30), Vector3(1.0, 0.25, 0.4))
				l.rotation_degrees.y = rad_to_deg(-a)
	return root
