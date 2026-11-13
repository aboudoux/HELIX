extends "res://tests/verify_lunar_escape.gd"
const TERRAIN := preload("res://missions/lunar_escape/regolith.gd")

func run() -> void:
	teleport_escorts_for_test=false
	game=load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(game);current_scene=game;player=game.pilot
	await frames(5);game.saver.enabled=false;game.set_physics_process(false)
	game.hud.title_card.hide();game.end_film();player.unlock_weapon("pistol")
	for director in game.directors+game.upper_directors: director.process_mode=Node.PROCESS_MODE_DISABLED
	for ally in game.squad.members: ally.set_physics_process(false)
	for base in range(3):
		var habitat: Node3D=game.world.get_node(["Selene","Tycho","Copernic"][base])
		check(habitat.global_position.is_equal_approx(WORLD.at(base,0,0,0)),"Base %d et objectifs à leur nouvelle position"%base)
		var point:=WORLD.at(base,0,0,10)
		var floor_hit:=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*2,point-Vector3.UP,1))
		check(not floor_hit.is_empty() and absf(floor_hit.position.y)<.15,"Base %d : plancher accessible sans terrain traversant"%base)
	for leg in range(2):
		check(absf(WORLD.BASE_Z[leg]-WORLD.BASE_Z[leg+1])==1200 and ROUTES.length(leg)>1400,"Trajet %d : 1,2 km entre bases et plus de 1,4 km de piste"%leg)
		print("LONGUEUR ROUTE ",leg," : ",ROUTES.length(leg))
		var count:=0
		var grounded:=true
		for patrol in game.road_guards:
			if patrol.get_meta("leg")!=leg: continue
			for enemy in patrol.get_children():
				count+=1
				grounded=grounded and enemy.alive and enemy.visible and enemy.disable_mode==CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
				grounded=grounded and absf(game.world.surface_profile.elevation(enemy.position.x,enemy.position.z))<.15
		check(count==32 if leg==0 else count==40,"Trajet %d : population prévue présente dès le chargement"%leg)
		check(grounded,"Trajet %d : ennemis placés sur la piste et collisions actives avant le combat"%leg)
		var road_clear:=true
		for i in range(1,120):
			var point:=ROUTES.point(leg,lerpf(ROUTES.start(leg),ROUTES.finish(leg),i/120.0))
			var hit:=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*2,point-Vector3.UP*2,1))
			road_clear=road_clear and not hit.is_empty() and absf(hit.position.y)<.4
		check(road_clear,"Trajet %d : sol continu sur toute la piste"%leg)
	game.step=game.Step.BIKE
	var first: Node3D=game.road_guards[0]
	await put_player(first.get_meta("site")+Vector3(0,.05,10))
	var population:=first.get_child_count()
	game._physics_process(0.0)
	check(first.process_mode==Node.PROCESS_MODE_INHERIT and first.get_child_count()==population,"L'approche active les ennemis existants sans apparition supplémentaire")
	await put_player(Vector3(0,.05,32));game._physics_process(0.0)
	check(first.process_mode==Node.PROCESS_MODE_DISABLED,"Les patrouilles lointaines suspendent leur IA")
	for patrol in game.road_guards: patrol.process_mode=Node.PROCESS_MODE_DISABLED
	await put_player(ROUTES.air_stop(0,0)+Vector3(0,.05,2))
	player.oxygen=12
	check(game.nearest_interaction()=="road_air","La borne de bord de piste propose la recharge")
	game.interact("road_air")
	check(player.oxygen==100,"La borne recharge réellement l'oxygène")
	var marker: Vector3=game.world.transport.global_position
	check(marker.distance_to(WORLD.at(1,0,0,-31))<.1,"Le blindé a suivi Tycho")
	check(game.world.rocket.global_position.distance_to(WORLD.pad(0,0,-249))<1,"La fusée a suivi Copernic")
	game.exploration.discovered.clear()
	game.exploration.reveal(WORLD.at(2,0,0,0))
	var cells: Array=game.exploration.snapshot()
	game.exploration.restore(cells)
	check(game.exploration.known(WORLD.at(2,0,0,0)),"La carte conserve les découvertes près de Copernic déplacée")
	game.exploration.restore([int((-680+1200)/20)*60+30],1)
	check(game.exploration.known(WORLD.at(2,10,0,30)),"Une découverte de l'ancienne carte migre près de la nouvelle base")
	var seam:=Vector3(14,2,TERRAIN.LOOP_MIN.y-.5)
	check(TERRAIN.wrapped(seam).distance_to(Vector3(14,2,899.5))<.001,"Les bords de la carte agrandie restent reliés")
	check(absf(game.world.surface_profile.elevation(30,-2700)-game.world.surface_profile.elevation(30,900))<.01,"Le relief raccorde les deux bords")
	if DisplayServer.get_name()=="headless":
		# Exercise actual save serialization and stage-based safe points on an isolated file.
		game.saver.path="user://test_long_routes_%d.json"%OS.get_process_id()
		game.saver.enabled=true
		game.step=game.Step.BIKE;player.set_control(true)
		check(game.saver.write_save(game),"La sauvegarde accepte la carte agrandie")
		var saved: Dictionary=game.saver.read_save()
		for base in range(3):
			saved.stage=[game.Step.HABITAT,game.Step.WORKSHOP,game.Step.CONTROL][base]
			check(game.saver.restore(game,saved) and player.global_position.distance_to(WORLD.at(base,0,.045,17))<.1,"Reprise de partie dans la base déplacée %d"%base)
		game.saver.clear();game.saver.enabled=false
		for director in game.directors+game.upper_directors: director.process_mode=Node.PROCESS_MODE_DISABLED
		for spider in game.resident_spiders: spider.process_mode=Node.PROCESS_MODE_DISABLED
		for leg in range(2):
			if "--tank-only" in OS.get_cmdline_user_args() and leg==0: continue
			player.dismount(false)
			var ride: Node3D=game.world.bike if leg==0 else game.world.transport
			ride.position=ROUTES.point(leg,ROUTES.start(leg)-6)+Vector3.UP*.05
			ride.rotation=Vector3.ZERO
			await put_player(ride.position+Vector3(0,.05,0))
			player.mount(ride);player.set_control(true)
			await drive_to(leg,WORLD.BASE_Z[leg+1]+29,6500,true)
			check(player.position.z<WORLD.BASE_Z[leg+1]+32 and player.position.z>WORLD.BASE_Z[leg+1]+23,"Le véhicule parcourt toute la longue piste %d jusqu'au sas"%leg)
			print("FIN TRAJET ",leg," : ",player.position)
			if player.position.z>WORLD.BASE_Z[leg+1]+32:
				print("ETAT ",player.in_control," sante ",player.health," pause ",paused," speed ",player.vehicle_speed," velocity ",player.velocity," rotation ",player.rotation," floor ",player.is_on_floor()," wall ",player.is_on_wall())
				for i in range(player.get_slide_collision_count()):
					var hit:=player.get_slide_collision(i)
					print("OBSTACLE ",hit.get_collider().get_path()," position ",hit.get_position()," normale ",hit.get_normal())
	else:
		player.set_physics_process(false)
		game.begin_film(Vector3(920,1900,-600),Vector3(0,0,-1200))
		await capture("longues_routes_vue_ensemble.png")
		game.frame_camera(first.get_meta("site")+Vector3(15,10,23),first.get_meta("site")+Vector3.UP*2)
		await capture("longues_routes_patrouille.png")
		game.frame_camera(Vector3(-26,1.65,12),Vector3(-29.2,.8,9.665))
		await capture("murs_photo_utilisateur.png")
		game.end_film();game.exploration.open()
		for base in range(3): game.exploration.reveal(WORLD.at(base,0,0,0))
		game.exploration.chart.queue_redraw()
		await capture("longues_routes_carte.png")
		game.exploration.close()
	await finish_run()
