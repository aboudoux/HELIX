extends "res://tests/verify_lunar_escape.gd"
const TERRAIN := preload("res://missions/lunar_escape/regolith.gd")

func run() -> void:
	teleport_escorts_for_test = false
	game = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(game); current_scene = game; player = game.pilot
	await frames(4)
	game.hud.title_card.hide(); game.hud.set_film(false)
	game.step = game.Step.HABITAT
	game.set_physics_process(false)
	for director in game.directors+game.upper_directors: director.process_mode = Node.PROCESS_MODE_DISABLED
	player.set_control(true); player.set_physics_process(false)
	player.unlock_weapon("pistol")
	var loop: Node = game.world.get_node("LunarLoop")
	loop.set_physics_process(false)
	var terrain := TERRAIN.new(WORLD.BASE_Z)
	for z in [-1200.0,-900.0,-300.0,0.0,600.0]:
		check(absf(terrain.elevation(-600,z)-terrain.elevation(600,z))<0.001,"Relief continu est/ouest à z="+str(z))
	for x in [-600.0,-200.0,0.0,200.0,600.0]:
		check(absf(terrain.elevation(x,-1200)-terrain.elevation(x,600))<0.001,"Relief continu nord/sud à x="+str(x))
	for point in [Vector3(600.4,3,-400),Vector3(-600.4,3,-400),Vector3(100,3,600.4),Vector3(100,3,-1200.4),Vector3(600.4,3,600.4)]:
		player.global_position = point; player.velocity = Vector3(4,0,11)
		loop._physics_process(0.016)
		check(player.global_position.is_equal_approx(TERRAIN.wrapped(point)) and player.velocity==Vector3(4,0,11),"Boucle dans les deux sens et en diagonale, vitesse préservée")
	var mael = game.squad.members[0]
	game.squad.recruit(0); mael.set_physics_process(false)
	player.global_position = Vector3(600.3,3,-400)
	mael.global_position = Vector3(596,3,-400); mael.health = 83; mael.rounds = 2
	loop._physics_process(0.016)
	check(mael.global_position.distance_to(player.global_position)<5 and mael.health==83 and mael.rounds==2,"Le compagnon proche suit la boucle sans soin ni recharge gratuits")
	mael.velocity = Vector3.ZERO
	mael.target = null; mael.greeting_left = 0
	mael.avatar.animate_escort(mael,0.2,mael.get_aim_point()-mael.global_basis.z*8,0,false)
	var head_before: Vector3 = mael.avatar.helmet.rotation
	mael.avatar.animate_escort(mael,0.8,mael.get_aim_point()-mael.global_basis.z*8,0,false)
	check(mael.avatar.helmet.rotation.distance_to(head_before)>0.01,"Les alliés regardent autour d'eux au repos")
	mael.hurt_left = 0.22
	mael.avatar.animate_escort(mael,0.2,mael.get_aim_point()-mael.global_basis.z*8,0,false)
	var hurt_tilt: float = absf(mael.avatar.torso.rotation.x)
	mael.hurt_left = 0
	mael.avatar.animate_escort(mael,0.8,mael.get_aim_point()-mael.global_basis.z*8,0,false)
	check(absf(mael.avatar.torso.rotation.x)<hurt_tilt*0.1,"Le torse revient au repos après la réaction à une blessure")
	var survivor = game.squad.members[1]
	survivor.show()
	var idle_clock: float = survivor.avatar.clock
	survivor._physics_process(0.5)
	check(survivor.avatar.clock>idle_clock and not survivor.recruited,"Un survivant non recruté respire et fait des gestes")
	var mechanic_clock: float = game.mechanic.clock
	game.squad.members[2]._physics_process(0.5)
	check(game.mechanic.clock>mechanic_clock,"Lina fait aussi des gestes dans son atelier avant son sauvetage")
	player.global_position = Vector3(-590,terrain.elevation(-590,-400)+0.04,-400)
	mael.global_position = Vector3(599,terrain.elevation(599,-400)+0.04,-400)
	mael.path.clear(); mael.route_clock = 0; mael.set_physics_process(true)
	loop.set_physics_process(true)
	await frames(230)
	loop.set_physics_process(false); mael.set_physics_process(false)
	check(mael.global_position.distance_to(player.global_position)<7,"Un compagnon suit réellement le joueur de l'autre côté du raccord")
	game.world.bike.global_position = Vector3(599,player.global_position.y,-400)
	loop._physics_process(0.016)
	check(game.world.bike.global_position.distance_to(player.global_position)<12,"Un véhicule garé près du bord reste accessible de l'autre côté")
	# Both vehicle controllers keep their state through the same seam.
	for ride in [game.world.bike,game.world.transport]:
		player.mount(ride)
		player.global_position = Vector3(-600.2,3,-100)
		player.vehicle_speed = 15
		loop._physics_process(0.016)
		check(ride.global_position.is_equal_approx(player.global_position) and player.vehicle_speed==15,"Boucle avec véhicule et vitesse conservée : "+ride.name)
		player.dismount(false)
		await frames(2)
		# Exercise actual steering/throttle and the wide driving hull at the boundary.
		ride.global_position = Vector3(598,terrain.elevation(598,-400)+0.25,-400)
		ride.rotation.y = -PI/2
		player.mount(ride)
		await frames(2)
		Input.action_press("move_forward")
		for i in range(150):
			player.drive(1.0/60); loop._physics_process(1.0/60)
			await physics_frame
		Input.action_release("move_forward")
		check(player.global_position.x<-500 and player.global_position.x>-599 and player.global_position.y>-20 and player.vehicle_speed>5,"Conduite réelle sur le raccord : "+ride.name)
		player.dismount(false); await frames(2)
	# A real grounded capsule crosses the seam without falling through terrain.
	player.global_position = Vector3(599.8,terrain.elevation(599.8,-400)+0.05,-400)
	player.velocity = Vector3(5,0,0)
	for i in range(120):
		player.velocity.x = 5; player.velocity.y -= 12.0/60
		player.move_and_slide(); loop._physics_process(1.0/60)
		await physics_frame
	check(player.global_position.x<-580 and player.is_on_floor(),"Traversée réelle du raccord avec collision au sol")
	check(player.global_position.y>-20,"Le relief étendu reste au-dessus de la limite de chute")
	# Make a real drone crash and verify geometry separates once, then settles.
	player.global_position = Vector3(8,0.05,35)
	var drone = game.add_enemy(0,Vector3(0,5,35),"TEST FRAGMENTATION")
	drone.attack_enabled = false
	drone.receive_hit_at(drone.global_position,Vector3.UP,Vector3.DOWN,999)
	await frames(300) # Lunar fall, impact and fragment separation.
	var wreck: RigidBody3D = drone.wreck
	check(wreck.has_exploded and wreck.fragmented and wreck.fragment_count==6,"Le drone se brise en quatre turbines et deux plaques après l'impact")
	var fragments := wreck.find_children("Debris_*","RigidBody3D",true,false)
	check(fragments.size()==6 and fragments.any(func(piece): return piece.global_position.distance_to(wreck.global_position)>1.5),"Les morceaux physiques se dispersent autour de la carcasse")
	if fragments.is_empty():
		await finish_run()
		return
	var count: int = wreck.fragment_count
	wreck.break_apart()
	check(wreck.fragment_count==count,"L'impact ne crée pas plusieurs fois les mêmes débris")
	var piece: RigidBody3D = fragments[0]
	var age: float = piece.age
	paused = true; await frames(15); paused = false
	check(is_equal_approx(age,piece.age),"La pause fige aussi les débris et leur durée de vie")
	if DisplayServer.get_name()!="headless":
		game.film.make_current(); game.frame_camera(Vector3(3,2.7,39),Vector3(0,0.3,35))
		await frames(3); await capture("revision_drone_debris.png")
	await frames(1450)
	check(wreck.find_children("Debris_*","RigidBody3D",true,false).is_empty(),"Les petits débris sont nettoyés, sans obstacles invisibles persistants")
	check(is_instance_valid(wreck) and wreck.settled,"Le châssis détruit reste au sol")
	await finish_run()
