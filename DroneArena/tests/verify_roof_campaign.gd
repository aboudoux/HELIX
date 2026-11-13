extends "res://tests/verify_lunar_escape.gd"
const CODES := preload("res://missions/lunar_escape/access_codes.gd")

func run() -> void:
	teleport_escorts_for_test = false
	game = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(game); current_scene = game; player = game.pilot
	await frames(5)
	game.hud.title_card.hide(); game.hud.set_film(false); game.camera.make_current()
	game.set_physics_process(false)
	for director in game.directors+game.upper_directors: director.process_mode = Node.PROCESS_MODE_DISABLED
	player.unlock_weapon("pistol"); player.set_control(true)
	game.step = game.Step.WORKSHOP
	# Every new campaign differs from the immediately preceding one, but reloads keep it.
	var first := CODES.new(); var second := CODES.new()
	check(first.tycho!=second.tycho,"Le code Tycho change pour une nouvelle partie")
	var saved := first.snapshot(); second.restore(saved,5)
	check(first.tycho==second.tycho and first.copernic==second.copernic,"Les deux codes survivent à la restauration")
	check(not CODES.valid({"tycho":"abcd","copernic":"1234","unlocked":false}),"Les codes invalides sont refusés")
	game.show_access_code("tycho")
	game.code_entry.text = "0000"; game.submit_code()
	check(game.code_window.visible and not game.clearance[1],"Un mauvais code laisse Tycho verrouillé")
	game.code_entry.text = game.access_codes.tycho; game.submit_code(); await frames(3)
	check(game.clearance[1] and not paused,"Le code aléatoire correct valide Tycho")
	var tablet: Vector3 = game.story.stations.access.marker.global_position
	await put_player(Vector3(tablet.x,0.045,tablet.z+1.1))
	check(game.nearest_interaction()=="story:access","La tablette cachée de la deuxième chambre est accessible")
	game.interact("story:access")
	check(game.story.flags.access and game.base_life.log_window.dialog_text.contains(game.access_codes.copernic),"Lire la tablette découvre et mémorise le code de Copernic")
	if paused: game.base_life.close_journal()
	game.step = game.Step.TRANSPORT
	await put_player(WORLD.at(2,0,0.045,21.6))
	game.enter_control(); await frames(2)
	check(paused and game.code_context=="copernic" and game.world.doors.control_entry.secured,"Copernic demande le code avant d'ouvrir")
	game.code_entry.text = "0000"; game.submit_code()
	check(game.world.doors.control_entry.secured,"Un mauvais code ne permet pas l'entrée dans Copernic")
	game.code_entry.text = game.access_codes.copernic; game.submit_code(); await frames(280)
	check(game.access_codes.copernic_unlocked and game.world.doors.control_entry_outer.is_open and game.step==game.Step.CONTROL,"Le bon code ouvre le sas extérieur de Copernic après décompression")
	for director in game.directors: director.process_mode = Node.PROCESS_MODE_DISABLED
	# Coplanar slabs and terrain no longer intersect.
	for point in [WORLD.at(1,0,0,-30),WORLD.at(1,8,0,-37),ROUTES.wreck_point(),ROUTES.wreck_point()+Vector3(4,0,3)]:
		check(game.world.surface_profile.elevation(point.x,point.z)<-0.12,"Le terrain est abaissé sous le plancher : "+str(point))
	check(game.world.rocket.global_position.y==WORLD.ROOF_HEIGHT and absf(game.world.rocket.global_position.z-WORLD.COPERNIC_Z)<20,"La fusée se trouve sur le toit de la dernière base")
	# Physically walk the full stair with a companion, rather than teleporting upstairs.
	game.story.flags.survivors = true; game.squad.recruit(0)
	await game.world.doors.roof_inner.open()
	var ally = game.squad.members[0]
	await put_player(WORLD.ROOF_STAIRS_BOTTOM+Vector3(0,0.045,-1))
	ally.reset_at(WORLD.ROOF_STAIRS_BOTTOM+Vector3(0.9,0.045,-2))
	player.rotation.y = PI
	Input.action_press("move_forward")
	for i in range(650):
		if player.position.z>WORLD.ROOF_STAIRS_TOP.z+2: break
		await physics_frame
	Input.action_release("move_forward")
	await frames(50)
	check(player.position.y>WORLD.ROOF_HEIGHT-0.1 and player.position.z>WORLD.ROOF_STAIRS_TOP.z,"Le joueur monte réellement jusqu'au toit")
	await frames(650)
	check(ally.position.y>WORLD.ROOF_HEIGHT-0.3 and ally.position.distance_to(player.position)<8,"L'allié emprunte l'escalier extérieur et rejoint le toit")
	# Lunar jump: real input, height and flight time; on the flat roof away from cover.
	await put_player(WORLD.at(2,30,WORLD.ROOF_HEIGHT+0.05,16))
	await frames(8)
	check(absf(player.get_gravity().y+1.62)<0.01,"La gravité effective du personnage vaut 1,62 m/s²")
	var bottom: float = player.position.y
	Input.action_press("jump"); await frames(2); Input.action_release("jump")
	var highest: float = player.position.y
	for i in range(150):
		await physics_frame
		highest = maxf(highest,player.position.y)
	check(highest-bottom>4.3 and highest-bottom<5.6,"Le saut lunaire atteint environ cinq mètres")
	check(not player.is_on_floor(),"Le personnage reste en suspension plus de deux secondes")
	await frames(210)
	check(player.is_on_floor(),"Le personnage retombe correctement sur le toit")
	# Fog of war wraps with the surface and survives save/load.
	game.exploration.discovered.clear()
	game.exploration.reveal(Vector3(599,0,0))
	check(game.exploration.known(Vector3(-599,0,0)) and not game.exploration.known(Vector3(0,0,-900)),"La carte révèle les bords reliés et masque les régions inconnues")
	var explored: Array = game.exploration.snapshot()
	game.exploration.restore(explored)
	check(game.exploration.snapshot().size()==explored.size(),"L'exploration est restaurée sans perte")
	game.exploration.open()
	check(paused and game.exploration.opened,"La carte portable suspend le combat")
	if DisplayServer.get_name()!="headless": await capture("carte_exploration.png")
	game.exploration.close(); check(not paused,"Fermer la carte reprend la partie")
	game.saver.path = "user://roof_validation_%d.json"%OS.get_process_id()
	game.saver.enabled = true
	check(game.saver.write_save(game),"La nouvelle progression peut être sauvegardée sur disque")
	var disk: Dictionary = game.saver.read_save()
	check(disk.access_codes.copernic==game.access_codes.copernic and disk.explored.size()==game.exploration.discovered.size(),"La sauvegarde conserve les codes et le terrain découvert")
	# The new encounter must reset every state after a defeat.
	game.ship_reveal(); await frames(450)
	check(game.step==game.Step.BATTLE and game.mothership.active,"La nouvelle cinématique rend le contrôle au début du combat")
	var boss = game.mothership
	check(boss.visual.scale.x>1.69 and boss.emitters.size()==18 and boss.guards.size()==6,"Le quadrupède possède huit canons supplémentaires et six défenseurs")
	if DisplayServer.get_name()!="headless":
		game.film.make_current(); game.frame_camera(WORLD.pad(23,7,-214),boss.global_position)
		await capture("boss_toit.png"); game.camera.make_current()
	boss.health = 30; boss.phase = 2; boss.pattern_index = 8; boss.subsystem_hp.assign([0,0])
	game.story.preparation = 22; game.story.link.health = 0
	game.on_death(); game.respawn()
	check(game.step==game.Step.REVEAL and not player.in_control,"Une défaite relance l'arrivée du boss depuis le début")
	await frames(450)
	boss = game.mothership
	check(boss.max_health==504 and boss.health>480 and boss.phase==0 and boss.subsystem_hp==[16,16],"Vie, phase et nacelles du boss sont réinitialisées")
	check(boss.guards.size()==6 and game.story.preparation<3 and game.story.link.health==100,"Les défenseurs et la préparation redémarrent aussi")
	# Reproduce a one-shot kill with a destroyed launch link and no preparation.
	game.story.preparation = 0; game.story.link.health = 0
	boss.receive_hit_at(boss.global_position,Vector3.UP,Vector3.DOWN,9999)
	await frames(4)
	check(game.step==game.Step.BOARD and game.story.ready_to_launch(),"Une victoire instantanée autorise le départ même si la liaison était détruite")
	check(game.world.pad_barriers.all(func(panel): return not panel.visible and panel.get_child(0).collision_layer==0),"Toutes les barrières visuelles et physiques disparaissent après la mort du boss")
	check(not is_instance_valid(boss.guard_director),"Les robots de défense cessent le combat après la victoire")
	game.animate_ascent(2)
	check(game.world.rocket.position.x==0 and game.world.rocket.position.y>0,"Le décollage commence verticalement")
	game.animate_ascent(8)
	check(game.world.rocket.position.y>120 and absf(game.world.rocket.rotation.x)<0.2,"La fusée accélère et s'incline progressivement en altitude")
	game.world.rocket.position = Vector3(0,0,-249); game.world.rocket.rotation = Vector3.ZERO
	await put_player(WORLD.pad(0,0.045,-243))
	game.squad.relocate()
	game.launch(); await frames(2400)
	check(game.step==game.Step.COMPLETE,"La nouvelle cinématique permet le retour sur Terre avec l'équipe")
	await finish_run()
