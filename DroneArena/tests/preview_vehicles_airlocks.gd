extends "res://tests/verify_lunar_escape.gd"

func run() -> void:
	game = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(game); current_scene = game; player = game.pilot
	await frames(5); game.hud.title_card.hide(); game.hud.set_film(true); game.film.make_current()
	game.frame_camera(game.world.bike.position+Vector3(2.6,1.7,-3.2),game.world.bike.position+Vector3.UP*0.7)
	await capture("vehicule_moto.png")
	game.frame_camera(game.world.transport.position+Vector3(6,3.7,7),game.world.transport.position+Vector3.UP)
	await capture("vehicule_blinde.png")
	game.frame_camera(WORLD.at(0,0,1.7,23),WORLD.at(0,1,1.5,19))
	await capture("sas_pression.png")
	game.frame_camera(WORLD.at(2,40,30,-65),WORLD.at(2,11,9,-35))
	await capture("tour_interieure.png")
	game.frame_camera(WORLD.at(2,22,7.3,-40),WORLD.at(2,22,14,-28))
	await capture("escalier_interieur.png")
	await finish_run()
