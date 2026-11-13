class_name UnitPortrait
extends PanelContainer
## Portrait d'un opérateur dans le HUD : vie, posture, munitions, sélection.
## Clic : sélectionner (Maj : ajouter). Double clic : centrer la caméra.

const POSTURE_NAMES: Dictionary = {
	SoldierModel.Posture.STANDING: "Debout",
	SoldierModel.Posture.CROUCHED: "Accroupi",
	SoldierModel.Posture.PRONE: "Rampé",
}

@export var selected_border := Color(0.25, 0.65, 1.0)
@export var normal_border := Color(0.3, 0.34, 0.3, 0.9)
@export var healthy_color := Color(0.35, 0.8, 0.4)
@export var wounded_color := Color(0.9, 0.25, 0.2)

var _unit: Commando
var _style: StyleBoxFlat
var _fill: StyleBoxFlat

@onready var _number: Label = %Number
@onready var _name: Label = %Name
@onready var _health: ProgressBar = %Health
@onready var _health_text: Label = %HealthText
@onready var _status: Label = %Status
@onready var _ammo: Label = %Ammo
@onready var _no_knife: Label = %NoKnife


## Associe le portrait à une unité.
func setup(unit: Commando) -> void:
	_unit = unit
	_style = (get_theme_stylebox(&"panel") as StyleBoxFlat).duplicate()
	add_theme_stylebox_override(&"panel", _style)
	_fill = (_health.get_theme_stylebox(&"fill") as StyleBoxFlat).duplicate()
	_health.add_theme_stylebox_override(&"fill", _fill)
	_number.text = str(unit.unit_index)
	_name.text = unit.display_name
	unit.selected_changed.connect(func(_selected: bool) -> void: _refresh())
	unit.posture_changed.connect(func(_posture: SoldierModel.Posture) -> void: _refresh())
	EventBus.unit_damaged.connect(_on_unit_event.unbind(1))
	EventBus.unit_ammo_changed.connect(_on_unit_event)
	EventBus.unit_died.connect(_on_unit_event)
	_refresh()


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null or not button.pressed or button.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	if _unit.is_dead:
		return
	SelectionManager.select([_unit] as Array[Commando], Input.is_action_pressed(&"select_additive"))
	if button.double_click:
		var rig := get_viewport().get_camera_3d().get_parent() as CameraRig
		if rig:
			rig.focus_on(_unit.global_position)


func _on_unit_event(unit: Node3D) -> void:
	if unit == _unit:
		_refresh()


func _refresh() -> void:
	var ratio := _unit.health.health / _unit.health.max_health
	_health.value = ratio * 100.0
	_health_text.text = "%d PV" % roundi(_unit.health.health)
	_fill.bg_color = wounded_color.lerp(healthy_color, ratio)
	_style.border_color = selected_border if _unit.is_selected else normal_border
	if _unit.is_dead:
		_status.text = "Mort"
		_ammo.text = ""
		_no_knife.visible = false
		modulate = Color(1.0, 1.0, 1.0, 0.45)
		return
	_status.text = POSTURE_NAMES[_unit.posture]
	if _unit.is_reloading():
		_ammo.text = "Rechargement…"
	elif not _unit.has_ammo():
		_ammo.text = "À sec"
	else:
		_ammo.text = "%d / %d" % [_unit.ammo_in_magazine, _unit.ammo_reserve]
	# Couteau de lancer : rappel discret tant qu'il n'est pas ramassé.
	_no_knife.visible = _unit.throwing_knives < _unit.stats.throwing_knives
	_ammo.modulate = wounded_color if _unit.ammo_in_magazine == 0 else Color.WHITE
