extends "res://tests/verify.gd"
## Contrôle des trois points d'entrée et vues réelles du nouveau décor orbital.

var graphics: bool


func snap(name: String, pos: Vector3, target: Vector3) -> void:
	if not graphics:
		return
	await put_player(pos)
	await aim_at(target)
	await frames(24)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(image.save_png(ProjectSettings.globalize_path("res://tests/artifacts/"+name)) == OK, "Capture réelle : " + name)


func run() -> void:
	graphics = DisplayServer.get_name() != "headless"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/artifacts"))
	for path in ["res://scenes/main.tscn", "res://missions/relay_run/mission.tscn", "res://missions/relay_run/boss_trial.tscn"]:
		game = load(path).instantiate()
		root.add_child(game)
		current_scene = game
		player = game.player
		await frames(6)
		var arena: Node3D = game.get_node("Arena")
		var environment: Environment = arena.get_node("WorldEnvironment").environment
		check(environment.resource_path == "res://environment/space.tres" and not environment.fog_enabled, "Espace partagé et sans brume diurne : " + path)
		check(environment.sky.sky_material is PanoramaSkyMaterial, "Panorama étoilé chargé : " + path)
		check(environment.ambient_light_source == Environment.AMBIENT_SOURCE_COLOR and environment.ambient_light_energy >= .4, "Éclairage ambiant indépendant du ciel noir")
		var roofs: Node3D = arena.get_node("Plafonds")
		var sectors := roofs.get_children()
		check(sectors.size() == (1 if path.contains("main.tscn") else 7), "Toutes les zones ont leur toiture : " + path)
		check(roofs.find_children("*", "CollisionObject3D", true, false).is_empty(), "Les toitures visuelles préservent les collisions existantes")
		for sector: Node3D in sectors:
			# Plus haut que les trajectoires des sauts et la partie supérieure du boss.
			check(sector.position.y >= 8.5, "Dégagement sous " + sector.name)
		game.start_exploration()
		for actor in get_nodes_in_group("enemies"):
			actor.attack_enabled = false
			actor.move_speed = 0
		await frames(4)
		if path.contains("main.tscn"):
			await snap("orbite_entrainement.png", Vector3(0,.05,18), Vector3(-2,8,-5))
		elif path.contains("boss_trial"):
			await snap("orbite_boss.png", Vector3(-15,.05,-56), Vector3(0,6,-68))
		else:
			await snap("orbite_quai.png", Vector3(0,.05,64), Vector3(-4,7,40))
			await snap("orbite_verriere.png", Vector3(0,.05,42), Vector3(-1,18,31))
			await snap("orbite_maintenance.png", Vector3(52,.05,8), Vector3(50,9,-6))
			await snap("orbite_reacteur.png", Vector3(-18,.05,-32), Vector3(0,10,-58))
		for sound in game.find_children("*", "AudioStreamPlayer3D", true, false) + game.find_children("*", "AudioStreamPlayer", true, false):
			sound.stop()
		game.queue_free()
		paused = false
		await frames(4)
	print("RESULT: %d orbital environment checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
