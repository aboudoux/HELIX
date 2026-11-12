extends RigidBody3D
## Modèle intact, chute physique puis épave persistante, séparée des effets courts.

signal landed(wreck: RigidBody3D)
const DRONE_CRASH := preload("res://audio/drone_crash.wav")
const BOSS_CRASH := preload("res://audio/boss_crash.wav")
static var collision_cache: Dictionary = {}
var visual: Node3D
var crash_sound: AudioStreamPlayer3D
var heavy: bool = false
var impact_count: int = 0
var settled: bool = false
var stable_time: float = 0.0
var rotor_speed: float = 32.0
var gun_speed: float = 0.0
var blades: Array[Node3D] = []
var barrels: Array[Node3D] = []


func setup(source: Node3D, inherited_velocity: Vector3, is_boss: bool, initial_gun_speed: float = 0.0) -> void:
	heavy = is_boss
	gun_speed = initial_gun_speed
	add_to_group("drone_wrecks")
	global_transform = source.global_transform
	visual = source.duplicate() as Node3D
	visual.name = "Visual"
	visual.transform = Transform3D.IDENTITY
	add_child(visual)
	var key := source.scene_file_path
	if not collision_cache.has(key):
		var points := PackedVector3Array()
		var inverse := visual.global_transform.affine_inverse()
		for mesh in visual.find_children("*","MeshInstance3D",true,false):
			var relative: Transform3D = inverse*mesh.global_transform
			for surface in range(mesh.mesh.get_surface_count()):
				var vertices: PackedVector3Array = mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
				for vertex in vertices: points.append(relative*vertex)
		var shape := ConvexPolygonShape3D.new()
		shape.points = points
		collision_cache[key] = shape
	var hit_shape := CollisionShape3D.new()
	hit_shape.name = "CollisionShape3D"
	hit_shape.shape = collision_cache[key]
	add_child(hit_shape)
	# Même couche que le décor : les épaves arrêtent aussi les tirs.
	collision_layer = 1
	collision_mask = 1
	mass = 420.0 if heavy else 18.0
	gravity_scale = .6
	linear_damp = .55
	angular_damp = 2.2
	continuous_cd = true
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = .95
	physics_material_override.bounce = .035 if heavy else .08
	contact_monitor = true
	max_contacts_reported = 8
	body_entered.connect(_on_contact)
	linear_velocity = inherited_velocity.limit_length(8)+Vector3.DOWN*.7
	angular_velocity = global_basis*Vector3(.3,.25,.55)*(1.0 if heavy else 2.2)
	_unpower_materials()
	var rotors: Node3D = visual.find_child("Rotors",true,false)
	if rotors != null:
		for rotor in rotors.get_children():
			var pivot: Node3D = rotor.find_child("Blades*",false,false)
			if pivot != null: blades.append(pivot)
	for pivot in visual.find_children("*Barrels","Node3D",true,false): barrels.append(pivot)
	crash_sound = AudioStreamPlayer3D.new()
	crash_sound.name = "CrashSound"
	crash_sound.stream = BOSS_CRASH if heavy else DRONE_CRASH
	crash_sound.volume_db = -7.0 if heavy else -10.0
	crash_sound.unit_size = 12.0 if heavy else 7.0
	crash_sound.max_distance = 75.0 if heavy else 40.0
	add_child(crash_sound)
	reset_physics_interpolation()


func _unpower_materials() -> void:
	var materials: Dictionary = {}
	for mesh in visual.find_children("*","MeshInstance3D",true,false):
		for surface in range(mesh.mesh.get_surface_count()):
			var source: Material = mesh.get_active_material(surface)
			if not source is BaseMaterial3D: continue
			var key := source.get_instance_id()
			if not materials.has(key):
				var worn: BaseMaterial3D = source.duplicate()
				worn.albedo_color = Color(.025,.035,.04,source.albedo_color.a) if source.emission_enabled else source.albedo_color.darkened(.2)
				worn.emission_enabled = false
				worn.roughness = maxf(worn.roughness,.72)
				materials[key] = worn
			mesh.set_surface_override_material(surface,materials[key])


func _on_contact(body: Node) -> void:
	if impact_count>0 or not body is CollisionObject3D or (body.collision_layer&1)==0:
		return
	impact_count = 1
	crash_sound.play()
	landed.emit(self)


func _physics_process(delta: float) -> void:
	rotor_speed = move_toward(rotor_speed,0,delta*75)
	gun_speed = move_toward(gun_speed,0,delta*120)
	for blade in blades: blade.rotate_y(delta*rotor_speed)
	for i in range(barrels.size()): barrels[i].rotate_z(delta*gun_speed*(-1 if i==0 else 1))
	var still := linear_velocity.length()<.12 and angular_velocity.length()<.15
	stable_time = stable_time+delta if impact_count>0 and still else 0.0
	if impact_count>0 and (sleeping or stable_time>.65):
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
		freeze = true
		settled = true
		set_physics_process(false)
