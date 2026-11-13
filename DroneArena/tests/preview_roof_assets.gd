extends "res://tests/verify_lunar_escape.gd"

func run() -> void:
	game = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(game); current_scene = game; player = game.pilot
	await frames(4)
	game.hud.title_card.hide(); game.hud.set_film(true); game.film.make_current()
	var wreck := ROUTES.wreck_point()
	game.hud.dialogue.text = "COURRIER 04 · SOL ET PLANCHER RACCORDÉS"
	game.frame_camera(wreck+Vector3(8,3,-9),wreck+Vector3(0,1.2,0))
	await capture("correction_epave.png")
	game.hud.dialogue.text = "TYCHO · PLANCHER DU HANGAR"
	game.frame_camera(WORLD.at(1,8,2.2,-22),WORLD.at(1,0,1,-31))
	await capture("correction_hangar.png")
	game.hud.dialogue.text = "COPERNIC · PILIERS ANCRÉS DANS LE CRATÈRE"
	game.frame_camera(Vector3(90,0.5,-730),Vector3(78,3,-706))
	await capture("correction_piliers.png")
	game.hud.dialogue.text = "COPERNIC · FUSÉE ET COMBAT SUR LE TOIT"
	game.frame_camera(WORLD.at(2,65,38,-63),WORLD.at(2,0,16,-5))
	await capture("fusee_sur_le_toit.png")
	game.world.rocket_flame.show()
	game.animate_ascent(4.8)
	game.hud.dialogue.text = "ALLUMAGE ET ASCENSION PROGRESSIVE"
	game.frame_camera(game.world.rocket.global_position+Vector3(16,-4,20),game.world.rocket.global_position+Vector3.UP*2)
	await capture("fusee_nouvelle_flamme.png")
	await finish_run()
