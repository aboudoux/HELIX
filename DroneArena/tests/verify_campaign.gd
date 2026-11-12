extends "res://tests/verify_mission.gd"
## La suite historique couvre le quai. Celle-ci parcourt le nouvel étage et sa fin.

func upper_grid() -> void:
	walking_grid.region = game.upper_director.bounds
	walking_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	walking_grid.update()
	var shape := BoxShape3D.new()
	shape.size = Vector3(.88,1.65,.88)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 1
	var space := game.get_world_3d().direct_space_state
	for x in range(walking_grid.region.position.x,walking_grid.region.end.x):
		for z in range(walking_grid.region.position.y,walking_grid.region.end.y):
			var inside := false
			for r in game.upper_layout.floors:
				inside = inside or Rect2(r[0],r[1],r[2],r[3]).has_point(Vector2(x,z))
			query.transform = Transform3D(Basis.IDENTITY,Vector3(x,14.95,z))
			var ray := PhysicsRayQueryParameters3D.create(Vector3(x,14.12,z),Vector3(x,13.6,z),1)
			walking_grid.set_point_solid(Vector2i(x,z),not inside or not space.intersect_shape(query,1).is_empty() or space.intersect_ray(ray).is_empty())


func run() -> void:
	game = load("res://missions/relay_run/mission.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	player = game.player
	director = game.director
	graphics = DisplayServer.get_name()!="headless"
	await frames(8)
	await snap("campaign_accueil.png")
	var card: Control = game.get_node("Interface/Overlay/Card")
	check(card.get_viewport_rect().encloses(card.get_global_rect()),"Le menu de campagne reste entièrement visible")
	check(game.hostile_total()==27 and game.upper_director.get_child_count()==10,"25 gardes et deux boss dans la campagne")
	check(not game.alpha.alive and not game.lift.unlocked,"FENRIR et l'ascenseur attendent CERBÈRE")
	check(not game.lift.request_ride(player) and not game.activate_upper_relay(),"Aucun raccourci depuis le menu")
	for level in range(3):
		game.alpha.configure_difficulty(difficulty.PROFILES[level])
		check(game.alpha.health==[60,85,115][level] and game.alpha.charge_duration>=1.25,"FENRIR respecte la difficulté et le délai d'esquive")
	game.apply_difficulty()
	game.start_exploration()
	for actor in get_nodes_in_group("enemies"): actor.attack_enabled = false
	await put_player(Vector3(0,.05,-90))
	check(not game.lift.request_ride(player),"L'ascenseur ne part pas avant la mort de CERBÈRE")
	# Valider la même séquence de relais que dans le parcours physique du premier niveau.
	for sector in range(3):
		director.engage_sector(sector)
		for actor in director.get_children():
			if actor.alive:
				while actor.alive: actor.receive_hit()
		await put_player(game.relays[sector].global_position+Vector3(0,.05,2))
		check(game.activate_relay(),"Relais du premier niveau %d" % sector)
		await frames(80)
	while game.boss.alive: game.boss.receive_hit()
	await frames(85)
	check(game.stage==4 and game.lift.unlocked and not game.alpha.alive,"CERBÈRE ouvre uniquement l'accès à l'ascenseur")
	await put_player(Vector3(0,.05,-85))
	check(not game.lift.request_ride(player),"Il faut entrer entièrement dans la cabine")
	Input.action_press("move_forward")
	player.rotation.y = 0
	await frames(42)
	Input.action_release("move_forward")
	await frames(10)
	check(game.lift.contains_player(player),"Entrée physique dans la cabine par la porte ouverte")
	await snap("campaign_lift_boarding.png")
	await tap(KEY_E)
	check(game.lift.state=="closing","E commande la fermeture avant la montée")
	await frames(180)
	var height: float = player.position.y
	check(height>1 and height<13 and game.lift.state=="rising","Le plancher physique porte le joueur à mi-parcours")
	game.show_pause()
	var cab_height: float = game.lift.cab.position.y
	await frames(60)
	check(player.position.y==height and game.lift.cab.position.y==cab_height,"La pause fige cabine et passager")
	check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"La souris reste récupérable dans l'ascenseur")
	game.start_exploration()
	await frames(470)
	check(game.stage==5 and game.lift.state=="arrived" and absf(player.position.y-14)<.15,"Arrivée réelle au deuxième étage sans déplacer le joueur par script")
	check(game.lift.get_node("Cab/NorthBlock").disabled and not game.lift.get_node("Cab/SouthBlock").disabled,"Une seule porte s'ouvre vers le palier supérieur")
	check(player.health==100 and game.upper_director.current_sector==-1,"Arrivée soignée et palier sans attaque immédiate")
	await snap("campaign_lift_arrived.png")
	Input.action_press("move_forward")
	await frames(100)
	Input.action_release("move_forward")
	await frames(10)
	check(player.position.z<-98 and player.is_on_floor() and player.position.y>13.9,"Sortie physique de la cabine sur le nouveau plancher")
	check(not game.lift.request_ride(player),"La cabine arrivée ne redémarre pas")
	await put_player(Vector3(0,14.05,-112))
	await frames(15)
	check(game.upper_director.remaining(0)==5 and not game.upper_gates[0].unlocked,"Cinq gardes protègent le premier verrou")
	var dog: CharacterBody3D = game.upper_director.get_child(3)
	var drone: CharacterBody3D = game.upper_director.get_child(0)
	var dog_start := dog.position
	var drone_start := drone.position
	await frames(150)
	check(dog.position.distance_to(dog_start)>1 and absf(dog.position.y-14)<.1,"Le limier poursuit au sol sur le bon étage")
	check(drone.position.distance_to(drone_start)>1 and absf(drone.position.y-16.4)<.1,"La sentinelle vole au-dessus du deuxième plancher")
	check(not game.activate_upper_relay(),"Une console ne s'active pas à distance")
	await put_player(Vector3(-26,14.05,-130))
	check(not game.activate_upper_relay(),"Les gardes vivants verrouillent leur console")
	# Parcours complet des deux secteurs avec le même contrôleur que le joueur.
	for sector in range(2):
		if sector==1:
			upper_grid()
			check(await walk_to(Vector2(0,-147)),"Passage physique de la porte vers l'usine")
			await frames(10)
		check(game.upper_director.current_sector==sector and game.upper_director.remaining(sector)==5,"Activation des cinq gardes du secteur supérieur %d" % sector)
		for actor in game.upper_director.get_children():
			if actor.alive:
				while actor.alive: actor.receive_hit()
		await frames(160)
		upper_grid()
		if sector==0:
			await put_player(Vector3(0,14.05,-112))
			check(await walk_to(Vector2(-26,-130)),"Parcours physique du chenil vers la première console")
		else:
			check(await walk_to(Vector2(32,-162)),"Parcours physique de l'usine vers la seconde console")
		await aim_at(game.upper_relays[sector].global_position+Vector3.UP)
		await snap("campaign_sector_%d.png" % sector)
		player.health = 45
		await tap(KEY_E)
		await frames(85)
		check(game.stage==sector+6 and game.upper_gates[sector].fully_open and player.health==100,"La console lève le verrou et restaure la santé")
	check(game.alpha.alive and game.stage==7 and not game.upper_gates[2].unlocked,"Le second verrou réveille FENRIR et garde l'extraction fermée")
	upper_grid()
	check(await walk_to(Vector2(0,-185)),"Entrée physique dans l'antre de FENRIR")
	var alpha: CharacterBody3D = game.alpha
	alpha.activate()
	alpha.attack_enabled = false
	await put_player(Vector3(0,14.05,-185))
	await frames(20)
	var before := alpha.position
	await frames(120)
	check(alpha.position.distance_to(before)>1 and absf(alpha.position.y-14)<.1,"Le boss quadrupède se déplace sur son plancher")
	check(alpha.hips.size()==4 and is_instance_valid(alpha.right_muzzle) and alpha.hit_shape.shape.radius>4,"FENRIR possède son grand GLB articulé et deux sorties de canon")
	alpha.activate()
	alpha.move_speed = 0
	alpha.attack_enabled = true
	await put_player(Vector3(0,14.05,-185))
	await aim_at(alpha.position+Vector3.UP*2.45)
	await frames(10)
	alpha.cooldown = 0
	await frames(6)
	check(alpha.charge_remaining>0 and alpha.shots_fired==0,"FENRIR annonce sa rafale avant de tirer")
	var aim: Vector3 = alpha.locked_aim
	await snap("campaign_fenrir.png")
	await frames(190)
	check(alpha.shots_fired==4 and player.health<100 and player.health>0,"Les deux canons infligent de vrais dégâts avec une rafale survivable")
	check(alpha.locked_aim==aim,"La visée du boss reste figée pour permettre l'esquive")
	alpha.attack_enabled = false
	player.restore_health()
	await frames(20)
	await aim_at(alpha.position+Vector3.UP*2.45)
	var hp: int = alpha.health
	mouse_button(true)
	await frames(2)
	mouse_button(false)
	await frames(16)
	check(alpha.health==hp-1,"Le fusil actuel touche le nouveau boss")
	while alpha.health>alpha.max_health/2: alpha.receive_hit()
	await frames(3)
	check(alpha.phase==2 and game.hud.get_node("Boss/Content/Phase").text.contains("RAGE"),"Mi-vie : la jauge annonce la rage de FENRIR")
	alpha.move_speed = 0
	alpha.attack_enabled = true
	alpha.cooldown = 0
	await frames(6)
	var shot_count: int = alpha.shots_fired
	Input.action_press("move_right")
	await frames(65)
	Input.action_release("move_right")
	await frames(125)
	check(alpha.shots_fired-shot_count==6 and player.health==100,"La rage tire six lasers et un déplacement latéral les esquive")
	alpha.attack_enabled = false
	while alpha.alive: alpha.receive_hit()
	await frames(180)
	check(game.stage==8 and game.upper_gates[2].fully_open and game.drones_destroyed==27,"Vaincre les deux boss ouvre l'extraction finale : 27 hostiles")
	check(is_instance_valid(alpha.wreck) and alpha.wreck.mass==650 and game.get_node("Wrecks").get_child_count()==27,"FENRIR s'effondre et les 27 carcasses restent dans la mission")
	upper_grid()
	check(await walk_to(Vector2(0,-229)),"Accès physique à l'extraction orbitale après le boss")
	await frames(140)
	check(game.mission_complete and paused and game.title.text=="Mission accomplie.","Victoire après les deux niveaux et les deux gardiens")
	await snap("campaign_victory.png")
	game.restart_exploration()
	await frames(15)
	check(game.stage==0 and player.position.y<.1 and player.health==100 and player.weapon.ammo==30,"Rejouer remet le joueur, la vie et l'arme au quai")
	check(not game.alpha.alive and not game.lift.unlocked and game.lift.cab.position.y==0,"Rejouer restaure FENRIR dormant et la cabine au premier étage")
	check(game.upper_director.current_sector==-1 and not game.upper_gates[0].fully_open and game.get_node("Wrecks").get_child_count()==0,"Rejouer nettoie les épaves et réarme les secteurs supérieurs")
	await finish_mission_test()
