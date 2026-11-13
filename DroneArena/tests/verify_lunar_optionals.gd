extends "res://tests/verify.gd"

const CAMPAIGN := preload("res://missions/lunar_escape/campaign.gd")
const WORLD := preload("res://missions/lunar_escape/lunar_world.gd")
const ROUTES := preload("res://missions/lunar_escape/lunar_routes.gd")

func run() -> void:
	game = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(game)
	current_scene = game
	player = game.pilot
	player.set_third_person(false)
	await frames(5)
	game.hud.title_card.hide()
	player.unlock_weapon("pistol")
	player.set_control(true)
	await verify_shortcut()
	await verify_rescue()
	await verify_transport()
	await verify_copernic()
	print("%d vérifications facultatives, %d échec(s)" % [checks, failures])
	quit(1 if failures else 0)

func verify_shortcut() -> void:
	game.step = CAMPAIGN.Step.BIKE
	var start := ROUTES.shortcut_start()
	var finish := ROUTES.shortcut_end()
	game.world.bike.position = start.lerp(finish, 0.42) + Vector3.UP * 0.04
	player.mount(game.world.bike)
	player.look_at(Vector3(finish.x, player.position.y, finish.z))
	var start_z: float = player.position.z
	Input.action_press("move_forward")
	await frames(80)
	Input.action_release("move_forward")
	check(game.using_shortcut() and start_z - player.position.z > 8.0,
		"La moto roule réellement dans le passage balisé")
	check(game.road_guards[0].process_mode == Node.PROCESS_MODE_DISABLED,
		"Le raccourci évite la patrouille sur la route principale")
	player.dismount(false)
	await frames(3)

func verify_rescue() -> void:
	game.step = CAMPAIGN.Step.WORKSHOP
	var guard: CharacterBody3D = game.rescue_guard
	var director: Node3D = game.directors[1]
	director.process_mode = Node.PROCESS_MODE_INHERIT
	guard.move_speed = 0.0
	guard.attack_enabled = false
	guard.global_position = WORLD.at(1, -18.9, 2.4, 13.0)
	var old_count := director.get_child_count()
	await put_player(WORLD.at(1, -21.7, 0.045, 13.0))
	await frames(120)
	check(guard.transmitted and director.get_child_count() == old_count + 2,
		"L’éclaireur qui garde le contact appelle deux renforts")
	await frames(40)
	check(director.get_child_count() == old_count + 2, "Un éclaireur ne transmet qu’une fois")
	check(game.world.doors["dome_1_-1"].secured, "Le drone verrouille l’accès à l’atelier")
	guard.receive_hit_at(guard.global_position, Vector3.UP, Vector3.FORWARD, 1000)
	var power: Vector3 = game.story.stations.power.marker.global_position
	await put_player(Vector3(power.x,0.045,power.z-1))
	await tap(KEY_E)
	check(game.story.flags.power,"Le courant est nécessaire pour libérer le sas de Lina")
	await put_player(WORLD.at(1, -24.5, 0.045, 17.6))
	await tap(KEY_E)
	await frames(48)
	check(game.world.doors["dome_1_-1"].is_open, "Neutraliser l’éclaireur libère le sas de Lina")
	await put_player(game.mechanic.global_position + Vector3(0, 0.045, -1.5))
	await tap(KEY_E)
	check(game.mechanic_rescued and not game.mechanic.visible, "Secourir Lina ouvre le suivi radio")

func verify_transport() -> void:
	game.start_transport()
	var patrol: Node3D = game.road_guards[ROUTES.PATROLS_PER_LEG]
	var site: Vector3 = patrol.get_meta("site")
	await put_player(site + Vector3(0, 0.045, 80))
	check(game.patrol_warning_given and patrol.process_mode == Node.PROCESS_MODE_DISABLED,
		"Lina prévient avant l’activation de la patrouille")
	game.world.transport.position = ROUTES.service_point() + Vector3.UP * 0.04
	player.mount(game.world.transport)
	await frames(3)
	player.health = 60
	var ammo: int = player.weapon.reserve_ammo
	await tap(KEY_E)
	check(game.service_used and player.health == player.max_health and player.weapon.reserve_ammo == ammo + 24,
		"À l’arrêt, le ravitaillement restaure la santé et les munitions")
	await tap(KEY_E)
	check(player.weapon.reserve_ammo == ammo + 24, "Le ravitaillement ne se répète pas")
	player.dismount(false)
	await frames(3)

func verify_copernic() -> void:
	game.step = CAMPAIGN.Step.CONTROL
	var director: Node3D = game.directors[2]
	director.process_mode = Node.PROCESS_MODE_INHERIT
	var repair: CharacterBody3D
	for actor in director.get_children():
		actor.attack_enabled = false
		actor.move_speed = 0.0
		if actor.drone_name == "DRONE DE MAINTENANCE":
			repair = actor
	var ally := director.get_child(0) as CharacterBody3D
	ally.global_position = WORLD.at(2, -4.8, 2.4, -10.0)
	repair.global_position = WORLD.at(2, -7.8, 2.4, -10.0)
	ally.health = ally.max_health - 2
	await put_player(WORLD.at(2, -31.5, 0.045, 40))
	await frames(45)
	check(ally.health > ally.max_health - 2, "Le robot de maintenance répare un allié visible")
	await tap(KEY_E)
	check(game.message_heard and game.film.current, "La console de l’observatoire lance le dernier message")
	check(game.world.sky_environment.environment.background_mode==Environment.BG_SKY and game.film.is_position_in_frustum(game.world.rocket.global_position + Vector3.UP * 7.0),
		"Le message cadre la fusée sous un ciel indépendant du terrain")
	if DisplayServer.get_name() != "headless":
		await capture("copernic_message.png")
	await frames(380)
	check(not game.transition and player.in_control and game.step == CAMPAIGN.Step.CONTROL,
		"L’alarme rend le contrôle et laisse la sortie jouable")
