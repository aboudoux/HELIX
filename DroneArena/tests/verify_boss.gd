extends "res://tests/verify.gd"
## Vrai niveau, GLB, IA, tirs, collisions, progression et redémarrage.

var boss: CharacterBody3D
var graphics: bool


func snap(name: String) -> void:
	if graphics:
		await frames(3)
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tests/artifacts/"+name))==OK,"Capture "+name)


func cleanup() -> void:
	for sound in game.find_children("*","AudioStreamPlayer",true,false)+game.find_children("*","AudioStreamPlayer3D",true,false): sound.stop()
	OS.delay_msec(50)
	game.queue_free()
	paused = false
	await frames(4)
	OS.delay_msec(80)


func run() -> void:
	graphics = DisplayServer.get_name() != "headless"
	game = load("res://missions/relay_run/mission.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	player = game.player
	boss = game.boss
	await frames(8)
	check(paused and not boss.alive and not boss.visible and boss.hit_shape.disabled,"Le boss dort hors du monde avant le troisième relais")
	check(not boss.receive_hit(),"Un boss dormant ne reçoit aucun dégât")
	check(boss.rotor_blades.size()==4 and boss.muzzles.size()==2 and boss.barrels.size()==2,"Le GLB fournit quatre hélices et deux armes animables")
	for blades in boss.rotor_blades: check(is_instance_valid(blades),"Pivot d'hélice présent")
	check(boss.hit_shape.shape.size.x>=6 and boss.muzzles[0].position.z<-2,"Envergure de six mètres et longues mitrailleuses")
	for level in range(3):
		boss.configure_difficulty(difficulty.PROFILES[level])
		check(boss.health==[32,44,60][level] and boss.projectile_damage==[4,6,8][level],"Vie et dégâts du boss adaptés à la difficulté")
		check(boss.charge_duration>=.95 and boss.rounds_per_burst%2==0,"Préavis suffisant et rafale équilibrée entre les deux armes")
	game.apply_difficulty()
	game.start_exploration()
	for sector in range(3):
		game.director.engage_sector(sector)
		for guard in game.director.get_children():
			guard.attack_enabled = false
			guard.move_speed = 0
			if guard.alive:
				for hit in range(guard.max_health): guard.receive_hit()
		await put_player(game.relays[sector].position+Vector3(0,.05,2))
		await tap(KEY_E)
		await frames(85)
		check(game.stage==sector+1,"Activation du relais %d" % (sector+1))
		if sector<2: check(not boss.alive,"Les premiers relais ne réveillent pas le boss")
	check(boss.alive and boss.visible and not boss.hit_shape.disabled,"Le troisième relais réveille CERBÈRE")
	check(not game.gates[2].fully_open,"L'extraction reste verrouillée pendant le combat")
	check(game.drones_destroyed==15 and game.get_node("Interface/MissionHUD/Boss").visible,"Compteurs séparés et jauge de boss visible")
	var boss_rect: Rect2 = game.get_node("Interface/MissionHUD/Boss").get_global_rect()
	for node in ["Interface/Header/Difficulty", "Interface/Header/Health", "Interface/MissionHUD/Objective", "Interface/MissionHUD/MapPanel"]:
		check(not boss_rect.intersects(game.get_node(node).get_global_rect()),"La jauge ne recouvre pas "+node.get_file())
	await put_player(Vector3(0,.05,-90))
	await frames(140)
	check(not game.mission_complete and game.extraction_progress==0,"Aucune victoire possible tant que CERBÈRE vit")
	boss.attack_enabled = false
	await put_player(Vector3(-15,.05,-56))
	await frames(10)
	var before := boss.position
	var blade_angle: float = boss.rotor_blades[0].rotation.y
	await frames(130)
	check(boss.position.distance_to(before)>2,"Le boss se déplace réellement dans la cour")
	check(not is_equal_approx(boss.rotor_blades[0].rotation.y,blade_angle),"Les grandes turbines tournent en jeu")
	check(boss.position.x>=-28 and boss.position.x<=28 and boss.position.z>=-71 and boss.position.z<=-30,"Le boss reste dans l'arène finale")
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = boss.hit_shape.shape
	query.transform = boss.global_transform
	query.collision_mask = 1
	check(game.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(),"Le colosse ne traverse pas les obstacles")
	# Position connue : rafale réelle vers le joueur, avec préavis et deux armes.
	boss.activate()
	boss.move_speed = 0
	boss.attack_enabled = true
	await put_player(Vector3(-15,.05,-56))
	await aim_at(boss.global_position)
	await frames(70)
	check(boss.has_line_of_sight(),"Le boss voit réellement le joueur dans sa cour")
	boss.cooldown = 0
	await frames(8)
	check(boss.charge_remaining>0 and boss.shots_fired==0,"Le verrouillage précède tout tir")
	check(boss.warnings[0].visible and boss.warnings[1].visible,"Deux lasers annoncent les deux canons")
	await snap("boss_verrouillage.png")
	var aim: Vector3 = boss.locked_aim
	await frames(135)
	check(boss.left_shots>=4 and boss.right_shots>=4 and abs(boss.left_shots-boss.right_shots)<=1,"Les deux mitrailleuses alternent une vraie rafale")
	await frames(45)
	check(player.health<100 and player.health>0 and (100-player.health)%boss.projectile_damage==0,"Les projectiles infligent de vrais dégâts sans tuer en une rafale")
	check(boss.locked_aim.is_equal_approx(aim),"La visée reste figée pendant la rafale pour permettre l'esquive")
	# Le joueur utilise réellement son contrôleur pour quitter le point annoncé.
	player.restore_health()
	boss.cooldown = 0
	await frames(6)
	var dodge_origin := player.position
	Input.action_press("move_right")
	await frames(100)
	Input.action_release("move_right")
	await frames(80)
	check(player.position.distance_to(dodge_origin)>4 and player.health==100,"Un déplacement latéral esquive la rafale annoncée")
	# Une paroi ferme la ligne de vue et annule les tirs.
	await put_player(Vector3(0,.05,-90))
	var shots: int = boss.shots_fired
	await frames(240)
	check(boss.shots_fired==shots and boss.burst_remaining==0,"Le boss ne tire pas à travers la porte d'extraction")
	await put_player(Vector3(-15,.05,-56))
	boss.attack_enabled = false
	player.restore_health()
	await aim_at(boss.global_position)
	var health_before: int = boss.health
	mouse_button(true)
	await frames(2)
	mouse_button(false)
	await frames(3)
	check(boss.health==health_before-1,"Le fusil actuel endommage le modèle du boss")
	check(game.get_node("Interface/MissionHUD/Boss/Content/Health").value==boss.health,"La jauge suit les vrais impacts")
	while boss.health>boss.max_health/2: boss.receive_hit()
	await frames(3)
	check(boss.phase==2 and game.get_node("Interface/MissionHUD/Boss/Content/Phase").text.contains("SURCHAUFFE"),"La moitié de vie déclenche la seconde phase")
	# Vérifier la vraie cadence et le nombre de projectiles en seconde phase.
	boss.attack_enabled = true
	boss.cooldown = 0
	await frames(8)
	var phase2_shots: int = boss.shots_fired
	check(boss.charge_remaining>0 and boss.charge_remaining<boss.charge_duration,"La seconde phase garde un préavis lisible")
	await frames(130)
	check(boss.shots_fired-phase2_shots==boss.rounds_per_burst+2,"La seconde phase tire une rafale réellement plus longue")
	boss.attack_enabled = false
	player.restore_health()
	await snap("boss_phase2.png")
	game.show_pause()
	var paused_position := boss.position
	var paused_barrel: Vector3 = boss.barrels[0].rotation
	await frames(30)
	check(boss.position==paused_position and boss.barrels[0].rotation==paused_barrel,"La pause fige IA et animations")
	check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE and not boss.receive_hit(),"Échap libère la souris et bloque les dégâts")
	game.start_exploration()
	while boss.alive: boss.receive_hit()
	await frames(85)
	check(game.stage==4 and game.gates[2].fully_open and boss.hit_shape.disabled,"La mort du boss ouvre réellement l'extraction et retire sa collision")
	check(not boss.receive_hit() and not game.get_node("Interface/MissionHUD/Boss").visible,"Le boss ne meurt qu'une fois et sa jauge disparaît")
	check(is_instance_valid(boss.wreck) and boss.wreck.heavy and boss.wreck.visible,"La neutralisation conserve une grande épave du boss")
	await put_player(Vector3(0,.05,-90))
	await frames(140)
	check(not game.mission_complete and game.stage==4 and game.lift.unlocked,"CERBÈRE débloque la montée vers le deuxième niveau")
	game.restart_exploration()
	await frames(5)
	check(game.stage==0 and not boss.alive and boss.health==44 and boss.phase==1,"Rejouer restaure le boss dormant et sa vie")
	check(not game.gates[2].fully_open and player.health==100,"Le redémarrage referme l'extraction et soigne le joueur")
	await cleanup()
	game = load("res://missions/relay_run/boss_trial.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	player = game.player
	boss = game.boss
	await frames(5)
	check(paused and game.title.text=="CERBÈRE.","Le raccourci propose un menu de test du boss")
	game.start_exploration()
	await frames(8)
	check(game.stage==3 and boss.alive and player.position.z<-50,"Le raccourci place directement face au boss")
	boss.attack_enabled = false
	await aim_at(boss.global_position)
	await snap("boss_combat.png")
	game.restart_exploration()
	await frames(5)
	check(game.stage==3 and boss.alive and boss.health==44 and player.health==100,"Le raccourci permet aussi de recommencer le combat")
	await cleanup()
	print("RESULT: %d boss checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
