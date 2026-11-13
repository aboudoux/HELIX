extends "res://tests/verify_lunar_escape.gd"
const RETURN := preload("res://missions/lunar_escape/return_flight.gd")

func run() -> void:
	teleport_escorts_for_test = false
	game = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(game); current_scene = game; player = game.pilot
	await frames(4)
	game.saver.enabled = false
	game.set_physics_process(false)
	for director in game.directors+game.upper_directors: director.process_mode = Node.PROCESS_MODE_DISABLED
	game.hud.title_card.hide()
	game.begin_film(WORLD.pad(24,7,-222),game.world.rocket.global_position+Vector3.UP*7)
	game.animate_ascent(6)
	game.world.rocket_flame.show()
	if DisplayServer.get_name()!="headless": await capture("retour_01_decollage.png")
	var flight := RETURN.new(); game.add_child(flight); flight.setup(game)
	check(game.film.cull_mask==RETURN.LAYER,"La scène terrestre exclut le terrain lunaire et sa Terre miniature")
	check(flight.earth.mesh.radius==6371 and game.film.far>12742,"La Terre possède un horizon à l'échelle planétaire dans la scène de retour")
	if DisplayServer.get_name()!="headless": await capture("retour_02_approche.png")
	flight.reentry(0.5)
	check(absf(flight.ship.position.distance_to(flight.earth.position)-(6371+flight.entry_altitude))<0.01,"La trajectoire de rentrée suit la courbure sans traverser la Terre")
	check(flight.ship.global_basis.y.dot(Vector3(0,0.16,0.987).normalized())>0.99,"Le bouclier thermique est orienté vers l'avant, la capsule vers l'arrière")
	check(not flight.service.visible and flight.plasma.get_shader_parameter("heat")>0.9,"Le module propulsif est séparé avant le maximum de chauffe")
	if DisplayServer.get_name()!="headless": await capture("retour_03_rentree.png")
	flight.descent(0.5)
	check(flight.canopy.visible and flight.ocean.visible and not flight.earth.visible,"La descente se termine sous parachute au-dessus de l'océan")
	check(flight.plasma.get_shader_parameter("heat")==0.0,"Les flammes de rentrée cessent avant la descente sous parachute")
	if DisplayServer.get_name()!="headless": await capture("retour_04_parachute.png")
	if "--preview-only" in OS.get_cmdline_user_args():
		await finish_run()
		return
	flight.queue_free(); await frames(2)
	game.film.cull_mask = 1; game.film.environment = null; game.film.far = 4000
	game.world.rocket.position = Vector3(0,0,-249); game.world.rocket.rotation = Vector3.ZERO
	game.story.boss_defeated = true; game.story.preparation = 35
	game.step = game.Step.BOARD
	game.launch()
	await frames(360)
	var rocket_position: Vector3 = game.world.rocket.position
	paused = true; await frames(20)
	check(game.world.rocket.position.is_equal_approx(rocket_position),"La pause interrompt réellement le décollage")
	paused = false
	await frames(600)
	var active: Node3D = game.get_node("RetourTerre")
	var point: Vector3 = active.ship.position
	paused = true; await frames(20)
	check(active.ship.position.is_equal_approx(point),"La pause interrompt aussi le retour dans l'espace")
	paused = false; await frames(1400)
	check(game.step==game.Step.COMPLETE and active.phase=="landed","Toute la cinématique rejoint l'épilogue après l'amerrissage")
	check(game.hud.card_title.text=="De retour sur Terre" and not player.in_control,"Le menu de fin est disponible, sans reprise du combat")
	await finish_run()
