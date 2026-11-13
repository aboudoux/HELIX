extends "res://tests/verify_lunar_escape.gd"

func run() -> void:
	teleport_escorts_for_test=false
	game=load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(game);current_scene=game;player=game.pilot
	await frames(5)
	game.hud.title_card.hide();game.hud.set_film(false);game.camera.make_current()
	game.step=game.Step.CONTROL;game.set_physics_process(false)
	for director in game.directors+game.upper_directors: director.process_mode=Node.PROCESS_MODE_DISABLED
	player.unlock_weapon("pistol");player.set_control(true)
	# A narrow passage outside the base nav graphs: no route around the debris.
	WORLD.block(game.world,Vector3(180,9.8,100),Vector3(20,.4,40),WORLD.FLOOR,true)
	for x in [178.9,181.1]: WORLD.block(game.world,Vector3(x,12,102),Vector3(.3,4,24),WORLD.WHITE,true)
	await put_player(Vector3(180,10.045,111))
	var ally: CharacterBody3D=game.squad.members[0]
	game.squad.recruit(0);ally.reset_at(Vector3(180,10.045,100));ally.set_physics_process(false)
	var drone: CharacterBody3D=game.add_enemy(0,Vector3(180,12.3,100),"TEST PASSAGE")
	drone.set_physics_process(false)
	check(drone.collision_layer==8,"Le drone vivant conserve ses collisions")
	drone.receive_hit_at(drone.global_position,Vector3.UP,Vector3.DOWN,999)
	var wreck: RigidBody3D=drone.wreck
	check(wreck.collision_layer==0 and wreck.collision_mask==1,"La carcasse ne bloque aucun acteur mais rencontre toujours le décor")
	check(is_equal_approx(wreck.gravity_scale*float(ProjectSettings.get_setting("physics/3d/default_gravity")),1.62),"La chute conserve la gravité lunaire sans dépendre des couches de collision")
	ally.set_physics_process(true)
	await frames(180)
	check(ally.global_position.z>107 and ally.alive,"L'allié repart et suit le joueur pendant la chute du drone au-dessus de lui")
	await frames(160)
	check(wreck.has_exploded and wreck.fragment_count==6,"Le drone explose au sol et conserve ses six morceaux dispersés")
	check(wreck.global_position.y>9.7 and wreck.global_position.y<11,"La carcasse ne traverse pas le plancher")
	ally.set_physics_process(false);ally.global_position=Vector3(185,10.045,110)
	await put_player(Vector3(180,10.045,105))
	Input.action_press("move_forward");await frames(100);Input.action_release("move_forward")
	check(player.global_position.z<97 and player.global_position.y<10.2,"Le joueur traverse le passage encombré sans grimper sur la carcasse")
	check(game.squad.clear_walk(Vector3(180,10.045,105),Vector3(180,10.045,96)),"Le calcul de trajet de l'allié ignore aussi les carcasses")
	# Reproduce an ally already embedded in the settled wreck, then let its real AI recover.
	await put_player(Vector3(180,10.045,110))
	ally.reset_at(Vector3(180,10.045,wreck.global_position.z));ally.set_physics_process(true)
	await frames(180)
	check(ally.global_position.z>106.5 and not ally.waiting,"Un compagnon placé dans la carcasse rejoint à nouveau le joueur sans téléportation")
	ally.set_physics_process(false);ally.global_position=Vector3(185,10.045,110)
	# Real walls remain solid; only dead actors lose their blocking role.
	await put_player(Vector3(180,10.045,102));player.rotation.y=-PI/2
	Input.action_press("move_forward");await frames(50);Input.action_release("move_forward")
	check(player.global_position.x<180.8,"Le personnage reste arrêté par le mur du couloir")
	var robot: CharacterBody3D=game.add_enemy(0,Vector3(180,10.045,99),"TEST ROBOT",true)
	robot.set_physics_process(false);robot.receive_hit_at(robot.global_position,Vector3.UP,Vector3.DOWN,999)
	await frames(50)
	check(robot.wreck.collision_layer==0 and robot.wreck.pose_ready,"Les robots terrestres détruits sont eux aussi non bloquants après leur repli")
	await put_player(Vector3(180,10.045,105));ally.reset_at(Vector3(180,10.045,96));ally.set_physics_process(true)
	await frames(180)
	check(ally.global_position.z>102,"L'allié traverse un passage contenant plusieurs carcasses et débris")
	var prior: Vector3=wreck.global_position
	paused=true;await frames(12);paused=false
	check(wreck.global_position.is_equal_approx(prior),"La pause conserve le comportement des épaves")
	await finish_run()
