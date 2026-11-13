extends "res://tests/verify_escorts.gd"

func run() -> void:
	game = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(game); current_scene = game; player = game.pilot
	await frames(5)
	game.hud.title_card.hide()
	game.hud.set_film(true)
	game.hud.dialogue.text = "ESCOUADE KAREN · MAËL / NOOR / LINA"
	game.film.make_current()
	for actor in game.squad.members:
		actor.reparent(game.world,true)
		actor.show()
		actor.avatar.gun.show()
		actor.global_position = Vector3(-2+actor.slot*2,0.05,35)
		actor.rotation.y = PI
		actor.avatar.animate_escort(actor,0.016,actor.get_aim_point()+Vector3.BACK*10,0,false)
	game.frame_camera(Vector3(-3.3,1.7,39.6),Vector3(-0.6,1.1,35))
	await frames(30)
	await capture_escort("escorts_suit.png")
	game.frame_camera(Vector3(-2.8,1.45,37.25),Vector3(-1.3,1.15,35))
	await frames(5)
	await capture_escort("escorts_suit_detail.png")
	check(game.squad.members.all(func(actor): return actor.avatar.gun.visible),"Aperçu des trois combinaisons et des armes généré")
	await finish_run()
