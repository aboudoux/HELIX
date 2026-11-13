extends "res://tests/verify.gd"
const WORLD := preload("res://missions/lunar_escape/lunar_world.gd")
const FEEDBACK := preload("res://missions/lunar_escape/combat_feedback.gd")
const SAVE := preload("res://missions/lunar_escape/campaign_save.gd")
var isolated_path := "user://test_polish_%d.json"%OS.get_process_id()

func fresh() -> void:
	game = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(game)
	current_scene = game
	player = game.pilot
	game.saver.path = isolated_path
	game.hud.title_card.hide()
	game.hud.set_film(false)
	game.camera.make_current()
	await frames(3)

func dispose() -> void:
	game.saver.enabled = false
	for sound in game.find_children("*","AudioStreamPlayer",true,false)+game.find_children("*","AudioStreamPlayer3D",true,false): sound.stop()
	OS.delay_msec(60)
	game.queue_free()
	await frames(4)
	OS.delay_msec(60)

func run() -> void:
	await fresh()
	game.step = game.Step.HABITAT
	player.set_third_person(true)
	player.unlock_weapon("pistol")
	player.set_control(true)
	await put_player(Vector3(-24.5,0.045,36))
	player.rotation.y = PI
	await frames(35)
	await tap(KEY_B)
	await frames(35)
	check(game.camera.position.x<-.48,"B déplace la caméra sur l'épaule gauche")
	var obstacle := WORLD.block(game.world,player.to_global(Vector3(-0.5,1.7,1.3)),Vector3(0.5,2.5,0.4),WORLD.STEEL,true)
	await frames(6)
	check(game.camera.position.length()<1.4,"La collision fonctionne aussi sur l'épaule gauche")
	await tap(KEY_B)
	var clear := true
	for i in range(35):
		await frames(1)
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = player.camera_probe
		query.transform = Transform3D(Basis.IDENTITY,game.camera.global_position)
		query.collision_mask = 1
		if not game.get_world_3d().direct_space_state.intersect_shape(query).is_empty(): clear = false
	check(clear,"Le changement d'épaule ne traverse pas l'obstacle")
	obstacle.queue_free()
	await frames(5)
	Input.action_press("jump")
	await frames(3)
	Input.action_release("jump")
	check(not player.is_on_floor() and player.avatar.last_vertical_speed>0,"Le saut anime le personnage en phase ascendante")
	var compression := 0.0
	for i in range(350):
		await frames(1)
		compression = maxf(compression,player.avatar.landing)
	check(compression>.05 and player.is_on_floor(),"La réception amortit le torse puis rend la pose au sol")
	var strengths: Array = []
	for key in ["pistol","shotgun","smg"]:
		player.unlock_weapon(key)
		await frames(12)
		player.weapon.fire()
		strengths.append(player.weapon.recoil)
		await frames(1)
	check(strengths[1]>strengths[0] and strengths[0]>strengths[2],"Le recul distingue pistolet, pompe et automatique")
	check(get_nodes_in_group("spent_cases").size()>=3,"Chaque tir éjecte une douille physique")
	for casing in get_nodes_in_group("spent_cases"): check(casing.collision_layer==0,"Les douilles ne bloquent pas le personnage")
	for kind in ["metal","glass","dust"]:
		var wall := WORLD.block(game.world,player.position+Vector3(0,1.5,-3),Vector3(3,3,0.2),WORLD.STEEL,true)
		var body: StaticBody3D = wall.get_child(0)
		body.set_meta("impact_surface",kind)
		check(FEEDBACK.surface_kind(body)==kind,"Identification de surface : "+kind)
		FEEDBACK.impact(player.weapon,{"collider":body,"position":wall.global_position,"normal":Vector3.BACK})
		check(get_nodes_in_group("surface_impacts").any(func(effect): return effect.get_meta("surface")==kind),"Effet de surface créé : "+kind)
		wall.queue_free()
	await frames(200)
	check(get_nodes_in_group("spent_cases").is_empty() and get_nodes_in_group("surface_impacts").is_empty(),"Douilles et impacts se nettoient automatiquement")
	var drone: CharacterBody3D = game.add_enemy(0,Vector3(2,2.4,0),"TEST FUMÉE")
	drone.max_health = 6
	drone.health = 6
	drone.receive_hit_at(drone.position,Vector3.UP,Vector3.FORWARD,3)
	check(drone.damage_details.smoke.emitting and drone.damage_details.removed>0,"Le moteur blessé fume et perd du blindage")
	drone.receive_repair()
	check(not drone.damage_details.smoke.emitting,"Réparer le moteur arrête la fumée critique")
	await put_player(Vector3(70,0.5,-110))
	await frames(40)
	check(game.soundscape.world_filter.cutoff_hz<2000 and game.soundscape.breath.playing,"La surface active le filtre de casque et la respiration")
	player.oxygen = 10
	game.soundscape.alarm_clock = 0
	await frames(2)
	check(game.soundscape.alarm.playing,"Une alerte audible annonce l'oxygène critique")
	await put_player(Vector3(-24.5,0.045,36))
	await frames(40)
	check(game.soundscape.world_filter.cutoff_hz>19000 and not game.soundscape.breath.playing,"Le son normal revient en intérieur")
	for i in range(3):
		check(game.world.has_node(["Selene/Observatoire/JardinDesColons","Tycho/Observatoire/AtelierDemontage","Copernic/Observatoire/CartographieOrbitale"][i]),"Décor narratif distinct pour la base %d"%i)
	game.saver.enabled = true
	game.saver.clear()
	game.step = game.Step.WORKSHOP
	game.story.flags.crew = true
	game.story.flags.medical = true
	game.story.flags.power = true
	game.story.flags.survivors = true
	game.story.flags.access = true
	game.mechanic_rescued = true
	player.weapon.ammo = 7
	player.weapon.reserve_ammo = 19
	player.set_third_person(false)
	player.shoulder_side = -1
	game.clearance[0] = true
	game.trials["upper_0"].started = true
	game.trials["upper_0"].left = 0
	game.base_life.stations[0].read = true
	game.base_life.stations[0].opened = true
	game.base_life.stations[0].taken = true
	game.saver.open_door(game.world.doors["cache_0"])
	game.take_supply("ammo_dorm")
	check(game.saver.write_save(game),"Écriture de la sauvegarde isolée sur disque")
	game.saver.enabled = false
	await dispose()
	await fresh()
	game.saver.enabled = true
	var stored: Dictionary = game.saver.read_save()
	check(not stored.is_empty(),"Une nouvelle scène retrouve la sauvegarde sur disque")
	var old_camera_save: Dictionary = stored.duplicate(true)
	old_camera_save.third_person = true
	check(game.saver.restore(game,old_camera_save),"La campagne recharge le point sûr de Tycho depuis une sauvegarde en troisième personne")
	await frames(5)
	check(game.step==game.Step.WORKSHOP and absf(player.position.z-WORLD.BASE_Z[1]-17)<0.5,"La reprise se place à l'entrée de la bonne base")
	check(player.equipped=="smg" and player.weapon.ammo==7 and player.weapon.reserve_ammo==56,"Le chargeur est conservé et la réserve de secours évite une reprise sans munitions")
	check(player.inventory.has("pistol") and player.inventory.has("shotgun"),"Toutes les autres armes restent disponibles")
	check(not player.third_person and not player.avatar.visible,"La reprise ignore l'ancien choix de troisième personne")
	check(game.story.flags.crew and game.story.flags.medical and game.story.flags.survivors and game.story.exit_ready(1),"Journal, survivants et secours de Lina persistent sur disque")
	var legacy: Dictionary = stored.duplicate(true)
	legacy.erase("story")
	legacy.erase("camera_revision")
	legacy.stage = 6
	legacy.third_person = true
	await dispose()
	await fresh()
	check(game.saver.restore(game,legacy) and not player.third_person and game.story.exit_ready(1),"Une ancienne sauvegarde reprend en première personne sans bloquer les survivants déjà dépassés")
	await dispose()
	await fresh()
	game.saver.enabled = true
	game.saver.restore(game,stored)
	check(not game.supplies.has("ammo_dorm"),"Les boîtes déjà ramassées ne réapparaissent pas")
	check(player.oxygen_efficiency==0.65 and game.base_life.stations[0].taken,"Le module et l'annexe sont restaurés")
	check(game.trials["upper_0"].started and not game.world.doors["upper_0"].secured,"Une épreuve terminée reste déverrouillée")
	check(game.world.doors["cache_0"].is_open,"Le sas de l'annexe reste ouvert")
	game.toggle_pause()
	check(paused and game.hud.card_copy.text.contains("Progression sauvegardée"),"La pause sauvegarde et confirme le résultat")
	game.toggle_pause()
	var corrupt := FileAccess.open(isolated_path,FileAccess.WRITE)
	corrupt.store_string("{interrupted")
	corrupt.close()
	check(not game.saver.read_save().is_empty(),"Une copie précédente valide récupère un fichier interrompu")
	check(not game.saver.valid({"version":1,"stage":999}),"Une sauvegarde incohérente est refusée")
	stored.stage = 7
	stored.armor = true
	stored.shield = true
	await dispose()
	await fresh()
	check(game.saver.restore(game,stored),"Reprise à Copernic depuis une scène neuve")
	await frames(5)
	check(player.avatar.reinforced and player.max_health==125 and player.shield_unlocked,"Armure renforcée et bouclier survivent à la fermeture")
	check(game.find_children("*","CharacterBody3D",true,false).filter(func(actor): return actor.get_script()==preload("res://missions/lunar_escape/spider.gd")).size()>=3,"Les araignées de Copernic existent après reprise")
	stored.stage = 9
	await dispose()
	await fresh()
	check(game.saver.restore(game,stored),"La sauvegarde du boss relance son approche")
	await frames(450)
	check(game.step==game.Step.BATTLE and game.mothership.active and player.in_control,"Le combat final redevient jouable après reprise")
	stored.stage = 10
	stored.story.preparation = 35
	await dispose()
	await fresh()
	check(game.saver.restore(game,stored),"La victoire sauvegardée restaure l'accès à la fusée")
	check(game.step==game.Step.BOARD and player.in_control,"La victoire ne fait pas réapparaître le boss")
	game.launch()
	await frames(2400)
	check(game.step==game.Step.COMPLETE,"La partie reprise peut terminer le retour sur Terre")
	game.saver.enabled = true
	game.saver.clear()
	await dispose()
	check(AudioServer.get_bus_index("LunarWorld")==-1,"Les bus audio sont retirés quand on quitte la campagne")
	print("%d vérifications finitions et sauvegarde, %d échec(s)"%[checks,failures])
	quit(1 if failures else 0)
