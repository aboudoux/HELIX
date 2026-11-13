extends "res://tests/verify_lunar_escape.gd"
const FIT := preload("res://missions/lunar_escape/block_fit.gd")

func run() -> void:
	if DisplayServer.get_name()!="headless": RenderingServer.render_loop_enabled=false
	teleport_escorts_for_test=false
	game=load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(game);current_scene=game;player=game.pilot
	await frames(5);game.hud.title_card.hide();game.hud.set_film(false);game.camera.make_current()
	game.step=game.Step.BIKE;game.set_physics_process(false)
	for director in game.directors+game.upper_directors+game.road_guards: director.process_mode=Node.PROCESS_MODE_DISABLED
	for actor in game.squad.members: actor.set_physics_process(false)
	player.unlock_weapon("pistol");player.set_control(true)
	var builder: Node3D=game.get_node("Construction")
	var supplies: Node=game.get_node("CabinetLoot")
	check(builder.stock==0,"Nouvelle partie : aucun bloc")
	check(supplies.cabinets.size()>30 and supplies.cabinets.size()==get_nodes_in_group("loot_cabinets").size(),"Tous les placards générés sont ouvrables et enregistrés")
	print("PLACARDS : ",supplies.cabinets.size())
	await put_player(Vector3(0,.05,-70));await tap(KEY_J);aim_at(Vector3(0,0,-75));await frames(3)
	await click(MOUSE_BUTTON_LEFT)
	check(builder.blocks.is_empty() and builder.stock==0,"Le clic ne crée aucun bloc sans stock")
	await tap(KEY_J)
	var id: String=supplies.cabinets.keys()[0]
	var cabinet: Node3D=supplies.cabinets[id]
	await put_player(cabinet.to_global(Vector3(0,.05,cabinet.depth*.5+1.65)))
	aim_at(cabinet.handle.global_position);await frames(3)
	check(game.nearest_interaction()=="cabinet:"+id,"Le placard est proposé avec E à portée")
	check(not supplies.claim(id),"Le contenu ne se récupère pas à travers une porte fermée")
	game.set_physics_process(true);await tap(KEY_E);game.set_physics_process(false)
	check(cabinet.moving,"L'ouverture des portes est animée")
	await frames(34)
	check(cabinet.opened and not cabinet.moving and absf(cabinet.doors[0].rotation.y)>1.5,"Les deux battants s'ouvrent réellement")
	check(not cabinet.taken and cabinet.contents.visible,"Le contenu est visible à l'intérieur avant la récupération")
	if DisplayServer.get_name()!="headless": await capture("placard_ouvert_provisions.png")
	if OS.get_cmdline_user_args().has("--preview-only"):
		finish_run();return
	var expected: Dictionary=cabinet.loot.duplicate(true)
	var ammo: int=player.weapon.reserve_ammo
	game.set_physics_process(true);await tap(KEY_E);game.set_physics_process(false);await frames(3)
	check(cabinet.taken and not cabinet.contents.visible,"Un deuxième E récupère le contenu visible")
	check(builder.stock==expected.blocks and supplies.food==expected.food,"Le placard donne exactement ses blocs et ses rations")
	check(player.weapon.reserve_ammo==ammo+expected.ammo and player.inventory.has(expected.weapon),"Arme et munitions du placard rejoignent l'inventaire")
	var stock: int=builder.stock
	check(not supplies.claim(id) and builder.stock==stock,"Un placard vidé ne duplique pas son butin")
	await supplies.interact(id);await frames(3)
	check(not cabinet.opened,"Le placard vide peut être refermé")
	await supplies.interact(id);await frames(3)
	check(cabinet.opened and cabinet.taken and not cabinet.contents.visible,"Rouvrir un placard vide ne le remplit pas")
	player.health=player.max_health;var food: int=supplies.food
	await tap(KEY_Y);check(supplies.food==food,"Une ration est conservée lorsque la santé est pleine")
	player.health=50;await tap(KEY_Y)
	check(player.health==80 and supplies.food==food-1,"Y consomme une ration et rend 30 points de vie")
	# Real construction after obtaining a finite stock.
	await put_player(Vector3(0,.05,-70));await tap(KEY_J);aim_at(Vector3(0,0,-75));await frames(3)
	await click(MOUSE_BUTTON_LEFT)
	check(builder.blocks.size()==1 and builder.stock==stock-1,"Poser un bloc consomme une unité récupérée")
	aim_at(builder.blocks[0].global_position);await frames(3);await click(MOUSE_BUTTON_RIGHT)
	check(builder.blocks.is_empty() and builder.stock==stock,"Démonter son bloc le rend au stock sans duplication")
	# A sloped piece of real collision geometry forces a trimmed block.
	var support: MeshInstance3D=game.WORLD.block(game.world,Vector3(0,.1,-75),Vector3(5,.25,4),game.WORLD.STEEL,true)
	support.rotation.z=.32;await frames(3)
	aim_at(Vector3(0,.25,-75));await frames(3)
	check(builder.can_place and builder.fitted.size()>0 and builder.fitted.size()<FIT.TOTAL,"La pose découpe le bloc pour s'adapter à une pente")
	var count: int=builder.fitted.size();await click(MOUSE_BUTTON_LEFT)
	check(builder.blocks.size()==1 and builder.blocks[0].get_meta("fit_cells").size()==count,"La forme découpée est celle du bloc posé")
	var cut: StaticBody3D=builder.blocks[0]
	check(cut.get_children().filter(func(n):return n is CollisionShape3D).size()>1,"Les collisions suivent les parties restantes du bloc")
	if DisplayServer.get_name()!="headless":
		aim_at(cut.global_position);await capture("bloc_adapte_pente.png")
	var space:=game.get_world_3d().direct_space_state
	var touch:=support.to_global(Vector3(1.5,.125,0))
	var buried:=FIT.fit(space,touch+Vector3.UP*.3,touch,support.global_basis.y)
	check(buried.size()>0 and buried.size()<FIT.TOTAL,"Un obstacle statique provoque une découpe et non un refus global")
	var wall: MeshInstance3D=game.WORLD.block(game.world,Vector3(3,1.5,-75),Vector3(.25,3,4),game.WORLD.STEEL,true)
	await frames(3);aim_at(Vector3(2.875,1.5,-75));await frames(3)
	check(builder.can_place and builder.fitted.size()>0,"La construction fonctionne aussi contre un mur vertical")
	check(not FIT.valid_cells([0,0]) and not FIT.valid_cells([125]),"Les découpes invalides sont rejetées")
	game.saver.enabled=true;game.saver.path="user://cabinets_fit_test_only.json"
	check(game.saver.write_save(game),"La sauvegarde enregistre les placards, les rations et le stock de blocs")
	var saved: Dictionary=game.saver.read_save()
	check(saved.stash.blocks==builder.stock and saved.stash.cabinets[id].taken and saved.construction[0].cells.size()==count,"Butin unique et forme des blocs sont conservés")
	supplies.food=99;builder.stock=99;cabinet.taken=false
	builder.restore(saved.construction);supplies.restore(saved.stash);await frames(3)
	check(builder.stock==saved.stash.blocks and supplies.food==saved.stash.food and cabinet.taken,"La reprise ne réinitialise ni les quantités ni les placards vidés")
	check(builder.blocks[0].get_meta("fit_cells").size()==count,"La découpe du bloc est restaurée à l'identique")
	var broken: Dictionary=saved.stash.duplicate(true);broken.blocks=-1
	check(not supplies.valid_snapshot(broken),"Un stock négatif est rejeté")
	game.saver.enabled=false
	finish_run()

func click(button: MouseButton) -> void:
	var event:=InputEventMouseButton.new();event.button_index=button;event.pressed=true
	Input.parse_input_event(event);await frames(2)
	event=InputEventMouseButton.new();event.button_index=button;event.pressed=false
	Input.parse_input_event(event);await frames(3)

func capture(filename: String) -> void:
	RenderingServer.render_loop_enabled=true
	await frames(2);await RenderingServer.frame_post_draw
	var folder:=ProjectSettings.globalize_path("res://tests/artifacts")
	DirAccess.make_dir_recursive_absolute(folder)
	check(root.get_texture().get_image().save_png(folder+"/"+filename)==OK,"Capture : "+filename)
	RenderingServer.render_loop_enabled=false
