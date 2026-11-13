extends RefCounted

const BASE_Z: Array[float] = [0.0, -1200.0, -2400.0]
const ROAD_HALF_WIDTH := 6.0
const PATROLS_PER_LEG := 8
const AIR_STOPS := [0.20, 0.50, 0.80]


static func start(leg: int) -> float:
	return BASE_Z[leg] - 24.0


static func finish(leg: int) -> float:
	return BASE_Z[leg + 1] + 21.0


static func x_at(leg: int, z: float) -> float:
	var t := clampf(inverse_lerp(start(leg), finish(leg), z), 0.0, 1.0)
	var amplitude := 135.0 if leg == 0 else -150.0
	return amplitude * sin(t * TAU * 2.0) * sin(t * PI)


static func air_stop(leg: int, index: int) -> Vector3:
	return point(leg,lerpf(start(leg),finish(leg),AIR_STOPS[index]))+Vector3(7.2,0,0)


static func point(leg: int, z: float) -> Vector3:
	return Vector3(x_at(leg, z), 0.0, z)


static func distance_from_road(leg: int, x: float, z: float) -> float:
	var z_on_road := clampf(z, finish(leg), start(leg))
	var grade := (x_at(leg, z + 0.75) - x_at(leg, z - 0.75)) / 1.5
	return Vector2((x - x_at(leg, z_on_road)) / sqrt(1.0 + grade * grade), z - z_on_road).length()


static func length(leg: int) -> float:
	var total := 0.0
	var previous := point(leg, start(leg))
	for i in range(1, 161):
		var next := point(leg, lerpf(start(leg), finish(leg), i / 160.0))
		total += previous.distance_to(next)
		previous = next
	return total


static func shortcut_start() -> Vector3:
	return point(0, lerpf(start(0), finish(0), 0.17))


static func shortcut_end() -> Vector3:
	return point(0, lerpf(start(0), finish(0), 0.43))


static func shortcut_distance(plan: Vector2) -> float:
	var a := shortcut_start()
	var b := shortcut_end()
	return plan.distance_to(Geometry2D.get_closest_point_to_segment(plan, Vector2(a.x, a.z), Vector2(b.x, b.z)))


static func service_turnoff() -> Vector3:
	return point(1, lerpf(start(1), finish(1), 0.48))


static func service_point() -> Vector3:
	var turnoff := service_turnoff()
	var tangent := point(1, turnoff.z + 0.5).direction_to(point(1, turnoff.z - 0.5))
	return turnoff - tangent.cross(Vector3.UP) * 14.0


static func service_distance(plan: Vector2) -> float:
	var a := service_turnoff()
	var b := service_point()
	return plan.distance_to(Geometry2D.get_closest_point_to_segment(plan, Vector2(a.x, a.z), Vector2(b.x, b.z)))

static func wreck_turnoff() -> Vector3:
	return point(0,lerpf(start(0),finish(0),0.61))

static func wreck_point() -> Vector3:
	var turnoff := wreck_turnoff()
	var tangent := point(0,turnoff.z+0.5).direction_to(point(0,turnoff.z-0.5))
	return turnoff+tangent.cross(Vector3.UP)*19.0

static func wreck_distance(plan: Vector2) -> float:
	var a := wreck_turnoff()
	var b := wreck_point()
	return plan.distance_to(Geometry2D.get_closest_point_to_segment(plan,Vector2(a.x,a.z),Vector2(b.x,b.z)))
