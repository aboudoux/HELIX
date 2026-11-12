extends "res://tests/verify.gd"
## Sélection par le vrai GUI, impacts et projectiles réels dans les trois niveaux.

var graphics: bool
var preferences_path: String
var director: Node3D
const HEALTH := [2,3,4]
const DAMAGE := [5,10,15]
const FIRE_SCALE := [1.45,0.9,0.65]


func click(control: Control) -> void:
	await frames(3)
	if graphics:
		await RenderingServer.frame_post_draw
	var position := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = position
	root.push_input(motion,true)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.pressed = pressed
		root.push_input(event,true)
		await frames(2)


func snap(name: String) -> void:
	if not graphics:
		return
	await frames(3)
	await RenderingServer.frame_post_draw
	var prefix := "small_" if "--small" in OS.get_cmdline_user_args() else ""
	check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tests/artifacts/"+prefix+name)) == OK,"Capture "+name)


func check_menu() -> void:
	var card: Control = game.get_node("Interface/Overlay/Card")
	check(card.get_viewport_rect().encloses(card.get_global_rect()),"Menu entièrement dans la fenêtre")
	for control in [game.resume_button,game.get_node("Interface/Overlay/Card/Content/Quit"),game.difficulty_picker]:
		check(card.get_global_rect().encloses(control.get_global_rect()),"Boutons et choix entièrement dans le menu")
	var count := 0
	for button in game.difficulty_picker.get_node("Choices").get_children():
		count += 1 if button.button_pressed else 0
	check(count == 1,"Un seul niveau est visiblement sélectionné")


func verify_scene(path: String, mission: bool, level: int) -> void:
	difficulty.selected = 1
	game = load(path).instantiate()
	root.add_child(game)
	current_scene = game
	player = game.get_node("Player")
	director = game.get_node("Drones")
	await frames(8)
	var choice: Button = game.difficulty_picker.get_node("Choices").get_child(level)
	await click(choice)
	check(difficulty.selected == level and paused,"Le clic choisit le niveau sans démarrer ni tirer")
	check_menu()
	check(player.weapon.shots_fired == 0,"Le choix de difficulté ne déclenche aucun tir")
	var prefix := "mission" if mission else "entrainement"
	await snap("difficulte_%s_%d.png" % [prefix,level])
	await click(game.resume_button)
	check(game.active_difficulty == level and not paused,"Commencer applique le niveau choisi")
	check(game.get_node("Interface/Header/Difficulty").text.contains(difficulty.PROFILES[level].name.to_upper()),"Le HUD affiche le niveau actif")
	var base_interval := 3.1 if mission else 2.2
	for actor in director.get_children():
		actor.attack_enabled = false
		actor.move_speed = 0.0
	check(director.projectile_damage == DAMAGE[level],"Dégâts configurés pour la rencontre")
	if mission:
		check(director.current_sector == -1,"Le choix conserve le quai sûr et les ennemis dormants")
		await put_player(Vector3(14,0.05,23))
	await put_player(Vector3(18,0.05,60) if mission else Vector3(0,0.05,18))
	var actor: CharacterBody3D = director.get_child(0)
	actor.position = Vector3(18,2.4,54) if mission else Vector3(0,2.4,12)
	actor.rotation.y = PI
	actor.velocity = Vector3.ZERO
	check(actor.health == HEALTH[level] and actor.max_health == HEALTH[level],"Résistance correcte au début du combat")
	check(is_equal_approx(actor.fire_interval,base_interval*FIRE_SCALE[level]),"Cadence adaptée à la scène et au niveau")
	actor.cooldown = 0.0
	actor.attack_enabled = true
	for tick in range(180):
		await frames(1)
		if player.health < 100:
			break
	check(actor.shots_fired > 0 and player.health == 100-DAMAGE[level],"Un vrai projectile inflige les dégâts du niveau")
	actor.attack_enabled = false
	for bolt in game.get_node("Projectiles").get_children():
		bolt.queue_free()
	await aim_at(actor.position)
	for hit in range(HEALTH[level]):
		mouse_button(true)
		await frames(2)
		mouse_button(false)
		check(actor.alive == (hit < HEALTH[level]-1),"Le fusil détruit le drone au bon nombre d'impacts")
		await frames(15)
	check(game.drones_destroyed == 1,"La difficulté conserve le comptage des destructions")
	await tap(KEY_ESCAPE)
	var next := (level+1)%3
	await click(game.difficulty_picker.get_node("Choices").get_child(next))
	check(game.difficulty_picker.get_node("Description").text.contains("Reprendre conserve"),"La pause explique l'application au redémarrage")
	await click(game.resume_button)
	check(game.active_difficulty == level and director.projectile_damage == DAMAGE[level],"Reprendre conserve la difficulté et les dégâts en cours")
	check(not actor.alive and game.drones_destroyed == 1,"Changer le choix en pause ne réanime aucun ennemi")
	await tap(KEY_ESCAPE)
	await click(choice)
	await click(game.resume_button)
	if mission:
		for sector in range(3):
			director.engage_sector(sector)
			for guard in director.get_children():
				if guard.alive and int(guard.get_meta("sector")) == sector:
					for hit in range(HEALTH[level]):
						guard.receive_hit()
			var relay: Node3D = game.relays[sector]
			await put_player(relay.position + Vector3(0,0.05,2))
			await tap(KEY_E)
			await frames(85)
			check(game.stage == sector+1 and game.gates[sector].fully_open == (sector<2) and player.health == 100,"Relais, portes et soin fonctionnent à ce niveau")
		check(game.boss.alive and game.boss.max_health==[32,44,60][level],"Le boss se réveille avec la vie de la difficulté jouée")
		game.boss.attack_enabled = false
		while game.boss.alive: game.boss.receive_hit()
		await frames(85)
		check(game.stage==4 and game.gates[2].fully_open and game.lift.unlocked,"CERBÈRE ouvre l’ascenseur dans chaque difficulté")
		await put_player(Vector3(0,0.05,-90))
		check(game.lift.request_ride(player),"L'ascenseur accepte le départ après CERBÈRE")
		await frames(660)
		check(game.stage==5 and absf(player.position.y-14)<.1,"Montée physique complète dans la difficulté jouée")
		for upper_sector in range(2):
			game.upper_director.engage_sector(upper_sector)
			for guard in game.upper_director.get_children():
				guard.attack_enabled = false
				if guard.alive:
					check(guard.max_health==HEALTH[level],"Les gardes du deuxième étage utilisent le niveau actif")
					while guard.alive: guard.receive_hit()
			await put_player(game.upper_relays[upper_sector].global_position+Vector3(0,.05,2))
			check(game.activate_upper_relay(),"La console supérieure suit la même difficulté")
			await frames(85)
		check(game.alpha.alive and game.alpha.max_health==[60,85,115][level],"FENRIR se réveille avec la résistance de la difficulté jouée")
		game.alpha.attack_enabled = false
		while game.alpha.alive: game.alpha.receive_hit()
		await frames(85)
		await put_player(Vector3(0,14.05,-230))
		await frames(140)
		check(game.mission_complete and paused and game.drones_destroyed==27,"Les deux étages peuvent être terminés dans ce niveau")
		check(game.get_node("Interface/Overlay/Card/Content/Note").text.contains(difficulty.PROFILES[level].name),"Le bilan conserve le niveau réellement joué")
		check_menu()
		await click(game.difficulty_picker.get_node("Choices").get_child(next))
		await snap("difficulte_bilan_%d.png" % level)
		await click(game.resume_button)
	else:
		await tap(KEY_ESCAPE)
		await click(game.difficulty_picker.get_node("Choices").get_child(next))
		await click(game.reset_button)
	check(game.active_difficulty == next and player.health == 100 and game.drones_destroyed == 0,"Recommencer applique le nouveau niveau et remet les compteurs à zéro")
	check(actor.max_health == HEALTH[next] and actor.health == HEALTH[next] and director.projectile_damage == DAMAGE[next],"Ennemis et projectiles utilisent ensemble le nouveau niveau")
	game.show_pause()
	game.reset_button.pressed.emit()
	await frames(5)
	check(is_equal_approx(actor.fire_interval,base_interval*FIRE_SCALE[next]),"Les redémarrages ne cumulent pas les multiplicateurs")
	player.apply_damage(1000)
	await frames(3)
	check_menu()
	await click(game.difficulty_picker.get_node("Choices").get_child(level))
	await click(game.resume_button)
	check(not game.game_over and game.active_difficulty == level and player.health == 100,"La défaite permet de repartir avec un autre niveau")
	for sound in game.find_children("*","AudioStreamPlayer",true,false)+game.find_children("*","AudioStreamPlayer3D",true,false):
		sound.stop()
	OS.delay_msec(25)
	game.queue_free()
	paused = false
	await frames(3)


func run() -> void:
	graphics = DisplayServer.get_name() != "headless"
	preferences_path = difficulty.settings_path
	difficulty.settings_path = "user://difficulty_verification_%d.cfg" % OS.get_process_id()
	difficulty.load_preference()
	check(difficulty.selected == 1,"Sans préférence, le niveau par défaut est Moyen")
	for level in range(3):
		difficulty.select(level)
		difficulty.selected = -1
		difficulty.load_preference()
		check(difficulty.selected == level,"Le choix est sauvegardé et relu")
	var invalid := ConfigFile.new()
	invalid.set_value("game","difficulty","impossible")
	invalid.save(difficulty.settings_path)
	invalid = null
	difficulty.load_preference()
	check(difficulty.selected == 1,"Une préférence invalide revient à Moyen")
	for level in range(3):
		await verify_scene("res://missions/relay_run/mission.tscn",true,level)
		await verify_scene("res://scenes/main.tscn",false,level)
	difficulty.select(0)
	game = load("res://missions/relay_run/mission.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await frames(8)
	var hard: Button = game.difficulty_picker.get_node("Choices/Hard")
	hard.grab_focus()
	await tap(KEY_SPACE)
	check(difficulty.selected == 2 and hard.button_pressed,"Le niveau peut être choisi au clavier")
	await click(game.difficulty_picker.get_node("Choices/Easy"))
	await click(game.reset_button)
	game = current_scene
	check(game.scene_file_path == "res://scenes/main.tscn" and game.active_difficulty == 0,"Passer de la mission à l'entraînement conserve le niveau choisi")
	check(game.difficulty_picker.get_node("Choices/Easy").button_pressed,"La scène suivante affiche la préférence commune")
	game.queue_free()
	paused = false
	await frames(3)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(difficulty.settings_path))
	difficulty.settings_path = preferences_path
	difficulty.load_preference()
	print("RESULT: %d difficulty checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
