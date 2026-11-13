extends RefCounted
## Project regions of the user's actual photograph onto independently animated parts.
const PHOTO_MATERIALS := preload("res://missions/lunar_escape/photo_materials.gd")
const PHOTO := PHOTO_MATERIALS.EVA_PHOTO
const SURFACE := preload("res://missions/lunar_escape/eva_photo.gdshader")
const KIT := preload("res://missions/lunar_escape/mesh_kit.gd")
const WORLD := preload("res://missions/lunar_escape/lunar_world.gd")

static func apply_patch_to(part: MeshInstance3D, origin: Vector2, across: Vector2, down: Vector2, fabric := true, front := true) -> void:
	var mat := ShaderMaterial.new()
	mat.shader=SURFACE;mat.set_shader_parameter("photograph",PHOTO)
	mat.set_shader_parameter("weave_height", KIT.FINISH.PHOTO.CLOTH_HEIGHT)
	mat.set_shader_parameter("photo_origin",origin)
	mat.set_shader_parameter("photo_across",across)
	mat.set_shader_parameter("photo_down",down)
	mat.set_shader_parameter("part_size",part.mesh.get_aabb().size)
	mat.set_shader_parameter("part_center",part.mesh.get_aabb().get_center())
	mat.set_shader_parameter("fabric",fabric)
	mat.set_shader_parameter("patch_on_front",front)
	part.material_override=mat

static func dress_pilot(suit: Node3D) -> void:
	apply_patch_to(suit.torso.get_child(0),Vector2(390,540),Vector2(220,0),Vector2(0,170))
	for limb in suit.limbs:
		apply_limb_photo(limb.upper.get_child(0),limb.arm,true)
		apply_limb_photo(limb.lower.get_child(0),limb.arm,false)
		apply_end_photo(limb.end,limb.arm)

static func apply_limb_photo(mesh: MeshInstance3D, arm: bool, upper: bool) -> void:
	if arm:
		# Rotated strips follow the shoulder-to-wrist direction in the source.
		var patch: Array = [Vector2(326,326),Vector2(63,24),Vector2(-91,172)] if upper else PHOTO_MATERIALS.EVA_FOREARM
		apply_patch_to(mesh,patch[0],patch[1],patch[2])
	else:
		if upper: apply_patch_to(mesh,Vector2(322,770),Vector2(151,0),Vector2(-18,238))
		else: apply_patch_to(mesh,Vector2(295,1020),Vector2(149,0),Vector2(-24,284))
		mesh.material_override.set_shader_parameter("soil_amount",.04 if upper else .16)

static func apply_end_photo(mesh: MeshInstance3D, arm: bool) -> void:
	if arm:
		var patch: Array = PHOTO_MATERIALS.EVA_GLOVE
		apply_patch_to(mesh,patch[0],patch[1],patch[2])
	else:
		apply_patch_to(mesh,Vector2(252,1337),Vector2(142,0),Vector2(0,151))
		mesh.material_override.set_shader_parameter("soil_amount",.32)

static func dress(suit: Node3D) -> void:
	# Apply source cloth to every textile part first, including pockets, hoses,
	# boots and backpack. Particular regions then replace this base on the front.
	for piece in suit.find_children("*","MeshInstance3D",true,false):
		var mat: Material=piece.get_active_material(0)
		if mat is ShaderMaterial and mat.shader.resource_path.ends_with("escort_suit.gdshader"):
			var tint: Color=mat.get_shader_parameter("tint")
			if tint.get_luminance()>.35:
				apply_patch_to(piece,Vector2(360,820),Vector2(60,0),Vector2(0,75),true,false)
	apply_patch_to(suit.torso.get_child(0),Vector2(390,540),Vector2(220,0),Vector2(0,170))
	var pack: MeshInstance3D=suit.torso.get_node("EVAControlPack")
	# The photographic control pack already contains its own seams, screws,
	# label patch and connectors. Remove the previous smooth placeholder discs.
	for child in pack.get_children(): child.hide()
	apply_patch_to(pack,Vector2(413,348),Vector2(196,0),Vector2(0,174),false)
	for limb in suit.limbs:
		var radius: float=.085 if limb.arm else .12
		for segment in [limb.upper,limb.lower]:
			var upper: bool=segment==limb.upper
			var mesh: MeshInstance3D=segment.get_child(0)
			mesh.mesh=pressure_mesh(radius*(1.0 if upper else .90),limb.length)
			mesh.position.y=-limb.length*.5
			for child in segment.get_children():
				if child!=mesh and child is GeometryInstance3D: child.hide()
			var joint:=WORLD.ball(segment,Vector3.ZERO,Vector3.ONE*radius*1.53,suit.cloth)
			apply_patch_to(joint,Vector2(360,820),Vector2(60,0),Vector2(0,75),true,false)
			apply_limb_photo(mesh,limb.arm,upper)
		if not limb.arm:
			limb.end.mesh=KIT.rounded_box(Vector3(.115,.08,.175),.065)
		apply_end_photo(limb.end,limb.arm)
	# A short fabric pelvis joins the trousers to the jacket when the legs move.
	var pelvis:=KIT.bevel(suit.torso,Vector3(0,-.30,0),Vector3(.40,.20,.29),.075,suit.cloth)
	apply_patch_to(pelvis,Vector2(360,686),Vector2(290,0),Vector2(0,135))

static func pressure_mesh(radius: float, length: float) -> ArrayMesh:
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	const AROUND := 32
	const ALONG := 40
	for row in range(ALONG+1):
		var t:=float(row)/ALONG
		for column in range(AROUND+1):
			var angle:=float(column)/AROUND*TAU
			# Broad, irregular compressed cloth folds; no stacked torus bracelets.
			var fold:=sin(t*41.0+sin(angle*3.0)*1.7)*.026
			fold+=sin(t*69.0-angle*2.0)*.013
			var taper:=.72+.28*sin(pow(t,.8)*PI)
			var r:=radius*(taper+fold*sin(t*PI))
			surface.set_smooth_group(0)
			surface.set_uv(Vector2(float(column)/AROUND,t))
			surface.add_vertex(Vector3(cos(angle)*r,(.5-t)*length,sin(angle)*r*.94))
	for row in range(ALONG):
		for column in range(AROUND):
			var a:=row*(AROUND+1)+column
			var b:=a+AROUND+1
			for index in [a,b,a+1,b,b+1,a+1]: surface.add_index(index)
	surface.generate_normals()
	return surface.commit()
