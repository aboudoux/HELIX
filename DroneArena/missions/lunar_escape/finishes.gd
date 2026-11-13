extends RefCounted

const SURFACE := preload("res://missions/lunar_escape/surface.gdshader")
const SHELL := preload("res://missions/lunar_escape/surface_shell.gdshader")
const PHOTO := preload("res://missions/lunar_escape/photo_materials.gd")
const RESEARCH := preload("res://missions/lunar_escape/researched_materials.gd")
const USER_WALL := preload("res://missions/lunar_escape/textures/user_reference/wall_user_photo.png")
static var finishes: Dictionary = {}
static var architectural_finishes: Dictionary = {}

enum Detail { WALL = 1, DOOR, TREAD, POWDER_COAT, USER_WALL_PHOTO, PAINTED_PANEL, LAMINATE, UPHOLSTERY, COVERLET }


static func architecture(source: Material, detail: Detail) -> Material:
	var original := material(source)
	if not original is ShaderMaterial or original.shader != SURFACE:
		return original
	var variants: Dictionary = architectural_finishes.get_or_add(source, {})
	if not variants.has(detail):
		var textured := original.duplicate() as ShaderMaterial
		textured.set_shader_parameter("architecture_detail", int(detail))
		if detail == Detail.USER_WALL_PHOTO:
			textured.set_shader_parameter("scan_albedo", USER_WALL)
			textured.set_shader_parameter("scan_height", RESEARCH.WALL_HEIGHT)
			textured.set_shader_parameter("scan_rough", RESEARCH.WALL_ROUGH)
			textured.set_shader_parameter("photo_scale", 0.72)
		elif detail == Detail.TREAD:
			RESEARCH.bind(textured, RESEARCH.Kind.TREAD)
		elif detail in [Detail.UPHOLSTERY, Detail.COVERLET]:
			textured.set_shader_parameter("scan_albedo", PHOTO.UPHOLSTERY)
			textured.set_shader_parameter("scan_height", PHOTO.UPHOLSTERY_HEIGHT)
			textured.set_shader_parameter("scan_rough", PHOTO.UPHOLSTERY_ROUGH)
			textured.set_shader_parameter("photo_scale", 1.65 if detail == Detail.COVERLET else 2.4)
		elif detail == Detail.PAINTED_PANEL:
			RESEARCH.bind(textured, RESEARCH.Kind.PAINT)
			textured.set_shader_parameter("photo_scale", 1.4)
		elif detail == Detail.LAMINATE:
			RESEARCH.bind(textured, RESEARCH.Kind.POLYMER)
			textured.set_shader_parameter("photo_scale", 3.1)
		variants[detail] = textured
	return variants[detail]


static func material(source: Material) -> Material:
	if not source is StandardMaterial3D:
		return source
	var standard := source as StandardMaterial3D
	if standard.resource_name=="EVAVisor": return source
	if standard.emission_enabled or standard.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or standard.albedo_texture != null:
		return source
	if not finishes.has(source):
		var coating := standard.albedo_color.get_luminance()>0.55 or standard.resource_name in ["EnemyArmor","Ivory","Wall","Orange","TileA","TileB"]
		finishes[source] = create(standard.albedo_color,minf(0.16,standard.metallic) if coating else standard.metallic,maxf(0.52,standard.roughness) if coating else standard.roughness,0.18)
		RESEARCH.bind(finishes[source],RESEARCH.kind_for(standard))
		# Thin pressure hulls must remain visible from outside AND inside.
		if standard.cull_mode==BaseMaterial3D.CULL_DISABLED: finishes[source].shader=SHELL
		if standard.resource_name in ["WeaponSilver","WeaponBody"]: finishes[source].set_shader_parameter("photo_scale",2.4)
		if standard.resource_name=="EnemyArmor": finishes[source].set_shader_parameter("photo_scale",0.8)
	return finishes[source]

static func apply_tree(root: Node) -> void:
	for mesh in root.find_children("*","MeshInstance3D",true,false):
		if mesh.material_override!=null: mesh.material_override=material(mesh.material_override)
		elif mesh.mesh!=null:
			for surface in range(mesh.mesh.get_surface_count()):
				var source: Material=mesh.get_active_material(surface)
				if source!=null: mesh.set_surface_override_material(surface,material(source))


static func create(tint: Color, metalness: float, roughness: float, grain: float, lunar := false, kind: int = -1) -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = SURFACE
	RESEARCH.bind(result,kind if kind>=0 else (RESEARCH.Kind.SOIL if lunar else (RESEARCH.Kind.METAL if metalness>.5 else RESEARCH.Kind.PAINT)))
	if lunar and kind!=RESEARCH.Kind.ROCK:
		RESEARCH.bind_regolith(result)
	result.set_shader_parameter("base_color", tint)
	result.set_shader_parameter("metalness", metalness)
	result.set_shader_parameter("surface_roughness", roughness)
	result.set_shader_parameter("grain_strength", grain)
	result.set_shader_parameter("regolith", 1.0 if lunar else 0.0)
	return result
