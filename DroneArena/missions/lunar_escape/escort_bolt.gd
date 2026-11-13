extends Node3D
var velocity := Vector3.ZERO
var owner_rid: RID
var life := 0.7
var squad: Node

func _ready() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("a8dfef")
	mat.emission_enabled = true
	mat.emission = Color("7da9b9")
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = Vector3(0.018,0.018,0.65)
	mesh.mesh = shape
	mesh.material_override = mat
	add_child(mesh)

func _physics_process(delta: float) -> void:
	life -= delta
	if life<=0: queue_free(); return
	var next := global_position+velocity*delta
	var ray := PhysicsRayQueryParameters3D.create(global_position,next,27,[owner_rid])
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():
		if hit.collider.has_method("receive_hit_at") and not hit.collider.is_in_group("escorts"):
			hit.collider.receive_hit_at(hit.position,hit.normal,velocity.normalized(),1)
			squad.confirmed_hits += 1
		queue_free()
	else: global_position = next
