extends "res://tests/verify_lunar_escape.gd"

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
	player.loadout.unlocked=true;player.loadout.configure("pistol","pistol",0)
	await put_player(Vector3(0,.05,-70))
	var builder: Node3D=game.get_node("Construction")
	# Stocked fixture; acquisition and zero-stock rules are covered by verify_cabinets_fit.
	builder.stock=16
	await tap(KEY_J);aim_at(Vector3(0,0,-75));await frames(4)
	check(builder.active and player.building and builder.preview.visible and builder.can_place,"J ouvre la construction avec un aperçu valide sur le sol")
	check(not player.weapon.visible and not player.loadout.offhand.visible,"Les deux armes sont rangées pendant la construction")
	var ammo: int=player.weapon.ammo;var left_ammo: int=player.loadout.offhand.ammo
	await click(MOUSE_BUTTON_LEFT)
	check(builder.blocks.size()==1,"Un clic gauche pose un vrai bloc")
	var first: StaticBody3D=builder.blocks[0]
	var origin:=first.global_position
	check(not builder.placement_allowed(origin),"Deux blocs ne peuvent pas occuper la même place")
	check(not builder.placement_allowed(player.global_position+Vector3.UP*.9),"La pose refuse le volume du joueur")
	aim_at(origin+Vector3.UP*.75);await frames(4)
	check(builder.can_place and builder.candidate.y>origin.y+1.4,"Viser le dessus propose un empilement aligné")
	await click(MOUSE_BUTTON_LEFT)
	check(builder.blocks.size()==2 and is_equal_approx(builder.blocks[1].position.y-origin.y,1.5),"Les blocs s'empilent sans espace")
	var upper: StaticBody3D=builder.blocks[1]
	aim_at(upper.global_position);await frames(3);await click(MOUSE_BUTTON_RIGHT)
	check(builder.blocks.size()==1 and is_instance_valid(first),"Clic droit détruit uniquement le bloc sélectionné")
	check(player.weapon.ammo==ammo and player.loadout.offhand.ammo==left_ammo,"Poser et détruire ne consomme aucune munition des deux mains")
	await tap(KEY_N);aim_at(Vector3(3,0,-75));await frames(4);await click(MOUSE_BUTTON_LEFT)
	check(builder.blocks.size()==2 and builder.blocks[1].get_meta("build_kind")==1,"N sélectionne un autre matériau réellement appliqué")
	var count: int=builder.blocks.size()
	paused=true;await click(MOUSE_BUTTON_LEFT);await frames(3)
	check(builder.blocks.size()==count and not builder.preview.visible,"La pause interdit toute modification et masque l'aperçu")
	paused=false;await frames(3)
	check(builder.blocks.size()==count,"Aucun clic reçu pendant la pause n'est rejoué")
	# A physical capsule must stop on the constructed block.
	await put_player(Vector3(origin.x,.05,origin.z+3.5));player.rotation.y=0
	Input.action_press("move_forward");await frames(65);Input.action_release("move_forward");await frames(5)
	check(player.position.z>origin.z+1.0 and player.position.z<origin.z+1.3,"Le bloc bloque réellement le déplacement du joueur")
	await put_player(Vector3(0,.05,-70));aim_at(Vector3(0,0,-75));await frames(3)
	if DisplayServer.get_name()!="headless": await capture("construction_blocs_apercu.png")
	var data: Array=builder.snapshot()
	check(builder.valid_snapshot(data),"Le plan construit est sérialisable")
	check(not builder.valid_snapshot([{"position":[0,INF,0],"kind":0}]) and not builder.valid_snapshot([{"position":[0,0,0],"kind":3}]),"Les coordonnées et matériaux invalides sont rejetés")
	check(not builder.valid_snapshot([data[0],data[0]]),"Les doublons de sauvegarde sont rejetés")
	game.saver.enabled=true;game.saver.path="user://construction_test_only.json"
	check(game.saver.write_save(game),"La sauvegarde de campagne contient les constructions")
	var saved: Dictionary=game.saver.read_save()
	var equivalent: bool=saved.construction.size()==data.size()
	for i in range(data.size()):
		var p: Array=saved.construction[i].position
		var q: Array=data[i].position
		equivalent=equivalent and Vector3(p[0],p[1],p[2]).is_equal_approx(Vector3(q[0],q[1],q[2])) and int(saved.construction[i].kind)==data[i].kind
	check(equivalent,"Positions et matériaux sont conservés dans le fichier")
	builder.restore([]);await frames(3);builder.restore(saved.construction);await frames(3)
	check(builder.blocks.size()==2 and builder.snapshot()==data,"Le chargement reconstruit les blocs avec leurs collisions")
	await tap(KEY_J)
	await put_player(Vector3(0,.1,-70));aim_at(Vector3(-3,0,-75));await frames(4);await click(MOUSE_BUTTON_LEFT)
	check(builder.blocks.size()==3,"La construction reprend après le chargement")
	var updated: Dictionary=game.saver.read_save()
	check(updated.construction.size()==3 and updated.stage==saved.stage and updated.clearance==saved.clearance,"Construire sauvegarde le plan sans modifier la progression")
	aim_at(Vector3(12,8,-70));await frames(3);await click(MOUSE_BUTTON_RIGHT)
	check(builder.blocks.size()==3,"Un clic dans le vide ne détruit aucun décor")
	await tap(KEY_J);await frames(4)
	check(not builder.active and not player.weapon.tool_blocked and not player.loadout.offhand.tool_blocked,"J rend les deux armes utilisables")
	Input.action_press("fire");await frames(2);Input.action_release("fire");await frames(4)
	check(player.weapon.ammo==ammo-1,"Le tir normal fonctionne après la construction")
	await tap(KEY_J)
	await put_player(game.world.doors["habitat_entry"].global_position+Vector3(0,.05,2))
	builder.contact=game.world.doors["habitat_entry"].global_position;builder.contact_normal=Vector3.BACK
	check(builder.placement_allowed(builder.contact+Vector3.UP*.75),"La pose découpe le bloc près d'une porte au lieu d'interdire la zone")
	var actual_before: int=builder.blocks.size();builder.target=null
	check(not builder.remove_target() and builder.blocks.size()==actual_before,"Le retrait ne détruit jamais un bâtiment de mission")
	builder.create_block(game.camera.global_position,0);await frames(3)
	await click(MOUSE_BUTTON_RIGHT)
	check(builder.blocks.size()==actual_before,"Un bloc qui entoure la caméra reste démontable de l'intérieur")
	player.set_control(false);await frames(3)
	check(not builder.active and not player.building,"Une cinématique ou une défaite ferme le mode construction")
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
