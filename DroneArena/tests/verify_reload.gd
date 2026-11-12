extends "res://tests/verify.gd"
## Chargeur réel, touche R, limites des tirs et cycle de partie dans les trois modes.

var weapon: Node3D
var graphics: bool


func snap(name: String) -> void:
	if graphics:
		await frames(3)
		await RenderingServer.frame_post_draw
		if "--small" in OS.get_cmdline_user_args():
			name = "small_"+name
		check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tests/artifacts/"+name)) == OK, "Capture " + name)


func release_inputs() -> void:
	mouse_button(false)
	key_event(KEY_R, false)
	for action in ["aim", "move_right", "sprint", "crouch"]:
		Input.action_release(action)


func open_scene(path: String) -> void:
	release_inputs()
	game = load(path).instantiate()
	root.add_child(game)
	current_scene = game
	player = game.player
	weapon = player.weapon
	for drone in game.get_node("Drones").get_children():
		drone.attack_enabled = false
		drone.move_speed = 0
	await frames(5)
	check(weapon.ammo == 30 and weapon.magazine_capacity == 30 and weapon.reload_duration == 1.8, "Chargeur plein au départ : " + path)
	check(not game.get_node("Interface/Ammo").visible, "Compteur masqué dans l'accueil")
	var controls: Label = game.get_node("Interface/Overlay/Card/Content/Controls")
	check(controls.text.contains("Recharger"), "La touche R est expliquée dans le menu")
	var card: Control = game.get_node("Interface/Overlay/Card")
	check(card.get_viewport_rect().encloses(card.get_global_rect()) and card.get_global_rect().encloses(game.get_node("Interface/Overlay/Card/Content/Quit").get_global_rect()), "Le menu et ses boutons tiennent dans la fenêtre")


func close_scene() -> void:
	release_inputs()
	for sound in game.find_children("*", "AudioStreamPlayer", true, false)+game.find_children("*", "AudioStreamPlayer3D", true, false):
		sound.stop()
	OS.delay_msec(50)
	game.queue_free()
	paused = false
	await frames(4)
	OS.delay_msec(80)


func run() -> void:
	graphics = DisplayServer.get_name() != "headless"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/artifacts"))
	await open_scene("res://scenes/main.tscn")
	key_event(KEY_R, true)
	await frames(3)
	check(not weapon.is_reloading and weapon.ammo == 30, "R dans le menu ne recharge pas")
	game.start_exploration()
	await frames(4)
	key_event(KEY_R, false)
	await frames(2)
	await tap(KEY_R)
	check(not weapon.is_reloading and not weapon.reload_sound.playing, "R avec un chargeur plein ne lance ni animation ni son")
	await put_player(Vector3(0,.05,18))
	player.head.rotation.x = deg_to_rad(70)
	var shots: int = weapon.shots_fired
	mouse_button(true)
	await frames(400)
	check(weapon.shots_fired == shots+30 and weapon.ammo == 0, "Le maintien du clic tire exactement les 30 impulsions, puis s'arrête")
	check(not weapon.is_reloading, "Le chargeur vide attend une recharge manuelle avec R")
	check(game.get_node("Interface/Ammo/Count").text == "00 / 30" and game.get_node("Interface/Ammo/Status").text.contains("CHARGEUR VIDE"), "Le HUD signale le chargeur vide")
	await snap("recharge_vide.png")
	await frames(90)
	check(weapon.shots_fired == shots+30 and weapon.ammo == 0, "Attendre à vide ne crée aucun tir ni munition")
	mouse_button(false)
	await frames(3)
	mouse_button(true)
	await frames(2)
	check(weapon.empty_sound.playing and weapon.shots_fired == shots+30, "Un nouveau clic à vide joue le mécanisme sans tirer")
	mouse_button(false)
	await tap(KEY_R)
	check(weapon.is_reloading and weapon.ammo == 0 and weapon.reload_sound.playing, "R démarre le rechargement et son son, sans remplir prématurément")
	Input.action_press("aim")
	mouse_button(true)
	await frames(20)
	check(not weapon.is_aiming and weapon.camera.fov == 78 and weapon.shots_fired == shots+30, "La recharge bloque tirs et visée précise")
	check(weapon.model.position.y < -.04 and absf(weapon.model.rotation.z) > .2, "La carabine s'abaisse et pivote pendant la manipulation")
	mouse_button(false)
	Input.action_release("aim")
	var remaining: float = weapon.reload_remaining
	await tap(KEY_R)
	check(weapon.reload_remaining < remaining, "R répété ne redémarre pas le délai")
	Input.action_press("move_right")
	var origin := player.position
	await frames(15)
	Input.action_release("move_right")
	check(player.position.x > origin.x+.5 and player.velocity.x > 4 and weapon.is_reloading, "Le joueur continue à se déplacer pendant la recharge")
	await snap("recharge_animation.png")
	game.show_pause()
	remaining = weapon.reload_remaining
	var pose: Transform3D = weapon.model.transform
	await frames(45)
	check(weapon.is_reloading and weapon.reload_remaining == remaining and weapon.ammo == 0 and weapon.model.transform == pose, "La pause fige la recharge, les munitions et l'animation")
	check(weapon.reload_sound.stream_paused, "Le son de manipulation est également en pause")
	mouse_button(true)
	key_event(KEY_R, true)
	await frames(3)
	game.start_exploration()
	await frames(130)
	check(not weapon.is_reloading and weapon.ammo == 30 and weapon.shots_fired == shots+30, "Reprendre termine la recharge sans tirer avec le clic maintenu depuis le menu")
	check(weapon.model.transform.is_equal_approx(Transform3D.IDENTITY), "La carabine retrouve sa pose normale après la recharge")
	check(game.get_node("Interface/Ammo/Count").text == "30 / 30", "Le compteur revient à 30 après 1,8 seconde de jeu")
	release_inputs()
	await frames(3)
	mouse_button(true)
	await frames(2)
	mouse_button(false)
	await frames(16)
	check(weapon.ammo == 29 and weapon.shots_fired == shots+31, "Un nouveau clic consomme une impulsion après la reprise")
	Input.action_press("aim")
	await tap(KEY_R)
	check(weapon.is_reloading and weapon.ammo == 29, "Une recharge anticipée fonctionne aussi avec un chargeur partiellement plein")
	await frames(92)
	check(weapon.is_reloading and weapon.ammo == 29, "Le chargeur ne se remplit pas avant la fin des 1,8 seconde")
	await frames(20)
	check(not weapon.is_reloading and weapon.ammo == 30, "La recharge anticipée se termine après 1,8 seconde")
	await frames(12)
	check(weapon.is_aiming and weapon.camera.fov == 58, "Le clic droit maintenu retrouve la visée précise une fois la recharge terminée")
	Input.action_release("aim")
	mouse_button(true)
	await frames(2)
	mouse_button(false)
	await tap(KEY_R)
	await frames(15)
	game.show_pause()
	game.restart_exploration()
	await frames(125)
	check(weapon.ammo == 30 and not weapon.is_reloading and weapon.reload_remaining == 0, "Recommencer annule l'ancienne recharge et restaure un chargeur plein")
	weapon.ammo = 7
	await tap(KEY_R)
	player.apply_damage(1000)
	await frames(3)
	check(game.game_over and not weapon.is_reloading and not weapon.reload_sound.playing and weapon.ammo == 7, "La défaite annule la recharge sans remplir le chargeur")
	game.start_exploration()
	await frames(4)
	check(weapon.ammo == 30 and not weapon.is_reloading, "Une nouvelle partie après défaite redonne 30 impulsions")
	await close_scene()

	await open_scene("res://missions/relay_run/mission.tscn")
	game.start_exploration()
	await frames(4)
	check(game.get_node("Interface/Ammo").visible and game.get_node("Interface/Footer/Commands").text.contains("R Recharger"), "La mission affiche le compteur et le rappel de R")
	var ammo_panel: Control = game.get_node("Interface/Ammo")
	check(ammo_panel.get_viewport_rect().encloses(ammo_panel.get_global_rect()), "Le compteur tient dans la fenêtre")
	for path in ["Interface/MissionHUD/MapPanel", "Interface/MissionHUD/Objective", "Interface/Footer/Commands", "Interface/Footer/PauseHint"]:
		check(not ammo_panel.get_global_rect().intersects(game.get_node(path).get_global_rect()), "Le compteur ne recouvre pas " + path.get_file())
	await snap("recharge_mission.png")
	await close_scene()

	await open_scene("res://missions/relay_run/boss_trial.tscn")
	game.start_exploration()
	var boss: CharacterBody3D = game.boss
	boss.attack_enabled = false
	boss.set_physics_process(false)
	await frames(4)
	await aim_at(boss.global_position)
	shots = weapon.shots_fired
	mouse_button(true)
	await frames(400)
	check(boss.alive and boss.health == 14 and weapon.ammo == 0, "Un chargeur de 30 tirs laisse 14 points de vie au boss Moyen")
	await tap(KEY_R)
	await frames(45)
	check(weapon.is_reloading and boss.health == 14, "Le boss ne reçoit aucun dégât pendant la recharge")
	await snap("recharge_boss.png")
	for tick in range(300):
		await frames(1)
		if not boss.alive:
			break
	mouse_button(false)
	await frames(5)
	check(not boss.alive and weapon.shots_fired == shots+44 and weapon.ammo == 16, "Après recharge, les tirs maintenus reprennent et les 44 impacts neutralisent le boss")
	await frames(85)
	await put_player(Vector3(0,.05,-90))
	await frames(65)
	await tap(KEY_R)
	await frames(75)
	check(game.mission_complete and paused and not weapon.is_reloading and not weapon.reload_sound.playing, "La victoire annule une recharge en cours")
	game.start_exploration()
	await frames(4)
	check(weapon.ammo == 30 and not weapon.is_reloading, "Rejouer le boss restaure aussi son chargeur")
	await close_scene()
	print("RESULT: %d reload checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
