class_name PauseMenu
extends Control
## Menu pause (Échap) : reprendre, recommencer la mission, aide, options,
## retour au menu, quitter. Le jeu est en pause tant qu'il est ouvert.

signal resume_requested
signal restart_requested
signal help_requested
signal options_requested
signal menu_requested
signal quit_requested

var _was_paused: bool = false
## Fermé le temps d'une autre page (aide, options, confirmation) : à sa
## réouverture, la pause d'origine reste celle d'avant le menu.
var _suspended: bool = false
var _first: Button


func _ready() -> void:
	name = "PauseMenu"
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()


func open() -> void:
	if visible:
		return
	if not _suspended:
		_was_paused = get_tree().paused
	_suspended = false
	get_tree().paused = true
	visible = true
	_first.grab_focus()


## Ferme le menu ; `keep_paused` laisse le jeu en pause (une autre page
## prend le relais).
func close(keep_paused: bool = false) -> void:
	if not visible:
		return
	visible = false
	_suspended = keep_paused
	if not keep_paused:
		get_tree().paused = _was_paused


func is_open() -> bool:
	return visible


## Vrai pendant qu'une page ouverte depuis le menu le remplace.
func is_suspended() -> bool:
	return _suspended


## Renonce au menu suspendu (la page ouverte depuis lui a quitté la partie,
## ou relancé la mission) : la pause d'avant le menu est rétablie.
func abandon() -> void:
	if _suspended:
		_suspended = false
		get_tree().paused = _was_paused


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
		resume_requested.emit()


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
	panel.name = "Panel"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.09, 0.11, 0.95)
	style.border_color = Color(0.35, 0.55, 0.75, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override(&"panel", style)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 10)
	column.custom_minimum_size = Vector2(280, 0)
	panel.add_child(column)
	var title := Label.new()
	title.text = "Pause"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", 26)
	column.add_child(title)
	_first = _button(column, "Resume", "Reprendre", func() -> void:
		close()
		resume_requested.emit())
	_button(column, "Restart", "Recommencer la mission", func() -> void:
		close(true)
		restart_requested.emit())
	_button(column, "Help", "Aide", func() -> void:
		close(true)
		help_requested.emit())
	# Options : voir le point 5.7.
	var options := _button(column, "Options", "Options", func() -> void:
		close(true)
		options_requested.emit())
	options.visible = false
	_button(column, "Menu", "Menu principal", func() -> void:
		close(true)
		menu_requested.emit())
	_button(column, "Quit", "Quitter le jeu", func() -> void:
		close(true)
		quit_requested.emit())


func _button(parent: Control, node_name: String, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.custom_minimum_size = Vector2(0, 36)
	button.pressed.connect(action)
	parent.add_child(button)
	return button
