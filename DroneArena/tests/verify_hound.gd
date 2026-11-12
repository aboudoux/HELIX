extends "res://tests/verify.gd"
## Vraies poursuite au sol, rafales, esquive, impacts et progression avec les limiers.

var hound: CharacterBody3D
var graphics: bool


func snap(name: String) -> void:
	if graphics:
		await frames(4)
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tests/artifacts/"+name)) == OK,"Capture "+name)


func cleanup() -> void:
	for action in ["fire","move_right"]: Input.action_release(action)
	for sound in game.find_children("*","AudioStreamPlayer",true,false)+game.find_children("*","AudioStreamPlayer3D",true,false): sound.stop()
	OS.delay_msec(50)
	game.queue_free()
	paused = false
	await frames(4)
	OS.delay_msec(80)


func run() -> void:
	graphics = DisplayServer.get_name()!="headless"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/artifacts"))
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	player = game.player
	hound = game.get_node("Drones/Sentinelle03")
	await frames(5)
	check(hound.is_in_group("hounds") and hound.visual.scene_file_path.ends_with("helix_hound.glb"),"Le troisième hostile d'entraînement est le K-9 Blender")
	check(hound.hips.size()==4 and hound.knees.size()==4 and not hound.hips.has(null),"Les quatre chaînes de pattes sont importées")
	check(hound.muzzle!=null and hound.turret!=null,"Le canon dorsal conserve son pivot et sa bouche")
	check(hound.visual.find_children("*","CollisionObject3D",true,false).is_empty(),"Le GLB reste séparé de la physique Godot")
	check(not hound.get_node("StepSound").playing and hound.shots_fired==0,"Le menu ne lance ni pas ni laser")
	for level in range(3):
		hound.configure_difficulty(Difficulty.PROFILES[level])
		check(hound.max_health==2+level and is_equal_approx(hound.move_speed,Difficulty.PROFILES[level].move_speed*1.35),"Vie et poursuite adaptées à la difficulté %d" % level)
	hound.configure_difficulty(Difficulty.PROFILES[1])
	for actor in game.get_node("Drones").get_children():
		actor.attack_enabled = false
	game.start_exploration()
	await put_player(Vector3(-15,.05,18))
	var origin := hound.position
	var angle: float = hound.hips[0].rotation.x
	await frames(180)
	check(hound.position.distance_to(origin)>4,"Le chien poursuit réellement le joueur en contournant les caisses")
	check(hound.is_on_floor() and absf(hound.position.y)<.08,"Le K-9 reste au sol avec la gravité")
	check(not is_equal_approx(hound.hips[0].rotation.x,angle),"Le déplacement anime les pattes")
	check(game.get_node("Drones").ground_navigation.ready,"La carte de marche est distincte de la carte de vol")
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = hound.hit_shape.shape
	query.transform = hound.hit_shape.global_transform.translated(Vector3.UP*.04)
	query.collision_mask = 1
	check(game.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(),"Le corps ne traverse pas les obstacles")
	hound.set_physics_process(false)
	hound.position = Vector3(0,.03,12)
	hound.rotation = Vector3(0,PI,0)
	await put_player(Vector3(3,.05,18))
	await aim_at(hound.global_position+Vector3(0,1,0))
	await snap("limier_modele.png")
	await put_player(Vector3(0,.05,18))
	await aim_at(hound.position+Vector3.UP)
	hound.attack_enabled = true
	hound.move_speed = 0
	hound.cooldown = 0
	hound.set_physics_process(true)
	await frames(8)
	check(hound.charge_remaining>0 and hound.warning.visible and hound.shots_fired==0,"Un laser de visée et une charge sonore précèdent les tirs")
	check(hound.get_node("ChargeSound").playing,"La charge du canon est audible")
	await snap("limier_verrouillage.png")
	var locked: Vector3 = hound.locked_aim
	await frames(110)
	check(hound.shots_fired==2 and hound.burst_remaining==0,"Le canon tire une rafale de deux lasers")
	check(player.health==94,"Un vrai laser inflige six dégâts en Moyen")
	check(hound.locked_aim==locked,"Le point visé reste fixe pendant la rafale")
	player.restore_health()
	hound.cooldown = 0
	await frames(5)
	Input.action_press("move_right")
	await frames(90)
	Input.action_release("move_right")
	await frames(40)
	check(player.health==100,"Le déplacement latéral esquive la rafale annoncée")
	await put_player(Vector3(0,.05,18))
	var wall := make_blocker(Vector3(0,1.5,15),Vector3(4,3,.4))
	var shots: int = hound.shots_fired
	await frames(220)
	check(hound.shots_fired==shots and not hound.warning.visible,"Une paroi bloque la visée et les tirs du chien")
	wall.queue_free()
	await frames(4)
	hound.attack_enabled = false
	hound.cooldown = 0
	await aim_at(hound.position+Vector3.UP)
	for i in range(3):
		mouse_button(true)
		await frames(2)
		mouse_button(false)
		await frames(15)
	check(not hound.alive and game.drones_destroyed==1,"Trois vrais tirs neutralisent le K-9 Moyen et comptent un hostile")
	check(is_instance_valid(hound.wreck) and hound.wreck.is_in_group("hound_wrecks"),"Le quadrupède laisse son modèle intact comme épave")
	await frames(300)
	check(is_instance_valid(hound.wreck) and hound.wreck.visible and hound.wreck.position.y<1,"L'épave reste sur le sol")
	await snap("limier_epave.png")
	game.restart_exploration()
	await frames(5)
	check(hound.alive and hound.health==3 and not is_instance_valid(hound.wreck),"Recommencer restaure le chien et nettoie son épave")
	game.show_pause()
	var frozen := hound.global_transform
	var leg: Vector3 = hound.hips[0].rotation
	await frames(35)
	check(hound.global_transform==frozen and hound.hips[0].rotation==leg,"La pause fige le quadrupède et ses articulations")
	await cleanup()

	game = load("res://missions/relay_run/mission.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	player = game.player
	await frames(5)
	var dogs: Array = game.director.get_children().filter(func(actor): return actor.is_in_group("hounds"))
	check(dogs.size()==3 and game.director.get_child_count()==15,"La mission mélange douze drones et trois chiens")
	check(dogs.all(func(dog): return not dog.alive and not dog.visible),"Les chiens attendent l'activation de leur secteur")
	for actor in game.director.get_children():
		actor.attack_enabled = false
		actor.move_speed = 0
	game.start_exploration()
	await frames(5)
	for sector in range(3):
		game.director.engage_sector(sector)
		await frames(4)
		var dog: CharacterBody3D
		for actor in game.director.get_children():
			if actor.alive and actor.is_in_group("hounds"):
				dog = actor
		check(dog!=null and dog.is_on_floor(),"Le limier du secteur %d apparaît au sol" % sector)
		var destination: Vector3 = [Vector3(-20,.05,53),Vector3(20,.05,10),Vector3(-20,.05,-30)][sector]
		await put_player(destination)
		var start: Vector3 = dog.position
		check(game.director.ground_path(start,destination).size()>12,"Chemin de marche entre annexe et cour du secteur %d" % sector)
		dog.move_speed = 4.05
		await frames(360)
		check(dog.position.distance_to(start)>8 and dog.position.distance_to(destination)<start.distance_to(destination)-6 and dog.is_on_floor(),"Poursuite physique dans l'annexe %d, sans quitter le sol" % sector)
		dog.move_speed = 0
		for actor in game.director.get_children():
			if actor.alive and not actor.is_in_group("hounds"):
				while actor.alive: actor.receive_hit()
		await put_player(game.relays[sector].global_position+Vector3(0,.05,1.6))
		check(not game.activate_relay(),"Le relais %d reste verrouillé tant que le limier vit" % sector)
		while dog.alive: dog.receive_hit()
		await frames(4)
		check(game.activate_relay(),"La neutralisation du chien permet de rétablir le relais %d" % sector)
	check(game.stage==3 and game.boss.alive and game.drones_destroyed==15,"Les groupes mixtes réveillent toujours CERBÈRE")
	await cleanup()
	print("RESULT: %d hound checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
