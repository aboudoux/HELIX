extends "res://tests/verify.gd"
## Commandes réelles, capsule, plafond bas, combat et boucle de pause/reprise.

var graphics: bool


func snap(name: String) -> void:
	if graphics:
		await frames(3)
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tests/artifacts/"+name))==OK,"Capture "+name)


func check_menu() -> void:
	var card: Control = game.get_node("Interface/Overlay/Card")
	check(card.get_viewport_rect().encloses(card.get_global_rect()),"Le menu avec les nouvelles commandes tient dans la fenêtre")
	check(card.get_global_rect().encloses(game.get_node("Interface/Overlay/Card/Content/Quit").get_global_rect()),"Le bouton Quitter reste accessible")
	var controls: Label = game.get_node("Interface/Overlay/Card/Content/Controls")
	check(controls.text.contains("MAJ") and controls.text.contains("CTRL"),"Les deux commandes sont affichées dans le menu")
	var footer: Label = game.get_node("Interface/Footer/Commands")
	check(footer.text.contains("MAJ") and footer.text.contains("CTRL") and footer.get_line_count()==2,"Les deux commandes sont affichées sur deux lignes en jeu")
	check(not footer.get_global_rect().intersects(game.get_node("Interface/Footer/PauseHint").get_global_rect()),"Les commandes ne recouvrent pas le rappel Échap")


func open_scene(path: String) -> void:
	game = load(path).instantiate()
	root.add_child(game)
	current_scene = game
	player = game.player
	for actor in game.get_node("Drones").get_children():
		actor.attack_enabled = false
		actor.move_speed = 0
	await frames(8)
	check_menu()


func close_scene() -> void:
	for action in ["move_forward","move_back","move_left","move_right","jump","sprint","crouch","fire"]: Input.action_release(action)
	for sound in game.find_children("*","AudioStreamPlayer",true,false)+game.find_children("*","AudioStreamPlayer3D",true,false): sound.stop()
	OS.delay_msec(50)
	game.queue_free()
	paused = false
	await frames(4)
	OS.delay_msec(80)


func run() -> void:
	graphics = DisplayServer.get_name()!="headless"
	await open_scene("res://scenes/main.tscn")
	await snap("mobilite_menu.png")
	game.start_exploration()
	await put_player(Vector3(0,.05,18))
	var start := player.position
	key_event(KEY_Z,true)
	await frames(60)
	key_event(KEY_Z,false)
	var walked: float = start.distance_to(player.position)
	check(walked>5 and walked<6.1 and is_equal_approx(player.velocity.z,-6),"La marche reste à 6 m/s")
	await put_player(Vector3(0,.05,18))
	start = player.position
	key_event(KEY_SHIFT,true)
	key_event(KEY_Z,true)
	await frames(60)
	check(Input.is_action_pressed("sprint") and player.is_sprinting,"Maj déclenche réellement la course")
	check(start.distance_to(player.position)>walked*1.4 and is_equal_approx(player.velocity.z,-9.5),"Courir augmente réellement la distance parcourue et la vitesse")
	key_event(KEY_SHIFT,false)
	await frames(20)
	check(not player.is_sprinting and is_equal_approx(player.velocity.z,-6),"Relâcher Maj rétablit la marche")
	key_event(KEY_Z,false)
	await put_player(Vector3(0,.05,18))
	key_event(KEY_SHIFT,true)
	key_event(KEY_Z,true)
	key_event(KEY_D,true)
	await frames(35)
	check(player.velocity.slide(Vector3.UP).length()<=9.51,"La course en diagonale n'accélère pas davantage")
	key_event(KEY_Z,false)
	key_event(KEY_D,false)
	key_event(KEY_SHIFT,false)
	await put_player(Vector3(0,.05,18))
	key_event(KEY_SHIFT,true)
	key_event(KEY_Z,true)
	await frames(30)
	await tap(KEY_SPACE)
	check(player.position.y>.3 and not player.is_on_floor() and absf(player.velocity.z)>9,"Sauter en courant conserve l'élan")
	key_event(KEY_SHIFT,false)
	key_event(KEY_Z,false)
	await put_player(Vector3(0,.05,18))
	var feet: float = player.position.y
	key_event(KEY_CTRL,true)
	await frames(15)
	check(Input.is_action_pressed("crouch") and player.is_crouching,"Ctrl déclenche réellement l'accroupissement")
	check(is_equal_approx(player.capsule.height,1.05) and is_equal_approx(player.body_shape.position.y,.525),"La capsule de collision rétrécit par le haut")
	check(is_equal_approx(player.head.position.y,.9) and absf(player.position.y-feet)<.015,"La vue descend à 90 cm et les pieds restent au sol")
	var other := load("res://scenes/player.tscn").instantiate() as CharacterBody3D
	other.set_physics_process(false)
	game.add_child(other)
	check(other.capsule!=player.capsule and is_equal_approx(other.capsule.height,1.8),"La posture ne modifie pas les autres instances du personnage")
	other.queue_free()
	key_event(KEY_SHIFT,true)
	key_event(KEY_Z,true)
	await frames(30)
	check(not player.is_sprinting and is_equal_approx(player.velocity.z,-3),"La marche accroupie à 3 m/s a priorité sur le sprint")
	key_event(KEY_Z,false)
	key_event(KEY_SHIFT,false)
	await frames(15)
	var grounded: float = player.position.y
	await tap(KEY_SPACE)
	check(player.is_on_floor() and absf(player.position.y-grounded)<.015,"Le saut reste bloqué pendant l'accroupissement")
	key_event(KEY_CTRL,false)
	await frames(15)
	check(not player.is_crouching and is_equal_approx(player.capsule.height,1.8) and is_equal_approx(player.head.position.y,1.65),"Relâcher Ctrl permet de se relever en terrain libre")
	# Plafond à 1,20 m : impossible debout, praticable accroupi.
	var ceiling := make_blocker(Vector3(0,1.4,14),Vector3(4,.4,3))
	await put_player(Vector3(0,.05,18))
	key_event(KEY_SHIFT,true)
	key_event(KEY_Z,true)
	await frames(60)
	check(player.position.z>15.75 and player.position.z<16,"La collision arrête le sprint devant un passage trop bas")
	key_event(KEY_SHIFT,false)
	key_event(KEY_CTRL,true)
	await frames(45)
	key_event(KEY_Z,false)
	await frames(12)
	check(player.position.z<15 and player.position.z>12.7 and player.is_crouching,"On peut passer sous le plafond en se baissant")
	key_event(KEY_CTRL,false)
	await frames(20)
	check(player.is_crouching and not player.can_stand() and is_equal_approx(player.capsule.height,1.05),"Relâcher Ctrl sous un plafond maintient la capsule basse")
	check(player.head.global_position.y<1.2,"La caméra reste sous le plafond")
	await tap(KEY_SPACE)
	check(player.head.global_position.y<1.2 and player.is_on_floor(),"Sauter ne permet pas de traverser un plafond bas")
	await snap("mobilite_passage_bas.png")
	key_event(KEY_Z,true)
	await frames(90)
	key_event(KEY_Z,false)
	await frames(15)
	check(player.position.z<12 and not player.is_crouching and is_equal_approx(player.capsule.height,1.8),"Le personnage se relève automatiquement une fois le passage dégagé")
	ceiling.queue_free()
	await frames(5)
	# Le tir utilise la caméra et la bouche du canon à leur nouvelle hauteur.
	await put_player(Vector3(5,.05,12))
	key_event(KEY_CTRL,true)
	await frames(15)
	var target: StaticBody3D = game.get_node("Arena/Cible02")
	await aim_at(target.to_global(Vector3(0,1.65,0)))
	var hits: int = target.times_hit
	mouse_button(true)
	await frames(2)
	mouse_button(false)
	check(target.times_hit==hits+1 and player.weapon.last_hit.get("collider")==target,"Viser et tirer accroupi touche la vraie cible")
	await snap("mobilite_accroupi.png")
	# Une sentinelle garde une vraie ligne de vue sur un joueur baissé à découvert.
	await put_player(Vector3(0,.05,18))
	var actor: CharacterBody3D = game.get_node("Drones").get_child(0)
	actor.global_position = Vector3(0,2.4,12)
	actor.velocity = Vector3.ZERO
	actor.attack_enabled = true
	actor.cooldown = 0
	await frames(3)
	check(actor.has_line_of_sight() and player.get_aim_point().y<player.global_position.y+1,"Les drones voient aussi le joueur accroupi à découvert")
	await frames(100)
	check(player.health<100 and player.health>0,"Les projectiles des drones peuvent atteindre la nouvelle capsule")
	actor.attack_enabled = false
	game.show_pause()
	var frozen := player.global_transform
	var frozen_head: Vector3 = player.head.position
	key_event(KEY_CTRL,false)
	key_event(KEY_SHIFT,true)
	key_event(KEY_Z,true)
	await frames(20)
	check(player.global_transform==frozen and player.head.position==frozen_head and player.is_crouching,"La pause fige déplacement et posture malgré les touches")
	key_event(KEY_SHIFT,false)
	key_event(KEY_Z,false)
	game.start_exploration()
	await frames(15)
	check(not player.is_crouching and is_equal_approx(player.head.position.y,1.65),"Reprendre applique correctement les touches relâchées en pause")
	key_event(KEY_CTRL,true)
	await frames(15)
	key_event(KEY_CTRL,false)
	game.restart_exploration()
	check(not player.is_crouching and not player.is_sprinting and is_equal_approx(player.capsule.height,1.8),"Recommencer remet immédiatement la posture debout")
	await close_scene()
	await open_scene("res://missions/relay_run/mission.tscn")
	await snap("mobilite_menu_mission.png")
	game.start_exploration()
	await put_player(Vector3(0,.05,64))
	key_event(KEY_SHIFT,true)
	key_event(KEY_Z,true)
	await frames(45)
	check(player.is_sprinting and player.position.z<60,"La course est aussi disponible dans la mission")
	key_event(KEY_SHIFT,false)
	key_event(KEY_Z,false)
	key_event(KEY_CTRL,true)
	await frames(15)
	check(player.is_crouching and is_equal_approx(player.head.position.y,.9),"La position accroupie est aussi disponible dans la mission")
	await close_scene()
	await open_scene("res://missions/relay_run/boss_trial.tscn")
	game.start_exploration()
	game.boss.move_speed = 0
	key_event(KEY_CTRL,true)
	await frames(20)
	game.boss.cooldown = 0
	await frames(8)
	check(game.boss.has_line_of_sight() and is_equal_approx(game.boss.locked_aim.y,player.get_aim_point().y),"CERBÈRE verrouille la hauteur réelle du joueur accroupi")
	await frames(155)
	check(player.health<100 and player.health>0,"Les deux armes du boss peuvent aussi toucher le joueur baissé")
	game.boss.attack_enabled = false
	await close_scene()
	print("RESULT: %d movement checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
