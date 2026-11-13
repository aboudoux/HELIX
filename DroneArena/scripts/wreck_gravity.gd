extends RefCounted
## Layerless debris cannot receive Area gravity. Use the same volumes as the pilot.
static func acceleration(body: Node3D) -> float:
	var scene := body.get_tree().current_scene
	if scene != null:
		var world = scene.get("world")
		if world != null and world.has_method("movement_gravity"):
			# A folded robot's original pivot may rotate below the floor. Sample its
			# physical hull center, which remains inside the room, rather than its feet.
			var center: Vector3 = body.get_meta("gravity_center",Vector3.ZERO)
			return world.movement_gravity(body.to_global(center)).length()
	return 1.62

static func scale_for(body: Node3D) -> float:
	return acceleration(body) / float(ProjectSettings.get_setting("physics/3d/default_gravity"))
