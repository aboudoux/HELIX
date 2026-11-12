extends "res://tests/verify.gd"
## Sons locaux, boucles, vraie touche E, animation de porte et arrêt des voix.


func open_scene(path: String) -> void:
	game = load(path).instantiate()
	root.add_child(game)
	current_scene = game
	player = game.player
	for actor in game.get_node("Drones").get_children():
		actor.attack_enabled = false
		actor.move_speed = 0
	await frames(8)


func close_scene() -> void:
	for sound in game.find_children("*","AudioStreamPlayer",true,false)+game.find_children("*","AudioStreamPlayer3D",true,false):
		sound.set_process(false)
		sound.stop()
	OS.delay_msec(50)
	game.queue_free()
	paused = false
	await frames(4)
	OS.delay_msec(80)


func run() -> void:
	for name in ["drone_rotor","boss_rotor","door_open","relay_activate","interaction_denied","repair_pickup"]:
		var sample := load("res://audio/"+name+".wav") as AudioStreamWAV
		check(sample!=null and sample.format==AudioStreamWAV.FORMAT_16_BITS and sample.mix_rate==48000 and not sample.stereo,"WAV mono 48 kHz importé : "+name)
	check(AudioServer.get_bus_effect(0,0) is AudioEffectHardLimiter,"Le limiteur du mix principal est conservé")
	await open_scene("res://scenes/main.tscn")
	var drones: Array = game.get_node("Drones").get_children()
	var actor: CharacterBody3D = drones[0]
	var rotor: AudioStreamPlayer3D = actor.rotor_sound
	var drone_volume: float = rotor.base_volume
	check(paused and not rotor.playing,"Le menu initial ne démarre pas les hélices")
	check(rotor.stream is AudioStreamWAV and rotor.stream.loop_mode==AudioStreamWAV.LOOP_FORWARD and rotor.stream.loop_end==192000,"Boucle de quatre secondes configurée sur le lecteur du drone")
	check(rotor.stream!=drones[1].rotor_sound.stream and rotor.max_polyphony==1,"Chaque drone garde une boucle indépendante et une seule voix")
	check(rotor.max_distance==45 and rotor.unit_size==5,"Les hélices utilisent la distance et la spatialisation 3D")
	game.start_exploration()
	await frames(30)
	check(rotor.playing and rotor.volume_db>-16 and not rotor.stream_paused,"Les hélices deviennent audibles avec un fondu au démarrage")
	actor.set_physics_process(false)
	actor.velocity = Vector3(6,0,0)
	await frames(35)
	check(rotor.pitch_scale>rotor.base_pitch*1.06 and rotor.volume_db>rotor.base_volume,"La poussée fait varier le régime et le niveau du moteur")
	actor.velocity = Vector3.ZERO
	actor.set_physics_process(true)
	game.show_pause()
	await frames(3)
	var position: float = rotor.get_playback_position()
	check(rotor.stream_paused,"Échap suspend le bourdonnement en cours")
	await frames(15)
	check(absf(rotor.get_playback_position()-position)<.03,"La boucle ne continue pas à avancer pendant la pause")
	game.start_exploration()
	await frames(3)
	check(rotor.playing and not rotor.stream_paused,"Reprendre rétablit les hélices")
	while actor.alive: actor.receive_hit()
	check(not rotor.playing,"Détruire le drone coupe immédiatement ses turbines")
	await frames(12)
	check(not rotor.playing and drones[1].rotor_sound.playing,"Le drone détruit reste silencieux, les autres continuent")
	game.restart_exploration()
	await frames(30)
	check(actor.alive and rotor.playing,"Recommencer restaure le bruit des drones vivants")
	actor.hide()
	await frames(3)
	check(not rotor.playing,"Un ennemi masqué ne produit pas d'hélices fantômes")
	actor.show()
	await frames(3)
	check(rotor.playing,"Rendre le drone actif et visible rétablit sa boucle")
	await close_scene()
	await open_scene("res://missions/relay_run/mission.tscn")
	game.start_exploration()
	await frames(12)
	var silent: bool = not game.boss.rotor_sound.playing
	for guard in game.director.get_children():
		for sound in guard.find_children("*","AudioStreamPlayer3D",true,false):
			silent = silent and not sound.playing
	check(silent,"Le quai sûr et les secteurs dormants restent silencieux")
	var gate: Node3D = game.gates[0]
	var motor: AudioStreamPlayer3D = gate.get_node("OpenSound")
	var relay: Node3D = game.relays[0]
	var activation: AudioStreamPlayer3D = relay.get_node("ActivationSound")
	var denied: AudioStreamPlayer3D = relay.get_node("DeniedSound")
	await tap(KEY_E)
	check(not activation.playing and not denied.playing and not motor.playing,"Appuyer sur E dans le vide ne déclenche aucun son")
	game.director.engage_sector(0)
	await put_player(relay.position+Vector3(0,.05,2))
	await tap(KEY_E)
	check(denied.playing and not activation.playing and not motor.playing and not gate.unlocked,"Un relais gardé émet un refus sans ouvrir la porte")
	check(game.director.get_child(0).rotor_sound.playing,"L'activation d'un secteur réveille aussi ses moteurs")
	for guard in game.director.get_children():
		if guard.alive:
			while guard.alive: guard.receive_hit()
	denied.stop()
	await tap(KEY_E)
	check(game.stage==1 and activation.playing and motor.playing,"La vraie touche E déclenche la confirmation et le moteur de la porte")
	check(motor.stream.loop_mode==AudioStreamWAV.LOOP_DISABLED and is_equal_approx(motor.stream.get_length(),1.5),"Le son de porte est un mouvement unique avec butée à 1,2 seconde")
	check(motor.unit_size==24 and motor.max_distance==140 and activation.max_distance==28,"La porte s'entend à distance, la confirmation reste locale au terminal")
	game.show_pause()
	var progress: float = gate.progress
	check(motor.stream_paused and activation.stream_paused,"La pause suspend moteur et confirmation")
	await frames(15)
	check(gate.progress==progress,"Le mouvement de porte reste synchronisé avec le son suspendu")
	game.start_exploration()
	await frames(85)
	check(gate.fully_open and gate.get_node("Barrier/CollisionShape3D").disabled,"Le son accompagne l'ouverture réelle et la libération du passage")
	motor.stop()
	gate.unlock()
	check(not motor.playing,"Une porte déjà ouverte ne rejoue pas son moteur")
	game.restart_exploration()
	await frames(5)
	check(not motor.playing and not activation.playing and not denied.playing and not gate.unlocked,"Recommencer arrête les anciens sons et referme les portes")
	var kit: Node3D = game.get_node("Arena/Medical").get_child(0)
	player.apply_damage(40)
	await put_player(kit.position+Vector3(0,.05,0))
	check(not kit.visible and kit.get_node("PickupSound").playing and player.health==100,"Prendre un kit confirme la réparation même après disparition du modèle")
	kit.get_node("PickupSound").stop()
	player.health = 80
	await frames(12)
	check(not kit.get_node("PickupSound").playing and player.health==80,"Un kit consommé ne soigne pas et ne sonne pas à nouveau")
	player.restore_health()
	var other_kit: Node3D = game.get_node("Arena/Medical").get_child(1)
	await put_player(other_kit.position+Vector3(0,.05,0))
	check(other_kit.visible and not other_kit.get_node("PickupSound").playing,"À santé maximale, un kit reste disponible et silencieux")
	game.restart_exploration()
	await frames(5)
	check(kit.visible and not kit.get_node("PickupSound").playing,"Le redémarrage restaure les kits et arrête leur son précédent")
	await close_scene()
	await open_scene("res://missions/relay_run/boss_trial.tscn")
	check(not game.boss.rotor_sound.playing,"CERBÈRE reste silencieux dans son menu")
	game.start_exploration()
	game.boss.attack_enabled = false
	game.boss.move_speed = 0
	await frames(30)
	var boss_rotor: AudioStreamPlayer3D = game.boss.rotor_sound
	check(boss_rotor.playing and boss_rotor.stream.data==load("res://audio/boss_rotor.wav").data and boss_rotor.stream.loop_mode==AudioStreamWAV.LOOP_FORWARD,"Le boss possède son propre grondement en boucle")
	check(boss_rotor.base_volume>drone_volume,"Le colosse garde un niveau propre à ses grandes turbines")
	while game.boss.health>game.boss.max_health/2: game.boss.receive_hit()
	await frames(30)
	check(boss_rotor.pitch_scale>boss_rotor.base_pitch*1.04,"La surchauffe augmente le régime des turbines du boss")
	while game.boss.alive: game.boss.receive_hit()
	check(not boss_rotor.playing and game.gates[2].get_node("OpenSound").playing,"Détruire CERBÈRE coupe ses hélices et fait entendre la porte finale")
	game.restart_exploration()
	game.boss.move_speed = 0
	game.boss.velocity = Vector3.ZERO
	await frames(30)
	check(boss_rotor.playing and game.boss.phase==1 and boss_rotor.pitch_scale<boss_rotor.base_pitch*1.02,"Rejouer le boss restaure son régime normal")
	await close_scene()
	print("RESULT: %d mechanical audio checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
