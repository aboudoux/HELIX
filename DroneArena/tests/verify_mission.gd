extends "res://tests/verify.gd"
## Parcours de la mission dans sa vraie physique, puis boucle de jeu complète.

var director: Node3D
var walking_grid := AStarGrid2D.new()
var graphics: bool


func snap(name: String) -> void:
	if not graphics:
		return
	await frames(3)
	await RenderingServer.frame_post_draw
	var prefix := "small_" if "--small" in OS.get_cmdline_user_args() else ""
	check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tests/artifacts/" + prefix + name)) == OK, "Capture " + name)


func ground_grid() -> void:
	walking_grid.region = director.bounds
	walking_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	walking_grid.update()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.88, 1.65, 0.88)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 1
	var space := game.get_world_3d().direct_space_state
	for x in range(director.bounds.position.x, director.bounds.end.x):
		for z in range(director.bounds.position.y, director.bounds.end.y):
			var inside := false
			for rect in game.layout.floors:
				inside = inside or Rect2(rect[0],rect[1],rect[2],rect[3]).has_point(Vector2(x,z))
			query.transform = Transform3D(Basis.IDENTITY, Vector3(x, 0.95, z))
			walking_grid.set_point_solid(Vector2i(x,z), not inside or not space.intersect_shape(query,1).is_empty())


func walk_to(destination: Vector2) -> bool:
	var path := walking_grid.get_id_path(Vector2i(roundi(player.position.x),roundi(player.position.z)), Vector2i(destination))
	if path.is_empty():
		return false
	var index := 0
	Input.action_press("move_forward")
	for tick in range(path.size() * 35 + 180):
		var offset := Vector2(path[index])-Vector2(player.position.x,player.position.z)
		if offset.length() < 0.22:
			index += 1
			if index == path.size():
				Input.action_release("move_forward")
				await frames(8)
				return Vector2(player.position.x,player.position.z).distance_to(destination) < 0.6
			offset = Vector2(path[index])-Vector2(player.position.x,player.position.z)
		player.rotation.y = atan2(-offset.x,-offset.y)
		await frames(1)
	Input.action_release("move_forward")
	print("WALK BLOCKED ",player.position," destination ",destination)
	return false


func kill_sector(index: int) -> void:
	for actor in director.get_children():
		if int(actor.get_meta("sector")) == index and actor.alive:
			for hit in range(3):
				actor.receive_hit()
	await frames(3)


func finish_mission_test() -> void:
	print("RESULT: %d checks, %d failures" % [checks,failures])
	paused = false
	for sound in game.find_children("*","AudioStreamPlayer",true,false)+game.find_children("*","AudioStreamPlayer3D",true,false):
		sound.stop()
	# Les voix audio se terminent sur le mixeur, indépendamment du pas physique.
	OS.delay_msec(50)
	game.queue_free()
	await frames(3)
	OS.delay_msec(80)
	quit(1 if failures else 0)


func run() -> void:
	game = load("res://missions/relay_run/mission.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	player = game.get_node("Player")
	director = game.get_node("Drones")
	graphics = DisplayServer.get_name() != "headless"
	await frames(8)
	check(paused and not game.has_started and player.health == 100, "Mission en attente dans l'accueil")
	check(director.get_child_count() == 15 and game.layout.floors.size() == 7, "Grande carte : sept zones et quinze sentinelles")
	check(director.remaining(0) == 0 and not director.get_child(0).visible, "Aucun ennemi actif dans l'accueil")
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Souris libre dans le menu")
	check(not game.activate_relay(), "Un relais ne s'active pas depuis le menu")
	var card: Control = game.get_node("Interface/Overlay/Card")
	check(card.get_viewport_rect().encloses(card.get_global_rect()), "Menu entièrement visible")
	await snap("mission_accueil.png")
	for actor in director.get_children():
		actor.attack_enabled = false
		actor.move_speed = 0.0
	game.resume_button.pressed.emit()
	await frames(12)
	check(not paused and player.is_on_floor(), "Démarrage au sol")
	check(player.position.distance_to(Vector3(0,0,64)) < 0.1, "Départ dans le quai agrandi")
	check(director.current_sector == -1, "Zone de départ sûre avant la première ligne")
	check(not game.activate_relay(), "Aucune activation à distance")
	await snap("mission_quai.png")
	# Une porte fermée bloque réellement le contrôleur CharacterBody3D.
	await put_player(Vector3(14,0.05,23))
	Input.action_press("move_forward")
	await frames(60)
	Input.action_release("move_forward")
	check(player.position.z > 20.5, "La porte verrouillée arrête le joueur")
	check(director.current_sector == 0 and director.remaining(0) == 4, "Le cargo déclenche quatre ennemis")
	check(not game.activate_relay(), "Le relais reste verrouillé tant que les gardes sont vivants")
	# La grille du directeur traverse les deux entrées des annexes sans couper les murs.
	for pair in [[Vector3(-53,2.4,32),Vector3(0,2.4,58)], [Vector3(57,2.4,-8),Vector3(20,2.4,10)], [Vector3(-53,2.4,-61),Vector3(-20,2.4,-30)]]:
		check(director.flight_path(pair[0],pair[1]).size() > 12, "Trajet de drone dans une annexe")
	# Le drone parcourt un vrai détour dans l'annexe logistique.
	var actor: CharacterBody3D = director.get_child(2)
	await put_player(Vector3(-30,0.05,53))
	actor.move_speed = 3.0
	var before := actor.position
	await frames(180)
	check(actor.position.distance_to(before) > 3.0 and actor.position.y > 2.1, "Un drone se déplace réellement dans l'annexe")
	actor.move_speed = 0.0
	# Tir ennemi, puis trois tirs du vrai fusil sur la sentinelle.
	await put_player(Vector3(18,0.05,60))
	actor = director.get_child(0)
	actor.position = Vector3(18,2.4,54)
	actor.rotation.y = PI
	actor.velocity = Vector3.ZERO
	actor.cooldown = 0.0
	actor.attack_enabled = true
	await frames(100)
	check(actor.shots_fired > 0 and player.health == 90, "Le combat de la mission inflige dix points de dégâts")
	actor.attack_enabled = false
	await aim_at(actor.position)
	for hit in range(3):
		mouse_button(true)
		await frames(2)
		mouse_button(false)
		await frames(15)
	check(not actor.alive and game.drones_destroyed == 1, "Trois tirs du fusil détruisent une sentinelle de mission")
	# Les soins sont consommés seulement lorsque le joueur est blessé.
	var kit: Node3D = game.get_node("Arena/Medical/Kit3")
	player.health = 45
	await put_player(kit.position + Vector3(0,0.05,0))
	check(player.health == 85 and not kit.visible, "Un kit soigne de 40 points et disparaît")
	await frames(30)
	check(player.health == 85, "Le kit est à usage unique")
	await put_player(Vector3(0,0.05,64))
	ground_grid()
	if "--capture-only" not in OS.get_cmdline_user_args():
		check(await walk_to(Vector2(-53,34)), "Parcours physique du quai jusqu'au relais logistique")
	else:
		await put_player(Vector3(-53,0.05,34))
	check(not game.activate_relay(), "Un relais proche reste protégé par ses gardes")
	await kill_sector(0)
	check(game.relay_accessible(), "Relais logistique accessible après le combat")
	var wall := make_blocker(Vector3(-53,1,33),Vector3(2,2,0.1))
	await frames(3)
	await tap(KEY_E)
	check(game.stage == 0 and not game.relay_accessible(), "Une paroi empêche l'activation d'un relais même proche")
	wall.queue_free()
	await frames(3)
	await tap(KEY_E)
	check(game.stage == 1 and player.health == 100 and game.gates[0].unlocked, "E rétablit le premier relais, soigne et ouvre sa porte")
	await frames(20)
	await tap(KEY_ESCAPE)
	var gate_progress: float = game.gates[0].progress
	var clock: float = game.elapsed
	await frames(60)
	check(game.gates[0].progress == gate_progress and game.elapsed == clock, "La pause fige portes et chronomètre")
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and not player.weapon.enabled, "Pause : souris libre et arme arrêtée")
	game.resume_button.pressed.emit()
	await frames(85)
	check(game.gates[0].fully_open and game.gates[0].get_node("Barrier/CollisionShape3D").disabled, "La porte retire sa collision après son ouverture")
	ground_grid()
	if "--capture-only" not in OS.get_cmdline_user_args():
		check(await walk_to(Vector2(14,16)), "Retour de l'annexe et passage de la première porte")
		check(await walk_to(Vector2(57,-6)), "Accès physique au relais de maintenance")
	else:
		await put_player(Vector3(57,0.05,-6))
	check(director.current_sector == 1 and director.remaining(1) == 5, "Le refroidissement déclenche cinq ennemis")
	await aim_at(game.relays[1].position + Vector3(0,1.1,0))
	await snap("mission_maintenance.png")
	await kill_sector(1)
	await tap(KEY_E)
	await frames(85)
	check(game.stage == 2 and game.gates[1].fully_open, "Deuxième relais et deuxième porte validés")
	# Les rampes portent le personnage à trois mètres, avec le même contrôleur.
	await put_player(Vector3(-1,0.05,-15))
	player.rotation.y = -PI/2
	Input.action_press("move_forward")
	var peak := 0.0
	for tick in range(310):
		peak = maxf(peak,player.position.y)
		await frames(1)
	Input.action_release("move_forward")
	check(peak > 2.9 and player.position.x > 27, "Montée et descente réelles de la passerelle par ses deux rampes")
	await put_player(Vector3(14,3.05,-15))
	await aim_at(Vector3(4,1.6,4))
	await snap("mission_passerelle.png")
	ground_grid()
	await put_player(Vector3(-16,0.05,-18))
	if "--capture-only" not in OS.get_cmdline_user_args():
		check(await walk_to(Vector2(-53,-59)), "Parcours physique du cœur vers la centrale énergie")
	else:
		await put_player(Vector3(-53,0.05,-59))
	check(director.current_sector == 2 and director.remaining(2) == 6, "Le cœur déclenche six ennemis")
	await kill_sector(2)
	await tap(KEY_E)
	await frames(85)
	check(game.stage == 3 and game.drones_destroyed == 15 and not game.gates[2].fully_open and game.boss.alive, "Les trois relais réveillent le boss et l'extraction reste verrouillée")
	game.boss.attack_enabled = false
	while game.boss.alive:
		game.boss.receive_hit()
	await frames(85)
	check(game.stage == 4 and game.gates[2].fully_open, "Vaincre le boss ouvre la dernière porte")
	ground_grid()
	if "--capture-only" not in OS.get_cmdline_user_args():
		check(await walk_to(Vector2(0,-85)), "Retour de la centrale et accès physique à l'extraction")
	for boundary in [[Vector3(0,0.05,70),PI],[Vector3(66,0.05,-1),-PI/2],[Vector3(-62,0.05,42),PI/2],[Vector3(0,0.05,-96),0.0]]:
		await put_player(boundary[0])
		player.rotation.y = boundary[1]
		var start := player.position
		Input.action_press("move_forward")
		await frames(45)
		Input.action_release("move_forward")
		check(player.position.distance_to(start) < 1.4 and player.is_on_floor(), "Le mur extérieur empêche de quitter la carte")
	await put_player(Vector3(0,0.05,-90))
	await frames(140)
	check(not game.mission_complete and game.stage==4 and game.extraction_progress==0, "L'ancien point d'extraction mène maintenant à l'ascenseur")
	check(game.lift.unlocked and game.lift.contains_player(player), "Cabine accessible après CERBÈRE")
	game.restart_exploration()
	await frames(12)
	check(game.stage==0 and not game.mission_complete and not paused and player.health==100, "Rejouer réinitialise mission et santé")
	check(director.current_sector==-1 and game.drones_destroyed==0 and kit.visible, "Rejouer restaure les gardes et les soins")
	check(not game.lift.unlocked and game.lift.cab.position.y==0 and not game.alpha.alive, "Rejouer réinitialise l'ascenseur et FENRIR")
	player.apply_damage(1000)
	check(game.game_over and paused and game.title.text == "Signal perdu.", "Défaite gérée dans la mission")
	await snap("mission_defaite.png")
	game.resume_button.pressed.emit()
	await frames(10)
	check(not game.game_over and player.health == 100 and not paused, "Recommencer après défaite fonctionne")
	await finish_mission_test()
