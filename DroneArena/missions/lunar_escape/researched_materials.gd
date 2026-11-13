extends RefCounted
## CC0 material library. Full provenance lives in textures/researched/README.md.
enum Kind { PAINT, METAL, POLYMER, RUBBER, TREAD, TEXTILE, SOIL, ROCK, LEAF }
const PHOTO := preload("res://missions/lunar_escape/photo_materials.gd")
const METAL_COLOR := preload("res://missions/lunar_escape/textures/scanned/metal_plate_02_diff.jpg")
const METAL_ROUGH := preload("res://missions/lunar_escape/textures/scanned/metal_plate_02_rough.jpg")
const METAL_HEIGHT := preload("res://missions/lunar_escape/textures/scanned/metal_plate_02_disp.jpg")
const RUBBER_COLOR := preload("res://missions/lunar_escape/textures/researched/rubber_tiles_diffuse.jpg")
const RUBBER_ROUGH := preload("res://missions/lunar_escape/textures/researched/rubber_tiles_rough.jpg")
const RUBBER_HEIGHT := preload("res://missions/lunar_escape/textures/researched/rubber_tiles_displacement.jpg")
const TREAD_COLOR := preload("res://missions/lunar_escape/textures/scanned/anti_skid_tiles_diff.jpg")
const TREAD_ROUGH := preload("res://missions/lunar_escape/textures/scanned/anti_skid_tiles_rough.jpg")
const TREAD_HEIGHT := preload("res://missions/lunar_escape/textures/scanned/anti_skid_tiles_disp.jpg")
const REGOLITH_COLOR := preload("res://missions/lunar_escape/textures/scanned/moon_dusted_01_diff.jpg")
const REGOLITH_ROUGH := preload("res://missions/lunar_escape/textures/scanned/moon_dusted_01_rough.jpg")
const REGOLITH_HEIGHT := preload("res://missions/lunar_escape/textures/scanned/moon_dusted_01_disp.jpg")
const REGOLITH_FINE := preload("res://missions/lunar_escape/textures/scanned/moon_flat_macro_01_diff.jpg")
const REGOLITH_FINE_HEIGHT := preload("res://missions/lunar_escape/textures/scanned/moon_flat_macro_01_disp.jpg")
const REGOLITH_COARSE := preload("res://missions/lunar_escape/textures/scanned/moon_02_diff.jpg")
const REGOLITH_COARSE_HEIGHT := preload("res://missions/lunar_escape/textures/scanned/moon_02_disp.jpg")
const ROCK_COLOR := preload("res://missions/lunar_escape/textures/scanned/dark_rock_02_diff.jpg")
const ROCK_HEIGHT := preload("res://missions/lunar_escape/textures/scanned/dark_rock_02_disp.jpg")
const ROCK_ROUGH := preload("res://missions/lunar_escape/textures/scanned/dark_rock_02_rough.jpg")
const WALL_HEIGHT := preload("res://missions/lunar_escape/textures/scanned/painted_plaster_wall_disp.jpg")
const WALL_ROUGH := preload("res://missions/lunar_escape/textures/scanned/painted_plaster_wall_rough.jpg")
const SOIL_COLOR := preload("res://missions/lunar_escape/textures/researched/dense_sand_diffuse.jpg")
const SOIL_ROUGH := preload("res://missions/lunar_escape/textures/researched/dense_sand_rough.jpg")
const SOIL_HEIGHT := preload("res://missions/lunar_escape/textures/researched/dense_sand_displacement.jpg")
const DAMAGE_COLOR := preload("res://missions/lunar_escape/textures/researched/rusty_metal_04_diffuse.jpg")
const DAMAGE_HEIGHT := preload("res://missions/lunar_escape/textures/researched/rusty_metal_04_displacement.jpg")

static func bind(mat: ShaderMaterial, kind: Kind = Kind.PAINT) -> void:
	var maps: Array=[PHOTO.PAINT,PHOTO.PAINT_ROUGH,PHOTO.PAINT_HEIGHT]
	var scale:=1.0
	match kind:
		Kind.METAL:
			maps=[METAL_COLOR,METAL_ROUGH,METAL_HEIGHT];scale=.85
		Kind.POLYMER:
			maps=[PHOTO.LEATHER,PHOTO.LEATHER_ROUGH,PHOTO.LEATHER_HEIGHT];scale=5.0
		Kind.RUBBER:
			maps=[RUBBER_COLOR,RUBBER_ROUGH,RUBBER_HEIGHT];scale=1.6
		Kind.TREAD:
			maps=[TREAD_COLOR,TREAD_ROUGH,TREAD_HEIGHT];scale=.95
		Kind.TEXTILE:
			maps=[PHOTO.CLOTH,PHOTO.CLOTH_ROUGH,PHOTO.CLOTH_HEIGHT];scale=4.0
		Kind.SOIL:
			maps=[SOIL_COLOR,SOIL_ROUGH,SOIL_HEIGHT];scale=.55
		Kind.ROCK:
			maps=[ROCK_COLOR,ROCK_ROUGH,ROCK_HEIGHT];scale=1.25
	mat.set_shader_parameter("material_kind",int(kind))
	mat.set_shader_parameter("scan_albedo",maps[0])
	mat.set_shader_parameter("scan_rough",maps[1])
	mat.set_shader_parameter("scan_height",maps[2])
	mat.set_shader_parameter("photo_scale",scale)

static func bind_regolith(mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("scan_albedo",REGOLITH_COLOR)
	mat.set_shader_parameter("scan_rough",REGOLITH_ROUGH)
	mat.set_shader_parameter("scan_height",REGOLITH_HEIGHT)
	mat.set_shader_parameter("fine_albedo",REGOLITH_FINE)
	mat.set_shader_parameter("fine_height",REGOLITH_FINE_HEIGHT)
	mat.set_shader_parameter("coarse_albedo",REGOLITH_COARSE)
	mat.set_shader_parameter("coarse_height",REGOLITH_COARSE_HEIGHT)

static func kind_for(source: StandardMaterial3D) -> Kind:
	var title:=source.resource_name
	if title=="Floor": return Kind.TREAD
	if title=="WeaponGrip": return Kind.RUBBER
	if title in ["WeaponDark","Inset"]: return Kind.POLYMER
	if title in ["WeaponSilver"] or source.metallic>.6: return Kind.METAL
	return Kind.PAINT
