extends "res://missions/relay_run/director.gd"
## Grille réservée à l'alpha ; son gabarit de rotation dépasse celui des limiers.

func fire_alpha(origin: Vector3, aim: Vector3, shooter: RID, damage: int, speed: float) -> void:
	var bolt := HOUND_BOLT.instantiate()
	bolt.damage = damage
	bolt.speed = speed
	bolt.pulse_length = 2.4
	get_parent().get_node("Projectiles").add_child(bolt)
	bolt.launch(origin,origin.direction_to(aim),shooter)
