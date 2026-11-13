extends "res://tests/verify_lunar_escape.gd"

func run() -> void:
	teleport_escorts_for_test=false
	game=load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(game);current_scene=game;player=game.pilot
	await frames(5);game.hud.title_card.hide();game.hud.set_film(false);game.camera.make_current()
	game.step=game.Step.WORKSHOP;game.set_physics_process(false)
	for director in game.directors+game.upper_directors: director.process_mode=Node.PROCESS_MODE_DISABLED
	player.unlock_weapon("pistol");player.set_control(true)
	var polish: Node3D=game.get_node("CampaignPolish")
	for base in ["Selene","Tycho","Copernic"]:
		check(game.world.has_node(base+"/Chambre1/IdentiteBase"),"Décor différencié : "+base)
	check(polish.discoveries.size()==2,"Deux convois facultatifs placés sur les longues routes")
	var hp: int=player.health
	player.health=50;var ammo: int=player.weapon.reserve_ammo
	polish.claim(polish.discoveries[0]);polish.claim(polish.discoveries[0])
	check(player.health==75 and player.weapon.reserve_ammo==ammo+24,"Une caisse ne donne ses soins et munitions qu'une seule fois")
	var original_path: String=game.saver.path
	game.saver.path="user://verify_polish_save.json";game.saver.enabled=true
	check(game.saver.write_save(game),"La campagne enrichie produit une sauvegarde valide")
	var saved: Dictionary=game.saver.read_save()
	check(saved.get("road_caches")==[true,false],"La sauvegarde conserve les caisses déjà fouillées")
	game.saver.clear();game.saver.path=original_path;game.saver.enabled=false
	player.restore_health()
	await put_player(Vector3(0,.045,16.8))
	check(game.squad.clear_walk(Vector3(0,.045,17),Vector3(0,.045,10)),"Les couvertures laissent le couloir central praticable")
	if DisplayServer.get_name()!="headless":
		game.begin_film(Vector3(10,2.5,17),Vector3(-3,1.3,11));await capture("karen_couloir_tactique.png")
		var room: Node3D=game.world.get_node("Selene/Chambre1")
		game.begin_film(room.global_position+Vector3(7,2.5,4.7),room.global_position+Vector3(1.5,1.1,1.5));await capture("karen_quartiers_habites.png")
		game.end_film();game.camera.make_current()
	WORLD.block(game.world,Vector3(180,9.8,100),Vector3(80,.4,70),WORLD.FLOOR,true)
	await put_player(Vector3(180,10.045,110))
	var target: CharacterBody3D=game.add_enemy(0,Vector3(180,12.3,95),"CIBLE PRÉCISE")
	target.set_physics_process(false);target.health=20;target.max_health=20
	var weak: Node3D=target.get_meta("weak_point")
	target.charge_remaining=.5
	target.receive_hit_at(weak.global_position,Vector3.UP,Vector3.BACK)
	check(target.health==18 and target.charge_remaining==0 and target.cooldown>=.65,"Un point faible double les dégâts et interrompt le tir")
	target.receive_hit_at(target.global_position+Vector3.RIGHT,Vector3.UP,Vector3.BACK)
	check(target.health==17,"Un tir ordinaire conserve ses dégâts normaux")
	var bastion: CharacterBody3D
	for actor in game.find_children("*","CharacterBody3D",true,false):
		if actor.get_meta("combat_role","")=="bastion": bastion=actor;break
	check(bastion!=null,"Les robots lourds protecteurs sont présents dès le chargement")
	if bastion!=null:
		bastion.global_position=Vector3(180,10.045,100);bastion.set_physics_process(false)
		var health: int=bastion.health
		var front: Vector3=bastion.global_position-bastion.global_basis.z+Vector3.UP
		for i in range(3): bastion.receive_hit_at(front,Vector3.FORWARD,bastion.global_basis.z)
		check(bastion.health==health and bastion.get_meta("armor_left")==0,"Trois impacts brisent le blindage avant sans retirer de vie")
		check(not bastion.get_meta("armor_visual").visible,"Le blindage détruit disparaît et laisse des débris")
		bastion.receive_hit_at(front,Vector3.FORWARD,bastion.global_basis.z)
		check(bastion.health==health-1,"La cible devient vulnérable après rupture du blindage")
		bastion.reset_drone();check(bastion.get_meta("armor_left")==3,"Le checkpoint restaure le blindage")
		bastion.global_position=Vector3(210,10.045,80)
	game.squad.recruit(0);var ally: CharacterBody3D=game.squad.members[0]
	ally.reset_at(Vector3(178,10.045,107));await frames(4)
	target.process_mode=Node.PROCESS_MODE_ALWAYS;target.set_physics_process(true);target.attack_enabled=false;target.move_speed=0
	player.head.look_at(target.global_position)
	var order:=InputEventKey.new();order.keycode=KEY_T;order.pressed=true
	game.squad.commands._unhandled_input(order)
	check(game.squad.commands.focus==target,"T désigne réellement l'ennemi visé")
	await frames(4)
	check(ally.target==target,"L'allié donne la priorité à la cible visible désignée")
	target.queue_free();game.squad.commands.focus=null;player.head.rotation=Vector3.ZERO
	game.squad.commands.take_cover();var anchor: Vector3=ally.global_position
	await put_player(Vector3(180,10.045,123));await frames(90)
	check(ally.global_position.distance_to(anchor)<1.5,"L'ordre à couvert maintient un allié sur place si aucun abri n'est proche")
	game.squad.commands.follow();await frames(180)
	check(ally.global_position.z>115,"L'ordre de suivi fait rejoindre le joueur")
	ally.reset_at(player.global_position+Vector3.LEFT*1.7);ally.hurt_left=0
	ally.apply_damage(1000);check(ally.downed and not game.defeated and ally.collision_layer==0,"Un allié au sol laisse une chance de secours sans bloquer le passage")
	check(not game.squad.can_board(),"Impossible d'abandonner un blessé en montant dans un véhicule")
	var countdown: float=ally.bleed_left
	paused=true;await frames(20);paused=false
	check(is_equal_approx(countdown,ally.bleed_left),"La pause fige le délai de secours")
	var key:=InputEventKey.new();key.keycode=KEY_G;key.physical_keycode=KEY_G;key.pressed=true;Input.parse_input_event(key)
	await frames(145);key=key.duplicate();key.pressed=false;Input.parse_input_event(key)
	check(not ally.downed and ally.health>=56 and ally.revives_left==0,"Maintenir G près du blessé le relève avec 40 % de vie")
	check(not ally.apply_damage(20),"La brève protection laisse le temps à l'allié de se relever")
	check(ally.collision_layer==16 and ally.alive,"Le compagnon secouru retrouve son rôle physique")
	ally.set_physics_process(false)
	# Boss armor forces timing and target choice.
	var boss: Node3D=game.mothership;boss.active=true;boss.set_physics_process(false)
	boss.guard_director.process_mode=Node.PROCESS_MODE_DISABLED
	boss.set_core_exposed(false);var boss_hp: int=boss.health
	boss.receive_hit_at(boss.visual.to_global(Vector3(0,1,0)),Vector3.UP,Vector3.DOWN)
	check(boss.health==boss_hp,"Le blindage fermé du boss bloque les tirs sur la coque")
	boss.set_core_exposed(true)
	boss.receive_hit_at(boss.visual.to_global(Vector3(0,-1,0)),Vector3.UP,Vector3.DOWN)
	check(boss.health==boss_hp-4,"Le réacteur exposé reçoit quatre fois les dégâts")
	check(boss.tactical_status().contains("PHASE"),"Le HUD explique la phase et la vulnérabilité du boss")
	boss.active=false
	ally.set_physics_process(true);ally.reset_at(player.global_position+Vector3.LEFT*1.5)
	ally.apply_damage(1000);ally.bleed_left=.01;await frames(3)
	check(game.defeated and not ally.alive,"Sans secours avant la fin du délai, la mission échoue")
	await finish_run()
