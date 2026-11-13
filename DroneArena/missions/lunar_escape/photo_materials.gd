extends RefCounted
## Original CC0 photographs, colour/roughness/height at 2048 px.
const PAINT := preload("res://missions/lunar_escape/textures/photographic/blue_metal_plate_diffuse.jpg")
const PAINT_ROUGH := preload("res://missions/lunar_escape/textures/photographic/blue_metal_plate_rough.jpg")
const PAINT_HEIGHT := preload("res://missions/lunar_escape/textures/photographic/blue_metal_plate_displacement.jpg")
const CLOTH := preload("res://missions/lunar_escape/textures/scanned/terlenka_diff.jpg")
const CLOTH_ROUGH := preload("res://missions/lunar_escape/textures/scanned/terlenka_rough.jpg")
const CLOTH_HEIGHT := preload("res://missions/lunar_escape/textures/scanned/terlenka_disp.jpg")
const EVA_PHOTO := preload("res://missions/lunar_escape/textures/user_reference/eva_user_photo.png")
const EVA_FOREARM := [Vector2(222,509),Vector2(63,25),Vector2(-53,123)]
const EVA_GLOVE := [Vector2(141,682),Vector2(57,0),Vector2(0,80)]
const LEATHER := preload("res://missions/lunar_escape/textures/photographic/leather_white_diffuse.jpg")
const LEATHER_ROUGH := preload("res://missions/lunar_escape/textures/photographic/leather_white_rough.jpg")
const LEATHER_HEIGHT := preload("res://missions/lunar_escape/textures/photographic/leather_white_displacement.jpg")
const UPHOLSTERY := preload("res://missions/lunar_escape/textures/photographic/denim_fabric_05_diffuse.jpg")
const UPHOLSTERY_ROUGH := preload("res://missions/lunar_escape/textures/photographic/denim_fabric_05_rough.jpg")
const UPHOLSTERY_HEIGHT := preload("res://missions/lunar_escape/textures/photographic/denim_fabric_05_displacement.jpg")

static func bind_paint(mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("scan_albedo",PAINT)
	mat.set_shader_parameter("scan_rough",PAINT_ROUGH)
	mat.set_shader_parameter("scan_height",PAINT_HEIGHT)

static func bind_fabric(mat: ShaderMaterial, leather := false) -> void:
	mat.set_shader_parameter("fabric_albedo",LEATHER if leather else CLOTH)
	mat.set_shader_parameter("fabric_rough",LEATHER_ROUGH if leather else CLOTH_ROUGH)
	mat.set_shader_parameter("fabric_height",LEATHER_HEIGHT if leather else CLOTH_HEIGHT)
