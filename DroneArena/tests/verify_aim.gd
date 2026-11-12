extends "res://tests/verify.gd"
## Clic droit réel, alignement du viseur, tirs et transitions de la boucle de jeu.

var graphics: bool
var weapon: Node3D
var camera: Camera3D


func right_button(pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = pressed
	event.position = root.get_visible_rect().size*.5
	Input.parse_input_event(event)


func snap(name: String) -> void:
	if graphics:
		await frames(3)
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tests/artifacts/"+name))==OK,"Capture "+name)


func open_scene(path: String) -> void:
	game = load(path).instantiate()
	root.add_child(game)
	current_scene = game
	player = game.player
	weapon = player.weapon
	camera = player.get_node("Head/Camera3D")
	for actor in game.get_node("Drones").get_children():
		actor.attack_enabled = false
		actor.move_speed = 0
	await frames(8)
	var card: Control = game.get_node("Interface/Overlay/Card")
	check(card.get_viewport_rect().encloses(card.get_global_rect()),"Le menu tient dans la fenêtre avec le clic droit")
	check(card.get_global_rect().encloses(game.get_node("Interface/Overlay/Card/Content/Quit").get_global_rect()),"Tous les boutons du menu restent accessibles")
	check(game.get_node("Interface/Overlay/Card/Content/Controls").text.contains("CLIC DROIT"),"Le menu explique la visée au clic droit")
	var footer: Label = game.get_node("Interface/Footer/Commands")
	check(footer.text.contains("CLIC D.") and footer.get_line_count()==2,"Le rappel de visée tient sur les deux lignes de commandes")
	check(not footer.get_global_rect().intersects(game.get_node("Interface/Footer/PauseHint").get_global_rect()),"Le rappel Échap reste dégagé")


func close_scene() -> void:
	right_button(false)
	mouse_button(false)
	for action in ["aim","fire","sprint","crouch","move_forward","move_right"]: Input.action_release(action)
	for sound in game.find_children("*","AudioStreamPlayer",true,false)+game.find_children("*","AudioStreamPlayer3D",true,false): sound.stop()
	OS.delay_msec(50)
	game.queue_free()
	paused = false
	await frames(4)
	OS.delay_msec(80)


func run() -> void:
	graphics = DisplayServer.get_name()!="headless"
	await open_scene("res://scenes/main.tscn")
	check(camera.fov==78 and weapon.position.is_equal_approx(Vector3(.28,-.24,-.5)),"La vue et la pose au repos sont conservées")
	right_button(true)
	await frames(5)
	check(paused and not weapon.is_aiming and camera.fov==78 and weapon.shots_fired==0,"Le clic droit dans le menu ne zoome pas et ne tire pas")
	game.start_exploration()
	await frames(16)
	check(not weapon.is_aiming and weapon.aim_blend==0,"Un clic droit maintenu dans le menu doit être relâché avant de viser")
	right_button(false)
	await frames(3)
	await put_player(Vector3(5,.05,12))
	var target: StaticBody3D = game.get_node("Arena/Cible02")
	var hip_mouse_yaw: float = 0.0
	if graphics:
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(100,-20)
		var yaw := player.rotation.y
		Input.parse_input_event(motion)
		await frames(3)
		hip_mouse_yaw = absf(player.rotation.y-yaw)
		check(hip_mouse_yaw>0,"La souris tourne normalement la caméra au repos")
	await aim_at(target.to_global(Vector3(0,1.65,0)))
	await snap("visee_repos.png")
	var hip_height: float = 0
	if graphics:
		hip_height = camera.unproject_position(target.to_global(Vector3(0,1.9,0))).distance_to(camera.unproject_position(target.to_global(Vector3(0,1.4,0))))
	right_button(true)
	await frames(1)
	check(Input.is_action_pressed("aim") and weapon.is_aiming and weapon.aim_blend>0 and weapon.aim_blend<1,"Le clic droit commence une transition progressive")
	await frames(16)
	check(weapon.aim_blend==1 and is_equal_approx(camera.fov,58),"Le maintien du clic droit stabilise le zoom à 58 degrés")
	check(weapon.position.is_equal_approx(weapon.aim_position),"La carabine rejoint sa pose de visée centrée")
	var sight: Node3D = weapon.get_node("Model/SightReference")
	var local_sight := camera.to_local(sight.global_position)
	check(absf(local_sight.x)<.0001 and absf(local_sight.y)<.0001 and local_sight.z<0,"Le centre de l'ouverture du viseur est sur l'axe exact de la caméra")
	check(game.reticle.get_node("AimDot").visible and game.reticle.get_node("Left").modulate.a==0,"Un point fin remplace la croix de visée")
	check(is_equal_approx(weapon.look_multiplier(),.65),"La sensibilité est réduite en visée précise")
	check(weapon.shots_fired==0,"Viser seul ne déclenche aucun tir")
	if graphics:
		var zoom_height := camera.unproject_position(target.to_global(Vector3(0,1.9,0))).distance_to(camera.unproject_position(target.to_global(Vector3(0,1.4,0))))
		check(zoom_height>hip_height*1.4,"Le zoom agrandit réellement la cible à l'écran")
		check(camera.unproject_position(sight.global_position).distance_to(root.get_visible_rect().size*.5)<.1,"Le viseur projeté et le point à l'écran coïncident")
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(100,-20)
		var yaw := player.rotation.y
		Input.parse_input_event(motion)
		await frames(3)
		# Comparer au repos tient compte de l'échelle du viewport dans la fenêtre.
		check(is_equal_approx(absf(player.rotation.y-yaw),hip_mouse_yaw*.65),"La vraie souris applique la sensibilité réduite")
		await aim_at(target.to_global(Vector3(0,1.65,0)))
	await snap("visee_precise.png")
	var hits: int = target.times_hit
	var shots: int = weapon.shots_fired
	mouse_button(true)
	await frames(3)
	mouse_button(false)
	check(weapon.shots_fired==shots+1 and target.times_hit==hits+1 and weapon.last_hit.get("collider")==target,"Le clic gauche vise et touche la vraie cible pendant la visée")
	check(weapon.recoil>0 and weapon.model.rotation.x<.025,"Le recul visuel reste plus contenu en visée précise")
	check(weapon.fire_interval==.2 and weapon.max_range==100,"La cadence, les dégâts par impact et la portée restent inchangés")
	var reference: Node3D = weapon.get_node("Model/VisualModel").find_child("MuzzleReference",true,false)
	check(reference.global_position.distance_to(weapon.muzzle.global_position)<.0001,"La bouche du GLB et l'origine des effets restent alignées pendant le tir visé")
	await frames(24)
	target.reset_target()
	await frames(4)
	# Le regard passe au-dessus, mais le canon centré est masqué par cet obstacle.
	var cover := make_blocker(Vector3(5,1.5,11.5),Vector3(.1,.2,.12))
	await frames(4)
	hits = target.times_hit
	mouse_button(true)
	await frames(2)
	mouse_button(false)
	check(weapon.last_hit.get("collider")==cover and target.times_hit==hits,"Un canon masqué ne traverse pas le décor en visée précise")
	cover.queue_free()
	await frames(24)
	right_button(false)
	await frames(1)
	check(not weapon.is_aiming and weapon.aim_blend>0 and weapon.aim_blend<1,"Relâcher le clic droit commence le retour progressif")
	await frames(16)
	check(camera.fov==78 and weapon.position.is_equal_approx(weapon.hip_position) and weapon.look_multiplier()==1,"Relâcher restaure le champ de vision, la pose et la sensibilité")
	check(not game.reticle.get_node("AimDot").visible and game.reticle.get_node("Left").modulate.a==1,"Le réticule normal revient après la visée")
	await put_player(Vector3(0,.05,18))
	right_button(true)
	key_event(KEY_SHIFT,true)
	key_event(KEY_Z,true)
	await frames(35)
	check(weapon.is_aiming and not player.is_sprinting and is_equal_approx(player.velocity.z,-4),"La visée quitte le sprint et réduit le déplacement à 4 m/s")
	key_event(KEY_CTRL,true)
	await frames(15)
	check(player.is_crouching and weapon.is_aiming and is_equal_approx(player.velocity.z,-3) and camera.fov==58,"La visée reste compatible avec la position accroupie")
	key_event(KEY_Z,false)
	key_event(KEY_SHIFT,false)
	key_event(KEY_CTRL,false)
	await frames(16)
	game.show_pause()
	await frames(3)
	check(paused and camera.fov==78 and weapon.aim_blend==0 and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Échap annule le zoom et libère la souris")
	game.start_exploration()
	await frames(16)
	check(not weapon.is_aiming and camera.fov==78,"Reprendre avec le clic droit maintenu n'enclenche pas de visée involontaire")
	right_button(false)
	await frames(3)
	right_button(true)
	await frames(16)
	check(weapon.is_aiming and camera.fov==58,"Un nouveau clic droit fonctionne après la reprise")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(paused and camera.fov==78 and not weapon.is_aiming,"La perte de focus annule également la visée")
	right_button(false)
	game.start_exploration()
	await frames(3)
	right_button(true)
	await frames(16)
	game.restart_exploration()
	await frames(12)
	check(weapon.aim_blend==0 and camera.fov==78 and weapon.position.is_equal_approx(weapon.hip_position),"Recommencer efface la visée même si le clic droit reste tenu")
	right_button(false)
	await frames(3)
	right_button(true)
	await frames(16)
	player.apply_damage(1000)
	check(game.game_over and paused and camera.fov==78 and weapon.aim_blend==0,"La défaite quitte la visée et restaure la caméra")
	await close_scene()
	for path in ["res://missions/relay_run/mission.tscn","res://missions/relay_run/boss_trial.tscn"]:
		await open_scene(path)
		await snap("visee_menu_mission.png")
		game.start_exploration()
		game.boss.attack_enabled = false
		right_button(true)
		await frames(16)
		check(weapon.is_aiming and camera.fov==58 and weapon.aim_blend==1,"La visée fonctionne dans "+path.get_file())
		await snap("visee_"+path.get_file().get_basename()+".png")
		right_button(false)
		await frames(16)
		check(camera.fov==78 and not weapon.is_aiming,"La mission retrouve sa vue normale au relâchement")
		await close_scene()
	print("RESULT: %d aiming checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
