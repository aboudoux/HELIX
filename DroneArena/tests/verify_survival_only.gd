extends "res://tests/verify_lunar_escape.gd"

func run() -> void:
	teleport_escorts_for_test=false
	game=load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(game);current_scene=game;player=game.pilot
	await frames(5)
	check(game.hud.title_card.find_children("*","Button",true,false).filter(func(button): return button.is_visible_in_tree()).size()==1,"L'accueil d'une nouvelle partie propose la campagne de survie")
	game.hud.title_card.hide();game.hud.set_film(false);game.camera.make_current()
	game.step=game.Step.HABITAT;game.set_physics_process(false)
	for director in game.directors+game.upper_directors: director.process_mode=Node.PROCESS_MODE_DISABLED
	player.unlock_weapon("pistol");player.set_control(true)
	await put_player(Vector3(0,.05,14))
	var start: Vector3=player.global_position
	var mask: int=player.collision_mask
	var door: Node3D=game.world.doors["bedroom"]
	door.lock()
	for key in [KEY_F12,KEY_F1,KEY_F2,KEY_F3,KEY_F4,KEY_F5,KEY_F8,KEY_4,KEY_P,KEY_L,KEY_M,KEY_K]:
		await tap(key)
	for key in [KEY_P,KEY_L,KEY_M,KEY_K]: key_event(key,true)
	await frames(3)
	for key in [KEY_P,KEY_L,KEY_M,KEY_K]: key_event(key,false)
	check(player.inventory.keys()==["pistol"] and player.equipped=="pistol","Les anciens raccourcis ne débloquent aucune arme")
	check(player.collision_mask==mask and player.global_position.distance_to(start)<.25,"F12 et les touches de voyage conservent les collisions et la position")
	check(door.secured and door.leaves.all(func(leaf): return leaf.visible),"Les portes verrouillées gardent leurs battants")
	player.hurt_cooldown=0
	check(player.apply_damage(10),"Le joueur reste vulnérable")
	await tap(KEY_I)
	check(not game.equipment_room.window.visible and not player.loadout.unlocked,"L'inventaire à deux mains attend l'armurerie")
	var rounds: int=player.weapon.ammo
	Input.action_press("fire");await frames(2);Input.action_release("fire")
	check(player.weapon.ammo==rounds-1,"Le tir consomme une cartouche")
	game.toggle_pause()
	var pause_buttons: Array=game.hud.title_card.find_children("*","Button",true,false).filter(func(button): return button.is_visible_in_tree())
	check(paused and pause_buttons.size()==2 and pause_buttons.has(game.hud.primary) and pause_buttons.has(game.hud.secondary),"La pause propose uniquement de reprendre ou recommencer")
	game.toggle_pause()
	game.saver.enabled=true;game.saver.path="user://survival_validation_%d.json"%OS.get_process_id()
	check(game.saver.write_save(game),"Le point sûr est sauvegardé")
	var saved: Dictionary=game.saver.read_save()
	saved.inventory.infinity={"loaded":1,"reserve":1};saved.equipped="infinity"
	saved.loadout={"unlocked":true,"active":true,"right":"infinity","left":"pistol","armor":2,"reserves":{}}
	check(game.saver.store_data(saved),"La sauvegarde au format précédent est reconnue")
	var restored: Dictionary=game.saver.read_save()
	check(not restored.inventory.has("infinity") and restored.equipped=="pistol" and not restored.has("loadout"),"Le chargement retire l'arme et l'accès prématuré à l'inventaire")
	check(game.saver.restore(game,saved) and player.equipped=="pistol" and not player.loadout.unlocked,"La reprise applique les règles de survie et conserve le point sûr")
	check(game.step==game.Step.HABITAT and player.weapon.ammo==rounds-1,"Le chapitre et le chargeur du pistolet sont conservés")
	saved.stage=game.Step.CONTROL
	var late: Dictionary=game.saver.survival_data(saved)
	check(late.loadout.right=="pistol" and late.loadout.left=="pistol","À Copernic, la migration préserve la deuxième main")
	game.saver.clear();game.saver.enabled=false
	await finish_run()
