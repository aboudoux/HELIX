extends "res://tests/verify.gd"
## Chute physique, collision du modèle, persistance jusqu'à la victoire et remise à zéro.

var graphics: bool


func open_scene(path: String) -> void:
	game = load(path).instantiate()
	root.add_child(game)
	current_scene = game
	player = game.player
	for actor in game.get_node("Drones").get_children():
		actor.attack_enabled = false
		actor.move_speed = 0
	await frames(8)
	game.start_exploration()


func close_scene() -> void:
	for sound in game.find_children("*","AudioStreamPlayer",true,false)+game.find_children("*","AudioStreamPlayer3D",true,false):
		sound.set_process(false)
		sound.stop()
	OS.delay_msec(50)
	game.queue_free()
	paused = false
	await frames(4)
	OS.delay_msec(80)


func shoot() -> void:
	mouse_button(true)
	await frames(2)
	mouse_button(false)
	await frames(15)


func snap(name: String) -> void:
	if graphics:
		await frames(3)
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tests/artifacts/"+name))==OK,"Capture "+name)


func floor_height(wreck: RigidBody3D) -> float:
	var lowest := INF
	for vertex in wreck.get_node("CollisionShape3D").shape.points:
		lowest = minf(lowest,(wreck.global_transform*vertex).y)
	return lowest


func emissive_count(visual: Node3D) -> int:
	var count := 0
	for mesh in visual.find_children("*","MeshInstance3D",true,false):
		for surface in range(mesh.mesh.get_surface_count()):
			var material: Material = mesh.get_active_material(surface)
			if material is BaseMaterial3D and material.emission_enabled: count += 1
	return count


func run() -> void:
	graphics = DisplayServer.get_name()!="headless"
	await open_scene("res://scenes/main.tscn")
	await put_player(Vector3(0,.05,18))
	var actor: CharacterBody3D = game.get_node("Drones").get_child(0)
	actor.position = Vector3(0,2.4,12)
	actor.velocity = Vector3.ZERO
	await aim_at(actor.position)
	await shoot()
	await shoot()
	mouse_button(true)
	await frames(2)
	mouse_button(false)
	var wreck: RigidBody3D = actor.wreck
	check(not actor.alive and actor.hit_shape.disabled and not actor.hull.visible,"Le tir fatal arrête l'ennemi et sa collision de cible")
	check(is_instance_valid(wreck) and wreck.get_parent()==game.get_node("Wrecks") and wreck.visible,"Une épave séparée garde le modèle visible")
	check(wreck.visual.find_children("*","MeshInstance3D",true,false).size()>30,"Le modèle détaillé entier est conservé")
	check(wreck.get_node("CollisionShape3D").shape is ConvexPolygonShape3D and wreck.continuous_cd,"Une enveloppe convexe et la détection continue protègent la chute")
	check(wreck.impact_count==0 and not wreck.crash_sound.playing,"Le choc ne joue pas avant le contact avec le décor")
	check(not actor.rotor_sound.playing and not actor.get_node("ShotSound").playing,"Le tir fatal coupe hélices et tirs ennemis")
	check(emissive_count(wreck.visual)==0,"Les cellules lumineuses de l'épave sont éteintes")
	var other: Node3D = game.get_node("Drones").get_child(1).get_node("Hull/VisualModel")
	check(emissive_count(other)>0,"Les matériaux des drones vivants gardent leurs lumières")
	var explosions := get_nodes_in_group("drone_debris_effects").filter(func(node): return node.destruction)
	check(explosions.is_empty() and actor.get_node_or_null("DestructionSound")==null,"Aucune explosion ni ancien son d'explosion n'est déclenché")
	var height: float = wreck.position.y
	await frames(8)
	check(wreck.position.y<height-.04,"L'épave tombe réellement avec la gravité")
	game.show_pause()
	var frozen := wreck.global_transform
	await frames(30)
	check(wreck.global_transform.is_equal_approx(frozen),"La pause fige aussi la chute physique")
	game.start_exploration()
	await frames(240)
	check(wreck.impact_count==1 and wreck.position.y<1.2,"L'épave percute le sol et ne joue qu'un impact")
	check(wreck.settled and wreck.freeze,"L'épave se stabilise au sol")
	check(floor_height(wreck)>-.08 and floor_height(wreck)<.15,"Le modèle repose sur le sol sans le traverser")
	check(wreck.blades.size()==4 and wreck.rotor_speed==0,"Les quatre hélices finissent de s'arrêter")
	var settled_transform := wreck.global_transform
	await frames(900)
	check(is_instance_valid(wreck) and wreck.visible and wreck.global_transform.is_equal_approx(settled_transform),"L'épave reste en place après quinze secondes supplémentaires")
	check(game.get_node("Effects").get_child_count()==0 and game.get_node("Wrecks").get_child_count()==1,"Le nettoyage des effets courts ne supprime pas les carcasses")
	await aim_at(wreck.global_position)
	await shoot()
	check(player.weapon.last_hit.get("collider")==wreck and game.drones_destroyed==1,"Les tirs s'arrêtent sur l'épave sans recompter un ennemi")
	check(not actor.receive_hit() and game.get_node("Wrecks").get_child_count()==1,"Un drone abattu ne crée jamais une deuxième épave")
	await snap("epave_sentinelle.png")
	actor.reset_drone()
	await frames(4)
	check(not is_instance_valid(wreck) and actor.alive and actor.wreck==null,"Réinitialiser un drone retire sa propre ancienne épave")
	await close_scene()
	await open_scene("res://missions/relay_run/mission.tscn")
	var expected := 0
	var persistent: Array = []
	for sector in range(3):
		game.director.engage_sector(sector)
		for guard in game.director.get_children():
			if guard.alive:
				while guard.alive: guard.receive_hit()
				persistent.append(guard.wreck)
				expected += 1
		await frames(180)
		await put_player(game.relays[sector].position+Vector3(0,.05,2))
		await tap(KEY_E)
		await frames(85)
		check(game.stage==sector+1 and game.get_node("Wrecks").get_child_count()==expected,"Les épaves restent après le relais %d" % (sector+1))
		check(persistent.all(func(body): return is_instance_valid(body) and body.is_visible_in_tree()),"Les carcasses des secteurs précédents restent visibles")
	check(expected==15 and game.drones_destroyed==15,"Les quinze sentinelles sont comptées et gardent leurs quinze carcasses")
	var boss: CharacterBody3D = game.boss
	boss.attack_enabled = false
	boss.move_speed = 0
	boss.position = Vector3(0,4.2,-68)
	boss.rotation = Vector3(0,PI,0)
	boss.velocity = Vector3.ZERO
	while boss.alive: boss.receive_hit()
	var boss_wreck: RigidBody3D = boss.wreck
	check(boss_wreck.heavy and boss_wreck.mass>400 and boss_wreck.barrels.size()==2,"CERBÈRE conserve sa grande carcasse et ses deux mitrailleuses")
	check(boss_wreck.get_node("CollisionShape3D").shape!=persistent[0].get_node("CollisionShape3D").shape,"Le boss possède une enveloppe adaptée à son propre modèle")
	check(game.stage==4 and game.drones_destroyed==16,"La neutralisation du boss conserve la progression et les compteurs")
	await frames(360)
	check(boss_wreck.impact_count==1 and boss_wreck.settled and boss_wreck.freeze,"CERBÈRE s'écrase et se stabilise à son tour")
	check(floor_height(boss_wreck)>-.08 and floor_height(boss_wreck)<.18,"La carcasse massive repose sur le sol")
	check(game.get_node("Wrecks").get_child_count()==16 and game.gates[2].fully_open,"Les seize carcasses sont conservées et l'extraction reste accessible")
	await put_player(Vector3(-12,.05,-59))
	await aim_at(boss_wreck.global_position)
	await snap("epave_cerbere.png")
	await put_player(Vector3(0,.05,-90))
	await frames(140)
	check(not game.mission_complete and game.stage==4 and game.lift.unlocked and game.get_node("Wrecks").get_child_count()==16,"Toutes les épaves restent avant la montée")
	game.restart_exploration()
	await frames(8)
	check(game.get_node("Wrecks").get_child_count()==0 and get_nodes_in_group("drone_wrecks").is_empty(),"Rejouer nettoie toutes les épaves de la partie précédente")
	check(game.stage==0 and game.drones_destroyed==0 and not game.boss.alive,"Rejouer restaure la mission et le boss dormant")
	await close_scene()
	print("RESULT: %d wreck checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
