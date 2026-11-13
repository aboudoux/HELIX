extends "res://tests/verify_lunar_escape.gd"

func run() -> void:
	teleport_escorts_for_test=false
	game=load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(game);current_scene=game;player=game.pilot
	await frames(5);game.hud.title_card.hide();game.hud.set_film(false);game.camera.make_current()
	game.step=game.Step.WORKSHOP;game.set_physics_process(false)
	for director in game.directors+game.upper_directors: director.process_mode=Node.PROCESS_MODE_DISABLED
	for actor in game.squad.members: actor.set_physics_process(false)
	player.unlock_weapon("pistol");player.set_control(true)
	var room: Node3D=game.world.get_node("Selene/Chambre1")
	for base in ["Selene","Tycho","Copernic"]:
		var services: Node3D=game.world.get_node(base+"/Chambre1/IdentiteBase/CircuitAir")
		check(services.find_children("*","SpotLight3D",true,false).size()==2,"Deux sources visibles éclairent la chambre de "+base)
		check(services.get_node("RefletsInterieurs").interior,"Le reflet de la chambre utilise son environnement intérieur : "+base)
	game.set_selene_lighting(true);await frames(2)
	var services: Node3D=room.get_node("IdentiteBase/CircuitAir")
	var dark:=true
	for lamp in services.find_children("*","Light3D",true,false): dark=dark and lamp.light_energy==0
	check(dark and not services.get_node("RefletsInterieurs").visible,"La panne coupe les nouvelles lampes et leurs reflets")
	game.set_selene_lighting(false);await frames(2)
	check(services.get_node("EclairageHabitat").light_energy>1,"Le courant rétablit les luminaires de la chambre")
	WORLD.block(game.world,Vector3(180,9.8,100),Vector3(80,.4,80),WORLD.FLOOR,true)
	await put_player(Vector3(180,10.045,110))
	var ally: CharacterBody3D=game.squad.members[0]
	ally.reparent(game.world,true);ally.show();ally.global_position=Vector3(180,10.045,100);ally.rotation=Vector3.ZERO
	ally.velocity=Vector3(0,0,-1);ally.avatar.gait=0;ally.avatar.feet.contacts.clear()
	var foot: Node3D
	for limb in ally.avatar.limbs:
		if not limb.arm and limb.side>0: foot=limb.end
	ally.avatar.animate_escort(ally,.016,ally.get_aim_point()+Vector3.FORWARD*10,0,false)
	var contact: Vector3=foot.global_position
	for i in range(12):
		ally.position.z-=.016
		ally.avatar.animate_escort(ally,.016,ally.get_aim_point()+Vector3.FORWARD*10,0,false)
	check(foot.global_position.distance_to(contact)<.015,"Le pied d'appui reste fixé au sol pendant le déplacement du corps")
	check(absf(foot.global_position.y-10.085)<.02,"La semelle se pose au niveau réel du sol")
	for speed in [1.0,5.0]:
		ally.global_position=Vector3(180,10.045,100);ally.velocity=Vector3.FORWARD*speed
		ally.avatar.gait=0;ally.avatar.gait_weight=0;ally.avatar.feet.contacts.clear()
		var planted:=false;var previous:=Vector3.ZERO;var slide:=0.0;var height_error:=0.0
		for i in range(80):
			ally.position.z-=speed/60.0
			ally.avatar.animate_escort(ally,1.0/60.0,ally.get_aim_point()+Vector3.FORWARD*10,0,false)
			var stance: bool=ally.avatar.feet.contacts[1.0].stance
			if stance:
				height_error=maxf(height_error,absf(foot.global_position.y-10.085))
				if planted: slide=maxf(slide,foot.global_position.distance_to(previous))
			previous=foot.global_position;planted=stance
		check(slide<.025 and height_error<.025,"Un cycle complet garde ses appuis au sol à %s m/s (glissement %.3f m, hauteur %.3f m)"%[speed,slide,height_error])
	ally.global_position=Vector3(190,14,100)
	ally.avatar.animate_escort(ally,.016,ally.get_aim_point()+Vector3.FORWARD*10,0,false)
	check(ally.avatar.feet.contacts.is_empty(),"En l'air, les pieds ne restent pas accrochés à l'ancien sol")
	ally.global_position=Vector3(180,10.045,100);ally.velocity=Vector3.ZERO
	ally.avatar.gun.show();ally.avatar.animate_escort(ally,.1,ally.get_aim_point()+Vector3.FORWARD*10,.5,false)
	var cloth: ShaderMaterial=ally.avatar.limbs[0].lower.get_child(0).material_override
	check(cloth.get_shader_parameter("joint_flex")>0,"La flexion du coude anime les plis du tissu")
	check(cloth.get_shader_parameter("photograph")==preload("res://missions/lunar_escape/eva_photo_finish.gd").PHOTO,"La combinaison conserve la photographie choisie par le joueur")
	var leg: Dictionary=ally.avatar.limbs.filter(func(limb): return not limb.arm)[0]
	check(leg.end.material_override.get_shader_parameter("soil_amount")>.2,"L'usure est concentrée sur les bottes")
	# Suspension samples the real world, without rotating the vehicle's collision hull.
	var ramp:=WORLD.block(game.world,Vector3(205,10.5,100),Vector3(10,.3,12),WORLD.FLOOR,true)
	ramp.rotation.x=.10
	var tank: Node3D=game.world.transport;tank.global_position=Vector3(205,10.65,100);tank.rotation=Vector3.ZERO
	await frames(60)
	var suspension: Node3D=tank.get_node("Suspension")
	check(suspension.pitch>.06,"Le blindé épouse la pente relevée sous ses roues")
	check(is_zero_approx(tank.rotation.x) and tank.get_node("ParkedCollision").collision_layer!=0,"La suspension préserve la coque de collision stable")
	check(tank.get_meta("track_links").size()==96,"Les deux chenilles disposent de maillons articulés")
	var link: Node3D=tank.get_meta("track_links")[0].node;var initial: Vector3=link.position
	tank.position.z-=.12;await frames(2)
	check(link.position.distance_to(initial)>.05,"Les maillons avancent avec le déplacement réel du char")
	var unchanged: float=suspension.travel;await frames(5)
	check(is_equal_approx(unchanged,suspension.travel),"Les chenilles s'arrêtent avec le véhicule")
	for particles in suspension.dust:
		check(is_equal_approx(particles.gravity.y,-1.62) and not particles.local_coords,"La poussière suit une trajectoire balistique indépendante du véhicule")
		check(not particles.emitting,"Le véhicule arrêté ne soulève pas de poussière")
	ramp.get_child(0).set_meta("impact_surface","dust")
	tank.position.z-=.1;await frames(1)
	check(suspension.dust.all(func(p):return p.emitting),"Rouler sur le régolithe soulève de vrais grains de poussière")
	ramp.get_child(0).set_meta("impact_surface","metal")
	tank.position.z-=.1;await frames(1)
	check(suspension.dust.all(func(p):return not p.emitting),"La poussière s'arrête sur le métal même en roulant")
	var bike: Node3D=game.world.bike;bike.global_position=Vector3(180,10.045,100);await frames(2)
	for i in range(15):
		bike.position.z-=.08;bike.rotation.y+=.02;await frames(1)
	check(absf(bike.get_node("Suspension").roll)>.025,"La moto s'incline progressivement dans un virage")
	# A pressurised cabin preserves onboard sounds but cannot restore sound in the vacuum outside.
	await put_player(Vector3(180,10.045,110));await frames(40)
	check(game.soundscape.world_filter.cutoff_hz<1000 and game.soundscape.suit_filter.cutoff_hz<3200,"Dans le vide, les sons du monde et les vibrations de la combinaison sont distincts")
	player.mount(tank);await frames(40)
	check(game.soundscape.world_filter.cutoff_hz<1000 and game.soundscape.suit_filter.cutoff_hz>19000,"Dans le blindé, l'habitacle reste audible et l'extérieur demeure étouffé")
	player.dismount();await put_player(room.global_position+Vector3(0,.045,0));await frames(40)
	check(game.soundscape.world_filter.cutoff_hz>19000,"Les sons ordinaires reviennent dans la base pressurisée")
	game.begin_film(room.global_position+Vector3(2,1.5,3),room.global_position+Vector3.UP)
	check(not player.weapon.is_visible_in_tree(),"Les mains de première personne ne flottent pas dans les cinématiques")
	game.end_film()
	check(player.weapon.is_visible_in_tree(),"L'arme revient au retour du contrôle du joueur")
	if DisplayServer.get_name()!="headless":
		ally.global_position=room.global_position+Vector3(-.5,.045,0);ally.rotation.y=PI;ally.velocity=Vector3.ZERO
		ally.avatar.feet.contacts.clear();ally.avatar.animate_escort(ally,.1,ally.get_aim_point()+Vector3.BACK*10,0,false)
		ally.caption.hide()
		game.begin_film(ally.global_position+Vector3(.65,1.5,2.1),ally.global_position+Vector3.UP*1.02)
		await frames(12);await capture("realisme_combinaison.png")
		game.frame_camera(room.global_position+Vector3(7,2.3,4.5),room.global_position+Vector3(0,2,0))
		await capture("realisme_chambre.png")
		game.frame_camera(tank.global_position+Vector3(6,3.5,-7),tank.global_position+Vector3.UP*1.4)
		await capture("realisme_suspension.png")
	await finish_run()
