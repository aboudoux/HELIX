extends RefCounted

var shift := Vector3.ZERO
var tilt := Vector3.ZERO


func kick(body: Node3D, incoming: Vector3, strength: float) -> void:
	var local := body.global_basis.inverse() * incoming.normalized()
	shift = (shift + local * strength).limit_length(strength * 1.4)
	tilt = Vector3(-local.z * 0.14, local.x * 0.08, -local.x * 0.22)


func apply(hull: Node3D, rest: Vector3, delta: float) -> void:
	hull.position = rest + shift
	hull.rotation = tilt
	var recovery := 1.0 - exp(-13.0 * delta)
	shift = shift.lerp(Vector3.ZERO, recovery)
	tilt = tilt.lerp(Vector3.ZERO, recovery)


func reset() -> void:
	shift = Vector3.ZERO
	tilt = Vector3.ZERO
