extends RefCounted
## Reference-inspired textile EVA finish. All details inherit the existing IK joints.
const KIT := preload("res://missions/lunar_escape/mesh_kit.gd")
const WORLD := preload("res://missions/lunar_escape/lunar_world.gd")
const FABRIC := preload("res://missions/lunar_escape/textures/user_reference/eva_reference_fabric.png")

static func dress(suit: Node3D) -> void:
	suit.cloth.set_shader_parameter("fabric_albedo",FABRIC)
	suit.cloth.set_shader_parameter("fabric_height",FABRIC)
	suit.cloth.set_shader_parameter("tint",Color("ece9df"))
	var webbing: ShaderMaterial = suit.cloth.duplicate()
	webbing.set_shader_parameter("tint",Color("b9b7ac"))
	var thread: ShaderMaterial = suit.cloth.duplicate()
	thread.set_shader_parameter("tint",Color("d3cfc2"))
	var alloy := StandardMaterial3D.new()
	alloy.resource_name = "EVAVisor" # Preserve the polished finish through the global pass.
	alloy.albedo_color = Color("adb3b5"); alloy.metallic = .85; alloy.roughness = .26
	for index in [3,4,5,6]: suit.helmet.get_child(index).hide()
	var seal := TorusMesh.new()
	seal.inner_radius=.158;seal.outer_radius=.170;seal.rings=48;seal.ring_segments=10
	var rim := MeshInstance3D.new()
	rim.mesh=seal;rim.material_override=alloy
	suit.helmet.add_child(rim)
	rim.position=Vector3(0,.012,-.14);rim.rotation.x=PI/2;rim.scale=Vector3(1,.94,.94)
	WORLD.cylinder(suit.torso,Vector3(0,.285,0),.15,.16,.09,suit.cloth)
	# Replace the old armoured breast plates and luminous screen with a pressure control pack.
	for piece in suit.plates:
		if piece.get_parent()==suit.torso: piece.hide()
	for index in [7,8,9]: suit.torso.get_child(index).hide()
	for index in [2,5]: suit.torso.get_child(index).material_override=webbing
	for label in suit.torso.find_children("*","Label3D",true,false): label.hide()
	var pack := KIT.bevel(suit.torso,Vector3(0,.025,-.207),Vector3(.31,.235,.092),.035,suit.ceramic)
	pack.name = "EVAControlPack"
	KIT.bevel(pack,Vector3(-.032,.037,-.048),Vector3(.13,.077,.013),.009,suit.cloth)
	for side in [-1.0,1.0]:
		var start := Vector3(side*.196,.236,-.10)
		var finish := Vector3(side*.139,.105,-.21)
		var strap := KIT.bevel(suit.torso,(start+finish)*.5,Vector3(.046,start.distance_to(finish),.017),.005,webbing)
		strap.basis = Basis(Quaternion(Vector3.UP,finish.direction_to(start)))
		KIT.bevel(strap,Vector3(0,-.025,-.013),Vector3(.057,.035,.012),.004,alloy)
		KIT.bevel(strap,Vector3(0,-.025,-.020),Vector3(.039,.018,.006),.002,webbing)
		# Double-stitched pocket edges and waist webbing.
		KIT.bevel(suit.torso,Vector3(side*.15,-.234,-.171),Vector3(.25,.036,.018),.004,webbing)
		for offset in [-.044,.044]:
			KIT.rod(suit.torso,Vector3(side*.22+offset,-.16,-.185),Vector3(side*.22+offset,-.29,-.185),.0018,thread,6)
		var port := WORLD.cylinder(pack,Vector3(side*.095,-.058,-.053),.026,.026,.018,alloy,Vector3(PI/2,0,0))
		WORLD.cylinder(port,Vector3(0,-.011,0),.016,.016,.005,WORLD.GRIP)
		# Helmet side lamp modules and visible metallic fasteners.
		KIT.bevel(suit.helmet,Vector3(side*.19,.065,-.083),Vector3(.052,.11,.055),.012,suit.ceramic)
		for y in [.042,.09]:
			WORLD.cylinder(suit.helmet,Vector3(side*.19,y,-.115),.017,.017,.009,alloy,Vector3(PI/2,0,0))
			WORLD.ball(suit.helmet,Vector3(side*.19,y,-.122),Vector3(.022,.022,.008),suit.ceramic)
	# Fabric seams follow each independent upper/lower limb, never bridge a moving joint.
	for limb in suit.limbs:
		var radius: float = .081 if limb.arm else .115
		for segment in [limb.upper,limb.lower]:
			var r := radius*(1.0 if segment==limb.upper else .88)
			for side in [-1.0,1.0]:
				KIT.rod(segment,Vector3(side*r*.72,-.10,-r*.70),Vector3(side*r*.72,-limb.length+.08,-r*.70),.0016,thread,6)
		if not limb.arm:
			KIT.bevel(limb.upper,Vector3(limb.side*.095,-.23,-.04),Vector3(.065,.15,.14),.02,suit.cloth)
			KIT.bevel(limb.upper,Vector3(limb.side*.128,-.19,-.045),Vector3(.009,.023,.13),.003,webbing)
			KIT.bevel(limb.end,Vector3(0,.046,-.05),Vector3(.205,.027,.06),.006,webbing)
			KIT.bevel(limb.end,Vector3(.065,.048,-.083),Vector3(.035,.03,.012),.003,alloy)
