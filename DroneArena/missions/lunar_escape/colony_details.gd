extends RefCounted

const KIT := preload("res://missions/lunar_escape/mesh_kit.gd")
const FINISH := preload("res://missions/lunar_escape/finishes.gd")
const POD_RADIUS := 10.5
const POD_Z := 39.0
const POD_X := 24.5
const LINK_HALF := 2.35
const SPRING := 3.5
const DOME_HEIGHT := 4.0
const WHITE := preload("res://materials/Ivory.tres")
const STEEL := preload("res://materials/WeaponSilver.tres")
const FLOOR := preload("res://materials/Floor.tres")
const CYAN := preload("res://materials/Cyan.tres")

static func join_z() -> float:
	return POD_Z - sqrt(POD_RADIUS * POD_RADIUS - LINK_HALF * LINK_HALF)

static func pod_x(index: int) -> float:
	return 31.5 if index == 2 else POD_X

static func breathable(local: Vector3, index: int) -> bool:
	if local.z < 19.0:
		return false
	if absf(absf(local.x) - pod_x(index)) < LINK_HALF and local.z <= join_z() and local.y < SPRING:
		return true
	var offset := Vector2(absf(local.x) - pod_x(index), local.z - POD_Z)
	return offset.length() < POD_RADIUS and local.y < SPRING + DOME_HEIGHT * sqrt(1.0 - offset.length_squared() / (POD_RADIUS * POD_RADIUS))

static func build(base: Node3D, world: Node3D, index: int) -> void:
	var glass := preload("res://missions/lunar_escape/pressure_glass.gd").material()
	for side in [-1.0, 1.0]:
		build_pod(base, world, side, index, glass)
	build_solar(base, world)

static func build_pod(base: Node3D, world: Node3D, side: float, index: int, glass: Material) -> void:
	var pod := Node3D.new()
	pod.name = "Serre" if side > 0 else "Observatoire"
	base.add_child(pod)
	pod.position = Vector3(side * pod_x(index), 0, POD_Z)
	var deck: MeshInstance3D = world.cylinder(pod, Vector3(0, -0.18, 0), POD_RADIUS + 0.12, POD_RADIUS + 0.3, 0.39, FLOOR)
	deck.create_trimesh_collision()
	var gap := asin(LINK_HALF / POD_RADIUS)
	var wall := SurfaceTool.new()
	wall.begin(Mesh.PRIMITIVE_TRIANGLES)
	var windows := SurfaceTool.new()
	windows.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sill := Vector3.UP * 1.05
	for section in range(48):
		var a := arc_point(lerpf(gap, TAU - gap, section / 48.0), POD_RADIUS, 0.0)
		var b := arc_point(lerpf(gap, TAU - gap, (section + 1) / 48.0), POD_RADIUS, 0.0)
		quad(wall, a, b, b + sill, a + sill)
		quad(windows, a + sill, b + sill, b + Vector3.UP * SPRING, a + Vector3.UP * SPRING)
		KIT.rod(pod, a + sill, b + sill, 0.045, STEEL, 6)
		if section % 4 == 0:
			KIT.rod(pod, a, a + Vector3.UP * SPRING, 0.065, STEEL, 8)
	finish_shell(pod, wall, FINISH.architecture(WHITE,FINISH.Detail.USER_WALL_PHOTO))
	var window_strip := finish_shell(pod, windows, glass)
	window_strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var glazing := SurfaceTool.new()
	glazing.begin(Mesh.PRIMITIVE_TRIANGLES)
	for longitude in range(48):
		for latitude in range(12):
			var a := TAU * longitude / 48.0
			var b := TAU * (longitude + 1) / 48.0
			var low := PI * latitude / 24.0
			var high := PI * (latitude + 1) / 24.0
			quad(glazing, dome_point(b, low), dome_point(a, low), dome_point(a, high), dome_point(b, high))
	var canopy := finish_shell(pod, glazing, glass)
	canopy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for rib in range(12):
		var angle := TAU * rib / 12.0
		for segment in range(10):
			KIT.rod(pod, dome_point(angle, PI * 0.05 * segment), dome_point(angle, PI * 0.05 * (segment + 1)), 0.045, STEEL, 6)
	for ring in [0.0, 0.48, 0.97]:
		for segment in range(48):
			KIT.rod(pod, dome_point(TAU * segment / 48, ring), dome_point(TAU * (segment + 1) / 48, ring), 0.052, STEEL, 6)
	var length := join_z() - 19.0
	var middle := Vector3(pod.position.x, 0, 19.0 + length * 0.5)
	world.block(base, middle + Vector3.DOWN * 0.13, Vector3(LINK_HALF * 2, 0.3, length + 0.28), FLOOR, true)
	for edge in [-1.0, 1.0]:
		world.block(base, middle + Vector3(edge * LINK_HALF, SPRING * 0.5, 0), Vector3(0.26, SPRING, length + 0.1), FINISH.architecture(WHITE,FINISH.Detail.USER_WALL_PHOTO), true)
		world.block(base, middle + Vector3(edge * (LINK_HALF - 0.2), 0.06, 0), Vector3(0.045, 0.025, length), CYAN)
	vault(base, middle + Vector3.UP * SPRING, LINK_HALF + 0.13, length + 0.05, 0.85, WHITE, false)
	for z in [21.0, 25.0]:
		world.ceiling_light(base, Vector3(middle.x, SPRING - 0.08, z), CYAN)
	world.build_door(base, "dome_%d_%d" % [index, int(side)], Vector3(middle.x, 0, 19.0), 3.45,
		"Serre hydroponique" if side > 0 else "Observatoire", false)
	for x in [-5.5, 5.5]:
		world.ceiling_light(pod, Vector3(x, 4.65, 0), CYAN)
		KIT.rod(pod, Vector3(x, 4.65, 0), Vector3(x, 6.87, 0), 0.042, STEEL, 8)
	if side > 0:
		world.furnishings.farm(pod, true)
	else:
		world.furnishings.table(pod, Vector3(0, 0, 3.0), Vector2(4.2, 1.3), 1.0)
		world.furnishings.screen(pod, Vector3(0, 1.78, 3.45), 2.75, "OBSERVATOIRE\nLIAISON TERRE")
		for x in [-2.5, 2.5]:
			world.furnishings.seat(pod, Vector3(x, 0, 1.8))
	world.placard(pod, "HYDROPONIE" if side > 0 else "OBSERVATOIRE", Vector3(0, 2.9, -7.3), Color("cef0df"), PI)

static func arc_point(angle: float, radius: float, height: float) -> Vector3:
	return Vector3(sin(angle) * radius, height, -cos(angle) * radius)

static func dome_point(angle: float, elevation: float) -> Vector3:
	return arc_point(angle, POD_RADIUS * cos(elevation), SPRING + sin(elevation) * DOME_HEIGHT)

static func vault(parent: Node3D, center: Vector3, half_width: float, length: float, height: float, material: Material, caps := true) -> void:
	var shell := Node3D.new()
	shell.name="CoquePressurisee"
	shell.add_to_group("pressure_hulls")
	parent.add_child(shell)
	shell.position = center
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for step in range(16):
		var a := Vector3(cos(PI * step / 16.0) * half_width, sin(PI * step / 16.0) * height, -length * 0.5)
		var b := Vector3(cos(PI * (step + 1) / 16.0) * half_width, sin(PI * (step + 1) / 16.0) * height, -length * 0.5)
		var rear := Vector3.BACK * length
		quad(surface, a, b, b + rear, a + rear)
		if caps:
			for offset in [Vector3.ZERO, rear]:
				quad(surface, a + offset, b + offset, Vector3(b.x, 0, b.z) + offset, Vector3(a.x, 0, a.z) + offset)
		for z in [-length * 0.5, -length * 0.25, 0.0, length * 0.25, length * 0.5]:
			KIT.rod(shell, Vector3(a.x, a.y, z), Vector3(b.x, b.y, z), 0.055, STEEL, 6)
	finish_shell(shell, surface, material)

static func quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for i in [0, 1, 2, 0, 2, 3]:
		surface.set_uv([Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN][i])
		surface.add_vertex([a, b, c, d][i])

static func finish_shell(parent: Node3D, surface: SurfaceTool, material: Material) -> MeshInstance3D:
	surface.generate_normals()
	var panel := MeshInstance3D.new()
	panel.mesh = surface.commit()
	var double_sided := material.duplicate() as Material
	if double_sided is BaseMaterial3D:
		double_sided.cull_mode = BaseMaterial3D.CULL_DISABLED
	elif double_sided is ShaderMaterial and double_sided.shader==FINISH.SURFACE:
		double_sided.shader=FINISH.SHELL
	panel.material_override = double_sided
	panel.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	parent.add_child(panel)
	panel.create_trimesh_collision()
	if (material is BaseMaterial3D and material.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED) or (material is ShaderMaterial and material.shader==preload("res://missions/lunar_escape/pressure_glass.gdshader")):
		panel.get_child(0).set_meta("impact_surface","glass")
	var collider := panel.get_child(0).get_child(0) as CollisionShape3D
	(collider.shape as ConcavePolygonShape3D).backface_collision = true
	return panel

static func build_solar(base: Node3D, world: Node3D) -> void:
	var cell := ShaderMaterial.new()
	cell.shader=preload("res://missions/lunar_escape/solar_cells.gdshader")
	cell.set_shader_parameter("dust_map",KIT.FINISH.RESEARCH.REGOLITH_FINE)
	for side in [-1.0, 1.0]:
		for row in range(3):
			var rack := Node3D.new()
			base.add_child(rack)
			rack.position = Vector3(side * 53, 2.6, -12 + row * 12)
			var ground: float = world.surface_profile.elevation(base.global_position.x+rack.position.x,base.global_position.z+rack.position.z)-0.3
			var top: float = maxf(2.6,ground+2.6)
			for dx in [-5.0,5.0]:
				for dz in [-4.0,4.0]:
					top = maxf(top,world.surface_profile.elevation(base.global_position.x+rack.position.x+dx,base.global_position.z+rack.position.z+dz)+2.0)
			rack.position.y = top
			KIT.bevel(base,Vector3(rack.position.x,(top+ground)*0.5,rack.position.z),Vector3(0.4,top-ground,0.4),0.04,STEEL,true)
			rack.rotation.z = side * 0.28
			KIT.bevel(rack, Vector3.ZERO, Vector3(10, 0.16, 8), 0.04, world.FRAME, true)
			for x in range(10):
				for z in range(8):
					KIT.bevel(rack, Vector3(-4.5 + x, 0.1, -3.5 + z), Vector3(0.94, 0.035, 0.94), 0.01, cell)
