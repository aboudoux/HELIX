extends "res://scripts/drone_debris.gd"
## Destruction : éléments de coque, pales, connectique et cellules d'énergie.

func explode(origin: Vector3, inherited_velocity: Vector3) -> void:
	setup(origin,Vector3.UP,Vector3.DOWN,true,inherited_velocity)
