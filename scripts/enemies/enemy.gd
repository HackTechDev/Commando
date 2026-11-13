class_name Enemy
extends CharacterBody3D
## Soldat ennemi : patrouille, détection progressive et alerte.
##
## Machine à états minimale (jalon M3) :
## - PATROL : suit les points du `patrol_path` avec une pause à chacun
##   (ou garde son poste s'il n'a pas de chemin) ;
## - SUSPICIOUS : la jauge de détection monte, il s'arrête et regarde la cible ;
## - ALERT : cible repérée. Il la poursuit jusqu'à portée de tir et tire tant
##   qu'il la voit ; s'il la perd, il court à sa dernière position connue,
##   y attend `alert_memory` secondes, puis reprend sa patrouille ;
## - STUNNED : assommé, au sol, aveugle, pendant `stun_duration` secondes. Au
##   réveil, il passe en alerte sur place, puis reprend sa patrouille ;
##   au contact de sa cible, il frappe au lieu de tirer ; un coup paré ou
##   esquivé le déséquilibre un instant ;
## - GRABBED : saisi par derrière (étranglement, égorgement), immobile et
##   sans réaction ; relâché, il passe en alerte.

enum State { PATROL, SUSPICIOUS, ALERT, STUNNED, GRABBED }

signal state_changed(state: State)

@export var stats: EnemyStats
## Chemin de patrouille (points de la courbe), parcouru en boucle.
@export var patrol_path: Path3D
## Porte une arme et tire en alerte. Sans arme, il se contente de regarder.
@export var armed: bool = true
## Ne se déplace jamais, même en alerte (sentinelle, cible d'entraînement).
@export var stationary: bool = false

## Évitement : en dessous de cette part de la vitesse voulue, l'unité est
## considérée comme bloquée et fait un pas de côté.
const BLOCKED_RATIO := 0.4
const SIDESTEP_RATIO := 0.7
## Couche physique d'un ennemi actif (« Ennemis ») et d'un ennemi assommé
## (« Interactables ») : assommé, il ne bloque plus le passage mais reste ciblable.
const LAYER_ACTIVE := 0b1000
const LAYER_DOWN := 0b10000
## Au-delà de cet angle (degrés) entre son regard et la direction d'une
## position, celle-ci est considérée comme dans son dos.
const BEHIND_ANGLE := 110.0
const GAUGE_HEIGHT := 2.3
const GAUGE_HEIGHT_DOWN := 1.0

var state: State = State.PATROL
var is_dead: bool = false
## Jauge de détection, de 0 (rien vu) à 1 (repéré).
var detection: float = 0.0

var _waypoints: Array[Vector3] = []
var _waypoint_index: int = 0
var _pause_left: float = 0.0
var _target: Commando
var _last_seen: Vector3
var _memory_left: float = 0.0
var _chase_arrived: bool = false
var _fire_cooldown: float = 0.0
var _stun_left: float = 0.0
var _shove_left: float = 0.0
var _shove_target: Commando
## Coup au corps à corps en cours (temps restant, cible, impact joué).
var _attack_left: float = 0.0
var _attack_target: Commando
var _attack_landed: bool = false
var _melee_cooldown: float = 0.0
var _off_balance_left: float = 0.0
var _vertical_velocity: float = 0.0
var _wants_to_move: bool = false
var _desired_velocity: Vector3
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var _agent: NavigationAgent3D = $NavigationAgent3D
@onready var _model: SoldierModel = $SoldierModel
@onready var _vision: VisionComponent = $VisionComponent
@onready var _gauge: Node3D = $Gauge
@onready var _gauge_back: MeshInstance3D = $Gauge/Back
@onready var _gauge_fill: MeshInstance3D = $Gauge/Fill
@onready var _mark: Label3D = $Gauge/Mark
@onready var health: HealthComponent = $HealthComponent


func _ready() -> void:
	health.reset(stats.max_health)
	health.died.connect(_on_died)
	_model.set_armed(armed)
	_agent.velocity_computed.connect(_apply_velocity)
	if patrol_path and patrol_path.curve:
		for i in patrol_path.curve.point_count:
			_waypoints.append(patrol_path.to_global(patrol_path.curve.get_point_position(i)))
	if not _waypoints.is_empty():
		_agent.target_position = _waypoints[0]
	_update_feedback()


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if state == State.STUNNED:
		_stun_left -= delta
		if _stun_left <= 0.0:
			_wake_up()
		return
	if state == State.GRABBED:
		velocity = Vector3.ZERO
		return
	_update_detection(delta)
	_update_state()
	_model.aiming = armed and state == State.ALERT and _target != null

	var horizontal := Vector3.ZERO
	_melee_cooldown -= delta
	_off_balance_left = maxf(_off_balance_left - delta, 0.0)
	_model.staggered = _off_balance_left > 0.0
	if _shove_left > 0.0:
		_update_shove(delta)
	elif _attack_left > 0.0:
		_update_attack(delta)
	elif _off_balance_left > 0.0:
		pass
	else:
		match state:
			State.PATROL:
				horizontal = _patrol(delta)
			State.SUSPICIOUS:
				_face(_last_seen - global_position, delta)
			State.ALERT:
				horizontal = _alert(delta)
	if stationary:
		horizontal = Vector3.ZERO

	_vertical_velocity = 0.0 if is_on_floor() else velocity.y - _gravity * delta
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
	if is_dead:
		return
	# Une unité à l'arrêt ne se laisse pas pousser par l'évitement.
	if not _wants_to_move:
		horizontal = Vector3.ZERO
	elif horizontal.length() < BLOCKED_RATIO * _desired_velocity.length():
		# Freiné presque à l'arrêt par une unité pile en face : pas de côté.
		horizontal += _desired_velocity.cross(Vector3.UP) * SIDESTEP_RATIO
	velocity = Vector3(horizontal.x, _vertical_velocity, horizontal.z)
	move_and_slide()
	var speed := Vector2(velocity.x, velocity.z).length()
	_model.move_ratio = 2.0 * speed / stats.chase_speed if state == State.ALERT else 0.6 * speed / stats.patrol_speed
	_update_feedback()


## Encaisse un tir venant de `from` : dégâts, puis alerte vers le tireur.
func take_hit(amount: float, from: Vector3) -> void:
	if is_dead:
		return
	health.take_damage(amount)
	if not is_dead:
		_model.play_hit(from)
	# Un soldat inconscient ne réagit pas.
	if is_dead or state == State.STUNNED:
		return
	detection = 1.0
	if _target == null:
		_last_seen = from
		_memory_left = stats.alert_memory
		_chase_arrived = false


## Vrai si l'ennemi est assommé.
func is_stunned() -> bool:
	return state == State.STUNNED


## Vrai si `world_position` est dans son dos.
func is_behind(world_position: Vector3) -> bool:
	var to := world_position - global_position
	to.y = 0.0
	if to.length_squared() < 0.0001:
		return false
	return rad_to_deg((-global_basis.z).angle_to(to)) > BEHIND_ANGLE


## Vrai s'il repousse un assaillant venant de `from` : en alerte, il le voit
## arriver de face et le coup échoue.
func resists(from: Vector3) -> bool:
	if is_dead or state != State.ALERT or _off_balance_left > 0.0:
		return false
	var to := from - global_position
	to.y = 0.0
	if to.length_squared() < 0.0001:
		return true
	return rad_to_deg((-global_basis.z).angle_to(to)) < stats.resist_angle


## Repousse `attacker` (animation de poussée), puis reprend le combat.
func shove(attacker: Commando) -> void:
	if is_dead or state == State.STUNNED or state == State.GRABBED:
		return
	_shove_left = stats.shove_time
	_shove_target = attacker
	detection = 1.0
	_last_seen = attacker.global_position
	_memory_left = stats.alert_memory
	_fire_cooldown = maxf(_fire_cooldown, stats.shove_time + 0.2)


func _update_shove(delta: float) -> void:
	_shove_left = maxf(_shove_left - delta, 0.0)
	_model.shove_progress = 1.0 - _shove_left / stats.shove_time
	if is_instance_valid(_shove_target):
		_face(_shove_target.global_position - global_position, delta)
	if _shove_left <= 0.0:
		_model.shove_progress = -1.0
		_shove_target = null


## Vrai pendant qu'il porte un coup au corps à corps.
func is_attacking() -> bool:
	return _attack_left > 0.0


## Vrai pendant le déséquilibre qui suit un coup paré ou esquivé.
func is_off_balance() -> bool:
	return _off_balance_left > 0.0


func _try_melee(to_target: Vector3) -> void:
	if _melee_cooldown > 0.0 or (-global_basis.z).angle_to(to_target) > 0.5:
		return
	_attack_left = stats.melee_time
	_attack_target = _target
	_attack_landed = false
	_melee_cooldown = stats.melee_time + stats.melee_interval
	_model.strike_with_knife = false
	_model.strike_move = SoldierModel.StrikeMove.BUTT_STRIKE if armed else SoldierModel.StrikeMove.UPPERCUT
	_model.strike_progress = 0.0


func _update_attack(delta: float) -> void:
	_attack_left = maxf(_attack_left - delta, 0.0)
	var progress := 1.0 - _attack_left / stats.melee_time
	_model.strike_progress = progress
	var valid := is_instance_valid(_attack_target) and not _attack_target.is_dead
	if valid:
		_face(_attack_target.global_position - global_position, delta)
	if not _attack_landed and progress >= Commando.STRIKE_HIT_TIME:
		_attack_landed = true
		if valid:
			var offset := _attack_target.global_position - global_position
			offset.y = 0.0
			if offset.length() <= stats.melee_range + Commando.STRIKE_REACH_MARGIN and _attack_target.defend_against(self):
				# Paré ou esquivé : emporté par son élan, il perd l'équilibre.
				_off_balance_left = stats.off_balance_time
	if _attack_left <= 0.0:
		_model.strike_progress = -1.0
		_attack_target = null


## Interrompt une action de corps à corps en cours (poussée, coup, déséquilibre).
func _cancel_melee() -> void:
	_shove_left = 0.0
	_shove_target = null
	_model.shove_progress = -1.0
	_attack_left = 0.0
	_attack_target = null
	_model.strike_progress = -1.0
	_off_balance_left = 0.0
	_model.staggered = false


## Saisi par derrière : immobile, aveugle, il se débat (animation).
func grab() -> void:
	if is_dead or state == State.STUNNED or state == State.GRABBED:
		return
	_cancel_melee()
	state = State.GRABBED
	_target = null
	velocity = Vector3.ZERO
	_agent.avoidance_enabled = false
	_model.grabbed = true
	_model.move_ratio = 0.0
	_vision.visible = false
	_vision.set_physics_process(false)
	_gauge.visible = false
	state_changed.emit(state)
	GameState.refresh_alert()


## Relâché avant d'être neutralisé (l'opérateur a été tué) : il donne l'alerte.
func release() -> void:
	if is_dead or state != State.GRABBED:
		return
	_model.grabbed = false
	_agent.avoidance_enabled = true
	_vision.visible = true
	_vision.set_physics_process(true)
	state = State.PATROL
	detection = 1.0
	_last_seen = global_position
	_memory_left = stats.alert_memory
	_update_state()
	_update_feedback()


## Élimination silencieuse (couteau) : mort immédiate, sans alerte.
## `fall_forward` : il s'effondre vers l'avant (attaqué par derrière).
func kill_silently(fall_forward: bool = false) -> void:
	if is_dead:
		return
	_model.grabbed = false
	_model.death_forward = fall_forward
	health.take_damage(health.health)


## Assomme l'ennemi : il tombe et reste inconscient `stun_duration` secondes.
## Assommer un ennemi déjà inconscient prolonge sa perte de connaissance.
func knock_out(fall_forward: bool = false) -> void:
	if is_dead:
		return
	_stun_left = stats.stun_duration
	if state == State.STUNNED:
		return
	_model.grabbed = false
	_model.death_forward = fall_forward
	_cancel_melee()
	state = State.STUNNED
	detection = 0.0
	_target = null
	velocity = Vector3.ZERO
	collision_layer = LAYER_DOWN
	_agent.avoidance_enabled = false
	_model.is_dead = true
	_model.move_ratio = 0.0
	_vision.visible = false
	_vision.set_physics_process(false)
	_update_feedback()
	state_changed.emit(state)
	GameState.refresh_alert()


## Fin de la perte de connaissance : il se relève et donne l'alerte sur place.
func _wake_up() -> void:
	collision_layer = LAYER_ACTIVE
	_agent.avoidance_enabled = true
	_model.is_dead = false
	_vision.visible = true
	_vision.set_physics_process(true)
	state = State.PATROL
	detection = 1.0
	_last_seen = global_position
	_memory_left = stats.alert_memory
	_update_state()
	_update_feedback()


func _on_died() -> void:
	is_dead = true
	_cancel_melee()
	state = State.PATROL
	detection = 0.0
	velocity = Vector3.ZERO
	remove_from_group(&"enemies")
	collision_layer = 0
	_agent.avoidance_enabled = false
	_model.is_dead = true
	_model.move_ratio = 0.0
	_vision.visible = false
	_vision.set_physics_process(false)
	_gauge.visible = false
	EventBus.enemy_killed.emit(self)
	GameState.refresh_alert()


func _update_detection(delta: float) -> void:
	var best_zone := VisionComponent.Zone.NONE
	var best_distance := INF
	_target = null
	for node in get_tree().get_nodes_in_group(&"commandos"):
		var commando := node as Commando
		if commando == null:
			continue
		var zone := _vision.check(commando, state == State.ALERT)
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
		# Le compte à rebours ne démarre qu'une fois le dernier point connu atteint.
		if _chase_arrived:
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
	if state == State.ALERT:
		_fire_cooldown = stats.aim_time
		_chase_arrived = false
		if _target:
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


## Comportement en alerte : tirer si la cible est visible, sinon la traquer.
func _alert(delta: float) -> Vector3:
	var to_target := _last_seen - global_position
	to_target.y = 0.0
	if _target:
		_chase_arrived = false
		_face(to_target, delta)
		if to_target.length() <= stats.melee_range:
			# Au contact : il frappe au lieu de tirer.
			_try_melee(to_target)
			return Vector3.ZERO
		_try_fire(delta, to_target)
		# Sans arme, il vient au contact.
		if to_target.length() <= (stats.hold_range if armed else stats.melee_range * 0.8):
			return Vector3.ZERO
	if _agent.target_position.distance_to(_last_seen) > 0.5:
		_agent.target_position = _last_seen
	if _agent.is_navigation_finished():
		_chase_arrived = _target == null
		return Vector3.ZERO
	var to_next := _agent.get_next_path_position() - global_position
	to_next.y = 0.0
	if to_next.length_squared() < 0.0001:
		return Vector3.ZERO
	if _target == null:
		_face(to_next, delta)
	return to_next.normalized() * stats.chase_speed


func _try_fire(delta: float, to_target: Vector3) -> void:
	if not armed:
		return
	_fire_cooldown -= delta
	var distance := to_target.length()
	if _fire_cooldown > 0.0 or distance > stats.fire_range:
		return
	# Ne tire que s'il est à peu près dans l'axe.
	var forward := -global_basis.z
	if distance > 0.01 and forward.angle_to(to_target) > 0.3:
		return
	_fire_cooldown = stats.fire_interval

	var chance := lerpf(stats.hit_chance_near, stats.hit_chance_far, clampf(distance / stats.fire_range, 0.0, 1.0))
	match _target.posture:
		SoldierModel.Posture.CROUCHED:
			chance *= 0.8
		SoldierModel.Posture.PRONE:
			chance *= 0.6
	var muzzle := global_position + Vector3.UP * 1.3 + forward * 0.7
	var aim := _target.global_position + Vector3.UP * (0.3 if _target.posture == SoldierModel.Posture.PRONE else 1.0)
	var hit := randf() < chance
	if not hit:
		var side := global_basis.x * (0.5 + randf() * 0.5) * (1.0 if randf() < 0.5 else -1.0)
		aim += side + (aim - muzzle).normalized() * 4.0
	Tracer.spawn(get_tree().current_scene, muzzle, aim)
	_model.play_shot()
	EventBus.noise_emitted.emit(global_position, stats.gunshot_noise_radius, &"gunshot")
	if hit:
		_target.health.take_damage(stats.fire_damage)


func _face(direction: Vector3, delta: float) -> void:
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return
	var target_yaw := atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-stats.turn_speed * delta))


func _update_feedback() -> void:
	if state == State.STUNNED:
		_gauge.visible = true
		_gauge.position.y = GAUGE_HEIGHT_DOWN
		_gauge_back.visible = false
		_gauge_fill.visible = false
		_mark.text = "z z"
		_mark.modulate = Color(0.6, 0.8, 1.0)
		return
	_gauge.position.y = GAUGE_HEIGHT
	_gauge_back.visible = true
	_gauge_fill.visible = true
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
