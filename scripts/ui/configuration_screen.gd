class_name ConfigurationScreen
extends Control
## Page « Configuration » du menu de démarrage : réglages du jeu,
## enregistrés par `Settings`. Pour l'instant : son activé ou coupé.

signal closed


func _ready() -> void:
	name = "Configuration"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()


func open() -> void:
	(find_child("Sound", true, false) as CheckButton).set_pressed_no_signal(Settings.sound_enabled())
	visible = true
	(find_child("Sound", true, false) as Control).grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
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
	column.add_theme_constant_override(&"separation", 14)
	column.custom_minimum_size = Vector2(380, 0)
	panel.add_child(column)
	var title := Label.new()
	title.text = "Configuration"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", 26)
	column.add_child(title)
	var heading := Label.new()
	heading.text = "SON"
	heading.add_theme_color_override(&"font_color", Color(0.55, 0.75, 0.95))
	column.add_child(heading)
	var sound := CheckButton.new()
	sound.name = "Sound"
	sound.text = "Son activé"
	sound.tooltip_text = "Coupé, le jeu est muet (musique et effets), quels que soient les volumes des options."
	sound.button_pressed = Settings.sound_enabled()
	sound.toggled.connect(func(on: bool) -> void: Settings.set_value("audio", "enabled", on))
	column.add_child(sound)
	var close_button := Button.new()
	close_button.name = "Close"
	close_button.text = "Retour"
	close_button.pressed.connect(close)
	column.add_child(close_button)
