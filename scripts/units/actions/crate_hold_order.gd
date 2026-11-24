class_name CrateHoldOrder
extends CommandoAction
## Mains sur une caisse : un ordre de déplacement (`set_goal`) la fait
## glisser dans l'axe du côté tenu, pas à pas, jusqu'au premier obstacle.
## Le déplacement est scripté : la physique de l'unité ne s'en mêle pas.

const NOISE_INTERVAL := 0.5
## Rotation : pas d'un ordre (45°) et vitesse (rad/s).
const TURN_STEP := PI / 4.0
const TURN_SPEED := 1.2

var crate: Climbable
var side: Vector3
var goal: Vector3
var _moving: bool = false
var _noise_left: float = 0.0
## Angle (rad) qui reste à faire tourner la caisse autour de son axe
## vertical (positif : sens trigonométrique vu de dessus).
var _turn_left: float = 0.0


func _init(owner: Commando, target: Climbable, toward: Vector3) -> void:
	super(owner)
	crate = target
	side = toward


## Point où se tient l'opérateur pour saisir `crate` par le côté `side`.
static func grip_point(target: Climbable, toward: Vector3, height: float) -> Vector3:
	var point := target.global_position + toward * (target.half_extent + SoldierModel.CRATE_GRIP_GAP)
	point.y = height
	return point


func start() -> void:
	crate.handler = unit
	unit.add_collision_exception_with(crate)
	goal = crate.global_position
	unit._model.crate_grip = true


func hands_free() -> bool:
	return true


## Fait pivoter la caisse d'un huitième de tour (`TURN_STEP`) : l'opérateur
## tourne autour avec elle, mains posées sur le même côté. Elle se pousse
## ensuite dans le nouvel axe (en diagonale, par exemple).
func turn(clockwise: bool = true) -> void:
	goal = crate.global_position
	_turn_left += -TURN_STEP if clockwise else TURN_STEP


## Destination de la caisse : projection de `target` sur l'axe du côté tenu.
func set_goal(target: Vector3) -> void:
	var axis := -side
	goal = crate.global_position + axis * (target - crate.global_position).dot(axis)


func cancel() -> void:
	if is_instance_valid(crate):
		unit.remove_collision_exception_with(crate)
		crate.handler = null
	unit._model.crate_grip = false
	if _moving:
		_moving = false
		EventBus.navigation_obstacle_moved.emit()


func update(delta: float) -> Vector3:
	if not is_instance_valid(crate):
		cancel()
		finish()
		return Vector3.ZERO
	unit.velocity = Vector3.ZERO
	unit._model.posture = unit.posture
	if absf(_turn_left) > 0.001:
		_update_turn(delta)
		return Vector3.ZERO
	var axis := -side
	unit._face(axis, delta)
	var remaining := (goal - crate.global_position).dot(axis)
	if absf(remaining) > 0.01:
		unit._model.crate_pull = remaining < 0.0
		var speed := unit.stats.crate_push_speed if remaining > 0.0 else unit.stats.crate_pull_speed
		var step := axis * signf(remaining) * minf(absf(remaining), speed * delta)
		if crate.is_free_at(crate.global_position + step, [unit.get_rid()]) and not unit.test_move(unit.global_transform, step):
			crate.global_position += step
			unit.global_position += step
			_moving = true
			# Poussée au-delà d'un rebord : elle tombe (l'ordre est annulé).
			if crate.check_support():
				return Vector3.ZERO
			unit._model.move_ratio = speed / unit.stats.walk_speed
			_noise_left -= delta
			if _noise_left <= 0.0:
				_noise_left = NOISE_INTERVAL
				EventBus.noise_emitted.emit(crate.global_position, unit.stats.crate_noise_radius, &"crate")
				Sfx.play_at(&"scrape", crate.global_position, -6.0, 0.15)
			return Vector3.ZERO
		# Bloqué : la caisse reste où elle est.
		goal = crate.global_position
	_stop()
	return Vector3.ZERO


## Rotation en cours : un pas, si la caisse et l'opérateur ont la place.
func _update_turn(delta: float) -> void:
	var angle := signf(_turn_left) * minf(absf(_turn_left), TURN_SPEED * delta)
	var basis := crate.global_basis.rotated(Vector3.UP, angle)
	var center := crate.global_position
	var new_side := side.rotated(Vector3.UP, angle)
	var grip := grip_point(crate, new_side, unit.global_position.y)
	var step := grip - unit.global_position
	step.y = 0.0
	if not crate.is_free_at(center, [unit.get_rid()], basis) or unit.test_move(unit.global_transform, step):
		# Bloquée : elle reste où elle est.
		_turn_left = 0.0
		_stop()
		return
	crate.global_basis = basis
	side = new_side
	unit.global_position += step
	unit._face(-side, delta * 4.0)
	_turn_left -= angle
	_moving = true
	unit._model.move_ratio = 0.4
	_noise_left -= delta
	if _noise_left <= 0.0:
		_noise_left = NOISE_INTERVAL
		EventBus.noise_emitted.emit(center, unit.stats.crate_noise_radius, &"crate")
		Sfx.play_at(&"scrape", center, -6.0, 0.15)
	if absf(_turn_left) <= 0.001:
		_turn_left = 0.0
		_stop()


## Plus rien ne bouge : la navigation et les piles se mettent à jour.
func _stop() -> void:
	unit._model.move_ratio = 0.0
	_noise_left = 0.0
	if _moving:
		_moving = false
		EventBus.navigation_obstacle_moved.emit()
		Climbable.settle_all(unit.get_tree())
