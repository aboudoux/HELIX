extends RigidBody3D
## Independent physical rotor/armor, with bounded lifetime and no invisible obstacles.
var age := 0.0
var visual: Node3D
var original_scale := Vector3.ONE
var lunar_fragment := false

func setup(piece: Node3D, impulse: Vector3, spin: Vector3) -> void:
	add_to_group("wreck_fragments")
	var active := get_tree().get_nodes_in_group("wreck_fragments")
	# At most twelve simultaneous six-piece explosions retain physical debris.
	if active.size()>72:
		for i in range(active.size()-72): active[i].queue_free()
	set_as_top_level(true)
	global_transform = piece.global_transform
	piece.reparent(self,true)
	visual = piece
	original_scale = piece.scale
	var bounds := AABB()
	var meshes := piece.find_children("*","MeshInstance3D",true,false)
	if piece is MeshInstance3D: meshes.append(piece)
	var points := PackedVector3Array()
	var inverse := global_transform.affine_inverse()
	for mesh in meshes:
		var box: AABB = mesh.get_aabb()
		for i in range(8): points.append(inverse*mesh.global_transform*box.get_endpoint(i))
	if points.is_empty(): queue_free(); return
	bounds = AABB(points[0],Vector3.ZERO)
	for point in points: bounds = bounds.expand(point)
	var center := bounds.get_center()
	global_position += global_basis*center
	piece.position -= center
	var shape := BoxShape3D.new()
	shape.size = bounds.size.max(Vector3.ONE*0.035)
	# The crash can start with a rotor penetrating the ground. Lift its bounds clear
	# before applying the explosion velocity, otherwise the contact cancels the throw.
	var floor_hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*2,global_position-Vector3.UP*2,1,[get_parent().get_rid()]))
	if not floor_hit.is_empty():
		var extent := (global_basis.x.abs()*shape.size.x+global_basis.y.abs()*shape.size.y+global_basis.z.abs()*shape.size.z)*0.5
		global_position.y = maxf(global_position.y,floor_hit.position.y+extent.y+0.08)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	add_child(collider)
	# Small debris hits the floor, but cannot trap the player in a doorway.
	collision_layer = 0; collision_mask = 1
	mass = 1.4; gravity_scale = 0.7
	linear_damp = 0.7; angular_damp = 0.8
	# Layerless fragments do not overlap Areas; apply lunar gravity explicitly.
	lunar_fragment = get_tree().get_first_node_in_group("lunar_gravity") != null
	if lunar_fragment:
		gravity_scale = preload("res://scripts/wreck_gravity.gd").scale_for(self)
		linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
		linear_damp = 0.08
	continuous_cd = true
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.bounce = 0.26
	physics_material_override.friction = 0.75
	linear_velocity = impulse
	angular_velocity = spin
	reset_physics_interpolation()

func _physics_process(delta: float) -> void:
	if lunar_fragment: gravity_scale = preload("res://scripts/wreck_gravity.gd").scale_for(self)
	age += delta
	if age>22:
		visual.scale = original_scale*maxf(0.001,1-(age-22)/2)
	if age>=24: queue_free()
