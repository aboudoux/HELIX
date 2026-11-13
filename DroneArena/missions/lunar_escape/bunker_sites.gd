extends RefCounted
## Small excavated pockets, separate from the mandatory bases and roads.
const ROUTES := preload("res://missions/lunar_escape/lunar_routes.gd")
const POINTS := [Vector3(42,-2.2,-390),Vector3(-36,-2.2,-1584),Vector3(-102,-2.2,-2190)]
const TITLES := ["CRYPTE HÉLIOS","ABRI NÉRÉIDE","SOUTE OBSIDIENNE"]
const WEAPONS := ["pistol","shotgun","smg"]

static func reserved(x: float,z: float) -> bool:
	for i in range(POINTS.size()):
		var center: Vector3=POINTS[i]
		if absf(z-center.z)>46: continue
		if absf(x-center.x)<15 and z>center.z-16 and z<center.z+34: return true
		var road:=ROUTES.point(0 if i==0 else 1,center.z+30)
		if Vector2(x,z).distance_to(Geometry2D.get_closest_point_to_segment(Vector2(x,z),Vector2(road.x,road.z),Vector2(center.x,center.z+27)))<7: return true
	return false

static func grade(x: float,z: float,original: float) -> float:
	var plan := Vector2(x,z)
	for i in range(POINTS.size()):
		var center: Vector3=POINTS[i]
		if absf(z-center.z)>48: continue
		var road := ROUTES.point(0 if i==0 else 1,center.z+30)
		var entrance := Vector2(center.x,center.z+27)
		var distance := plan.distance_to(Geometry2D.get_closest_point_to_segment(plan,Vector2(road.x,road.z),entrance))
		original=lerpf(0,original,smoothstep(4,14,distance))
		var p := plan-Vector2(center.x,center.z)
		# Recess the terrain under the slab; slope gently back to surface at the entrance.
		var bounds := p.abs()-Vector2(9,15)
		var pocket := 1-smoothstep(0,8,maxf(bounds.x,bounds.y))
		var ramp := 1-smoothstep(3,8,absf(p.x))
		if p.y>=5 and p.y<=28:
			original=lerpf(original,lerpf(-2.5,-.15,clampf((p.y-13)/13,0,1)),ramp)
		original=lerpf(original,-2.5,pocket*(1-smoothstep(12,15,p.y)))
	return original
