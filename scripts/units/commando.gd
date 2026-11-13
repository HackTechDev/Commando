class_name Commando
extends CharacterBody3D
## Unité contrôlable par le joueur : déplacement par navigation et postures.

signal selected_changed(is_selected: bool)
signal posture_changed(posture: SoldierModel.Posture)
signal sling_changed(slung: bool)

enum MeleeKind { KNIFE, KNOCKOUT }

const MASK_OCCLUDERS := 0b10
## Distance (entre centres) à partir de laquelle une attaque au corps à corps est possible.
const MELEE_RANGE := 1.3
## Instant de l'attaque (0 à 1) où le coup porte.
const STRIKE_HIT_TIME := 0.45
## Marge tolérée si la cible s'éloigne pendant l'élan.
const STRIKE_REACH_MARGIN := 0.4
## Instants (0 à 1) où l'étranglement et l'égorgement neutralisent la victime.
const CHOKE_HIT_TIME := 0.85
const THROAT_CUT_HIT_TIME := 0.6
## Durée (s) du glissement de l'opérateur contre la victime d'une prise.
const GRAB_SLIDE_TIME := 0.15
## Caisse : distance au point de prise à partir de laquelle l'opérateur s'y
## glisse sans navigation, et intervalle entre deux bruits de frottement.
const CRATE_GRIP_REACH := 0.75
const CRATE_NOISE_INTERVAL := 0.5
## Repoussé par un ennemi en alerte : recul (m) et durée du recul (s).
const REPEL_DISTANCE := 1.0
const REPEL_TIME := 0.35
## Réaction d'un opérateur repoussé ou frappé.
const SHOVED_HIT_STRENGTH := 1.8
## Esquive : pas de côté (m) et sa durée (s).
const DODGE_DISTANCE := 0.5
const DODGE_TIME := 0.3
## Évitement : en dessous de cette part de la vitesse voulue, l'unité est
## considérée comme bloquée et fait un pas de côté.
const BLOCKED_RATIO := 0.4
const SIDESTEP_RATIO := 0.7
## Part de la vitesse au sol utilisée pour marcher d'une caisse à l'autre.
const CRATE_WALK_RATIO := 0.6
const CLIMB_START_DISTANCE := 0.4
const CLIMB_REACH := 1.2
# Avancée et élévation du corps pendant l'escalade, par paires (instant,
# fraction du trajet), calées sur les images clés de `SoldierModel`.
const CLIMB_UP_FORWARD: Array[float] = [0, 0, 0.12, 0.069, 0.26, 0.194, 0.45, 0.312, 0.54, 0.3, 0.62, 0.344, 0.72, 0.5, 0.84, 0.75, 1, 1]
const CLIMB_UP_HEIGHT: Array[float] = [0, 0, 0.12, 0, 0.26, 0.06, 0.45, 0.438, 0.54, 0.709, 0.62, 0.674, 0.72, 0.938, 0.84, 1, 1, 1]
const CLIMB_DOWN_FORWARD: Array[float] = [0, 0, 0.25, 0.3, 0.35, 0.529, 0.45, 0.688, 0.6, 0.85, 0.74, 1, 1, 1]
const CLIMB_DOWN_HEIGHT: Array[float] = [0, 0, 0.25, 0, 0.35, 0.006, 0.45, 0.338, 0.6, 0.668, 0.74, 1, 1, 1]
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
			if _model:
				_model.posture = value
			posture_changed.emit(posture)
## Cartouches dans le chargeur engagé.
var ammo_in_magazine: int = 0
## Cartouches en réserve.
var ammo_reserve: int = 0
## Couteaux de lancer en main (à ramasser après chaque lancer).
var throwing_knives: int = 0
## Obstacle sur lequel l'unité se tient, le cas échéant.
var perched_on: Climbable

var _running: bool = false
var _has_order: bool = false
var _attack_target: Enemy
var _fire_cooldown: float = 0.0
var _reload_left: float = 0.0
var _climb_target: Climbable
var _melee_target: Enemy
var _melee_kind: MeleeKind = MeleeKind.KNIFE
## Caisse à saisir (approche), côté choisi (direction du centre vers
## l'opérateur), caisse tenue, position visée pour la caisse.
var _crate_target: Climbable
var _crate_side: Vector3
var _crate: Climbable
var _crate_goal: Vector3
var _crate_moving: bool = false
var _crate_noise_left: float = 0.0
## Lancer de couteau : cible, temps restant du geste, couteau parti.
var _throw_target: Enemy
var _throw_left: float = 0.0
var _throw_released: bool = false
var _strike_target: Enemy
var _strike_kind: MeleeKind = MeleeKind.KNIFE
var _strike_left: float = 0.0
var _strike_landed: bool = false
## Durée et instant d'impact (0 à 1) de la frappe en cours.
var _strike_duration: float = 1.0
var _strike_hit_time: float = STRIKE_HIT_TIME
## Prise par derrière en cours (étranglement, égorgement) et glissement de
## l'opérateur vers sa place, juste derrière la victime.
var _grapple: bool = false
var _grab_from: Vector3
var _grab_to: Vector3
var _climb_point: Vector3
## Déplacement subi (repoussé, esquive) : délai avant, durée, vitesse
## initiale, et position de l'assaillant pour la réaction (INF : aucune).
var _push_delay: float = 0.0
var _push_left: float = 0.0
var _push_time: float = 1.0
var _push_velocity: Vector3
var _push_hit_from: Vector3 = Vector3.INF
## Parade ou esquive en cours face à `_defend_enemy`.
var _defend_left: float = 0.0
var _defend_enemy: Enemy
## Choix du joueur : arme à la bretelle (mains libres) plutôt qu'en main.
## Un ordre d'attaque ou de rechargement la fait reprendre en main.
var weapon_slung: bool = false:
	set(value):
		if value != weapon_slung:
			weapon_slung = value
			sling_changed.emit(value)
var _hopping: bool = false
## Vrai pendant une escalade (attente de la bretelle comprise).
var _climbing: bool = false
var _vertical_velocity: float = 0.0
var _last_health: float = INF
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
	_last_health = health.health
	ammo_in_magazine = stats.magazine_size
	ammo_reserve = stats.reserve_ammo
	throwing_knives = stats.throwing_knives
	health.health_changed.connect(_on_health_changed)
	health.died.connect(_on_died)
	_agent.velocity_computed.connect(_apply_velocity)


func _exit_tree() -> void:
	# Une unité retirée de la scène (changement de niveau…) quitte la sélection.
	SelectionManager.remove(self)


func _physics_process(delta: float) -> void:
	# Mains libres pour grimper ou jouer du couteau : arme à la bretelle.
	# Pour assommer, l'arme reste comme le joueur l'a choisie (crosse ou mains nues).
	var knife := (_melee_target != null and _melee_kind == MeleeKind.KNIFE) or (_strike_left > 0.0 and (_strike_kind == MeleeKind.KNIFE or _grapple)) \
			or _throw_target != null
	var crate := _crate_target != null or _crate != null
	_model.weapon_slung = not is_dead and (weapon_slung or _climbing or _climb_target != null or knife or crate)
	_update_reload(delta)
	_model.aiming = not is_dead and is_instance_valid(_attack_target) and not _attack_target.is_dead
	if _hopping:
		return
	if _crate and not is_dead:
		_update_crate(delta)
		return
	var horizontal := Vector3.ZERO
	if is_dead:
		pass
	elif _defend_left > 0.0:
		horizontal = _update_defend(delta)
	elif _push_delay > 0.0 or _push_left > 0.0:
		horizontal = _update_push(delta)
	elif _strike_left > 0.0:
		_update_strike(delta)
	elif _throw_left > 0.0:
		_update_throw(delta)
	elif _climb_target:
		horizontal = _approach_climb()
		if horizontal != Vector3.ZERO:
			_face(horizontal, delta)
	elif _melee_target:
		horizontal = _approach_melee(delta)
	elif _throw_target:
		horizontal = _approach_throw(delta)
	elif _crate_target:
		horizontal = _approach_crate(delta)
	elif _attack_target:
		horizontal = _attack(delta)
	elif _has_order:
		if _agent.is_navigation_finished():
			_has_order = false
		else:
			horizontal = _follow_path(delta)

	# Se coucher ou se relever immobilise l'unité un instant.
	if _model.is_changing_posture():
		horizontal = Vector3.ZERO
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
	# Pendant une escalade, une traversée de caisses ou le déplacement d'une
	# caisse, le déplacement et l'animation sont scriptés : la physique (et
	# l'évitement, qui rappelle cette fonction) ne doit pas s'en mêler.
	if _hopping or _crate:
		return
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
	if _crate:
		# Mains sur une caisse : l'ordre de déplacement la pousse ou la tire.
		_set_crate_goal(target)
		return
	_crate_target = null
	_climb_target = null
	_melee_target = null
	if perched_on:
		_descend(target, move_to.bind(target, run))
		return
	_attack_target = null
	_throw_target = null
	_running = run
	_has_order = true
	_best_goal_distance = INF
	_agent.target_position = target


## Ordonne d'attaquer `enemy` : l'unité s'approche jusqu'à avoir une ligne de
## tir, puis tire jusqu'à ce que la cible soit neutralisée.
func attack(enemy: Enemy, run: bool) -> void:
	if is_dead or _hopping or enemy == null or enemy.is_dead or not has_ammo():
		return
	_release_crate()
	weapon_slung = false
	_climb_target = null
	_melee_target = null
	_throw_target = null
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
	if target.handler != null:
		return false
	_release_crate()
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
	_melee_target = null
	_throw_target = null
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
	_release_crate()
	weapon_slung = false
	_reload_left = stats.reload_time
	EventBus.unit_ammo_changed.emit(self)


## Ordonne d'éliminer `enemy` au corps à corps : l'unité s'en approche (à la
## vitesse de sa posture), puis frappe. Au couteau, l'ennemi est tué ; sinon il
## est assommé. Renvoie faux si l'ordre est impossible.
func melee(enemy: Enemy, kind: MeleeKind, run: bool = false) -> bool:
	if is_dead or _hopping or enemy == null or enemy.is_dead:
		return false
	if kind == MeleeKind.KNOCKOUT and enemy.is_stunned():
		return false
	if perched_on:
		return _descend(enemy.global_position, melee.bind(enemy, kind, run))
	_release_crate()
	_has_order = false
	_attack_target = null
	_climb_target = null
	_throw_target = null
	_running = run
	_melee_target = enemy
	_melee_kind = kind
	return true


## Ordonne de lancer un couteau sur `enemy` : l'unité s'approche à portée,
## avec une ligne de vue dégagée, puis lance. Renvoie faux si c'est
## impossible (plus de couteau, cible morte…).
func throw_knife(enemy: Enemy, run: bool = false) -> bool:
	if is_dead or _hopping or enemy == null or enemy.is_dead or throwing_knives <= 0:
		return false
	if perched_on and not _can_throw_at(enemy):
		return _descend(enemy.global_position, throw_knife.bind(enemy, run))
	_release_crate()
	_has_order = false
	_attack_target = null
	_climb_target = null
	_melee_target = null
	_running = run
	_throw_target = enemy
	return true


## Ramasse un couteau de lancer au sol. Renvoie faux s'il en a déjà son compte.
func pick_up_knife() -> bool:
	if is_dead or throwing_knives >= stats.throwing_knives:
		return false
	throwing_knives += 1
	EventBus.unit_ammo_changed.emit(self)
	return true


## Vrai pendant une attaque au corps à corps (élan et coup).
func is_striking() -> bool:
	return _strike_left > 0.0


## Arrête le déplacement et l'attaque en cours (un coup déjà lancé va à son terme).
func stop() -> void:
	_has_order = false
	_attack_target = null
	_climb_target = null
	_melee_target = null
	_throw_target = null
	_release_crate()


## Ordonne de pousser ou tirer `crate` : l'unité rejoint le côté le plus
## proche de `near`, passe son arme à la bretelle et pose les mains dessus.
## Ensuite, un ordre de déplacement fait glisser la caisse dans l'axe de ce
## côté. Renvoie faux si c'est impossible (caisse occupée, aucun côté libre).
func handle_crate(crate: Climbable, near: Vector3) -> bool:
	if is_dead or _hopping or crate == null or crate.occupant != null:
		return false
	if crate.handler != null and crate.handler != self:
		return false
	if perched_on:
		return _descend(near, handle_crate.bind(crate, near))
	var side := crate.get_side_toward(near)
	if side == Vector3.ZERO:
		return false
	_release_crate()
	_has_order = false
	_attack_target = null
	_climb_target = null
	_melee_target = null
	_throw_target = null
	_crate_target = crate
	_crate_side = side
	_agent.target_position = crate.get_access_point(side)
	return true


## Lâche la caisse tenue.
func release_crate() -> void:
	_release_crate()


## Vrai pendant qu'il tient une caisse.
func is_handling_crate() -> bool:
	return _crate != null


## Lâche la caisse tenue (ou abandonne l'approche).
func _release_crate() -> void:
	_crate_target = null
	if _crate == null:
		return
	if is_instance_valid(_crate):
		remove_collision_exception_with(_crate)
		_crate.handler = null
	_crate = null
	_model.crate_grip = false
	if _crate_moving:
		_crate_moving = false
		EventBus.navigation_obstacle_moved.emit()


func _crate_grip_point(crate: Climbable) -> Vector3:
	var point := crate.global_position + _crate_side * (crate.half_extent + SoldierModel.CRATE_GRIP_GAP)
	point.y = global_position.y
	return point


## Rejoint le côté choisi ; tout près, se glisse au point de prise, face à
## la caisse, et la saisit une fois l'arme à la bretelle.
func _approach_crate(delta: float) -> Vector3:
	var crate := _crate_target
	if not is_instance_valid(crate) or crate.occupant != null or (crate.handler != null and crate.handler != self):
		_crate_target = null
		return Vector3.ZERO
	var to_grip := _crate_grip_point(crate) - global_position
	to_grip.y = 0.0
	if to_grip.length() > CRATE_GRIP_REACH:
		if _agent.is_navigation_finished():
			_crate_target = null
			return Vector3.ZERO
		return _follow_path(delta)
	posture = SoldierModel.Posture.STANDING
	if to_grip.length() > 0.04:
		_face(to_grip, delta)
		return to_grip.normalized() * minf(stats.walk_speed * 0.5, to_grip.length() / delta)
	_face(-_crate_side, delta)
	if _model.is_weapon_slung() and not _model.is_changing_posture() and (-global_basis.z).angle_to(-_crate_side) < 0.15:
		_crate_target = null
		_crate = crate
		crate.handler = self
		add_collision_exception_with(crate)
		_crate_goal = crate.global_position
		_model.crate_grip = true
	return Vector3.ZERO


## Destination de la caisse : projection de `target` sur l'axe du côté tenu.
func _set_crate_goal(target: Vector3) -> void:
	var axis := -_crate_side
	var along := (target - _crate.global_position).dot(axis)
	_crate_goal = _crate.global_position + axis * along


## Pousse ou tire la caisse vers `_crate_goal`, pas à pas, et s'arrête au
## premier obstacle (la caisse ou l'opérateur heurterait quelque chose).
func _update_crate(delta: float) -> void:
	var crate := _crate
	if not is_instance_valid(crate):
		_release_crate()
		return
	velocity = Vector3.ZERO
	_model.posture = posture
	var axis := -_crate_side
	_face(axis, delta)
	var remaining := (_crate_goal - crate.global_position).dot(axis)
	if absf(remaining) > 0.01:
		_model.crate_pull = remaining < 0.0
		var speed := stats.crate_push_speed if remaining > 0.0 else stats.crate_pull_speed
		var step := axis * signf(remaining) * minf(absf(remaining), speed * delta)
		if crate.is_free_at(crate.global_position + step, [get_rid()]) and not test_move(global_transform, step):
			crate.global_position += step
			global_position += step
			_crate_moving = true
			_model.move_ratio = speed / stats.walk_speed
			_crate_noise_left -= delta
			if _crate_noise_left <= 0.0:
				_crate_noise_left = CRATE_NOISE_INTERVAL
				EventBus.noise_emitted.emit(crate.global_position, stats.crate_noise_radius, &"crate")
			return
		# Bloqué : la caisse reste où elle est.
		_crate_goal = crate.global_position
	_model.move_ratio = 0.0
	_crate_noise_left = 0.0
	if _crate_moving:
		_crate_moving = false
		EventBus.navigation_obstacle_moved.emit()


## Passe l'arme à la bretelle, ou la reprend en main.
func toggle_sling() -> void:
	if is_dead:
		return
	weapon_slung = not weapon_slung
	# Reprendre son arme oblige à lâcher la caisse.
	if not weapon_slung:
		_release_crate()


## Bascule entre `new_posture` et debout.
func toggle_posture(new_posture: SoldierModel.Posture) -> void:
	if is_dead:
		return
	posture = SoldierModel.Posture.STANDING if posture == new_posture else new_posture
	# On ne déplace une caisse que debout.
	if posture != SoldierModel.Posture.STANDING:
		_release_crate()


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
	# Pas prudents sur les caisses : plus lent qu'au sol, à cadence de marche.
	var speed := _current_speed() * CRATE_WALK_RATIO
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void:
		global_position = from.lerp(to, t)
		_model.posture = posture
		_model.move_ratio = 1.0
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
	_climbing = true
	_has_order = false
	velocity = Vector3.ZERO
	posture = SoldierModel.Posture.STANDING
	var from := global_position
	var flat := to - from
	flat.y = 0.0
	if flat.length_squared() > 0.0001:
		rotation.y = atan2(-flat.x, -flat.z)
	# Se relever et passer l'arme à la bretelle avant de grimper.
	_model.weapon_slung = true
	_model.move_ratio = 0.0
	while not is_dead and (_model.is_changing_posture() or not _model.is_weapon_slung()):
		await get_tree().physics_frame
	if is_dead:
		_hopping = false
		_climbing = false
		return
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
		_climbing = false
		_model.climb_progress = -1.0
		if not is_dead:
			done.call())


## Approche de la cible du corps à corps ; frappe dès qu'elle est à portée.
func _approach_melee(delta: float) -> Vector3:
	var enemy := _melee_target
	if not is_instance_valid(enemy) or enemy.is_dead or (_melee_kind == MeleeKind.KNOCKOUT and enemy.is_stunned()):
		_melee_target = null
		return Vector3.ZERO
	var to_enemy := enemy.global_position - global_position
	to_enemy.y = 0.0
	if to_enemy.length() <= MELEE_RANGE:
		if enemy.is_attacking():
			# Il frappe le premier : on attend l'issue (parade, puis contre).
			_face(to_enemy, delta)
			return Vector3.ZERO
		_melee_target = null
		if enemy.resists(global_position):
			# Il l'a vu venir : il le repousse, le coup échoue.
			enemy.shove(self)
			_push(-to_enemy.normalized() * REPEL_DISTANCE, REPEL_TIME, enemy.stats.shove_time * 0.5, enemy.global_position)
			return Vector3.ZERO
		_start_strike(enemy, _melee_kind)
		return Vector3.ZERO
	if _agent.target_position.distance_to(enemy.global_position) > 0.3:
		_agent.target_position = enemy.global_position
	if _agent.is_navigation_finished():
		return Vector3.ZERO
	return _follow_path(delta)


## Vrai si `enemy` est à portée de lancer, avec une ligne de vue dégagée.
func _can_throw_at(enemy: Enemy) -> bool:
	var offset := enemy.global_position - global_position
	offset.y = 0.0
	return offset.length() <= stats.throw_range and _has_line_of_fire(enemy)


## Approche jusqu'à portée de lancer ; lance une fois les mains libres et
## la cible dans l'axe.
func _approach_throw(delta: float) -> Vector3:
	var enemy := _throw_target
	if not is_instance_valid(enemy) or enemy.is_dead or throwing_knives <= 0:
		_throw_target = null
		return Vector3.ZERO
	var to_enemy := enemy.global_position - global_position
	to_enemy.y = 0.0
	if _can_throw_at(enemy):
		_face(to_enemy, delta)
		# On ne lance pas couché : l'opérateur se met à genoux.
		if posture == SoldierModel.Posture.PRONE:
			posture = SoldierModel.Posture.CROUCHED
		if _model.is_weapon_slung() and not _model.is_changing_posture() and (-global_basis.z).angle_to(to_enemy) < 0.2:
			_throw_left = stats.throw_time
			_throw_released = false
			_model.throw_progress = 0.0
		return Vector3.ZERO
	if _agent.target_position.distance_to(enemy.global_position) > 0.3:
		_agent.target_position = enemy.global_position
	if _agent.is_navigation_finished():
		return Vector3.ZERO
	return _follow_path(delta)


func _update_throw(delta: float) -> void:
	_throw_left = maxf(_throw_left - delta, 0.0)
	var progress := 1.0 - _throw_left / stats.throw_time
	_model.throw_progress = progress
	var enemy := _throw_target
	var valid := is_instance_valid(enemy) and not enemy.is_dead
	if valid:
		_face(enemy.global_position - global_position, delta)
	if not _throw_released and progress >= SoldierModel.THROW_RELEASE:
		_throw_released = true
		if valid and throwing_knives > 0:
			_release_knife(enemy)
	if _throw_left <= 0.0:
		_model.throw_progress = -1.0
		_throw_target = null


func _release_knife(enemy: Enemy) -> void:
	throwing_knives -= 1
	EventBus.unit_ammo_changed.emit(self)
	var offset := enemy.global_position - global_position
	offset.y = 0.0
	var distance := offset.length()
	var chance := 1.0
	if distance > stats.throw_sure_range:
		chance = lerpf(1.0, stats.throw_hit_chance_far, inverse_lerp(stats.throw_sure_range, stats.throw_range, minf(distance, stats.throw_range)))
	var hand := global_position + Vector3.UP * (_weapon_height() + 0.25) + global_basis.x * 0.15 - global_basis.z * 0.3
	ThrownKnife.spawn(get_tree().current_scene, hand, enemy, randf() < chance, global_position)


## Coup porté par `enemy` au corps à corps : l'opérateur pare ou esquive
## s'il est disponible et que le tirage le permet, sinon il encaisse.
## Renvoie vrai si le coup est évité.
func defend_against(enemy: Enemy) -> bool:
	if is_dead:
		return false
	var busy := _strike_left > 0.0 or _hopping or perched_on != null or _defend_left > 0.0 \
			or _push_delay > 0.0 or _push_left > 0.0 \
			or posture == SoldierModel.Posture.PRONE or _model.is_changing_posture()
	var roll := randf()
	if busy or roll >= stats.parry_chance + stats.dodge_chance:
		health.take_damage(enemy.stats.melee_damage)
		if not is_dead:
			_model.play_hit(enemy.global_position, SHOVED_HIT_STRENGTH)
		return false
	_defend_left = stats.defend_time
	_defend_enemy = enemy
	if roll < stats.parry_chance:
		_model.defend_move = SoldierModel.DefendMove.PARRY
	else:
		# Pas de côté, perpendiculaire à l'axe du coup.
		var side := 1.0 if randf() < 0.5 else -1.0
		var to_enemy := enemy.global_position - global_position
		to_enemy.y = 0.0
		_model.defend_move = SoldierModel.DefendMove.DODGE
		_model.defend_side = side
		_push(to_enemy.normalized().cross(Vector3.UP) * side * DODGE_DISTANCE, DODGE_TIME, 0.0)
	_model.defend_progress = 0.0
	return true


func _update_defend(delta: float) -> Vector3:
	_defend_left = maxf(_defend_left - delta, 0.0)
	_model.defend_progress = 1.0 - _defend_left / stats.defend_time
	var horizontal := Vector3.ZERO
	if _push_left > 0.0:
		horizontal = _update_push(delta)
	var enemy := _defend_enemy
	if is_instance_valid(enemy):
		_face(enemy.global_position - global_position, delta)
	if _defend_left <= 0.0:
		_model.defend_progress = -1.0
		_defend_enemy = null
		# Contre : un ordre de corps à corps en attente sur l'assaillant
		# déséquilibré part aussitôt, s'il est à portée.
		if _melee_target == enemy and is_instance_valid(enemy) and not enemy.is_dead and enemy.is_off_balance():
			var offset := enemy.global_position - global_position
			offset.y = 0.0
			if offset.length() <= MELEE_RANGE + STRIKE_REACH_MARGIN:
				_melee_target = null
				_start_strike(enemy, _melee_kind)
	return horizontal


## Fait subir un déplacement de `offset` en `duration` secondes, après
## `delay` secondes, avec réaction à un choc venu de `hit_from` (INF : aucun).
func _push(offset: Vector3, duration: float, delay: float, hit_from: Vector3 = Vector3.INF) -> void:
	_push_delay = delay
	_push_time = duration
	_push_left = duration
	_push_velocity = offset / duration
	_push_hit_from = hit_from


func _update_push(delta: float) -> Vector3:
	if _push_delay > 0.0:
		_push_delay -= delta
		if _push_delay <= 0.0 and _push_hit_from != Vector3.INF:
			_model.play_hit(_push_hit_from, SHOVED_HIT_STRENGTH)
		return Vector3.ZERO
	_push_left = maxf(_push_left - delta, 0.0)
	# Vitesse décroissante : départ brusque, arrêt en douceur.
	return _push_velocity * 2.0 * (_push_left / _push_time)


func _start_strike(enemy: Enemy, kind: MeleeKind) -> void:
	_strike_target = enemy
	_strike_kind = kind
	_strike_landed = false
	_model.strike_with_knife = kind == MeleeKind.KNIFE
	# Un ennemi déjà au sol s'achève sans prise.
	_grapple = not enemy.is_stunned() and enemy.is_behind(global_position)
	if _grapple:
		# Par derrière : l'opérateur se glisse contre la victime, qui est
		# immobilisée, puis l'étrangle ou l'égorge.
		posture = SoldierModel.Posture.STANDING
		enemy.grab()
		add_collision_exception_with(enemy)
		_grab_from = global_position
		_grab_to = enemy.global_position + enemy.global_basis.z * SoldierModel.GRAB_DISTANCE
		_grab_to.y = global_position.y
		rotation.y = enemy.rotation.y
		if kind == MeleeKind.KNIFE:
			_model.strike_move = SoldierModel.StrikeMove.THROAT_CUT
			_strike_duration = stats.throat_cut_time
			_strike_hit_time = THROAT_CUT_HIT_TIME
		else:
			_model.strike_move = SoldierModel.StrikeMove.CHOKE
			_strike_duration = stats.choke_time
			_strike_hit_time = CHOKE_HIT_TIME
	else:
		_strike_duration = stats.melee_time
		_strike_hit_time = STRIKE_HIT_TIME
		# On ne frappe pas allongé : l'opérateur se met à genoux.
		if posture == SoldierModel.Posture.PRONE:
			posture = SoldierModel.Posture.CROUCHED
		if kind == MeleeKind.KNOCKOUT:
			_model.strike_move = _pick_strike_move()
		elif _model.strike_move == SoldierModel.StrikeMove.CHOKE or _model.strike_move == SoldierModel.StrikeMove.THROAT_CUT:
			_model.strike_move = SoldierModel.StrikeMove.UPPERCUT
	_strike_left = _strike_duration
	_model.strike_progress = 0.0


## Coup pour assommer : coup de crosse arme en main ; à mains nues (arme à
## la bretelle), tiré au hasard, jamais deux fois de suite le même, et
## uppercut seulement hors de la position debout.
func _pick_strike_move() -> SoldierModel.StrikeMove:
	if not weapon_slung:
		return SoldierModel.StrikeMove.BUTT_STRIKE
	if posture != SoldierModel.Posture.STANDING:
		return SoldierModel.StrikeMove.UPPERCUT
	var moves: Array = [SoldierModel.StrikeMove.UPPERCUT, SoldierModel.StrikeMove.FRONT_KICK,
			SoldierModel.StrikeMove.ROUNDHOUSE, SoldierModel.StrikeMove.SIDE_KICK]
	moves.erase(_model.strike_move)
	return moves.pick_random()


func _update_strike(delta: float) -> void:
	_strike_left = maxf(_strike_left - delta, 0.0)
	var progress := 1.0 - _strike_left / _strike_duration
	_model.strike_progress = progress
	if _grapple:
		var slide := smoothstep(0.0, 1.0, minf(progress * _strike_duration / GRAB_SLIDE_TIME, 1.0))
		global_position = _grab_from.lerp(_grab_to, slide)
		velocity = Vector3.ZERO
	elif is_instance_valid(_strike_target):
		_face(_strike_target.global_position - global_position, delta)
	if not _strike_landed and progress >= _strike_hit_time:
		_strike_landed = true
		_land_strike()
	if _strike_left <= 0.0:
		_model.strike_progress = -1.0
		_end_grapple()
		_strike_target = null


## Fin d'une prise par derrière : la victime n'est plus tenue. Si elle n'a
## pas été neutralisée (opérateur tué), elle se dégage et donne l'alerte.
func _end_grapple() -> void:
	if not _grapple:
		return
	_grapple = false
	if is_instance_valid(_strike_target):
		remove_collision_exception_with(_strike_target)
		if not _strike_landed:
			_strike_target.release()


func _land_strike() -> void:
	var enemy := _strike_target
	if not is_instance_valid(enemy) or enemy.is_dead:
		return
	if _grapple:
		# Par derrière : sans un bruit, la victime s'effondre vers l'avant.
		match _strike_kind:
			MeleeKind.KNIFE:
				enemy.kill_silently(true)
			MeleeKind.KNOCKOUT:
				enemy.knock_out(true)
		return
	var offset := enemy.global_position - global_position
	offset.y = 0.0
	if offset.length() > MELEE_RANGE + STRIKE_REACH_MARGIN:
		return
	match _strike_kind:
		MeleeKind.KNIFE:
			# De face, la victime a le temps de crier.
			enemy.kill_silently()
			EventBus.noise_emitted.emit(global_position, stats.knife_front_noise_radius, &"scream")
		MeleeKind.KNOCKOUT:
			enemy.knock_out()
			EventBus.noise_emitted.emit(global_position, stats.melee_noise_radius, &"melee")


func _update_reload(delta: float) -> void:
	if not is_reloading() or is_dead:
		return
	# On ne recharge qu'arme en main.
	if not _model.is_weapon_ready():
		return
	_reload_left -= delta
	_model.reload_progress = 1.0 - _reload_left / stats.reload_time
	if _reload_left <= 0.0:
		_reload_left = 0.0
		_model.reload_progress = -1.0
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
		elif not is_reloading() and _model.is_weapon_ready() and not _model.is_changing_posture() and _fire_cooldown <= 0.0 and (-global_basis.z).angle_to(to_target) < 0.25:
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
	_model.play_shot()
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


func _on_health_changed(current: float, _maximum: float) -> void:
	if current < _last_health and current > 0.0:
		_model.play_hit()
	_last_health = current
	EventBus.unit_damaged.emit(self, health.max_health - health.health)


func _on_died() -> void:
	is_dead = true
	_has_order = false
	_attack_target = null
	_climb_target = null
	_melee_target = null
	_throw_target = null
	_throw_left = 0.0
	_model.throw_progress = -1.0
	_release_crate()
	_strike_left = 0.0
	_model.strike_progress = -1.0
	_end_grapple()
	_push_delay = 0.0
	_push_left = 0.0
	_defend_left = 0.0
	_defend_enemy = null
	_model.defend_progress = -1.0
	_reload_left = 0.0
	_model.reload_progress = -1.0
	remove_from_group(&"commandos")
	collision_layer = 0
	_agent.avoidance_enabled = false
	_model.is_dead = true
	SelectionManager.remove(self)
	EventBus.unit_died.emit(self)
