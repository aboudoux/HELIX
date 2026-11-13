extends "res://tests/verify.gd"
## Native run also captures the three viewmodels, reloads and articulated spider.
const CAMPAIGN := preload("res://missions/lunar_escape/campaign.gd")

func run() -> void:
	game = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(game)
	current_scene = game
	player = game.pilot
	player.set_third_person(false)
	game.step = CAMPAIGN.Step.HABITAT
	game.hud.title_card.hide()
	game.hud.set_film(false)
	game.camera.make_current()
	player.unlock_weapon("pistol")
	player.set_control(true)
	await put_player(Vector3(5,0.045,10))
	for key in ["pistol","shotgun","smg"]:
		player.unlock_weapon(key)
		await frames(30)
		await screenshot("design_%s.png" % key)
		Input.action_press("aim")
		await frames(30)
		var sight: Vector3 = player.gun_visual.to_global(Vector3(0,player.gun_visual.sight_height,-0.2))
		var screen: Vector2 = game.camera.unproject_position(sight)
		check(screen.distance_to(root.get_visible_rect().size*0.5)<2.0,"%s : viseur aligné au centre en visée" % key)
		await screenshot("design_%s_aim.png" % key)
		Input.action_release("aim")
		await frames(20)
		player.weapon.fire()
		await frames(14 if key=="shotgun" else 2)
		check(player.gun_visual.action.position.z>player.gun_visual.action_seat.z+0.009,"%s : mécanisme mobile après le tir" % key)
		if key=="shotgun":
			check(absf((player.gun_visual.support.position.z-player.gun_visual.support_seat.z)-(player.gun_visual.action.position.z-player.gun_visual.action_seat.z))<0.003,"La main accompagne exactement la pompe")
		await frames(40)
		player.weapon.ammo = 0
		player.weapon.reserve_ammo = 2
		player.weapon.start_reload()
		await frames(roundi(player.weapon.reload_duration*60*0.40))
		await screenshot("design_%s_reload.png" % key)
		var magazine: Vector3 = player.gun_visual.magazine.position
		paused = true
		await frames(8)
		check(magazine.is_equal_approx(player.gun_visual.magazine.position),"%s : pose de recharge figée pendant la pause" % key)
		paused = false
		await frames(100)
		check(player.weapon.ammo==2 and player.weapon.reserve_ammo==0,"%s : deux cartouches disponibles, deux cartouches transférées" % key)
		check(player.gun_visual.magazine.position.is_equal_approx(player.gun_visual.magazine_seat),"%s : chargeur réinséré au repos" % key)
	var spider: CharacterBody3D = game.add_spider(2,5.8,12.0)
	await frames(3)
	spider.set_physics_process(false)
	check(spider.legs.size()==8,"L'araignée possède huit pattes articulées")
	var leg: Node3D = spider.legs[0]
	leg.step(spider,0.60)
	var foot: Vector3 = leg.toe.global_position
	spider.position += -spider.global_basis.z*0.04
	leg.step(spider,0.64)
	check(foot.distance_to(leg.toe.global_position)<0.002,"Un pied en appui reste fixe pendant le déplacement du corps")
	for offset in [1.1,12.0,24.0]:
		spider.offset = offset
		spider.elapsed = 0.0
		spider.update_route(0.0)
		for limb in spider.legs:
			limb.initialized = false
			limb.step(spider,0.60)
		var lengths_ok := true
		for limb in spider.legs:
			lengths_ok = lengths_ok and absf(limb.upper.position.distance_to(limb.lower.position)-limb.UPPER)<0.001
			lengths_ok = lengths_ok and absf(limb.lower.position.distance_to(limb.toe.position)-limb.LOWER)<0.001
		check(lengths_ok,"Les huit articulations restent raccordées sur la surface %.1f" % offset)
	spider.offset = 1.1
	spider.update_route(0.0)
	for limb in spider.legs:
		limb.initialized = false
		limb.step(spider,0.60)
	game.hud.hide()
	game.film.make_current()
	game.frame_camera(spider.position+spider.global_basis*Vector3(2.6,2.1,-3.2),spider.position)
	await frames(12)
	await screenshot("design_spider.png")
	spider.set_physics_process(true)
	await frames(90)
	check(spider.gait>0.5,"La démarche progresse avec la distance réellement parcourue")
	spider.receive_hit_at(spider.position,Vector3.UP,Vector3.FORWARD,1000)
	await frames(45)
	var wreck: Node3D = game.get_node("Wrecks/Epave_Araignee")
	var folded: Node3D = wreck.get_node("Visual/Leg0_L")
	check(folded.toe.position.distance_to(Vector3(-0.43,-0.16,folded.hip.z-0.12))<0.005,"Les pattes de l'épave se replient sans se désarticuler")
	game.frame_camera(wreck.position+Vector3(2.8,1.9,-2.6),wreck.position)
	await frames(12)
	await screenshot("design_spider_wreck.png")
	print("%d vérifications design et animations, %d échec(s)" % [checks,failures])
	for sound in game.find_children("*","AudioStreamPlayer",true,false)+game.find_children("*","AudioStreamPlayer3D",true,false):
		sound.stop()
	OS.delay_msec(70)
	game.queue_free()
	await frames(4)
	OS.delay_msec(80)
	quit(1 if failures else 0)

func screenshot(filename: String) -> void:
	if DisplayServer.get_name()=="headless": return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/artifacts"))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/artifacts/"+filename)
