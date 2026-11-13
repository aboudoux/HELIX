extends "res://tests/verify_lunar_escape.gd"

func run() -> void:
	teleport_escorts_for_test=false
	game=load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(game);current_scene=game;player=game.pilot
	await frames(5)
	game.saver.enabled=false;game.set_physics_process(false)
	game.hud.title_card.hide()
	var env: Environment=game.world.sky_environment.environment
	check(env.background_mode==Environment.BG_SKY,"La Terre appartient au ciel, sans sphère située dans la carte")
	check(WORLD.EARTH_DIRECTION.y>.5,"La Terre reste nettement au-dessus de l'horizon")
	var material: ShaderMaterial=env.sky.sky_material
	check(material.get_shader_parameter("earth_map")==WORLD.EARTH_TEXTURE,"La carte terrestre est conservée dans le ciel")
	game.begin_film(Vector3(100,2,100),Vector3(100,2,100)+WORLD.EARTH_DIRECTION*100)
	game.film.fov=75
	if DisplayServer.get_name()!="headless":
		await capture("terre_ciel_surface.png")
		var first:=root.get_texture().get_image()
		var center:=Vector2i(first.get_width()/2,first.get_height()/2)
		var rect:=Rect2i(center-Vector2i(25,25),Vector2i(50,50))
		var origin: Vector3=game.film.global_position
		game.frame_camera(origin+Vector3(1200,400,-900),origin+Vector3(1200,400,-900)+WORLD.EARTH_DIRECTION*100)
		await capture("terre_ciel_altitude.png")
		var second:=root.get_texture().get_image()
		var difference:=0.0
		var brightest:=0.0
		for y in range(rect.position.y,rect.end.y):
			for x in range(rect.position.x,rect.end.x):
				var a:=first.get_pixel(x,y);var b:=second.get_pixel(x,y)
				difference+=absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)
				brightest=maxf(brightest,a.get_luminance())
		check(brightest>.15,"Le disque terrestre est effectivement visible au centre du ciel")
		check(difference/7500.0<.005,"Même position et même taille apparente après un déplacement de plus d'un kilomètre")
		var wall:=WORLD.block(game,game.film.global_position+WORLD.EARTH_DIRECTION*12,Vector3(8,8,8),WORLD.FRAME,false)
		await capture("terre_occlusion.png")
		var covered:=root.get_texture().get_image()
		check(covered.get_region(rect).get_data()!=second.get_region(rect).get_data(),"Les parois opaques masquent le ciel")
		wall.queue_free();await frames(2)
		game.frame_camera(WORLD.pad(40,140,-180),WORLD.pad(0,0,-240))
		await capture("terre_absente_terrain.png")
	var flight:=preload("res://missions/lunar_escape/return_flight.gd").new()
	game.add_child(flight);flight.setup(game)
	check(game.film.environment!=env and game.film.environment.background_mode==Environment.BG_COLOR,"La rentrée terrestre utilise son propre ciel, sans Terre miniature supplémentaire")
	await finish_run()
