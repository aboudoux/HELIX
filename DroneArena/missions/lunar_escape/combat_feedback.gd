extends RefCounted
## Bounded, cosmetic effects: never add a blocking collision layer.
static var last_sound_msec := 0

static func surface_kind(body: Node) -> String:
	return str(body.get_meta("impact_surface","metal"))

static func eject(weapon: Node3D, third_person: bool) -> void:
	var tree := weapon.get_tree()
	if tree.get_nodes_in_group("spent_cases").size()>=36: return
	var shell := RigidBody3D.new()
	shell.add_to_group("spent_cases")
	shell.collision_layer = 0
	shell.collision_mask = 1
	shell.mass = 0.025
	shell.gravity_scale = 0.45
	shell.continuous_cd = true
	var gun: Node3D = weapon.world_muzzle.get_parent() if third_person else weapon.reload_visual
	tree.current_scene.get_node("Effects").add_child(shell)
	shell.global_transform = gun.global_transform
	shell.global_position = gun.to_global(Vector3(0.08,0.02,-0.08))
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.012
	mesh.bottom_radius = 0.012
	mesh.height = 0.048 if weapon.pellets>1 else 0.032
	mesh.radial_segments = 8
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("b54f32") if weapon.pellets>1 else Color("b4a06b")
	material.metallic = 0.7
	material.roughness = 0.4
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = material
	shell.add_child(visual)
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.017
	collision.shape = shape
	shell.add_child(collision)
	shell.linear_velocity = gun.global_basis.x*randf_range(1.4,2.2)+Vector3.UP*1.1
	shell.angular_velocity = Vector3(7,3,9)
	expire(shell,2.8)

static func impact(weapon: Node3D, hit: Dictionary) -> void:
	var tree := weapon.get_tree()
	if tree.get_nodes_in_group("surface_impacts").size()>=28: return
	var kind := surface_kind(hit.collider)
	var root := Node3D.new()
	root.add_to_group("surface_impacts")
	root.set_meta("surface",kind)
	tree.current_scene.get_node("Effects").add_child(root)
	root.global_position = hit.position+hit.normal*0.018
	var particles := CPUParticles3D.new()
	root.add_child(particles)
	particles.amount = 9 if kind=="metal" else 12
	particles.lifetime = 0.32 if kind=="metal" else 0.65
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.direction = hit.normal
	particles.spread = 55
	particles.gravity = Vector3.DOWN*2.0
	particles.initial_velocity_min = 0.7
	particles.initial_velocity_max = 2.4
	particles.scale_amount_min = 0.01
	particles.scale_amount_max = 0.028 if kind!="dust" else 0.10
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("f7c16a") if kind=="metal" else (Color("a9d5d6") if kind=="glass" else Color("797875"))
	material.emission_enabled = kind=="metal"
	material.emission = Color("ec8f30")
	var mesh := SphereMesh.new()
	mesh.radial_segments = 6
	mesh.rings = 3
	mesh.material = material
	particles.mesh = mesh
	particles.emitting = true
	# A shallow star fracture on laminated glass; the pressure shell stays intact.
	if kind=="glass":
		var crack := Node3D.new()
		root.add_child(crack)
		crack.quaternion = Quaternion(Vector3.UP,hit.normal)
		for i in range(5):
			var angle := TAU*i/5.0
			preload("res://missions/lunar_escape/mesh_kit.gd").rod(crack,Vector3.ZERO,Vector3(cos(angle),0,sin(angle))*0.11,0.0025,material,4)
	var now := Time.get_ticks_msec()
	if now-last_sound_msec>60:
		last_sound_msec = now
		var sound := AudioStreamPlayer3D.new()
		root.add_child(sound)
		sound.stream = load("res://audio/impact_%s.wav"%kind)
		sound.bus = "LunarWorld" if AudioServer.get_bus_index("LunarWorld")>=0 else "Master"
		sound.volume_db = -17
		sound.unit_size = 7
		sound.max_distance = 40
		sound.play()
	expire(root,3.0 if kind=="glass" else 0.8)

static func expire(node: Node, seconds: float) -> void:
	var timer := Timer.new()
	node.add_child(timer)
	timer.one_shot = true
	timer.wait_time = seconds
	timer.timeout.connect(node.queue_free)
	timer.start()
