extends RefCounted

const SIZE := 1.5
const RISE := 1.46
const STEPS := 6


static func shape() -> ConvexPolygonShape3D:
	# Continuous walking surface under the steps, within the same footprint.
	var ramp := ConvexPolygonShape3D.new()
	var points := PackedVector3Array()
	var half := SIZE * .5
	for x in [-half, half]:
		points.append(Vector3(x, -half, half))
		points.append(Vector3(x, -half, -half))
		points.append(Vector3(x, RISE - half, -half))
	ramp.points = points
	return ramp


static func mesh() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for step in STEPS:
		var height := RISE * (step + .5) / STEPS
		var tread := BoxMesh.new()
		tread.size = Vector3(SIZE, height, SIZE / STEPS)
		var center := Vector3(0, (height-SIZE)*.5, SIZE*.5 - (step+.5)*SIZE/STEPS)
		tool.append_from(tread, 0, Transform3D(Basis.IDENTITY, center))
	return tool.commit()
