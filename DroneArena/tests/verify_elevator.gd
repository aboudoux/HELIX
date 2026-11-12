extends "res://tests/verify.gd"
## Fermeture, confinement, montée, réinitialisation en mouvement et raccourci de boss.

func cleanup() -> void:
	for action in ["move_forward","move_right","jump"]: Input.action_release(action)
	for sound in game.find_children("*","AudioStreamPlayer3D",true,false): sound.stop()
	game.queue_free()
	paused = false
	await frames(5)


func run() -> void:
	game = load("res://missions/relay_run/mission.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	player = game.player
	await frames(8)
	game.start_exploration()
	# Isoler la mécanique après le verrou de progression, vérifié par verify_campaign.
	game.stage = 4
	game.lift.unlock()
	await put_player(Vector3(0,.05,-90))
	game.show_pause()
	check(not game.lift.request_ride(player),"La pause interdit le départ de l'ascenseur")
	game.start_exploration()
	check(game.lift.request_ride(player),"Départ avec un passager posé dans la cabine")
	check(not game.lift.request_ride(player),"Deux appels ne redémarrent pas le trajet")
	player.rotation.y = PI
	Input.action_press("move_forward")
	await frames(120)
	Input.action_release("move_forward")
	check(player.position.z<-86.4 and player.position.y>0,"La porte fermée retient le joueur pendant la montée")
	player.rotation.y = -PI/2
	Input.action_press("move_forward")
	await frames(120)
	Input.action_release("move_forward")
	check(absf(player.position.x)<2.65 and player.position.y>2,"Les parois de la cabine retiennent le joueur latéralement")
	check(game.lift.get_node("Motor").playing,"Le moteur accompagne la montée")
	game.restart_exploration()
	await frames(15)
	check(game.stage==0 and game.lift.state=="locked" and game.lift.cab.position.y==0,"Recommencer pendant la montée réinitialise le mécanisme")
	check(not game.lift.get_node("Motor").playing and player.position.y<.1,"Recommencer arrête le moteur et replace le joueur au quai")
	await cleanup()
	game = load("res://missions/relay_run/fenrir_trial.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	player = game.player
	await frames(8)
	check(paused and game.title.text=="FENRIR." and game.hostile_total()==1,"Le raccourci FENRIR possède son accueil et son compteur")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tests/artifacts/fenrir_accueil.png"))==OK,"Capture accueil FENRIR")
	game.start_exploration()
	game.alpha.attack_enabled = false
	await frames(15)
	check(game.stage==7 and game.alpha.alive and player.position.y>13.9,"Le raccourci place directement face au boss du deuxième étage")
	check(game.upper_director.current_sector==-1 and not game.boss.alive,"Le raccourci ne réveille pas les autres rencontres")
	if DisplayServer.get_name()!="headless":
		game.alpha.move_speed = 0
		await put_player(Vector3(8,14.05,-196))
		await aim_at(game.alpha.position+Vector3.UP*2.5)
		await frames(12)
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tests/artifacts/fenrir_close.png"))==OK,"Capture du modèle FENRIR dans son antre")
	while game.alpha.alive: game.alpha.receive_hit()
	await frames(85)
	check(game.stage==8 and game.drones_destroyed==1 and game.upper_gates[2].fully_open,"Vaincre FENRIR ouvre aussi la sortie du raccourci")
	game.restart_exploration()
	await frames(15)
	check(game.stage==7 and game.alpha.health==85 and game.alpha.phase==1 and game.alpha.move_speed==4,"Rejouer FENRIR restaure sa vie, sa vitesse et sa première phase")
	check(player.health==100 and player.weapon.ammo==30 and game.drones_destroyed==0,"Rejouer le raccourci restaure le joueur et les compteurs")
	await cleanup()
	print("RESULT: %d elevator checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
