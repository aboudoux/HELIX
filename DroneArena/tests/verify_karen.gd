extends "res://tests/verify_lunar_escape.gd"

func run() -> void:
	game = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(game)
	current_scene = game
	player = game.pilot
	await frames(5)
	check(not player.third_person,"Karen démarre à la première personne")
	check(game.hud.card_title.text=="Le silence de Karen","Le briefing annonce la mission de secours")
	game.hud.primary.pressed.emit()
	await frames(100)
	check(game.story.arrival_ship.position.y>0 and game.story.arrival_flame.visible,"La fusée descend avec ses moteurs allumés")
	check(game.voice.stream.resource_path.ends_with("arrival.wav") and game.voice.playing,"Le briefing français est réellement joué")
	await screenshot("karen_arrival.png")
	await frames(310)
	check(game.step==CAMPAIGN.Step.TUTORIAL and player.position.z>19 and player.in_control,"La mission commence au pied de la fusée, devant Karen")
	check(game.voice.stream.resource_path.ends_with("mission.wav"),"La voix accompagne les deux objectifs affichés")
	game.step = CAMPAIGN.Step.HABITAT
	game.directors[0].process_mode = Node.PROCESS_MODE_DISABLED
	game.clearance[0] = true
	game.update_clearance(0)
	check(game.world.doors.habitat_exit.secured,"Rétablir le courant ne suffit pas sans le journal et les survivants")
	game.story.interact("crew")
	check(not game.story.flags.crew,"Le journal ne se récupère pas à distance")
	await use_story_station("crew")
	check(game.hud.modules.text.contains("Journal Karen"),"Le journal récupéré figure dans l'équipement")
	check(game.voice.stream.resource_path.ends_with("log.wav"),"La découverte du journal possède sa voix off")
	await use_story_station("medical")
	check(not game.world.doors.habitat_exit.secured,"Le journal et le registre autorisent la poursuite de la recherche")
	# Return routes are tested on both sides with physical movement.
	var shortcut: Node3D = game.world.doors.shortcut_0_1
	await put_player(shortcut.global_position+Vector3(0,0.045,1.6))
	await tap(KEY_E)
	check(shortcut.secured,"Le raccourci reste verrouillé depuis le mauvais côté")
	await put_player(shortcut.global_position+Vector3(0,0.045,-1.6))
	await tap(KEY_E)
	await frames(50)
	check(shortcut.is_open,"Le verrou de retour s'ouvre depuis la pièce nord")
	await walk_to(Vector2(shortcut.global_position.x,shortcut.global_position.z+2.0))
	check(player.position.z>shortcut.global_position.z+1.2,"Le passage entre pièces est réellement traversable")
	game.step = CAMPAIGN.Step.WORKSHOP
	game.rescue_guard.receive_hit_at(game.rescue_guard.position,Vector3.UP,Vector3.FORWARD,10000)
	check(game.world.doors["dome_1_-1"].secured,"Le sas de Lina reste fermé sans courant même après le combat")
	await use_story_station("power")
	check(not game.world.doors["dome_1_-1"].secured,"Rétablir le courant libère l'atelier sécurisé")
	await put_player(game.mechanic.global_position+Vector3(0,0.045,-1.5))
	await tap(KEY_E)
	check(game.mechanic_rescued and game.story.companion.visible,"Lina secourue rejoint la préparation du blindé")
	await use_story_station("survivors")
	await use_story_station("access")
	check(game.squad.members[0].recruited and game.squad.members[1].recruited,"Les survivants de Karen rejoignent l'escouade")
	check(game.story.exit_ready(1),"Lina et les survivants ont été retrouvés avant de repartir")
	game.film.make_current()
	var refuge: Node3D = game.world.get_node("Tycho/Chambre3")
	game.frame_camera(refuge.to_global(Vector3(3.4,2,-3.2)),refuge.to_global(Vector3(3.8,1,1.1)))
	await screenshot("karen_survivors.png")
	game.camera.make_current()
	# Garage ramp and observatory ramp exercise the real collision geometry.
	await put_player(WORLD.at(1,7.2,0.045,-21.8))
	await walk_to(Vector2(7.2,WORLD.BASE_Z[1]-34),220)
	check(player.position.y>2.6,"La passerelle du hangar est accessible par sa rampe")
	await put_player(Vector3(36.4,0.045,-706))
	await walk_to(Vector2(60,-706),360)
	check(player.position.x>58.5 and player.position.y>6.1,"La rampe rejoint le balcon du cratère scientifique")
	await put_player(ROUTES.wreck_point()+Vector3(0,0.045,-4.5))
	await walk_to(Vector2(ROUTES.wreck_point().x,ROUTES.wreck_point().z-0.3),160)
	check(absf(player.position.z-ROUTES.wreck_point().z+0.3)<0.7,"L'épave du courrier peut être explorée à pied")
	game.step = CAMPAIGN.Step.CONTROL
	await use_story_station("coordinates")
	await use_story_station("fuel")
	check(game.story.exit_ready(2),"La trajectoire et l'alimentation préparent le départ")
	var saved: Dictionary = game.story.snapshot()
	game.story.flags.crew = false
	game.story.flags.survivors = false
	game.story.restore(saved,CAMPAIGN.Step.CONTROL)
	check(game.story.flags.crew and game.story.flags.survivors,"Le journal et les survivants sont restaurés avec la progression")
	# Solid shield at first person, with unchanged protection and charge rules.
	await put_player(Vector3(-24.5,0.045,36))
	player.rotation.y = PI
	player.shield_unlocked = true
	player.shield_charge = 100
	var key := InputEventKey.new()
	key.physical_keycode = KEY_F
	key.pressed = true
	Input.parse_input_event(key)
	await frames(8)
	check(player.shield_visual.visible and player.shield_visual.plate.mesh is ArrayMesh,"F lève un bouclier solide à la place de la bulle")
	var hp: int = player.health
	player.apply_damage(20)
	await frames(2)
	check(player.health==hp-4 and player.shield_charge<100 and player.shield_visual.impact>0,"Le bouclier absorbe le choc, consomme sa charge et réagit à l'impact")
	await screenshot("karen_shield.png")
	key.pressed = false
	Input.parse_input_event(key)
	# All main enemy families share the new cooled/damaged surface pipeline.
	for hound in [false,true]:
		var enemy: CharacterBody3D = game.add_enemy(0,Vector3(-5+int(hound)*3,2.4 if not hound else 0.05,35),"ÉPAVE TEST",hound)
		enemy.receive_hit_at(enemy.position,Vector3.UP,Vector3.FORWARD,10000)
	var spider := preload("res://missions/lunar_escape/spider.gd").new()
	spider.pilot = player
	spider.lane = 35
	spider.offset = 0
	game.add_child(spider)
	spider.set_physics_process(false)
	spider.global_transform = Transform3D(Basis.IDENTITY,Vector3(1,0.7,35))
	spider.receive_hit_at(spider.global_position,Vector3.UP,Vector3.FORWARD,10000)
	await frames(100)
	var wrecks := get_nodes_in_group("drone_wrecks")
	check(wrecks.size()>=3,"Drones, limiers et araignées conservent de vraies carcasses")
	var all_damaged := true
	for wreck in wrecks:
		if wreck.damaged_materials.is_empty() or wreck.cooling>=1: all_damaged = false
	check(all_damaged,"Les carcasses ont des matériaux endommagés et refroidissent")
	game.film.make_current()
	game.frame_camera(Vector3(-3,4.2,40),Vector3(-2,0.35,35))
	await screenshot("karen_wrecks.png")
	var hot: float = wrecks[-1].cooling
	paused = true
	await frames(15)
	check(wrecks[-1].cooling==hot,"La pause fige aussi le refroidissement des carcasses")
	paused = false
	await frames(850)
	check(wrecks.all(func(wreck): return wreck.cooling==0 and wreck.damaged_materials.all(func(material): return material.get_shader_parameter("heat")==0)),"Les carcasses restent calcinées après extinction de leur incandescence")
	await screenshot("karen_wrecks_cold.png")
	game.camera.make_current()
	game.ship_reveal()
	await frames(450)
	game.mothership.set_physics_process(false)
	game.mothership.pattern_index = 0
	game.mothership.phase = 0
	game.mothership.start_attack()
	check(game.mothership.target.distance_to(game.story.link.global_position+Vector3.UP*1.4)<0.01,"Le boss vise réellement la liaison de lancement")
	for i in range(5):
		game.mothership.fire_volley_shot()
		await frames(16)
	await frames(50)
	check(game.story.link.health<100,"Les projectiles du boss endommagent l'installation")
	game.story.link.apply_damage(100)
	var progress: float = game.story.preparation
	await frames(20)
	check(game.story.preparation==progress,"La liaison coupée suspend la préparation de Lina")
	await put_player(game.story.link.global_position+Vector3(0,0.045,1.65))
	await tap(KEY_E)
	check(game.story.link.health==100,"E répare la liaison depuis sa console")
	await frames(30)
	check(game.story.preparation>progress,"La préparation reprend après la réparation")
	game.story.preparation = 35
	game.on_ship_destroyed()
	check(game.story.ready_to_launch(),"La victoire et la préparation autorisent le départ à deux")
	await finish_run()

func screenshot(file: String) -> void:
	if DisplayServer.get_name()=="headless": return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/artifacts"))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/artifacts/"+file)
