class_name EndScreen
extends Control
## Écran de fin de mission : réussite ou échec (VIP évacué ou tué, opérateur
## tué…), avec le message de la mission. Propose de recommencer, de revenir
## au menu, ou de continuer à jouer (la partie n'est pas bloquée). Le jeu est
## en pause tant qu'il est affiché.

signal restart_requested
signal menu_requested

## Délai avant l'affichage : on voit la chute de l'opérateur ou l'arrivée du
## VIP.
const DELAY := 1.2

## Faux : la fin de mission ne s'affiche pas (tests de jeu, qui
## continuent après la mort d'un opérateur).
static var enabled: bool = true

var success: bool = false
var message: String = ""
var _title: Label
var _message: Label
var _restart: Button
var _was_paused: bool = false
## Déjà affiché une fois : un second événement de fin ne le rouvre pas.
var _shown: bool = false


func _ready() -> void:
	name = "EndScreen"
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	EventBus.mission_ended.connect(_on_mission_ended)
	EventBus.unit_died.connect(_on_unit_died)


func _on_unit_died(unit: Node3D) -> void:
	var commando := unit as Commando
	if commando:
		_on_mission_ended(false, "ÉCHEC — %s tué" % commando.display_name)


func _on_mission_ended(won: bool, text: String) -> void:
	if _shown or not enabled:
		return
	_shown = true
	success = won
	message = text
	await get_tree().create_timer(DELAY, true, false, true).timeout
	if is_inside_tree():
		show_result()


## Affiche le résultat (sans délai).
func show_result() -> void:
	_title.text = "MISSION RÉUSSIE" if success else "MISSION ÉCHOUÉE"
	_title.add_theme_color_override(&"font_color", Color(0.45, 0.9, 0.5) if success else Color(1.0, 0.35, 0.3))
	_message.text = message
	_was_paused = get_tree().paused
	get_tree().paused = true
	visible = true
	_restart.grab_focus()


func is_open() -> bool:
	return visible


## Referme l'écran : la partie continue.
func continue_playing() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = _was_paused


func _build() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.5)
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
	style.set_content_margin_all(28)
	panel.add_theme_stylebox_override(&"panel", style)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 14)
	column.custom_minimum_size = Vector2(420, 0)
	panel.add_child(column)
	_title = Label.new()
	_title.name = "Title"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override(&"font_size", 34)
	column.add_child(_title)
	_message = Label.new()
	_message.name = "Message"
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.add_theme_font_size_override(&"font_size", 18)
	column.add_child(_message)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override(&"separation", 10)
	column.add_child(buttons)
	_restart = Button.new()
	_restart.name = "Restart"
	_restart.text = "Recommencer"
	_restart.pressed.connect(func() -> void:
		visible = false
		restart_requested.emit())
	buttons.add_child(_restart)
	var keep := Button.new()
	keep.name = "Continue"
	keep.text = "Continuer à jouer"
	keep.pressed.connect(continue_playing)
	buttons.add_child(keep)
	var menu := Button.new()
	menu.name = "Menu"
	menu.text = "Menu principal"
	menu.pressed.connect(func() -> void:
		visible = false
		get_tree().paused = false
		menu_requested.emit())
	buttons.add_child(menu)
