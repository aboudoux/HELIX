extends SceneTree
## Vérifications du vrai projet : physique, commandes, pause et reprise.
## --headless --path DroneArena --script res://tests/verify.gd --fixed-fps 60

var failures: int = 0
var checks: int = 0
var game: Node3D
var player: CharacterBody3D
var difficulty: Node


func _initialize() -> void:
	call_deferred("prepare_tests")


func prepare_tests() -> void:
	# Les suites historiques vérifient le niveau Moyen indépendamment du choix sauvegardé.
	difficulty = root.get_node("Difficulty")
	difficulty.selected = 1
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)


func frames(count: int) -> void:
	for i in count:
		await physics_frame
	await process_frame


func key_event(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)


func mouse_button(pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = root.get_visible_rect().size * 0.5
	Input.parse_input_event(event)


func tap(code: Key) -> void:
	key_event(code, true)
	await frames(2)
	key_event(code, false)
	await frames(2)


func put_player(position: Vector3) -> void:
	player.global_position = position
	player.rotation = Vector3.ZERO
	player.head.rotation = Vector3.ZERO
	player.velocity = Vector3.ZERO
	await frames(8)


func capture(filename: String) -> void:
	await frames(12)
	await RenderingServer.frame_post_draw
	var prefix := "petite_" if "--small" in OS.get_cmdline_user_args() else ""
	var path := ProjectSettings.globalize_path("res://tests/artifacts/" + prefix + filename)
	var result := root.get_texture().get_image().save_png(path)
	check(result == OK, "Capture " + filename)


func run() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		push_error("Impossible de charger main.tscn")
		quit(1)
		return
	game = packed.instantiate()
	# Cette suite garde les commandes et le tir isolés de la rencontre ennemie.
	# verify_combat.gd vérifie séparément les drones et les dégâts réels.
	game.get_node("Drones").process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(game)
	current_scene = game
	player = game.get_node("Player")
	await frames(5)
	check(paused, "Accueil en pause")
	check(game.overlay.visible and not game.reticle.visible, "Accueil visible, réticule caché")
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Souris libre à l'accueil")
	check(game.resume_button.has_focus(), "Bouton principal accessible au clavier")
	var graphics := DisplayServer.get_name() != "headless"
	if graphics:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/artifacts"))
		await capture("accueil.png")
	mouse_button(true)
	await frames(4)
	check(player.weapon.shots_fired == 0, "Aucun tir dans l'accueil")
	game.resume_button.pressed.emit()
	await frames(20)
	check(player.weapon.shots_fired == 0, "Le clic sur Entrer ne tire pas")
	mouse_button(false)
	await frames(2)
	check(not paused and not game.overlay.visible, "Bouton Entrer : reprise du jeu")
	if graphics:
		check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Souris capturée pendant l'exploration")
	check(player.is_on_floor() and absf(player.position.y) < 0.08, "Personnage posé sur le sol")
	if graphics:
		await capture("arene.png")
	if "--capture-only" in OS.get_cmdline_user_args():
		await tap(KEY_ESCAPE)
		check(paused and game.overlay.visible, "Pause ouverte en fenêtre de contrôle")
		await capture("pause.png")
		# La taille et la position globales garantissent que la carte et ses boutons
		# restent dans la zone visible, y compris à la résolution minimale.
		var card: Control = game.get_node("Interface/Overlay/Card")
		var screen := card.get_viewport_rect()
		check(screen.encloses(card.get_global_rect()), "Menu de pause entièrement dans la fenêtre")
		var quit_button: Control = game.get_node("Interface/Overlay/Card/Content/Quit")
		check(screen.encloses(quit_button.get_global_rect()), "Dernier bouton entièrement visible")
		quit(1 if failures else 0)
		return
	await verify_weapon(graphics)

	# Les événements traversent le vrai InputMap : AZERTY et QWERTY.
	for code in [KEY_Z, KEY_W]:
		await put_player(Vector3(0, 0.05, 18))
		key_event(code, true)
		await frames(30)
		key_event(code, false)
		check(player.position.z < 16, "Avancer avec " + OS.get_keycode_string(code))
	for code in [KEY_Q, KEY_A]:
		await put_player(Vector3(0, 0.05, 18))
		key_event(code, true)
		await frames(30)
		key_event(code, false)
		check(player.position.x < -2, "Gauche avec " + OS.get_keycode_string(code))
	await put_player(Vector3(0, 0.05, 18))
	key_event(KEY_D, true)
	await frames(30)
	key_event(KEY_D, false)
	check(player.position.x > 2, "Droite avec D")
	await put_player(Vector3(0, 0.05, 18))
	key_event(KEY_S, true)
	await frames(30)
	key_event(KEY_S, false)
	check(player.position.z > 20, "Reculer avec S")

	await put_player(Vector3(0, 0.05, 18))
	key_event(KEY_Z, true)
	await frames(20)
	var straight_speed := Vector2(player.velocity.x, player.velocity.z).length()
	key_event(KEY_D, true)
	await frames(20)
	check(Vector2(player.velocity.x, player.velocity.z).length() <= straight_speed + 0.05, "Diagonale sans accélération supplémentaire")
	key_event(KEY_Z, false)
	key_event(KEY_D, false)

	await put_player(Vector3(0, 0.05, 18))
	key_event(KEY_SPACE, true)
	await frames(12)
	key_event(KEY_SPACE, false)
	check(player.position.y > 0.7, "Saut avec Espace")
	await frames(65)
	check(player.is_on_floor() and absf(player.position.y) < 0.08, "Retour au sol après le saut")

	# Trajets dégagés vers chacun des quatre murs.
	for item in [
		[Vector3(0, 0.05, 20), KEY_D, 0, 19.2],
		[Vector3(0, 0.05, 20), KEY_Q, 0, -19.2],
		[Vector3(16, 0.05, 18), KEY_Z, 2, -23.2],
		[Vector3(0, 0.05, 18), KEY_S, 2, 23.2]
	]:
		await put_player(item[0])
		key_event(item[1], true)
		await frames(500)
		key_event(item[1], false)
		var coordinate: float = player.position[item[2]]
		check(absf(coordinate - item[3]) < 0.25, "Mur bloque le trajet " + OS.get_keycode_string(item[1]))
		check(player.is_on_floor(), "Pas de chute au bord de l'arène")

	await put_player(Vector3(8, 0.05, 13))
	key_event(KEY_Z, true)
	await frames(100)
	key_event(KEY_Z, false)
	check(player.position.z > 9.7 and player.position.z < 10.0, "Collision avec un obstacle")
	await put_player(Vector3(0, 0.05, 18))
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(100, -100000)
	if graphics:
		var initial_yaw := player.rotation.y
		Input.parse_input_event(motion)
		await frames(3)
		check(player.rotation.y < initial_yaw, "La souris fait tourner le personnage")
		check(is_equal_approx(player.head.rotation_degrees.x, 85.0), "Vue verticale limitée à 85 degrés")
	else:
		print("SKIP: capture souris et visée réservées au test avec fenêtre native")
	await tap(KEY_ESCAPE)
	check(paused and game.overlay.visible, "Échap ouvre la pause")
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Échap libère la souris")
	var frozen := player.global_transform
	key_event(KEY_Z, true)
	key_event(KEY_SPACE, true)
	Input.parse_input_event(motion)
	await frames(20)
	key_event(KEY_Z, false)
	key_event(KEY_SPACE, false)
	check(player.global_transform.is_equal_approx(frozen), "Déplacement et rotation figés pendant la pause")
	game.resume_button.pressed.emit()
	await frames(2)
	check(not paused, "Bouton Reprendre fonctionnel")
	if graphics:
		check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Reprendre capture à nouveau la souris")
	await tap(KEY_ESCAPE)
	await tap(KEY_ESCAPE)
	check(not paused, "Échap permet aussi de reprendre")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await frames(2)
	check(paused and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Perte de focus : pause et souris libre")
	game.reset_button.pressed.emit()
	await frames(8)
	check(player.position.distance_to(Vector3(0, 0, 18)) < 0.1, "Bouton Revenir au départ : position réinitialisée")
	check(player.rotation.is_zero_approx() and player.head.rotation.is_zero_approx(), "Retour au départ : visée réinitialisée")
	player.position.y = -20
	await frames(8)
	check(player.position.distance_to(Vector3(0, 0, 18)) < 0.1, "Filet de sécurité si chute hors du décor")
	print("RESULT: %d checks, %d failures" % [checks, failures])
	# Laisser le mixeur audio libérer les voix avant de fermer le moteur.
	for sound in game.find_children("*", "AudioStreamPlayer", true, false)+game.find_children("*", "AudioStreamPlayer3D", true, false):
		sound.stop()
	OS.delay_msec(50)
	game.queue_free()
	paused = false
	await frames(4)
	OS.delay_msec(80)
	quit(1 if failures else 0)


func aim_at(point: Vector3) -> void:
	player.look_at(Vector3(point.x, player.global_position.y, point.z))
	player.head.look_at(point)
	await frames(3)


func make_blocker(position: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	game.get_node("Arena").add_child(body)
	body.global_position = position
	return body


func verify_weapon(graphics: bool) -> void:
	var weapon: Node3D = player.weapon
	var target: StaticBody3D = game.get_node("Arena/Cible02")
	check(get_nodes_in_group("training_targets").size() == 4, "Quatre cibles d'entraînement")
	await put_player(Vector3(5, 0.05, 12))
	await aim_at(target.to_global(Vector3(0, 1.65, 0)))
	if graphics:
		await capture("arme.png")
	var shots: int = weapon.shots_fired
	var hits: int = target.times_hit
	mouse_button(true)
	await frames(2)
	check(weapon.shots_fired == shots + 1, "Un clic produit un tir")
	check(weapon.last_hit.get("collider") == target, "Le rayon atteint la cible visée au centre")
	check(not target.active and target.times_hit == hits + 1, "La cible touchée devient inactive")
	check(game.target_hits == 1, "Le compteur reflète la cible touchée")
	check(game.hit_feedback_time > 0.0, "Confirmation visuelle de touche")
	check(weapon.flash.visible and weapon.recoil > 0.0, "Flash et recul déclenchés")
	check(weapon.shot_sound.playing and weapon.hit_sound.playing, "Sons de tir et de touche lancés")
	if graphics:
		await RenderingServer.frame_post_draw
		var shot_image := root.get_texture().get_image()
		check(shot_image.save_png(ProjectSettings.globalize_path("res://tests/artifacts/tir.png")) == OK, "Capture d'un tir")
	await frames(6)
	check(weapon.shots_fired == shots + 1, "La cadence empêche un second tir immédiat")
	await frames(55)
	check(weapon.shots_fired >= shots + 5 and weapon.shots_fired <= shots + 6, "Maintien du clic : rafale limitée à cinq tirs par seconde")
	check(target.times_hit == hits + 1 and game.target_hits == 1, "Une cible rabattue n'est pas comptée plusieurs fois")
	mouse_button(false)
	await frames(18)
	shots = weapon.shots_fired
	await frames(10)
	check(weapon.shots_fired == shots, "Relâcher arrête les tirs")
	await tap(KEY_ESCAPE)
	var remaining: float = target.recovery_remaining
	mouse_button(true)
	await frames(20)
	check(weapon.shots_fired == shots, "Impossible de tirer pendant la pause")
	check(is_equal_approx(target.recovery_remaining, remaining), "Pause : délai des cibles figé")
	game.resume_button.pressed.emit()
	await frames(16)
	check(weapon.shots_fired == shots, "Reprendre avec le clic maintenu ne tire pas")
	mouse_button(false)
	await frames(130)
	check(target.active and not target.hit_shape.disabled, "La cible se relève et redevient touchable")
	mouse_button(true)
	await frames(2)
	mouse_button(false)
	check(weapon.shots_fired == shots + 1 and not target.active, "Un nouveau clic fonctionne après la reprise")
	await frames(130)

	# Une paroi ajoutée dans le vrai monde physique protège la cible derrière elle.
	var wall := make_blocker(Vector3(5, 1.5, 8), Vector3(2, 3, 0.4))
	await frames(3)
	hits = target.times_hit
	mouse_button(true)
	await frames(2)
	mouse_button(false)
	check(weapon.last_hit.get("collider") == wall, "Le tir s'arrête au premier obstacle")
	check(target.active and target.times_hit == hits, "Impossible de toucher à travers un mur")
	wall.queue_free()
	await frames(16)

	# Le réticule voit la cible, mais le canon dépasse derrière ce petit obstacle.
	var cover := make_blocker(Vector3(5.14, 1.55, 11.5), Vector3(0.1, 0.2, 0.12))
	await frames(3)
	mouse_button(true)
	await frames(2)
	mouse_button(false)
	check(weapon.last_hit.get("collider") == cover, "Un canon derrière un obstacle ne traverse pas la paroi")
	check(target.active and target.times_hit == hits, "La cible reste intacte lorsque le canon est masqué")
	cover.queue_free()
	await frames(16)

	player.head.rotation.x = deg_to_rad(70)
	await frames(3)
	shots = weapon.shots_fired
	mouse_button(true)
	await frames(2)
	mouse_button(false)
	check(weapon.shots_fired == shots + 1 and weapon.last_hit.is_empty(), "Tirer dans le ciel fonctionne sans collision")
	await frames(30)
	check(game.get_node("Effects").get_child_count() == 0, "Les effets sont libérés automatiquement")
	await tap(KEY_ESCAPE)
	game.reset_button.pressed.emit()
	await frames(8)
	check(game.target_hits == 0 and target.active, "Revenir au départ réinitialise les touches et les cibles")
	check(weapon.last_hit.is_empty() and weapon.recoil == 0.0, "Revenir au départ réinitialise l'arme")
