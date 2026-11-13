extends "res://tests/verify_lunar_escape.gd"

func run() -> void:
	teleport_escorts_for_test=false
	game=load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(game);current_scene=game;player=game.pilot
	await frames(5);game.hud.title_card.hide();game.set_physics_process(false)
	for actor in game.squad.members:
		actor.set_physics_process(false);actor.reparent(game.world,true);actor.show();actor.avatar.gun.show()
		actor.global_position=Vector3(-2+actor.slot*2,.05,35);actor.rotation.y=PI
		actor.avatar.animate_escort(actor,.016,actor.get_aim_point()+Vector3.BACK*10,0,false)
	game.begin_film(Vector3(-3.3,1.7,39.6),Vector3(-.6,1.1,35))
	await capture("reference_combinaisons.png")
	game.frame_camera(Vector3(-2.7,1.4,37.15),Vector3(-1.9,1.25,35))
	await capture("reference_combinaison_detail.png")
	var mael: Node3D=game.squad.members[0].avatar
	mael.gun.hide();mael.pose_rest()
	game.film.fov=50
	game.frame_camera(Vector3(-2.36,1.64,36.45),Vector3(-2,1.35,35))
	await capture("eva_reference_portrait.png")
	game.film.fov=75
	mael.gun.show()
	var soil: RefCounted=game.world.surface_profile
	var target:=Vector3(80,soil.elevation(80,35),35)
	game.frame_camera(target+Vector3(6,4,7),target)
	await capture("reference_sol_lunaire.png")
	game.end_film();player.unlock_weapon("pistol");player.set_control(true)
	await put_player(Vector3(0,.05,35));player.rotation.y=PI
	game.hud.set_film(false);await capture("reference_gants.png")
	await finish_run()
