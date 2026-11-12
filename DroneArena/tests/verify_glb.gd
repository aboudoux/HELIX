extends "res://tests/verify.gd"
## Le modèle doit être portable, correctement orienté et indépendant de l'IA.


func run() -> void:
	create_timer(10.0).timeout.connect(func(): push_error("Délai de vérification GLB dépassé"); quit(1))
	var packed := load("res://assets/models/helix_sentinel.glb") as PackedScene
	check(packed != null, "Le GLB est importable comme scène Godot")
	if packed == null:
		quit(1)
		return
	var model := packed.instantiate() as Node3D
	root.add_child(model)
	check(model.get_script() == null, "Le modèle GLB est dépourvu de logique de combat")
	check(model.find_children("*", "CollisionObject3D", true, false).is_empty(), "Aucune collision supplémentaire importée avec le modèle")
	check(model.find_children("*", "Camera3D", true, false).is_empty(), "La caméra de studio n'est pas exportée")
	check(model.find_children("*", "Light3D", true, false).is_empty(), "Les lumières de studio ne sont pas exportées")
	var mesh_nodes := model.find_children("*", "MeshInstance3D", true, false)
	check(mesh_nodes.size() > 15 and mesh_nodes.size() <= 50, "Modèle détaillé regroupé en un nombre raisonnable de maillages")
	var bounds := AABB()
	var first := true
	for mesh_node in mesh_nodes:
		var local_transform: Transform3D = model.global_transform.affine_inverse() * mesh_node.global_transform
		var box: AABB = local_transform * mesh_node.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	check(bounds.size.x > 1.7 and bounds.size.x < 1.85, "Largeur du modèle conforme au volume du drone")
	check(bounds.size.y < 0.75 and bounds.size.z < 1.5, "Axes et dimensions du GLB conformes à Godot")
	check(bounds.position.y > -0.375 and bounds.end.y < 0.375, "Le modèle tient dans la hauteur de collision existante")
	var imported_rotors: Node3D = model.find_child("Rotors", true, false)
	check(imported_rotors != null, "Le groupe de rotors est conservé à l'import")
	for i in range(4):
		var path := "Rotor%d/Blades%d" % [i, i]
		check(imported_rotors != null and imported_rotors.has_node(path), "Pivot d'animation " + path)
	model.free()

	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	player = game.get_node("Player")
	await frames(3)
	var drone: CharacterBody3D = game.get_node("Drones/Sentinelle01")
	var visual: Node3D = drone.get_node("Hull/VisualModel")
	check(visual.scene_file_path == "res://assets/models/helix_sentinel.glb", "Le jeu utilise bien le GLB comme modèle visuel")
	check(drone.rotor_blades.size() == 4 and not drone.rotor_blades.has(null), "Les quatre hélices sont reliées à l'animation")
	check(drone.hit_shape.shape.size.is_equal_approx(Vector3(1.8, 0.75, 1.5)), "Volume de collision inchangé")
	check(drone.collision_layer == 8 and drone.collision_mask == 11, "Couches physiques inchangées")
	check(drone.max_health == 3 and is_equal_approx(drone.move_speed,3.3) and is_equal_approx(drone.fire_interval,1.98) and drone.charge_duration == 0.6, "IA plus mobile, résistance et préavis conservés")
	check(drone.muzzle.position.is_equal_approx(Vector3(0, -0.11, -0.64)), "Point de départ des projectiles inchangé")
	var blades: Node3D = drone.rotor_blades[0]
	var resting_rotation := blades.rotation.y
	game.resume_button.pressed.emit()
	await frames(8)
	check(not is_equal_approx(blades.rotation.y, resting_rotation), "Les hélices importées tournent en jeu")
	check(absf(blades.basis.y.dot(Vector3.UP)) > 0.99, "Rotation sur le bon axe vertical")
	await tap(KEY_ESCAPE)
	var frozen_rotation := blades.rotation.y
	await frames(8)
	check(is_equal_approx(blades.rotation.y, frozen_rotation), "La pause fige aussi les hélices du GLB")
	game.resume_button.pressed.emit()
	drone.receive_hit()
	drone.receive_hit()
	drone.receive_hit()
	await frames(3)
	check(not visual.is_visible_in_tree(), "La destruction masque le modèle importé")
	check(game.get_node("Drones/Sentinelle03/Hull/VisualModel").is_visible_in_tree(), "Les autres instances du GLB restent visibles")
	game.restart_exploration()
	await frames(5)
	check(visual.is_visible_in_tree() and drone.health == 3, "Recommencer restaure le modèle et les points de vie")
	print("RESULT: %d GLB checks, %d failures" % [checks, failures])
	paused = false
	for sound in game.find_children("*", "AudioStreamPlayer", true, false) + game.find_children("*", "AudioStreamPlayer3D", true, false):
		sound.stop()
	OS.delay_msec(50)
	game.queue_free()
	await frames(3)
	OS.delay_msec(50)
	quit(1 if failures else 0)
