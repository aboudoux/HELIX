extends "res://tests/verify_lunar_escape.gd"
const SITES := preload("res://missions/lunar_escape/bunker_sites.gd")

func run() -> void:
	if DisplayServer.get_name()!="headless": RenderingServer.render_loop_enabled=false
	teleport_escorts_for_test=false
	game=load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(game);current_scene=game;player=game.pilot
	await frames(5);game.hud.title_card.hide();game.hud.set_film(false);game.camera.make_current()
	game.step=game.Step.BIKE;game.set_physics_process(false)
	for director in game.directors+game.upper_directors+game.road_guards: director.process_mode=Node.PROCESS_MODE_DISABLED
	for actor in game.squad.members: actor.set_physics_process(false)
	player.unlock_weapon("pistol");player.set_control(true)
	var bunkers: Node=game.get_node("SecretBunkers")
	check(bunkers.entries.size()==3,"Trois bunkers facultatifs construits au chargement")
	var stage: int=game.step;var clearance: Array=game.clearance.duplicate()
	for i in range(3):
		var entry: Dictionary=bunkers.entries[i]
		var point: Vector3=SITES.POINTS[i]
		entry.guard.attack_enabled=false
		check(entry.guard.alive and entry.guard.health==[18,30,44][i] and not entry.discovered,"Gardien %d présent et coffre encore secret"%i)
		check(not bunkers.claim(i),"Coffre %d inaccessible avant la victoire"%i)
		await put_player(point+Vector3(0,2.3,27));player.rotation.y=0
		Input.action_press("move_forward");await frames(120);Input.action_release("move_forward");await frames(6)
		check(player.position.z<point.z+18 and player.position.y<-.8,"Rampe %d réellement descendue à pied sans traverser le sol"%i)
		check(entry.discovered,"L'entrée %d est découverte sur place"%i)
		var inside: Node3D=game.world.doors["bunker_%d"%i]
		var outside: Node3D=game.world.doors["bunker_%d_outer"%i]
		check(inside.airlock==outside.airlock and not inside.airlock.can_open(outside),"Sas %d : porte externe bloquée tant que pressurisé"%i)
		if i==0:
			await inside.airlock.operate(outside)
			await walk_to(Vector2(point.x,point.z+10),240)
			check(inside.airlock.contains(player.position),"Le joueur franchit réellement la porte extérieure du bunker")
			await inside.airlock.operate(outside)
			await inside.airlock.operate(inside)
			await walk_to(Vector2(point.x,point.z+5),180)
			check(player.position.z<point.z+6 and not outside.is_open and inside.is_open,"Le cycle du sas permet de rejoindre la salle sans téléportation")
		else: await put_player(point+Vector3(0,.05,5))
		await frames(3)
		var berm: MeshInstance3D=entry.root.get_node("RemblaiLunaire")
		var normals: PackedVector3Array=berm.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
		check(normals[0].y>0,"Le relief qui recouvre le bunker %d est visible par le dessus"%i)
		check(game.world.air_at(player.position) and game.world.movement_gravity(player.position).y< -9,"Bunker %d pressurisé et gravité intérieure"%i)
		var guard: CharacterBody3D=entry.guard
		await frames(8)
		if i>0:
			var hp: int=guard.health
			aim_at(guard.global_position)
			Input.action_press("fire");await frames(2);Input.action_release("fire");await frames(3)
			check(guard.health<=hp-2,"Un vrai tir de l'arme rare inflige des dégâts renforcés au gardien")
		check(entry.director.navigation_ready and entry.director.flight_path(guard.position,point+Vector3(-2,1.95,0)).size()>0,"Navigation physique du gardien %d disponible"%i)
		var roof:=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3(0,2,0),point+Vector3(0,6,0),1))
		check(not roof.is_empty() and roof.position.y>point.y+3.3,"Toit fermé du bunker %d et aucun terrain dans la salle"%i)
		if i==0 and DisplayServer.get_name()!="headless":
			aim_at(guard.global_position);await capture("bunker_helios_gardien.png")
			await put_player(point+Vector3(8,5,24));aim_at(point+Vector3(0,1,5));await capture("bunker_helios_entree.png")
		guard.receive_hit_at(guard.global_position,Vector3.UP,Vector3.FORWARD,1000000)
		await frames(40)
		check(entry.defeated and not guard.alive and entry.prize.visible,"Gardien %d vaincu : ouverture animée du coffre"%i)
		await put_player(point+Vector3(-2,.06,-3.6))
		await tap(KEY_E)
		check(entry.claimed,"E récupère réellement l'arme et l'armure %d à portée"%i)
		await frames(3)
		check(player.weapon.damage_per_hit==2 and player.equipped==SITES.WEAPONS[i],"Arme Mk II %d : dégâts réellement doublés"%i)
		check(not bunkers.claim(i),"Coffre %d à usage unique"%i)
		check(player.get_meta("bunker_armor")==i+1 and player.max_health>=100+25*(i+1),"Armure %d renforce réellement la protection"%i)
	check(game.step==stage and game.clearance==clearance,"Les bunkers ne modifient aucun verrou ou objectif principal")
	player.health=player.max_health;player.hurt_cooldown=0
	var before: int=player.health;player.apply_damage(100)
	check(before-player.health==65,"La meilleure armure absorbe 35 % des dégâts")
	var snapshot: Array=bunkers.snapshot()
	check(bunkers.valid_snapshot(snapshot) and not bunkers.valid_snapshot([{}]),"Validation stricte des données de sauvegarde des bunkers")
	bunkers.restore(snapshot);await frames(3)
	check(bunkers.entries.all(func(e):return e.claimed and not e.guard.alive) and player.weapon.damage_per_hit==2,"Restauration : gardiens vaincus, coffres vidés et améliorations conservés")
	player.loadout.unlocked=true;player.loadout.configure("pistol","pistol",0);await frames(20)
	var gear: Node=player.loadout
	check(gear.offhand.damage_per_hit==2 and player.weapon.damage_per_hit==2,"La version améliorée fonctionne dans les deux mains")
	player.weapon.ammo=5;gear.offhand.ammo=0;gear.offhand.reserve_ammo=3
	await tap(KEY_R);await frames(18)
	check(gear.offhand.is_reloading and not player.weapon.is_reloading and player.gun_visual.stow_weight>.95,"La main droite s'abaisse avant le rechargement de la main gauche")
	check(gear.left_visual.support.visible,"La main libérée accompagne le chargeur gauche")
	var remaining: float=gear.offhand.reload_remaining
	paused=true;await frames(8);check(is_equal_approx(remaining,gear.offhand.reload_remaining),"La pause fige le geste et le transfert de munitions");paused=false
	if DisplayServer.get_name()!="headless": await capture("main_gauche_recharge_articulee.png")
	await frames(155)
	check(gear.offhand.ammo==3 and gear.offhand.reserve_ammo==0 and player.weapon.ammo==12,"Recharge successive des deux armes sans créer de munitions")
	check(not player.weapon.hand_busy and not gear.offhand.hand_busy and not gear.left_visual.support.visible,"Après recharge, deux mains seulement et tirs réactivés")
	var sleeve: Node3D=gear.left_visual.grip.get_meta("sleeve")
	var elbow:=sleeve.to_global(Vector3.UP*sleeve.mesh.height*.5)
	check(elbow.distance_to(game.camera.to_global(Vector3(-.43,-.57,-.02)))<.01,"Le bras gauche rejoint le coude même avec une arme miroir")
	gear.offhand.ammo=0;gear.offhand.reserve_ammo=12
	await tap(KEY_R);await frames(18);player.equip("smg");await frames(3)
	check(not gear.offhand.is_reloading and gear.offhand.ammo==0 and gear.offhand.reserve_ammo==12,"Changer d'arme annule le geste sans transférer les cartouches")
	game.saver.enabled=true;game.saver.path="user://bunker_test_only.json"
	check(game.saver.write_save(game),"Écriture d'une vraie sauvegarde comprenant les bunkers")
	var saved: Dictionary=game.saver.read_save()
	check(saved.get("bunkers",[])==snapshot,"Les trois récompenses sont enregistrées dans le fichier")
	game.saver.enabled=false
	finish_run()

func capture(filename: String) -> void:
	RenderingServer.render_loop_enabled=true
	await frames(2);await RenderingServer.frame_post_draw
	var folder:=ProjectSettings.globalize_path("res://tests/artifacts")
	DirAccess.make_dir_recursive_absolute(folder)
	check(root.get_texture().get_image().save_png(folder+"/"+filename)==OK,"Capture : "+filename)
	RenderingServer.render_loop_enabled=false
