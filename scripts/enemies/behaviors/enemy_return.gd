class_name EnemyReturn
extends EnemyBehavior
## Retour, fouille ou enquête finie : il marche jusqu'à sa ronde (qu'il
## reprend au point le plus proche) ou à son poste (où il reprend son cap).
## Un garde fixe se contente de reprendre son cap, sauf s'il regagne son
## poste à pied (`Enemy.walking_home`).
## Méfiant en route (jauge qui monte), il s'arrête pour regarder, puis
## repart une fois rassuré.


func activity() -> Enemy.Activity:
	return Enemy.Activity.RETURN


## Où il rentre : le point de sa ronde le plus proche (il la reprend de
## là), ou son poste.
func goal() -> Vector3:
	var waypoints := enemy._waypoints
	if waypoints.is_empty():
		return enemy._home
	var at := enemy.global_position
	var best := 0
	for i in waypoints.size():
		if waypoints[i].distance_squared_to(at) < waypoints[best].distance_squared_to(at):
			best = i
	enemy._waypoint_index = best
	return waypoints[best]


func update(delta: float) -> Vector3:
	if enemy.state == Enemy.State.SUSPICIOUS:
		enemy._face(enemy._last_seen - enemy.global_position, delta)
		return Vector3.ZERO
	if enemy.stationary and not enemy.walking_home:
		return _face_home(delta)
	if not enemy._agent.is_navigation_finished():
		var direction := enemy._path_direction(delta)
		if direction != Vector3.ZERO:
			return direction * enemy.stats.patrol_speed
	if enemy._waypoints.is_empty():
		return _face_home(delta)
	enemy.patrol_behavior.pause_left = 0.0
	enemy._agent.target_position = enemy._waypoints[enemy._waypoint_index]
	enemy._end_activity()
	return Vector3.ZERO


## À son poste : il reprend son cap, et le retour est fini.
func _face_home(delta: float) -> Vector3:
	var yaw := enemy._home_yaw
	enemy._face(Vector3(-sin(yaw), 0.0, -cos(yaw)), delta)
	if absf(angle_difference(enemy.rotation.y, yaw)) < 0.05:
		enemy.walking_home = false
		enemy._end_activity()
	return Vector3.ZERO
