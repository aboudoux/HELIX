extends "res://tests/verify_lunar_escape.gd"
const LIB := preload("res://missions/lunar_escape/researched_materials.gd")

func run() -> void:
	teleport_escorts_for_test=false
	game=load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(game);current_scene=game;player=game.pilot
	await frames(5);game.saver.enabled=false;game.set_physics_process(false)
	game.hud.title_card.hide()
	for director in game.directors+game.upper_directors: director.process_mode=Node.PROCESS_MODE_DISABLED
	for actor in game.squad.members: actor.set_physics_process(false)
	var samples={"Ivory":LIB.Kind.PAINT,"WeaponSilver":LIB.Kind.METAL,"WeaponDark":LIB.Kind.POLYMER,"WeaponGrip":LIB.Kind.RUBBER,"Floor":LIB.Kind.TREAD}
	for key in samples:
		var mat: Material=WORLD.FINISH.material(load("res://materials/"+key+".tres"))
		check(mat.get_shader_parameter("material_kind")==samples[key],key+" possède sa propre famille de matière")
		check(mat.get_shader_parameter("scan_height")!=null,key+" possède sa carte de relief")
	check(game.world.furnishings.cloth.get_shader_parameter("material_kind")==LIB.Kind.TEXTILE,"Les sièges et couvertures utilisent du textile")
	check(game.world.furnishings.bedding.get_shader_parameter("material_kind")==LIB.Kind.TEXTILE,"Oreillers et matelas ne sont plus métalliques")
	check(game.world.furnishings.soil.get_shader_parameter("regolith")==0.0,"Le substrat hydroponique reste distinct de la poussière lunaire")
	var wall: ShaderMaterial = WORLD.FINISH.architecture(WORLD.WHITE, WORLD.FINISH.Detail.USER_WALL_PHOTO)
	check(wall.get_shader_parameter("scan_albedo")==WORLD.FINISH.USER_WALL and wall.get_shader_parameter("scan_height")==LIB.WALL_HEIGHT,"La photo blanche et le relief scanné sont combinés")
	var regolith: ShaderMaterial = WORLD.FINISH.create(Color.WHITE,0,.96,.9,true)
	check(regolith.get_shader_parameter("scan_albedo")==LIB.REGOLITH_COLOR
		and regolith.get_shader_parameter("fine_albedo")==LIB.REGOLITH_FINE
		and regolith.get_shader_parameter("coarse_albedo")==LIB.REGOLITH_COARSE,"Le régolithe utilise trois scans à des échelles distinctes")
	for actor in game.squad.members:
		check(actor.avatar.torso.get_node("EVAControlPack").material_override.get_shader_parameter("photograph")==preload("res://missions/lunar_escape/eva_photo_finish.gd").PHOTO,"La texture d'astronaute demandée est conservée")
	if DisplayServer.get_name()=="headless":
		await finish_run();return
	game.begin_film(Vector3(0,1.65,4),Vector3(7,1.3,-6))
	await capture("matiere_01_couloir.png")
	game.frame_camera(Vector3(-26,1.65,12),Vector3(-29.2,.8,9.665))
	await capture("matiere_02_chambre.png")
	if "--interior-only" in OS.get_cmdline_user_args():
		await finish_run();return
	game.frame_camera(WORLD.at(0,20,1.65,6),WORLD.at(0,27,1,2))
	await capture("matiere_03_ferme.png")
	game.frame_camera(game.world.bike.position+Vector3(2.6,1.7,-3.2),game.world.bike.position+Vector3.UP*.7)
	await capture("matiere_04_moto.png")
	game.frame_camera(game.world.transport.position+Vector3(6,3.7,7),game.world.transport.position+Vector3.UP)
	await capture("matiere_05_blinde.png")
	game.frame_camera(Vector3(55,7,4),Vector3(52,2.7,-8))
	await capture("matiere_06_solaire.png")
	var soil: RefCounted=game.world.surface_profile
	var target:=Vector3(80,soil.elevation(80,35),35)
	game.frame_camera(target+Vector3(4,2.2,5),target)
	await capture("matiere_07_regolithe.png")
	game.frame_camera(WORLD.pad(18,8,-230),game.world.rocket.global_position+Vector3.UP*8)
	await capture("matiere_08_fusee.png")
	game.frame_camera(game.mothership.global_position+Vector3(12,5,14),game.mothership.global_position)
	await capture("matiere_09_boss.png")
	game.frame_camera(WORLD.at(0,24,3,36),WORLD.at(0,24,3,42))
	await capture("matiere_10_verre.png")
	WORLD.block(game.world,Vector3(180,9.8,100),Vector3(20,.4,20),WORLD.FLOOR,true)
	var drone: CharacterBody3D=game.add_enemy(0,Vector3(180,12.3,100),"TEST MATIERE EPAVE")
	drone.set_physics_process(false)
	drone.receive_hit_at(drone.global_position,Vector3.UP,Vector3.DOWN,999)
	var wreck: RigidBody3D=drone.wreck
	await frames(220)
	check(wreck.has_exploded and wreck.collision_layer==0,"La nouvelle matière conserve l'explosion et la carcasse non bloquante")
	check(not wreck.damaged_materials.is_empty() and wreck.damaged_materials[0].get_shader_parameter("damage_map")==LIB.DAMAGE_COLOR,"Les épaves utilisent la carte de métal endommagé")
	game.frame_camera(wreck.global_position+Vector3(3,1.7,3),wreck.global_position)
	await capture("matiere_11_epave.png")
	game.world.rocket_flame.show()
	game.animate_ascent(4.8)
	game.frame_camera(game.world.rocket.global_position+Vector3(16,-4,20),game.world.rocket.global_position+Vector3.UP*2)
	await capture("matiere_12_panache.png")
	game.end_film();player.set_physics_process(false);player.set_control(true)
	player.global_position=Vector3(0,.05,35);player.rotation=Vector3.ZERO;player.head.rotation=Vector3.ZERO
	for key in ["pistol","shotgun","smg"]:
		player.unlock_weapon(key)
		player.equip(key)
		await capture("matiere_arme_"+key+".png")
	await finish_run()
