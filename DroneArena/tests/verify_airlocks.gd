extends "res://tests/verify_lunar_escape.gd"

func run() -> void:
	teleport_escorts_for_test = false
	game = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(game); current_scene = game; player = game.pilot
	await frames(5)
	game.hud.title_card.hide(); game.hud.set_film(false); game.camera.make_current()
	game.set_physics_process(false); game.step = game.Step.CONTROL
	for director in game.directors+game.upper_directors: director.process_mode = Node.PROCESS_MODE_DISABLED
	player.unlock_weapon("pistol"); player.set_control(true)
	check(game.world.airlocks.size()==6,"Six sas protègent les accès extérieurs des trois bases et du toit")
	for lock in game.world.airlocks:
		lock.inner.unlock()
		await put_player(lock.outer.global_position+Vector3(8,0.05,0))
		check(not await lock.outer.open(),"L'ouverture directe ne contourne pas la pression : "+lock.name)
		lock.operate(lock.outer)
		await frames(60)
		var pressure: float = lock.pressure
		paused = true; await frames(20)
		check(is_equal_approx(pressure,lock.pressure) and not lock.outer.is_open,"La pause fige le cycle et garde les portes fermées")
		paused = false; await frames(220)
		check(lock.outer.is_open and not lock.inner.is_open and lock.pressure<0.01,"La porte extérieure s'ouvre après décompression")
		check(not await lock.inner.open(),"Les deux portes ne peuvent jamais être ouvertes ensemble")
		var center: Vector3 = lock.chamber.get_center(); center.y = lock.chamber.position.y+0.05
		await put_player(center)
		check(game.nearest_interaction()=="door:"+String(game.world.doors.find_key(lock.outer)),"Depuis le sas, E propose de refermer la porte restée ouverte")
		check(not game.world.air_at(player.position),"Le sas vide ne recharge pas l'air de la combinaison")
		await lock.operate(lock.outer)
		check(lock.pressure>0.99 and not lock.outer.is_open and game.world.air_at(player.position),"Refermer derrière soi remet le sas en pression")
		await lock.operate(lock.inner)
		check(lock.inner.is_open and not lock.outer.is_open,"La porte intérieure devient accessible après pressurisation")
		player.oxygen = 20
		check(not await lock.operate(lock.inner) and lock.pressure>0.99,"La sortie attend la recharge de la combinaison avant d'évacuer l'air")
		player.oxygen = 100
		await put_player(lock.inner.global_position+Vector3(8,0.05,0))
		await lock.operate(lock.inner)
		check(lock.pressure<0.01 and not lock.inner.is_open,"Le cycle inverse permet de ressortir vers la Lune")
		lock.set_pressure(1.0)
	# A companion crosses the airlock after the player, with no teleport.
	var entry = game.world.doors.habitat_entry.airlock
	await put_player(Vector3(0,0.05,28))
	game.squad.recruit(0); var ally = game.squad.members[0]
	ally.reset_at(Vector3(1,0.05,30)); ally.attack_clock = 1000
	await entry.operate(entry.outer)
	await move_to_point(Vector3(0,0.05,20.8),160)
	await frames(240)
	print("ALLY SAS ",ally.position," pressure ",entry.pressure)
	check(entry.contains(ally.position),"Le compagnon entre dans le sas avec le joueur")
	await entry.operate(entry.outer)
	await entry.operate(entry.inner)
	await move_to_point(Vector3(0,0.05,14),180)
	await frames(240)
	check(ally.position.z<19,"Le compagnon traverse la porte intérieure sans téléportation")
	ally.recruited = false; ally.hide(); ally.collision_layer = 0
	# Walk the complete protected route from INSIDE Copernic.
	game.world.doors.launch_exit.unlock(); await game.world.doors.launch_exit.open()
	await put_player(WORLD.at(2,0,0.05,-17))
	await move_to_point(WORLD.at(2,0,0.05,-50),500)
	check(player.position.distance_to(WORLD.at(2,0,0.05,-50))<1.2,"Le couloir intérieur rejoint le fond de la tour")
	await move_to_point(WORLD.ROOF_STAIRS_BOTTOM,350)
	check(player.position.distance_to(WORLD.ROOF_STAIRS_BOTTOM)<1.2,"Le virage intérieur mène au pied de l'escalier")
	await move_to_point(WORLD.ROOF_STAIRS_TOP-Vector3(0,0,0.8),650)
	check(player.position.y>WORLD.ROOF_HEIGHT-0.8,"L'escalier fermé se monte réellement jusqu'au sas du toit")
	var roof = game.world.doors.roof_inner.airlock
	await roof.operate(roof.inner)
	await move_to_point(WORLD.at(2,22,WORLD.ROOF_HEIGHT+0.05,-14.6),160)
	await roof.operate(roof.inner)
	await roof.operate(roof.outer)
	await move_to_point(WORLD.at(2,22,WORLD.ROOF_HEIGHT+0.05,-8.5),160)
	check(player.position.z>WORLD.COPERNIC_Z-10,"On accède à la fusée en traversant le sas intérieur du toit")
	var space := game.get_world_3d().direct_space_state
	for pair in [[WORLD.at(2,-6,1,-35),WORLD.at(2,0,1,-35)],[WORLD.at(2,10,1,-56),WORLD.at(2,10,1,-50)],[WORLD.at(2,28,2,-48),WORLD.at(2,22,2,-48)]]:
		check(not space.intersect_ray(PhysicsRayQueryParameters3D.create(pair[0],pair[1],1)).is_empty(),"La tour reste fermée depuis l'extérieur")
	# Real sound routing and grounded cadence.
	await put_player(WORLD.at(2,30,WORLD.ROOF_HEIGHT+0.05,16))
	var count: int = player.steps_played
	player.rotation.y = 0; Input.action_press("move_forward"); await frames(55); Input.action_release("move_forward")
	check(player.steps_played>count and player.steps_played-count<=3 and player.foot_surface=="metal","La marche sur le toit joue des pas enregistrés à une cadence naturelle")
	check(player.footsteps.volume_db==-17 and player.footsteps.pitch_scale>=0.98 and player.footsteps.pitch_scale<=1.02,"Les pas restent discrets, sans modification excessive de hauteur")
	await frames(20); count = player.steps_played; await frames(30)
	check(player.steps_played==count,"Aucun pas ne se répète à l'arrêt")
	Input.action_press("jump"); await frames(2); Input.action_release("jump"); count=player.steps_played
	await frames(70); check(player.steps_played==count,"Aucun pas n'est joué pendant le saut")
	await frames(270); check(player.steps_played>count,"L'atterrissage joue un impact de semelle")
	await put_player(Vector3(80,game.world.surface_profile.elevation(80,-400)+0.05,-400))
	await frames(20); player.play_footstep(false)
	check(player.foot_surface=="dust" and player.footsteps.stream.resource_path.contains("snow"),"La poussière utilise un son de pas distinct du métal")
	for key in ["pistol","shotgun","smg"]:
		player.unlock_weapon(key)
		check(player.weapon.shot_sound.stream.resource_path.contains("recorded_"),"Tir enregistré pour "+key)
	if DisplayServer.get_name()!="headless":
		game.film.make_current(); game.hud.set_film(true)
		game.frame_camera(game.world.bike.position+Vector3(2.6,1.7,-3.2),game.world.bike.position+Vector3.UP*0.7)
		await capture("vehicule_moto.png")
		game.frame_camera(game.world.transport.position+Vector3(6,3.7,7),game.world.transport.position+Vector3.UP)
		await capture("vehicule_blinde.png")
		game.frame_camera(WORLD.at(0,0,1.7,23),WORLD.at(0,0,1.5,19))
		await capture("sas_pression.png")
		game.frame_camera(WORLD.at(2,40,30,-65),WORLD.at(2,11,9,-35))
		await capture("tour_interieure.png")
	await finish_run()

func move_to_point(destination: Vector3, limit: int) -> void:
	for i in range(limit):
		var delta := destination-player.global_position; delta.y = 0
		if delta.length()<0.45: break
		player.rotation.y = atan2(-delta.x,-delta.z)
		Input.action_press("move_forward")
		await physics_frame
	Input.action_release("move_forward"); await frames(5)
	print("PATH ",player.global_position," target ",destination)
