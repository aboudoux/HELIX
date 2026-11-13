extends CanvasLayer

signal start_pressed
signal menu_pressed
signal restart_pressed
signal continue_pressed

const FONT := preload("res://assets/fonts/DejaVuSans.ttf")
# NASA / Artemis II, art002e009594, Orientale Basin Along the Moon's Limb.
const LUNAR_PHOTO := preload("res://missions/lunar_escape/menu_lunar_orbit.jpg")
const TEXT := Color("e0efff")
const CYAN := Color("92efff")
const AMBER := Color("ffce83")

var content: Control
var chapter: Label
var objective: Label
var optional_objective: Label
var inventory: Label
var status: Label
var modules: Label
var oxygen: Label
var visor: Panel
var hint: Label
var dialogue: Label
var marker: Label
var marker_icon: Label
var reticle: Label
var boss_label: Label
var boss_meter: ProgressBar
var film_bars: Control
var title_card: PanelContainer
var intro_backdrop: Control
var intro_menu := false
var card_kicker: Label
var card_title: Label
var card_copy: Label
var primary: Button
var secondary: Button
var has_started := false
var continue_button: Button
var save_available := false
var health_panel: VBoxContainer
var health_label: Label
var health_meter: ProgressBar
var damage_feedback: Control
var health_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	content = Control.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content)
	visor = Panel.new()
	visor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var seal := panel_style(Color.TRANSPARENT, Color("2e688494"))
	seal.set_border_width_all(8)
	seal.set_corner_radius_all(33)
	visor.add_theme_stylebox_override("panel", seal)
	content.add_child(visor)
	visor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visor.hide()
	damage_feedback = preload("res://missions/lunar_escape/damage_feedback.gd").new()
	content.add_child(damage_feedback)
	health_panel = stack(Vector2(34,-183),Vector2(300,0),Control.PRESET_BOTTOM_LEFT)
	health_label = label(health_panel,"VIE  100 / 100",16,Color("fff1f1"))
	health_meter = ProgressBar.new()
	health_meter.custom_minimum_size = Vector2(300,22)
	health_meter.show_percentage = false
	health_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_meter.add_theme_stylebox_override("background",panel_style(Color("290e16e8"),Color("953a49")))
	health_meter.add_theme_stylebox_override("fill",panel_style(Color("ed344b"),Color("ff6975")))
	health_panel.add_child(health_meter)
	health_meter.value = 100

	var mission := stack(Vector2(34, 30), Vector2(540, 0), Control.PRESET_TOP_LEFT)
	chapter = label(mission, "", 15, CYAN)
	objective = label(mission, "", 24, TEXT)
	objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	optional_objective = label(mission, "", 15, AMBER)
	optional_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var loadout := stack(Vector2(34, -118), Vector2(415, 0), Control.PRESET_BOTTOM_LEFT)
	inventory = label(loadout, "", 17, TEXT)
	status = label(loadout, "", 15, CYAN)
	oxygen = label(loadout, "", 15, CYAN)
	modules = label(loadout,"",13,AMBER)
	modules.text = "Tab · Carte"
	hint = label(content, "", 19, AMBER)
	pin(hint, Control.PRESET_CENTER_BOTTOM, Vector2(-410, -131), Vector2(820, 36))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	reticle = label(content, "+", 23, Color("c5e9f2"))
	pin(reticle, Control.PRESET_CENTER, Vector2(-15, -15), Vector2(30, 30))
	reticle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reticle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	marker_icon = label(content, "◇", 26, CYAN)
	marker = label(content, "", 13, CYAN)
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var boss := stack(Vector2(-210, 108), Vector2(420, 0), Control.PRESET_CENTER_TOP)
	boss_label = label(boss, "QUADRUPÈDE DE SIÈGE", 14, AMBER)
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_meter = ProgressBar.new()
	boss_meter.custom_minimum_size = Vector2(0, 9)
	boss_meter.show_percentage = false
	boss_meter.add_theme_stylebox_override("background", panel_style(Color("1f202f"), Color.TRANSPARENT))
	boss_meter.add_theme_stylebox_override("fill", panel_style(Color("ff6688"), Color.TRANSPARENT))
	boss.add_child(boss_meter)
	set_boss_health(0, 1)

	film_bars = Control.new()
	film_bars.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	film_bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(film_bars)
	for side in [Control.PRESET_TOP_WIDE, Control.PRESET_BOTTOM_WIDE]:
		var bar := ColorRect.new()
		bar.color = Color("070a13")
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		film_bars.add_child(bar)
		bar.set_anchors_and_offsets_preset(side)
		if side == Control.PRESET_TOP_WIDE:
			bar.offset_bottom = 60
		else:
			bar.offset_top = -96
	film_bars.hide()
	dialogue = label(content, "", 20, TEXT)
	pin(dialogue, Control.PRESET_CENTER_BOTTOM, Vector2(-470, -208), Vector2(940, 78))
	dialogue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialogue.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	build_menu()


func build_menu() -> void:
	build_intro_backdrop()
	title_card = PanelContainer.new()
	content.add_child(title_card)
	title_card.visibility_changed.connect(update_intro_backdrop)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	title_card.add_child(body)
	card_kicker = label(body, "", 15, CYAN)
	card_title = label(body, "", 38, TEXT)
	card_copy = label(body, "", 17, TEXT)
	card_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_copy.size_flags_vertical = Control.SIZE_EXPAND_FILL
	primary = button(body, "Commencer", func(): start_pressed.emit())
	continue_button = button(body,"Continuer la sauvegarde",func(): continue_pressed.emit())
	secondary = button(body, "Recommencer la campagne", func(): restart_pressed.emit())
	body.move_child(continue_button, primary.get_index())
	content.resized.connect(layout_menu)


func build_intro_backdrop() -> void:
	intro_backdrop = Control.new()
	intro_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(intro_backdrop)
	intro_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var photo := TextureRect.new()
	photo.texture = LUNAR_PHOTO
	photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intro_backdrop.add_child(photo)
	photo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var shades := Gradient.new()
	shades.offsets = PackedFloat32Array([0.0, 0.40, 0.68, 1.0])
	shades.colors = PackedColorArray([Color("070c1810"), Color("070c182a"), Color("090e18e8"), Color("090e18")])
	var gradient := GradientTexture2D.new()
	gradient.gradient = shades
	gradient.fill_from = Vector2.ZERO
	gradient.fill_to = Vector2.RIGHT
	var scrim := TextureRect.new()
	scrim.texture = gradient
	scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intro_backdrop.add_child(scrim)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var credit := label(intro_backdrop, "Bassin Orientale  ·  Photo NASA / Artemis II", 13, Color("ced5df"))
	pin(credit, Control.PRESET_BOTTOM_LEFT, Vector2(32, -48), Vector2(400, 24))
	intro_backdrop.hide()


func layout_menu() -> void:
	if not intro_menu:
		pin(title_card, Control.PRESET_CENTER, Vector2(-278, -178), Vector2(556, 356))
		return
	var width := clampf(content.size.x * 0.36, 340, 474)
	var margin := clampf(content.size.x * 0.06, 30, 100)
	var height := 435.0 if save_available else 380.0
	pin(title_card, Control.PRESET_CENTER_RIGHT, Vector2(-width - margin, -height * .5), Vector2(width, height))


func update_intro_backdrop() -> void:
	intro_backdrop.visible = intro_menu and title_card.is_visible_in_tree()


func style_menu_button(node: Button, highlighted := false) -> void:
	node.custom_minimum_size.y = 52 if intro_menu else 39
	node.alignment = HORIZONTAL_ALIGNMENT_LEFT if intro_menu else HORIZONTAL_ALIGNMENT_CENTER
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var foreground := Color("171416") if highlighted else TEXT
	var fill := Color("f0c988") if highlighted else Color("151f2bea")
	var hover := Color("ffdb9f") if highlighted else Color("25364a")
	var border := Color("e8ba75") if highlighted else Color("465466")
	var normal := panel_style(fill, border, 16) if intro_menu else panel_style(Color("203649"), Color("3f6880"))
	var over := panel_style(hover, border, 16) if intro_menu else panel_style(Color("2f536d"), CYAN)
	node.add_theme_stylebox_override("normal", normal)
	node.add_theme_stylebox_override("hover", over)
	node.add_theme_stylebox_override("pressed", over)
	node.add_theme_stylebox_override("hover_pressed", over)
	node.add_theme_stylebox_override("focus", panel_style(Color.TRANSPARENT, Color("fff2db"), 0))
	for state in ["font_color", "font_focus_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		node.add_theme_color_override(state, foreground)


func show_menu(mode: String) -> void:
	intro_menu = mode == "intro"
	title_card.show()
	update_intro_backdrop()
	continue_button.visible = mode=="intro" and save_available
	secondary.visible = mode == "pause"
	match mode:
		"intro":
			card_kicker.text = "HELIX / DRONE ARENA"
			card_title.text = "Le silence de Karen"
			card_copy.text = "La base lunaire Karen ne répond plus. Retrouvez les survivants et récupérez le journal de bord."
			primary.text = "Nouvelle campagne" if save_available else "Commencer"
		"pause":
			card_kicker.text = "HELIX  /  EN PAUSE"
			card_title.text = "Campagne en pause"
			card_copy.text = "ZQSD / WASD : déplacement · Maj : courir · E : interagir\nClic gauche : tirer · Clic droit : viser · R : recharger\n1 / 2 / 3 : armes · F : bouclier · Tab : carte\nVéhicule : souris pour viser · Clic gauche pour tirer\nSauvegarde : reprise au point sûr, équipement conservé."
			primary.text = "Reprendre"
		"death":
			card_kicker.text = "HELIX  /  LIAISON INTERROMPUE"
			card_title.text = "Signal perdu"
			card_copy.text = "Reprenez depuis le dernier point de passage."
			primary.text = "Reprendre au point de passage"
		"complete":
			card_kicker.text = "HELIX  /  ÉPILOGUE"
			card_title.text = "De retour sur Terre"
			card_copy.text = "Vous, Maël, Noor et Lina avez amerri dans le Pacifique. Toute l'équipe est vivante. Le journal de Karen est transmis à la Terre et les secours partent chercher les familles restées dans les abris de Tycho."
			primary.text = "Rejouer la campagne"
	var panel := panel_style(Color.TRANSPARENT, Color.TRANSPARENT) if intro_menu else panel_style(Color("101b2ef7"), Color("34556e"), 30)
	title_card.add_theme_stylebox_override("panel", panel)
	card_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if intro_menu else TextServer.AUTOWRAP_OFF
	card_title.add_theme_font_size_override("font_size", 54 if intro_menu else 38)
	var title_font := FontVariation.new()
	title_font.base_font = FONT
	title_font.variation_embolden = .72
	card_title.add_theme_font_override("font", title_font if intro_menu else FONT)
	card_kicker.add_theme_color_override("font_color", AMBER if intro_menu else CYAN)
	card_copy.add_theme_color_override("font_color", Color("c2cad8") if intro_menu else TEXT)
	card_copy.add_theme_constant_override("line_spacing", 5 if intro_menu else 0)
	var default_button := continue_button if intro_menu and save_available else primary
	for action in [primary, continue_button, secondary]:
		style_menu_button(action, intro_menu and action == default_button)
	layout_menu()
	default_button.grab_focus()


func set_film(active: bool) -> void:
	health_panel.visible = not active
	damage_feedback.visible = not active
	if active: damage_feedback.impacts.clear()
	film_bars.visible = active
	pin(dialogue, Control.PRESET_CENTER_BOTTOM, Vector2(-470,-88 if active else -208), Vector2(940,78))
	chapter.get_parent().visible = not active
	inventory.get_parent().visible = not active
	reticle.visible = not active
	if active:
		visor.hide()
		hint.text = ""
		marker.hide()
		marker_icon.hide()


func set_health(current: int, maximum: int) -> void:
	health_label.text = "VIE  %d / %d%s" % [current, maximum, "  ·  CRITIQUE" if current <= maximum*0.25 else ""]
	health_meter.max_value = maximum
	if health_tween != null: health_tween.kill()
	health_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	health_tween.tween_property(health_meter,"value",float(current),0.18)
	health_label.modulate = Color("ff7180") if current <= maximum*0.25 else Color.WHITE


func set_air(level: float, breathable: bool, in_cabin: bool) -> void:
	visor.visible = not breathable
	var mode := "CABINE PRESSURISÉE" if in_cabin else ("AIR INTÉRIEUR" if breathable else "COMBINAISON")
	var warning := "  ·  AIR CRITIQUE" if not breathable and level < 20.0 else ""
	oxygen.text = "O₂ %d %%  ·  %s%s" % [ceili(level), mode, warning]
	oxygen.modulate = Color("ff976f") if not warning.is_empty() else CYAN


func set_marker(camera: Camera3D, point: Vector3, title: String, distance: float) -> void:
	var show_marker := not title.is_empty() and not film_bars.visible and not title_card.visible
	marker.visible = show_marker
	marker_icon.visible = show_marker
	if not show_marker:
		return
	var bounds := get_viewport().get_visible_rect().size
	var local := camera.to_local(point)
	var screen: Vector2
	if local.z >= -camera.near:
		screen = Vector2(52.0 if local.x < 0.0 else bounds.x - 52.0, bounds.y * 0.5)
	else:
		screen = camera.unproject_position(point)
	screen = screen.clamp(Vector2(66, 157), bounds - Vector2(66, 158))
	marker_icon.position = screen - Vector2(11, 26)
	marker.text = "%s · %d m" % [title, roundi(distance)]
	marker.size = Vector2(190, 23)
	marker.position = screen - Vector2(95, 1)


func set_boss_health(current: int, maximum: int) -> void:
	boss_label.get_parent().visible = current > 0
	boss_meter.max_value = maximum
	boss_meter.value = current


func _unhandled_input(event: InputEvent) -> void:
	if has_started and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		menu_pressed.emit()


func stack(point: Vector2, size: Vector2, preset: Control.LayoutPreset) -> VBoxContainer:
	var node := VBoxContainer.new()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_constant_override("separation", 5)
	content.add_child(node)
	pin(node, preset, point, size)
	return node


func button(parent: Control, caption: String, callback: Callable) -> Button:
	var node := Button.new()
	node.text = caption
	node.custom_minimum_size.y = 39
	node.add_theme_font_override("font", FONT)
	node.add_theme_font_size_override("font_size", 16)
	node.add_theme_stylebox_override("normal", panel_style(Color("203649"), Color("3f6880")))
	node.add_theme_stylebox_override("hover", panel_style(Color("2f536d"), CYAN))
	node.pressed.connect(callback)
	parent.add_child(node)
	return node


func label(parent: Control, caption: String, font_size: int, tint: Color) -> Label:
	var node := Label.new()
	node.text = caption
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_font_override("font", FONT)
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", tint)
	node.add_theme_color_override("font_outline_color", Color("050a17"))
	node.add_theme_constant_override("outline_size", 6)
	parent.add_child(node)
	return node


func pin(node: Control, preset: Control.LayoutPreset, point: Vector2, size: Vector2) -> void:
	node.set_anchors_and_offsets_preset(preset)
	node.offset_left = point.x
	node.offset_top = point.y
	node.offset_right = point.x + size.x
	node.offset_bottom = point.y + size.y


func panel_style(fill: Color, border: Color, margin := 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.content_margin_left = margin
	style.content_margin_top = margin
	style.content_margin_right = margin
	style.content_margin_bottom = margin
	return style
