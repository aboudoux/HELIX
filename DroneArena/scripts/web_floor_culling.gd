extends Node
## Render only the current closed floor. The lift switches floors behind doors.
## Visibility does not remove nodes, physics, scripts, lights' settings or state.

const SWITCH_HEIGHT := 8.0
var active_floor := -1
var game: Node3D
var lower: Node3D
var upper: Node3D
var originally_visible: Array[bool] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	game = get_parent()
	lower = game.get_node("Arena")
	upper = game.get_node("UpperArena")
	originally_visible = [lower.visible, upper.visible]
	update_floor()

func _process(_delta: float) -> void:
	update_floor()

func update_floor() -> void:
	var next_floor := 1 if game.player.global_position.y > SWITCH_HEIGHT else 0
	if next_floor == active_floor: return
	active_floor = next_floor
	lower.visible = originally_visible[0] and active_floor == 0
	upper.visible = originally_visible[1] and active_floor == 1
