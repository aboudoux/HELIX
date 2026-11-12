extends "res://tests/verify.gd"
## Impulsions allongées : croissance depuis le canon et collisions de la vraie pointe.


func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	player = game.player
	for actor in game.get_node("Drones").get_children():
		actor.attack_enabled = false
		actor.move_speed = 0
	game.start_exploration()
	await frames(4)
	var director: Node3D = game.get_node("Drones")
	var origin := Vector3(0,2.4,8)
	director.spawn_bolt(origin,Vector3.BACK,RID())
	var pulse: Node3D = game.get_node("Projectiles").get_child(0)
	check(not pulse.core.visible and not pulse.trail.visible,"Le trait ne dépasse pas derrière le canon à sa création")
	await frames(3)
	check(pulse.core.mesh is CylinderMesh and pulse.trail.mesh is CylinderMesh,"La sentinelle utilise deux traits cylindriques sans boule")
	check(pulse.trail.scale.y>0 and pulse.trail.scale.y<=pulse.travelled+.001,"Le laser grandit uniquement dans l'espace déjà parcouru")
	check(pulse.trail.to_global(Vector3(0,.5,0)).distance_to(origin)<.001,"La queue du laser reste au point de départ pendant sa croissance")
	await frames(6)
	check(is_equal_approx(pulse.trail.scale.y,1.8),"Le trait atteint sa longueur maximale de 1,8 m")
	var position_before: Vector3 = pulse.global_position
	var length_before: float = pulse.trail.scale.y
	game.show_pause()
	await frames(15)
	check(pulse.global_position==position_before and pulse.trail.scale.y==length_before,"La pause fige le laser et sa longueur")
	game.start_exploration()
	await frames(3)
	check(pulse.global_position!=position_before,"Le laser reprend sa trajectoire après la pause")
	pulse.queue_free()
	await frames(3)
	var wall := make_blocker(Vector3(0,1.5,14),Vector3(4,3,.12))
	director.spawn_bolt(origin,Vector3.BACK,RID())
	pulse = game.get_node("Projectiles").get_child(0)
	await frames(30)
	check(not is_instance_valid(pulse) and player.health==100,"Le mur arrête la pointe du laser avant d'atteindre le joueur")
	wall.queue_free()
	await frames(3)
	director.spawn_hound_bolt(Vector3(2,1.2,9),Vector3.BACK,RID())
	pulse = game.get_node("Projectiles").get_child(0)
	await frames(7)
	check(pulse.core.mesh is CylinderMesh and is_equal_approx(pulse.trail.scale.y,1.4),"Le LIMIER conserve sa couleur rose avec un trait de 1,4 m sans boule")
	pulse.queue_free()
	await frames(3)
	if DisplayServer.get_name()!="headless":
		await put_player(Vector3(3,.05,18))
		await aim_at(Vector3(-2,2.2,10))
		for start in [Vector3(-2,2.4,9),Vector3(-4,2.4,11)]:
			director.spawn_bolt(start,Vector3.BACK,RID())
		director.spawn_hound_bolt(Vector3(-1,1.4,11),Vector3.BACK,RID())
		await frames(8)
		for laser in game.get_node("Projectiles").get_children(): laser.set_physics_process(false)
		await frames(3)
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/artifacts"))
		check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tests/artifacts/lasers_ennemis.png"))==OK,"Capture réelle des traits laser")
	for sound in game.find_children("*","AudioStreamPlayer",true,false)+game.find_children("*","AudioStreamPlayer3D",true,false): sound.stop()
	OS.delay_msec(50)
	game.queue_free()
	paused = false
	await frames(4)
	OS.delay_msec(80)
	print("RESULT: %d laser checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
