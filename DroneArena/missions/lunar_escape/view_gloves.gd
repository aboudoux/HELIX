extends RefCounted
## Sewn gloves in the existing grip coordinates; reload/pump pivots remain unchanged.
const KIT := preload("res://missions/lunar_escape/mesh_kit.gd")
const FABRIC := preload("res://missions/lunar_escape/glove_fabric.gdshader")
const PHOTO := preload("res://missions/lunar_escape/photo_materials.gd")

static func material(tint: Color, leather := false, patch: Array = []) -> ShaderMaterial:
	var result := ShaderMaterial.new(); result.shader = FABRIC
	result.set_shader_parameter("tint",tint); result.set_shader_parameter("leather",leather)
	PHOTO.bind_fabric(result,leather)
	if not patch.is_empty():
		result.set_shader_parameter("use_eva_photo",true)
		result.set_shader_parameter("eva_photo",PHOTO.EVA_PHOTO)
		result.set_shader_parameter("photo_origin",patch[0])
		result.set_shader_parameter("photo_across",patch[1])
		result.set_shader_parameter("photo_down",patch[2])
	return result

static func oval(parent: Node3D, point: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new(); mesh.radius = 0.5; mesh.height = 1.0
	mesh.radial_segments = 28; mesh.rings = 16
	var node := MeshInstance3D.new(); node.mesh = mesh; node.material_override = mat
	node.position = point; node.scale = size; parent.add_child(node)
	return node

static func segment(parent: Node3D, a: Vector3, b: Vector3, radius: float, mat: Material) -> void:
	var mesh := CapsuleMesh.new(); mesh.radius = radius; mesh.height = a.distance_to(b)+radius*2
	mesh.radial_segments = 20; mesh.rings = 8
	var node := MeshInstance3D.new(); node.mesh = mesh; node.material_override = mat
	node.position = (a+b)*0.5; node.basis = Basis(Quaternion(Vector3.UP,a.direction_to(b)))
	parent.add_child(node)

static func finger(parent: Node3D, points: Array, radius: float, mat: Material) -> void:
	for i in range(points.size()-1): segment(parent,points[i],points[i+1],radius*(1.0-i*0.09),mat)

static func forearm(parent: Node3D, start: Vector3, end: Vector3, radius: float, cloth: Material, cuff: Material) -> void:
	var axis := start.direction_to(end)
	for band in [false,true]:
		var mesh := CylinderMesh.new()
		mesh.radial_segments = 32
		mesh.height = 0.024 if band else start.distance_to(end)
		mesh.bottom_radius = radius+(0.003 if band else 0.0)
		mesh.top_radius = radius+(0.004 if band else 0.012)
		var node := MeshInstance3D.new(); node.mesh = mesh
		node.material_override = cuff if band else cloth
		node.position = start+axis*0.012 if band else (start+end)*0.5
		node.basis = Basis(Quaternion(Vector3.UP,axis)); parent.add_child(node)
		parent.set_meta("cuff" if band else "sleeve",node)
	parent.set_meta("wrist_anchor",start)

static func align_forearm(glove: Node3D, camera: Camera3D, side: float) -> void:
	if not glove.has_meta("sleeve"): return
	var start: Vector3 = glove.get_meta("wrist_anchor")
	var end := glove.to_local(camera.to_global(Vector3(side*.43,-.57,-.02)))
	var direction := start.direction_to(end)
	var sleeve: MeshInstance3D = glove.get_meta("sleeve")
	sleeve.mesh.height = start.distance_to(end)
	sleeve.position = (start+end)*.5
	sleeve.basis = Basis(Quaternion(Vector3.UP,direction))
	var cuff: MeshInstance3D = glove.get_meta("cuff")
	cuff.position = start+direction*.012
	cuff.basis = sleeve.basis

static func build(parent: Node3D, left: bool) -> void:
	var cloth := material(Color("e6e4d9"),false,PHOTO.EVA_GLOVE)
	var palm := material(Color("282f32"),true)
	var sleeve := material(Color("f0eee3"),false,PHOTO.EVA_FOREARM)
	sleeve.set_shader_parameter("sleeve",true)
	var thread := material(Color("aaa99e"))
	if left:
		oval(parent,Vector3(-0.066,-0.105,-0.260),Vector3(0.092,0.060,0.133),cloth)
		oval(parent,Vector3(-0.065,-0.081,-0.259),Vector3(0.078,0.021,0.114),palm)
		for i in range(4):
			var z := -0.302+i*0.027
			finger(parent,[Vector3(-0.095,-0.106,z),Vector3(-0.112,-0.065,z),Vector3(-0.089,-0.034,z),Vector3(-0.046,-0.035,z)],0.0115 if i<3 else 0.0105,cloth)
			KIT.rod(parent,Vector3(-0.119,-0.066,z-0.005),Vector3(-0.119,-0.066,z+0.005),0.0008,thread,6)
		finger(parent,[Vector3(-0.044,-0.113,-0.207),Vector3(-0.008,-0.098,-0.197),Vector3(0.023,-0.073,-0.219),Vector3(0.025,-0.065,-0.244)],0.014,cloth)
		segment(parent,Vector3(-0.075,-0.129,-0.203),Vector3(-0.105,-0.182,-0.137),0.044,cloth)
		forearm(parent,Vector3(-0.105,-0.182,-0.137),Vector3(-0.162,-0.291,0.068),0.046,sleeve,palm)
		KIT.rod(parent,Vector3(-0.108,-0.121,-0.279),Vector3(-0.108,-0.121,-0.228),0.0009,thread,6)
	else:
		oval(parent,Vector3(0.015,-0.165,0.173),Vector3(0.096,0.126,0.062),cloth)
		oval(parent,Vector3(0.015,-0.165,0.146),Vector3(0.075,0.104,0.018),palm)
		for i in range(3):
			var y := -0.146-i*0.025
			finger(parent,[Vector3(0.046,y,0.17),Vector3(0.057,y,0.115),Vector3(0.025,y,0.078),Vector3(-0.030,y,0.089)],0.0125-i*0.001,cloth)
			KIT.rod(parent,Vector3(0.060,y-0.004,0.136),Vector3(0.060,y+0.004,0.136),0.0009,thread,6)
		finger(parent,[Vector3(0.039,-0.124,0.147),Vector3(0.050,-0.112,0.095),Vector3(0.023,-0.112,0.048),Vector3(0.010,-0.117,0.027)],0.0115,cloth)
		finger(parent,[Vector3(-0.029,-0.14,0.183),Vector3(-0.051,-0.110,0.159),Vector3(-0.051,-0.101,0.110),Vector3(-0.032,-0.112,0.087)],0.014,cloth)
		segment(parent,Vector3(0.026,-0.213,0.186),Vector3(0.055,-0.265,0.231),0.047,cloth)
		forearm(parent,Vector3(0.055,-0.265,0.231),Vector3(0.145,-0.403,0.437),0.050,sleeve,palm)
		KIT.rod(parent,Vector3(0.051,-0.14,0.195),Vector3(0.051,-0.20,0.195),0.0009,thread,6)
