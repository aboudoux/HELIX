extends Node
## Préférence commune aux deux scènes ; chaque partie garde son propre niveau actif.

const PROFILES := [
	{"name": "Facile", "health": 2, "damage": 5, "move_speed": 2.2, "fire_scale": 1.45, "charge": 0.9, "bolt_speed": 12.0, "delay_scale": 1.25,
	 "summary": "2 impacts par drone · 5 dégâts par projectile", "hint": "Drones plus lents, tirs espacés et avertissement plus long."},
	{"name": "Moyen", "health": 3, "damage": 10, "move_speed": 3.3, "fire_scale": 0.9, "charge": 0.6, "bolt_speed": 16.0, "delay_scale": 0.9,
	 "summary": "3 impacts par drone · 10 dégâts par projectile", "hint": "Ennemis mobiles, contournements et pression modérée."},
	{"name": "Difficile", "health": 4, "damage": 15, "move_speed": 4.2, "fire_scale": 0.65, "charge": 0.4, "bolt_speed": 20.0, "delay_scale": 0.7,
	 "summary": "4 impacts par drone · 15 dégâts par projectile", "hint": "Drones plus rapides, tirs rapprochés et avertissement court."},
]
var selected: int = 1
var settings_path: String = "user://preferences.cfg"


func _ready() -> void:
	load_preference()


func load_preference() -> void:
	selected = 1
	var config := ConfigFile.new()
	if config.load(settings_path) != OK:
		return
	var value: Variant = config.get_value("game", "difficulty", 1)
	if value is int and value >= 0 and value < PROFILES.size():
		selected = value


func select(index: int) -> void:
	if index < 0 or index >= PROFILES.size():
		return
	selected = index
	var config := ConfigFile.new()
	config.load(settings_path)
	config.set_value("game", "difficulty", selected)
	var result := config.save(settings_path)
	if result != OK:
		push_warning("Le choix de difficulté ne peut pas être enregistré : " + error_string(result))
