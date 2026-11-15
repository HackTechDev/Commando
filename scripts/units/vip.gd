class_name Vip
extends Unit
## Personnage non joueur à protéger (VIP, otage) : il ne reçoit pas d'ordres,
## il suit un opérateur.
##
## - Ralliement : un opérateur vivant à moins de `rally_range` et en vue
##   devient son guide. Il le garde tant qu'il ne s'éloigne pas au-delà de
##   `lose_range` ; sinon il attend sur place qu'un opérateur revienne.
## - Suite : il se tient à `follow_distance` derrière son guide et prend sa
##   posture (accroupi, couché) pour rester aussi discret que lui. Il court si
##   son guide court ou s'il est distancé.
## - Seul, l'alarme donnée : il s'accroupit.
## - Les ennemis le repèrent, lui tirent dessus et le frappent comme un
##   opérateur (`Unit`). Arrivé dans une zone d'extraction (`ExtractionZone`),
##   il y reste, à l'abri.

## Le VIP est entré dans une zone d'extraction.
signal evacuated
## Le VIP a été tué.
signal killed
## Nouveau guide (null : il attend seul).
signal leader_changed(leader: Commando)

const MASK_OCCLUDERS := 0b10
## Distance de son guide au-delà de laquelle il court pour le rattraper.
const CATCH_UP_DISTANCE := 4.0
## Déplacement du guide (m) qui relance le calcul du chemin.
const RETARGET_DISTANCE := 0.5

@export var stats: UnitStats
@export var display_name: String = "VIP"
## Un opérateur plus proche que cette distance, et en vue, le prend en charge.
@export var rally_range: float = 6.0
## Au-delà de cette distance, il perd son guide et l'attend.
@export var lose_range: float = 14.0
## Distance à laquelle il suit son guide.
@export var follow_distance: float = 1.8
## Tenue (couleurs, visage) ; le modèle est celui d'un civil, sans arme.
@export var top_color := Color(0.12, 0.13, 0.17)
@export var pants_color := Color(0.11, 0.12, 0.15)
@export var skin: int = 1
@export var hair_color: int = 2

var leader: Commando
var is_evacuated: bool = false

var _running: bool = false
## Point où il se met à l'abri une fois évacué.
var _shelter: Vector3 = Vector3.INF
var _last_health: float = INF
var _vertical_velocity: float = 0.0
var _wants_to_move: bool = false
var _desired_velocity: Vector3
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _walker := PathWalker.new()

@onready var _agent: NavigationAgent3D = $NavigationAgent3D


func _ready() -> void:
	_model.outfit = civilian_outfit()
	_model.set_armed(false)
	health.reset(stats.max_health)
	_last_health = health.health
	health.health_changed.connect(_on_health_changed)
	health.died.connect(_on_died)
	_agent.velocity_computed.connect(_apply_velocity)


## Tenue civile : costume, tête nue, sans aucun équipement militaire.
func civilian_outfit() -> OperatorProfile:
	var outfit := OperatorProfile.new()
	outfit.name = display_name
	outfit.top_color = top_color
	outfit.pants_color = pants_color
	outfit.skin = skin
	outfit.hair_color = hair_color
	outfit.hair_style = &"short"
	outfit.headwear = &"none"
	for accessory: String in ["balaclava", "nvg", "headset", "vest", "backpack", "radio", "knee_pads"]:
		outfit.set(accessory, false)
	outfit.secondary = &"none"
	outfit.throwing_knives = 0
	return outfit


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	var horizontal := Vector3.ZERO
	if is_evacuated:
		horizontal = _go_to(_shelter, false, delta)
		posture = SoldierModel.Posture.STANDING
	else:
		_update_leader()
		horizontal = _follow(delta)
	_model.look_target = leader.global_position + Vector3.UP * 1.5 if leader else Vector3.INF
	if _model.is_changing_posture():
		horizontal = Vector3.ZERO
	_vertical_velocity = 0.0 if is_on_floor() else velocity.y - _gravity * delta
	_wants_to_move = horizontal != Vector3.ZERO
	_desired_velocity = horizontal
	_agent.avoidance_priority = 0.5 if _wants_to_move else 1.0
	if _agent.avoidance_enabled:
		_agent.velocity = horizontal
	else:
		_apply_velocity(horizontal)


## Garde son guide tant qu'il est vivant et assez proche, sinon se rallie à
## l'opérateur en vue le plus proche.
func _update_leader() -> void:
	if leader and (not is_instance_valid(leader) or leader.is_dead or _flat_distance(leader) > lose_range):
		_set_leader(null)
	if leader:
		return
	var best: Commando = null
	var best_distance := rally_range
	for node in get_tree().get_nodes_in_group(&"commandos"):
		var unit := node as Commando
		if unit == null or unit.is_dead:
			continue
		var distance := _flat_distance(unit)
		if distance <= best_distance and _sees(unit):
			best = unit
			best_distance = distance
	_set_leader(best)


func _set_leader(unit: Commando) -> void:
	if unit == leader:
		return
	leader = unit
	leader_changed.emit(leader)


func _follow(delta: float) -> Vector3:
	if leader == null:
		_running = false
		# Seul pendant l'alarme : il se fait petit.
		if GameState.alert_level == GameState.AlertLevel.ALARM and posture == SoldierModel.Posture.STANDING:
			posture = SoldierModel.Posture.CROUCHED
		return Vector3.ZERO
	posture = leader.posture
	var distance := _flat_distance(leader)
	if distance <= follow_distance:
		_running = false
		_face(leader.global_position - global_position, delta)
		return Vector3.ZERO
	var leader_speed := Vector2(leader.velocity.x, leader.velocity.z).length()
	var run := leader_speed > leader.stats.walk_speed * 1.1 or distance > CATCH_UP_DISTANCE
	return _go_to(leader.global_position, run, delta)


## Vitesse pour se rapprocher de `target` par la navigation.
func _go_to(target: Vector3, run: bool, delta: float) -> Vector3:
	if target == Vector3.INF:
		return Vector3.ZERO
	if _agent.target_position.distance_to(target) > RETARGET_DISTANCE:
		_agent.target_position = target
	if _agent.is_navigation_finished():
		return Vector3.ZERO
	var to_next := _walker.next_point(_agent, self, get_physics_process_delta_time()) - global_position
	to_next.y = 0.0
	if to_next.length_squared() < 0.0001:
		return Vector3.ZERO
	_running = run
	_face(to_next, delta)
	return to_next.normalized() * _current_speed()


## Entre dans la zone d'extraction : il s'abrite en `shelter` et n'en bouge plus.
func evacuate(shelter: Vector3) -> void:
	if is_dead or is_evacuated:
		return
	is_evacuated = true
	_shelter = shelter
	_set_leader(null)
	# À l'abri : les ennemis ne le prennent plus pour cible.
	remove_from_group(&"vips")
	evacuated.emit()


func _apply_velocity(horizontal: Vector3) -> void:
	if is_dead:
		return
	if not _wants_to_move:
		horizontal = Vector3.ZERO
	velocity = Vector3(horizontal.x, _vertical_velocity, horizontal.z)
	var before := global_position
	move_and_slide()
	var wanted := horizontal * get_physics_process_delta_time()
	var moved := global_position - before
	var climbed := 0.0
	if Vector2(moved.x, moved.z).length() < 0.5 * Vector2(wanted.x, wanted.z).length():
		climbed = PathWalker.step_up(self, wanted)
	PathWalker.smooth_model(_model, climbed, get_physics_process_delta_time())
	_model.move_ratio = Vector2(velocity.x, velocity.z).length() / stats.walk_speed


func _current_speed() -> float:
	match posture:
		SoldierModel.Posture.CROUCHED:
			return stats.crouch_speed
		SoldierModel.Posture.PRONE:
			return stats.crawl_speed
	return stats.run_speed if _running else stats.walk_speed


func _face(direction: Vector3, delta: float) -> void:
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return
	rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), 1.0 - exp(-stats.turn_speed * delta))


func _sees(unit: Node3D) -> bool:
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.5, unit.global_position + Vector3.UP * 1.2, MASK_OCCLUDERS)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _flat_distance(unit: Node3D) -> float:
	return Vector2(unit.global_position.x - global_position.x, unit.global_position.z - global_position.z).length()


func _on_health_changed(current: float, _maximum: float) -> void:
	if current < _last_health and current > 0.0:
		_model.play_hit()
		Sfx.play_at(&"hit", global_position + Vector3.UP, -4.0)
	_last_health = current


func _on_died() -> void:
	is_dead = true
	Sfx.play_at(&"fall", global_position, -2.0)
	_set_leader(null)
	remove_from_group(&"vips")
	collision_layer = 0
	velocity = Vector3.ZERO
	_agent.avoidance_enabled = false
	_model.is_dead = true
	_model.move_ratio = 0.0
	$Marker.visible = false
	killed.emit()
