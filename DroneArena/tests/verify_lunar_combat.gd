extends "res://tests/verify.gd"
## --headless --path DroneArena --script res://tests/verify_lunar_combat.gd --fixed-fps 60

const CAMPAIGN := preload("res://missions/lunar_escape/campaign.gd")
const WORLD := preload("res://missions/lunar_escape/lunar_world.gd")
const ROUTES := preload("res://missions/lunar_escape/lunar_routes.gd")


func run() -> void:
	game = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(game)
	current_scene = game
	player = game.pilot
	player.set_third_person(false)
	game.step = CAMPAIGN.Step.BIKE
	game.hud.title_card.hide()
	game.hud.set_film(false)
	game.camera.make_current()
	player.unlock_weapon("pistol")
	player.set_control(true)
	await frames(6)
	await verify_vehicle_gun()

	var bike: Node3D = game.world.bike
	var truck: Node3D = game.world.transport
	await walk_into(bike.position + Vector3(2, 0.05, -0.04), PI / 2)
	check(player.position.x > bike.position.x+0.54, "Le joueur ne traverse pas la moto garée")
	await walk_into(truck.position + Vector3(4.7, 0.05, 0), PI / 2)
	check(player.position.x > 1.98, "Le joueur ne traverse pas le blindé garé")
	var truck_body := truck.get_node("ParkedCollision") as StaticBody3D
	var ray := PhysicsRayQueryParameters3D.create(truck.position + Vector3(5, 0.88, 0),
		truck.position + Vector3(-5, 0.88, 0), 1)
	check(game.get_world_3d().direct_space_state.intersect_ray(ray).get("collider") == truck_body,
		"La coque garée bloque aussi les tirs")

	verify_tiers()
	var target := ROUTES.point(1, -510.0) + Vector3.UP * 0.045
	var hound: CharacterBody3D = game.add_enemy(1, target - Vector3(0, 0, WORLD.BASE_Z[1]), "LIMIER DE TEST", true)
	hold_encounter(1)
	await walk_into(hound.position + Vector3(0, 0.045, 3.2), 0)
	check(player.position.z > hound.position.z + 0.70, "La collision du limier bloque le joueur à pied")
	truck.position = ROUTES.point(1, -490.0)
	var bearing := truck.position.direction_to(Vector3(target.x, 0, target.z))
	truck.rotation.y = atan2(-bearing.x, -bearing.z)
	await put_player(truck.position + Vector3(2.7, 0.045, 0))
	player.mount(truck)
	await frames(5)
	check(player.drive_colliders.size() == truck_body.parts.size()
		and truck_body.parts.all(func(part): return part.disabled), "Le blindé utilise les mêmes formes en conduite et au stationnement")
	Input.action_press("move_forward")
	var top_speed := 0.0
	var hit_hound := false
	for tick in range(245):
		await physics_frame
		top_speed = maxf(top_speed, player.vehicle_speed)
		for index in range(player.get_slide_collision_count()):
			hit_hound = hit_hound or player.get_slide_collision(index).get_collider() == hound
	Input.action_release("move_forward")
	check(hit_hound and top_speed > 19.0 and (hound.position - player.position).dot(bearing) > 3.15,
		"À vitesse élevée, la coque du blindé s’arrête devant le limier")
	await frames(20)
	check(player.dismount(), "Le pilote peut descendre à côté de la coque sans la traverser")
	await frames(5)
	check(truck_body.parts.all(func(part): return not part.disabled) and player.drive_colliders.is_empty(),
		"Le blindé redevient un obstacle dès que le pilote descend")

	await put_player(hound.position + Vector3(4.1, 0.045, 1.7))
	await aim_at(hound.global_position + Vector3.UP)
	await shoot_once()
	check(hound.health == hound.max_health - 1 and hound.hull.position.length() > 0.016,
		"Une balle touche la coque du limier et la fait reculer")
	while hound.alive:
		hound.receive_hit()
	var hound_wreck: RigidBody3D = hound.wreck
	await frames(25)
	var fire := hound_wreck.get_node("WreckFire")
	check(fire.flames.emitting and fire.smoke.emitting and hound_wreck.rotation.length() > 0.13,
		"Le limier bascule et son épave émet des flammes et de la fumée")
	if DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/artifacts"))
		await aim_at(hound_wreck.global_position + Vector3.UP * 0.65)
		await capture("lune_limier_en_feu.png")

	var drone: CharacterBody3D = game.add_enemy(0, Vector3(0, 3.8, -43), "DRONE DE TEST")
	game.directors[0].flight_height = 3.8
	hold_encounter(0)
	await put_player(Vector3(0, 0.045, -37))
	var rotor: CollisionShape3D = drone.extra_colliders[0]
	var rotor_ray := PhysicsRayQueryParameters3D.create(rotor.global_position + Vector3.UP * 0.8,
		rotor.global_position + Vector3.DOWN * 0.32, 8)
	check(game.get_world_3d().direct_space_state.intersect_ray(rotor_ray).get("collider") == drone,
		"Un tir sur un rotor touche le drone hors de son fuselage")
	await aim_at(drone.global_position)
	await shoot_once()
	check(drone.health == 2 and drone.hull.rotation.length() > 0.01 and drone.extra_colliders.size() == 4,
		"Le drone accuse l’impact et ses quatre rotors ont une collision")
	while drone.alive:
		drone.receive_hit()
	var drone_wreck: RigidBody3D = drone.wreck
	var drop_height := drone_wreck.position.y
	await frames(9)
	check(drone_wreck.position.y < drop_height and not drone_wreck.has_exploded,
		"Le drone chute avant de déclencher son explosion")
	for tick in range(300):
		if drone_wreck.has_exploded:
			break
		await physics_frame
	check(drone_wreck.has_exploded and drone_wreck.impact_count == 1
		and drone_wreck.get_node_or_null("WreckFire") != null, "Le drone explose une fois au contact du sol")
	if DisplayServer.get_name() != "headless":
		await aim_at(drone_wreck.global_position)
		await capture("lune_drone_ecrasement.png")

	var spider: CharacterBody3D = game.add_spider(2, 5.8, 1.1)
	spider.set_physics_process(false)
	var spider_point := spider.position
	await walk_into(spider_point + Vector3(3, -spider_point.y + 0.045, 0), PI / 2)
	check(player.position.x > spider.position.x + 0.50,
		"L’araignée accrochée au mur reste un obstacle pour le joueur")
	spider.offset = 12.0
	spider.update_route(0.0)
	while spider.health > 0:
		spider.receive_hit_at(spider.position, Vector3.UP, Vector3.FORWARD)
	var spider_wreck := game.get_node("Wrecks/Epave_Araignee") as RigidBody3D
	var ceiling_height := spider_wreck.position.y
	await frames(19)
	check(spider_wreck.position.y < ceiling_height - 0.15 and spider_wreck.get_node_or_null("WreckFire") != null,
		"Abattue au plafond, l’araignée décroche et tombe en brûlant")
	await clean_exit()


func hold_encounter(base: int) -> void:
	var director: Node3D = game.directors[base]
	director.process_mode = Node.PROCESS_MODE_INHERIT
	for actor in director.get_children():
		actor.attack_enabled = false
		actor.move_speed = 0.0


func verify_vehicle_gun() -> void:
	var target: CharacterBody3D = game.add_enemy(0, Vector3(0.27, 2.4, -36), "CIBLE DU CANON")
	target.max_health = 20
	target.health = 20
	target.process_mode = Node.PROCESS_MODE_ALWAYS
	target.set_physics_process(false)
	await put_player(game.world.bike.position + Vector3(1.4, 0.045, 0))
	player.mount(game.world.bike)
	await frames(3)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(70, -25)
	Input.parse_input_event(motion)
	await frames(2)
	if DisplayServer.get_name() != "headless":
		check(absf(player.head.rotation.y) > 0.05 and absf(player.rotation.y) < 0.01,
			"La souris vise depuis le véhicule sans tourner son châssis")
	player.head.look_at(target.global_position)
	var rounds: int = player.weapon.ammo
	Input.action_press("fire")
	await frames(2)
	Input.action_release("fire")
	check(target.health == 19 and player.weapon.ammo == rounds,
		"Le canon touche la cible du viseur avec ses propres munitions")
	await frames(22)
	var wall := WORLD.block(game.world, game.world.bike.position+Vector3(0.0, 1.1, -1.15), Vector3(3.0, 2.2, 0.18), WORLD.WHITE, true)
	await frames(3)
	Input.action_press("fire")
	await frames(3)
	Input.action_release("fire")
	check(target.health == 19, "Un mur entre le véhicule et son canon bloque le tir")
	wall.queue_free()
	await frames(22)
	paused = true
	player.fire_cannon()
	check(target.health == 19, "Le canon reste arrêté pendant la pause")
	paused = false
	player.dismount()
	check(player.head.rotation.y == 0.0, "La vue revient dans l’axe en descendant")
	target.queue_free()
	await put_player(game.world.scout.position + Vector3(2.9, 0.045, 0))
	player.mount(game.world.scout)
	player.restore_health()
	player.apply_damage(20)
	check(player.health == player.max_health - 11, "Le blindage absorbe une partie des dégâts en cabine")
	player.dismount(false)
	player.shield_unlocked = true
	player.shield_charge = 1.0
	player.shielding = true
	player.restore_health()
	player.apply_damage(20)
	check(player.health <= 81 and player.shield_charge == 0.0,
		"Un bouclier presque vide ne peut pas absorber une attaque entière")
	player.shield_unlocked = false
	player.shielding = false
	player.restore_health()
	await frames(3)


func verify_tiers() -> void:
	var selene: CharacterBody3D = game.directors[0].get_child(1)
	var tycho: CharacterBody3D = game.directors[1].get_child(0)
	var copernic: CharacterBody3D = game.directors[2].get_child(0)
	check(selene.max_health < tycho.max_health and tycho.max_health < copernic.max_health,
		"La vie des sentinelles augmente de Séléné à Copernic")
	check(selene.move_speed < tycho.move_speed and tycho.move_speed < copernic.move_speed
		and selene.fire_interval > tycho.fire_interval and tycho.fire_interval > copernic.fire_interval,
		"Les sentinelles se déplacent et tirent plus vite à chaque base")
	check(selene.director.projectile_damage < tycho.director.projectile_damage
		and tycho.director.projectile_damage < copernic.director.projectile_damage
		and selene.director.projectile_speed < tycho.director.projectile_speed
		and tycho.director.projectile_speed < copernic.director.projectile_speed,
		"Les projectiles accélèrent et infligent davantage de dégâts")


func walk_into(origin: Vector3, yaw: float) -> void:
	await put_player(origin)
	player.rotation.y = yaw
	Input.action_press("move_forward")
	await frames(75)
	Input.action_release("move_forward")
	await frames(6)


func shoot_once() -> void:
	Input.action_press("fire")
	await frames(2)
	Input.action_release("fire")
	await frames(5)


func clean_exit() -> void:
	for sound in game.find_children("*", "AudioStreamPlayer", true, false) + game.find_children("*", "AudioStreamPlayer3D", true, false):
		sound.stop()
	OS.delay_msec(70)
	game.queue_free()
	await frames(4)
	OS.delay_msec(80)
	print("%d vérifications de combat, %d échec(s)" % [checks, failures])
	quit(1 if failures else 0)
