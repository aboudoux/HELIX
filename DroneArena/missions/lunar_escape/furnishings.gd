extends RefCounted

const KIT := preload("res://missions/lunar_escape/mesh_kit.gd")
const FINISH := preload("res://missions/lunar_escape/finishes.gd")
const STEEL := preload("res://materials/WeaponSilver.tres")
const CERAMIC := preload("res://materials/Ivory.tres")
const FRAME := preload("res://materials/Frame.tres")
const INSET := preload("res://materials/Inset.tres")
const CYAN := preload("res://materials/Cyan.tres")
const AMBER := preload("res://materials/Amber.tres")
const STORAGE := preload("res://assets/models/helix_storage.glb")
const RELAY := preload("res://assets/models/helix_mission_relay.glb")
const FONT := preload("res://assets/fonts/DejaVuSans.ttf")

var cloth := FINISH.architecture(FINISH.create(Color("536d7e"), 0, 0.9, 0.8, false, FINISH.RESEARCH.Kind.TEXTILE), FINISH.Detail.UPHOLSTERY)
var bedding := FINISH.architecture(FINISH.create(Color("ded9cc"), 0, 0.9, 0.5, false, FINISH.RESEARCH.Kind.TEXTILE), FINISH.Detail.UPHOLSTERY)
var coverlet := FINISH.architecture(cloth, FINISH.Detail.COVERLET)
var furniture_frame := FINISH.architecture(FRAME, FINISH.Detail.PAINTED_PANEL)
var furniture_panel := FINISH.architecture(CERAMIC, FINISH.Detail.PAINTED_PANEL)
var worktop := FINISH.architecture(INSET, FINISH.Detail.LAMINATE)
var soil := FINISH.create(Color("3d3225"), 0, 0.95, 0.9, false, FINISH.RESEARCH.Kind.SOIL)
var leaf_green := FINISH.create(Color("4b8843"), 0, 0.66, 0.58, false, FINISH.RESEARCH.Kind.LEAF)
var leaf_young := FINISH.create(Color("86a953"), 0, 0.62, 0.68, false, FINISH.RESEARCH.Kind.LEAF)
var ammo_shell := FINISH.architecture(FINISH.create(Color("747958"), 0.28, 0.67, 0.45), FINISH.Detail.POWDER_COAT)
var supply_shell := FINISH.architecture(FINISH.create(Color("4b7687"), 0.30, 0.61, 0.40), FINISH.Detail.POWDER_COAT)
var hardware := FINISH.architecture(STEEL, FINISH.Detail.DOOR)
var brass := FINISH.create(Color("b5854c"), 0.56, 0.42, 0.24)


func ammunition_case(parent: Node3D, mixed: bool) -> void:
	var shell := supply_shell if mixed else ammo_shell
	KIT.bevel(parent, Vector3(0, -0.24, 0), Vector3(0.80, 0.33, 0.51), 0.046, shell)
	KIT.bevel(parent, Vector3(0, -0.085, 0), Vector3(0.817, 0.025, 0.52), 0.011, INSET)
	KIT.bevel(parent, Vector3(0, -0.037, 0), Vector3(0.84, 0.077, 0.54), 0.030, shell)
	for x in [-0.31, 0.31]:
		for z in [-0.199, 0.199]:
			KIT.bevel(parent, Vector3(x, -0.40, z), Vector3(0.153, 0.052, 0.118), 0.019, FRAME)
		KIT.bevel(parent, Vector3(x, -0.13, 0.267), Vector3(0.117, 0.169, 0.046), 0.014, hardware)
		KIT.bevel(parent, Vector3(x, -0.105, 0.296), Vector3(0.073, 0.085, 0.021), 0.008, FRAME)
		KIT.rod(parent, Vector3(x - 0.052, -0.167, 0.306), Vector3(x + 0.052, -0.167, 0.306), 0.009, brass, 8)
		KIT.rod(parent, Vector3(x - 0.054, -0.07, -0.265), Vector3(x + 0.054, -0.07, -0.265), 0.020, hardware, 8)
		KIT.bevel(parent, Vector3(x, 0.004, 0), Vector3(0.043, 0.022, 0.45), 0.009, shell)
	KIT.bevel(parent, Vector3(0, -0.216, 0.262), Vector3(0.401, 0.160, 0.016), 0.007, FRAME)
	case_stamp(parent, Vector3(0, -0.214, 0.272), "MUNITIONS\nDOTATION MIXTE" if mixed else "MUNITIONS\nPISTOLET • 24 CART.", 0.0010)
	KIT.bevel(parent, Vector3(0, 0.007, -0.044), Vector3(0.48, 0.009, 0.226), 0.004, FRAME)
	case_stamp(parent, Vector3(0, 0.014, -0.035), "HELIX / RÉSERVE\nMIXTE" if mixed else "HELIX / RÉSERVE\nPISTOLET", 0.00134).rotation.x = -PI / 2.0
	for x in [-0.105, 0.105]:
		KIT.rod(parent, Vector3(x, 0.011, 0.112), Vector3(x, 0.040, 0.112), 0.018, hardware, 8)
	KIT.rod(parent, Vector3(-0.113, 0.040, 0.112), Vector3(0.113, 0.040, 0.112), 0.017, FRAME)
	KIT.bevel(parent, Vector3(0, -0.33, 0.257), Vector3(0.23, 0.014, 0.012), 0.003, CYAN if mixed else AMBER)


func case_stamp(parent: Node3D, point: Vector3, text: String, pixel: float) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = FONT
	label.font_size = 30
	label.outline_size = 0
	label.pixel_size = pixel
	label.modulate = Color("e6e4cd")
	label.position = point
	parent.add_child(label)
	return label


func bed(room: Node3D, at: Vector3) -> void:
	var frame := KIT.bevel(room, at + Vector3(0, 0.36, 0), Vector3(1.68, 0.58, 2.92), 0.13, furniture_frame, true)
	KIT.bevel(frame, Vector3(0, 0.32, 0), Vector3(1.53, 0.22, 2.72), 0.104, bedding)
	KIT.bevel(frame, Vector3(0, 0.48, 0.88), Vector3(1.14, 0.19, 0.63), 0.089, bedding).rotation.y = -0.06
	KIT.bevel(frame, Vector3(0, 0.45, -0.45), Vector3(1.54, 0.105, 1.72), 0.050, coverlet)
	for x in [-0.77, 0.77]:
		KIT.rod(frame, Vector3(x, -0.06, -1.31), Vector3(x, -0.06, 1.31), 0.052, STEEL)
		KIT.bevel(frame, Vector3(x, -0.24, 1.16), Vector3(0.28, 0.24, 0.46), 0.06, FRAME)
		KIT.bevel(frame, Vector3(x, -0.24, -1.16), Vector3(0.28, 0.24, 0.46), 0.06, FRAME)


func cabinet(parent: Node3D, at: Vector3, width: float, height: float, depth: float, _searchable := false) -> void:
	var body:=preload("res://missions/lunar_escape/loot_cabinet.gd").new()
	parent.add_child(body);body.position=at;body.build(width,height,depth)


func table(room: Node3D, at: Vector3, size: Vector2, height: float) -> void:
	var slab := KIT.bevel(room, at + Vector3.UP * height, Vector3(size.x, 0.11, size.y), 0.048, worktop, true)
	var feet := KIT.bevel(room, at + Vector3(0, 0.12, 0), Vector3(size.x * 0.80, 0.24, size.y * 0.68), 0.067, furniture_frame, true)
	for x in [-size.x * 0.36, size.x * 0.36]:
		KIT.rod(feet, Vector3(x, 0.0, 0), Vector3(x, height - 0.13, 0), 0.073, STEEL)
		KIT.collision_box(feet, Vector3(x, (height - 0.13) * 0.5, 0), Vector3(0.146, height - 0.13, 0.146))
	KIT.bevel(slab, Vector3(0, 0.003, size.y * 0.50), Vector3(size.x * 0.89, 0.043, 0.044), 0.013, hardware)


func seat(room: Node3D, at: Vector3, yaw := 0.0) -> void:
	var root := Node3D.new()
	root.position = at
	root.rotation.y = yaw
	room.add_child(root)
	KIT.rod(root, Vector3(0, 0.11, 0), Vector3(0, 0.53, 0), 0.093, STEEL)
	for direction in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		KIT.rod(root, Vector3.UP * 0.095, direction * 0.36 + Vector3.UP * 0.069, 0.036, FRAME)
	KIT.bevel(root, Vector3(0, 0.54, 0), Vector3(0.55, 0.12, 0.55), 0.054, cloth, true)
	KIT.rod(root, Vector3(0, 0.47, 0.21), Vector3(0, 0.97, 0.29), 0.048, STEEL)
	KIT.bevel(root, Vector3(0, 0.91, 0.27), Vector3(0.48, 0.47, 0.115), 0.052, cloth, true).rotation.x = 0.14


func screen(room: Node3D, at: Vector3, width: float, text: String, support_y := 0.0) -> void:
	# Every display rests on a desk or on its own floor-mounted pedestal.
	var foot := KIT.bevel(room,Vector3(at.x,support_y+.025,at.z+.05),Vector3(width*.48,.05,.34),.018,FRAME)
	foot.set_meta("screen_support",true)
	KIT.rod(room,Vector3(at.x,support_y+.05,at.z+.05),at+Vector3(0,-width*.21,.02),.035,STEEL)
	var display := KIT.bevel(room, at, Vector3(width, width * 0.52, 0.11), 0.048, FRAME)
	display.rotation.x = -0.15
	KIT.bevel(display, Vector3(0, 0, 0.059), Vector3(width * 0.91, width * 0.45, 0.026), 0.011, INSET)
	KIT.bevel(display, Vector3(0, width * 0.19, 0.075), Vector3(width * 0.80, 0.015, 0.008), 0.002, CYAN)
	var label := Label3D.new()
	label.text = text
	label.font = FONT
	label.font_size = 34
	label.pixel_size = width * 0.00205
	label.modulate = Color("a8eee5")
	label.position = Vector3(0, 0.005, 0.083)
	display.add_child(label)


func quarters(room: Node3D, id: int) -> Marker3D:
	bed(room, Vector3(-4.7, 0, -3.0))
	cabinet(room, Vector3(5.8, 0, -4.8), 2.25, 2.26, 0.85, true)
	table(room, Vector3(-0.3, 0, -4.35), Vector2(2.65, 1.06), 0.92)
	seat(room, Vector3(-0.4, 0, -3.13))
	screen(room, Vector3(-0.34, 1.46, -4.67), 1.28, "CABINE %02d\nAIR  •  NOMINAL" % id,.975)
	gear_shelf(room, Vector3(2.75, 0, -4.63), true)
	var rack := KIT.bevel(room, Vector3(0, 1.6, 4.77), Vector3(2.44, 1.07, 0.17), 0.062, FRAME)
	rack.rotation.y = PI
	for x in [-.91,.91]:
		KIT.rod(rack,Vector3(x,-1.56,0),Vector3(x,-.50,0),.04,STEEL)
		KIT.bevel(rack,Vector3(x,-1.575,0),Vector3(.28,.05,.65),.015,FRAME)
	for x in [-0.91, 0.91]:
		KIT.rod(rack, Vector3(x, -0.37, 0.13), Vector3(x, 0.36, 0.13), 0.035, STEEL)
	KIT.bevel(rack, Vector3(0, -0.32, 0.17), Vector3(2.15, 0.088, 0.33), 0.026, CERAMIC)
	KIT.bevel(rack, Vector3(0.72, 0.29, 0.103), Vector3(0.19, 0.041, 0.016), 0.006, AMBER)
	var mount := Marker3D.new()
	mount.position = Vector3(-0.08, -0.11, 0.23)
	rack.add_child(mount)
	return mount


func kitchen(room: Node3D) -> void:
	for x in [-4.8, -2.6, -0.4, 1.8]:
		cabinet(room, Vector3(x, 0, -4.8), 2.11, 0.91, 0.83)
	KIT.bevel(room, Vector3(-1.5, 0.94, -4.78), Vector3(8.91, 0.12, 1.02), 0.051, STEEL, true)
	KIT.bevel(room, Vector3(-3.4, 1.014, -4.7), Vector3(0.65, 0.022, 0.49), 0.010, INSET)
	KIT.rod(room, Vector3(-3.45, 0.98, -5.01), Vector3(-3.45, 1.31, -5.01), 0.036, STEEL)
	KIT.rod(room, Vector3(-3.45, 1.31, -5.01), Vector3(-3.45, 1.31, -4.76), 0.033, STEEL)
	cabinet(room, Vector3(5.45, 0, -4.70), 1.61, 2.31, 1.0)
	var dispenser := KIT.bevel(room, Vector3(5.3, 0.69, 3.42), Vector3(1.78, 1.38, 0.80), 0.093, furniture_frame, true)
	KIT.bevel(dispenser, Vector3(0, 0.24, -0.393), Vector3(1.53, 0.62, 0.07), 0.033, furniture_panel)
	KIT.bevel(dispenser, Vector3(0, 0.31, -0.443), Vector3(0.82, 0.38, 0.05), 0.022, INSET)
	KIT.rod(dispenser, Vector3(0, 0.34, -0.486), Vector3(0, 0.44, -0.486), 0.036, hardware)
	KIT.bevel(dispenser, Vector3(0, 0.06, -0.488), Vector3(0.79, 0.038, 0.16), 0.011, hardware)
	KIT.bevel(dispenser, Vector3(0.57, 0.44, -0.435), Vector3(0.11, 0.039, 0.014), 0.007, CYAN)
	mark_searchable(dispenser, Vector3(0, 0.18, -0.60), "distributeur")
	for x in [-3.35, 3.35]:
		table(room, Vector3(x, 0, 2.11), Vector2(2.5, 1.28), 0.87)
		seat(room, Vector3(x, 0, 3.36))
		seat(room, Vector3(x, 0, 0.88), PI)
		for offset in [-0.63, 0.61]:
			KIT.rod(room, Vector3(x + offset, 0.918, 2.12), Vector3(x + offset, 0.94, 2.12), 0.17, CERAMIC)
		screen(room, Vector3(x, 2.25, -5.05), 1.22, "GALLEY\nSERVICE")


func farm(room: Node3D, freestanding := false) -> void:
	for x in [-4.9, 0.0, 4.9]:
		for z in [-2.6, 2.6]:
			var tray := KIT.bevel(room, Vector3(x, 0.81, z), Vector3(3.12, 0.62, 1.72), 0.14, furniture_panel, true)
			KIT.bevel(tray, Vector3(0, 0.32, 0), Vector3(2.89, 0.09, 1.49), 0.044, soil)
			KIT.bevel(tray, Vector3(0, -0.06, 0.865), Vector3(2.63, 0.049, 0.043), 0.017, CYAN)
			for dx in [-1.37, 1.37]:
				KIT.rod(tray, Vector3(dx, -0.76, 0.57), Vector3(dx, 1.52, 0.57), 0.045, FRAME)
			KIT.bevel(tray, Vector3(0, 1.50, 0.52), Vector3(2.96, 0.12, 0.22), 0.049, CERAMIC)
			KIT.bevel(tray, Vector3(0, 1.43, 0.52), Vector3(2.68, 0.04, 0.14), 0.012, CYAN)
			for row in [-0.35, 0.35]:
				for column in [-0.95, -0.31, 0.31, 0.95]:
					plant(tray, Vector3(column, 0.36, row))
	KIT.rod(room, Vector3(-6.5, 0.61, -4.96), Vector3(6.5, 0.61, -4.96), 0.092, STEEL)
	service_cart(room, Vector3(-7.4, 0, -4.2), 0.0)
	screen(room, Vector3(0, 2.2, -4.9), 1.54, "HYDROPONIE\nCIRCUIT  B")
	if freestanding:
		KIT.bevel(room, Vector3(0, 0.08, -5.05), Vector3(1.05, 0.16, 0.55), 0.04, FRAME, true)
		KIT.rod(room, Vector3(0, 0.16, -5.05), Vector3(0, 2.2, -5.05), 0.068, STEEL)
		KIT.rod(room, Vector3(0, 2.2, -5.05), Vector3(0, 2.2, -4.89), 0.055, STEEL)


func plant(parent: Node3D, at: Vector3) -> void:
	KIT.rod(parent, at, at + Vector3.UP * 0.37, 0.025, leaf_green, 6)
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 7
	mesh.rings = 3
	for i in range(4):
		var yaw := i * TAU * 0.25 + at.x
		var radial := Vector3(cos(yaw), 0.0, sin(yaw))
		var blade := MeshInstance3D.new()
		blade.mesh = mesh
		blade.material_override = leaf_green if i % 2 == 0 else leaf_young
		blade.position = at + radial * 0.109 + Vector3.UP * (0.18 + i * 0.043)
		blade.basis = Basis(Quaternion(Vector3.UP, (radial + Vector3.UP * 0.36).normalized())).scaled_local(Vector3(0.096, 0.29, 0.048))
		parent.add_child(blade)


func control(room: Node3D, base: int) -> void:
	for x in [-4.5, 0.0, 4.5]:
		table(room, Vector3(x, 0, -3.86), Vector2(3.56, 1.59), 1.0)
		seat(room, Vector3(x, 0, -2.16))
		screen(room, Vector3(x, 1.78, -4.17), 2.64, ["KAREN", "TYCHO", "COPERNIC"][base] + "\nRÉSEAU  •  HELIX")
		for i in range(5):
			KIT.bevel(room, Vector3(x - 0.47 + 0.23 * i, 1.086, -3.45), Vector3(0.15, 0.048, 0.13), 0.017, AMBER if i == 0 else INSET)
	var terminal := RELAY.instantiate() as Node3D
	terminal.position = Vector3(4.8, 0.055, 2.85)
	room.add_child(terminal)
	KIT.model_collision(terminal)
	var storage := STORAGE.instantiate() as Node3D
	storage.position = Vector3(-4.8, 0.07, 3.16)
	room.add_child(storage)
	KIT.model_collision(storage)


func gallery_bay(hall: Node3D, point: Vector3, yaw: float, caption: String) -> void:
	var bay := Node3D.new()
	bay.position = point
	bay.rotation.y = yaw
	hall.add_child(bay)
	cabinet(bay, Vector3(-2.65, 0, -0.20), 1.26, 2.12, 0.88)
	KIT.bevel(bay, Vector3(-0.50, 0.40, -0.13), Vector3(2.48, 0.66, 0.80), 0.082, furniture_frame, true)
	KIT.bevel(bay, Vector3(-0.50, 0.77, -0.13), Vector3(2.36, 0.145, 0.79), 0.061, cloth)
	KIT.bevel(bay, Vector3(-0.50, 1.02, -0.50), Vector3(2.33, 0.46, 0.18), 0.055, cloth)
	screen(bay, Vector3(0, 2.04, -0.57), 1.76, caption)
	var case := STORAGE.instantiate() as Node3D
	case.position = Vector3(2.45, 0.05, -0.18)
	case.scale = Vector3.ONE * 0.68
	bay.add_child(case)
	KIT.model_collision(case)


func gear_shelf(room: Node3D, point: Vector3, searchable := false) -> void:
	var shelf := KIT.bevel(room, point + Vector3.UP * 0.72, Vector3(1.37, 1.44, 0.65), 0.061, furniture_frame, true)
	KIT.bevel(shelf, Vector3(0, 0.05, 0.322), Vector3(1.21, 1.18, 0.030), 0.011, INSET)
	for y in [-0.38, 0.035, 0.46]:
		KIT.bevel(shelf, Vector3(0, y, 0.47), Vector3(1.24, 0.065, 0.33), 0.023, furniture_panel, true)
	for x in [-0.38, -0.04, 0.30]:
		KIT.rod(shelf, Vector3(x, -0.34, 0.48), Vector3(x, -0.075, 0.48), 0.097, ammo_shell, 12)
		KIT.rod(shelf, Vector3(x, -0.075, 0.48), Vector3(x, -0.03, 0.48), 0.079, hardware, 12)
	KIT.bevel(shelf, Vector3(0.18, 0.16, 0.49), Vector3(0.54, 0.20, 0.27), 0.045, cloth)
	KIT.rod(shelf, Vector3(-0.39, 0.11, 0.48), Vector3(-0.39, 0.33, 0.48), 0.082, CERAMIC, 12)
	KIT.bevel(shelf, Vector3(0, 0.64, 0.323), Vector3(0.52, 0.023, 0.016), 0.006, CYAN)
	if searchable:
		mark_searchable(shelf, Vector3(0, 0.14, 0.72), "étagère")


func service_cart(room: Node3D, point: Vector3, yaw: float) -> void:
	var cart := Node3D.new()
	cart.position = point
	cart.rotation.y = yaw
	room.add_child(cart)
	KIT.bevel(cart, Vector3(0, 0.59, 0), Vector3(1.33, 0.71, 0.64), 0.071, furniture_frame, true)
	KIT.bevel(cart, Vector3(0, 0.96, 0), Vector3(1.46, 0.085, 0.71), 0.034, hardware, true)
	for y in [0.42, 0.62, 0.82]:
		KIT.bevel(cart, Vector3(0, y, 0.328), Vector3(1.20, 0.152, 0.068), 0.028, furniture_panel)
		KIT.rod(cart, Vector3(-0.23, y, 0.378), Vector3(0.23, y, 0.378), 0.017, INSET)
	for x in [-0.51, 0.51]:
		for z in [-0.24, 0.24]:
			KIT.rod(cart, Vector3(x - 0.050, 0.126, z), Vector3(x + 0.05, 0.126, z), 0.11, INSET)
	for z in [-0.23, 0.23]:
		KIT.rod(cart, Vector3(0.53, 0.81, z), Vector3(0.82, 0.81, z), 0.026, hardware)
	KIT.rod(cart, Vector3(0.82, 0.81, -0.24), Vector3(0.82, 0.81, 0.24), 0.028, hardware)
	KIT.bevel(cart, Vector3(-0.31, 1.08, 0.025), Vector3(0.51, 0.16, 0.32), 0.047, ammo_shell)
	KIT.rod(cart, Vector3(0.14, 1.024, -0.09), Vector3(0.54, 1.024, 0.12), 0.026, hardware)
	mark_searchable(cart, Vector3(0, 0.81, 0.46), "chariot")


func mark_searchable(furniture: Node3D, point: Vector3, description: String) -> void:
	var handle := Marker3D.new()
	handle.position = point
	if point.z < 0.0:
		handle.rotation.y = PI
	handle.set_meta("description", description)
	furniture.add_child(handle)
	handle.add_to_group("ration_furniture")
