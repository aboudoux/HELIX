extends AudioStreamPlayer3D
## Boucle locale aux turbines : silencieuse pour les ennemis dormants ou détruits.

var actor: CharacterBody3D
var base_volume: float
var base_pitch: float
var start_offset: float


func _ready() -> void:
	actor = get_parent()
	base_volume = volume_db
	base_pitch = pitch_scale
	var loop := stream.duplicate() as AudioStreamWAV
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_begin = 0
	loop.loop_end = roundi(loop.get_length()*loop.mix_rate)
	stream = loop
	start_offset = randf()*loop.get_length()
	volume_db = -60


func silence() -> void:
	stop()
	volume_db = -60
	pitch_scale = base_pitch


func _process(delta: float) -> void:
	if not actor.alive or not actor.is_visible_in_tree():
		if playing: silence()
		return
	if not playing:
		volume_db = -60
		play(start_offset)
	var load_factor := clampf(actor.velocity.length()/6,0,1)
	var charge: float = .035 if actor.charge_remaining>0 else 0.0
	var rage: float = .055 if "phase" in actor and actor.phase==2 else 0.0
	pitch_scale = move_toward(pitch_scale,base_pitch*(1+load_factor*.08+charge+rage),delta*.3)
	volume_db = move_toward(volume_db,base_volume+load_factor*1.5+rage*20,delta*140)
