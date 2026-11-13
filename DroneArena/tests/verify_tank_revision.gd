extends "res://tests/verify_lunar_escape.gd"

func run() -> void:
	teleport_escorts_for_test=false
	game=load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(game);current_scene=game;player=game.pilot
	await frames(5);game.hud.title_card.hide();game.hud.set_film(false);game.camera.make_current()
	game.step=game.Step.TRANSPORT;game.set_physics_process(false)
	for director in game.directors+game.upper_directors: director.process_mode=Node.PROCESS_MODE_DISABLED
	WORLD.block(game.world,Vector3(180,9.8,100),Vector3(90,.4,100),WORLD.FLOOR,true)
	var tank: Node3D=game.world.transport;tank.global_position=Vector3(180,10.04,100)
	player.unlock_weapon("pistol");player.set_control(true);player.mount(tank);await frames(5)
	var target: CharacterBody3D=game.add_enemy(0,Vector3(180,12.3,75),"CIBLE CANON")
	target.set_physics_process(false);target.max_health=200;target.health=200
	player.head.look_at(target.global_position);await frames(2)
	var cannon: Node3D=tank.get_node("Canon")
	player.fire_cannon();await frames(5)
	check(not target.alive,"Un obus détruit en un coup un ennemi de 200 PV")
	check(cannon.barrel.position.z>.30,"Le canon recule visiblement après le tir")
	check(player.cannon_sound.stream.resource_path.ends_with("tank_cannon.wav"),"Le char utilise sa détonation lourde dédiée")
	var count: int=cannon.shots;player.fire_cannon()
	check(cannon.shots==count,"Le canon attend son cycle avant de tirer à nouveau")
	var recoil: float=cannon.barrel.position.z;paused=true;await frames(12)
	check(is_equal_approx(cannon.barrel.position.z,recoil),"La pause fige le recul du canon");paused=false
	await frames(65);check(cannon.barrel.position.z<.001,"Le tube revient dans sa position initiale")
	var wall:=WORLD.block(game.world,Vector3(180,12,88),Vector3(12,4,.4),WORLD.WHITE,true)
	var hidden: CharacterBody3D=game.add_enemy(0,Vector3(180,12.3,80),"DERRIÈRE CLOISON")
	hidden.set_physics_process(false);await frames(3);player.head.look_at(hidden.global_position)
	player.fire_cannon();await frames(3)
	check(hidden.alive,"L'obus ne traverse pas un mur")
	wall.queue_free();hidden.queue_free();target.queue_free();await frames(3)
	player.head.rotation=Vector3.ZERO
	var robot: CharacterBody3D=game.add_enemy(0,Vector3(180,10.04,94),"CIBLE POUSSÉE",true)
	robot.set_physics_process(false);await frames(3)
	Input.action_press("move_forward");await frames(95);Input.action_release("move_forward")
	check(not robot.alive,"Le char écrase un robot en avançant")
	player.vehicle_speed=0;player.velocity=Vector3.ZERO
	player.global_position=Vector3(180,10.04,100);tank.global_position=player.global_position
	robot.reset_drone();robot.set_physics_process(false)
	robot.global_position=Vector3(180,10.04,106);await frames(3)
	Input.action_press("move_back");await frames(105);Input.action_release("move_back")
	check(not robot.alive,"Le char écrase aussi en marche arrière")
	player.vehicle_speed=0;player.velocity=Vector3.ZERO
	player.global_position=Vector3(180,10.04,100);tank.global_position=player.global_position
	robot.reset_drone();robot.set_physics_process(false)
	robot.global_position=Vector3(180,10.04,94)
	wall=WORLD.block(game.world,Vector3(180,12,88),Vector3(12,4,.4),WORLD.WHITE,true);await frames(3)
	Input.action_press("move_forward");await frames(150);Input.action_release("move_forward")
	check(not robot.alive and player.global_position.z>90,"Après l'écrasement, le char reste bloqué par le mur")
	if DisplayServer.get_name()!="headless":
		wall.queue_free();await frames(2)
		game.begin_film(tank.global_position+Vector3(5,3,-6),tank.global_position+Vector3.UP*1.7)
		cannon.fire();await frames(4);await capture("char_recul_canon.png")
	await finish_run()
