extends RefCounted
## Codes belong to a campaign, never to a checkpoint or a dialog opening.
static var previous_tycho := ""
var tycho := ""
var copernic := ""
var copernic_unlocked := false

func _init() -> void:
	while tycho.is_empty() or tycho==previous_tycho:
		tycho = str(randi_range(1000,9999))
	previous_tycho = tycho
	copernic = str(randi_range(1000,9999))

func tycho_hint() -> String:
	var a := int(tycho[0]); var b := int(tycho[1]); var c := int(tycho[2]); var d := int(tycho[3])
	return "CALCUL DE CONTRÔLE · QUATRE CHIFFRES\nPremier : %d − 2\nDeuxième : %d − 3\nTroisième : %d ÷ 2\nDernier : %d − 4" % [a+2,b+3,c*2,d+4]

func snapshot() -> Dictionary:
	return {"tycho":tycho,"copernic":copernic,"unlocked":copernic_unlocked}

static func valid(data: Variant) -> bool:
	if not data is Dictionary or not data.get("unlocked") is bool: return false
	for key in ["tycho","copernic"]:
		var value: Variant = data.get(key)
		if not value is String or value.length()!=4 or not value.is_valid_int() or int(value)<1000 or int(value)>9999: return false
	return true

func restore(data: Dictionary, stage: int) -> void:
	if valid(data):
		tycho = data.tycho; copernic = data.copernic
		copernic_unlocked = data.unlocked
	# A save already inside Copernic must not be locked out of its reached chapter.
	if stage>=7: copernic_unlocked = true
