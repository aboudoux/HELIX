extends Node
var game: Node3D
var cabinets: Dictionary={}
var food := 0
var loose_ammo := {"pistol":0,"shotgun":0,"smg":0}

func setup(campaign: Node3D) -> void:
	game=campaign;name="CabinetLoot"
	var index:=0
	for cabinet in get_tree().get_nodes_in_group("loot_cabinets"):
		if not game.is_ancestor_of(cabinet): continue
		var p: Vector3=cabinet.global_position
		var id:="%d:%d:%d"%[roundi(p.x*100),roundi(p.y*100),roundi(p.z*100)]
		assert(not cabinets.has(id),"Deux placards ont le même identifiant")
		cabinets[id]=cabinet;cabinet.set_meta("loot_id",id)
		var base:=0 if p.z> -600 else (1 if p.z> -1800 else 2)
		var key: String=["pistol","shotgun","smg"][base]
		cabinet.stock({"blocks":randi_range(3,7),"food":1 if index%3==0 else 0,"ammo":12 if base==0 else (6 if base==1 else 24),"ammo_kind":key,"weapon":key if index%5==0 else ""})
		index+=1

func reachable(cabinet: Node3D) -> bool:
	if cabinet.moving: return false
	var offset: Vector3=game.pilot.head.global_position-cabinet.handle.global_position
	if offset.length()>2.35 or offset.dot(cabinet.global_basis.z)<.08: return false
	var hit:=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(game.pilot.head.global_position,cabinet.handle.global_position,1))
	return hit.is_empty() or cabinet.is_ancestor_of(hit.collider)

func nearest() -> String:
	var best:=INF;var result:=""
	for id in cabinets:
		var cabinet: Node3D=cabinets[id]
		var distance: float=game.pilot.head.global_position.distance_squared_to(cabinet.handle.global_position)
		if distance<best and reachable(cabinet): result="cabinet:"+id;best=distance
	return result

func hint(id: String) -> String:
	var cabinet: Node3D=cabinets[id]
	if not cabinet.opened: return "E · Ouvrir le placard"+(" · Vide" if cabinet.taken else "")
	return "E · Refermer le placard vide" if cabinet.taken else "E · Récupérer le contenu : blocs, munitions et provisions"

func interact(id: String) -> void:
	if not cabinets.has(id) or not reachable(cabinets[id]): return
	var cabinet: Node3D=cabinets[id]
	if not cabinet.opened or cabinet.taken:
		if not await cabinet.toggle(): game.speak("Reculez un peu pour laisser les portes s'ouvrir.",2)
		game.saver.write_save(game)
	else: claim(id)

func claim(id: String) -> bool:
	if not cabinets.has(id): return false
	var cabinet: Node3D=cabinets[id]
	if cabinet.taken or not cabinet.opened or cabinet.moving or not reachable(cabinet): return false
	cabinet.taken=true;cabinet.contents.hide()
	var items: Dictionary=cabinet.loot
	game.get_node("Construction").stock+=int(items.blocks)
	food+=int(items.food)
	var weapon: String=items.weapon
	if not weapon.is_empty(): game.pilot.unlock_weapon(weapon)
	loose_ammo[items.ammo_kind]+=int(items.ammo)
	transfer_ammo()
	game.play_cue(game.PICKUP_SOUND)
	game.speak("PLACARD · +%d blocs · +%d rations · +%d munitions%s"%[items.blocks,items.food,items.ammo," · "+game.pilot.WEAPONS[weapon].name if not weapon.is_empty() else ""],4)
	game.saver.write_save(game)
	return true

func transfer_ammo() -> void:
	for key in loose_ammo:
		if game.pilot.inventory.has(key) and loose_ammo[key]>0:
			game.pilot.add_ammo(key,loose_ammo[key]);loose_ammo[key]=0

func _physics_process(_delta: float) -> void:
	if game!=null: transfer_ammo()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode==KEY_Y or event.physical_keycode==KEY_Y):
		if get_tree().paused or not game.pilot.in_control or game.defeated: return
		get_viewport().set_input_as_handled()
		if food<=0: game.speak("Aucune ration · Fouillez les placards.",2);return
		var recovered: int=game.pilot.eat_ration()
		if recovered<=0: game.speak("Santé pleine · Ration conservée.",2);return
		food-=1;game.speak("Ration consommée · +%d santé"%recovered,2);game.saver.write_save(game)

func snapshot() -> Dictionary:
	var states: Dictionary={}
	for id in cabinets:
		var cabinet: Node3D=cabinets[id]
		states[id]={"opened":cabinet.opened,"taken":cabinet.taken,"loot":cabinet.loot.duplicate(true)}
	return {"food":food,"blocks":game.get_node("Construction").stock,"ammo":loose_ammo.duplicate(),"cabinets":states}

static func valid_snapshot(data: Variant) -> bool:
	if not data is Dictionary or not data.get("cabinets") is Dictionary or data.cabinets.size()>200: return false
	for key in ["food","blocks"]:
		if not count_valid(data.get(key)): return false
	if not data.get("ammo") is Dictionary: return false
	for key in ["pistol","shotgun","smg"]:
		if not count_valid(data.ammo.get(key)): return false
	for id in data.cabinets:
		if not id is String or id.length()>60: return false
		var state: Variant=data.cabinets[id]
		if not state is Dictionary or not state.get("opened") is bool or not state.get("taken") is bool or not state.get("loot") is Dictionary: return false
		var loot: Dictionary=state.loot
		for key in ["blocks","food","ammo"]:
			if not count_valid(loot.get(key)): return false
		if loot.get("ammo_kind") not in ["pistol","shotgun","smg"] or loot.get("weapon") not in ["","pistol","shotgun","smg"]: return false
	return true

static func count_valid(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(value) and value>=0 and value<=100000 and value==floorf(value)

func restore(data: Dictionary) -> void:
	if data.is_empty():
		food=0;game.get_node("Construction").stock=0;loose_ammo={"pistol":0,"shotgun":0,"smg":0}
		for cabinet in cabinets.values(): cabinet.restore({})
		return
	if not valid_snapshot(data): return
	food=int(data.food);game.get_node("Construction").stock=int(data.blocks);loose_ammo=data.ammo.duplicate()
	for id in cabinets: cabinets[id].restore(data.cabinets.get(id,{}))
