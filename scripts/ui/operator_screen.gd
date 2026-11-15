class_name OperatorScreen
extends Control
## Écran « Opérateurs » (depuis le menu principal) : personnalisation des
## trois opérateurs de l'équipe (`OperatorRoster`), avec aperçu 3D qui tourne
## sur un socle. Chaque changement est sauvegardé aussitôt et s'applique en
## mission.

const SCENE := "res://scenes/ui/operator_screen.tscn"
## Rotation automatique du socle (rad/s) et pause après un glissé (s).
const TURN_SPEED := 0.45
const TURN_PAUSE := 2.5
## Rotation par pixel glissé.
const DRAG_TURN := 0.012
## Distance de la caméra au modèle (m) : bornes et pas de la molette.
const ZOOM_MIN := 1.3
const ZOOM_MAX := 4.5
const ZOOM_STEP := 0.25
## Animations de l'aperçu : nom affiché.
const ANIMATIONS: Dictionary = {
	&"idle": "Repos",
	&"walk": "Marche",
	&"run": "Course",
	&"crouch": "Accroupi",
	&"prone": "Couché",
	&"aim": "Visée",
}

## Opérateur modifié (0 à 2).
var current: int = 0
var roster: OperatorRoster
## Modèle de l'aperçu.
var model: SoldierModel
var zoom: float = 3.0
var animation: StringName = &"idle"
## Confirmation avant de remettre l'opérateur par défaut.
var reset_dialog: ConfirmDialog

var _selectors: Array[Button] = []
var _tabs: TabContainer
var _turntable: Node3D
var _camera: Camera3D
var _turn_pause: float = 0.0
var _dragging: bool = false
var _status: Label
var _animation_buttons: Dictionary = {}
## Contrôles des onglets, rafraîchis quand on change d'opérateur.
var _name_edit: LineEdit
var _callsign_edit: LineEdit
var _option_buttons: Dictionary = {}
var _checks: Dictionary = {}
var _spins: Dictionary = {}
var _swatches: Dictionary = {}
var _camo_buttons: Dictionary = {}
var _weapon_info: Label
var _refreshing: bool = false


func _ready() -> void:
	roster = OperatorRoster.current()
	var background := ColorRect.new()
	background.color = Color(0.11, 0.13, 0.12)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 12)
	margin.add_child(column)
	column.add_child(_build_header())
	column.add_child(_build_selectors())
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override(&"separation", 16)
	column.add_child(body)
	body.add_child(_build_preview())
	_tabs = TabContainer.new()
	_tabs.name = "Tabs"
	_tabs.custom_minimum_size = Vector2(460, 0)
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_tabs)
	_add_tab("Identité", _build_identity())
	_add_tab("Tenue", _build_outfit())
	_add_tab("Accessoires", _build_accessories())
	_add_tab("Armement", _build_armament())
	column.add_child(_build_footer())
	reset_dialog = ConfirmDialog.new("Réinitialiser", "", "Réinitialiser", reset_current)
	add_child(reset_dialog)
	select(0)


## Modifie l'opérateur `index` (0 à 2).
func select(index: int) -> void:
	current = clampi(index, 0, roster.operators.size() - 1)
	for i in _selectors.size():
		_selectors[i].set_pressed_no_signal(i == current)
	_refresh_controls()
	_update_preview()


func profile() -> OperatorProfile:
	return roster.operators[current]


## Remet l'opérateur modifié à son profil par défaut (et sauvegarde).
func reset_current() -> void:
	roster.reset(current)
	_refresh_controls()
	_changed()


## Lance l'animation `id` de l'aperçu (`ANIMATIONS`).
func play(id: StringName) -> void:
	animation = id
	for key: StringName in _animation_buttons:
		(_animation_buttons[key] as Button).set_pressed_no_signal(key == id)
	_apply_animation()


func back_to_menu() -> void:
	get_tree().change_scene_to_file(LevelCatalog.MENU_SCENE)


func _process(delta: float) -> void:
	if _turn_pause > 0.0:
		_turn_pause -= delta
	elif not _dragging:
		_turntable.rotation.y += TURN_SPEED * delta
	_place_camera()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		back_to_menu()


# --- Construction ------------------------------------------------------------

func _build_header() -> Control:
	var row := HBoxContainer.new()
	var title := Label.new()
	title.text = "OPÉRATEURS"
	title.add_theme_font_size_override(&"font_size", 34)
	title.add_theme_color_override(&"font_color", Color(0.85, 0.9, 0.82))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	var back := Button.new()
	back.name = "Back"
	back.text = "Retour au menu"
	back.pressed.connect(back_to_menu)
	row.add_child(back)
	return row


## Portraits cliquables des trois opérateurs (numéro, indicatif, nom).
func _build_selectors() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	var group := ButtonGroup.new()
	for i in roster.operators.size():
		var button := Button.new()
		button.name = "Operator%d" % (i + 1)
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size = Vector2(190, 56)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(select.bind(i))
		row.add_child(button)
		_selectors.append(button)
	_refresh_selectors()
	return row


func _build_preview() -> Control:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var container := SubViewportContainer.new()
	container.name = "Preview"
	container.stretch = true
	container.custom_minimum_size = Vector2(420, 420)
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.gui_input.connect(_on_preview_input)
	column.add_child(container)
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	container.add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.16, 0.18, 0.17)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.58, 0.55)
	environment.ambient_light_energy = 0.8
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	world.add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.8, 0.5, 0.0)
	sun.shadow_enabled = true
	world.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(-0.3, PI + 0.6, 0.0)
	fill.light_energy = 0.35
	world.add_child(fill)
	# Socle.
	var base := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.6
	disc.bottom_radius = 0.65
	disc.height = 0.1
	base.mesh = disc
	base.position.y = -0.05
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.24, 0.26, 0.25)
	stone.roughness = 0.9
	base.material_override = stone
	world.add_child(base)
	_turntable = Node3D.new()
	_turntable.name = "Turntable"
	_turntable.rotation.y = PI
	world.add_child(_turntable)
	model = SoldierModel.new()
	model.name = "Model"
	model.silent = true
	_turntable.add_child(model)
	_camera = Camera3D.new()
	_camera.fov = 40.0
	world.add_child(_camera)
	_place_camera()
	# Animations et aide.
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override(&"separation", 6)
	var group := ButtonGroup.new()
	for id: StringName in ANIMATIONS:
		var button := Button.new()
		button.text = ANIMATIONS[id]
		button.toggle_mode = true
		button.button_group = group
		button.pressed.connect(play.bind(id))
		buttons.add_child(button)
		_animation_buttons[id] = button
	column.add_child(buttons)
	var hint := Label.new()
	hint.text = "Glisser : faire pivoter  •  Molette : zoom"
	hint.modulate = Color(1, 1, 1, 0.6)
	column.add_child(hint)
	(_animation_buttons[&"idle"] as Button).button_pressed = true
	return column


func _build_identity() -> Control:
	var box := _section_box()
	_name_edit = _line_edit(box, "Nom", 24, func(text: String) -> void:
		profile().name = text.strip_edges()
		_changed(false))
	_callsign_edit = _line_edit(box, "Indicatif", 16, func(text: String) -> void:
		var callsign := text.strip_edges()
		profile().callsign = callsign if not callsign.is_empty() else OperatorProfile.defaults(current).callsign
		_changed(false))
	_heading(box, "Visage")
	_swatch_row(box, &"skin", GearCatalog.SKINS, func(i: int) -> void: profile().skin = i)
	_option(box, "Barbe", &"beard", GearCatalog.BEARDS)
	_heading(box, "Cheveux")
	_option(box, "Coupe", &"hair_style", GearCatalog.HAIR_STYLES)
	_swatch_row(box, &"hair_color", GearCatalog.HAIR_COLORS, func(i: int) -> void: profile().hair_color = i)
	_note(box, "Le visage se voit sans cagoule (onglet Accessoires).")
	return box


func _build_outfit() -> Control:
	var box := _section_box()
	_heading(box, "Camouflage (haut et pantalon)")
	var camos := HFlowContainer.new()
	var group := ButtonGroup.new()
	var ids: Array[StringName] = [&""]
	ids.append_array(GearCatalog.CAMOS.keys())
	for id in ids:
		var button := Button.new()
		button.text = "Uni" if id.is_empty() else GearCatalog.CAMOS[id]["name"]
		button.toggle_mode = true
		button.button_group = group
		button.pressed.connect(func() -> void:
			if id.is_empty():
				profile().camo = &""
			else:
				profile().set_camo(id)
			_refresh_controls()
			_changed())
		camos.add_child(button)
		_camo_buttons[id] = button
	box.add_child(camos)
	for entry: Array in [["Haut", "top_color", true], ["Pantalon", "pants_color", true], ["Gilet et équipement", "vest_color", false], ["Couvre-chef", "headwear_color", false]]:
		_heading(box, entry[0])
		var key := StringName(entry[1])
		var plain: bool = entry[2]
		_swatch_row(box, key, GearCatalog.PALETTE, func(i: int) -> void:
			profile().set(key, GearCatalog.PALETTE[i])
			# Une couleur unie choisie pour le haut ou le pantalon remplace le camouflage.
			if plain:
				profile().camo = &"")
	return box


func _build_accessories() -> Control:
	var box := _section_box()
	_option(box, "Couvre-chef", &"headwear", GearCatalog.HEADWEAR)
	_heading(box, "Accessoires")
	for key: StringName in GearCatalog.ACCESSORIES:
		var check := CheckBox.new()
		check.text = GearCatalog.ACCESSORIES[key]
		check.toggled.connect(func(on: bool) -> void:
			if _refreshing:
				return
			profile().set(key, on)
			_changed())
		box.add_child(check)
		_checks[key] = check
	return box


func _build_armament() -> Control:
	var box := _section_box()
	_option(box, "Arme principale", &"primary", _names(GearCatalog.PRIMARY))
	_weapon_info = Label.new()
	_weapon_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_weapon_info.modulate = Color(1, 1, 1, 0.8)
	box.add_child(_weapon_info)
	_option(box, "Arme secondaire", &"secondary", GearCatalog.SECONDARY)
	_heading(box, "Équipement")
	for key: StringName in GearCatalog.EQUIPMENT:
		var entry: Dictionary = GearCatalog.EQUIPMENT[key]
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = entry["name"]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var spin := SpinBox.new()
		spin.min_value = 0
		spin.max_value = entry["max"]
		spin.value_changed.connect(func(value: float) -> void:
			if _refreshing:
				return
			profile().set(key, int(value))
			_changed())
		row.add_child(spin)
		box.add_child(row)
		_spins[key] = spin
	_note(box, "Le couteau de combat est toujours emporté. L'arme principale et les couteaux de lancer comptent en mission ; arme secondaire, grenades, charges et trousse ne sont pour l'instant que portées (visibles), pas encore utilisables.")
	return box


func _build_footer() -> Control:
	var row := HBoxContainer.new()
	var reset := Button.new()
	reset.name = "Reset"
	reset.text = "Réinitialiser l'opérateur"
	reset.pressed.connect(func() -> void:
		reset_dialog.dialog_text = "Remettre %s dans sa tenue par défaut ?" % profile().callsign
		reset_dialog.ask())
	row.add_child(reset)
	_status = Label.new()
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status.modulate = Color(1, 1, 1, 0.65)
	row.add_child(_status)
	return row


# --- Petits contrôles -------------------------------------------------------

func _add_tab(title: String, content: Control) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	margin.add_child(content)
	scroll.add_child(margin)
	_tabs.add_child(scroll)


func _section_box() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override(&"separation", 8)
	return box


func _heading(box: Container, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override(&"font_color", Color(0.75, 0.85, 0.7))
	box.add_child(label)


func _note(box: Container, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override(&"font_size", 13)
	label.modulate = Color(1, 1, 1, 0.6)
	box.add_child(label)


func _line_edit(box: Container, title: String, length: int, on_change: Callable) -> LineEdit:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = title
	label.custom_minimum_size = Vector2(110, 0)
	row.add_child(label)
	var edit := LineEdit.new()
	edit.name = title
	edit.max_length = length
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.text_changed.connect(func(text: String) -> void:
		if not _refreshing:
			on_change.call(text))
	row.add_child(edit)
	box.add_child(row)
	return edit


## Liste déroulante liée à la propriété `key` du profil (`choices` : id → nom).
func _option(box: Container, title: String, key: StringName, choices: Dictionary) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = title
	label.custom_minimum_size = Vector2(150, 0)
	row.add_child(label)
	var option := OptionButton.new()
	option.name = String(key)
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ids: Array = choices.keys()
	for id: StringName in ids:
		option.add_item(choices[id])
	option.item_selected.connect(func(index: int) -> void:
		if _refreshing:
			return
		profile().set(key, ids[index])
		_refresh_controls()
		_changed())
	row.add_child(option)
	box.add_child(row)
	_option_buttons[key] = [option, ids]


## Rangée de pastilles de couleur ; `on_pick` reçoit l'indice choisi.
func _swatch_row(box: Container, key: StringName, colors: Array[Color], on_pick: Callable) -> void:
	var row := HFlowContainer.new()
	row.add_theme_constant_override(&"h_separation", 4)
	row.add_theme_constant_override(&"v_separation", 4)
	var buttons: Array[Button] = []
	for i in colors.size():
		var button := Button.new()
		button.custom_minimum_size = Vector2(28, 28)
		button.tooltip_text = "#" + colors[i].to_html(false)
		for state in ["normal", "hover", "pressed", "focus"]:
			var style := StyleBoxFlat.new()
			style.bg_color = colors[i]
			style.set_corner_radius_all(4)
			style.set_border_width_all(2 if state != "normal" else 1)
			style.border_color = Color(0.9, 0.9, 0.85) if state != "normal" else Color(0, 0, 0, 0.5)
			button.add_theme_stylebox_override(state, style)
		button.pressed.connect(func() -> void:
			on_pick.call(i)
			_refresh_controls()
			_changed())
		row.add_child(button)
		buttons.append(button)
	box.add_child(row)
	_swatches[key] = [buttons, colors]


func _names(entries: Dictionary) -> Dictionary:
	var names := {}
	for id: StringName in entries:
		names[id] = entries[id]["name"]
	return names


# --- Mise à jour -------------------------------------------------------------

## Le profil a changé : aperçu (si `rebuild`), portraits, sauvegarde.
func _changed(rebuild: bool = true) -> void:
	if rebuild:
		_update_preview()
	_refresh_selectors()
	var error := roster.save()
	_status.text = "Sauvegardé" if error == OK else "Échec de la sauvegarde (%s)" % error_string(error)


func _refresh_selectors() -> void:
	for i in _selectors.size():
		var operator := roster.operators[i]
		_selectors[i].text = "%d  %s\n    %s" % [i + 1, operator.callsign, operator.name]


## Contrôles des onglets d'après le profil de l'opérateur courant.
func _refresh_controls() -> void:
	_refreshing = true
	var operator := profile()
	if _name_edit.text != operator.name:
		_name_edit.text = operator.name
	if _callsign_edit.text != operator.callsign:
		_callsign_edit.text = operator.callsign
	for key: StringName in _option_buttons:
		var option: OptionButton = _option_buttons[key][0]
		option.select((_option_buttons[key][1] as Array).find(operator.get(key)))
	for key: StringName in _checks:
		var check: CheckBox = _checks[key]
		check.button_pressed = operator.get(key)
	var nvg: CheckBox = _checks[&"nvg"]
	nvg.disabled = operator.headwear != &"helmet"
	nvg.tooltip_text = "Se fixe sur le casque balistique." if nvg.disabled else ""
	for key: StringName in _spins:
		(_spins[key] as SpinBox).value = operator.get(key)
	for key: StringName in _swatches:
		var buttons: Array[Button] = _swatches[key][0]
		var colors: Array[Color] = _swatches[key][1]
		var value: Variant = operator.get(key)
		for i in buttons.size():
			var chosen: bool = (value == i) if value is int else (value as Color).is_equal_approx(colors[i])
			buttons[i].modulate = Color.WHITE if chosen else Color(1, 1, 1, 0.75)
			buttons[i].text = "✓" if chosen else ""
	for id: StringName in _camo_buttons:
		(_camo_buttons[id] as Button).set_pressed_no_signal(id == operator.camo)
	var weapon: Dictionary = GearCatalog.PRIMARY[operator.primary]
	var stats: Dictionary = weapon["stats"]
	_weapon_info.text = "%s\nPortée %d m • Dégâts %d • %.1f tirs/s • Chargeur %d (+%d)" % [
		weapon["description"], stats["fire_range"], stats["fire_damage"], 1.0 / float(stats["fire_interval"]),
		stats["magazine_size"], stats["reserve_ammo"]]
	_refreshing = false


func _update_preview() -> void:
	model.outfit = profile()
	_apply_animation()


func _apply_animation() -> void:
	model.move_ratio = {&"walk": 1.0, &"run": 2.0}.get(animation, 0.0)
	match animation:
		&"crouch":
			model.posture = SoldierModel.Posture.CROUCHED
		&"prone":
			model.posture = SoldierModel.Posture.PRONE
		_:
			model.posture = SoldierModel.Posture.STANDING
	model.aiming = animation == &"aim"


func _place_camera() -> void:
	# Plus on est près, plus on vise la tête (plus bas accroupi ou couché).
	var head: float = {&"crouch": 1.1, &"prone": 0.4}.get(animation, 1.5)
	var middle: float = {&"crouch": 0.65, &"prone": 0.3}.get(animation, 0.95)
	var target_height := lerpf(head, middle, (zoom - ZOOM_MIN) / (ZOOM_MAX - ZOOM_MIN))
	var eye := Vector3(0.0, target_height + zoom * 0.18, zoom)
	_camera.transform = Transform3D(Basis(), eye).looking_at(Vector3(0.0, target_height, 0.0))


func _on_preview_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button:
		match button.button_index:
			MOUSE_BUTTON_LEFT:
				_dragging = button.pressed
				_turn_pause = TURN_PAUSE
			MOUSE_BUTTON_WHEEL_UP:
				zoom = maxf(zoom - ZOOM_STEP, ZOOM_MIN)
			MOUSE_BUTTON_WHEEL_DOWN:
				zoom = minf(zoom + ZOOM_STEP, ZOOM_MAX)
		return
	var motion := event as InputEventMouseMotion
	if motion and _dragging:
		_turntable.rotation.y += motion.relative.x * DRAG_TURN
		_turn_pause = TURN_PAUSE
