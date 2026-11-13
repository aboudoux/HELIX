extends "res://tests/verify_lunar_escape.gd"

func run() -> void:
	teleport_escorts_for_test = false
	game = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(game); current_scene = game; player = game.pilot
	await frames(5)
	game.hud.title_card.hide(); game.hud.set_film(false); game.camera.make_current()
	game.step = game.Step.CONTROL; game.set_physics_process(false)
	for director in game.directors+game.upper_directors: director.process_mode = Node.PROCESS_MODE_DISABLED
	player.unlock_weapon("pistol"); player.set_control(true)
	await put_player(Vector3(0,0.045,11))
	var feedback: Control = game.hud.damage_feedback
	var front: Vector3 = player.global_position + Vector3(0,1.6,-10)
	player.hurt_cooldown = 0
	check(player.apply_damage_from(35,front),"Un impact réel retire des points de vie")
	check(feedback.impacts.size()==1,"Un impact accepté affiche sa direction")
	check(not player.apply_damage_from(35,front+Vector3.RIGHT*5),"Le délai de protection bloque le doublon")
	check(feedback.impacts.size()==1,"Aucun faux indicateur pour les dégâts rejetés")
	await frames(15)
	check(is_equal_approx(game.hud.health_meter.value,65.0),"La barre rouge descend à 65 PV")
	check(absf(angle_difference(feedback.bearing(front),-PI/2))<.05,"Un tir de face apparaît en haut")
	player.rotation.y = PI
	check(absf(angle_difference(feedback.bearing(front),PI/2))<.05,"Tourner le dos place le même tir en bas")
	player.rotation.y = 0
	check(absf(feedback.bearing(player.global_position+Vector3(10,1.6,0)))<.05,"Un tir de droite apparaît à droite")
	check(absf(angle_difference(feedback.bearing(player.global_position+Vector3(-10,1.6,0)),PI))<.05,"Un tir de gauche apparaît à gauche")
	var life: float = feedback.impacts[0].life
	paused = true; await frames(12); paused = false
	check(is_equal_approx(life,feedback.impacts[0].life),"La pause fige l'indicateur")
	if DisplayServer.get_name() != "headless":
		player.hurt_cooldown = 0; player.apply_damage_from(12,player.global_position+Vector3(8,1.6,-6))
		game.update_interface(); await capture("vie_rouge_direction_tirs.png")
	await frames(90)
	check(feedback.impacts.is_empty(),"Les repères s'effacent après l'impact")
	player.restore_health(); await frames(15)
	check(is_equal_approx(game.hud.health_meter.value,100.0),"Soins et reprise restaurent la barre")
	WORLD.block(game.world,Vector3(180,9.8,100),Vector3(90,.4,100),WORLD.FLOOR,true)
	await put_player(Vector3(180,10.045,120)); player.hurt_cooldown = 0
	var bolt: Node3D = load("res://scenes/enemy_bolt.tscn").instantiate()
	game.add_child(bolt)
	var firing_point := player.global_position+Vector3(0,1.25,-3)
	bolt.launch(firing_point,Vector3.BACK,RID())
	await frames(20)
	check(player.health<100 and not feedback.impacts.is_empty(),"Un vrai projectile déclenche la barre et le repère")
	check(not feedback.impacts.is_empty() and feedback.impacts[0].origin.is_equal_approx(firing_point),"Le repère conserve l'origine du tir et non son point d'impact")
	player.restore_health(); feedback.impacts.clear()
	# Compare actual physical falls, including independent exploded pieces.
	var indoor: CharacterBody3D = game.add_enemy(0,Vector3(0,3.0,7),"CHUTE INTÉRIEURE")
	var outdoor: CharacterBody3D = game.add_enemy(0,Vector3(180,13.0,100),"CHUTE EXTÉRIEURE")
	for enemy in [indoor,outdoor]:
		enemy.set_physics_process(false)
		enemy.receive_hit_at(enemy.global_position,Vector3.UP,Vector3.DOWN,999)
	var inside_wreck: RigidBody3D = indoor.wreck
	var outside_wreck: RigidBody3D = outdoor.wreck
	check(is_equal_approx(inside_wreck.gravity_scale*24,9.81),"Épave intérieure : gravité normale")
	check(is_equal_approx(outside_wreck.gravity_scale*24,1.62),"Épave extérieure : gravité lunaire")
	await frames(60)
	check(inside_wreck.impact_count>0 and outside_wreck.impact_count==0,"À hauteur égale, le drone intérieur touche le sol plus tôt")
	await frames(70)
	var indoor_fragments := 0
	for fragment in get_nodes_in_group("wreck_fragments"):
		if game.world.interior_at(fragment.global_position):
			indoor_fragments += 1
			check(is_equal_approx(fragment.gravity_scale*24,9.81),"Un débris intérieur retombe avec la bonne gravité")
	check(indoor_fragments>0,"Le drone intérieur se brise après sa chute")
	check(inside_wreck.collision_layer==0 and outside_wreck.collision_layer==0,"Les carcasses restent non bloquantes")
	var robot: CharacterBody3D = game.add_enemy(0,Vector3(0,0.045,5),"REPLI ROBOT",true)
	robot.set_physics_process(false); robot.receive_hit_at(robot.global_position,Vector3.UP,Vector3.DOWN,999)
	await frames(50)
	check(robot.wreck.pose_ready and is_equal_approx(robot.wreck.gravity_scale*24,9.81),"Le robot replie ses articulations sous la gravité intérieure (g=%s, pose=%s)" % [robot.wreck.gravity_scale*24,robot.wreck.pose_ready])
	# Real movement and real collider overlap, both directions; no proximity kills.
	var tank: Node3D = game.world.transport
	tank.global_position = Vector3(180,10.045,100)
	player.mount(tank); await frames(5)
	var victim: CharacterBody3D = game.add_enemy(0,Vector3(180,10.045,94),"ÉCRASEMENT AVANT",true)
	victim.set_physics_process(false)
	await frames(20)
	check(victim.alive,"Un char immobile ne tue pas un ennemi proche")
	Input.action_press("move_forward"); await frames(100); Input.action_release("move_forward")
	check(not victim.alive,"Le char tue par contact en marche avant")
	player.vehicle_speed = 0; player.velocity = Vector3.ZERO
	player.global_position = Vector3(180,10.045,100); tank.global_position = player.global_position
	var reverse: CharacterBody3D = game.add_enemy(0,Vector3(180,10.045,106),"ÉCRASEMENT ARRIÈRE",true)
	reverse.set_physics_process(false); await frames(3)
	Input.action_press("move_back"); await frames(110); Input.action_release("move_back")
	check(not reverse.alive,"Le char tue aussi en marche arrière")
	player.vehicle_speed = 0; player.velocity = Vector3.ZERO
	player.global_position = Vector3(180,10.045,100); tank.global_position = player.global_position
	var wall := WORLD.block(game.world,Vector3(180,12,94),Vector3(12,4,.4),WORLD.WHITE,true)
	var protected: CharacterBody3D = game.add_enemy(0,Vector3(180,10.045,92),"DERRIÈRE MUR",true)
	protected.set_physics_process(false); await frames(3)
	Input.action_press("move_forward"); await frames(120); Input.action_release("move_forward")
	check(protected.alive and player.global_position.z>95,"Le char ne traverse pas le mur et ne tue pas derrière")
	# Imported voice assets and subtitle durations use the same real WAVs.
	for key in game.voice.LINES:
		var clip: AudioStreamWAV = load("res://audio/voice/"+key+".wav")
		check(clip != null and clip.mix_rate==24000 and clip.get_length()>1,"Voix neurale française : "+key)
	var length: float = game.voice.play_line(game.voice.LINES.arrival)
	check(is_equal_approx(length,game.voice.stream.get_length()+.25),"Sous-titres synchronisés à la nouvelle voix")
	await finish_run()
