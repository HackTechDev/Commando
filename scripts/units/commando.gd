class_name Commando
extends CharacterBody3D
## Unité contrôlable par le joueur : déplacement par navigation et postures.

signal selected_changed(is_selected: bool)

@export var stats: UnitStats
## Numéro de l'unité dans l'escouade (touches 1 à 6).
@export_range(1, 6) var unit_index: int = 1
@export var display_name: String = "Opérateur"

var is_selected: bool = false
var posture: SoldierModel.Posture = SoldierModel.Posture.STANDING

var _running: bool = false
var _has_order: bool = false
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var _agent: NavigationAgent3D = $NavigationAgent3D
@onready var _model: SoldierModel = $SoldierModel
@onready var _ring: MeshInstance3D = $SelectionRing


func _physics_process(delta: float) -> void:
	var horizontal := Vector3.ZERO
	if _has_order:
		if _agent.is_navigation_finished():
			_has_order = false
		else:
			var to_next := _agent.get_next_path_position() - global_position
			to_next.y = 0.0
			if to_next.length_squared() > 0.0001:
				var direction := to_next.normalized()
				horizontal = direction * _current_speed()
				var target_yaw := atan2(-direction.x, -direction.z)
				rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-stats.turn_speed * delta))

	velocity.x = horizontal.x
	velocity.z = horizontal.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - _gravity * delta
	move_and_slide()

	_model.posture = posture
	_model.move_ratio = Vector2(velocity.x, velocity.z).length() / stats.walk_speed


## Ordonne un déplacement vers `target`. `run` n'a d'effet que debout.
func move_to(target: Vector3, run: bool) -> void:
	_running = run
	_has_order = true
	_agent.target_position = target


## Arrête le déplacement en cours.
func stop() -> void:
	_has_order = false


## Bascule entre `new_posture` et debout.
func toggle_posture(new_posture: SoldierModel.Posture) -> void:
	posture = SoldierModel.Posture.STANDING if posture == new_posture else new_posture


## Met à jour l'état de sélection et l'anneau au sol.
func set_selected(value: bool) -> void:
	if is_selected == value:
		return
	is_selected = value
	_ring.visible = value
	selected_changed.emit(value)


func _current_speed() -> float:
	match posture:
		SoldierModel.Posture.CROUCHED:
			return stats.crouch_speed
		SoldierModel.Posture.PRONE:
			return stats.crawl_speed
	return stats.run_speed if _running else stats.walk_speed
