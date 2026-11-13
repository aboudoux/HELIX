extends RefCounted
## Versioned safe-point save. Live encounters restart; completed trials and loot persist.
var path := "user://lunar_campaign_v1.json"
var enabled := not OS.get_cmdline_args().has("--script")
const MAP := preload("res://missions/lunar_escape/exploration_map.gd")
const RETIRED_WEAPON := "infinity"

func read_save() -> Dictionary:
	if not enabled: return {}
	for file in [path,path+".bak"]:
		if not FileAccess.file_exists(file): continue
		var parser := JSON.new()
		if parser.parse(FileAccess.get_file_as_string(file))!=OK: continue
		var data: Variant = parser.data
		if valid(data): return survival_data(data)
	return {}

func valid(data: Variant) -> bool:
	if not data is Dictionary or data.get("version")!=1: return false
	if data.has("access_codes") and not preload("res://missions/lunar_escape/access_codes.gd").valid(data.access_codes): return false
	if data.has("loadout") and not valid_loadout(data.loadout): return false
	if data.has("bunkers") and not preload("res://missions/lunar_escape/secret_bunkers.gd").valid_snapshot(data.bunkers): return false
	if data.has("construction") and not preload("res://missions/lunar_escape/construction.gd").valid_snapshot(data.construction): return false
	if data.has("stash") and not preload("res://missions/lunar_escape/cabinet_loot.gd").valid_snapshot(data.stash): return false
	if data.has("explored"):
		var limit := MAP.COLS*MAP.ROWS if data.get("map_revision",1)==MAP.MAP_REVISION else 5400
		if not data.explored is Array or data.explored.size()>limit: return false
		for cell in data.explored:
			if (not cell is int and not cell is float) or float(cell)!=floorf(float(cell)) or int(cell)<0 or int(cell)>=limit: return false
	if not data.get("stage") is float and not data.get("stage") is int: return false
	if int(data.stage) not in [2,3,4,5,6,7,9,10]: return false
	if float(data.stage)!=float(int(data.stage)): return false
	if not data.get("inventory") is Dictionary or not data.get("equipped") is String: return false
	if not data.inventory.has(data.equipped) or not data.inventory.has("pistol"): return false
	for key in data.inventory:
		if key not in ["pistol","shotgun","smg",RETIRED_WEAPON]: return false
		var rounds: Variant = data.inventory[key]
		if not rounds is Dictionary: return false
		for field in ["loaded","reserve"]:
			if not rounds.get(field) is float and not rounds.get(field) is int: return false
			if rounds[field]<0 or rounds[field]>100000: return false
	for field in ["supplies","trials","doors","upgrades","stations","clearance"]:
		if not data.get(field) is Array: return false
	if data.clearance.size()!=3 or data.stations.size()!=3: return false
	for value in data.clearance:
		if not value is bool: return false
	for station in data.stations:
		if not station is Dictionary: return false
		for flag in ["read","opened","taken"]:
			if not station.get(flag) is bool: return false
	for flag in ["armor","shield","third_person","mechanic"]:
		if not data.get(flag) is bool: return false
	if data.has("story"):
		if not data.story is Dictionary or not data.story.get("flags") is Dictionary: return false
		for flag in ["crew","medical","power","coordinates","fuel","wreck","aid"]:
			if not data.story.flags.get(flag) is bool: return false
		if not data.story.get("preparation") is float and not data.story.get("preparation") is int: return false
		if data.story.preparation<0 or data.story.preparation>35: return false
		if data.story.flags.has("survivors") and not data.story.flags.survivors is bool: return false
	return true

func valid_loadout(data: Variant) -> bool:
	if not data is Dictionary: return false
	for flag in ["unlocked","active"]:
		if not data.get(flag) is bool: return false
	if data.get("right") not in ["pistol","shotgun","smg","sabre","lance",RETIRED_WEAPON]: return false
	if data.get("left") not in ["none","pistol","shotgun","smg","sabre","lance","shield"]: return false
	var armor: Variant=data.get("armor")
	if (not armor is int and not armor is float) or armor<0 or armor>2 or armor!=floorf(armor) or not data.get("reserves") is Dictionary: return false
	for key in data.reserves:
		if key not in ["pistol","shotgun","smg"] or not data.reserves[key] is Dictionary: return false
		for field in ["loaded","reserve"]:
			var value: Variant=data.reserves[key].get(field)
			if (not value is int and not value is float) or value<0 or value>100000 or value!=floorf(value): return false
	return true

func survival_data(data: Dictionary) -> Dictionary:
	var clean := data.duplicate(true)
	clean.inventory.erase(RETIRED_WEAPON)
	if clean.equipped==RETIRED_WEAPON:
		clean.equipped="pistol"
	var gear: Dictionary = clean.get("loadout",{})
	if int(clean.stage)<7 and gear.get("unlocked",false):
		# A visit to Copernic could previously be skipped through the creative inventory.
		clean.erase("loadout")
		clean.armor=false
		clean.shield=false
	elif gear.get("right")==RETIRED_WEAPON:
		gear.right=clean.equipped
	return clean

func write_save(game: Node3D) -> bool:
	if not enabled or game.defeated or game.transition or not game.pilot.in_control: return false
	if game.step not in [2,3,4,5,6,7,9,10]: return false
	var pilot: CharacterBody3D = game.pilot
	var inventory: Dictionary = pilot.inventory.duplicate(true)
	inventory[pilot.equipped] = {"loaded":pilot.weapon.ammo,"reserve":pilot.weapon.reserve_ammo}
	var completed: Array = []
	for key in game.trials:
		if game.trials[key].started and game.trials[key].left==0: completed.append(key)
	var opened: Array = []
	for key in game.world.doors:
		if game.world.doors[key].is_open: opened.append(key)
	var stations: Array = []
	for station in game.base_life.stations:
		stations.append({"read":station.read,"opened":station.opened,"taken":station.taken})
	var data := {"version":1,"stage":game.step,"inventory":inventory,"equipped":pilot.equipped,
		"supplies":game.supplies.keys(),"trials":completed,"doors":opened,"clearance":game.clearance,
		"armor":game.armor_worn,"shield":pilot.shield_unlocked,"upgrades":pilot.upgrades,
		"stations":stations,"third_person":false,"shoulder":pilot.shoulder_side,
		"mechanic":game.mechanic_rescued,"story":game.story.snapshot(),"camera_revision":2,"access_codes":game.access_codes.snapshot(),"explored":game.exploration.snapshot()}
	data.loadout=pilot.loadout.snapshot()
	if game.has_node("SecretBunkers"): data.bunkers=game.get_node("SecretBunkers").snapshot()
	if game.has_node("Construction"): data.construction=game.get_node("Construction").snapshot()
	if game.has_node("CabinetLoot"): data.stash=game.get_node("CabinetLoot").snapshot()
	data.map_revision=MAP.MAP_REVISION
	if game.has_node("CampaignPolish"):
		data.road_caches = game.get_node("CampaignPolish").discoveries.map(func(entry): return bool(entry.claimed))
	return store_data(data)

func store_data(data: Dictionary) -> bool:
	if not enabled or not valid(data): return false
	var temp := path+".tmp"
	var file := FileAccess.open(temp,FileAccess.WRITE)
	if file==null: return false
	file.store_string(JSON.stringify(data))
	file.flush()
	var error := file.get_error()
	file.close()
	if error!=OK: return false
	# Keep one previous valid version if a write or the next launch is interrupted.
	if FileAccess.file_exists(path):
		var previous := JSON.new()
		if previous.parse(FileAccess.get_file_as_string(path))==OK and valid(previous.data):
			if DirAccess.copy_absolute(path,path+".bak")!=OK: return false
		if DirAccess.remove_absolute(path)!=OK: return false
	return DirAccess.rename_absolute(temp,path)==OK

func clear() -> void:
	if not enabled: return
	for file in [path,path+".bak",path+".tmp"]:
		if FileAccess.file_exists(file): DirAccess.remove_absolute(file)

func open_door(door: Node3D) -> void:
	door.unlock()
	# Safe-point loads reset both airlock doors closed and the chamber pressurised.
	if door.airlock!=null: return
	door.is_open = true
	for i in range(door.leaves.size()):
		door.leaves[i].position.x = (-1 if i==0 else 1)*(door.width*0.75+0.085)
		door.leaves[i].get_child(0).set_deferred("collision_layer",0)

func restore(game: Node3D, data: Dictionary) -> bool:
	if not valid(data): return false
	data = survival_data(data)
	if game.has_node("Construction"): game.get_node("Construction").restore(data.get("construction",[]))
	if game.has_node("CampaignPolish"):
		var caches = data.get("road_caches",[])
		if caches is Array and caches.size()==2 and caches.all(func(value): return value is bool):
			for i in range(2): game.get_node("CampaignPolish").discoveries[i].claimed = caches[i]
	game.squad.commands.follow()
	var pilot: CharacterBody3D = game.pilot
	game.step = int(data.stage)
	game.access_codes.restore(data.get("access_codes",{}),game.step)
	game.exploration.restore(data.get("explored",[]),int(data.get("map_revision",1)))
	pilot.inventory = data.inventory.duplicate(true)
	# Encounters restart at a safe point: guarantee two spare magazines so a
	# save made with no ammunition cannot leave the player unable to progress.
	for key in pilot.inventory:
		var capacity: int = pilot.WEAPONS[key].capacity
		pilot.inventory[key].loaded = clampi(int(pilot.inventory[key].loaded),0,capacity)
		pilot.inventory[key].reserve = maxi(int(pilot.inventory[key].reserve),capacity*2)
	pilot.equipped = ""
	pilot.equip(data.equipped)
	pilot.weapon.ammo = clampi(pilot.weapon.ammo,0,pilot.weapon.magazine_capacity)
	pilot.set_third_person(false)
	pilot.shoulder_side = -1.0 if data.get("shoulder",1.0)==-1 else 1.0
	pilot.shoulder_blend = pilot.shoulder_side
	pilot.shield_unlocked = data.shield
	pilot.shield_charge = 100 if data.shield else 0
	game.armor_taken = data.armor
	game.armor_worn = data.armor
	pilot.avatar.set_reinforced(data.armor)
	pilot.max_health = 125 if data.armor else 100
	pilot.restore_health()
	pilot.oxygen = 100
	game.clearance.assign(data.clearance)
	game.mechanic_rescued = data.mechanic
	game.mechanic.visible = not data.mechanic
	game.story.restore(data.get("story",{}),game.step)
	if data.armor:
		for part in game.armor_stand.get_children().slice(1):
			if part is Node3D: part.hide()
	for key in game.supplies.keys():
		if key not in data.supplies:
			game.supplies[key].node.queue_free()
			game.supplies.erase(key)
	for key in data.trials:
		if game.trials.has(key):
			game.trials[key].started = true
			game.trials[key].left = 0
			for enemy in game.trials[key].enemies:
				if is_instance_valid(enemy):
					enemy.hide(); enemy.queue_free()
			game.world.doors[key].unlock()
	for key in data.doors:
		if game.world.doors.has(key): open_door(game.world.doors[key])
	for i in range(3):
		var station: Dictionary = game.base_life.stations[i]
		for flag in ["read","opened","taken"]: station[flag] = data.stations[i][flag]
		station.module.visible = not station.taken
		if station.opened: open_door(game.world.doors["cache_%d"%i])
		game.update_clearance(i)
		# Old saves may contain a gate opened before the new story objectives.
		if not game.story.exit_ready(i) and game.step in [3,5,7]:
			var gate: Node3D = game.world.doors[game.exit_key(i)]
			gate.is_open = false
			gate.lock()
			for leaf_index in range(gate.leaves.size()):
				gate.leaves[leaf_index].position.x = (-1 if leaf_index==0 else 1)*gate.width*0.25
				gate.leaves[leaf_index].get_child(0).set_deferred("collision_layer",1)
	pilot.upgrades.clear()
	for i in range(3):
		if data.stations[i].taken: pilot.upgrades.append(["O₂+","Stabilité+","Bouclier+"][i])
	pilot.oxygen_efficiency = 0.65 if data.stations[0].taken else 1.0
	pilot.weapon.recoil_multiplier = 0.72 if data.stations[1].taken else 1.0
	pilot.shield_recovery = 40.0 if data.stations[2].taken else 28.0
	game.selene_power = game.Power.RESTORED if game.clearance[0] else game.Power.ONLINE
	game.set_selene_lighting(false)
	game.checkpoint_heading = 0
	var base := 0 if game.step<=4 else (1 if game.step<=6 else 2)
	game.checkpoint = game.WORLD.at(base,0,0.045,17.0)
	if game.step==2:
		game.checkpoint = Vector3(0,0.08,28)
		game.checkpoint_heading = 0
		game.world.doors["habitat_entry"].unlock()
	elif game.step>=3:
		game.tutorial_drone.hide()
		game.tutorial_drone.queue_free()
		open_door(game.world.doors["tutorial"])
	if game.step in [4,6]:
		game.checkpoint = game.WORLD.at(base,2.5,0.045,-28.8)
		open_door(game.world.doors[game.exit_key(base)])
	if game.step in [9,10]: game.checkpoint = game.WORLD.pad(0,0.045,-216)
	for i in range(3):
		game.directors[i].process_mode = Node.PROCESS_MODE_INHERIT if i==base and game.step in [2,3,5,7] else Node.PROCESS_MODE_DISABLED
	if game.step==7:
		for spider in game.resident_spiders:
			if is_instance_valid(spider): spider.process_mode=Node.PROCESS_MODE_INHERIT
	game.place_pilot(game.checkpoint,game.checkpoint_heading)
	game.hud.has_started = true
	game.hud.title_card.hide()
	game.end_film()
	pilot.loadout.restore(data.get("loadout",{}))
	if game.has_node("CabinetLoot"): game.get_node("CabinetLoot").restore(data.get("stash",{}))
	if game.has_node("SecretBunkers"):
		game.get_node("SecretBunkers").restore(data.get("bunkers",[{"discovered":false,"defeated":false,"claimed":false},{"discovered":false,"defeated":false,"claimed":false},{"discovered":false,"defeated":false,"claimed":false}]))
	if pilot.loadout.active: pilot.restore_health()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	match game.step:
		2: game.set_objective("MISSION KAREN","Entrez dans la base. Retrouvez les survivants et le journal de bord.")
		3,5,7: game.refresh_base_objective(base)
		4,6: game.set_objective("SURFACE LUNAIRE","Reprenez votre véhicule et suivez les balises vers la prochaine base.")
		9: game.ship_reveal()
		10: game.on_ship_destroyed()
	game.speak("Partie reprise au point sûr. Équipement, annexes et épreuves terminées conservés.",5.0)
	return true
