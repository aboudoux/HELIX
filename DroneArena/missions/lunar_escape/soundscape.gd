extends Node
## Two local buses keep radio/UI clear while exterior world sounds are muffled.
var campaign: Node3D
var world_filter := AudioEffectLowPassFilter.new()
var suit_filter := AudioEffectLowPassFilter.new()
var outside_mix := 0.0
var helmet_mix := 0.0
var breath: AudioStreamPlayer
var alarm: AudioStreamPlayer
var alarm_clock := 0.0
var voice_duck := 0.0

func setup(game: Node3D) -> void:
	campaign = game
	for title in ["LunarWorld","LunarSuit"]:
		if AudioServer.get_bus_index(title)<0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count-1,title)
		AudioServer.set_bus_send(AudioServer.get_bus_index(title),"Master")
	AudioServer.add_bus_effect(AudioServer.get_bus_index("LunarWorld"),world_filter)
	AudioServer.add_bus_effect(AudioServer.get_bus_index("LunarSuit"),suit_filter)
	world_filter.cutoff_hz = 20000
	suit_filter.cutoff_hz = 20000
	for sound in campaign.find_children("*","AudioStreamPlayer3D",true,false): route(sound)
	get_tree().node_added.connect(route)
	campaign.pilot.weapon.shot_sound.bus = "LunarSuit"
	campaign.pilot.footsteps.bus = "LunarSuit"
	campaign.pilot.vehicle_engine.bus = "LunarSuit"
	campaign.pilot.cannon_sound.bus = "LunarSuit"
	breath = AudioStreamPlayer.new()
	var loop := preload("res://audio/suit_breath.wav").duplicate() as AudioStreamWAV
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_end = roundi(loop.get_length()*loop.mix_rate)
	breath.stream = loop
	breath.volume_db = -29
	add_child(breath)
	alarm = AudioStreamPlayer.new()
	alarm.stream = preload("res://audio/suit_alarm.wav")
	alarm.volume_db = -17
	add_child(alarm)

func route(node: Node) -> void:
	if node is AudioStreamPlayer3D and campaign.is_ancestor_of(node): node.bus = "LunarWorld"

func _physics_process(delta: float) -> void:
	voice_duck = move_toward(voice_duck, 5.0 if campaign.voice.playing else 0.0, delta * 12.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("LunarWorld"),-18.0*outside_mix-voice_duck)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("LunarSuit"),-voice_duck*0.6)
	if not campaign.pilot.in_control:
		breath.stop()
		return
	var pilot: CharacterBody3D = campaign.pilot
	var vacuum: bool = not campaign.world.air_at(pilot.global_position)
	var outside: bool = vacuum and not (pilot.vehicle!=null and pilot.vehicle.get_meta("sealed",false))
	outside_mix = move_toward(outside_mix,1.0 if vacuum else 0.0,delta*2.0)
	helmet_mix = move_toward(helmet_mix,1.0 if outside else 0.0,delta*2.0)
	world_filter.cutoff_hz = lerpf(20000,900,outside_mix)
	suit_filter.cutoff_hz = lerpf(20000,3100,helmet_mix)
	if outside:
		breath.pitch_scale = 1.2 if pilot.is_sprinting else 1.0
		if not breath.playing: breath.play()
	else: breath.stop()
	alarm_clock = maxf(0,alarm_clock-delta)
	if alarm_clock==0 and ((outside and pilot.oxygen<20) or campaign.selene_power==campaign.Power.OUTAGE or campaign.step==campaign.Step.BATTLE):
		alarm.play()
		alarm_clock = 6.0

func _exit_tree() -> void:
	for title in ["LunarWorld","LunarSuit"]:
		var index := AudioServer.get_bus_index(title)
		if index>=0: AudioServer.remove_bus(index)
