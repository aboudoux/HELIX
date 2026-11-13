extends RefCounted


static func add_shape(body: CollisionObject3D, shape: Shape3D, center: Vector3) -> CollisionShape3D:
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = center
	body.add_child(collider)
	return collider


static func add_box(body: CollisionObject3D, size: Vector3, center: Vector3) -> CollisionShape3D:
	var box := BoxShape3D.new()
	box.size = size
	return add_shape(body, box, center)


static func set_enabled(parts: Array[CollisionShape3D], enabled: bool) -> void:
	for part in parts:
		part.set_deferred("disabled", not enabled)


static func try_turn(body: PhysicsBody3D, basis: Basis, ground_margin := 0.0) -> void:
	var prospective := Transform3D(basis, body.global_position + Vector3.UP * ground_margin)
	if not body.test_move(prospective, Vector3.ZERO, null, 0.001, true):
		body.global_basis = basis
