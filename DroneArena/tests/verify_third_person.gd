extends "res://tests/verify.gd"
const WORLD := preload("res://missions/lunar_escape/lunar_world.gd")

func run() -> void:
	game = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(game)
	current_scene = game
	player = game.pilot
	check(not player.third_person,"La première personne est active par défaut pour la mission Karen")
	player.set_third_person(true)
	game.step = game.Step.HABITAT
	game.hud.title_card.hide()
	game.hud.set_film(false)
	game.camera.make_current()
	player.unlock_weapon("pistol")
	player.set_control(true)
	await put_player(Vector3(-24.5,0.045,36.0))
	player.rotation.y = PI
	await frames(35)
	check(player.third_person and player.avatar.visible and not player.weapon.model.visible,"La troisième personne reste disponible avec un corps visible")
	check(game.camera.position.length()>2.9,"La caméra se place derrière l'épaule en espace dégagé")
	await screenshot("third_person.png")
	var target: CharacterBody3D = game.add_enemy(0,game.camera.global_position-game.camera.global_basis.z*9.0,"CIBLE TPS")
	target.process_mode = Node.PROCESS_MODE_PAUSABLE
	target.set_physics_process(false)
	target.max_health = 50
	target.health = 50
	for key in ["pistol","shotgun","smg"]:
		player.unlock_weapon(key)
		await frames(25)
		var old_health: int = target.health
		player.weapon.fire()
		await frames(3)
		check(target.health<old_health and player.weapon.last_hit.get("collider")==target,"%s : le tir atteint la cible du viseur depuis l'arme du personnage"%key)
		check(player.weapon.world_muzzle==player.avatar.muzzle,"%s : le départ du tir suit le canon tenu en main"%key)
		check(player.weapon.shot_sound.volume_db>=-6,"%s : la détonation est mise en avant dans le mix"%key)
		player.weapon.ammo = 0
		player.weapon.reserve_ammo = 2
		player.weapon.start_reload()
		await frames(25)
		check(player.avatar.gun.magazine.position.distance_to(player.avatar.gun.magazine_seat)>0.03,"%s : le chargeur bouge aussi en troisième personne"%key)
		if key=="shotgun": await screenshot("third_person_reload.png")
		var pose: Vector3 = player.avatar.gun.magazine.position
		paused = true
		await frames(12)
		check(pose==player.avatar.gun.magazine.position,"%s : la pause fige l'animation du personnage"%key)
		paused = false
		await frames(100)
		check(player.weapon.ammo==2 and player.weapon.reserve_ammo==0,"%s : la recharge conserve les munitions"%key)
	var barrier := WORLD.block(game.world,player.to_global(Vector3(0.20,1.3,-0.38)),Vector3(0.38,1.7,0.12),WORLD.STEEL,true)
	await frames(4)
	var health: int = target.health
	player.weapon.fire()
	await frames(3)
	check(target.health==health,"Un obstacle devant le canon bloque le tir même si la caméra voit la cible")
	barrier.queue_free()
	await frames(4)
	var wall := WORLD.block(game.world,player.to_global(Vector3(0,1.5,1.5)),Vector3(5,3,0.20),WORLD.WHITE,true)
	await frames(8)
	check(game.camera.position.length()<1.3,"La caméra se rétracte devant un mur derrière le personnage")
	var probe := PhysicsShapeQueryParameters3D.new()
	probe.shape = player.camera_probe
	probe.transform = Transform3D(Basis.IDENTITY,game.camera.global_position)
	probe.collision_mask = 1
	check(game.get_world_3d().direct_space_state.intersect_shape(probe).is_empty(),"Le volume de la caméra reste hors du mur")
	wall.queue_free()
	await frames(30)
	player.set_third_person(false)
	var shoulder: float = player.shoulder_side
	await tap(KEY_V)
	await tap(KEY_B)
	check(not player.third_person and not player.avatar.visible and player.weapon.model.visible and game.camera.position==Vector3.ZERO,"V et B laissent le joueur à la première personne")
	check(player.shoulder_side==shoulder,"B ne change plus l'épaule")
	var journal: Vector3 = game.base_life.stations[0].journal.global_position
	await put_player(Vector3(journal.x,0.045,journal.z-1.1))
	await frames(15)
	check(game.nearest_interaction()=="annex:journal:0","Les interactions restent à portée du personnage, pas de la caméra reculée")
	player.mount(game.world.bike)
	await frames(4)
	check(game.camera.position==Vector3.ZERO and not player.avatar.visible,"Monter en véhicule reprend la caméra de conduite")
	check(player.dismount(),"Le personnage peut redescendre du véhicule")
	await frames(30)
	check(not player.third_person and not player.avatar.visible and game.camera.position==Vector3.ZERO,"La première personne revient après la conduite")
	player.set_third_person(true)
	await put_player(Vector3(-24.5,0.045,36))
	Input.action_press("move_forward")
	var gait: float = player.avatar.gait
	await frames(20)
	Input.action_release("move_forward")
	check(player.avatar.gait>gait+1.0,"La marche anime les jambes en fonction du déplacement réel")
	game.interact("armor")
	game.interact("armor")
	check(player.avatar.reinforced and player.max_health==125,"Enfiler l'armure change le personnage visible et sa protection")
	game.hud.hide()
	game.film.make_current()
	game.frame_camera(player.position+Vector3(2.4,1.85,-3.0),player.position+Vector3.UP*1.0)
	await frames(15)
	await screenshot("armor_character.png")
	game.respawn()
	await frames(20)
	check(player.avatar.reinforced,"Le checkpoint conserve l'armure")
	for sound in game.find_children("*","AudioStreamPlayer",true,false)+game.find_children("*","AudioStreamPlayer3D",true,false): sound.stop()
	OS.delay_msec(70)
	game.queue_free()
	await frames(4)
	OS.delay_msec(80)
	print("%d vérifications troisième personne, %d échec(s)"%[checks,failures])
	quit(1 if failures else 0)

func screenshot(file: String) -> void:
	if DisplayServer.get_name()=="headless": return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/artifacts"))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/artifacts/"+file)
