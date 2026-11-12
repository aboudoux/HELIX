extends "res://tests/verify.gd"
## Modèles séparés, alignement avec le collider et bascule par les vrais tirs.


func bounds_of(model: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = model.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds


func snapshot(name: String) -> void:
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tests/artifacts/" + name)) == OK, "Capture " + name)


func run() -> void:
	create_timer(25.0).timeout.connect(func(): push_error("Délai de vérification des cibles dépassé"); quit(1))
	for name in ["helix_target_base", "helix_target_plate"]:
		var packed := load("res://assets/models/" + name + ".glb") as PackedScene
		check(packed != null, "Import du modèle " + name)
		if packed == null:
			quit(1)
			return
		var visual: Node3D = packed.instantiate()
		root.add_child(visual)
		check(visual.find_children("*", "CollisionObject3D", true, false).is_empty(), name + " ne contient aucun corps physique")
		check(visual.find_children("*", "Camera3D", true, false).is_empty() and visual.find_children("*", "Light3D", true, false).is_empty(), name + " exclut le studio")
		var meshes := visual.find_children("*", "MeshInstance3D", true, false)
		check(meshes.size() >= 5 and meshes.size() <= 10, name + " est regroupé par matériau pour le rendu")
		var bounds := bounds_of(visual)
		if name == "helix_target_plate":
			check(bounds.size.x <= 1.301 and absf(bounds.position.y) < 0.002 and absf(bounds.end.y - 1.30) < 0.002, "Disque à la bonne échelle et à 0,65 m au-dessus du pivot")
			check(bounds.position.z >= -0.081 and bounds.end.z <= 0.081, "Épaisseur du disque conforme au collider de 0,16 m")
		else:
			check(bounds.size.x <= 1.451 and bounds.size.z <= 0.851 and absf(bounds.position.y) < 0.001, "Socle à la bonne échelle et posé au sol")
		visual.free()

	game = load("res://scenes/main.tscn").instantiate()
	game.get_node("Drones").process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(game)
	current_scene = game
	player = game.get_node("Player")
	await frames(3)
	var target: StaticBody3D = game.get_node("Arena/Cible02")
	var base: Node3D = target.get_node("BaseVisual")
	var plate: Node3D = target.get_node("Plate/PlateVisual")
	check(base.scene_file_path == "res://assets/models/helix_target_base.glb" and plate.scene_file_path == "res://assets/models/helix_target_plate.glb", "La vraie cible utilise les deux nouveaux modèles GLB")
	check(base.transform.is_equal_approx(Transform3D.IDENTITY) and plate.transform.is_equal_approx(Transform3D.IDENTITY), "Modèles montés sans décalage ni changement d'échelle")
	check(target.plate.position.is_equal_approx(Vector3(0, 1, 0)), "Pivot de rabattement inchangé")
	check(target.hit_shape.shape is CylinderShape3D and is_equal_approx(target.hit_shape.shape.radius, 0.65) and is_equal_approx(target.hit_shape.shape.height, 0.16), "Forme, rayon et profondeur de collision inchangés")
	check(target.hit_shape.position.is_equal_approx(Vector3(0, 1.65, 0)) and target.collision_layer == 5 and target.collision_mask == 2, "Position du collider et couches physiques inchangées")
	check(target.recovery_delay == 2.0 and target.status.text == "PRÊT", "Délai de rétablissement et indication initiale inchangés")
	game.resume_button.pressed.emit()
	await put_player(Vector3(5, 0.05, 7.8))
	await aim_at(target.hit_shape.global_position)
	var graphics := DisplayServer.get_name() != "headless"
	if graphics:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/artifacts"))
		await snapshot("target_ready.png")
	var fixed_base := base.global_transform
	var upright := plate.global_transform
	mouse_button(true)
	await frames(2)
	mouse_button(false)
	check(player.weapon.last_hit.get("collider") == target and not target.active, "Un vrai tir vise le nouveau disque et désactive la cible")
	check(target.hit_shape.disabled and target.status.text == "TOUCHÉ" and game.target_hits == 1, "Collider désactivé, libellé et compteur mis à jour comme avant")
	await frames(15)
	check(is_equal_approx(target.plate.rotation_degrees.x, -80.0), "Le disque importé se rabat à 80 degrés")
	check(not plate.global_transform.is_equal_approx(upright) and base.global_transform.is_equal_approx(fixed_base), "Le disque bascule ; le socle et la charnière restent fixes")
	for name in ["Cible01", "Cible03", "Cible04"]:
		var other: StaticBody3D = game.get_node("Arena/" + name)
		check(other.active and other.plate.rotation.is_zero_approx(), "Les autres instances restent prêtes : " + name)
	if graphics:
		await snapshot("target_hit.png")
	await tap(KEY_ESCAPE)
	var remaining: float = target.recovery_remaining
	var frozen := plate.global_transform
	await frames(25)
	check(plate.global_transform.is_equal_approx(frozen) and is_equal_approx(remaining, target.recovery_remaining), "La pause fige aussi le modèle et son délai de rétablissement")
	game.resume_button.pressed.emit()
	await frames(130)
	check(target.active and not target.hit_shape.disabled and target.plate.rotation.is_zero_approx(), "Retour après deux secondes de jeu avec collision réactivée")
	check(plate.global_transform.is_equal_approx(upright) and target.status.text == "PRÊT", "Le modèle importé revient exactement dans sa pose initiale")
	mouse_button(true)
	await frames(2)
	mouse_button(false)
	check(not target.active and game.target_hits == 2, "Un second tir fonctionne après le retour de la cible")
	game.restart_exploration()
	await frames(5)
	check(target.active and not target.hit_shape.disabled and target.plate.rotation.is_zero_approx() and game.target_hits == 0, "Recommencer restaure la cible et le compteur")
	print("RESULT: %d target checks, %d failures" % [checks, failures])
	paused = false
	for sound in game.find_children("*", "AudioStreamPlayer", true, false) + game.find_children("*", "AudioStreamPlayer3D", true, false):
		sound.stop()
	OS.delay_msec(50)
	game.queue_free()
	await frames(3)
	OS.delay_msec(50)
	quit(1 if failures else 0)
