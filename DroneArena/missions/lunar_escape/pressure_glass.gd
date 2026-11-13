extends RefCounted
const SHADER := preload("res://missions/lunar_escape/pressure_glass.gdshader")
const PHOTO := preload("res://missions/lunar_escape/photo_materials.gd")
static func material() -> ShaderMaterial:
	var glass:=ShaderMaterial.new()
	glass.shader=SHADER
	glass.set_shader_parameter("imperfections",PHOTO.PAINT_ROUGH)
	return glass
