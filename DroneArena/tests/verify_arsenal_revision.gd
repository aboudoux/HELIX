extends "res://tests/verify_lunar_escape.gd"

func run() -> void:
	teleport_escorts_for_test=false
	game=load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(game);current_scene=game;player=game.pilot
	await frames(4);game.hud.title_card.hide();game.hud.set_film(false);game.camera.make_current()
	game.step=game.Step.CONTROL;game.set_physics_process(false)
	for director in game.directors+game.upper_directors: director.process_mode=Node.PROCESS_MODE_DISABLED
	player.unlock_weapon("pistol");player.set_control(true)
	for key in game.trials:
		var trial: Dictionary=game.trials[key]
		check(trial.enemies.size()>0 and trial.enemies.all(func(enemy): return is_instance_valid(enemy) and enemy.is_visible_in_tree()),key+" : ennemis déjà visibles avant l'entrée")
		var ids: Array=trial.enemies.map(func(enemy): return enemy.get_instance_id())
		var count: int=game.find_children("*","CharacterBody3D",true,false).size()
		game.begin_trial(key)
		check(count==game.find_children("*","CharacterBody3D",true,false).size() and ids==trial.enemies.map(func(enemy): return enemy.get_instance_id()),key+" : activation sans apparition ni remplacement")
		for enemy in trial.enemies: enemy.process_mode=Node.PROCESS_MODE_DISABLED
	for director in game.directors+game.upper_directors: director.process_mode=Node.PROCESS_MODE_DISABLED
	check(game.resident_spiders.size()==3 and game.resident_spiders.all(func(enemy): return enemy.visible),"Les trois araignées d'accueil existent avant le sas de Copernic")
	check(game.standby_guards.size()==2,"Les limiers du code sont prépositionnés dans leur salle")
	# The existing room has a reachable console; the dialogue really pauses the game.
	await put_player(game.equipment_room.terminal.global_position+Vector3(0,.05,1.8))
	check(game.nearest_interaction()=="equipment_room","E cible le terminal d'armurerie à portée")
	game.interact("equipment_room")
	check(paused and game.equipment_room.window.visible,"Le choix d'équipement met le combat en pause")
	game.equipment_room.main_choice.select(0);game.equipment_room.left_choice.select(3);game.equipment_room.armor_choice.select(2)
	game.equipment_room.equip_selected();await frames(3)
	var gear: Node=player.loadout
	check(not paused and player.in_control and gear.active and player.max_health==175,"Deux armes et armure Bastion sont équipées depuis le terminal")
	await put_player(WORLD.at(2,0,.05,14));aim_at(WORLD.at(2,0,1.4,-10))
	var primary: int=player.weapon.ammo;var secondary: int=gear.offhand.ammo
	Input.action_press("fire");await frames(2);Input.action_release("fire");await frames(2)
	check(player.weapon.ammo==primary-1 and gear.offhand.ammo==secondary,"Le clic gauche tire uniquement l'arme droite")
	Input.action_press("aim");await frames(2);Input.action_release("aim");await frames(2)
	check(gear.offhand.ammo<secondary and player.weapon.ammo==primary-1 and not player.weapon.is_aiming,"Le clic droit tire uniquement l'arme gauche sans déclencher la visée")
	gear.offhand.ammo=0;gear.offhand.reserve_ammo=3
	await tap(KEY_R);await frames(12)
	check(gear.offhand.is_reloading,"R recharge aussi la main gauche")
	var remaining: float=gear.offhand.reload_remaining
	paused=true;await frames(10);check(gear.offhand.reload_remaining==remaining,"La pause fige la recharge gauche");paused=false
	await frames(110)
	check(gear.offhand.ammo==3 and gear.offhand.reserve_ammo==0,"La recharge gauche respecte la réserve insuffisante")
	gear.configure("pistol","smg",2);await frames(3)
	check(gear.offhand.ammo==3 and gear.offhand.reserve_ammo==0,"Changer la sélection ne crée pas de munitions")
	var ammunition_save: Dictionary=gear.snapshot()
	gear.offhand.ammo=0;gear.restore(ammunition_save);await frames(2)
	check(gear.offhand.ammo==3,"Une reprise dans la même scène conserve les munitions sauvegardées")
	if DisplayServer.get_name()!="headless": await capture("arsenal_double_arme.png")
	gear.configure("sabre","shield",1);player.set_control(true);await frames(3)
	check(gear.melee_right.visible and not player.weapon.enabled,"Le sabre remplace réellement l'arme droite")
	Input.action_press("aim");await frames(2)
	check(player.shielding and player.shield_visual.visible,"Le clic droit lève le bouclier équipé dans la main gauche")
	if DisplayServer.get_name()!="headless": await capture("arsenal_sabre_bouclier.png")
	Input.action_release("aim");await frames(2)
	# Isolate a real robot in reach and verify that melee obeys world collision.
	var target: CharacterBody3D=game.add_enemy(2,Vector3(0,1.65,12.3),"CIBLE TEST")
	target.set_physics_process(false);target.max_health=30;target.health=30
	await put_player(WORLD.at(2,0,.05,14));aim_at(target.global_position)
	var hp: int=target.health;gear.strike("sabre")
	check(target.health==hp-3,"Le sabre touche un ennemi à courte portée")
	gear.configure("pistol","smg",1);player.set_control(true);await frames(3)
	hp=target.health;Input.action_press("aim");await frames(3);Input.action_release("aim");await frames(3)
	check(target.health<hp,"Le tir de la main gauche atteint réellement la cible")
	var wall:=WORLD.block(game.world,WORLD.at(2,0,1.1,13.2),Vector3(2,2.2,.2),WORLD.FRAME,true)
	await frames(2);hp=target.health;gear.strike("lance")
	check(target.health==hp,"Une lance ne traverse pas une cloison")
	wall.queue_free();target.queue_free();await frames(3)
	gear.configure("lance","sabre",0);player.set_control(true);await frames(3)
	check(gear.melee_right.visible and gear.melee_left.visible,"Une lance et un sabre peuvent être portés ensemble")
	var snapshot: Dictionary=gear.snapshot()
	check(game.saver.valid_loadout(snapshot) and not game.saver.valid_loadout({"active":true}),"La sauvegarde valide le nouvel équipement et refuse un état incomplet")
	gear.configure("pistol","none",0);gear.restore(snapshot);player.set_control(true)
	check(gear.right=="lance" and gear.left=="sabre","Les deux mains sont restaurées depuis la sauvegarde")
	if DisplayServer.get_name()!="headless":
		game.begin_film(WORLD.at(2,25,6.8,7.5),WORLD.at(2,30,6.4,7))
		await capture("arsenal_salle.png");game.end_film()
	# A dead quadruped must use its folded pose for resting collision.
	var robot: CharacterBody3D=game.add_enemy(1,Vector3(0,.045,14),"TEST ÉPAVE",true)
	robot.set_physics_process(false)
	await put_player(WORLD.at(1,0,.05,16))
	robot.receive_hit_at(robot.global_position+Vector3.UP,Vector3.UP,Vector3.FORWARD,1000)
	var wreck: RigidBody3D=robot.wreck
	await frames(600)
	var bottom:=INF
	for mesh in wreck.visual.find_children("*","MeshInstance3D",true,false):
		if not mesh.is_visible_in_tree(): continue
		for surface in range(mesh.mesh.get_surface_count()):
			for vertex in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]: bottom=minf(bottom,(mesh.global_transform*vertex).y)
	check(wreck.pose_ready and wreck.collision_mask==1,"La carcasse replie ses membres et ignore les collisions du joueur")
	check(bottom<.30 and bottom>-.18,"Le robot détruit repose au sol et ne flotte pas à hauteur d'arme : "+str(bottom))
	if DisplayServer.get_name()!="headless":
		game.begin_film(wreck.global_position+Vector3(2,1.3,2.3),wreck.global_position)
		await capture("robot_au_sol.png");game.end_film()
	# Full-height exterior walls physically stop a lunar jump.
	check(get_nodes_in_group("pressure_tower_walls").size()>30,"La tour possède des panneaux de pression continus")
	await put_player(WORLD.at(2,-7,.05,-36));player.rotation.y=-PI/2
	Input.action_press("jump");Input.action_press("move_forward");await frames(180)
	Input.action_release("jump");Input.action_release("move_forward")
	check(player.position.x<-3.4,"Le saut lunaire ne franchit pas le mur extérieur")
	game.saver.path="user://arsenal_revision_test.json";game.saver.enabled=true
	check(game.saver.write_save(game),"Le nouvel équipement est sauvegardé sur disque")
	var saved: Dictionary=game.saver.read_save()
	check(not saved.is_empty() and saved.loadout.right=="lance","La sauvegarde reste valide après conversion JSON")
	if not saved.is_empty():
		gear.configure("pistol","none",0)
		check(game.saver.restore(game,saved) and gear.right=="lance" and gear.left=="sabre","La reprise complète conserve les deux mains équipées")
	game.saver.clear();game.saver.enabled=false
	if DisplayServer.get_name()!="headless":
		game.begin_film(WORLD.at(2,-20,5,-68),WORLD.at(2,12,10,-37))
		await capture("tour_grands_murs.png")
	await finish_run()
