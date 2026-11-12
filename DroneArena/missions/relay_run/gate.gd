extends Node3D
signal opened

var unlocked: bool = false
var fully_open: bool = false
var progress: float = 0.0


func unlock() -> void:
	if unlocked:
		return
	unlocked = true
	$OpenSound.play()
	$Label.text = "OUVERTURE..."
	$Label.modulate = Color(0.3, 0.95, 0.85)


func _physics_process(delta: float) -> void:
	if not unlocked or fully_open:
		return
	progress = minf(progress + delta / 1.2, 1.0)
	var smooth := smoothstep(0.0, 1.0, progress)
	$Left.position.x = -1.5 - smooth * 3.15
	$Right.position.x = 1.5 + smooth * 3.15
	if progress >= 1.0:
		fully_open = true
		$Barrier/CollisionShape3D.set_deferred("disabled", true)
		$Label.text = "PASSAGE OUVERT"
		opened.emit()


func reset_gate() -> void:
	$OpenSound.stop()
	unlocked = false
	fully_open = false
	progress = 0.0
	$Left.position.x = -1.5
	$Right.position.x = 1.5
	$Barrier/CollisionShape3D.set_deferred("disabled", false)
	$Label.text = "ACCES VERROUILLE"
	$Label.modulate = Color(1.0, 0.56, 0.22)
