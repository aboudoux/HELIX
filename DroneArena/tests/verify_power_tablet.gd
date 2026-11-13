extends "res://tests/verify_lunar_escape.gd"

func run() -> void:
	teleport_escorts_for_test=false
	game=load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(game);current_scene=game;player=game.pilot
	await frames(5)
	game.hud.title_card.hide();game.hud.set_film(false);game.camera.make_current()
	game.step=game.Step.HABITAT
	for director in game.directors+game.upper_directors: director.process_mode=Node.PROCESS_MODE_DISABLED
	player.unlock_weapon("pistol");player.set_control(true)
	await put_player(Vector3(0,.045,15))
	if DisplayServer.get_name()!="headless": await capture("courant_avant.png")
	await put_player(Vector3(24.5,.045,23))
	check(game.selene_power==game.Power.OUTAGE,"L'entrée réelle dans la serre déclenche la panne")
	var grid: RefCounted=game.selene_lighting
	check(grid.surfaces.size()>100,"La panne inclut les bandes, écrans, mobilier et voyants de la base : "+str(grid.surfaces.size()))
	var all_off:=true
	for item in grid.surfaces:
		var mat: Material=item.node.material_override if item.slot<0 else item.node.get_surface_override_material(item.slot)
		all_off=all_off and mat==grid.DARK
	check(all_off,"Toutes les surfaces bleues recensées sont éteintes")
	var locks: Array=game.world.airlocks.filter(func(lock): return absf(lock.chamber.get_center().z)<30)
	for lock in locks: lock.update_display()
	check(locks.all(func(lock): return not lock.display.visible),"Un changement de pression ne rallume pas les afficheurs pendant la panne")
	check(WORLD.CYAN.emission_enabled and WORLD.CYAN.emission_energy_multiplier==2,"Le matériau partagé des autres bases et armes reste intact")
	var door: Node3D=game.world.doors.bedroom
	door.unlock()
	check(door.indicators.all(func(indicator): return indicator.material_override==grid.DARK),"Déverrouiller une porte pendant la panne ne rallume pas ses voyants")
	await put_player(Vector3(0,.045,15))
	if DisplayServer.get_name()!="headless": await capture("courant_panne.png")
	game.interact("breaker");await frames(3)
	check(game.selene_power==game.Power.RESTORED and door.indicators[0].material_override==WORLD.CYAN,"Le disjoncteur rétablit les voyants")
	check(grid.lamps.all(func(item): return is_equal_approx(item.node.light_energy,item.energy)),"Les luminaires retrouvent exactement leur énergie")
	check(locks.all(func(lock): return lock.display.visible),"Les afficheurs des sas reviennent avec le courant")
	game.set_selene_lighting(true);game.set_selene_lighting(false)
	check(door.indicators[0].material_override==WORLD.CYAN,"Un deuxième cycle panne/rétablissement reste réversible")
	if DisplayServer.get_name()!="headless": await capture("courant_retabli.png")
	game.step=game.Step.WORKSHOP
	var tablet: Marker3D=game.story.stations.access.marker
	var floor_hit:=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(tablet.global_position,tablet.global_position+Vector3.DOWN*.2,1))
	check(not floor_hit.is_empty() and absf(floor_hit.position.y-(tablet.global_position.y-.0225))<.005,"La tablette bleue repose réellement sur son chevet")
	await put_player(tablet.global_position+Vector3(1.4,-.905,1.3))
	check(game.nearest_interaction()=="story:access","Le support laisse la tablette accessible avec E")
	if DisplayServer.get_name()!="headless":
		game.begin_film(tablet.global_position+Vector3(2,1.2,2),tablet.global_position+Vector3.DOWN*.25)
		await capture("tablette_support.png");game.end_film()
	game.interact("story:access")
	check(game.story.flags.access and game.base_life.log_window.dialog_text.contains(game.access_codes.copernic),"Lire la tablette conserve le code de Copernic")
	if paused: game.base_life.close_journal()
	await finish_run()
