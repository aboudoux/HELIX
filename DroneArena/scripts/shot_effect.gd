extends Node3D
## Un effet court, sans collision, libéré automatiquement.

var remaining: float = 0.0


func setup(start: Vector3, end: Vector3, beam: bool, on_target: bool) -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	var mesh_instance := MeshInstance3D.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.35, 0.95, 1.0) if beam else Color(1.0, 0.6, 0.2)
	material.emission_enabled = true
	material.emission = material.albedo_color
	material.emission_energy_multiplier = 2.5
	if beam:
		var length := start.distance_to(end)
		if length < 0.01:
			queue_free()
			return
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.012
		mesh.bottom_radius = 0.012
		mesh.height = length
		mesh.radial_segments = 6
		mesh_instance.mesh = mesh
		add_child(mesh_instance)
		global_position = (start + end) * 0.5
		quaternion = Quaternion(Vector3.UP, (end - start).normalized())
		remaining = 0.055
	else:
		var mesh := SphereMesh.new()
		mesh.radius = 0.09 if on_target else 0.045
		mesh.height = mesh.radius * 2.0
		mesh.radial_segments = 12
		mesh.rings = 6
		mesh_instance.mesh = mesh
		add_child(mesh_instance)
		global_position = start
		remaining = 0.22
	mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _physics_process(delta: float) -> void:
	remaining -= delta
	if remaining <= 0.0:
		queue_free()
