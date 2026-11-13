extends StaticBody3D

var parts: Array[CollisionShape3D] = []
var footprint: Vector2


func build(body_parts: Array) -> void:
	for part in body_parts:
		var shape := BoxShape3D.new()
		shape.size = part[1]
		var collider := CollisionShape3D.new()
		collider.position = part[0]
		collider.shape = shape
		add_child(collider)
		parts.append(collider)
		var center: Vector3 = part[0]
		var half := shape.size * 0.5
		footprint.x = maxf(footprint.x, absf(center.x) + half.x)
		footprint.y = maxf(footprint.y, absf(center.z) + half.z)


func set_parked(parked: bool) -> void:
	for part in parts:
		part.set_deferred("disabled", not parked)
