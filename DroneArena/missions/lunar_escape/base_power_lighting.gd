extends RefCounted
## Local overrides: never edit Cyan.tres, which is shared with weapons and other bases.
const DARK := preload("res://missions/lunar_escape/PowerOff.tres")
var surfaces: Array[Dictionary]=[]
var labels: Array[Dictionary]=[]
var doors: Array[Node3D]=[]
var lamps: Array[Dictionary]=[]
var probes: Array[ReflectionProbe]=[]
var initialized:=false

static func blue(color: Color) -> bool:
	return color.b>.25 and color.b>color.r*1.1 and color.g>color.r*1.1

func belongs(node: Node3D, world: Node3D) -> bool:
	if world.get_node("Selene").is_ancestor_of(node): return true
	# The two vestibules are built under Terrain, outside the Selene subtree.
	for lock in world.airlocks:
		if absf(lock.chamber.get_center().z)<30 and lock.chamber.grow(.6).has_point(node.global_position): return true
	return false

func collect(world: Node3D) -> void:
	initialized=true
	for node in world.find_children("*","Node3D",true,false):
		if not belongs(node,world): continue
		if node.has_method("set_power_available"): doors.append(node)
		if node is SpotLight3D or (node is OmniLight3D and node.get_meta("base_power_fixture",false)):
			lamps.append({"node":node,"energy":node.light_energy,"color":node.light_color})
		if node is ReflectionProbe and node.get_meta("base_power_fixture",false): probes.append(node)
		if node is Label3D and blue(node.modulate):
			labels.append({"node":node,"visible":node.visible})
		if not node is MeshInstance3D or node.mesh==null: continue
		for slot in range(node.mesh.get_surface_count()):
			var material: Material=node.get_active_material(slot)
			if not material is BaseMaterial3D or not material.emission_enabled or not (blue(material.emission) or node.get_meta("base_power_fixture",false)): continue
			if node.material_override!=null:
				surfaces.append({"node":node,"slot":-1,"original":node.material_override})
				break
			surfaces.append({"node":node,"slot":slot,"original":node.get_surface_override_material(slot)})

func set_outage(world: Node3D, outage: bool) -> void:
	if not initialized: collect(world)
	for item in surfaces:
		if not is_instance_valid(item.node): continue
		if item.slot<0: item.node.material_override=DARK if outage else item.original
		else: item.node.set_surface_override_material(item.slot,DARK if outage else item.original)
	for item in labels:
		if is_instance_valid(item.node): item.node.visible=false if outage else item.visible
	for door in doors:
		if is_instance_valid(door): door.set_power_available(not outage)
	for lock in world.airlocks:
		if absf(lock.chamber.get_center().z)<30: lock.set_power_available(not outage)
	for item in lamps:
		if not is_instance_valid(item.node): continue
		item.node.light_energy=item.energy*((0.0 if item.node.get_meta("base_power_fixture",false) else .12) if outage else 1.0)
		item.node.light_color=Color("ff704a") if outage else item.color
	for probe in probes:
		if is_instance_valid(probe): probe.visible=not outage
