extends "res://tests/verify.gd"
## Perception réelle, radio, bruit, absence de suivi à travers les murs et flancs.


func cleanup() -> void:
	mouse_button(false)
	for sound in game.find_children("*","AudioStreamPlayer",true,false)+game.find_children("*","AudioStreamPlayer3D",true,false): sound.stop()
	OS.delay_msec(50)
	game.queue_free()
	paused = false
	await frames(4)
	OS.delay_msec(80)


func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	player = game.player
	var director: Node3D = game.get_node("Drones")
	var left: CharacterBody3D = director.get_child(0)
	var right: CharacterBody3D = director.get_child(1)
	for actor in director.get_children():
		if "--lunar" in OS.get_cmdline_user_args(): actor.campaign_combat = true
		actor.attack_enabled = false
		actor.move_speed = 0
	await frames(5)
	game.start_exploration()
	await put_player(Vector3(0,.05,18))
	check(is_equal_approx(left.fire_interval,1.98) and left.charge_duration==.6 and left.health==3,"Moyen tire plus souvent sans changer résistance ni avertissement")
	left.position = Vector3(-8,2.4,14)
	right.position = Vector3(12,2.4,8)
	director.get_child(2).set_physics_process(false)
	left.tactics.reset(Vector3(-12,0,-12),1)
	right.tactics.reset(Vector3(-12,0,-12),-1)
	var cover := make_blocker(Vector3(8,2.5,14),Vector3(20,5,.5))
	await frames(6)
	check(left.has_line_of_sight() and not right.has_line_of_sight(),"Un seul des deux drones peut voir le joueur derrière la couverture")
	check(not right.tactics.visible_contact and right.tactics.last_known_position.distance_to(player.global_position)<.1,"Le drone masqué reçoit le repérage de son allié par radio")
	var curtain := make_blocker(Vector3(0,2.5,16),Vector3(40,5,.4))
	await frames(4)
	var known: Vector3 = left.tactics.last_known_position
	await put_player(Vector3(5,.05,20))
	await frames(30)
	check(not left.has_line_of_sight() and not right.has_line_of_sight(),"La grande paroi masque réellement le joueur aux deux ennemis")
	check(left.tactics.last_known_position.distance_to(known)<.1 and right.tactics.last_known_position.distance_to(known)<.1,"Un déplacement invisible ne révèle pas la nouvelle position")
	await frames(510)
	check(left.tactics.memory_left==0 and right.tactics.memory_left==0,"L'information visuelle vieillit au bout de huit secondes")
	player.head.rotation.x = deg_to_rad(70)
	mouse_button(true)
	await frames(2)
	mouse_button(false)
	await frames(3)
	check(left.tactics.last_known_position.distance_to(player.global_position)<.1 and left.tactics.memory_left>0,"Un vrai tir du joueur alerte les ennemis proches malgré la couverture")
	cover.queue_free()
	curtain.queue_free()
	await frames(4)
	await put_player(Vector3(0,.05,18))
	left.position = Vector3(-8,2.4,12)
	right.position = Vector3(8,2.4,12)
	left.velocity = Vector3.ZERO
	right.velocity = Vector3.ZERO
	left.tactics.reset(player.global_position,1)
	right.tactics.reset(player.global_position,-1)
	await frames(4)
	left.tactics.decision_left = 0
	right.tactics.decision_left = 0
	var left_flank: Vector3 = left.tactics.choose_destination(left,false,9)
	var right_flank: Vector3 = right.tactics.choose_destination(right,false,9)
	check(left_flank.x<-5 and right_flank.x>5 and left_flank.distance_to(right_flank)>10,"Les deux sentinelles choisissent des flancs opposés et espacés")
	check(director.flight_path(left.position,left_flank).size()>0 and director.flight_path(right.position,right_flank).size()>0,"Les angles choisis sont accessibles dans la vraie carte de vol")
	left.move_speed = 3.3
	right.move_speed = 3.3
	left.path_refresh = 0
	right.path_refresh = 0
	var origin := left.position
	await frames(75)
	check(left.position.distance_to(origin)>1 and absf(left.position.y-2.4)<.1,"Les drones exécutent réellement leur contournement sans changer d'altitude")
	var side: float = left.tactics.flank_sign
	left.receive_hit()
	check(left.tactics.flank_sign==-side and left.path_refresh==0,"Un impact déclenche un changement de côté et un nouveau trajet")
	game.show_pause()
	var memory: float = left.tactics.memory_left
	var position: Vector3 = left.position
	await frames(40)
	check(left.tactics.memory_left==memory and left.position==position,"La pause fige aussi la perception et les décisions tactiques")
	game.restart_exploration()
	await frames(5)
	check(left.tactics.flank_sign==left.orbit_direction and left.health==3,"Recommencer efface la réaction précédente et restaure l'ennemi")
	await cleanup()

	game = load("res://missions/relay_run/mission.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	player = game.player
	await frames(5)
	game.start_exploration()
	player.head.rotation.x = deg_to_rad(70)
	mouse_button(true)
	await frames(2)
	mouse_button(false)
	check(game.director.current_sector==-1 and game.director.get_children().all(func(actor): return not actor.alive),"Tirer dans le quai sûr ne réveille aucun secteur dormant")
	await cleanup()
	print("RESULT: %d tactical checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
