extends "res://tests/verify_lunar_escape.gd"

func run() -> void:
	teleport_escorts_for_test=false
	game=load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(game);current_scene=game;player=game.pilot
	await frames(5);game.hud.title_card.hide();game.hud.set_film(false);game.camera.make_current()
	game.step=game.Step.CONTROL;game.set_physics_process(false)
	for director in game.directors+game.upper_directors: director.process_mode=Node.PROCESS_MODE_DISABLED
	player.unlock_weapon("pistol");player.set_control(true)
	var boss: Node3D=game.mothership
	var ids: Array=boss.guards.map(func(guard): return guard.get_instance_id())
	check(ids.size()==6 and boss.guards.all(func(guard): return guard.is_visible_in_tree()),"Les six drones existent et sont visibles avant la cinématique du boss")
	check(boss.walker.legs.size()==4,"Le boss possède quatre pattes articulées")
	check(boss.max_health==360,"Le boss a 360 PV avant adaptation à l'escouade")
	var room: Node3D=game.equipment_room
	await put_player(room.equipment_points[0].global_position+Vector3(0,-1.25,1.6))
	check(game.nearest_interaction()=="equipment_room","Les armes du râtelier ouvrent le choix des deux mains avec E")
	for i in range(3):
		game.interact("equipment_room");await frames(3)
		var button: Button=room.preset_buttons[i]
		var center:=button.get_global_transform_with_canvas()*(button.size*.5)
		check(root.get_visible_rect().has_point(center),"Le choix rapide %d est visible dans la fenêtre"%i)
		if i==0 and DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://tests/artifacts/armurerie_deux_mains.png")
		var move:=InputEventMouseMotion.new();move.position=center;root.push_input(move,true)
		var click:=InputEventMouseButton.new();click.position=center;click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true;root.push_input(click,true)
		click=click.duplicate();click.pressed=false;root.push_input(click,true)
		await frames(3)
		var expected: String=["shield","pistol","sabre"][i]
		check(not paused and player.loadout.active and player.loadout.right=="pistol" and player.loadout.left==expected,"Un clic équipe réellement pistolet + "+expected)
		if paused: room.close()
		if expected=="pistol" and is_instance_valid(player.loadout.offhand):
			var ammo: int=player.loadout.offhand.ammo
			Input.action_press("aim");await frames(3);Input.action_release("aim")
			check(player.loadout.offhand.ammo==ammo-1,"Le deuxième pistolet tire au clic droit")
		if DisplayServer.get_name()!="headless": await capture("deux_mains_%s.png"%expected)
	var space:=game.get_world_3d().direct_space_state
	var rocket: Node3D=game.world.rocket
	for y in [1.1,3.2,6.5,10.0,12.6]:
		var from:=rocket.to_global(Vector3(6,y,0));var to:=rocket.to_global(Vector3(-6,y,0))
		var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(from,to,1))
		check(not hit.is_empty() and hit.collider.name=="CoqueSolide","La collision de la fusée est présente à hauteur "+str(y))
	player.set_physics_process(false)
	player.global_position=rocket.to_global(Vector3(6,.05,1.3));player.velocity=Vector3.ZERO
	var contact:=player.move_and_collide(Vector3(-12,0,0))
	check(contact!=null and contact.get_collider().name=="CoqueSolide" and player.global_position.x>0,"Le déplacement physique du joueur s'arrête contre la fusée")
	var gap:=space.intersect_ray(PhysicsRayQueryParameters3D.create(rocket.to_global(Vector3(2.65,.9,-2)),rocket.to_global(Vector3(2.65,.9,2)),1))
	check(gap.is_empty(),"L'espace libre entre la tuyère et un pied n'est pas bouché par une grosse boîte invisible")
	player.set_physics_process(true)
	await put_player(WORLD.pad(0,.045,-244.8));game.step=game.Step.BOARD
	check(game.nearest_interaction()=="rocket","La coque solide conserve l'accès à l'embarquement")
	game.ship_reveal();await frames(450)
	check(game.step==game.Step.BATTLE and boss.active,"L'arrivée du quadrupède rend le contrôle au joueur")
	check(ids==boss.guards.map(func(guard): return guard.get_instance_id()),"La cinématique n'ajoute ni ne remplace les drones")
	var original: Vector3=boss.walker.legs[0].planted
	await frames(110)
	check(original.distance_to(boss.walker.legs[0].planted)>.2,"Les pieds progressent avec la marche du boss")
	check(boss.walker.legs.all(func(leg): return leg.planted.y>=WORLD.ROOF_HEIGHT and leg.planted.y<WORLD.ROOF_HEIGHT+1),"Les pieds restent sur le toit ou à hauteur d'un pas")
	boss.set_core_exposed(true)
	boss.receive_hit_at(boss.global_position,Vector3.UP,Vector3.FORWARD,125)
	check(boss.phase==1 and boss.guards.size()==6 and boss.reinforcement_delay>0,"Le changement de phase annonce les renforts avant leur arrivée")
	await frames(130)
	check(boss.guards.size()==10 and absf(boss.guards[6].position.x)>44,"Quatre drones de renfort arrivent depuis l’extérieur du toit")
	await frames(225)
	check(boss.guards.size()==10 and boss.guards[6].is_physics_processing(),"Les renforts rejoignent le combat à la fin de leur approche")
	if DisplayServer.get_name()!="headless":
		game.begin_film(boss.global_position+Vector3(17,7,18),boss.global_position+Vector3.DOWN)
		await capture("boss_quatre_pattes.png");game.end_film()
	boss.receive_hit_at(boss.global_position,Vector3.UP,Vector3.DOWN,10000);await frames(4)
	check(game.step==game.Step.BOARD and game.story.ready_to_launch(),"La victoire sur le quadrupède débloque toujours la fusée")
	await finish_run()
