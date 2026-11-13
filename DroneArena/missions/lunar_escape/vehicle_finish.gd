extends RefCounted
const KIT := preload("res://missions/lunar_escape/mesh_kit.gd")
const SURFACE := preload("res://missions/lunar_escape/vehicle_surface.gdshader")

static func material(color: Color, metal := 0.45, rubber := 0.0) -> ShaderMaterial:
	var result := ShaderMaterial.new(); result.shader = SURFACE
	result.set_shader_parameter("paint",color)
	result.set_shader_parameter("metal",metal)
	result.set_shader_parameter("rubber",rubber)
	KIT.FINISH.RESEARCH.bind(result,KIT.FINISH.RESEARCH.Kind.RUBBER if rubber>.5 else (KIT.FINISH.RESEARCH.Kind.METAL if metal>.7 else KIT.FINISH.RESEARCH.Kind.PAINT))
	result.set_shader_parameter("dust_map",KIT.FINISH.RESEARCH.REGOLITH_FINE)
	return result

static func dress(world: Node3D) -> void:
	var steel := material(Color("808a90"),0.85)
	var dark := material(Color("303e43"),0.55)
	var ivory := material(Color("bfc8c3"),0.35)
	var coated := material(Color("788984"),0.25)
	var rubber := material(Color("1d2529"),0.0,1.0)
	var orange := material(Color("cf783b"),0.25)
	for ride in [world.bike,world.transport,world.scout]:
		for mesh in ride.find_children("*","MeshInstance3D",true,false):
			var source: Material = mesh.material_override
			if not source is ShaderMaterial: continue
			var color: Variant = source.get_shader_parameter("base_color")
			if not color is Color: continue
			var brightness: float = (color.r+color.g+color.b)/3
			mesh.material_override = rubber if brightness<0.065 else (dark if brightness<0.2 else (coated if brightness<0.3 else (ivory if brightness>0.65 else steel)))
		if ride==world.bike:
			for side in [-1,1]:
				KIT.bevel(ride,Vector3(side*0.27,0.89,-0.28),Vector3(0.024,0.12,0.57),0.01,orange)
				for z in [-0.5,-0.15,0.2]:
					KIT.rod(ride,Vector3(side*0.25,0.7,z),Vector3(side*0.285,0.7,z),0.025,steel,8)
				KIT.rod(ride,Vector3(side*0.19,0.43,0.95),Vector3(side*0.19,0.77,0.4),0.035,steel)
				for rib in range(9): KIT.bevel(ride,Vector3(side*0.255,0.57,0.05+rib*0.045),Vector3(0.05,0.16,0.018),0.005,dark)
			world.placard(ride,"KAREN · M-02",Vector3(0.29,0.92,-0.28),Color("d5e6df"),PI/2).pixel_size = 0.0011
		else:
			for label in ride.find_children("*","Label3D",true,false): label.pixel_size = 0.0032
			for side in [-1,1]:
				for z in [-1.7,-0.6,0.5,1.6]:
					KIT.bevel(ride,Vector3(side*1.65,1.14,z),Vector3(0.13,0.45,0.89),0.04,ivory)
					for dy in [-0.14,0.14]:
						for dz in [-0.3,0.3]: KIT.rod(ride,Vector3(side*1.71,1.14+dy,z+dz),Vector3(side*1.74,1.14+dy,z+dz),0.035,steel,6)
				KIT.bevel(ride,Vector3(side*1.42,1.85,-0.75),Vector3(0.025,0.12,1.9),0.009,orange)
				for z in [0.8,1.2,1.6]: KIT.bevel(ride,Vector3(side*0.82,1.61,z),Vector3(0.65,0.035,0.18),0.009,dark)
				KIT.rod(ride,Vector3(side*1.1,1.1,2.68),Vector3(side*1.1,1.65,2.68),0.055,steel)
			world.placard(ride,"EVA / 06 · PRESSURISÉ",Vector3(0,1.3,2.66),Color("d4e7dd")).pixel_size = 0.0018
