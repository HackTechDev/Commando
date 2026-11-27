class_name EnemyErrand
extends EnemyBehavior
## Mission au calme, donnée par le décor ou un événement (`Enemy.send_on_errand`) :
## il marche jusqu'à un point (même un garde fixe), y travaille un moment
## (réparer une lampe, prendre la relève, voir pourquoi un poste ne répond
## plus) en regardant vers `look_at`, puis prévient (`on_done`) et rentre
## (`EnemyReturn`) ; s'il doit rester sur place (`stay`), il en fait son
## nouveau poste. Méfiant en route, il s'arrête pour regarder ; une alerte
## l'interrompt (`on_done` n'est alors jamais appelé).

## Distance (m) au point à partir de laquelle il est arrivé.
const ARRIVE_DISTANCE := 1.3

var goal := Vector3.ZERO
var look_at := Vector3.INF
var work_time: float = 0.0
var work_left: float = 0.0
## Reste sur place une fois le travail fini (nouveau poste, garde fixe).
var stay: bool = false
var on_done: Callable
## Arrivé, il travaille.
var arrived: bool = false


func activity() -> Enemy.Activity:
	return Enemy.Activity.ERRAND


func begin(at: Vector3, look: Vector3, seconds: float, keep: bool, done: Callable) -> void:
	goal = at
	look_at = look
	work_time = seconds
	work_left = seconds
	stay = keep
	on_done = done
	arrived = false
	enemy._agent.target_position = at


func update(delta: float) -> Vector3:
	if enemy.state == Enemy.State.SUSPICIOUS:
		enemy._face(enemy._last_seen - enemy.global_position, delta)
		return Vector3.ZERO
	var flat := Vector3(goal.x - enemy.global_position.x, 0.0, goal.z - enemy.global_position.z)
	if not arrived:
		# Arrivé, ou au plus près si le point n'est pas atteignable.
		if flat.length() > ARRIVE_DISTANCE:
			if enemy._agent.target_position.distance_to(goal) > 0.3:
				enemy._agent.target_position = goal
			if not enemy._agent.is_navigation_finished():
				var direction := enemy._path_direction(delta)
				if direction != Vector3.ZERO:
					return direction * enemy.stats.patrol_speed
		arrived = true
	if look_at != Vector3.INF:
		enemy._face(look_at - enemy.global_position, delta)
	work_left -= delta
	if work_left > 0.0:
		return Vector3.ZERO
	var done := on_done
	on_done = Callable()
	if stay:
		enemy._home = enemy.global_position
		enemy._home_yaw = enemy.rotation.y
		enemy._end_activity()
	else:
		enemy.walking_home = enemy.stationary
		enemy._begin_return()
	if done.is_valid():
		done.call()
	return Vector3.ZERO
