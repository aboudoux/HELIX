extends "res://tests/verify_lunar_escape.gd"

func run() -> void:
	teleport_escorts_for_test = false
	game = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(game); current_scene = game; player = game.pilot
	await frames(4)
	game.hud.title_card.hide(); game.hud.set_film(false); game.camera.make_current()
	game.step = game.Step.WORKSHOP; game.set_physics_process(false)
	for director in game.directors+game.upper_directors: director.process_mode = Node.PROCESS_MODE_DISABLED
	player.set_control(true); player.set_physics_process(false)
	for actor in game.squad.members:
		actor.set_physics_process(false)
		actor.has_greeted = false; actor.notice_clock = 0
		player.global_position = actor.global_position+Vector3(0,0.05,2.9)
		aim_at(actor.global_position+Vector3.UP*1.5)
		var obstacle := WORLD.block(game.world,actor.global_position+Vector3(0,1.1,1.5),Vector3(1.9,2.2,0.25),WORLD.FRAME,true)
		await frames(3)
		actor._physics_process(0.16)
		check(not actor.has_greeted,"%s ne voit pas le joueur à travers une cloison"%actor.identity)
		obstacle.queue_free(); await frames(3)
		actor._physics_process(0.16)
		check(actor.has_greeted and actor.greeting_left>1.8,"%s salue dès que le joueur le voit"%actor.identity)
		check(not actor.recruited and not actor.avatar.gun.visible,"%s reste dans son abri sans être recruté automatiquement"%actor.identity)
		actor.set_physics_process(true)
		await frames(20)
		if DisplayServer.get_name()!="headless": await capture("survivant_%d_accueil.png"%actor.slot)
		var initial: Vector3 = actor.global_position
		var moved := 0.0
		for i in range(180):
			await physics_frame
			moved = maxf(moved,actor.global_position.distance_to(initial))
		print("REFUGE ",actor.identity," home ",actor.refuge_origin," point ",actor.global_position," goal ",actor.refuge_goal," wait ",actor.refuge_wait," legs ",actor.refuge_leg," moved ",moved," velocity ",actor.velocity)
		check(moved>0.25,"%s marche réellement avant le recrutement"%actor.identity)
		check(actor.global_position.distance_to(actor.refuge_origin)<1.6,"%s reste près de son abri"%actor.identity)
		var before: Vector3 = actor.global_position
		var clock_before: float = actor.avatar.clock
		paused = true; await frames(30)
		check(actor.global_position.is_equal_approx(before) and actor.avatar.clock==clock_before,"La pause fige les gestes et les déplacements de %s"%actor.identity)
		paused = false
		actor.set_physics_process(false)
	check(game.mechanic==game.squad.members[2].avatar and game.mechanic.get_parent()==game.squad.members[2],"Lina utilise le même corps visible avant et après le sauvetage")
	game.squad.recruit(2)
	check(game.mechanic.is_visible_in_tree() and game.mechanic.gun.visible,"Lina reste visible et prend son arme après le recrutement")
	game.mechanic.hide()
	game.mechanic_rescued = true
	game.story.restore({"flags":{"power":true,"survivors":true}},game.Step.TRANSPORT)
	check(game.mechanic.is_visible_in_tree(),"Une reprise de sauvegarde restaure aussi le corps visible de Lina")
	await finish_run()
