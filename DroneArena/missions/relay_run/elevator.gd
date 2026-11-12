extends Node3D
## Cabine physique portée par AnimatableBody3D ; aucun changement de position du joueur.
signal arrived
var unlocked: bool = false
var state: String = "locked"
var clock: float = 0.0
@onready var cab: AnimatableBody3D = $Cab


func unlock() -> void:
	unlocked = true
	state = "boarding"
	$DoorSound.play()
	set_door("South",true)
	$Sign.text = "ASCENSEUR DISPONIBLE\nENTREZ, PUIS APPUYEZ SUR E"


func contains_player(player: CharacterBody3D) -> bool:
	var p := cab.to_local(player.global_position)
	return absf(p.x)<2.2 and absf(p.z)<2.8 and p.y>-.1 and p.y<.4 and player.is_on_floor()


func request_ride(player: CharacterBody3D) -> bool:
	if get_tree().paused or not unlocked or state!="boarding" or not contains_player(player):
		return false
	state = "closing"
	clock = 0
	# Barrage immédiat : personne ne sort pendant la fermeture et la montée.
	$Cab/SouthBlock.disabled = false
	$DoorSound.play()
	$Sign.text = "FERMETURE DES PORTES"
	return true


func set_door(side: String, opened: bool) -> void:
	cab.get_node(side+"Block").set_deferred("disabled",opened)
	cab.get_node(side+"Door").position.x = 6.2 if opened else 0.0


func _physics_process(delta: float) -> void:
	clock += delta
	if state=="closing":
		$Cab/SouthDoor.position.x = lerpf(6.2,0,smoothstep(0,1,clock/1.2))
		if clock>=1.2:
			state = "rising"
			clock = 0
			$Motor.play()
			$Sign.text = "MONTEE / ETAGE 02"
	elif state=="rising":
		# Rampe douce sans départ brutal ; la physique transmet la vitesse du plancher.
		cab.position.y = 14.0*smoothstep(0,1,minf(clock/8.0,1))
		if clock>=8.0:
			state = "opening"
			$Cab/CabHelp.hide()
			clock = 0
			$Motor.stop()
			$Bell.play()
			$DoorSound.play()
	elif state=="opening":
		$Cab/NorthDoor.position.x = 6.2*smoothstep(0,1,clock/1.2)
		if clock>=1.2:
			set_door("North",true)
			state = "arrived"
			$Sign.text = "ETAGE 02 / LE CHENIL"
			arrived.emit()


func reset_lift() -> void:
	state = "locked"
	$Cab/CabHelp.show()
	unlocked = false
	clock = 0
	cab.position.y = 0
	set_door("South",false)
	set_door("North",false)
	for sound in [$Motor,$Bell,$DoorSound]: sound.stop()
	$Sign.text = "ASCENSEUR VERROUILLE\nNEUTRALISEZ CERBERE"
	cab.reset_physics_interpolation()
