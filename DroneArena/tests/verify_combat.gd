extends "res://tests/verify.gd"
## Scénarios de combat dans le vrai monde physique, sans IA simulée.

var director: Node3D
var drone: CharacterBody3D


func snapshot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var prefix := "petit_" if "--small" in OS.get_cmdline_user_args() else ""
	check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tests/artifacts/" + prefix + name)) == OK, "Capture " + name)


func finish() -> void:
	# Le pilote audio garde son rythme réel malgré la simulation accélérée.
	paused = false
	for sound in game.find_children("*", "AudioStreamPlayer", true, false) + game.find_children("*", "AudioStreamPlayer3D", true, false):
		sound.stop()
	OS.delay_msec(50)
	game.queue_free()
	await frames(3)
	OS.delay_msec(50)
	quit(1 if failures else 0)


func reset_shooting_lane() -> void:
	drone.attack_enabled = false
	drone.charge_remaining = 0.0
	for bolt in game.get_node("Projectiles").get_children():
		bolt.queue_free()
	player.restore_health()
	await put_player(Vector3(0, 0.05, 18))
	drone.global_position = Vector3(0, 2.4, 12)
	drone.rotation = Vector3(0, PI, 0)
	drone.velocity = Vector3.ZERO
	drone.move_speed = 0.0
	drone.charge_remaining = 0.0
	drone.cooldown = 0.0
	drone.attack_enabled = true
	await frames(3)


func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	player = game.get_node("Player")
	director = game.get_node("Drones")
	drone = director.get_child(0)
	var graphics := DisplayServer.get_name() != "headless"
	if graphics:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/artifacts"))
	await frames(5)
	check(director.get_child_count() == 3, "Trois drones présents")
	check(paused and player.health == 100, "Accueil en pause avec 100 points de vie")
	check(game.get_node("Interface/Header/Health/Bar").value == 100, "Jauge initialisée à 100")
	var initial_position := drone.global_position
	await frames(30)
	check(drone.global_position == initial_position and drone.shots_fired == 0, "Les drones attendent dans le menu")
	if graphics:
		await snapshot("combat_accueil.png")
	for actor in director.get_children():
		actor.attack_enabled = false
	game.resume_button.pressed.emit()
	await frames(10)
	check(director.navigation_ready, "Carte de vol construite au lancement")
	if "--capture-only" in OS.get_cmdline_user_args():
		await reset_shooting_lane()
		await aim_at(drone.global_position)
		await snapshot("drones.png")
		player.apply_damage(1000)
		await snapshot("defaite.png")
		var small_card: Control = game.get_node("Interface/Overlay/Card")
		var quit_button: Control = game.get_node("Interface/Overlay/Card/Content/Quit")
		check(small_card.get_viewport_rect().encloses(small_card.get_global_rect()), "Carte de défaite entièrement visible")
		check(quit_button.get_viewport_rect().encloses(quit_button.get_global_rect()), "Dernier bouton entièrement visible")
		await finish()
		return
	var route: PackedVector3Array = director.flight_path(Vector3(0, 2.4, -17), Vector3(0, 0, 18))
	check(route.size() > 10, "Un chemin traverse l'arène")
	var detour := false
	for point in route:
		if absf(point.x) >= 4:
			detour = true
	check(detour, "Le chemin contourne le réacteur central")
	for i in range(1, 3):
		director.get_child(i).process_mode = Node.PROCESS_MODE_DISABLED
	drone.global_position = Vector3(0, 2.4, -12)
	drone.velocity = Vector3.ZERO
	drone.path_refresh = 0.0
	await frames(150)
	check(absf(drone.position.x) > 3.0, "Le drone effectue réellement le détour")
	check(drone.position.distance_to(Vector3(0, 2.4, -7)) > 2.6, "Le drone ne traverse pas le réacteur")
	await put_player(Vector3(8, 0.05, -12))
	drone.global_position = Vector3(8, 2.4, 13)
	drone.velocity = Vector3.ZERO
	drone.path_refresh = 0.0
	await frames(180)
	check(drone.position.z < 8, "Le drone vole au-dessus d'un obstacle bas")
	check(absf(drone.position.y - 2.4) < 0.1, "Altitude de vol stable")

	await reset_shooting_lane()
	check(drone.charge_remaining > 0 and drone.warning.visible, "Un viseur rouge annonce le tir")
	check(player.health == 100, "Aucun dégât pendant l'annonce du tir")
	if graphics:
		await aim_at(drone.global_position)
		await snapshot("drones.png")
	var before_shots: int = drone.shots_fired
	await frames(40)
	check(drone.shots_fired == before_shots + 1, "Le drone tire après son avertissement")
	check(game.get_node("Projectiles").get_child_count() > 0, "Le tir crée un projectile en déplacement")
	for i in range(90):
		if player.health < 100:
			break
		await frames(1)
	check(player.health == 90, "Un projectile ennemi inflige dix points de dégâts")
	check(game.get_node("Interface/Header/Health/Bar").value == 90, "La jauge reflète les dégâts")
	check(game.get_node("Interface/Header/Health/Value").text.contains("90 / 100"), "La vie est aussi affichée en chiffres")
	check(game.damage_feedback_time > 0, "Retour visuel lorsqu'on est touché")
	check(not player.apply_damage(10) and player.health == 90, "Brève protection contre les impacts simultanés")
	check(not player.apply_damage(-10) and player.health == 90, "Un dégât négatif ne soigne pas le joueur")
	if graphics:
		await snapshot("degats.png")

	# Les acteurs et les projectiles suivent tous la pause.
	director.spawn_bolt(Vector3(-5, 2.4, 0), Vector3.FORWARD, drone.get_rid())
	await frames(2)
	var bolt: Node3D = game.get_node("Projectiles").get_child(0)
	await tap(KEY_ESCAPE)
	var frozen_bolt := bolt.global_position
	var frozen_drone := drone.global_position
	var frozen_lifetime: float = bolt.remaining
	await frames(30)
	check(bolt.global_position == frozen_bolt and bolt.remaining == frozen_lifetime, "Pause : projectile et durée de vie figés")
	check(drone.global_position == frozen_drone, "Pause : déplacement ennemi figé")
	check(not player.apply_damage(10) and player.health == 90, "Aucun dégât pendant la pause")
	game.resume_button.pressed.emit()
	await frames(2)
	check(bolt.global_position != frozen_bolt, "Le projectile reprend son déplacement")

	# L'ennemi vise la position annoncée ; le joueur peut l'esquiver.
	await reset_shooting_lane()
	key_event(KEY_D, true)
	await frames(30)
	key_event(KEY_D, false)
	await frames(50)
	check(player.health == 100, "Un déplacement latéral permet d'esquiver")
	await reset_shooting_lane()
	drone.charge_remaining = 0.0
	var wall := make_blocker(Vector3(0, 2, 15), Vector3(4, 5, 0.6))
	await frames(3)
	before_shots = drone.shots_fired
	await frames(130)
	check(drone.shots_fired == before_shots and not drone.warning.visible, "Le drone ne tire pas sans ligne de vue")
	check(player.health == 100, "Le mur protège le joueur")
	director.spawn_bolt(Vector3(0, 1.1, 12), Vector3.BACK, drone.get_rid())
	await frames(30)
	check(player.health == 100 and game.get_node("Projectiles").get_child_count() == 0, "Le projectile lui-même est arrêté par le mur")
	wall.queue_free()
	await frames(5)
	check(drone.charge_remaining > 0, "Le drone verrouille de nouveau après disparition de la couverture")
	wall = make_blocker(Vector3(0, 2, 15), Vector3(4, 5, 0.6))
	await frames(45)
	check(drone.shots_fired == before_shots and drone.charge_remaining == 0, "Une couverture interrompt le verrouillage en cours")
	drone.attack_enabled = false
	wall.queue_free()
	await frames(3)

	# Les tirs de l'arme existante atteignent les vrais corps ennemis.
	# Arrêter l'IA conserve le corps dans la physique (PROCESS_MODE_DISABLED
	# retirerait aussi sa collision avec le réglage Godot par défaut).
	drone.set_physics_process(false)
	drone.global_position = Vector3(0, 2.4, 10)
	drone.health = drone.max_health
	await put_player(Vector3(0, 0.05, 18))
	await aim_at(drone.global_position)
	for i in range(3):
		mouse_button(true)
		await frames(2)
		mouse_button(false)
		check(drone.health == 2 - i, "Impact %d sur le drone" % (i + 1))
		await frames(15)
	check(not drone.alive and drone.hit_shape.disabled, "Trois impacts neutralisent le drone et retirent sa collision")
	check(game.drones_destroyed == 1 and game.target_hits == 0, "Compteurs des drones et des cibles distincts")
	check(not drone.receive_hit() and game.drones_destroyed == 1, "Un drone détruit n'est pas compté deux fois")
	for i in range(1, 3):
		for hit in range(3):
			director.get_child(i).receive_hit()
	await frames(3)
	check(game.drones_destroyed == 3 and game.get_node("Interface/ClearBanner").visible, "Le secteur est sécurisé après les trois drones")
	check(not paused, "On peut continuer à explorer le secteur sécurisé")
	await frames(190)
	check(game.get_node("Effects").get_child_count() == 0, "Les débris et effets de destruction sont libérés")
	check(game.get_node("Wrecks").get_child_count()==3,"Les trois épaves restent dans l'arène sécurisée")

	await tap(KEY_ESCAPE)
	for actor in director.get_children():
		actor.process_mode = Node.PROCESS_MODE_INHERIT
		actor.set_physics_process(true)
		actor.attack_enabled = true
		actor.move_speed = 3.0
	game.reset_button.pressed.emit()
	await frames(10)
	check(player.health == 100 and game.drones_destroyed == 0, "Recommencer restaure la santé et les compteurs")
	check(not game.get_node("Interface/ClearBanner").visible, "Recommencer retire l'annonce de victoire")
	var all_alive := true
	for actor in director.get_children():
		all_alive = all_alive and actor.alive and actor.health == 3 and not actor.hit_shape.disabled
	check(all_alive, "Recommencer remet les trois drones en état")
	player.apply_damage(75)
	check(player.health == 25, "Les dégâts sont bornés dans la jauge")
	var fill := game.get_node("Interface/Header/Health/Bar").get_theme_stylebox("fill") as StyleBoxFlat
	check(fill.bg_color.r > fill.bg_color.g, "La jauge devient rouge quand la santé est faible")
	await frames(25)
	check(player.apply_damage(1000) and player.health == 0, "Les dégâts létaux ramènent la vie à zéro")
	check(game.game_over and paused and game.overlay.visible, "La défaite affiche un écran en pause")
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and not player.weapon.enabled, "Défaite : souris libre et arme désactivée")
	check(game.resume_button.text.contains("Recommencer"), "La défaite propose explicitement une nouvelle partie")
	if graphics:
		await snapshot("defaite.png")
	var card: Control = game.get_node("Interface/Overlay/Card")
	check(card.get_viewport_rect().encloses(card.get_global_rect()), "L'écran de défaite tient dans la fenêtre")
	await tap(KEY_ESCAPE)
	check(paused and game.game_over and player.health == 0, "Échap ne permet pas de reprendre une partie perdue")
	var death_position := drone.global_position
	var shot_count: int = player.weapon.shots_fired
	mouse_button(true)
	await frames(30)
	check(drone.global_position == death_position and player.weapon.shots_fired == shot_count, "Aucun combat ne continue après la défaite")
	game.resume_button.pressed.emit()
	await frames(10)
	check(not paused and not game.game_over and player.health == 100, "Le bouton Recommencer lance une nouvelle partie")
	check(player.weapon.shots_fired == shot_count, "Le clic de redémarrage ne tire pas")
	mouse_button(false)
	await frames(2)
	check(game.get_node("Projectiles").get_child_count() == 0 and game.drones_destroyed == 0, "Aucun projectile ni compteur hérité de la partie précédente")
	# Une rencontre complète avec les trois IA, leurs réglages réels et le joueur
	# immobile, complète les cas contrôlés ci-dessus.
	var previous_shots: Array[int] = []
	for actor in director.get_children():
		previous_shots.append(actor.shots_fired)
	var inside_arena := true
	var natural_capture := false
	for step in range(900):
		await frames(1)
		for actor in director.get_children():
			inside_arena = inside_arena and absf(actor.global_position.x) < 19.5 and absf(actor.global_position.z) < 23.5
		if graphics and not natural_capture and player.health <= 60:
			await snapshot("combat_reel.png")
			natural_capture = true
		if game.game_over:
			break
	var all_attacked := true
	for i in range(3):
		all_attacked = all_attacked and director.get_child(i).shots_fired > previous_shots[i]
	check(all_attacked, "Rencontre complète : les trois drones rejoignent le combat et attaquent")
	check(player.health < 100, "Rencontre complète : les projectiles des IA atteignent réellement le joueur")
	check(inside_arena, "Rencontre complète : aucun drone ne sort de l'arène")
	print("RESULT: %d combat checks, %d failures" % [checks, failures])
	await finish()
