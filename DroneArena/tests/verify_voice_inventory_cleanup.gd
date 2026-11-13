extends "res://tests/verify_lunar_escape.gd"

func run() -> void:
	# Advance functional checks without rendering hundreds of redundant GPU frames.
	# The player's running game may share the graphics card during this test.
	if DisplayServer.get_name()!="headless": RenderingServer.render_loop_enabled=false
	teleport_escorts_for_test=false
	game=load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(game);current_scene=game;player=game.pilot
	await frames(5);game.hud.title_card.hide();game.hud.set_film(false);game.camera.make_current()
	game.step=game.Step.HABITAT;game.set_physics_process(false)
	for director in game.directors+game.upper_directors+game.road_guards: director.process_mode=Node.PROCESS_MODE_DISABLED
	for actor in game.squad.members: actor.set_physics_process(false)
	player.unlock_weapon("pistol");player.set_control(true)
	var report: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://audio/voice/synthesis.json"))
	check(report.voice=="fr-FR-VivienneMultilingualNeural","Les huit répliques utilisent réellement la nouvelle voix Vivienne")
	for entry in report.clips:
		var clip: AudioStreamWAV=load("res://audio/voice/"+entry.key+".wav")
		check(clip.mix_rate==24000 and absf(clip.get_length()-float(entry.seconds))<.01 and entry.peak<.999,"Nouveau WAV importé, complet et sans saturation : "+entry.key)
	var duration: float=game.voice.play_line(game.voice.LINES.arrival)
	check(is_equal_approx(duration,game.voice.stream.get_length()+.25),"Les sous-titres suivent la durée de la nouvelle voix")
	paused=true;await frames(4);check(game.voice.stream_paused,"La pause suspend la nouvelle voix")
	paused=false;await frames(4);check(not game.voice.stream_paused,"La voix reprend après la pause");game.voice.stop()
	var signs:=0;var clean:=true
	for node in game.find_children("*","Label3D",true,false):
		if node.get_meta("decorative_sign",false): signs+=1;clean=clean and not node.is_visible_in_tree()
	check(signs>100 and clean,"Les écriteaux flottants sont retirés des trois bases")
	var room: Node3D=game.world.get_node("Selene/Chambre1")
	var cards:=room.get_children().filter(func(n):return n is MeshInstance3D and n.position.distance_to(Vector3(5.8,1.2,2.1))<.01)
	check(cards.is_empty(),"Le cadre décoratif suspendu devant l'armoire est supprimé")
	check(room.get_children().any(func(n):return n.get_meta("screen_support",false)),"L'écran du bureau dispose d'un support physique")
	await put_player(room.global_position+Vector3(7,.045,4));aim_at(room.global_position+Vector3(0,1.4,-3))
	if DisplayServer.get_name()!="headless": await capture("chambre_sans_ecriteaux.png")
	game.set_physics_process(true)
	await tap(KEY_I);check(not paused and not game.equipment_room.window.visible,"Avant l'armurerie, le jeu normal conserve la progression des équipements")
	game.set_physics_process(false)
	game.step=game.Step.CONTROL
	await put_player(game.equipment_room.terminal.global_position+Vector3(0,.05,1.8))
	check(game.nearest_interaction()=="equipment_room","Le terminal de Copernic est à portée")
	game.interact("equipment_room")
	check(paused and game.equipment_room.window.visible,"L'armurerie ouvre l'inventaire des deux mains")
	game.equipment_room.preset_buttons[1].pressed.emit();await frames(4)
	var gear: Node=player.loadout
	check(gear.left=="pistol" and gear.right=="pistol" and gear.offhand.is_visible_in_tree() and player.weapon.is_visible_in_tree(),"Le bouton Deux pistolets équipe réellement les deux mains")
	check(game.armor_worn and game.clearance[2],"La visite à l'armurerie valide l'armure de la campagne")
	await put_player(WORLD.at(2,0,.05,14))
	var right_ammo: int=player.weapon.ammo;var left_ammo: int=gear.offhand.ammo
	Input.action_press("fire");await frames(2);Input.action_release("fire");await frames(3)
	check(player.weapon.ammo==right_ammo-1 and gear.offhand.ammo==left_ammo,"Clic gauche tire uniquement le pistolet droit")
	Input.action_press("aim");await frames(2);Input.action_release("aim");await frames(3)
	check(gear.offhand.ammo==left_ammo-1 and not player.weapon.is_aiming,"Clic droit tire réellement le pistolet gauche")
	gear.offhand.ammo=0;gear.offhand.reserve_ammo=3
	await tap(KEY_R);await frames(85)
	check(gear.offhand.ammo==3 and gear.offhand.reserve_ammo==0,"R recharge la main gauche en utilisant la réserve")
	if DisplayServer.get_name()!="headless": await capture("inventaire_deux_pistolets.png")
	await tap(KEY_I);game.equipment_room.preset_buttons[0].pressed.emit();await frames(3)
	Input.action_press("aim");await frames(3)
	check(player.shielding and player.shield_visual.is_visible_in_tree(),"Le bouclier de main gauche fonctionne")
	Input.action_release("aim");await frames(3)
	await tap(KEY_I);game.equipment_room.preset_buttons[2].pressed.emit();await frames(3)
	check(gear.left=="sabre" and gear.melee_left.is_visible_in_tree(),"Le sabre peut remplacer le pistolet gauche")
	await tap(KEY_I)
	game.equipment_room.preset_buttons[1].pressed.emit();await frames(3)
	check(gear.offhand.ammo==3 and gear.offhand.reserve_ammo==0,"Les changements d'équipement conservent les munitions de la main gauche")
	await tap(KEY_I)
	check(paused and game.equipment_room.window.visible,"L'inventaire acquis reste accessible avec I dans le jeu normal")
	if DisplayServer.get_name()!="headless": await capture("inventaire_choix_deux_mains.png")
	await tap(KEY_I);check(not paused and player.in_control,"I referme l'inventaire et rend le contrôle")
	var saved: Dictionary=gear.snapshot();gear.configure("pistol","none",0);gear.restore(saved);await frames(3)
	check(gear.left=="pistol" and gear.offhand.ammo==3,"La sauvegarde de l'équipement conserve la deuxième arme et ses cartouches")
	await finish_run()

func capture(filename: String) -> void:
	RenderingServer.render_loop_enabled=true
	await frames(2)
	await RenderingServer.frame_post_draw
	var path:=ProjectSettings.globalize_path("res://tests/artifacts/"+filename)
	check(root.get_texture().get_image().save_png(path)==OK,"Capture "+filename)
	RenderingServer.render_loop_enabled=false
