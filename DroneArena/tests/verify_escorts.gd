extends "res://tests/verify_lunar_escape.gd"

func run() -> void:
	teleport_escorts_for_test = false
	game = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(game); current_scene = game; player = game.pilot
	await frames(4)
	game.hud.title_card.hide(); game.hud.set_film(false); game.camera.make_current()
	game.step = game.Step.WORKSHOP
	player.unlock_weapon("pistol"); player.set_control(true)
	game.set_physics_process(false)
	for director in game.directors+game.upper_directors: director.process_mode = Node.PROCESS_MODE_DISABLED
	check(game.squad.members.size()==3,"Les trois survivants possèdent un corps et une IA indépendante")
	var mael: CharacterBody3D = game.squad.members[0]
	var noor: CharacterBody3D = game.squad.members[1]
	check(mael.avatar.ceramic.shader.resource_path.ends_with("escort_suit.gdshader") and mael.avatar.limbs.size()==4,"Combinaisons EVA détaillées et membres articulés")
	await put_player(game.story.stations.survivors.marker.global_position+Vector3(0,-1.28,-1))
	game.story.interact("survivors")
	if paused: game.base_life.close_journal()
	check(mael.recruited and noor.recruited,"Lire le registre recrute réellement Maël et Noor")
	var initial: float = mael.global_position.distance_to(player.global_position)
	await frames(330)
	check(mael.global_position.distance_to(player.global_position)<initial-3,"Les survivants rejoignent le joueur entre les meubles de l'abri")
	var door: Node3D = game.world.doors.room_1_0_2
	door.unlock()
	await put_player(Vector3(-10,0.045,door.global_position.z))
	await frames(420)
	check(door.is_open and mael.global_position.x>-17,"L'escouade ouvre un sas autorisé et le traverse physiquement")
	await capture_escort("escorts_follow.png")
	# Stairs connect the ground and upper navigation graphs.
	game.world.doors.stair_down_1.unlock(); game.world.doors.stair_up_1.unlock()
	mael.reset_at(WORLD.at(1,39,0.045,6)); noor.reset_at(WORLD.at(1,40,0.045,7))
	await put_player(WORLD.at(1,39,5.045,-15))
	await frames(500)
	check(mael.global_position.y>4.7,"Un compagnon monte réellement l'escalier pour suivre le joueur")
	await put_player(WORLD.at(1,39,0.045,5.2))
	await frames(500)
	check(mael.global_position.y<0.5,"Un compagnon redescend l'escalier")
	var depot: Node3D = game.world.doors.room_1_1_2
	depot.unlock(); depot.open(); await frames(50)
	await put_player(depot.global_position+Vector3(-1.6,0.045,0))
	game.squad.relocate()
	await frames(200)
	game.garage_alarm = true
	await game.use_door("room_1_1_2")
	await frames(50)
	check(not depot.is_open,"Les alliés dégagent le sas et le laissent se refermer")
	# Actual allied projectiles, enemy target selection and blocked lines of fire.
	await put_player(WORLD.at(1,7,0.045,-30))
	mael.reset_at(WORLD.at(1,1,0.045,-30)); noor.reset_at(WORLD.at(1,4,0.045,-29))
	game.directors[1].process_mode = Node.PROCESS_MODE_INHERIT
	for enemy in game.directors[1].get_children(): enemy.set_physics_process(false)
	var drone: CharacterBody3D = game.add_enemy(1,Vector3(1,2.4,-38),"CIBLE ESCOUADE")
	drone.move_speed = 0; drone.attack_enabled = false; drone.health = 12; drone.max_health = 12
	game.squad.update_enemies()
	await frames(3)
	check(drone.max_health==17 and drone.fire_interval<1.9,"Les ennemis sont renforcés après le recrutement")
	check(game.squad.pick_target(drone,player)==mael,"Un ennemi peut choisir un compagnon visible comme cible")
	var wall := WORLD.block(game.world,WORLD.at(1,1,1.7,-34),Vector3(8,3.4,0.3),WORLD.STEEL,true)
	await frames(120)
	check(game.squad.confirmed_hits==0,"Les alliés ne tirent pas à travers les murs")
	wall.queue_free(); await frames(4)
	await frames(1100)
	check(game.squad.confirmed_hits>0 and drone.health==0,"Les tirs physiques des compagnons peuvent éliminer un monstre")
	check(mael.shots_fired>6 or noor.shots_fired>6,"L'escouade recharge et continue à combattre")
	var bolt = preload("res://scenes/enemy_bolt.tscn").instantiate()
	game.get_node("Projectiles").add_child(bolt)
	var before: int = mael.health
	bolt.launch(mael.get_aim_point()+Vector3(0,0,-3),Vector3.BACK,RID())
	await frames(30)
	check(mael.health<before,"Un projectile ennemi touche réellement la capsule d'un allié")
	# A vehicle waits for the group, carries them, and returns them on foot.
	await put_player(WORLD.at(1,2.5,0.045,-26))
	mael.reset_at(WORLD.at(1,40,0.045,10))
	check(not game.squad.can_board(),"Le blindé refuse d'abandonner un compagnon éloigné")
	game.squad.relocate()
	mael.health = 96
	player.mount(game.world.transport)
	await frames(4)
	check(mael.embarked and not mael.visible and mael.collision_layer==0,"Les compagnons embarquent dans le blindé")
	player.dismount(false); await frames(4)
	check(not mael.embarked and mael.visible and mael.collision_layer==16,"Les compagnons débarquent et retrouvent leurs collisions")
	check(mael.health==96,"Le véhicule ne soigne pas gratuitement les passagers")
	# Pause freezes both AI and health. Fatal ally damage fails the entire mission.
	var pos: Vector3 = mael.global_position
	before = mael.health
	paused = true; mael.apply_damage(20); await frames(20)
	check(mael.health==before and mael.global_position==pos,"La pause fige l'IA et les dégâts alliés")
	paused = false; await frames(20)
	mael.apply_damage(1000)
	check(mael.downed and not game.defeated,"Un compagnon peut être secouru avant sa mort")
	mael.bleed_left = .01; await frames(2)
	check(game.defeated and paused and game.hud.card_title.text.contains("MAËL"),"La mort d'un compagnon fait perdre la mission")
	game.respawn(); await frames(6)
	check(not game.defeated and mael.alive and mael.health==mael.max_health and mael.recruited,"Le checkpoint restaure l'équipe recrutée")
	game.story.flags.survivors = true; game.mechanic_rescued = true
	game.squad.restore_members()
	check(game.squad.members.all(func(actor): return actor.recruited),"Lina rejoint également le combat et le suivi")
	# Boss attacks affect teammates, while its telegraphs give them time to evade.
	game.ship_reveal()
	await frames(450)
	game.mothership.set_physics_process(false)
	game.mothership.guard_director.process_mode = Node.PROCESS_MODE_DISABLED
	for actor in game.squad.members: actor.attack_clock = 1000
	check(game.mothership.max_health==504 and game.mothership.subsystem_hp==[16,16],"Le boss et ses nacelles sont renforcés pour l'escouade")
	before = mael.health
	game.mothership.strike_radius = 2.4
	game.mothership.strike_sites.assign([mael.global_position+Vector3.UP*0.05])
	game.mothership.fire_barrage()
	check(mael.health<before,"Le bombardement du boss peut blesser un compagnon")
	mael.hurt_left = 0
	game.mothership.wave_origin = mael.global_position+Vector3.LEFT*2
	game.mothership.wave_radius = 1.6
	game.mothership.wave_active = true
	before = mael.health
	game.mothership.advance_wave(0.033)
	check(mael.health<before,"L'onde au sol touche aussi l'escouade")
	before = mael.health; mael.hurt_left = 0
	game.mothership.advance_wave(0)
	check(mael.health==before,"Une même onde ne frappe chaque compagnon qu'une fois")
	game.mothership.wave_radius = 0.5
	await frames(2)
	check(mael.velocity.y>0,"Les compagnons sautent à l'approche d'une onde annoncée")
	# Exercise the full evasion against an advancing wave under lunar gravity.
	game.mothership.wave_active = false
	await frames(330)
	mael.hurt_left = 0
	game.mothership.escort_wave_hits.clear()
	game.mothership.wave_origin = mael.global_position+Vector3.LEFT*5.4
	game.mothership.wave_radius = 0.5
	game.mothership.wave_active = true
	before = mael.health
	for i in range(35):
		await physics_frame
		game.mothership.advance_wave(1.0/60)
	check(mael.health==before and mael.position.y>WORLD.ROOF_HEIGHT+0.75,"Le saut lunaire du compagnon évite réellement l'onde en mouvement")
	game.mothership.strike_marks[0].global_position = mael.global_position
	game.mothership.strike_marks[0].show()
	check(game.squad.avoid_blast(mael).length()>0.9,"Les zones de bombardement déclenchent une esquive")
	game.mothership.active = false
	game.mothership.wave_active = false
	for marker in game.mothership.strike_marks: marker.hide()
	game.story.preparation = 35
	game.on_ship_destroyed()
	await put_player(WORLD.pad(0,0.045,-243))
	await frames(500)
	check(game.squad.can_board(),"L'escouade rejoint réellement la fusée après la levée du champ de force")
	game.launch()
	await frames(2400)
	check(game.step==game.Step.COMPLETE and game.squad.members.all(func(actor): return actor.alive and not actor.visible),"Toute l'équipe embarque et revient vivante sur Terre")
	game.squad.relocate()
	player.set_control(false)
	for actor in game.squad.members:
		actor.global_position = Vector3(-2+actor.slot*2,0.04,35)
		actor.rotation.y = PI
		actor.avatar.animate_escort(actor,0.016,actor.get_aim_point()+Vector3.BACK*10,0,false)
	game.film.make_current()
	game.frame_camera(Vector3(-3.3,1.7,39.6),Vector3(-0.6,1.1,35))
	await capture_escort("escorts_suit.png")
	await finish_run()

func capture_escort(file: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/artifacts/"+file)
