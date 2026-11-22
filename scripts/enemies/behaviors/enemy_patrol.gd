class_name EnemyPatrol
extends EnemyBehavior
## Ronde, au calme : il suit les points de sa ronde (`Enemy._waypoints`) en
## boucle, avec une pause à chacun et des haltes imprévues en route. Sans
## ronde, il garde son poste (son regard fait le reste : `EnemyGaze`).

## Haltes imprévues en route : durée et intervalle (s), tirés au hasard.
const HALT_TIME := Vector2(1.5, 3.0)
const HALT_INTERVAL := Vector2(10.0, 22.0)

## Pause restante (s) au point atteint.
var pause_left: float = 0.0
## Halte imprévue restante (s).
var halt_left: float = 0.0
var _halt_wait: float = 0.0


## Premier intervalle avant une halte (au `_ready` de l'ennemi).
func start() -> void:
	_halt_wait = GameRng.of(enemy).randf_range(HALT_INTERVAL.x, HALT_INTERVAL.y)


## Vrai s'il s'est arrêté en route (pause à un point, ou halte).
func is_stopped() -> bool:
	return pause_left > 0.0 or halt_left > 0.0


func update(delta: float) -> Vector3:
	var waypoints := enemy._waypoints
	if waypoints.is_empty():
		return Vector3.ZERO
	# Halte imprévue en route : il s'arrête et regarde autour de lui.
	if halt_left > 0.0:
		halt_left -= delta
		return Vector3.ZERO
	if pause_left > 0.0:
		pause_left -= delta
		if pause_left <= 0.0:
			enemy._waypoint_index = (enemy._waypoint_index + 1) % waypoints.size()
			enemy._agent.target_position = waypoints[enemy._waypoint_index]
		return Vector3.ZERO
	if enemy._agent.is_navigation_finished():
		pause_left = maxf(enemy.stats.patrol_pause, 0.01)
		return Vector3.ZERO
	# Pas de halte pour un garde fixe : il ne fait pas sa ronde.
	_halt_wait -= 0.0 if enemy.stationary else delta
	if _halt_wait <= 0.0:
		_halt_wait = GameRng.of(enemy).randf_range(HALT_INTERVAL.x, HALT_INTERVAL.y)
		halt_left = GameRng.of(enemy).randf_range(HALT_TIME.x, HALT_TIME.y)
		return Vector3.ZERO
	return enemy._path_direction(delta) * enemy.stats.patrol_speed
