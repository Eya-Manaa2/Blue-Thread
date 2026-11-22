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
			# journal plié : deux feuilles, gros titre, colonnes de texte, photo
			var paper := Mats.mat(c, 0.9)
			Mats.mi(Mats.box(Vector3(0.48, 0.022, 0.34)), paper, Vector3(0, 0.011, 0), root, Vector3(0, 0, 2))
			Mats.mi(Mats.box(Vector3(0.46, 0.022, 0.32)), Mats.mat(c.darkened(0.06), 0.9), Vector3(0.015, 0.034, 0.008), root, Vector3(0, 9, -1))
			var ink := Mats.mat(Color(0.16, 0.16, 0.18), 0.9)
			var top := Node3D.new()
			top.position = Vector3(0.015, 0.047, 0.008)
			top.rotation_degrees = Vector3(0, 9, 0)
			root.add_child(top)
			if item_id == "magazine":
				Mats.mi(Mats.box(Vector3(0.40, 0.003, 0.26)), Mats.mat(Color(0.92, 0.45, 0.5), 0.5), Vector3.ZERO, top)
			else:
				Mats.mi(Mats.box(Vector3(0.36, 0.003, 0.05)), ink, Vector3(0, 0, -0.11), top)
				Mats.mi(Mats.box(Vector3(0.13, 0.003, 0.10)), Mats.mat(Color(0.45, 0.47, 0.52), 0.8), Vector3(-0.11, 0, -0.01), top)
				for col in 2:
					for k in 5:
						Mats.mi(Mats.box(Vector3(0.1, 0.002, 0.008)), ink, Vector3(0.04 + col * 0.12, 0, -0.05 + k * 0.025), top)
				for k in 3:
					Mats.mi(Mats.box(Vector3(0.36, 0.002, 0.008)), ink, Vector3(0, 0, 0.08 + k * 0.022), top)
		"notebook":
			# cahier à spirale : couverture bleue, pages, anneaux métalliques
			var cover := Mats.mat(Color(0.20, 0.42, 0.78), 0.6)
			Mats.mi(Mats.box(Vector3(0.30, 0.012, 0.40)), cover, Vector3(0, 0.006, 0), root)
			Mats.mi(Mats.box(Vector3(0.285, 0.03, 0.385)), Mats.mat(Color(0.97, 0.96, 0.92), 0.9), Vector3(0.005, 0.027, 0), root)
			Mats.mi(Mats.box(Vector3(0.30, 0.012, 0.40)), cover, Vector3(0, 0.048, 0), root)
			Mats.mi(Mats.box(Vector3(0.16, 0.002, 0.06)), Mats.mat(Color(0.96, 0.96, 0.96), 0.7), Vector3(0.02, 0.055, -0.08), root)
			var ring_m := Mats.mat(Color(0.75, 0.76, 0.8), 0.3, 0.9)
			for k in 8:
				Mats.mi(Mats.torus(0.014, 0.022, 10), ring_m, Vector3(-0.15, 0.027, -0.17 + k * 0.048), root, Vector3(0, 0, 90))
		"box":
			# carton : volume, rabats entrouverts, ruban adhésif, symbole recyclage imprimé
			Mats.mi(Mats.box(Vector3(0.42, 0.30, 0.32)), m, Vector3(0, 0.15, 0), root)
			var flap := Mats.mat(c.lightened(0.06), 0.85)
			Mats.mi(Mats.box(Vector3(0.42, 0.012, 0.16)), flap, Vector3(0, 0.32, -0.11), root, Vector3(-28, 0, 0))
			Mats.mi(Mats.box(Vector3(0.42, 0.012, 0.16)), flap, Vector3(0, 0.33, 0.11), root, Vector3(32, 0, 0))
			Mats.mi(Mats.box(Vector3(0.07, 0.004, 0.33)), Mats.mat(Color(0.86, 0.72, 0.45), 0.4), Vector3(0, 0.302, 0), root)
			Mats.mi(Mats.box(Vector3(0.43, 0.06, 0.005)), Mats.mat(c.darkened(0.25), 0.9), Vector3(0, 0.22, -0.163), root)
			if item_id == "egg_carton":
				for k in 3:
					Mats.mi(Mats.sphere(0.06), m, Vector3(-0.13 + k * 0.13, 0.32, 0), root, Vector3.ZERO, Vector3(1, 0.5, 1))
		"bag":
			Mats.mi(Mats.box(Vector3(0.3, 0.38, 0.18)), m, Vector3(0, 0.19, 0), root)
			Mats.mi(Mats.box(Vector3(0.31, 0.06, 0.19)), Mats.mat(c.darkened(0.12), 0.85), Vector3(0, 0.36, 0), root)
			Mats.mi(Mats.torus(0.06, 0.075), Mats.mat(c.darkened(0.25), 0.8), Vector3(0, 0.42, 0), root, Vector3(90, 0, 0), Vector3(1, 1, 1.6))
		"stack":
			for k in 5:
				Mats.mi(Mats.box(Vector3(0.36, 0.022, 0.26)), m, Vector3(0, 0.012 + k * 0.024, 0), root, Vector3(0, k * 7 - 14, 0))
		"tshirt", "sweater":
			# vêtement posé à plat : corps arrondi, manches, col et poignets côtelés
			var long := shape == "sweater"
			var cloth := Mats.mat(c, 0.95, 0.0, 0.15)
			Mats.mi(Mats.capsule(0.17, 0.44), cloth, Vector3(0, 0.03, 0), root, Vector3(90, 0, 0), Vector3(1.05, 1.0, 0.28))
			for sx in [-1.0, 1.0]:
				var sl := Node3D.new()
				sl.position = Vector3(0.17 * sx, 0.03, -0.13)
				sl.rotation_degrees = Vector3(0, -50.0 * sx if long else -70.0 * sx, 0)
				root.add_child(sl)
				var ln: float = 0.30 if long else 0.13
				Mats.mi(Mats.capsule(0.055, ln + 0.08), cloth, Vector3(0.0, 0, ln * 0.5), sl, Vector3(90, 0, 0), Vector3(1, 1, 0.6))
				if long:
					Mats.mi(Mats.cyl(0.05, 0.05, 0.05, 12), Mats.mat(c.darkened(0.18), 0.95), Vector3(0, 0, ln + 0.02), sl, Vector3(90, 0, 0), Vector3(1, 1, 0.6))
			Mats.mi(Mats.torus(0.05, 0.08, 20), Mats.mat(c.darkened(0.22), 0.95), Vector3(0, 0.05, -0.2), root, Vector3.ZERO, Vector3(1, 0.5, 0.7))
			if long:
				for k in 4:
					Mats.mi(Mats.box(Vector3(0.30, 0.005, 0.012)), Mats.mat(c.lightened(0.18), 0.95), Vector3(0, 0.07, -0.05 + k * 0.06), root)
				Mats.mi(Mats.box(Vector3(0.33, 0.04, 0.05)), Mats.mat(c.darkened(0.18), 0.95), Vector3(0, 0.03, 0.22), root)
			else:
				Mats.mi(Mats.sphere(0.05, -1.0, 12), Mats.mat(Color(0.2, 0.55, 0.85), 0.8), Vector3(0.05, 0.072, -0.06), root, Vector3.ZERO, Vector3(1, 0.15, 1))
		"pants":
			Mats.mi(Mats.box(Vector3(0.34, 0.1, 0.08)), m, Vector3(0, 0.5, 0), root)
			for sx in [-1.0, 1.0]:
				Mats.mi(Mats.box(Vector3(0.15, 0.48, 0.075)), m, Vector3(0.09 * sx, 0.22, 0), root, Vector3(0, 0, 4 * sx))
			Mats.mi(Mats.box(Vector3(0.35, 0.02, 0.085)), Mats.mat(Color(0.75, 0.55, 0.2), 0.5), Vector3(0, 0.54, 0), root)
		"scarf":
			# écharpe tricotée : bande souple en S, rayures, franges
			var pts := Mats.bezier(Vector3(-0.32, 0.04, -0.06), Vector3(-0.1, 0.12, 0.2), Vector3(0.1, -0.02, -0.25), Vector3(0.32, 0.05, 0.06), 14)
			for i in pts.size():
				var stripe := Mats.mat(c if (i / 2) % 2 == 0 else Color(0.92, 0.92, 0.96), 0.95)
				Mats.mi(Mats.box(Vector3(0.06, 0.035, 0.13)), stripe, pts[i], root, Vector3(0, -40 + i * 6, 0))
			for k in 5:
				Mats.mi(Mats.cyl(0.006, 0.006, 0.07, 4), Mats.mat(c, 0.95), pts[pts.size() - 1] + Vector3(0.04, 0.0, -0.05 + k * 0.025), root, Vector3(0, 0, 90))
		"sock":
			Mats.mi(Mats.capsule(0.06, 0.28), m, Vector3(0, 0.18, 0), root)
			Mats.mi(Mats.capsule(0.06, 0.2), m, Vector3(0, 0.05, -0.08), root, Vector3(90, 0, 0))
			Mats.mi(Mats.cyl(0.065, 0.065, 0.05), Mats.mat(Color(0.95, 0.95, 0.95), 0.9), Vector3(0, 0.3, 0), root)
		"cloth":
			Mats.mi(Mats.box(Vector3(0.5, 0.06, 0.36)), m, Vector3(0, 0.03, 0), root, Vector3(0, 0, 4))
			Mats.mi(Mats.box(Vector3(0.45, 0.06, 0.3)), Mats.mat(c.darkened(0.08), 0.95), Vector3(0.02, 0.08, 0.02), root, Vector3(0, 20, -3))
		"bottle":
			# bouteille PET : corps à côtes, épaulement, goulot, bouchon, étiquette
			var g := Mats.glass(Color(c.r, c.g, c.b, 0.5))
			var soda: bool = item_id == "soda_bottle"
			Mats.mi(Mats.cyl(0.078, 0.07 if soda else 0.078, 0.30, 20), g, Vector3(0, 0.15, 0), root)
			if not soda:
				for k in 4:
					Mats.mi(Mats.torus(0.074, 0.084, 20), g, Vector3(0, 0.05 + k * 0.03, 0), root)
			else:
				Mats.mi(Mats.sphere(0.075, -1.0, 16), g, Vector3(0, 0.01, 0), root, Vector3.ZERO, Vector3(1, 0.35, 1))
			Mats.mi(Mats.cyl(0.03, 0.078, 0.10, 20), g, Vector3(0, 0.35, 0), root)
			Mats.mi(Mats.cyl(0.026, 0.026, 0.04, 14), g, Vector3(0, 0.42, 0), root)
			Mats.mi(Mats.cyl(0.032, 0.032, 0.035, 14), Mats.mat(Color(0.85, 0.15, 0.15) if soda else Color(0.15, 0.45, 0.9), 0.4), Vector3(0, 0.455, 0), root)
			var lab_c: Color = Color(0.85, 0.12, 0.15) if soda else Color(0.2, 0.55, 0.95)
			Mats.mi(Mats.cyl(0.08, 0.08, 0.10, 20), Mats.mat(lab_c, 0.55), Vector3(0, 0.2, 0), root)
			Mats.mi(Mats.cyl(0.081, 0.081, 0.02, 20), Mats.mat(Color(0.97, 0.97, 0.97), 0.6), Vector3(0, 0.2, 0), root)
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
			# mouchoir usagé : papier froissé + taches (non recyclable)
			Mats.mi(Mats.rock(0.12, 31, 0.9), Mats.mat(c, 0.95), Vector3(0, 0.1, 0), root, Vector3.ZERO, Vector3(0.15, 0.13, 0.15))
			Mats.mi(Mats.rock(0.1, 47, 0.8), Mats.mat(c.darkened(0.05), 0.95), Vector3(0.09, 0.06, 0.05), root, Vector3.ZERO, Vector3(0.1, 0.08, 0.1))
			for k in 3:
				Mats.mi(Mats.sphere(0.03), Mats.mat(Color(0.62, 0.55, 0.30), 0.9), Vector3(-0.05 + k * 0.05, 0.17 - k * 0.03, -0.09 + k * 0.04), root, Vector3.ZERO, Vector3(1.4, 0.3, 1.0))
		"mug":
			# tasse cassée : corps ébréché, anse, éclat posé à côté
			var cer := Mats.mat(c, 0.35, 0.0, 0.2)
			Mats.mi(Mats.cyl(0.09, 0.08, 0.18, 22), cer, Vector3(0, 0.09, 0), root)
			Mats.mi(Mats.cyl(0.075, 0.075, 0.005, 22), Mats.mat(Color(0.25, 0.15, 0.1), 0.5), Vector3(0, 0.17, 0), root)
			Mats.mi(Mats.torus(0.035, 0.06, 16), cer, Vector3(0.11, 0.1, 0), root, Vector3(90, 0, 0))
			Mats.mi(Mats.box(Vector3(0.06, 0.06, 0.03)), Mats.mat(Color(0.95, 0.93, 0.9), 0.5), Vector3(-0.06, 0.16, -0.06), root, Vector3(0, 40, 20))
			Mats.mi(Mats.box(Vector3(0.09, 0.012, 0.06)), cer, Vector3(-0.17, 0.008, 0.08), root, Vector3(0, 30, 0))
			Mats.mi(Mats.box(Vector3(0.05, 0.012, 0.04)), cer, Vector3(-0.12, 0.008, 0.16), root, Vector3(0, -20, 0))
		"battery":
			# pile usagée (format AA) : corps noir, bande orange, borne +, symbole
			Mats.mi(Mats.cyl(0.06, 0.06, 0.28, 20), Mats.mat(Color(0.12, 0.13, 0.15), 0.4, 0.5), Vector3(0, 0.14, 0), root)
			Mats.mi(Mats.cyl(0.061, 0.061, 0.10, 20), Mats.mat(Color(0.95, 0.55, 0.10), 0.35, 0.6), Vector3(0, 0.23, 0), root)
			Mats.mi(Mats.cyl(0.022, 0.022, 0.025, 12), Mats.mat(Color(0.82, 0.82, 0.85), 0.25, 0.95), Vector3(0, 0.292, 0), root)
			Mats.mi(Mats.cyl(0.058, 0.058, 0.006, 20), Mats.mat(Color(0.75, 0.75, 0.78), 0.3, 0.9), Vector3(0, 0.002, 0), root)
			Mats.mi(Mats.box(Vector3(0.04, 0.012, 0.004)), Mats.mat(Color(1, 1, 1), 0.5), Vector3(0, 0.23, -0.062), root)
			Mats.mi(Mats.box(Vector3(0.012, 0.04, 0.004)), Mats.mat(Color(1, 1, 1), 0.5), Vector3(0, 0.23, -0.062), root)
			root.rotation_degrees = Vector3(0, 0, 0)
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
