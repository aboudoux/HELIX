extends Node3D
## Débris cosmétiques regroupés par matériau, avec rebonds sur le décor.

const MAX_ACTIVE := 16
const IMPACT_LIFETIME := 1.65
const DESTRUCTION_LIFETIME := 3.0
static var resources: Dictionary = {}
var elapsed: float = 0.0
var lifetime: float = IMPACT_LIFETIME
var destruction: bool = false
var pieces: Array[Dictionary] = []
var sparks: Array[Dictionary] = []
var smoke: Array[Dictionary] = []
var batches: Dictionary = {}
var flash: MeshInstance3D
var light: OmniLight3D
var shockwave: MeshInstance3D
var rng := RandomNumberGenerator.new()


static func material(color: Color, metallic: float = 0.0, glow: float = 0.0) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.metallic = metallic
	result.roughness = .47
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	result.vertex_color_use_as_albedo = true
	if glow > 0:
		result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		result.emission_enabled = true
		result.emission = color
		result.emission_energy_multiplier = glow
	return result


static func triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	tool.set_color(color)
	tool.set_normal((b-a).cross(c-a).normalized())
	for point in [a,b,c]:
		tool.add_vertex(point)


static func plate(color: Color) -> ArrayMesh:
	var shape := PackedVector2Array([Vector2(-.5,-.34),Vector2(-.15,-.5),Vector2(.47,-.23),Vector2(.32,.1),Vector2(.5,.39),Vector2(-.3,.5)])
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(shape.size()):
		var a := Vector3(shape[i].x,.055,shape[i].y)
		var b := Vector3(shape[(i+1)%shape.size()].x,.055,shape[(i+1)%shape.size()].y)
		triangle(tool,Vector3(0,.055,0),b,a,color)
		triangle(tool,Vector3(0,-.055,0),a-Vector3(0,.11,0),b-Vector3(0,.11,0),Color(.25,.3,.32))
		triangle(tool,a,b,b-Vector3(0,.11,0),Color(.28,.33,.35))
		triangle(tool,a,b-Vector3(0,.11,0),a-Vector3(0,.11,0),Color(.28,.33,.35))
	# Bande de sécurité et tranches métalliques sur le fragment arraché.
	triangle(tool,Vector3(-.31,.057,-.035),Vector3(.29,.057,.035),Vector3(.29,.057,-.035),Color(.96,.25,.035))
	triangle(tool,Vector3(-.31,.057,-.035),Vector3(-.31,.057,.035),Vector3(.29,.057,.035),Color(.96,.25,.035))
	return tool.commit()


static func wire_mesh() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points := [Vector3(-.5,0,0),Vector3(-.25,.12,.08),Vector3(0,-.1,.04),Vector3(.25,.12,-.08),Vector3(.5,0,0)]
	for i in range(points.size()-1):
		var axis: Vector3 = (points[i+1]-points[i]).normalized()
		var basis := Basis(Quaternion(Vector3.UP,axis))
		for side in range(6):
			var a := basis*Vector3(cos(side*TAU/6)*.035,0,sin(side*TAU/6)*.035)
			var b := basis*Vector3(cos((side+1)*TAU/6)*.035,0,sin((side+1)*TAU/6)*.035)
			triangle(tool,points[i]+a,points[i+1]+a,points[i+1]+b,Color.WHITE)
			triangle(tool,points[i]+a,points[i+1]+b,points[i]+b,Color.WHITE)
	return tool.commit()


static func prepare_resources() -> void:
	if not resources.is_empty():
		return
	var steel := material(Color.WHITE,.72)
	var blade := BoxMesh.new()
	blade.size = Vector3(.24,.045,1.0)
	var bolt := CylinderMesh.new()
	bolt.top_radius = .28
	bolt.bottom_radius = .15
	bolt.height = .8
	bolt.radial_segments = 6
	var cell := CylinderMesh.new()
	cell.top_radius = .22
	cell.bottom_radius = .22
	cell.height = .8
	cell.radial_segments = 10
	var sphere := SphereMesh.new()
	sphere.radius = .5
	sphere.height = 1.0
	sphere.radial_segments = 12
	sphere.rings = 6
	var streak := BoxMesh.new()
	streak.size = Vector3.ONE
	resources = {
		"armor": [plate(Color(.76,.8,.72)),steel],
		"metal": [plate(Color(.32,.39,.42)),steel],
		"bolt": [bolt,material(Color(.38,.44,.47),.85)],
		"blade": [blade,material(Color(.035,.055,.065),.55)],
		"wire": [wire_mesh(),material(Color(.68,.23,.065),.7)],
		"cell": [cell,material(Color(.03,.55,.68),.3,1.4)],
		"spark": [streak,material(Color(1,.42,.08),0,3.5)],
		"flash_mesh": sphere,
		"flash_material": material(Color(1,.88,.62),0,4.0),
	}
	var texture_image := Image.create(64,64,false,Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 1707
	noise.frequency = .10
	for x in range(64):
		for y in range(64):
			var radius := Vector2(x-31.5,y-31.5).length()/31.5
			var alpha := pow(maxf(0,1-radius*radius),2.2)*(.7+.3*noise.get_noise_2d(x,y))
			texture_image.set_pixel(x,y,Color(1,1,1,alpha))
	var smoke_material := material(Color.WHITE)
	smoke_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	smoke_material.albedo_texture = ImageTexture.create_from_image(texture_image)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	resources["smoke"] = [quad,smoke_material]


func batch(kind: String, count: int) -> MultiMesh:
	var instance := MultiMeshInstance3D.new()
	instance.name = kind.capitalize()
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh := MultiMesh.new()
	mesh.transform_format = MultiMesh.TRANSFORM_3D
	mesh.use_colors = true
	mesh.mesh = resources[kind][0]
	mesh.instance_count = count
	instance.multimesh = mesh
	instance.material_override = resources[kind][1]
	add_child(instance)
	batches[kind] = mesh
	return mesh


func setup(origin: Vector3, normal: Vector3, incoming: Vector3, heavy: bool = false, inherited_velocity: Vector3 = Vector3.ZERO) -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	destruction = heavy
	lifetime = DESTRUCTION_LIFETIME if heavy else IMPACT_LIFETIME
	global_transform = Transform3D(Basis.IDENTITY,origin)
	add_to_group("drone_debris_effects")
	var active := get_tree().get_nodes_in_group("drone_debris_effects").filter(func(effect): return not effect.is_queued_for_deletion())
	var count := active.size()-MAX_ACTIVE
	for effect in active:
		if count <= 0:
			break
		if effect != self and not effect.is_queued_for_deletion():
			effect.queue_free()
			count -= 1
	rng.randomize()
	prepare_resources()
	var outward := normal.normalized() if normal.length_squared() > .01 else -incoming.normalized()
	if outward.length_squared() < .01:
		outward = Vector3.UP
	var counts := {"armor":14,"metal":10,"bolt":8,"blade":4,"wire":6,"cell":4} if heavy else {"armor":7,"metal":5,"bolt":4,"wire":2}
	for kind in counts:
		var mesh := batch(kind,counts[kind])
		for i in range(counts[kind]):
			mesh.set_instance_color(i,Color.WHITE)
			var direction := Vector3(rng.randf_range(-1,1),rng.randf_range(-.9 if heavy else .15,1.2),rng.randf_range(-1,1)).normalized()
			if not heavy:
				direction = (outward*1.8+direction+incoming.bounce(outward)*.35).normalized()
			var radius := rng.randf_range(.10,.34) if heavy else rng.randf_range(.055,.17)
			if kind == "wire":
				radius *= 1.3
			var size := Vector3(radius,radius,radius*rng.randf_range(.7,1.4))
			pieces.append({"mesh":mesh,"index":i,"kind":kind,"position":direction*(rng.randf_range(.06,.45) if heavy else .025),
				"velocity":direction*rng.randf_range(3.5,8.5 if heavy else 6.0)+Vector3.UP*1.2+inherited_velocity*.3,
				"rotation":Vector3(rng.randf()*TAU,rng.randf()*TAU,rng.randf()*TAU),
				"spin":Vector3(rng.randf_range(-9,9),rng.randf_range(-9,9),rng.randf_range(-9,9)),
				"size":size,"bounces":0,"resting":false})
	var spark_count := 54 if heavy else 24
	batch("spark",spark_count)
	for i in range(spark_count):
		var direction := Vector3(rng.randf_range(-1,1),rng.randf_range(-.8 if heavy else -.1,1),rng.randf_range(-1,1)).normalized()
		if not heavy:
			direction = (outward*1.4+direction).normalized()
		sparks.append({"position":Vector3.ZERO,"velocity":direction*rng.randf_range(4,12),"life":rng.randf_range(.18,.7 if heavy else .45),"width":rng.randf_range(.005,.012)})
	var smoke_count := 9 if heavy else 4
	batch("smoke",smoke_count)
	for i in range(smoke_count):
		smoke.append({"position":Vector3.ZERO,"velocity":(Vector3(rng.randf_range(-1,1),rng.randf_range(.3,1),rng.randf_range(-1,1))+outward*.4)*.7,
			"size":rng.randf_range(.45,1.0) if heavy else rng.randf_range(.15,.32),"life":rng.randf_range(.65,1.25 if heavy else .8)})
	flash = MeshInstance3D.new()
	flash.name = "ImpactFlash"
	flash.mesh = resources.flash_mesh
	flash.material_override = resources.flash_material
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(flash)
	light = OmniLight3D.new()
	light.light_color = Color(1,.48,.15)
	light.omni_range = 4.0 if heavy else 1.5
	add_child(light)
	if heavy:
		shockwave = MeshInstance3D.new()
		var ring := TorusMesh.new()
		ring.inner_radius = .93
		ring.outer_radius = 1.0
		ring.rings = 32
		ring.ring_segments = 6
		shockwave.mesh = ring
		shockwave.material_override = material(Color(1,.5,.12,.65),0,2.5)
		shockwave.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		shockwave.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(shockwave)
	update_batches(0.0)


func _physics_process(delta: float) -> void:
	elapsed += delta
	if elapsed >= lifetime:
		queue_free()
		return
	update_batches(delta)


func update_batches(delta: float) -> void:
	var fade := clampf((lifetime-elapsed)/.45,0,1)
	var space := get_world_3d().direct_space_state
	for piece in pieces:
		if not piece.resting and delta > 0:
			piece.velocity += Vector3.DOWN*13.0*delta
			var next: Vector3 = piece.position+piece.velocity*delta
			var query := PhysicsRayQueryParameters3D.create(to_global(piece.position),to_global(next),1)
			var hit := space.intersect_ray(query)
			if not hit.is_empty():
				next = to_local(hit.position+hit.normal*.025)
				piece.velocity = piece.velocity.bounce(hit.normal)*.32
				piece.spin *= .5
				piece.bounces += 1
				if hit.normal.dot(Vector3.UP) > .6 and (piece.bounces >= 2 or piece.velocity.length() < .6):
					piece.resting = true
					piece.spin = Vector3.ZERO
					if piece.kind in ["armor","metal"]:
						piece.rotation = (Basis(Quaternion(Vector3.UP,hit.normal))*Basis(Vector3.UP,piece.rotation.y)).get_euler()
			piece.position = next
			piece.rotation += piece.spin*delta
		piece.mesh.set_instance_transform(piece.index,Transform3D(Basis.from_euler(piece.rotation).scaled(piece.size*fade),piece.position))
	for i in range(sparks.size()):
		var spark: Dictionary = sparks[i]
		var life := clampf(1-elapsed/spark.life,0,1)
		spark.velocity += Vector3.DOWN*8*delta
		spark.position += spark.velocity*delta
		var basis := Basis(Quaternion(Vector3.BACK,spark.velocity.normalized()))
		batches.spark.set_instance_transform(i,Transform3D(basis.scaled(Vector3(spark.width,spark.width,clampf(spark.velocity.length()*.025,.04,.3))*life),spark.position))
		batches.spark.set_instance_color(i,Color(life,life,life,1))
	for i in range(smoke.size()):
		var puff: Dictionary = smoke[i]
		var life := clampf(1-elapsed/puff.life,0,1)
		puff.position += puff.velocity*delta
		var size: float = puff.size*(.2+elapsed*2)*life
		batches.smoke.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*size),puff.position))
		batches.smoke.set_instance_color(i,Color(.23,.25,.27,life*.34))
	var flash_life := clampf(1-elapsed/(.13 if destruction else .065),0,1)
	flash.scale = Vector3.ONE*maxf(.001,flash_life*(.8 if destruction else .20))
	flash.visible = flash_life > 0
	light.light_energy = flash_life*(2.2 if destruction else 1.1)
	if shockwave != null:
		var ring_size := .25+elapsed*5
		shockwave.scale = Vector3.ONE*ring_size
		shockwave.visible = elapsed < .3
		shockwave.material_override.albedo_color.a = clampf(1-elapsed/.3,0,1)*.55
