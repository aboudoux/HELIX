extends "res://tests/verify_escorts.gd"

func run() -> void:
	game = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(game); current_scene = game; player = game.pilot
	await frames(5)
	game.hud.title_card.hide(); game.hud.set_film(true)
	game.hud.dialogue.text = "KAREN · COMBINAISONS EVA ET GESTES DE L'ÉQUIPAGE"
	game.film.make_current()
	for actor in game.squad.members:
		actor.reparent(game.world,true); actor.show(); actor.avatar.gun.show()
		actor.global_position = Vector3(-2+actor.slot*1.3,0.05,35)
		actor.rotation.y = PI
		actor.greeting_left = 1.1 if actor.slot==1 else 0.0
		actor.hurt_left = 0
	for i in range(100):
		for actor in game.squad.members:
			actor.avatar.animate_escort(actor,1.0/60,actor.get_aim_point()+Vector3.BACK*10,0,false)
		await physics_frame
	game.frame_camera(Vector3(-2.7,1.55,38.2),Vector3(-1,1.12,35))
	await frames(5); await capture_escort("revision_equipage.png")
	game.hud.dialogue.text = "SURFACE ÉTENDUE · CRATÈRES ET ROCHES"
	game.frame_camera(Vector3(390,48,-440),Vector3(310,0,-310))
	await frames(10); await capture_escort("revision_lune.png")
	game.hud.dialogue.text = "KAREN · MATÉRIAUX SOUS L'ÉCLAIRAGE INTÉRIEUR"
	game.frame_camera(Vector3(0,1.65,4),Vector3(7,1.3,-6))
	await frames(10); await capture_escort("revision_interieur.png")
	check(true,"Aperçus des combinaisons, du terrain et des matériaux intérieurs")
	await finish_run()
