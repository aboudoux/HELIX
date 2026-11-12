extends "res://tests/verify.gd"
## Compare la vraie physique au relevé effectué avant le remplacement du décor.

const PHYSICS := preload("res://tests/arena_physics.gd")


func same_numbers(actual: Array, expected: Array) -> bool:
	if actual.size() != expected.size():
		return false
	for i in range(actual.size()):
		if absf(float(actual[i]) - float(expected[i])) > 0.00001:
			return false
	return true


func bounds_of(model: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = model.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds


func screenshot(name: String) -> void:
	await frames(8)
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tests/artifacts/" + name)) == OK, "Capture " + name)


func run() -> void:
	create_timer(30.0).timeout.connect(func(): push_error("Délai de vérification du décor dépassé"); quit(1))
	for name in ["helix_arena", "helix_cover", "helix_storage"]:
		var packed := load("res://assets/models/" + name + ".glb") as PackedScene
		check(packed != null, "Import du modèle " + name)
		if packed == null:
			quit(1)
			return
		var model: Node3D = packed.instantiate()
		root.add_child(model)
		check(model.find_children("*", "CollisionObject3D", true, false).is_empty(), name + " n'ajoute aucun corps physique")
		check(model.find_children("*", "Camera3D", true, false).is_empty() and model.find_children("*", "Light3D", true, false).is_empty(), name + " exclut le studio Blender")
		var count := model.find_children("*", "MeshInstance3D", true, false).size()
		check(count >= 10 and count <= 100, name + " est détaillé et regroupé pour le rendu")
		if name != "helix_arena":
			var bounds := bounds_of(model)
			var expected := Vector3(3, 1.1, 3) if name == "helix_cover" else Vector3(2.8, 3.2, 3)
			check(bounds.size.distance_to(expected) < 0.003 and absf(bounds.position.y) < 0.001, name + " respecte le volume de collision et l'origine au sol")
		model.free()

	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	player = game.get_node("Player")
	await frames(3)
	var baseline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/arena_physics.json"))
	var actual := PHYSICS.snapshot(game.get_node("Arena"))
	var expected: Array = baseline.colliders
	check(actual.size() == expected.size() and actual.size() == 21, "Les 21 collisions initiales sont conservées")
	for i in range(mini(actual.size(), expected.size())):
		var a: Dictionary = actual[i]
		var b: Dictionary = expected[i]
		check(a.path == b.path and a.shape == b.shape and a.layer == b.layer and a.mask == b.mask and a.disabled == b.disabled and same_numbers(a.dimensions, b.dimensions) and same_numbers(a.transform, b.transform), "Collision inchangée : " + str(b.path))
	var director: Node3D = game.get_node("Drones")
	director.build_flight_map()
	var cells := PHYSICS.solid_cells(director)
	var old_cells: Array = baseline.solid_cells
	var same_map := cells.size() == old_cells.size()
	for i in range(mini(cells.size(), old_cells.size())):
		# Le parseur JSON relit les coordonnées entières comme des flottants.
		same_map = same_map and same_numbers(cells[i], old_cells[i])
	check(same_map, "Carte de vol identique : %d cellules bloquées, référence %d" % [cells.size(), old_cells.size()])
	check(game.get_node("Arena/VisualModel").scene_file_path == "res://assets/models/helix_arena.glb", "La vraie arène utilise le décor Blender")
	for name in ["Obstacle_A01", "Obstacle_A02", "Obstacle_B01", "Obstacle_B02", "Stockage_C01", "Stockage_C02"]:
		var obstacle: Node3D = game.get_node("Arena/" + name)
		check(obstacle.has_node("VisualModel") and obstacle.get_node("VisualModel").scene_file_path.ends_with(".glb"), "Modèle et collision restent réunis dans " + name)
	if DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/artifacts"))
		director.process_mode = Node.PROCESS_MODE_DISABLED
		game.resume_button.pressed.emit()
		await put_player(Vector3(0, 0.05, 18))
		await aim_at(Vector3(0, 2.1, -7))
		await screenshot("decor_arene.png")
		await put_player(Vector3(-5.5, 0.05, 11.5))
		await aim_at(Vector3(-8, 0.75, 8))
		await screenshot("decor_caisse.png")
		await put_player(Vector3(5, 0.05, -1))
		await aim_at(Vector3(0, 2, -7))
		await screenshot("decor_reacteur.png")
		await put_player(Vector3(0, 0.05, -16))
		await aim_at(Vector3(0, 3.1, -23.5))
		await screenshot("decor_porte.png")
	print("RESULT: %d arena checks, %d failures" % [checks, failures])
	paused = false
	for sound in game.find_children("*", "AudioStreamPlayer", true, false) + game.find_children("*", "AudioStreamPlayer3D", true, false):
		sound.stop()
	OS.delay_msec(50)
	game.queue_free()
	await frames(3)
	OS.delay_msec(50)
	quit(1 if failures else 0)
