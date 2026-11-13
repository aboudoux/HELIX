extends "res://tests/verify_lunar_escape.gd"

func run() -> void:
	teleport_escorts_for_test=false
	game=load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(game);current_scene=game;player=game.pilot
	await frames(5)
	game.hud.title_card.hide();game.set_physics_process(false)
	for director in game.directors+game.upper_directors: director.process_mode=Node.PROCESS_MODE_DISABLED
	player.set_control(false)
	var space:=game.get_world_3d().direct_space_state
	for base in range(3):
		var gaps: Array[String]=[]
		for x in [-32,-25,-18,-10,0,10,18,25,32]:
			for z in [-17.5,-10.0,0.0,10.0,17.5]:
				var origin:=WORLD.at(base,x,3.7,z)
				var up:=space.intersect_ray(PhysicsRayQueryParameters3D.create(origin,origin+Vector3.UP*24,1))
				if up.is_empty(): gaps.append(str(Vector2(x,z)))
		check(gaps.is_empty(),"Base %d : couverture de 45 points du rez-de-chaussée, ouvertures %s"%[base+1,str(gaps)])
		gaps.clear()
		for x in [-12,-5,3,10,17,25,32]:
			for z in [-15,-5,5,11]:
				var origin:=WORLD.at(base,x,WORLD.UPPER_HEIGHT+3.7,z)
				var up:=space.intersect_ray(PhysicsRayQueryParameters3D.create(origin,origin+Vector3.UP*24,1))
				if up.is_empty(): gaps.append(str(Vector2(x,z)))
		check(gaps.is_empty(),"Base %d : couverture des pièces à l'étage, ouvertures %s"%[base+1,str(gaps)])
	var shell_count:=0
	for shell in get_nodes_in_group("pressure_hulls"):
		for mesh in shell.find_children("*","MeshInstance3D",true,false):
			if mesh.material_override is ShaderMaterial and mesh.material_override.shader==WORLD.FINISH.SHELL:
				shell_count+=1
	check(shell_count>=20,"Les coques conservent un matériau visible des deux côtés : "+str(shell_count))
	var example:=WORLD.FINISH.material(WORLD.WHITE)
	check(example.get_shader_parameter("scan_albedo")==WORLD.FINISH.PHOTO.PAINT,"Les panneaux utilisent la photographie de métal")
	check(player.avatar.cloth.get_shader_parameter("fabric_height")==WORLD.FINISH.PHOTO.CLOTH_HEIGHT,"Le corps utilise le relief du tissu photographié")
	var photographed_parts:=0
	for mesh in game.tutorial_drone.find_children("*","MeshInstance3D",true,false):
		var mat: Material=mesh.get_active_material(0)
		if mat is ShaderMaterial and mat.shader==WORLD.FINISH.SURFACE:
			var color_map: Texture2D = mat.get_shader_parameter("scan_albedo")
			if color_map in [WORLD.FINISH.PHOTO.PAINT,WORLD.FINISH.RESEARCH.METAL_COLOR,WORLD.FINISH.RESEARCH.RUBBER_COLOR]:
				photographed_parts+=1
	check(photographed_parts>=5,"Le drone utilise les cartes photographiques sur ses pièces : "+str(photographed_parts))
	if DisplayServer.get_name()!="headless":
		game.begin_film(Vector3(3,6,65),Vector3(0,6,0));await capture("pression_facade.png")
		game.frame_camera(Vector3(36,24,38),Vector3(0,6,0));await capture("pression_toitures.png")
		game.frame_camera(Vector3(0,7,9),Vector3(0,13,-8));await capture("pression_interieur.png")
		game.frame_camera(Vector3(35,5,55),Vector3(24.5,4,39));await capture("pression_verre.png")
		game.frame_camera(Vector3(2.2,3.1,13.8),Vector3(.7,2.4,11.9));await capture("pression_drone.png")
		game.end_film();game.hud.set_film(false);game.camera.make_current()
		await put_player(Vector3(4,.045,11));player.unlock_weapon("smg");player.set_control(true)
		await capture("pression_arme.png")
		for actor in game.squad.members:
			actor.reparent(game.world,true);actor.show();actor.set_physics_process(false)
			actor.avatar.gun.show();actor.global_position=Vector3(-2+actor.slot*2,.05,35);actor.rotation.y=PI
			actor.avatar.animate_escort(actor,.016,actor.get_aim_point()+Vector3.BACK*10,0,false)
		game.begin_film(Vector3(-3.1,1.45,38),Vector3(-1,1.15,35));await capture("pression_combinaisons.png")
	await finish_run()
