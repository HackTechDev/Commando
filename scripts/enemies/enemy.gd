class_name Enemy
extends CharacterBody3D
## Soldat ennemi : patrouille, détection progressive et alerte.
##
## Machine à états minimale (jalon M3) :
## - PATROL : suit les points du `patrol_path` avec une pause à chacun
##   (ou garde son poste s'il n'a pas de chemin) ;
## - SUSPICIOUS : la jauge de détection monte, il s'arrête et regarde la cible ;
## - ALERT : cible repérée, il lui fait face tant qu'il s'en souvient.

enum State { PATROL, SUSPICIOUS, ALERT }

signal state_changed(state: State)

@export var stats: EnemyStats
## Chemin de patrouille (points de la courbe), parcouru en boucle.
@export var patrol_path: Path3D

var state: State = State.PATROL
## Jauge de détection, de 0 (rien vu) à 1 (repéré).
var detection: float = 0.0

var _waypoints: Array[Vector3] = []
var _waypoint_index: int = 0
var _pause_left: float = 0.0
var _target: Commando
var _last_seen: Vector3
var _memory_left: float = 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var _agent: NavigationAgent3D = $NavigationAgent3D
@onready var _model: SoldierModel = $SoldierModel
@onready var _vision: VisionComponent = $VisionComponent
@onready var _gauge: Node3D = $Gauge
@onready var _gauge_fill: MeshInstance3D = $Gauge/Fill
@onready var _mark: Label3D = $Gauge/Mark


func _ready() -> void:
	if patrol_path and patrol_path.curve:
		for i in patrol_path.curve.point_count:
			_waypoints.append(patrol_path.to_global(patrol_path.curve.get_point_position(i)))
	if not _waypoints.is_empty():
		_agent.target_position = _waypoints[0]
	_update_feedback()


func _physics_process(delta: float) -> void:
	_update_detection(delta)
	_update_state()

	var horizontal := Vector3.ZERO
	match state:
		State.PATROL:
			horizontal = _patrol(delta)
		State.SUSPICIOUS, State.ALERT:
			_face(_last_seen - global_position, delta)

	velocity.x = horizontal.x
	velocity.z = horizontal.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - _gravity * delta
	move_and_slide()
	_model.move_ratio = Vector2(velocity.x, velocity.z).length() / stats.patrol_speed * 0.6
	_update_feedback()


func _update_detection(delta: float) -> void:
	var best_zone := VisionComponent.Zone.NONE
	var best_distance := INF
	_target = null
	for node in get_tree().get_nodes_in_group(&"commandos"):
		var commando := node as Commando
		if commando == null:
			continue
		var zone := _vision.check(commando)
		if zone == VisionComponent.Zone.NONE:
			continue
		var distance := global_position.distance_to(commando.global_position)
		if distance < best_distance:
			best_distance = distance
			best_zone = zone
			_target = commando

	if _target:
		_last_seen = _target.global_position
		_memory_left = stats.alert_memory
		if best_zone == VisionComponent.Zone.NEAR:
			detection = 1.0
		else:
			var config := _vision.config
			var closeness := 1.0 - inverse_lerp(config.near_range, config.far_range, best_distance)
			detection += delta / stats.detection_time * lerpf(0.6, 1.6, closeness)
	elif state == State.ALERT:
		_memory_left -= delta
		if _memory_left <= 0.0:
			detection = 0.0
	else:
		detection -= delta / stats.forget_time
	detection = clampf(detection, 0.0, 1.0)


func _update_state() -> void:
	var new_state := State.PATROL
	if detection >= 1.0:
		new_state = State.ALERT
	elif state == State.ALERT and detection > 0.0:
		new_state = State.ALERT
	elif detection >= stats.suspicion_threshold or (state == State.SUSPICIOUS and detection > 0.0):
		new_state = State.SUSPICIOUS
	if new_state == state:
		return
	state = new_state
	if state == State.ALERT and _target:
		EventBus.unit_spotted.emit(_target, self)
	elif state == State.PATROL and not _waypoints.is_empty():
		_agent.target_position = _waypoints[_waypoint_index]
	state_changed.emit(state)
	GameState.refresh_alert()


func _patrol(delta: float) -> Vector3:
	if _waypoints.is_empty():
		return Vector3.ZERO
	if _pause_left > 0.0:
		_pause_left -= delta
		if _pause_left <= 0.0:
			_waypoint_index = (_waypoint_index + 1) % _waypoints.size()
			_agent.target_position = _waypoints[_waypoint_index]
		return Vector3.ZERO
	if _agent.is_navigation_finished():
		_pause_left = maxf(stats.patrol_pause, 0.01)
		return Vector3.ZERO
	var to_next := _agent.get_next_path_position() - global_position
	to_next.y = 0.0
	if to_next.length_squared() < 0.0001:
		return Vector3.ZERO
	_face(to_next, delta)
	return to_next.normalized() * stats.patrol_speed


func _face(direction: Vector3, delta: float) -> void:
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return
	var target_yaw := atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-stats.turn_speed * delta))


func _update_feedback() -> void:
	var color := _vision.calm_color
	if state == State.ALERT:
		color = _vision.alert_color
	elif state == State.SUSPICIOUS:
		color = _vision.suspicious_color
	_vision.set_cone_color(color)
	_gauge.visible = detection > 0.0
	_gauge_fill.scale.x = maxf(detection, 0.001)
	var material := _gauge_fill.material_override as StandardMaterial3D
	material.albedo_color = _vision.suspicious_color.lerp(_vision.alert_color, detection)
	_mark.text = "!" if state == State.ALERT else "?"
	_mark.modulate = color
