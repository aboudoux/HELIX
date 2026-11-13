extends "res://tests/verify.gd"
## Godot 4.7.2 — --headless --path DroneArena --script res://tests/verify_lunar_escape.gd --fixed-fps 60

const CAMPAIGN := preload("res://missions/lunar_escape/campaign.gd")
const WORLD := preload("res://missions/lunar_escape/lunar_world.gd")
const ROUTES := preload("res://missions/lunar_escape/lunar_routes.gd")


var teleport_escorts_for_test := true

func put_player(point: Vector3) -> void:
	await super.put_player(point)
	if teleport_escorts_for_test and game.squad!=null: game.squad.relocate()

func run() -> void:
	game = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(game)
	current_scene = game
	player = game.pilot
	player.set_third_person(false)
	await frames(5)
	verify_closed_rooms()
	check(game.step == CAMPAIGN.Step.BRIEFING and not player.in_control and not player.weapon.visible,
		"Le joueur attend le briefing de Karen, sans arme ni contrôle")
	if DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/artifacts"))
		await capture("lune_accueil.png")
	game.hud.primary.pressed.emit()
	await frames(ceili(maxf(6.6,game.voice.stream.get_length()+.25)*60)+10)
	check(game.step == CAMPAIGN.Step.TUTORIAL and player.in_control and player.inventory.size() == 1
		and player.equipped == "pistol", "La cinématique équipe uniquement le pistolet et rend le contrôle")
	check(player.weapon.shot_sound.stream == player.PISTOL_SHOT and player.weapon.shot_sound.volume_db > player.default_shot_volume,
		"Le pistolet utilise sa nouvelle détonation et son propre niveau sonore")
	check(not player.third_person and game.story.arrival_ship.position.y==0,"La fusée atterrit et le jeu rend la première personne")
	await walk_to(Vector2(0,27.0))
	await open_test_door("habitat_entry")
	await walk_to(Vector2(0,16.4))
	check(player.position.z<18,"Le joueur entre réellement dans Karen depuis la piste d'atterrissage")
	var tutorial: CharacterBody3D = game.tutorial_drone
	check(tutorial.get_node("ShotSound").stream.resource_path.ends_with("lunar_drone_pulse.wav")
		and tutorial.rotor_sound.base_volume > -15.0, "Le drone de Séléné utilise le nouveau mix spatial")
	aim_at(tutorial.position)
	if DisplayServer.get_name() != "headless":
		await capture("lune_tutoriel.png")
	for shot in range(3):
		if not tutorial.alive: break
		aim_at(tutorial.position)
		Input.action_press("fire")
		await frames(2)
		Input.action_release("fire")
		await frames(18)
	check(not tutorial.alive and game.step == CAMPAIGN.Step.HABITAT,
		"Le drone en patrouille tombe en trois tirs au plus et libère le couloir")
	await use_story_station("crew")
	await use_story_station("medical")
	await verify_food()
	await verify_pressurized_dome()
	await frames(48)
	check(door_clear("tutorial"), "La porte du tutoriel libère physiquement le passage après le combat")
	await put_player(Vector3(-33.4, 0.045, 12.66))
	await open_test_door("west_room_0_0")
	await walk_to(Vector2(-39.6, 12.66))
	check(player.position.x < -37.5 and not game.world.doors["west_security_0"].secured,
		"La galerie meublée est praticable après le contrôle de sécurité")
	if DisplayServer.get_name() != "headless":
		aim_at(Vector3(-42.4, 1.60, 0))
		await capture("lune_galerie_ouest.png")
		await put_player(Vector3(4.22, 0.045, 15.86))
		aim_at(Vector3(4.41, 0.50, 14.60))
		await capture("lune_munitions.png")
	await put_player(Vector3(4, 0.045, 14.5))
	await tap(KEY_E)
	check(player.weapon.reserve_ammo == 72 and not game.supplies.has("ammo_dorm"), "Les chargeurs peuvent être ramassés")
	await reload_key()
	if DisplayServer.get_name() != "headless":
		await frames(13)
		await capture("lune_recharge.png")
	else:
		await frames(29)
	var during_reload: Vector3 = player.gun_visual.magazine.position
	var magazine_screen: Vector2 = game.camera.unproject_position(player.gun_visual.magazine.global_position)
	check(player.weapon.is_reloading and during_reload.distance_to(player.gun_visual.magazine_seat) > 0.045,
		"La touche R physique déclenche le retrait visible du chargeur")
	check(root.get_visible_rect().grow(-16).has_point(magazine_screen), "Le chargeur reste dans le cadre pendant la recharge")
	await tap(KEY_ESCAPE)
	var held: float = player.weapon.reload_remaining
	var pose: Vector3 = player.gun_visual.magazine.position
	await frames(21)
	check(paused and held == player.weapon.reload_remaining and pose == player.gun_visual.magazine.position, "La pause fige le geste de recharge")
	await tap(KEY_ESCAPE)
	await frames(90)
	check(player.weapon.ammo == 12 and player.weapon.reserve_ammo == 69, "Recharger consomme la réserve du pistolet")
	player.weapon.ammo = 0
	player.weapon.reserve_ammo = 2
	await reload_key()
	await frames(92)
	check(player.weapon.ammo == 2 and player.weapon.reserve_ammo == 0 and game.hud.inventory.text.contains("Réserve vide"),
		"La recharge à vide transfère uniquement les deux munitions disponibles")
	await reload_key()
	check(not player.weapon.is_reloading, "R reste sans effet quand la réserve est vide")
	player.weapon.ammo = 12
	player.weapon.reserve_ammo = 69
	var rack_point: Vector3 = game.supplies["rack_0"].node.position
	await put_player(rack_point + Vector3(0, -rack_point.y + 0.045, -1.25))
	await tap(KEY_E)
	check(not game.supplies.has("rack_0") and player.weapon.reserve_ammo == 93 and player.inventory.size() == 1,
		"Une arme de râtelier déjà acquise fournit des munitions")
	if DisplayServer.get_name() != "headless":
		await put_player(Vector3(17.6, 0.045, 0))
		aim_at(Vector3(28.0, 1.25, -1.8))
		await capture("lune_ferme.png")
	check(game.world.doors["habitat_exit"].secured, "Le sas nord de Séléné reste verrouillé pendant la panne")
	await put_player(Vector3(-24.5, 0.045, 17.55))
	await open_test_door("dome_0_-1")
	await walk_to(Vector2(-24.5, 40.0), 320)
	await tap(KEY_E)
	check(game.selene_power == CAMPAIGN.Power.RESTORED and not game.world.doors["habitat_exit"].secured,
		"La commande de l’observatoire rétablit le courant et déverrouille le sas nord")
	await authorize_base(0)
	await put_player(Vector3(0, 0.045, -17.6))
	await open_test_door("habitat_exit")
	Input.action_press("move_forward")
	await frames(54)
	Input.action_release("move_forward")
	check(game.step == CAMPAIGN.Step.BIKE, "La sortie de Séléné mène sur le sol lunaire")
	await verify_suit()
	await put_player(game.world.bike.global_position+Vector3(1.1,0.045,0))
	await tap(KEY_E)
	check(game.transition and game.film.current and player.vehicle == null, "La montée sur la moto commence par un mouvement de caméra")
	if DisplayServer.get_name() != "headless":
		await capture("lune_moto_embarquement.png")
	await frames(48)
	check(player.vehicle == game.world.bike and not player.weapon.enabled, "La moto se monte avec E et masque l'arme")
	if "--capture-only" in OS.get_cmdline_user_args():
		player.dismount(false)
		var truck: Node3D = game.world.transport
		await put_player(truck.position + Vector3(2.9, 0.045, 0.30))
		aim_at(truck.position + Vector3.UP * 1.55)
		game.board_vehicle(truck)
		await frames(13)
		await capture("lune_embarquement.png")
		await frames(43)
		await finish_run()
		return
	await drive_to(0, WORLD.BASE_Z[1] + 28.2, 6500, true)
	check(player.position.z < WORLD.BASE_Z[1] + 30.0 and player.position.z >= WORLD.BASE_Z[1] + 25.0
		and player.global_position.distance_to(game.world.bike.global_position) < 0.02,
		"La moto roule jusqu'au sas de Tycho et s'arrête devant la porte")
	await tap(KEY_E)
	await frames(280)
	check(game.step == CAMPAIGN.Step.WORKSHOP and player.vehicle == null and player.equipped == "pistol",
		"L'entrée de Tycho rend le pistolet et ferme la phase de moto")
	player.apply_damage(100)
	check(paused and game.defeated, "Une défaite suspend la partie")
	game.hud.primary.pressed.emit()
	await frames(4)
	check(not paused and player.in_control and player.health == 100 and game.step == CAMPAIGN.Step.WORKSHOP
		and player.global_position.distance_to(game.checkpoint) < 0.15, "Le point de passage restaure le joueur à Tycho")
	var tycho: Node3D = game.directors[1]
	check(tycho.get_child(1).max_health > tycho.get_child(0).max_health
		and tycho.get_child(1).fire_interval < tycho.get_child(0).fire_interval, "Les limiers sont plus solides et tirent plus souvent")
	await put_player(WORLD.at(1, -5.4, 0.045, 8.6))
	await resolve_trial("ground_1")
	await use_story_station("power")
	game.rescue_guard.receive_hit_at(game.rescue_guard.position,Vector3.UP,Vector3.FORWARD,10000)
	await put_player(game.mechanic.global_position+Vector3(0,0.045,-1.5))
	await tap(KEY_E)
	check(game.mechanic_rescued,"Lina est libérée après le rétablissement du courant")
	await use_story_station("survivors")
	await use_story_station("access")
	await authorize_base(1)
	check(game.world.doors["garage"].secured, "Le garage attend encore le fusil à pompe")
	await put_player(WORLD.at(1, 7.6, 0.045, -11.9))
	await tap(KEY_E)
	check(player.equipped == "shotgun" and player.weapon.pellets == 7 and not game.supplies.has("shotgun"),
		"Le fusil à pompe débloque un tir à dispersion")
	if DisplayServer.get_name() != "headless":
		await capture("lune_fusil.png")
	player.weapon.ammo = 2
	var shotgun_reserve: int = player.weapon.reserve_ammo
	await reload_key()
	check(player.weapon.is_reloading, "R recharge aussi le fusil à pompe")
	await tap(KEY_1)
	await tap(KEY_2)
	check(not player.weapon.is_reloading and player.weapon.ammo == 2 and player.weapon.reserve_ammo == shotgun_reserve,
		"Changer d'arme annule la recharge sans dépenser de munitions")
	await put_player(WORLD.at(1, 0, 0.045, -17.55))
	await open_test_door("garage")
	await put_player(game.world.transport.global_position+Vector3(2.9,0.045,0.3))
	await tap(KEY_E)
	check(game.transition and game.film.current and not player.in_control, "L’embarquement du blindé coupe la conduite pendant l’animation")
	await frames(22)
	check(game.world.transport.get_meta("hatches")[1].position.z > -0.40, "La trappe du blindé coulisse à l’embarquement")
	if DisplayServer.get_name() != "headless":
		await capture("lune_embarquement.png")
	await frames(40)
	check(game.step == CAMPAIGN.Step.TRANSPORT and player.in_control and player.vehicle == game.world.transport,
		"Le blindé conserve le contrôle au joueur")
	var start_z := player.position.z
	Input.action_press("move_back")
	await frames(23)
	Input.action_release("move_back")
	check(player.position.z > start_z + 0.13 and player.vehicle_speed < 0.0, "Le blindé recule")
	await frames(33)
	await tap(KEY_E)
	check(player.vehicle == null and absf(player.position.x) > 1.8, "Le joueur peut descendre du blindé à l'arrêt")
	await tap(KEY_E)
	await frames(59)
	check(player.vehicle == game.world.transport, "Le blindé peut être repris")
	var heading: float = player.rotation.y
	Input.action_press("move_forward")
	Input.action_press("move_right")
	await frames(24)
	Input.action_release("move_right")
	Input.action_release("move_forward")
	check(player.rotation.y < heading - 0.04, "Le blindé tourne avec la commande de direction")
	await frames(29)
	player.rotation.y = 0.0
	if DisplayServer.get_name() != "headless":
		await capture("lune_blinde.png")
	await drive_to(1, WORLD.BASE_Z[2] + 29.2, 6500, true)
	await tap(KEY_E)
	check(game.code_window.visible,"Le clavier protège l'entrée de Copernic")
	game.code_entry.text = game.access_codes.copernic
	game.submit_code()
	await frames(280)
	check(game.step == CAMPAIGN.Step.CONTROL and door_clear("control_entry_outer") and player.in_control,
		"Le blindé a roulé jusqu'au sas de Copernic")
	var spider: Node3D
	for child in game.resident_spiders:
		if is_instance_valid(child):
			spider = child
			break
	check(spider != null and spider.global_basis.y.y < -0.8, "Les araignées suivent la face intérieure du plafond")
	if spider:
		spider.offset = 1.1
		spider.elapsed = 0.0
		spider.update_route(0)
		check(absf(spider.global_basis.y.x) > 0.8, "La même araignée s'oriente contre un mur")
	await put_player(WORLD.at(2, 0, 0.045, 9.6))
	await resolve_trial("ground_2")
	await authorize_base(2)
	await put_player(WORLD.at(2, -7.0, 0.045, 4.9))
	await tap(KEY_E)
	check(player.equipped == "smg" and player.weapon.automatic, "Le pistolet-mitrailleur récupéré tire en automatique")
	await tap(KEY_2)
	check(player.equipped == "shotgun" and player.weapon.pellets == 7, "Les raccourcis retrouvent les armes déjà acquises")
	await tap(KEY_3)
	check(game.world.doors["launch_exit"].secured, "La sortie reste verrouillée avant le bouclier")
	await put_player(WORLD.at(2, 8.2, 0.045, -12.6))
	await tap(KEY_E)
	check(player.shield_unlocked and player.shield_charge == 100 and not game.world.doors["launch_exit"].secured,
		"Le bouclier est chargé et les deux équipements autorisent l’ouverture")
	await put_player(WORLD.at(2, 0, 0.045, -17.55))
	await open_test_door("launch_exit")
	await put_player(WORLD.at(2, 0, 0.045, -19.8))
	# The new physical stair is covered separately; reach its rooftop landing.
	await game.world.doors.roof_inner.airlock.operate(game.world.doors.roof_inner_outer)
	await put_player(WORLD.at(2,22,WORLD.ROOF_HEIGHT+0.05,-9))
	await frames(4)
	check(game.step == CAMPAIGN.Step.REVEAL and game.film.current and not player.in_control,
		"La sortie déclenche la cinématique d'arrivée du vaisseau")
	await frames(450)
	check(game.step == CAMPAIGN.Step.BATTLE and player.in_control and game.mothership.active
		and game.world.pad_barriers[0].get_child(0).collision_layer == 1,
		"Le vaisseau lance le combat et ferme l'accès à la fusée")
	# Companions may already have hit the exposed core after control is returned.
	check(game.mothership.max_health == 504 and game.mothership.health > 0 and game.mothership.health <= 504 and game.mothership.phase == 0, "Le combat final adapte son blindage à l'escouade")
	check(game.mothership.core.visible, "Le réacteur s’allume pendant la fenêtre de tir")
	if DisplayServer.get_name() != "headless":
		await capture("lune_combat.png")
	var shield_key := InputEventKey.new()
	shield_key.physical_keycode = KEY_F
	shield_key.pressed = true
	Input.parse_input_event(shield_key)
	await frames(4)
	var old_health: int = player.health
	player.apply_damage(20)
	check(old_health - player.health == 4 and player.shield_charge < 100, "Le bouclier réduit les dégâts et se décharge")
	shield_key.pressed = false
	Input.parse_input_event(shield_key)
	# Isolate progression from this fixed strafing bot's survival skill. Real damage
	# is asserted above and in verify_lunar_combat; defeat/reset has its own suite.
	# Only the test actors receive extra health. Boss HP, ammunition, hits, phases,
	# projectiles and all production difficulty settings remain unchanged.
	player.max_health=2000;player.health=2000
	for companion in game.squad.members: companion.max_health=2000;companion.health=2000
	# The reinforced boss needs a longer fight and the rooftop ammunition cache.
	await put_player(WORLD.pad(-4.8,.045,-221.8))
	await tap(KEY_E)
	await put_player(game.checkpoint)
	Input.action_press("fire")
	var seen_phase := 0
	var seen_barrage := false
	var hit_core := false
	var move_right := true
	for tick in range(2400):
		if game.step != CAMPAIGN.Step.BATTLE:
			break
		if player.weapon.ammo == 0 and not player.weapon.is_reloading:
			if player.weapon.reserve_ammo>0: player.weapon.start_reload()
			elif player.equipped=="smg": player.equip("shotgun")
			elif player.equipped=="shotgun": player.equip("pistol")
		if not player.weapon.automatic:
			Input.action_release("fire");await frames(1);Input.action_press("fire")
		seen_phase = maxi(seen_phase, game.mothership.phase)
		seen_barrage = seen_barrage or game.mothership.strike_marks.any(func(mark): return mark.visible)
		if player.position.x > 5.0:
			move_right = false
		elif player.position.x < -5.0:
			move_right = true
		Input.action_release("move_left" if move_right else "move_right")
		Input.action_press("move_right" if move_right else "move_left")
		var previous_health: int = game.mothership.health
		var guards: Array=game.mothership.guards.filter(func(guard): return is_instance_valid(guard) and guard.alive)
		if not guards.is_empty(): aim_at(guards[0].global_position)
		else: aim_at(game.mothership.core.global_position if game.mothership.core.visible else game.mothership.position)
		shield_key.pressed=game.mothership.attack==game.mothership.Attack.VOLLEY
		Input.parse_input_event(shield_key)
		if game.mothership.wave_active: Input.action_press("jump")
		else: Input.action_release("jump")
		await frames(2)
		hit_core = hit_core or previous_health - game.mothership.health >= 4
	Input.action_release("fire")
	Input.action_release("move_right")
	Input.action_release("move_left")
	Input.action_release("jump");shield_key.pressed=false;Input.parse_input_event(shield_key)
	print("BOSS CHECK · hp=",game.mothership.health," pilot=",player.health," ammo=",player.weapon.ammo," reserve=",player.weapon.reserve_ammo," phase=",seen_phase," defeated=",game.defeated)
	check(seen_phase == 2 and seen_barrage, "Le vaisseau entre en surcharge et annonce les bombardements au sol")
	check(hit_core, "Un tir réel sur le réacteur exposé inflige des dégâts supplémentaires")
	# Take cover behind the antenna while Lina finishes; unneutralized base guards remain dangerous.
	await walk_to(Vector2(-6,game.story.link.global_position.z-2.5),300)
	await walk_to(Vector2(-3,game.story.link.global_position.z-2.5),100)
	game.story.link.repair()
	await frames(2120)
	check(game.step == CAMPAIGN.Step.BOARD and game.mothership.health == 0
		and game.world.pad_barriers[0].get_child(0).collision_layer == 0,
		"Le tir réel détruit le vaisseau et rend la fusée accessible")
	await put_player(WORLD.pad(0, 0.045, -243.0))
	await tap(KEY_E)
	await frames(2400)
	check(game.step == CAMPAIGN.Step.COMPLETE and game.hud.title_card.visible
		and game.hud.card_title.text == "De retour sur Terre", "Le départ en fusée conduit à l'épilogue terrestre")
	if DisplayServer.get_name() != "headless":
		await capture("lune_terre.png")
	await finish_run()


func finish_run() -> void:
	for sound in game.find_children("*", "AudioStreamPlayer", true, false) + game.find_children("*", "AudioStreamPlayer3D", true, false):
		sound.stop()
	OS.delay_msec(70)
	await frames(5)
	game.queue_free()
	await frames(5)
	OS.delay_msec(80)
	print("%d vérifications, %d échec(s)" % [checks, failures])
	quit(1 if failures else 0)


func aim_at(point: Vector3) -> void:
	player.look_at(Vector3(point.x, player.position.y, point.z))
	player.head.look_at(point)

func use_story_station(id: String) -> void:
	var point: Vector3 = game.story.stations[id].marker.global_position
	await put_player(Vector3(point.x,0.045 if id=="access" else point.y-1.32+0.045,point.z+1.1 if id=="access" else point.z-1.0))
	await tap(KEY_E)
	check(game.story.flags[id],"L'objectif narratif %s se valide avec E"%id)
	if paused: game.base_life.close_journal()
	await frames(3)


func reload_key() -> void:
	var key := InputEventKey.new()
	key.device = InputEvent.DEVICE_ID_KEYBOARD
	key.physical_keycode = KEY_R
	key.pressed = true
	Input.parse_input_event(key)
	await frames(3)
	key = key.duplicate() as InputEventKey
	key.pressed = false
	Input.parse_input_event(key)
	await frames(3)


func drive_to(leg: int, z: float, budget: int, combat := false) -> void:
	Input.action_press("move_forward")
	var west := 0.0
	var east := 0.0
	var progress_point: Vector3=player.position
	for i in range(budget):
		if player.position.z <= z:
			break
		var point: Vector3 = player.position
		var next := ROUTES.point(leg, maxf(z - 1.0, point.z - 10.0))
		var heading := atan2(point.x - next.x, point.z - next.z)
		var steer := clampf(-angle_difference(player.rotation.y, heading) * 4.5, -1.0, 1.0)
		Input.action_release("move_left")
		Input.action_release("move_right")
		if absf(steer) > 0.015:
			Input.action_press("move_right" if steer > 0.0 else "move_left", absf(steer))
		if combat:
			var target: Node3D=null
			var nearest:=1600.0
			for patrol in game.road_guards:
				if patrol.get_meta("leg")!=leg: continue
				for enemy in patrol.get_children():
					if not enemy.alive: continue
					var local: Vector3=player.to_local(enemy.global_position)
					if local.z>=0 or absf(atan2(-local.x,-local.z))>.8: continue
					var distance: float=local.length_squared()
					if enemy.get("burst_remaining")!=null: distance*=.4
					if distance<nearest: nearest=distance;target=enemy
			if target!=null:
				player.head.look_at(game.squad.aim_point(target))
				Input.action_press("fire")
			else: Input.action_release("fire")
		west = minf(west, point.x)
		east = maxf(east, point.x)
		await physics_frame
		if i>0 and i%180==0:
			if player.position.distance_to(progress_point)<.5:
				print("STALLED ",i," speed ",player.vehicle_speed," velocity ",player.velocity," floor ",player.is_on_floor()," wall ",player.is_on_wall())
				for collision in range(player.get_slide_collision_count()):
					var hit:=player.get_slide_collision(collision)
					for contact in range(hit.get_collision_count()):
						print("CONTACT ",hit.get_collider(contact).get_path()," normal ",hit.get_normal(contact)," position ",hit.get_position(contact))
				break
			progress_point=player.position
	Input.action_release("move_forward")
	Input.action_release("move_right")
	Input.action_release("move_left")
	if combat: Input.action_release("fire");player.head.rotation=Vector3.ZERO
	await frames(20)
	check(west < -55.0 and east > 55.0, "La piste %d fait réellement tourner le véhicule dans les deux sens" % (leg + 1))


func verify_food() -> void:
	player.restore_health()
	var stocked := 0
	var ration: Dictionary
	for record in game.searchable_furniture.values():
		if record.ration:
			stocked += 1
			if absf(record.handle.global_position.z) < 20.0:
				ration = record
	check(stocked == 3 and game.get_node("CabinetLoot").cabinets.size()>30, "Les réserves des chariots restent disponibles en plus des nouveaux placards ouvrables")
	if ration.is_empty():
		return
	var handle: Node3D = ration.handle
	var approach := handle.global_position + handle.global_basis.z * 1.0
	approach.y = WORLD.UPPER_HEIGHT + 0.045 if approach.y > WORLD.UPPER_HEIGHT else 0.045
	await put_player(approach)
	aim_at(handle.global_position)
	await tap(KEY_E)
	check(ration.searched and ration.ration and player.health == 100, "Une ration découverte à pleine santé reste disponible")
	player.apply_damage(43)
	await tap(KEY_E)
	check(not ration.ration and player.health == 87, "Fouiller puis manger soigne de 30 et ne permet pas de réutiliser la ration")
	player.restore_health()


func verify_suit() -> void:
	await put_player(Vector3(3.5, 0.045, -24.2))
	player.oxygen = 50.0
	await frames(22)
	check(player.oxygen < 50.0 and game.hud.visor.visible, "L’oxygène baisse sur la surface et la visière s’affiche")
	await tap(KEY_ESCAPE)
	var before: float = player.oxygen
	await frames(30)
	check(paused and player.oxygen == before, "La pause fige la consommation d’oxygène")
	await tap(KEY_ESCAPE)
	var quiet_spot := ROUTES.point(0, -64.0) + Vector3.UP * 0.045
	await put_player(quiet_spot)
	player.restore_health()
	player.oxygen = 0.02
	await frames(9)
	check(player.health == 90 and player.oxygen == 0.0, "La panne d’oxygène fait perdre de la santé")
	player.restore_health()
	await put_player(game.world.scout.position + Vector3(2.91, 0.045, 0.4))
	await tap(KEY_E)
	await frames(62)
	check(player.vehicle == game.world.scout and player.oxygen > 0.1 and not game.hud.visor.visible,
		"L’éclaireur se pilote et sa cabine recharge l’oxygène")
	if player.vehicle != null:
		await tap(KEY_E)
	check(player.vehicle == null, "On peut descendre de l’éclaireur")
	player.oxygen = 100.0
	player.restore_health()


func verify_closed_rooms() -> void:
	var space := game.get_world_3d().direct_space_state
	var standing := CapsuleShape3D.new()
	standing.height = 1.8
	standing.radius = 0.32
	for base in range(3):
		check(game.world.doors["west_security_%d" % base].secured, "La galerie ouest est cloisonnée avant l’épreuve")
		var shell: Node3D = game.world.get_node(["Selene", "Tycho", "Copernic"][base])
		var doors_block := true
		for side in [-1.0, 1.0]:
			for slot in range(3):
				var id: String = "Chambre%d" % (slot + 1) if side < 0 else ["Cuisine", "Ferme", "Controle"][slot]
				var room := shell.get_node(id) as Node3D
				var query := PhysicsShapeQueryParameters3D.new()
				query.shape = standing
				query.transform = Transform3D(Basis.IDENTITY, Vector3(side * 12.65, 0.95, room.global_position.z))
				query.motion = Vector3(side * 5.8, 0, 0)
				var distances := space.cast_motion(query)
				doors_block = doors_block and distances.size() > 0 and distances[0] < 0.85
		check(doors_block, "Six portes ferment les pièces de " + shell.name)
		var y := 1.25
		var z := WORLD.BASE_Z[base]
		var edge := PhysicsRayQueryParameters3D.create(Vector3(45.0, y, z - 7.0), Vector3(37.0, y, z - 7.0), 1)
		var roof := PhysicsRayQueryParameters3D.create(Vector3(-40.0, 8.0, z + 11.0), Vector3(-40.0, 2.8, z + 11.0), 1)
		check(not space.intersect_ray(edge).is_empty() and not space.intersect_ray(roof).is_empty(),
			"Le mur extérieur et le plafond ferment " + shell.name)
		check(shell.get_node(WORLD.EAST_ROOMS[base][1]).position.z == 0.0,
			"L’aile centrale de %s a sa propre disposition" % shell.name)


func verify_pressurized_dome() -> void:
	var saved: Vector3 = player.position
	await put_player(Vector3(24.5, 0.045, 17.55))
	await open_test_door("dome_0_1")
	await walk_to(Vector2(24.5, 34.0))
	check(player.position.z > 33.0 and WORLD.pressurized(player.position), "La serre est accessible à pied et reste pressurisée")
	check(game.selene_power == CAMPAIGN.Power.OUTAGE and game.world.doors["habitat_exit"].secured,
		"Entrer dans le tunnel déclenche la panne et garde le sas nord verrouillé")
	check(not WORLD.pressurized(Vector3(37, 0.045, 39)), "Le terrain à côté de la serre reste sous vide")
	await put_player(saved)


func door_clear(key: String) -> bool:
	var door: Node3D = game.world.doors[key]
	return (door.is_open and door.leaves[0].get_child(0).collision_layer == 0
		and door.leaves[1].get_child(0).collision_layer == 0)


func open_test_door(key: String) -> void:
	var door: Node3D = game.world.doors[key]
	if door.airlock!=null:
		var lock: Node3D = door.airlock
		var entrance := key in ["habitat_entry","workshop_entry","control_entry"]
		var first: Node3D = lock.outer if entrance else lock.inner
		var second: Node3D = lock.inner if entrance else lock.outer
		if not first.is_open: await lock.operate(first)
		check(first.is_open and not second.is_open,"Une seule porte s'ouvre à l'entrée du sas "+key)
		var center: Vector3 = lock.chamber.get_center()
		await walk_to(Vector2(center.x,center.z),180)
		if teleport_escorts_for_test: game.squad.relocate()
		await frames(45)
		await lock.operate(first)
		await lock.operate(second)
		check(second.is_open and not first.is_open,"Le cycle de pression libère l'autre porte du sas "+key)
		var direction: float = signf(second.global_position.z-first.global_position.z)
		await walk_to(Vector2(second.global_position.x,second.global_position.z+direction*2),180)
		return
	if door.is_open:
		return
	if key == "upper_0":
		aim_at(door.global_position + Vector3.UP * 1.58)
	var initial: float = door.leaves[0].position.x
	await tap(KEY_E)
	await frames(9)
	check(door.opening and not door.is_open and door.leaves[0].position.x < initial - 0.001,
		"Les battants coulissent à l’ouverture de " + key)
	if key == "upper_0" and DisplayServer.get_name() != "headless":
		await capture("lune_ouverture_sas.png")
	await frames(48)
	check(door_clear(key), "Les collisions libèrent le passage de " + key)


func walk_to(target: Vector2, budget := 250) -> void:
	Input.action_press("move_forward")
	for frame in range(budget):
		if Vector2(player.position.x, player.position.z).distance_to(target) < 0.43:
			break
		player.look_at(Vector3(target.x, player.position.y, target.y))
		await physics_frame
	Input.action_release("move_forward")
	await frames(12)


func resolve_trial(key: String) -> void:
	var trial: Dictionary = game.trials[key]
	var parent: Node3D = game.upper_directors[trial.base] if trial.upper else game.directors[trial.base]
	check(trial.started and trial.left > 0 and game.world.doors[key].secured, "L’épreuve de " + key + " a commencé à l’entrée, sans E")
	var targets: Array[Node] = []
	for actor in parent.get_children():
		if actor.alive and (trial.upper or actor.drone_name.contains("INTERVENTION")):
			targets.append(actor)
	for actor in game.get_children():
		if trial.upper and trial.base == 2 and actor.has_method("update_route") and actor.floor_level == WORLD.UPPER_HEIGHT:
			targets.append(actor)
	check(targets.size() == trial.left, "Les hostiles de l’épreuve sont comptés")
	if key == "upper_0" and not targets.is_empty():
		var first := targets[0] as Node3D
		var health_before: int = first.health
		for shot in range(4):
			if first.health < health_before:
				break
			aim_at(first.global_position)
			Input.action_press("fire")
			await frames(2)
			Input.action_release("fire")
			await frames(18)
		check(first.health < health_before, "Le tir du joueur atteint un garde du nouvel étage")
	for index in range(targets.size()):
		var actor := targets[index]
		while actor.health > 0:
			if actor.has_method("receive_hit"):
				actor.receive_hit()
			else:
				actor.receive_hit_at(actor.global_position, Vector3.UP, Vector3.FORWARD)
		if index == 0 and targets.size() > 1:
			check(game.world.doors[key].secured, "Le sas reste fermé tant qu’un hostile est vivant")
	await frames(4)
	check(trial.left == 0 and not game.world.doors[key].secured and not game.world.doors[key].is_open,
		"Le dernier hostile déverrouille le sas sans ouvrir les battants")
	await open_test_door(key)


func authorize_base(base: int) -> void:
	var z := WORLD.BASE_Z[base]
	await put_player(WORLD.at(base, 12.4, 0.045, 0))
	await open_test_door("room_%d_1_1" % base)
	await walk_to(Vector2(32.6, z))
	check(player.position.x > 31.5, "Le joueur traverse la pièce centrale de la base %d" % (base + 1))
	await walk_to(Vector2(33.2, z + 4.9))
	await open_test_door("stair_down_%d" % base)
	await walk_to(Vector2(39.2, z + 4.9))
	await walk_to(Vector2(39.2, z - 13.9))
	check(absf(player.position.y - WORLD.UPPER_HEIGHT) < 0.14 and player.position.z < z - 13.1,
		"Le joueur monte physiquement à l’étage de la base %d" % (base + 1))
	await walk_to(Vector2(36.45, z - 13.9))
	await open_test_door("stair_up_%d" % base)
	await walk_to(Vector2(31.2, z - 13.9))
	check(player.position.x < 33.0, "Le palier débouche sur l’étage")
	check(game.trials["upper_%d" % base].started, "Franchir le palier déclenche automatiquement l’épreuve de l’étage")
	await walk_to(Vector2(13.2, z - 8.8))
	if DisplayServer.get_name() != "headless" and base == 0:
		await capture("lune_sas_etage.png")
	await resolve_trial("upper_%d" % base)
	await walk_to(Vector2(-6.15, z - 9.0))
	await tap(KEY_E)
	if base==2:
		await use_story_station("coordinates")
		await use_story_station("fuel")
		await put_player(WORLD.at(2,-6.15,WORLD.UPPER_HEIGHT+0.045,-9.0))
	check(game.clearance[base] == (base == 0), "L’autorisation de Séléné est conservée pendant l’exploration de l’étage")
	if base == 2:
		await put_player(WORLD.at(2, 22.6, WORLD.UPPER_HEIGHT + 0.045, 6.2))
		await open_test_door("reserve_2")
		await walk_to(Vector2(27.5, z + 6.2))
		await walk_to(Vector2(27.5, z + 8.8))
		await tap(KEY_E)
		check(game.armor_taken and not game.clearance[2], "Ramasser l’armure ne suffit pas à ouvrir la sortie")
		await tap(KEY_E)
		check(game.armor_worn and game.clearance[2] and player.max_health == 125, "Enfiler l’armure valide l’accès EVA et renforce la protection")
		await put_player(WORLD.at(2, -6.15, WORLD.UPPER_HEIGHT + 0.045, -9.0))
	if base == 0:
		await walk_to(Vector2(-13.40, z - 10.4))
		await open_test_door("upper_service_0_0")
		await walk_to(Vector2(-22.1, z - 10.4))
		await walk_to(Vector2(-22.1, z + 7.0))
		await walk_to(Vector2(-16.40, z + 7.0))
		await open_test_door("upper_service_0_1")
		await walk_to(Vector2(-9.0, z + 7.0))
		check(player.position.x > -10.0 and player.position.z > z + 6.4, "La galerie technique permet de faire le tour de l’étage")
		await walk_to(Vector2(-5.5, z - 8.8))
	await walk_to(Vector2(14.8, z - 8.8))
	if base in [0,1,2]:
		# New flanking positions leave wrecks in the central aisle; walk around them.
		await walk_to(Vector2(14.8, z - 6.2))
		await walk_to(Vector2(31.0, z - 6.2))
	else:
		await walk_to(Vector2(31.0, z - 9.1))
	await walk_to(Vector2(31.0, z - 13.9))
	await walk_to(Vector2(39.2, z - 13.9))
	await walk_to(Vector2(39.2, z + 4.9))
	check(player.position.y < 0.20, "L’escalier de la base %d se redescend à pied (position %s)" % [base + 1, player.position])
	if base == 1:
		var station: Vector3 = game.code_station.global_position
		await put_player(Vector3(station.x + 1.4, 0.045, station.z + 1.3))
		await tap(KEY_E)
		check(paused and game.code_window.visible, "L’ordinateur de contrôle ouvre l’énigme du code")
		game.code_entry.text = "0000"
		game.code_window.confirmed.emit()
		check(not game.clearance[1] and game.code_window.visible, "Un code incorrect laisse le sas verrouillé")
		game.code_entry.text = game.access_codes.tycho
		game.code_window.confirmed.emit()
		check(game.clearance[1] and not paused, "Résoudre le code autorise la sortie de Tycho")
		check(game.garage_alarm, "Le code réveille les limiers du dépôt")
		var depot: Node3D = game.world.doors["room_1_1_2"]
		await put_player(depot.global_position + Vector3(-1.6, 0.045, 0))
		await frames(49)
		await tap(KEY_E)
		await frames(38)
		for attempt in range(6):
			if not depot.is_open: break
			# The player retries once the moving squad/guards have cleared the safety sensor.
			await frames(50)
			if not depot.passage_occupied():
				await tap(KEY_E)
				await frames(45)
		check(not depot.is_open and depot.leaves[0].get_child(0).collision_layer == 1,
			"Refermer le sas du dépôt rétablit sa collision")
