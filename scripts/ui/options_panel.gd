class_name OptionsPanel
extends Control
## Options (menu pause) : volumes, plein écran, défilement de la caméra par
## le bord de l'écran, parade automatique. Enregistrées par `Settings`.

signal closed

var _was_paused: bool = false


func _ready() -> void:
	name = "OptionsPanel"
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()


func open() -> void:
	if visible:
		return
	_was_paused = get_tree().paused
	get_tree().paused = true
	visible = true
	(find_child("Close", true, false) as Button).grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = _was_paused
	closed.emit()


func is_open() -> bool:
	return visible


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _build() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.09, 0.11, 0.96)
	style.border_color = Color(0.35, 0.55, 0.75, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override(&"panel", style)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 12)
	column.custom_minimum_size = Vector2(380, 0)
	panel.add_child(column)
	var title := Label.new()
	title.text = "Options"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", 26)
	column.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", 16)
	grid.add_theme_constant_override(&"v_separation", 10)
	column.add_child(grid)
	for bus: StringName in Settings.BUSES:
		var label := Label.new()
		label.text = Settings.BUSES[bus]
		grid.add_child(label)
		var slider := HSlider.new()
		slider.name = "Volume%s" % bus
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.custom_minimum_size = Vector2(200, 0)
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.value = Settings.volume(bus)
		slider.value_changed.connect(func(value: float) -> void: Settings.set_value("audio", String(bus), value))
		grid.add_child(slider)
	var fullscreen := CheckBox.new()
	fullscreen.name = "Fullscreen"
	fullscreen.text = "Plein écran"
	fullscreen.button_pressed = Settings.fullscreen()
	fullscreen.toggled.connect(func(on: bool) -> void: Settings.set_value("display", "fullscreen", on))
	column.add_child(fullscreen)
	var edge := CheckBox.new()
	edge.name = "EdgeScroll"
	edge.text = "Déplacer la caméra au bord de l'écran"
	edge.button_pressed = Settings.edge_scroll()
	edge.toggled.connect(func(on: bool) -> void: Settings.set_value("display", "edge_scroll", on))
	column.add_child(edge)
	var follow := CheckBox.new()
	follow.name = "FollowVehicle"
	follow.text = "La caméra suit le véhicule en route"
	follow.button_pressed = Settings.follow_vehicle()
	follow.toggled.connect(func(on: bool) -> void: Settings.set_value("display", "follow_vehicle", on))
	column.add_child(follow)
	var parry := CheckBox.new()
	parry.name = "AutoParry"
	parry.text = "Parade automatique (au hasard, sans la touche %s)" % KeyNames.label(&"parry")
	parry.button_pressed = Settings.auto_parry()
	parry.toggled.connect(func(on: bool) -> void: Settings.set_value("gameplay", "auto_parry", on))
	column.add_child(parry)
	var close_button := Button.new()
	close_button.name = "Close"
	close_button.text = "Retour"
	close_button.pressed.connect(close)
	column.add_child(close_button)
