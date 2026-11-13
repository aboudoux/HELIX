extends RefCounted
## Cosmetic armor fragments never block doors or navigation.
const KIT := preload("res://missions/lunar_escape/mesh_kit.gd")
const FINISH := preload("res://missions/lunar_escape/finishes.gd")
static var scar: ShaderMaterial
var plates: Array[MeshInstance3D] = []
var removed := 0
var smoke: CPUParticles3D

func build(parent: Node3D, center: Vector3, width: float, length: float) -> void:
	smoke = CPUParticles3D.new()
	parent.add_child(smoke)
	smoke.position = center+Vector3.UP*0.1
	smoke.emitting = false
	smoke.amount = 10
	smoke.lifetime = 1.4
	smoke.direction = Vector3.UP
	smoke.spread = 24
	smoke.gravity = Vector3.UP*0.12
	smoke.initial_velocity_min = 0.24
	smoke.initial_velocity_max = 0.45
	smoke.scale_amount_min = 0.12
	smoke.scale_amount_max = 0.23
	var mesh := SphereMesh.new()
	mesh.radial_segments = 6
	mesh.rings = 4
	var soot := StandardMaterial3D.new()
	soot.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	soot.vertex_color_use_as_albedo = true
	soot.albedo_color = Color(0.21,0.23,0.24,0.65)
	mesh.material = soot
	smoke.mesh = mesh
	var fade := Gradient.new()
	fade.set_color(0,Color(1,1,1,0.75))
	fade.set_color(1,Color(1,1,1,0))
	smoke.color_ramp = fade
	smoke.local_coords = false
	if scar == null:
		scar = ShaderMaterial.new()
		scar.shader = preload("res://missions/lunar_escape/wreck_surface.gdshader")
		scar.set_shader_parameter("damage_map", FINISH.RESEARCH.DAMAGE_COLOR)
		scar.set_shader_parameter("damage_height", FINISH.RESEARCH.DAMAGE_HEIGHT)
	var armor := FINISH.create(Color("99a5a3"),0.65,0.46,0.20)
	for side in [-1.0,1.0]:
		for i in range(2):
			var position := center+Vector3(side*width,0,(i-0.5)*length*0.46)
			KIT.bevel(parent,position,Vector3(0.035,0.21,length*0.35),0.01,scar)
			plates.append(KIT.bevel(parent,position+Vector3.RIGHT*side*0.025,Vector3(0.055,0.24,length*0.37),0.02,armor))

func hit(actor: Node3D, point: Vector3, fraction: float, incoming: Vector3) -> void:
	if is_instance_valid(smoke): smoke.emitting = fraction>0 and fraction<=0.5
	var expected := mini(4,int((1.0-fraction)*4.0))
	if removed>=expected: return
	var nearest: MeshInstance3D
	var distance := INF
	for plate in plates:
		if plate.visible and plate.global_position.distance_squared_to(point)<distance:
			nearest = plate
			distance = plate.global_position.distance_squared_to(point)
	if nearest != null:
		shed(actor,nearest,incoming)
		removed += 1

static func shed(actor: Node3D, mesh: MeshInstance3D, impulse: Vector3) -> void:
	var chip := RigidBody3D.new()
	chip.collision_layer = 0
	chip.collision_mask = 1
	chip.mass = 0.4
	chip.gravity_scale = 0.6
	chip.continuous_cd = true
	chip.add_to_group("armor_fragments")
	actor.get_tree().current_scene.get_node("Effects").add_child(chip)
	chip.global_transform = mesh.global_transform
	var piece := MeshInstance3D.new()
	piece.mesh = mesh.mesh
	piece.material_override = mesh.material_override
	chip.add_child(piece)
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = mesh.get_aabb().size.clamp(Vector3.ONE*0.03,Vector3.ONE*1.8)
	collider.shape = box
	chip.add_child(collider)
	chip.linear_velocity = impulse.normalized()*2.0+Vector3.UP*2.3
	chip.angular_velocity = Vector3(4,2,5)
	mesh.hide()
	# A tree-bound timer respects pause and vanishes cleanly on restart.
	var timer := Timer.new()
	timer.wait_time = 3.5
	timer.one_shot = true
	chip.add_child(timer)
	timer.timeout.connect(chip.queue_free)
	timer.start()

func reset() -> void:
	if is_instance_valid(smoke): smoke.emitting = false
	removed = 0
	for plate in plates: plate.show()
