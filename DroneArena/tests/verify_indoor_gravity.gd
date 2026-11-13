extends "res://tests/verify_lunar_escape.gd"

func run() -> void:
	teleport_escorts_for_test = false
	game = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(game); current_scene = game; player = game.pilot
	await frames(5)
	game.hud.title_card.hide(); game.hud.set_film(false)
	game.set_physics_process(false)
	for director in game.directors+game.upper_directors: director.process_mode = Node.PROCESS_MODE_DISABLED
	player.unlock_weapon("pistol"); player.set_control(true)
	for base in range(3):
		await verify_jump(WORLD.at(base,0,0.05,11),true,"Bâtiment %d"%(base+1))
	await verify_jump(WORLD.at(1,3,5.05,-2),true,"Étage de Tycho")
	await verify_jump(WORLD.at(0,-24.5,0.05,35),true,"Dôme de Karen")
	var lock = game.world.doors.habitat_entry.airlock
	lock.set_pressure(0)
	await verify_jump(Vector3(0,0.05,22),true,"Sas dépressurisé")
	check(not game.world.air_at(player.position),"La gravité du sas ne recharge pas l'air quand il est vide")
	lock.set_pressure(1)
	check(game.world.air_at(player.position),"Le sas pressurisé reste respirable")
	await verify_jump(WORLD.at(2,0,0.05,-35),true,"Couloir intérieur de lancement")
	await verify_jump(WORLD.at(2,30,WORLD.ROOF_HEIGHT+0.05,16),false,"Toit extérieur")
	await verify_jump(Vector3(80,game.world.surface_profile.elevation(80,-400)+0.1,-400),false,"Surface lunaire")
	# Re-entering a building in flight immediately changes acceleration, without
	# resetting velocity or adding a second jump.
	await put_player(WORLD.at(0,0,1.2,11))
	player.velocity = Vector3(0,2,0)
	await physics_frame; await physics_frame
	check(player.velocity.y<1.85 and player.velocity.y>1.5,"Entrer dans un bâtiment applique la gravité normale dès le vol en cours")
	await finish_run()

func verify_jump(point: Vector3, inside: bool, title: String) -> void:
	await put_player(point); await frames(30)
	check(player.is_on_floor(),title+" : départ au sol")
	check(is_equal_approx(player.movement_gravity().y,-9.81 if inside else -1.62),title+" : gravité adaptée")
	var bottom: float = player.position.y
	Input.action_press("jump"); await frames(2); Input.action_release("jump")
	var highest: float = player.position.y
	var duration := 2
	for i in range(360):
		await physics_frame; duration += 1
		highest = maxf(highest,player.position.y)
		if player.is_on_floor(): break
	var height := highest-bottom
	if inside:
		check(height>0.65 and height<1.0,title+" : saut normal inférieur à un mètre")
		check(duration<65,title+" : retour au sol en moins de 1,1 seconde")
	else:
		check(height>4.3 and height<5.6,title+" : grand saut lunaire conservé")
		check(duration>250 and player.is_on_floor(),title+" : flottement puis atterrissage")
