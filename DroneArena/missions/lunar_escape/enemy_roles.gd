extends RefCounted
const KIT := preload("res://missions/lunar_escape/mesh_kit.gd")
const WORLD := preload("res://missions/lunar_escape/lunar_world.gd")

static func install(actor: CharacterBody3D, grounded: bool, base: int) -> void:
	var model: Node3D = actor.get_node("Hull/VisualModel")
	var socket := Marker3D.new()
	socket.name = "PointFaible"
	model.add_child(socket)
	# Drone hits use the existing hull collider and the model's built-in optical sensor.
	socket.global_position = actor.to_global(Vector3(0,1.42,.98) if grounded else Vector3(0,.025,-.49))
	actor.set_meta("weak_point",socket)
	if grounded:
		KIT.bevel(socket,Vector3.ZERO,Vector3(.45,.38,.10),.055,WORLD.STEEL)
		KIT.bevel(socket,Vector3(0,0,.065),Vector3(.28,.24,.04),.045,WORLD.AMBER)
		var sphere := SphereShape3D.new()
		sphere.radius = .21
		actor.extra_colliders.append(preload("res://scripts/actor_collision.gd").add_shape(actor,sphere,actor.to_local(socket.global_position)))
	var bastion := grounded and base>0 and actor.get_index()%3==0
	actor.set_meta("combat_role","bastion" if bastion else ("flanker" if grounded else "sentinel"))
	actor.set_meta("armor_left",3 if bastion else 0)
	actor.set_meta("armor_max",3 if bastion else 0)
	if bastion:
		actor.move_speed *= .75
		actor.preferred_range = 9.0
		var shield := KIT.bevel(model,Vector3.ZERO,Vector3(1.4,1.0,.18),.09,WORLD.STEEL)
		shield.name = "BlindageBastion"
		shield.global_position = actor.to_global(Vector3(0,1.05,-1.0))
		for x in [-.55,.55]: KIT.bevel(shield,Vector3(x,0,-.11),Vector3(.06,.73,.03),.02,WORLD.AMBER)
		actor.set_meta("armor_visual",shield)
		actor.get_node("Hull/NameTag").text = "BASTION · BLINDAGE / RÉACTEUR ARRIÈRE"

static func resolve(actor: CharacterBody3D, point: Vector3, incoming: Vector3, damage: int) -> int:
	actor.set_meta("last_weak_hit",false)
	actor.set_meta("last_armor_hit",false)
	if damage>=10000: return damage
	var weak: Node3D = actor.get_meta("weak_point") if actor.has_meta("weak_point") else null
	var weak_radius := .23 if actor.get_meta("combat_role", "") == "sentinel" else .43
	if is_instance_valid(weak) and weak.global_position.distance_to(point)<weak_radius:
		actor.set_meta("last_weak_hit",true)
		actor.charge_remaining = 0
		actor.cooldown = maxf(actor.cooldown,.65)
		actor.warning.hide()
		var charge_sound: AudioStreamPlayer3D = actor.get("charge_sound") if "charge_sound" in actor else null
		if is_instance_valid(charge_sound): charge_sound.stop()
		if actor.get("burst_remaining")!=null: actor.burst_remaining = 0
		return damage*2
	# Ablative shields protect a nearby squad for a limited number of hits, not forever.
	for guard in actor.director.get_children():
		if not guard is CharacterBody3D or not guard.get("alive") or int(guard.get_meta("armor_left",0))<=0: continue
		if guard.global_position.distance_to(actor.global_position)>4.5: continue
		if guard==actor and incoming.dot(-actor.global_basis.z)>-.3: continue
		if guard!=actor and not actor.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(guard.global_position+Vector3.UP,actor.global_position+Vector3.UP*.4,1)).is_empty(): continue
		guard.set_meta("armor_left",int(guard.get_meta("armor_left"))-1)
		actor.set_meta("last_armor_hit",true)
		guard.get_node("Hull/NameTag").text = "BASTION · ÉCRAN %d / 3 · RÉACTEUR ARRIÈRE" % int(guard.get_meta("armor_left"))
		var shield: Node3D = guard.get_meta("armor_visual",null)
		if is_instance_valid(shield) and guard.get_meta("armor_left")==0:
			preload("res://missions/lunar_escape/damage_details.gd").shed(guard,shield,incoming*3)
			shield.hide()
		return 0
	return damage

static func reset(actor: CharacterBody3D) -> void:
	if not actor.has_meta("combat_role"): return
	actor.set_meta("armor_left",actor.get_meta("armor_max",0))
	var shield: Node3D = actor.get_meta("armor_visual") if actor.has_meta("armor_visual") else null
	if is_instance_valid(shield):
		shield.show()
		actor.get_node("Hull/NameTag").text = "BASTION · ÉCRAN 3 / 3 · RÉACTEUR ARRIÈRE"
