extends RigidBody3D
## Modèle intact, chute physique puis épave persistante, séparée des effets courts.

signal landed(wreck: RigidBody3D)
const DRONE_CRASH := preload("res://audio/drone_crash.wav")
const BOSS_CRASH := preload("res://audio/boss_crash.wav")
const CRASH_BURST := preload("res://scripts/drone_burst.gd")
const FIRE := preload("res://scripts/burning_wreck.gd")
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
var explosive := false
var has_exploded := false
var damaged_materials: Array[ShaderMaterial] = []
var cooling := 1.0
var fragmented := false
var fragment_count := 0
var pose_ready := true
var lunar_wreck := false


func setup(source: Node3D, inherited_velocity: Vector3, is_boss: bool, initial_gun_speed: float = 0.0) -> void:
	heavy = is_boss
	gun_speed = initial_gun_speed
	add_to_group("drone_wrecks")
	var source_transform := source.global_transform
	var model_scale := source_transform.basis.get_scale()
	global_transform = Transform3D(source_transform.basis.orthonormalized(),source_transform.origin)
	visual = source.duplicate() as Node3D
	visual.name = "Visual"
	visual.transform = Transform3D(Basis.IDENTITY.scaled(model_scale),Vector3.ZERO)
	add_child(visual)
	var key: String = source.get_meta("wreck_geometry", source.scene_file_path)
	if not key.is_empty(): key += "@"+str(model_scale)
	var collision: ConvexPolygonShape3D = collision_cache.get(key)
	if collision == null:
		var points := PackedVector3Array()
		var inverse := global_transform.affine_inverse()
		for mesh in visual.find_children("*","MeshInstance3D",true,false):
			var relative: Transform3D = inverse*mesh.global_transform
			for surface in range(mesh.mesh.get_surface_count()):
				var vertices: PackedVector3Array = mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
				for vertex in vertices: points.append(relative*vertex)
		collision = ConvexPolygonShape3D.new()
		collision.points = points
		if not key.is_empty():
			collision_cache[key] = collision
	var hit_shape := CollisionShape3D.new()
	hit_shape.name = "CollisionShape3D"
	hit_shape.shape = collision
	add_child(hit_shape)
	lunar_wreck = get_tree().get_first_node_in_group("lunar_gravity") != null
	# Campaign wrecks fall onto scenery, but are never walls, navigation obstacles
	# or supports for actors. Keep legacy arena cover behavior unchanged.
	collision_layer = 0 if lunar_wreck else 1
	collision_mask = 1
	mass = 420.0 if heavy else 18.0
	set_fall_gravity(.6)
	linear_damp = .55
	if lunar_wreck:
		linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
		linear_damp = 0.0
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
	refit_visible_hull()
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


func set_fall_gravity(legacy_scale: float) -> void:
	gravity_scale = preload("res://scripts/wreck_gravity.gd").scale_for(self) if lunar_wreck else legacy_scale


func collapse_robot(source_height: float, size: float) -> void:
	pose_ready = false
	set_fall_gravity(1.0)
	var fall_side := -1.0 if linear_velocity.dot(global_basis.x) < 0.0 else 1.0
	angular_velocity = global_basis * Vector3(1.4, 0.28 * fall_side, 3.4 * fall_side)
	var topple := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# Articulated spiders use their own IK fold, so this tween may have no joints.
	topple.tween_interval(0.52)
	for part in visual.find_children("Hip*", "Node3D", true, false):
		if part.get_parent().has_method("fold_wreck"):
			continue
		topple.tween_property(part, "rotation:x", -0.68 if String(part.name).contains("F") else 0.58, 0.24)
	for part in visual.find_children("Knee*", "Node3D", true, false):
		if part.get_parent().has_method("fold_wreck"):
			continue
		topple.tween_property(part, "rotation:x", 1.12, 0.42).set_delay(0.06)
	for part in visual.find_children("Leg*", "Node3D", true, false):
		if part.has_method("fold_wreck"):
			part.fold_wreck()
		else:
			topple.tween_property(part, "rotation:z", 0.85 * signf(part.position.x), 0.45).set_delay(0.05)
	start_burning(Vector3(0, source_height, 0.06), size)
	topple.finished.connect(func():
		refit_visible_hull()
		pose_ready = true
		sleeping = false
		stable_time = 0.0
	)

func refit_visible_hull() -> void:
	# Resting bounds must match the folded, damaged pose, not the standing robot.
	var points := PackedVector3Array()
	var inverse := global_transform.affine_inverse()
	for mesh in visual.find_children("*","MeshInstance3D",true,false):
		if not mesh.is_visible_in_tree() or mesh.mesh==null: continue
		var relative: Transform3D = inverse*mesh.global_transform
		for surface in range(mesh.mesh.get_surface_count()):
			for vertex in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]: points.append(relative*vertex)
	if points.size()>3:
		var bounds := AABB(points[0],Vector3.ZERO)
		for point in points: bounds = bounds.expand(point)
		set_meta("gravity_center",bounds.get_center())
		var shape := ConvexPolygonShape3D.new(); shape.points = points
		get_node("CollisionShape3D").set_deferred("shape",shape)


func start_burning(origin: Vector3, size: float) -> void:
	var fire := FIRE.new()
	fire.name = "WreckFire"
	fire.position = origin
	add_child(fire)
	fire.start(size)


func try_crash_explosion(settling: bool) -> void:
	if not explosive or has_exploded or impact_count == 0:
		return
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.2,
		global_position - Vector3.UP * (4.5 if heavy else 0.98), 1, [get_rid()])
	var support := get_world_3d().direct_space_state.intersect_ray(query)
	var landed_on_floor: bool = not support.is_empty() and support.normal.y > 0.57
	if not landed_on_floor and not settling:
		return
	has_exploded = true
	if not heavy: break_apart()
	crash_sound.play()
	var effect := CRASH_BURST.new()
	get_tree().current_scene.get_node("Effects").add_child(effect)
	var site: Vector3 = support.position + Vector3.UP * 0.08 if landed_on_floor else global_position
	effect.explode(site, linear_velocity)
	start_burning(Vector3(0, 0.13, 0), 1.5 if heavy else 0.78)

func break_apart() -> void:
	if fragmented: return
	var rotors := visual.find_child("Rotors",true,false)
	if rotors==null: return
	fragmented = true
	var pieces: Array[Node] = rotors.get_children()
	for pattern in ["Chassis_HX_Ceramique*","Chassis_HX_Orange*"]:
		var shell := visual.find_child(pattern,true,false)
		if shell!=null: pieces.append(shell)
	blades.clear()
	for i in range(pieces.size()):
		var piece: Node3D = pieces[i]
		var angle := float(i)*TAU/float(pieces.size())+0.3
		var scatter := Vector3(cos(angle),0,sin(angle))*(4.3+0.5*(i%3))
		var fragment := preload("res://scripts/wreck_fragment.gd").new()
		fragment.name = "Debris_"+str(i)
		add_child(fragment)
		fragment.setup(piece,linear_velocity*0.25+scatter+Vector3.UP*(3.6+0.3*(i%2)),Vector3(2+i*0.3,1.4,-3+i*0.4))
		fragment.add_collision_exception_with(self)
		fragment_count += 1
	# Refit to the exposed frame: detached rotors must not leave a phantom hull.
	var points := PackedVector3Array()
	var inverse := global_transform.affine_inverse()
	for mesh in visual.find_children("*","MeshInstance3D",true,false):
		for i in range(8): points.append(inverse*mesh.global_transform*mesh.get_aabb().get_endpoint(i))
	if points.size()>3:
		var shape := ConvexPolygonShape3D.new()
		shape.points = points
		get_node("CollisionShape3D").shape = shape


func _unpower_materials() -> void:
	var piece_index := 0
	for piece in visual.find_children("*", "MeshInstance3D", true, false):
		var source: Material = piece.get_active_material(0)
		var paint := Color("59666b")
		var soft := false
		if source is BaseMaterial3D:
			paint = source.albedo_color
			soft = paint.get_luminance()<0.12 and source.metallic<0.35
		elif source is ShaderMaterial and source.shader==preload("res://missions/lunar_escape/surface.gdshader"):
			paint = source.get_shader_parameter("base_color")
		var charred := ShaderMaterial.new()
		charred.shader = preload("res://missions/lunar_escape/wreck_surface.gdshader")
		charred.set_shader_parameter("damage_map",preload("res://missions/lunar_escape/researched_materials.gd").DAMAGE_COLOR)
		charred.set_shader_parameter("damage_height",preload("res://missions/lunar_escape/researched_materials.gd").DAMAGE_HEIGHT)
		charred.set_shader_parameter("original_paint",paint)
		charred.set_shader_parameter("soft_part",soft)
		charred.set_shader_parameter("variation",float(piece_index%11)*0.731)
		charred.set_shader_parameter("heat",1.0)
		damaged_materials.append(charred)
		piece.material_override = charred
		piece_index += 1
		if piece_index % 4 == 0:
			piece.rotation.z += 0.18 if piece_index % 8 == 0 else -0.23
			piece.scale *= Vector3(1.0, 0.78, 1.0)
	for particles in visual.find_children("*","CPUParticles3D",true,false): particles.emitting = false

func _process(delta: float) -> void:
	cooling = maxf(0,cooling-delta/14.0)
	for material in damaged_materials: material.set_shader_parameter("heat",cooling)
	if cooling==0: set_process(false)


func worn_material(source: BaseMaterial3D, materials: Dictionary) -> BaseMaterial3D:
	var key := source.get_instance_id()
	if not materials.has(key):
		var worn := source.duplicate() as BaseMaterial3D
		worn.albedo_color = Color(.025,.035,.04,source.albedo_color.a) if source.emission_enabled else source.albedo_color.darkened(.2)
		worn.emission_enabled = false
		worn.roughness = maxf(worn.roughness,.72)
		materials[key] = worn
	return materials[key]


func _on_contact(body: Node) -> void:
	if impact_count>0 or not body is CollisionObject3D or (body.collision_layer&1)==0:
		return
	impact_count = 1
	# Let the damaged frame carry its flight momentum into a short slide.
	linear_damp = .24 if lunar_wreck and explosive and not heavy else .55
	if not explosive:
		crash_sound.play()
	landed.emit(self)


func _physics_process(delta: float) -> void:
	if lunar_wreck: set_fall_gravity(1.0)
	rotor_speed = move_toward(rotor_speed,0,delta*75)
	gun_speed = move_toward(gun_speed,0,delta*120)
	for blade in blades: blade.rotate_y(delta*rotor_speed)
	for i in range(barrels.size()): barrels[i].rotate_z(delta*gun_speed*(-1 if i==0 else 1))
	var still := linear_velocity.length()<.12 and angular_velocity.length()<.15
	stable_time = stable_time+delta if impact_count>0 and still else 0.0
	var settling := pose_ready and impact_count > 0 and (sleeping or stable_time > 0.65)
	try_crash_explosion(settling)
	if settling:
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
		freeze = true
		settled = true
		set_physics_process(false)
