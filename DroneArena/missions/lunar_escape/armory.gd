extends Node3D

const KIT := preload("res://missions/lunar_escape/mesh_kit.gd")
const CERAMIC := preload("res://materials/Ivory.tres")
const GRAPHITE := preload("res://materials/WeaponDark.tres")
const STEEL := preload("res://materials/WeaponSilver.tres")
const RUBBER := preload("res://materials/WeaponGrip.tres")
const ORANGE := preload("res://materials/Orange.tres")
const CYAN := preload("res://materials/Cyan.tres")
const LEFT_PALM := Vector3(-0.068, -0.102, -0.261)
const VIEWMODEL_LAYER := 1 << 1

var magazine: Node3D
var action: Node3D
var support: Node3D
var grip: Node3D
var hand_side := 1.0
var one_handed := false
var stowed := false
var stow_weight := 0.0
var magazine_seat := Vector3.ZERO
var action_seat := Vector3.ZERO
var support_seat := Vector3.ZERO
var muzzle := Vector3.ZERO
var sight_height := 0.0
var profile := ""
var shot_age := 10.0
var draw_age := 0.0
var stride := 0.0
var motion := Vector3.ZERO
var turn_lag := Vector3.ZERO
var last_view := Basis.IDENTITY
var view_initialized := false


func build(key: String, first_person: bool) -> void:
	profile = key
	action = Node3D.new()
	action.name = "Action"
	add_child(action)
	magazine = Node3D.new()
	magazine.name = "Chargeur"
	add_child(magazine)
	match key:
		"pistol": pistol()
		"shotgun": shotgun()
		"smg": compact_carbine()
	magazine.position = magazine_seat
	action.position = action_seat
	# Close viewmodels need finer sampling than two-metre habitat panels.
	var detail_materials: Dictionary={}
	for part in find_children("*","MeshInstance3D",true,false):
		var source: Material=part.material_override
		if source is ShaderMaterial and source.shader==KIT.FINISH.SURFACE:
			if not detail_materials.has(source):
				var finish:=source.duplicate() as ShaderMaterial
				var kind: int = source.get_shader_parameter("material_kind")
				var close_scale := 5.5 if kind in [KIT.FINISH.RESEARCH.Kind.POLYMER, KIT.FINISH.RESEARCH.Kind.RUBBER] else 2.7
				finish.set_shader_parameter("photo_scale",close_scale)
				detail_materials[source]=finish
			part.material_override=detail_materials[source]
	if first_person:
		build_hands(key)
		for piece in find_children("*", "GeometryInstance3D", true, false):
			piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			piece.layers = VIEWMODEL_LAYER


func build_hands(key: String) -> void:
	grip = Node3D.new()
	grip.name = "GantDroit"
	grip.position = Vector3(0, 0.050, -0.079) if key == "pistol" else (Vector3(0, 0.045, -0.060) if key == "shotgun" else Vector3(0, 0.035, -0.060))
	add_child(grip)
	support = Node3D.new()
	support.name = "GantGauche"
	add_child(support)
	var palms := {
		"pistol": Vector3(-0.064, -0.102, -0.034),
		"shotgun": Vector3(-0.067, -0.092, -0.431),
		"smg": Vector3(-0.062, -0.075, -0.327),
	}
	support_seat = palms[key] - LEFT_PALM
	support.position = support_seat
	preload("res://missions/lunar_escape/view_gloves.gd").build(grip,false)
	preload("res://missions/lunar_escape/view_gloves.gd").build(support,true)


func pistol() -> void:
	muzzle = Vector3(0, 0.030, -0.337)
	sight_height = 0.104
	magazine_seat = Vector3(0, -0.141, 0.025)
	# A slim open slide over a separate barrel, with faceted ceramic cheeks.
	panel(self, 0, 0.086, [Vector2(-0.30,-0.007),Vector2(-0.27,-0.049),Vector2(-0.085,-0.049),Vector2(0.075,-0.022),Vector2(0.075,0.013)], GRAPHITE)
	for side in [-1.0, 1.0]:
		panel(action, side * 0.045, 0.019, [Vector2(-0.316,0.013),Vector2(-0.29,0.068),Vector2(0.045,0.068),Vector2(0.065,0.042),Vector2(0.06,0.006)], CERAMIC)
		for i in range(6):
			var serration := KIT.bevel(action, Vector3(side*0.056,0.038,0.025-i*0.012),Vector3(0.006,0.037,0.005),0.002,GRAPHITE)
			serration.rotation.x = -0.22
		KIT.bevel(action,Vector3(side*0.056,0.029,-0.232),Vector3(0.005,0.012,0.070),0.003,GRAPHITE)
		KIT.bevel(action,Vector3(side*0.059,0.031,-0.258),Vector3(0.003,0.006,0.020),0.001,ORANGE)
		fastener(self,Vector3(side*0.045,-0.011,-0.091),side,0.008)
	KIT.bevel(action,Vector3(0,0.058,0.015),Vector3(0.09,0.020,0.092),0.004,GRAPHITE)
	KIT.bevel(action,Vector3(0,0.034,0.061),Vector3(0.093,0.062,0.017),0.005,GRAPHITE)
	KIT.bevel(action,Vector3(0,0.035,0.071),Vector3(0.031,0.032,0.005),0.003,STEEL)
	KIT.bevel(action,Vector3(0,0.072,-0.191),Vector3(0.06,0.009,0.166),0.003,GRAPHITE)
	KIT.rod(self,Vector3(0,0.03,0),Vector3(0,0.03,-0.31),0.022,STEEL,20)
	barrel(self,muzzle,0.027,0.014,0.035)
	grip_and_guard(Vector3(0, -0.087, 0.035), 0.17)
	cell(magazine, Vector3(0.072, 0.12, 0.091))
	sights(action, 0.035, -0.275)


func shotgun() -> void:
	muzzle = Vector3(0, 0.043, -0.735)
	sight_height = 0.105
	magazine_seat = Vector3(0, -0.103, -0.178)
	action_seat = Vector3(0, 0, -0.421)
	panel(self,0,0.108,[Vector2(-0.30,-0.035),Vector2(-0.27,0.073),Vector2(0.05,0.073),Vector2(0.09,0.028),Vector2(0.04,-0.06),Vector2(-0.20,-0.06)],GRAPHITE)
	for side in [-1.0,1.0]:
		panel(self,side*0.057,0.015,[Vector2(-0.27,0.012),Vector2(-0.24,0.064),Vector2(0.025,0.064),Vector2(0.059,0.024),Vector2(-0.025,-0.013),Vector2(-0.21,-0.019)],CERAMIC)
		KIT.bevel(self,Vector3(side*0.067,0.038,-0.134),Vector3(0.008,0.03,0.105),0.005,GRAPHITE)
		for z in [-0.235,0.023]: fastener(self,Vector3(side*0.067,0.027,z),side,0.008)
	# Skeleton stock, cheek pad and shoulder pad.
	KIT.rod(self,Vector3(0,0.032,0.05),Vector3(0,0.028,0.32),0.024,STEEL)
	KIT.rod(self,Vector3(0,-0.04,0.045),Vector3(0,-0.095,0.31),0.018,GRAPHITE)
	KIT.bevel(self,Vector3(0,0.05,0.21),Vector3(0.087,0.044,0.17),0.012,CERAMIC)
	KIT.bevel(self,Vector3(0,-0.032,0.33),Vector3(0.10,0.182,0.043),0.012,RUBBER)
	KIT.rod(self, Vector3(0, 0.043, -0.218), Vector3(0,0.043,-0.704), 0.029, STEEL,20)
	KIT.rod(self, Vector3(0, -0.033, -0.20), Vector3(0, -0.033, -0.64), 0.026, GRAPHITE)
	barrel(self,muzzle,0.042,0.024,0.063)
	KIT.bevel(action, Vector3(0, -0.037, 0), Vector3(0.11, 0.087, 0.21), 0.011, RUBBER)
	for i in range(8):
		KIT.bevel(action, Vector3(0, -0.037, -0.082 + i * 0.024), Vector3(0.124, 0.099, 0.009), 0.003, GRAPHITE)
	for side in [-1.0,1.0]:
		KIT.bevel(action,Vector3(side*0.064,-0.023,0),Vector3(0.009,0.038,0.17),0.004,ORANGE)
		KIT.rod(action,Vector3(side*0.046,-0.015,0.1),Vector3(side*0.046,-0.015,0.26),0.009,STEEL)
	# Visible spare shells on the receiver's left side.
	for i in range(4):
		var z := -0.20+i*0.043
		KIT.rod(self,Vector3(-0.081,-0.014,z),Vector3(-0.081,0.047,z),0.013,ORANGE)
		KIT.rod(self,Vector3(-0.081,0.047,z),Vector3(-0.081,0.055,z),0.014,STEEL)
	grip_and_guard(Vector3(0, -0.086, 0.053), 0.167)
	cell(magazine, Vector3(0.096, 0.112, 0.152))
	sights(self, 0.042, -0.674)


func compact_carbine() -> void:
	muzzle = Vector3(0, 0.025, -0.625)
	sight_height = 0.154
	magazine_seat = Vector3(0, -0.102, -0.161)
	panel(self,0,0.096,[Vector2(-0.30,-0.036),Vector2(-0.29,0.078),Vector2(0.07,0.078),Vector2(0.095,0.023),Vector2(0.02,-0.035),Vector2(-0.11,-0.064)],GRAPHITE)
	for side in [-1.0,1.0]:
		panel(self,side*0.052,0.016,[Vector2(-0.29,0.018),Vector2(-0.26,0.069),Vector2(0.044,0.069),Vector2(0.069,0.028),Vector2(0.006,-0.007),Vector2(-0.21,-0.016)],CERAMIC)
		# Segmented handguard: actual gaps reveal the inner barrel.
		for i in range(5):
			panel(self,side*0.05,0.016,[Vector2(-0.50+i*0.042,-0.025),Vector2(-0.50+i*0.042,0.063),Vector2(-0.472+i*0.042,0.063),Vector2(-0.472+i*0.042,-0.025)],CERAMIC)
		for z in [-0.25,0.025]: fastener(self,Vector3(side*0.063,0.038,z),side,0.008)
		KIT.bevel(self,Vector3(side*0.064,0.038,-0.081),Vector3(0.008,0.028,0.106),0.005,GRAPHITE)
	KIT.bevel(action,Vector3(0.071,0.038,-0.08),Vector3(0.038,0.023,0.047),0.005,STEEL)
	KIT.rod(self,Vector3(0,0.025,-0.25),Vector3(0,0.025,-0.59),0.022,STEEL,20)
	barrel(self,muzzle,0.032,0.016,0.065)
	KIT.bevel(self,Vector3(0,-0.039,-0.37),Vector3(0.082,0.027,0.26),0.006,RUBBER)
	KIT.bevel(self,Vector3(0,0.083,-0.21),Vector3(0.045,0.018,0.55),0.004,GRAPHITE)
	for i in range(17):
		KIT.bevel(self,Vector3(0,0.095,0.028-i*0.03),Vector3(0.061,0.009,0.012),0.002,STEEL)
	for x in [-0.026,0.026]:
		KIT.rod(self,Vector3(x,0.02,0.06),Vector3(x,-0.004,0.29),0.012,STEEL)
	KIT.bevel(self,Vector3(0,0.043,0.18),Vector3(0.076,0.045,0.16),0.009,CERAMIC)
	KIT.bevel(self,Vector3(0,-0.025,0.30),Vector3(0.095,0.16,0.042),0.009,RUBBER)
	grip_and_guard(Vector3(0,-0.106,0.052),0.17)
	cell(magazine, Vector3(0.078, 0.183, 0.102))
	# Open reflex sight: glass stays subtle and the centre remains unobstructed.
	for x in [-0.029,0.029]:
		KIT.bevel(self,Vector3(x,0.144,-0.065),Vector3(0.009,0.085,0.039),0.003,GRAPHITE)
	KIT.bevel(self,Vector3(0,0.185,-0.065),Vector3(0.065,0.009,0.039),0.003,GRAPHITE)
	KIT.bevel(self,Vector3(0,0.111,-0.065),Vector3(0.057,0.009,0.042),0.003,GRAPHITE)
	KIT.bevel(self,Vector3(0,0.154,-0.075),Vector3(0.003,0.003,0.004),0.001,CYAN)
	KIT.bevel(self,Vector3(-0.063,0.012,-0.185),Vector3(0.005,0.008,0.046),0.002,ORANGE)


func panel(parent: Node3D, x: float, width: float, outline: Array, material: Material) -> void:
	# Extrude an authored silhouette in the YZ plane; hard normals keep the machined edges.
	var polygon := PackedVector2Array(outline)
	if Geometry2D.is_polygon_clockwise(polygon):
		polygon.reverse()
	var triangles := Geometry2D.triangulate_polygon(polygon)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.0,1.0]:
		for i in range(0,triangles.size(),3):
			for j in ([0,1,2] if side > 0 else [2,1,0]):
				var p := polygon[triangles[i+j]]
				surface.set_normal(Vector3(side,0,0))
				surface.add_vertex(Vector3(x+side*width*0.5,p.y,p.x))
	for i in range(polygon.size()):
		var a := polygon[i]
		var b := polygon[(i+1)%polygon.size()]
		var normal := Vector3(0,a.x-b.x,b.y-a.y).normalized()
		for p in [Vector3(x-width*0.5,a.y,a.x),Vector3(x+width*0.5,b.y,b.x),Vector3(x+width*0.5,a.y,a.x),Vector3(x-width*0.5,a.y,a.x),Vector3(x-width*0.5,b.y,b.x),Vector3(x+width*0.5,b.y,b.x)]:
			surface.set_normal(normal)
			surface.add_vertex(p)
	var mesh := MeshInstance3D.new()
	mesh.mesh = surface.commit()
	mesh.material_override = KIT.FINISH.material(material)
	parent.add_child(mesh)


func barrel(parent: Node3D, tip: Vector3, outside: float, inside: float, length: float) -> void:
	# Annular muzzle and dark inner bore, rather than a closed cylinder cap.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in range(3):
		for i in range(24):
			var a := TAU*i/24.0
			var b := TAU*(i+1)/24.0
			var r0 := outside if ring != 2 else inside
			var r1 := inside if ring == 0 else r0
			var depth := 0.0 if ring == 0 else length
			var points := [Vector3(cos(a)*r0,sin(a)*r0,0),Vector3(cos(b)*r0,sin(b)*r0,0),Vector3(cos(b)*r1,sin(b)*r1,depth),Vector3(cos(a)*r1,sin(a)*r1,depth)]
			for j in [0,1,2,0,2,3]:
				var p: Vector3 = points[j]
				surface.set_normal(Vector3.FORWARD if ring==0 else Vector3(p.x,p.y,0).normalized()*(1 if ring==1 else -1))
				surface.add_vertex(tip+p)
	var mesh := MeshInstance3D.new()
	mesh.mesh = surface.commit()
	var mat := GRAPHITE.duplicate() as StandardMaterial3D
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material_override = mat
	parent.add_child(mesh)
	KIT.rod(parent,tip+Vector3.BACK*(length-0.003),tip+Vector3.BACK*length,inside,GRAPHITE,24)


func fastener(parent: Node3D, point: Vector3, side: float, radius: float) -> void:
	KIT.rod(parent,point,point+Vector3.RIGHT*side*0.003,radius,STEEL,6)
	KIT.bevel(parent,point+Vector3.RIGHT*side*0.004,Vector3(0.002,radius*0.24,radius*1.15),0.001,GRAPHITE)


func grip_and_guard(point: Vector3, length: float) -> void:
	var grip := KIT.bevel(self, point, Vector3(0.077, length, 0.105), 0.021, RUBBER)
	grip.rotation.x = 0.16
	for i in range(6):
		KIT.bevel(grip, Vector3(0, -0.052 + i * 0.018, 0.044), Vector3(0.067, 0.007, 0.027), 0.003, GRAPHITE)
	KIT.rod(self, Vector3(0, -0.032, -0.138), Vector3(0, -0.087, -0.123), 0.012, GRAPHITE)
	KIT.rod(self, Vector3(0, -0.087, -0.123), Vector3(0, -0.085, 0.004), 0.012, GRAPHITE)
	KIT.rod(self, Vector3(0, -0.037, -0.050), Vector3(0, -0.069, -0.040), 0.009, STEEL)


func cell(node: Node3D, size: Vector3) -> void:
	KIT.bevel(node, Vector3(0, -size.y * 0.19, 0), size, 0.014, GRAPHITE)
	KIT.bevel(node, Vector3(0, -size.y * 0.64, 0), Vector3(size.x + 0.011, 0.024, size.z + 0.011), 0.009, ORANGE)
	KIT.bevel(node, Vector3(-size.x * 0.5, -size.y * 0.2, 0), Vector3(0.006, size.y * 0.44, 0.026), 0.002, CYAN)


func sights(parent: Node3D, back_z: float, front_z: float) -> void:
	for x in [-0.023, 0.023]:
		KIT.bevel(parent, Vector3(x, sight_height - 0.016, back_z), Vector3(0.015, 0.028, 0.038), 0.005, GRAPHITE)
	KIT.bevel(parent, Vector3(0, sight_height - 0.021, front_z), Vector3(0.019, 0.024, 0.035), 0.005, GRAPHITE)
	KIT.bevel(parent, Vector3(0, sight_height, front_z), Vector3(0.008, 0.008, 0.018), 0.002, CYAN)


func pose_reload(progress: float, recoil: float) -> void:
	var draw := smoothstep(0.16, 0.39, progress)
	var seat := smoothstep(0.49, 0.75, progress)
	var travel := draw * (1.0 - seat)
	var cycle := smoothstep(0.73, 0.86, progress) * (1.0 - smoothstep(0.86, 0.98, progress))
	var direction := Vector3(-0.105, -0.185, 0.045) if profile != "shotgun" else Vector3(-0.115, -0.18, 0.054)
	magazine.position = magazine_seat + direction * travel
	magazine.rotation.z = travel * -0.34
	var action_travel := 0.106 if profile == "shotgun" else 0.043
	var pump := smoothstep(0.10,0.24,shot_age)*(1.0-smoothstep(0.32,0.49,shot_age))
	var firing_motion := pump if profile == "shotgun" else recoil * 0.95
	action.position = action_seat + Vector3.BACK * maxf(cycle, firing_motion) * action_travel
	if support != null:
		support.visible = not one_handed or (progress>.12 and progress<.92 and not stowed)
		var reach := smoothstep(0.05, 0.21, progress) * (1.0 - smoothstep(0.68, 0.79, progress))
		var contact := magazine_seat + Vector3(-0.037, -0.049, 0.033) - LEFT_PALM
		support.position = support_seat.lerp(contact, reach) + direction * travel
		if profile == "shotgun":
			support.position.z += maxf(cycle,firing_motion)*action_travel*(1.0-reach)
		else:
			var rack_contact := Vector3(-0.052,0.034,0.018) if profile == "pistol" else Vector3(-0.059,0.035,-0.09)
			support.position = support.position.lerp(rack_contact-LEFT_PALM+Vector3.BACK*cycle*action_travel,cycle*0.82)
		support.rotation = Vector3(0,reach*0.15,-travel*0.30)


func fired() -> void:
	shot_age = 0.0

func align_forearms(view: Camera3D) -> void:
	if grip!=null: preload("res://missions/lunar_escape/view_gloves.gd").align_forearm(grip,view,hand_side)
	if support!=null and support.visible: preload("res://missions/lunar_escape/view_gloves.gd").align_forearm(support,view,-hand_side)


func animate_view(delta: float, view: Camera3D, body: CharacterBody3D, aim: float, reload_amount: float, kick: float) -> Transform3D:
	shot_age += delta
	draw_age += delta
	var speed := Vector2(body.velocity.x,body.velocity.z).length()
	stride += speed*delta*1.7
	var ease := 1.0-exp(-delta*11.0)
	var moving := minf(speed/6.0,1.3) if body.is_on_floor() else 0.0
	var bob := Vector3(sin(stride)*0.008,absf(cos(stride))*0.009,0)*moving
	motion = motion.lerp(bob,ease)
	if view_initialized:
		var rotation_delta := last_view.inverse()*view.global_basis
		var angles := rotation_delta.get_euler()/maxf(delta,0.001)
		turn_lag = turn_lag.lerp(Vector3(-angles.x*0.018,-angles.y*0.018,angles.y*0.009).clamp(Vector3.ONE*-0.065,Vector3.ONE*0.065),ease)
	last_view = view.global_basis
	view_initialized = true
	var weight := (1.0-aim*0.94)*(1.0-reload_amount)
	var heavy := 1.45 if profile == "shotgun" else (0.72 if profile == "smg" else 1.0)
	var draw := 1.0-smoothstep(0.0,0.30,draw_age)
	var run := clampf((speed-6.0)/3.5,0.0,1.0)*weight
	stow_weight = move_toward(stow_weight,1.0 if stowed else 0.0,delta*7.0)
	visible = stow_weight<.99
	var translation := motion*weight+Vector3(-reload_amount*.11*hand_side,kick*.027*heavy+reload_amount*.12-draw*.23-run*.025,kick*.077*heavy-reload_amount*.08+draw*.13)
	translation += Vector3(hand_side*.08,-.68,.16)*stow_weight
	var rotation := turn_lag*weight+Vector3(kick*.105*heavy-reload_amount*.08-draw*.32,(reload_amount*.22)*hand_side,(-reload_amount*.25-run*.10)*hand_side)
	return Transform3D(Basis.from_euler(rotation),translation)
