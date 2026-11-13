extends Node3D

const DEBRIS := preload("res://scripts/drone_debris.gd")

var remaining := 10.0
var elapsed := 0.0
var flames: CPUParticles3D
var smoke: CPUParticles3D
var glow: OmniLight3D
var anchor: Node3D
var attachment: Vector3


func start(size: float) -> void:
	anchor = get_parent()
	attachment = position
	top_level = true
	global_transform = Transform3D(Basis.IDENTITY, anchor.to_global(attachment))
	DEBRIS.prepare_resources()
	var puff_material: StandardMaterial3D = DEBRIS.resources.smoke[1]
	flames = plume(size, 20, 0.64, puff_material, true)
	# Fine glowing fragments accompany the initial electrical failure.
	var sparks := CPUParticles3D.new()
	sparks.amount = 24
	sparks.lifetime = 0.85
	sparks.one_shot = true
	sparks.explosiveness = 0.85
	sparks.direction = Vector3.UP
	sparks.spread = 75.0
	sparks.initial_velocity_min = 1.8
	sparks.initial_velocity_max = 4.5
	sparks.gravity = Vector3(0, -4, 0)
	sparks.local_coords = false
	var spark_mesh := SphereMesh.new()
	spark_mesh.radius = 0.018
	spark_mesh.height = 0.036
	var spark_material := StandardMaterial3D.new()
	spark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_material.albedo_color = Color(1, 0.6, 0.13)
	spark_material.emission_enabled = true
	spark_material.emission = Color(1, 0.3, 0.03)
	spark_material.emission_energy_multiplier = 4
	spark_mesh.material = spark_material
	sparks.mesh = spark_mesh
	add_child(sparks)
	smoke = plume(size, 25, 2.35, puff_material, false)
	glow = OmniLight3D.new()
	glow.light_color = Color("ff7531")
	glow.omni_range = size * 4.2
	add_child(glow)


func plume(size: float, count: int, duration: float, material: Material, fire: bool) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.emitting = false
	particles.amount = count
	particles.lifetime = duration
	particles.preprocess = 0.22
	particles.local_coords = false
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = size * (0.20 if fire else 0.18)
	particles.direction = Vector3.UP
	particles.spread = 26.0
	particles.gravity = Vector3(0, 1.25 if fire else 0.3, 0)
	particles.initial_velocity_min = size * (0.66 if fire else 0.42)
	particles.initial_velocity_max = size * (1.20 if fire else 0.78)
	particles.scale_amount_min = 0.50
	particles.scale_amount_max = 1.25
	particles.angular_velocity_min = -55.0
	particles.angular_velocity_max = 55.0
	particles.scale_amount_curve = Curve.new()
	particles.scale_amount_curve.add_point(Vector2(0.0, 0.46))
	particles.scale_amount_curve.add_point(Vector2(0.36, 0.85))
	particles.scale_amount_curve.add_point(Vector2(1.0, 0.12 if fire else 1.0))
	particles.color_ramp = Gradient.new()
	particles.color_ramp.offsets = PackedFloat32Array([0.0, 0.28, 0.68, 1.0])
	particles.color_ramp.colors = PackedColorArray([
		Color(1.0, 0.95, 0.58, 1.0), Color(1.0, 0.46, 0.09, 0.9),
		Color(0.94, 0.14, 0.025, 0.53), Color(0.36, 0.035, 0.013, 0.0)
	] if fire else [
		Color(0.31, 0.24, 0.20, 0.47), Color(0.25, 0.23, 0.22, 0.65),
		Color(0.40, 0.39, 0.38, 0.40), Color(0.48, 0.47, 0.46, 0.0)
	])
	var quad := QuadMesh.new()
	quad.size = Vector2(0.58, 0.99) * size if fire else Vector2(1.52, 1.62) * size
	quad.material = material
	particles.mesh = quad
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(particles)
	particles.emitting = true
	return particles


func _process(delta: float) -> void:
	elapsed += delta
	remaining -= delta
	global_position = anchor.to_global(attachment) + Vector3.UP * 0.10
	flames.emitting = remaining > 2.4
	smoke.emitting = remaining > 0.0
	glow.light_energy = (1.10 + sin(elapsed * 18.0) * 0.31 + cos(elapsed * 31.0) * 0.24) * clampf(remaining - 2.2, 0, 1)
	if remaining < -smoke.lifetime:
		queue_free()
