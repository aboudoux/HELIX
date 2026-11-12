extends "res://tests/verify.gd"
## Impacts au point touché, gravité, rebonds, pause, nettoyage et budget d'effets.

const DEBRIS := preload("res://scripts/drone_debris.gd")
var drone: CharacterBody3D
var graphics: bool


func debris() -> Array:
	return get_nodes_in_group("drone_debris_effects").filter(func(node): return not node.is_queued_for_deletion())


func snap(name: String) -> void:
	if not graphics:
		return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tests/artifacts/"+name)) == OK,"Capture "+name)


func shoot() -> void:
	mouse_button(true)
	await frames(2)
	mouse_button(false)


func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	player = game.get_node("Player")
	drone = game.get_node("Drones").get_child(0)
	graphics = DisplayServer.get_name() != "headless"
	for actor in game.get_node("Drones").get_children():
		actor.attack_enabled = false
		actor.move_speed = 0.0
	await frames(5)
	game.resume_button.pressed.emit()
	await put_player(Vector3(0,.05,18))
	drone.position = Vector3(0,2.4,12)
	drone.velocity = Vector3.ZERO
	await aim_at(drone.position)
	await shoot()
	check(drone.health == 2 and player.weapon.last_hit.get("collider") == drone,"Le vrai tir conserve les dégâts et la détection du drone")
	check(debris().size() == 1,"Un seul effet de fragments par impact")
	var impact: Node3D = debris()[0]
	var hit: Dictionary = player.weapon.last_hit
	check(impact.global_position.distance_to(hit.position+hit.normal*.025) < .001,"Les fragments partent du point réellement touché")
	check(impact.pieces.size() == 18 and impact.sparks.size() == 24,"Éclats de coque, boulons, fils et gerbe d'étincelles")
	check(impact.batches.has("armor") and impact.batches.has("metal") and impact.batches.has("wire") and impact.batches.has("bolt"),"Quatre familles de petits débris distinctes")
	check(impact.find_children("*","CollisionObject3D",true,false).is_empty(),"Les débris ne bloquent ni le joueur ni les tirs")
	var outside := true
	for piece in impact.pieces:
		outside = outside and piece.velocity.dot(hit.normal) > 0
	check(outside,"Les éclats sont projetés vers l'extérieur du blindage")
	await frames(5)
	await snap("debris_impact.png")
	await tap(KEY_ESCAPE)
	var position: Vector3 = impact.pieces[0].position
	var age: float = impact.elapsed
	await frames(30)
	check(impact.pieces[0].position == position and impact.elapsed == age,"La pause fige les fragments et leur durée de vie")
	game.resume_button.pressed.emit()
	await frames(16)
	check(impact.pieces[0].position != position,"La reprise relance les trajectoires")
	await shoot()
	await frames(16)
	await shoot()
	check(not drone.alive and game.drones_destroyed == 1,"Le troisième impact neutralise toujours le drone")
	var bursts := debris().filter(func(node): return node.destruction)
	check(bursts.is_empty(),"Aucune gerbe d'explosion n'accompagne le tir fatal")
	check(is_instance_valid(drone.wreck) and drone.wreck.visible,"Le modèle du drone devient une épave visible")
	check(drone.wreck.blades.size()==4,"L'épave conserve ses turbines et leurs pales")
	check(not drone.receive_hit() and game.drones_destroyed == 1,"Les drones abattus ne génèrent pas de nouvelles touches")
	await frames(6)
	await snap("debris_destruction.png")
	# De vrais contacts avec le sol, puis avec une paroi de test.
	var floor_effect := DEBRIS.new()
	game.get_node("Effects").add_child(floor_effect)
	floor_effect.setup(Vector3(4,0,14),Vector3.UP,Vector3.DOWN)
	for piece in floor_effect.pieces:
		piece.position = Vector3(0,.12,0)
		piece.velocity = Vector3.DOWN*5
	await frames(16)
	var bounced := 0
	var above_floor := true
	for piece in floor_effect.pieces:
		bounced += piece.bounces
		above_floor = above_floor and floor_effect.to_global(piece.position).y >= .02
	check(bounced > 0 and above_floor,"Les fragments rebondissent sur le sol sans le traverser")
	var wall := make_blocker(Vector3(7,1.5,14),Vector3(.3,3,3))
	await frames(3)
	var wall_effect := DEBRIS.new()
	game.get_node("Effects").add_child(wall_effect)
	wall_effect.setup(Vector3(6,1.5,14),Vector3.RIGHT,Vector3.LEFT)
	for piece in wall_effect.pieces:
		piece.position = Vector3.ZERO
		piece.velocity = Vector3.RIGHT*7
	await frames(10)
	check(wall_effect.pieces[0].velocity.x < 0 and wall_effect.pieces[0].bounces > 0,"Les morceaux sont aussi arrêtés par les murs")
	wall.queue_free()
	await frames(190)
	check(debris().is_empty(),"Tous les fragments disparaissent après leur durée de vie")
	check(is_instance_valid(drone.wreck) and drone.wreck.visible,"Les fragments temporaires disparaissent mais l'épave reste")
	# Un grand nombre de touches dans la même image garde un budget borné.
	for i in range(40):
		var effect := DEBRIS.new()
		game.get_node("Effects").add_child(effect)
		effect.setup(Vector3(0,2,8),Vector3.BACK,Vector3.FORWARD,i%4 == 0)
	await frames(3)
	check(debris().size() == DEBRIS.MAX_ACTIVE,"Une rafale conserve les seize effets les plus récents")
	game.restart_exploration()
	await frames(3)
	check(debris().is_empty() and game.get_node("Effects").get_child_count() == 0,"Recommencer efface immédiatement tous les débris")
	check(game.get_node("Wrecks").get_child_count()==0,"Recommencer retire aussi les anciennes épaves")
	await put_player(Vector3(0,.05,18))
	drone.position = Vector3(0,2.4,12)
	drone.velocity = Vector3.ZERO
	await aim_at(drone.position)
	wall = make_blocker(Vector3(0,1.5,15),Vector3(3,3,.4))
	await frames(3)
	await shoot()
	check(drone.health == 3 and debris().is_empty(),"Un drone derrière une couverture ne perd pas de fragments")
	wall.queue_free()
	print("RESULT: %d debris checks, %d failures" % [checks,failures])
	for sound in game.find_children("*","AudioStreamPlayer",true,false)+game.find_children("*","AudioStreamPlayer3D",true,false):
		sound.stop()
	OS.delay_msec(50)
	game.queue_free()
	paused = false
	await frames(3)
	OS.delay_msec(80)
	quit(1 if failures else 0)
