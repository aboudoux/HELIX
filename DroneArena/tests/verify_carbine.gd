extends "res://tests/verify.gd"
## Vérifie le contrat entre le modèle Blender et les tirs existants.


func run() -> void:
	create_timer(15.0).timeout.connect(func(): push_error("Délai de vérification de l'arme dépassé"); quit(1))
	var packed := load("res://assets/models/helix_carbine.glb") as PackedScene
	check(packed != null, "Le GLB de la carabine est importable")
	if packed == null:
		quit(1)
		return
	var visual := packed.instantiate() as Node3D
	root.add_child(visual)
	check(visual.find_children("*", "CollisionObject3D", true, false).is_empty(), "Le modèle n'ajoute aucune collision aux tirs")
	check(visual.find_children("*", "Camera3D", true, false).is_empty() and visual.find_children("*", "Light3D", true, false).is_empty(), "Caméra et lumières du studio exclues du jeu")
	var meshes := visual.find_children("*", "MeshInstance3D", true, false)
	check(meshes.size() >= 10 and meshes.size() <= 20, "Maillages du modèle détaillé regroupés par matériau")
	var bounds := AABB()
	var first := true
	var no_shadows := true
	var no_scripts := visual.get_script() == null
	for node in visual.find_children("*", "Node", true, false):
		no_scripts = no_scripts and node.get_script() == null
	for mesh in meshes:
		var box: AABB = visual.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
		no_shadows = no_shadows and mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	check(no_scripts, "Le GLB ne contient aucune logique de jeu")
	check(no_shadows, "Absence d'ombre conservée pour le modèle à la première personne")
	check(bounds.size.x < 0.46 and bounds.size.y < 0.72 and bounds.size.z < 1.05, "Échelle en mètres et axes conformes au montage existant")
	check(absf(bounds.position.z + 0.55) < 0.002, "La bouche visuelle du canon pointe vers -Z au bon emplacement")
	visual.free()

	game = load("res://scenes/main.tscn").instantiate()
	game.get_node("Drones").process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(game)
	current_scene = game
	player = game.get_node("Player")
	await frames(4)
	var weapon: Node3D = player.weapon
	visual = weapon.get_node("Model/VisualModel")
	check(visual.scene_file_path == "res://assets/models/helix_carbine.glb", "La vraie scène de jeu utilise le nouveau GLB")
	check(weapon.position.is_equal_approx(Vector3(0.28, -0.24, -0.5)), "Position de l'arme par rapport à la caméra inchangée")
	check(visual.transform.is_equal_approx(Transform3D.IDENTITY), "Aucun décalage ni changement d'échelle ajouté au modèle")
	check(weapon.muzzle.position.is_equal_approx(Vector3(0, 0.025, -0.555)), "Origine des rayons et du flash inchangée")
	check(weapon.fire_interval == 0.2 and weapon.max_range == 100.0, "Cadence et portée des tirs inchangées")
	var reference: Node3D = visual.find_child("MuzzleReference", true, false)
	check(reference != null, "Le GLB conserve un repère de bouche de canon")
	if reference != null:
		check(reference.global_position.distance_to(weapon.muzzle.global_position) < 0.0001, "La sortie du modèle coïncide avec le marqueur de tir")
	game.resume_button.pressed.emit()
	await frames(3)
	mouse_button(true)
	await frames(2)
	mouse_button(false)
	check(weapon.shots_fired == 1 and weapon.recoil > 0.0, "Le tir existant anime le recul du modèle importé")
	if reference != null:
		check(reference.global_position.distance_to(weapon.muzzle.global_position) < 0.0001, "Le canon et les effets restent alignés pendant le recul")
	await tap(KEY_ESCAPE)
	var frozen: Transform3D = weapon.model.transform
	await frames(8)
	check(weapon.model.transform.is_equal_approx(frozen), "La pause fige le nouveau modèle et son recul")
	game.restart_exploration()
	await frames(4)
	check(weapon.model.transform.is_equal_approx(Transform3D.IDENTITY) and visual.is_visible_in_tree(), "Une nouvelle partie restaure l'arme dans sa position de repos")
	print("RESULT: %d carbine checks, %d failures" % [checks, failures])
	paused = false
	for sound in game.find_children("*", "AudioStreamPlayer", true, false) + game.find_children("*", "AudioStreamPlayer3D", true, false):
		sound.stop()
	OS.delay_msec(50)
	game.queue_free()
	await frames(3)
	OS.delay_msec(50)
	quit(1 if failures else 0)
