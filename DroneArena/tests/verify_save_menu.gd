extends "res://tests/verify.gd"
var isolated_path := "user://test_save_menu_%d.json"%OS.get_process_id()

func load_game() -> void:
	game = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	game.saver.path = isolated_path
	game.saver.enabled = true
	root.add_child(game)
	current_scene = game
	player = game.pilot
	await frames(3)

func close_game() -> void:
	game.saver.enabled = false
	for sound in game.find_children("*","AudioStreamPlayer",true,false)+game.find_children("*","AudioStreamPlayer3D",true,false): sound.stop()
	OS.delay_msec(60)
	game.queue_free()
	await frames(4)
	OS.delay_msec(60)

func capture(file: String) -> void:
	if DisplayServer.get_name()=="headless": return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/artifacts"))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/artifacts/"+file)

func run() -> void:
	await load_game()
	check(not game.hud.continue_button.visible,"Le menu neuf ne propose pas une sauvegarde inexistante")
	check(game.hud.intro_backdrop.visible and game.hud.intro_backdrop.size.is_equal_approx(root.get_visible_rect().size),
		"La photo lunaire couvre le menu d’accueil")
	await capture("accueil_lunaire.png")
	game.step = game.Step.HABITAT
	player.unlock_weapon("pistol")
	player.set_control(true)
	game.saver.write_save(game)
	await close_game()
	await load_game()
	check(game.hud.continue_button.visible and game.hud.primary.text=="Nouvelle campagne","Le lancement détecte le fichier et distingue Continuer de Nouvelle campagne")
	check(game.hud.continue_button.has_focus(),"Continuer reçoit le focus lorsqu'une sauvegarde existe")
	await capture("save_menu.png")
	game.hud.continue_button.pressed.emit()
	await frames(20)
	check(game.step==game.Step.HABITAT and player.in_control and not game.hud.title_card.visible,"Le bouton Continuer recharge effectivement la campagne")
	check(not game.hud.intro_backdrop.visible,"La photo disparaît lors de la reprise")
	game.toggle_pause()
	await frames(3)
	check(paused and game.hud.card_copy.text.contains("Progression sauvegardée"),"Le menu de pause confirme la sauvegarde effectuée")
	check(not game.hud.intro_backdrop.visible,"Le menu de pause laisse voir la partie")
	await capture("save_pause.png")
	game.toggle_pause()
	game.saver.clear()
	await close_game()
	print("%d vérifications menu de sauvegarde, %d échec(s)"%[checks,failures])
	quit(1 if failures else 0)
