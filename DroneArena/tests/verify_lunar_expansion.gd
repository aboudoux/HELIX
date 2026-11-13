extends "res://tests/verify.gd"
const WORLD := preload("res://missions/lunar_escape/lunar_world.gd")
const SHIP := preload("res://missions/lunar_escape/mothership.gd")

func run() -> void:
	game = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(game)
	current_scene = game
	player = game.pilot
	player.set_third_person(false)
	game.step = game.Step.HABITAT
	game.hud.title_card.hide()
	game.hud.set_film(false)
	game.camera.make_current()
	player.unlock_weapon("pistol")
	player.set_control(true)
	await frames(5)
	for i in range(3):
		var station: Dictionary = game.base_life.stations[i]
		var journal: Vector3 = station.journal.global_position
		await put_player(Vector3(journal.x,0.045,journal.z-1.1))
		check(game.nearest_interaction()=="annex:journal:%d"%i,"Le journal %d est accessible à pied"%i)
		game.interact("annex:journal:%d"%i)
		check(paused and game.base_life.log_window.visible,"Lecture du journal %d sans combat en arrière-plan"%i)
		if i==0: await screenshot("expansion_journal.png")
		game.base_life.close_journal()
		var relay: Vector3 = station.relay.global_position
		await put_player(Vector3(relay.x,0.045,relay.z-1.0))
		game.interact("annex:relay:%d"%i)
		await frames(50)
		var door: Node3D = game.world.doors["cache_%d"%i]
		check(door.is_open,"Réarmement du sas caché %d"%i)
		await put_player(door.global_position+Vector3(0,0.045,-1.8))
		player.rotation.y = PI
		Input.action_press("move_forward")
		await frames(34)
		Input.action_release("move_forward")
		await frames(8)
		check(player.global_position.z>door.global_position.z+0.3,"Le joueur traverse physiquement le sas %d"%i)
		var reward_id := "annex:reward:%d"%i
		check(game.base_life.nearest()==reward_id,"Le module %d est à portée dans l'annexe"%i)
		game.interact(reward_id)
		game.interact(reward_id)
		await frames(3)
		check(station.taken and player.upgrades.size()==i+1,"Le module %d ne s'applique qu'une fois"%i)
		if i==0: await screenshot("expansion_annexe.png")
	game.hud.hide()
	game.film.make_current()
	var workshop: Node3D = game.world.get_node("Selene/Observatoire")
	game.frame_camera(workshop.to_global(Vector3(-1,2.1,-8)),workshop.to_global(Vector3(-3,1.4,-2.0)))
	await frames(12)
	await screenshot("expansion_observatoire.png")
	game.camera.make_current()
	game.hud.show()
	var oxygen: float = player.oxygen
	player.update_air(10.0,false)
	check(absf(oxygen-player.oxygen-4.68)<0.01,"Le recycleur réduit effectivement la consommation d'air")
	player.unlock_weapon("shotgun")
	check(player.weapon.recoil_multiplier==0.72,"Le stabilisateur reste actif après un changement d'arme")
	check(player.weapon.shot_sound.stream.resource_path.ends_with("recorded_shotgun.wav"),"Le fusil à pompe possède sa propre détonation enregistrée")
	player.unlock_weapon("smg")
	check(player.weapon.shot_sound.stream.resource_path.ends_with("recorded_rifle.wav"),"Le fusil automatique possède sa propre détonation enregistrée")
	player.shield_unlocked = true
	player.shield_charge = 0
	player.shield_delay = 0
	await frames(30)
	check(player.shield_charge>=19 and player.shield_charge<24,"Le condensateur accélère la recharge réelle du bouclier")
	game.respawn()
	check(player.upgrades.size()==3 and player.oxygen_efficiency==0.65 and player.weapon.recoil_multiplier==0.72,"Les trois améliorations survivent au checkpoint")
	var drone: CharacterBody3D = game.add_enemy(2,Vector3(0,2.4,0),"BLINDAGE TEST")
	var plate: MeshInstance3D = drone.damage_details.plates[0]
	drone.receive_hit_at(plate.global_position,Vector3.LEFT,Vector3.RIGHT,2)
	check(not plate.visible and drone.damage_details.removed==1 and get_nodes_in_group("armor_fragments").size()>0,"Une plaque se détache d'un drone encore vivant")
	var spider: CharacterBody3D = game.add_spider(2,5.8,12.0)
	spider.arm_ambush()
	await put_player(Vector3(0,0.045,-700))
	var held: Vector3 = spider.global_position
	await frames(20)
	check(spider.ambush_armed and spider.global_position.is_equal_approx(held),"L'araignée attend au plafond sans poursuivre à travers les murs")
	await put_player(Vector3(spider.position.x,0.045,spider.position.z+2.0))
	await frames(4)
	check(not spider.ambush_armed and spider.ambush_warning>0,"Une approche visible déclenche un avertissement avant l'embuscade")
	var speed: float = spider.move_speed
	spider.receive_hit_at(spider.to_global(Vector3(-0.8,0.1,0)),Vector3.LEFT,Vector3.RIGHT)
	check(spider.damaged_legs.size()==1 and spider.move_speed<speed,"Un tir dans une patte ralentit l'araignée")
	spider.set_physics_process(false)
	var ship := SHIP.new()
	ship.pilot = player
	game.add_child(ship)
	ship.position = WORLD.pad(0,7,-225)
	ship.activate()
	ship.set_physics_process(false)
	for hit in range(6):
		ship.receive_hit_at(ship.subsystems[0].global_position,Vector3.LEFT,Vector3.RIGHT)
	check(ship.subsystem_hp[0]==0 and not ship.subsystems[0].visible,"Six impacts détruisent une nacelle sans tuer le boss")
	ship.phase = 0
	ship.start_attack()
	check(ship.shots_left==3,"La destruction de la nacelle réduit la salve suivante")
	ship.recover()
	check(ship.cooldown>1.45,"Une nacelle détruite allonge la fenêtre de contre-attaque")
	for hit in range(6):
		ship.receive_hit_at(ship.subsystems[1].global_position,Vector3.RIGHT,Vector3.LEFT)
	ship.phase = 1
	ship.pattern_index = 1
	ship.start_attack()
	check(ship.subsystem_hp[1]==0 and ship.strike_radius<2.0,"La seconde nacelle détruite réduit la zone des bombardements")
	ship.recover()
	ship.phase = 2
	ship.pattern_index = 2
	ship.start_attack()
	check(ship.attack==ship.Attack.SHOCKWAVE and ship.cooldown>=1.0 and ship.wave.visible,"L'onde finale est annoncée avant de pouvoir blesser")
	await put_player(WORLD.pad(7,0.045,-225))
	ship.wave_origin = WORLD.pad(0,0.1,-225)
	ship.wave.global_position = ship.wave_origin
	ship.wave_radius = 6.5
	ship.wave_hit = false
	ship.wave_active = true
	player.shielding = false
	player.hurt_cooldown = 0
	var health: int = player.health
	ship.advance_wave(0.04)
	check(player.health==health-24,"L'onde touche un joueur qui reste au sol")
	Input.action_press("jump")
	await frames(18)
	Input.action_release("jump")
	player.hurt_cooldown = 0
	health = player.health
	ship.wave_hit = false
	ship.wave_radius = 6.5
	ship.advance_wave(0.04)
	check(player.health==health and player.position.y>WORLD.ROOF_HEIGHT+0.85,"Un vrai saut évite l'onde")
	game.hud.hide()
	game.film.make_current()
	game.frame_camera(ship.position+Vector3(9,5,12),ship.position)
	await frames(12)
	await screenshot("expansion_boss.png")
	ship.receive_hit_at(ship.position,Vector3.UP,Vector3.DOWN,1000000)
	check(ship.health==0 and not ship.active and not ship.wave.visible,"La mort du boss arrête l'onde et conserve la compatibilité HELIX infini")
	print("%d vérifications des ajouts, %d échec(s)"%[checks,failures])
	for sound in game.find_children("*","AudioStreamPlayer",true,false)+game.find_children("*","AudioStreamPlayer3D",true,false):
		sound.stop()
	OS.delay_msec(70)
	game.queue_free()
	await frames(4)
	OS.delay_msec(80)
	quit(1 if failures else 0)

func screenshot(file: String) -> void:
	if DisplayServer.get_name()=="headless": return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/artifacts"))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/artifacts/"+file)
