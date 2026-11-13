extends Node3D

signal opened

const KIT := preload("res://missions/lunar_escape/mesh_kit.gd")
const FINISH := preload("res://missions/lunar_escape/finishes.gd")
const FRAME := preload("res://materials/Frame.tres")
const ARMOR := preload("res://missions/lunar_escape/MartianGreen.tres")
const STEEL := preload("res://materials/WeaponSilver.tres")
const LOCKED := preload("res://materials/EnemyGlow.tres")
const READY := preload("res://materials/Cyan.tres")
const MOTOR := preload("res://audio/door_open.wav")

var width: float
var title: String
var secured := false
var opening := false
var is_open := false
var leaves: Array[MeshInstance3D] = []
var indicators: Array[MeshInstance3D] = []
var motor: AudioStreamPlayer3D
var airlock: Node3D
var power_available := true


func build(span: float, caption: String, locked: bool) -> void:
	width = span
	title = caption
	secured = locked
	var brushed := FINISH.architecture(STEEL, FINISH.Detail.DOOR)
	var plating := FINISH.architecture(ARMOR, FINISH.Detail.DOOR)
	var insert := FINISH.architecture(FRAME, FINISH.Detail.WALL)
	for side in [-1.0, 1.0]:
		var leaf := KIT.bevel(self, Vector3(side * width * 0.25, 1.58, 0),
			Vector3(width * 0.5 + 0.014, 3.17, 0.34), 0.074, plating, true)
		leaves.append(leaf)
		for face in [-1.0, 1.0]:
			KIT.bevel(leaf, Vector3(0, 0.48, face * 0.176), Vector3(width * 0.43, 0.57, 0.08), 0.027, insert)
			KIT.bevel(leaf, Vector3(0, 0.36, face * 0.227), Vector3(width * 0.30, 0.051, 0.025), 0.010, brushed)
			KIT.bevel(leaf, Vector3(-side * width * 0.14, -0.13, face * 0.187),
				Vector3(0.058, 0.48, 0.064), 0.016, brushed)
			KIT.bevel(leaf, Vector3(0, -0.88, face * 0.176), Vector3(width * 0.44, 0.65, 0.064), 0.021, insert)
			for rib in range(5):
				KIT.bevel(leaf, Vector3((rib - 2) * width * 0.067, -0.87, face * 0.213),
					Vector3(0.036, 0.41, 0.026), 0.009, brushed)
		for z in [-0.26, 0.26]:
			KIT.bevel(self, Vector3(side * (width * 0.5 + 0.11), 1.59, z),
				Vector3(0.19, 3.15, 0.12), 0.045, FRAME)
			indicators.append(KIT.bevel(self, Vector3(side * (width * 0.5 + 0.14), 1.72, z * 1.25),
				Vector3(0.059, 0.48, 0.052), 0.017, LOCKED if secured else READY))
	motor = AudioStreamPlayer3D.new()
	motor.position.y = 1.6
	motor.stream = MOTOR
	motor.max_distance = 17.0
	motor.volume_db = -11
	add_child(motor)


func unlock() -> void:
	secured = false
	update_indicators()


func lock() -> void:
	secured = true
	update_indicators()

func set_power_available(available: bool) -> void:
	power_available=available
	update_indicators()

func update_indicators() -> void:
	for indicator in indicators:
		indicator.material_override = (LOCKED if secured else READY) if power_available else preload("res://missions/lunar_escape/PowerOff.tres")


func open() -> bool:
	if airlock != null and not airlock.can_open(self): return false
	if secured or opening or is_open:
		return false
	opening = true
	motor.play()
	var slide := create_tween().set_parallel(true).set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	slide.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	for i in range(leaves.size()):
		var side := -1.0 if i == 0 else 1.0
		slide.tween_property(leaves[i], "position:x", side * (width * 0.75 + 0.085), 0.72)
	await slide.finished
	for leaf in leaves:
		leaf.get_child(0).set_deferred("collision_layer", 0)
	opening = false
	is_open = true
	opened.emit()
	return true


func close() -> bool:
	if opening or not is_open or passage_occupied():
		return false
	opening = true
	motor.play()
	var slide := create_tween().set_parallel(true).set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	for i in range(leaves.size()):
		slide.tween_property(leaves[i], "position:x", (-1.0 if i == 0 else 1.0) * width * 0.25, 0.55)
	await slide.finished
	opening = false
	is_open = false
	if passage_occupied():
		await open()
		return false
	for leaf in leaves:
		leaf.get_child(0).set_deferred("collision_layer", 1)
	return true


func passage_occupied() -> bool:
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, 3.0, 0.8)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = global_transform.translated_local(Vector3.UP * 1.5)
	query.collision_mask = 26
	return not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()
