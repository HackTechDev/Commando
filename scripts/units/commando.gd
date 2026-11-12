class_name Commando
extends CharacterBody3D
## Unité contrôlable par le joueur : déplacement par navigation et postures.

signal selected_changed(is_selected: bool)
signal posture_changed(posture: SoldierModel.Posture)

const MASK_OCCLUDERS := 0b10
## Évitement : en dessous de cette part de la vitesse voulue, l'unité est
## considérée comme bloquée et fait un pas de côté.
const BLOCKED_RATIO := 0.4
const SIDESTEP_RATIO := 0.7
const CLIMB_START_DISTANCE := 0.4
const CLIMB_REACH := 1.2
# Avancée et élévation du corps pendant l'escalade, par paires (instant,
# fraction du trajet), calées sur les images clés de `SoldierModel`.
const CLIMB_UP_FORWARD: Array[float] = [0.0, 0.0, 0.18, 0.28, 0.5, 0.33, 0.66, 0.55, 0.82, 0.8, 1.0, 1.0]
const CLIMB_UP_HEIGHT: Array[float] = [0.0, 0.0, 0.18, 0.0, 0.5, 0.28, 0.66, 0.75, 0.82, 1.0, 1.0, 1.0]
const CLIMB_DOWN_FORWARD: Array[float] = [0.0, 0.0, 0.25, 0.42, 0.6, 0.85, 0.8, 1.0, 1.0, 1.0]
const CLIMB_DOWN_HEIGHT: Array[float] = [0.0, 0.0, 0.25, 0.0, 0.6, 1.0, 1.0, 1.0]
const STUCK_PROGRESS := 0.05
const STUCK_DELAY := 0.6
const STUCK_GOAL_DISTANCE := 2.0

@export var stats: UnitStats
## Numéro de l'unité dans l'escouade (touches 1 à 6).
@export_range(1, 6) var unit_index: int = 1
@export var display_name: String = "Opérateur"

var is_selected: bool = false
var is_dead: bool = false
var posture: SoldierModel.Posture = SoldierModel.Posture.STANDING:
	set(value):
		if value != posture:
			posture = value
			posture_changed.emit(posture)
## Cartouches dans le chargeur engagé.
var ammo_in_magazine: int = 0
## Cartouches en réserve.
var ammo_reserve: int = 0
## Obstacle sur lequel l'unité se tient, le cas échéant.
var perched_on: Climbable

var _running: bool = false
var _has_order: bool = false
var _attack_target: Enemy
var _fire_cooldown: float = 0.0
var _reload_left: float = 0.0
var _climb_target: Climbable
var _climb_point: Vector3
var _hopping: bool = false
var _vertical_velocity: float = 0.0
var _wants_to_move: bool = false
var _desired_velocity: Vector3
var _stuck_time: float = 0.0
var _best_goal_distance: float = INF
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var _agent: NavigationAgent3D = $NavigationAgent3D
@onready var _model: SoldierModel = $SoldierModel
@onready var _ring: MeshInstance3D = $SelectionRing
@onready var health: HealthComponent = $HealthComponent


func _ready() -> void:
	health.reset(stats.max_health)
	ammo_in_magazine = stats.magazine_size
	ammo_reserve = stats.reserve_ammo
	health.health_changed.connect(_on_health_changed)
	health.died.connect(_on_died)
	_agent.velocity_computed.connect(_apply_velocity)


func _physics_process(delta: float) -> void:
	_update_reload(delta)
	if _hopping:
		return
	var horizontal := Vector3.ZERO
	if is_dead:
		pass
	elif _climb_target:
		horizontal = _approach_climb()
		if horizontal != Vector3.ZERO:
			_face(horizontal, delta)
	elif _attack_target:
		horizontal = _attack(delta)
	elif _has_order:
		if _agent.is_navigation_finished():
			_has_order = false
		else:
			horizontal = _follow_path(delta)

	_vertical_velocity = 0.0 if is_on_floor() else velocity.y - _gravity * delta
	_update_stuck(delta, horizontal)
	_wants_to_move = horizontal != Vector3.ZERO
	_desired_velocity = horizontal
	# Une unité à l'arrêt est prioritaire : ce sont les autres qui la contournent.
	_agent.avoidance_priority = 0.5 if _wants_to_move else 1.0
	if _agent.avoidance_enabled:
		# L'évitement renvoie une vitesse corrigée via `velocity_computed`.
		_agent.velocity = horizontal
	else:
		_apply_velocity(horizontal)


## Applique la vitesse horizontale (éventuellement corrigée par l'évitement).
func _apply_velocity(horizontal: Vector3) -> void:
	# Une unité à l'arrêt ne se laisse pas pousser par l'évitement.
	if not _wants_to_move:
		horizontal = Vector3.ZERO
	elif horizontal.length() < BLOCKED_RATIO * _desired_velocity.length():
		# Freiné presque à l'arrêt par une unité pile en face : pas de côté.
		horizontal += _desired_velocity.cross(Vector3.UP) * SIDESTEP_RATIO
	velocity = Vector3(horizontal.x, _vertical_velocity, horizontal.z)
	move_and_slide()
	_model.posture = posture
	_model.move_ratio = Vector2(velocity.x, velocity.z).length() / stats.walk_speed


## Abandonne un ordre de déplacement dont la destination est occupée par une
## autre unité : près du but et sans s'en rapprocher, on considère qu'on est arrivé.
func _update_stuck(delta: float, desired: Vector3) -> void:
	if not _has_order or desired == Vector3.ZERO:
		_stuck_time = 0.0
		_best_goal_distance = INF
		return
	var goal_distance := global_position.distance_to(_agent.target_position)
	if goal_distance < _best_goal_distance - STUCK_PROGRESS:
		_best_goal_distance = goal_distance
		_stuck_time = 0.0
	elif goal_distance < STUCK_GOAL_DISTANCE:
		_stuck_time += delta
		if _stuck_time > STUCK_DELAY:
			_has_order = false
			_stuck_time = 0.0
			_best_goal_distance = INF


## Ordonne un déplacement vers `target`. `run` n'a d'effet que debout.
func move_to(target: Vector3, run: bool) -> void:
	if is_dead or _hopping:
		return
	_climb_target = null
	if perched_on:
		_descend(target, move_to.bind(target, run))
		return
	_attack_target = null
	_running = run
	_has_order = true
	_best_goal_distance = INF
	_agent.target_position = target


## Ordonne d'attaquer `enemy` : l'unité s'approche jusqu'à avoir une ligne de
## tir, puis tire jusqu'à ce que la cible soit neutralisée.
func attack(enemy: Enemy, run: bool) -> void:
	if is_dead or _hopping or enemy == null or enemy.is_dead or not has_ammo():
		return
	_climb_target = null
	_has_order = false
	_running = run
	_attack_target = enemy
	_fire_cooldown = stats.aim_time


## Ordonne de grimper sur `target`. Renvoie faux si c'est impossible
## (déjà occupé, inaccessible, unité morte).
func climb(target: Climbable, run: bool) -> bool:
	if is_dead or _hopping or target == null:
		return false
	if perched_on == target:
		return true
	if target.occupant != null and target.occupant != self:
		return false
	if perched_on:
		var route := _route_across(perched_on, target)
		if not route.is_empty():
			_walk_across(route)
			return true
		if not _descend(target.global_position, climb.bind(target, run)):
			return false
		return true
	var access := target.get_nearest_access(global_position)
	if not access["found"]:
		return false
	_has_order = false
	_attack_target = null
	_running = run
	_climb_target = target
	_climb_point = access["point"]
	_agent.target_position = _climb_point
	return true


## Vrai s'il reste au moins une cartouche (chargeur ou réserve).
func has_ammo() -> bool:
	return ammo_in_magazine > 0 or ammo_reserve > 0


## Vrai pendant un rechargement.
func is_reloading() -> bool:
	return _reload_left > 0.0


## Lance un rechargement si le chargeur n'est pas plein et qu'il reste de la réserve.
func reload() -> void:
	if is_dead or is_reloading() or ammo_reserve <= 0 or ammo_in_magazine >= stats.magazine_size:
		return
	_reload_left = stats.reload_time
	EventBus.unit_ammo_changed.emit(self)


## Arrête le déplacement et l'attaque en cours.
func stop() -> void:
	_has_order = false
	_attack_target = null
	_climb_target = null


## Bascule entre `new_posture` et debout.
func toggle_posture(new_posture: SoldierModel.Posture) -> void:
	if is_dead:
		return
	posture = SoldierModel.Posture.STANDING if posture == new_posture else new_posture


## Met à jour l'état de sélection et l'anneau au sol.
func set_selected(value: bool) -> void:
	if is_selected == value or (value and is_dead):
		return
	is_selected = value
	_ring.visible = value
	selected_changed.emit(value)


## Rejoint le point d'accès de l'obstacle visé, puis grimpe.
func _approach_climb() -> Vector3:
	if _climb_target.occupant != null and _climb_target.occupant != self:
		_climb_target = null
		return Vector3.ZERO
	var offset := _climb_point - global_position
	offset.y = 0.0
	var distance := offset.length()
	var arrived := _agent.is_navigation_finished()
	if distance < CLIMB_START_DISTANCE or (arrived and distance < CLIMB_REACH):
		var target := _climb_target
		_climb_target = null
		target.occupant = self
		_hop(target.get_top_position(), func() -> void: perched_on = target)
		return Vector3.ZERO
	if arrived:
		_climb_target = null
		return Vector3.ZERO
	var to_next := _agent.get_next_path_position() - global_position
	to_next.y = 0.0
	if to_next.length_squared() < 0.0001:
		return Vector3.ZERO
	return to_next.normalized() * _current_speed()


## Redescend de l'obstacle du côté le plus proche de `toward`, puis appelle
## `then`. Renvoie faux s'il n'y a aucun côté praticable.
func _descend(toward: Vector3, then: Callable) -> bool:
	var access := perched_on.get_nearest_access(toward)
	if not access["found"]:
		return false
	var obstacle := perched_on
	perched_on = null
	_hop(access["point"], func() -> void:
		obstacle.occupant = null
		then.call())
	return true


## Suite d'obstacles voisins et libres menant de `from` à `to` sans toucher
## le sol (`from` exclu, `to` inclus) ; vide s'il n'y en a pas.
func _route_across(from: Climbable, to: Climbable) -> Array[Climbable]:
	var previous: Dictionary = {from: null}
	var queue: Array[Climbable] = [from]
	while not queue.is_empty():
		var current: Climbable = queue.pop_front()
		if current == to:
			var route: Array[Climbable] = []
			while current != from:
				route.push_front(current)
				current = previous[current]
			return route
		for node in get_tree().get_nodes_in_group(&"climbables"):
			var next := node as Climbable
			if next == null or previous.has(next) or not current.is_adjacent_to(next):
				continue
			if next.occupant != null and next.occupant != self:
				continue
			previous[next] = current
			queue.append(next)
	return []


## Passe à pied de l'obstacle occupé aux obstacles voisins de `route`, l'un
## après l'autre, sans redescendre.
func _walk_across(route: Array[Climbable]) -> void:
	var target: Climbable = route[0]
	_hopping = true
	_has_order = false
	_attack_target = null
	_climb_target = null
	velocity = Vector3.ZERO
	var origin := perched_on
	var from := global_position
	var to := target.get_top_position()
	var flat := to - from
	flat.y = 0.0
	if flat.length_squared() > 0.0001:
		rotation.y = atan2(-flat.x, -flat.z)
	perched_on = null
	target.occupant = self
	_running = false
	var speed := _current_speed()
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void:
		global_position = from.lerp(to, t)
		_model.move_ratio = speed / stats.walk_speed
	, 0.0, 1.0, from.distance_to(to) / speed)
	tween.tween_callback(func() -> void:
		_hopping = false
		_model.move_ratio = 0.0
		origin.occupant = null
		if is_dead:
			return
		perched_on = target
		# Étape suivante, si elle est toujours libre.
		var rest := route.slice(1)
		if not rest.is_empty() and (rest[0].occupant == null or rest[0].occupant == self):
			_walk_across(rest))


## Escalade scriptée (montée ou descente) : pendant sa durée, l'unité ne
## reçoit aucun ordre et n'est pas déplacée par la physique. Le corps suit des
## courbes calées sur l'animation du modèle (`SoldierModel.climb_progress`).
func _hop(to: Vector3, done: Callable) -> void:
	_hopping = true
	_has_order = false
	velocity = Vector3.ZERO
	posture = SoldierModel.Posture.STANDING
	var from := global_position
	var flat := to - from
	flat.y = 0.0
	if flat.length_squared() > 0.0001:
		rotation.y = atan2(-flat.x, -flat.z)
	var going_up := to.y > from.y
	var forward_keys := CLIMB_UP_FORWARD if going_up else CLIMB_DOWN_FORWARD
	var height_keys := CLIMB_UP_HEIGHT if going_up else CLIMB_DOWN_HEIGHT
	_model.climb_descending = not going_up
	_model.climb_progress = 0.0
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void:
		var forward := SoldierModel.sample_keys(forward_keys, t)
		var height := SoldierModel.sample_keys(height_keys, t)
		global_position = Vector3(lerpf(from.x, to.x, forward), lerpf(from.y, to.y, height), lerpf(from.z, to.z, forward))
		_model.climb_progress = t
	, 0.0, 1.0, stats.climb_time if going_up else stats.descend_time)
	tween.tween_callback(func() -> void:
		_hopping = false
		_model.climb_progress = -1.0
		if not is_dead:
			done.call())


func _update_reload(delta: float) -> void:
	if not is_reloading() or is_dead:
		return
	_reload_left -= delta
	if _reload_left <= 0.0:
		_reload_left = 0.0
		var loaded := mini(stats.magazine_size - ammo_in_magazine, ammo_reserve)
		ammo_in_magazine += loaded
		ammo_reserve -= loaded
		EventBus.unit_ammo_changed.emit(self)


func _follow_path(delta: float) -> Vector3:
	var to_next := _agent.get_next_path_position() - global_position
	to_next.y = 0.0
	if to_next.length_squared() < 0.0001:
		return Vector3.ZERO
	_face(to_next, delta)
	return to_next.normalized() * _current_speed()


func _face(direction: Vector3, delta: float) -> void:
	var target_yaw := atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-stats.turn_speed * delta))


func _attack(delta: float) -> Vector3:
	if not is_instance_valid(_attack_target) or _attack_target.is_dead:
		_attack_target = null
		return Vector3.ZERO
	if not has_ammo():
		_attack_target = null
		return Vector3.ZERO
	var to_target := _attack_target.global_position - global_position
	to_target.y = 0.0
	var distance := to_target.length()
	if distance <= stats.fire_range and _has_line_of_fire(_attack_target):
		if distance > 0.01:
			_face(to_target, delta)
		_fire_cooldown -= delta
		if ammo_in_magazine <= 0:
			reload()
		elif not is_reloading() and _fire_cooldown <= 0.0 and (-global_basis.z).angle_to(to_target) < 0.25:
			_fire(_attack_target, distance)
		return Vector3.ZERO
	# Pas de ligne de tir : s'approcher, puis viser de nouveau.
	_fire_cooldown = stats.aim_time
	if perched_on:
		_descend(_attack_target.global_position, func() -> void: pass)
		return Vector3.ZERO
	if _agent.target_position.distance_to(_attack_target.global_position) > 0.5:
		_agent.target_position = _attack_target.global_position
	if _agent.is_navigation_finished():
		return Vector3.ZERO
	return _follow_path(delta)


func _weapon_height() -> float:
	match posture:
		SoldierModel.Posture.CROUCHED:
			return 0.9
		SoldierModel.Posture.PRONE:
			return 0.3
	return 1.4


func _has_line_of_fire(enemy: Enemy) -> bool:
	var from := global_position + Vector3.UP * _weapon_height()
	var to := enemy.global_position + Vector3.UP * 1.2
	var query := PhysicsRayQueryParameters3D.create(from, to, MASK_OCCLUDERS)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _fire(enemy: Enemy, distance: float) -> void:
	_fire_cooldown = stats.fire_interval
	ammo_in_magazine -= 1
	EventBus.unit_ammo_changed.emit(self)
	var forward := -global_basis.z
	var muzzle := global_position + Vector3.UP * _weapon_height() + forward * 0.7
	var aim := enemy.global_position + Vector3.UP * 1.2
	var chance := lerpf(stats.hit_chance_near, stats.hit_chance_far, clampf(distance / stats.fire_range, 0.0, 1.0))
	var hit := randf() < chance
	if not hit:
		var side := global_basis.x * (0.5 + randf() * 0.5) * (1.0 if randf() < 0.5 else -1.0)
		aim += side + (aim - muzzle).normalized() * 4.0
	Tracer.spawn(get_tree().current_scene, muzzle, aim, Color(0.6, 0.9, 1.0))
	EventBus.noise_emitted.emit(global_position, stats.gunshot_noise_radius, &"gunshot")
	if hit:
		enemy.take_hit(stats.fire_damage, global_position)


func _current_speed() -> float:
	match posture:
		SoldierModel.Posture.CROUCHED:
			return stats.crouch_speed
		SoldierModel.Posture.PRONE:
			return stats.crawl_speed
	return stats.run_speed if _running else stats.walk_speed


func _on_health_changed(_current: float, _maximum: float) -> void:
	EventBus.unit_damaged.emit(self, health.max_health - health.health)


func _on_died() -> void:
	is_dead = true
	_has_order = false
	_attack_target = null
	_climb_target = null
	remove_from_group(&"commandos")
	collision_layer = 0
	_agent.avoidance_enabled = false
	_model.is_dead = true
	SelectionManager.remove(self)
	EventBus.unit_died.emit(self)
