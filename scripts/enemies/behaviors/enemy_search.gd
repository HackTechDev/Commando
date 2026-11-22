class_name EnemySearch
extends EnemyBehavior
## Fouille (méfiant), cible perdue : il va d'un bon pas au dernier point
## connu, puis à d'autres points au hasard autour, et regarde autour de
## chacun ; ensuite il rentre (`EnemyReturn`). Un garde fixe fouille du
## regard, sur place.

## Points visités (le dernier point connu, puis d'autres au hasard dans ce
## rayon, en m), regard autour de chacun (s), allure (multiple de celle de
## la ronde).
const POINTS := 3
const RADIUS := 7.0
const LOOK_TIME := 2.5
const SPEED := 1.4

## Points de la fouille et point visé.
var points: Array[Vector3] = []
var index: int = 0
## Temps restant (s) à regarder autour du point atteint.
var look_left: float = 0.0


func activity() -> Enemy.Activity:
	return Enemy.Activity.SEARCH


func begin(center: Vector3) -> void:
	points = plan(center)
	index = 0
	look_left = LOOK_TIME
	if not enemy.stationary:
		enemy._agent.target_position = points[0]


func exit() -> void:
	points.clear()


## Points d'une fouille autour de `center`, sur le maillage de navigation.
func plan(center: Vector3) -> Array[Vector3]:
	var planned: Array[Vector3] = [center]
	var map := enemy._agent.get_navigation_map()
	var nav_ready := map.is_valid() and NavigationServer3D.map_get_iteration_id(map) > 0
	for i in POINTS - 1:
		# Directions réparties autour du centre, distances au hasard.
		var angle := TAU * (float(i) + GameRng.of(enemy).randf() * 0.6) / float(POINTS - 1)
		var spot := center + Vector3(sin(angle), 0.0, cos(angle)) * GameRng.of(enemy).randf_range(RADIUS * 0.4, RADIUS)
		if nav_ready:
			spot = NavigationServer3D.map_get_closest_point(map, spot)
		planned.append(spot)
	return planned


func update(delta: float) -> Vector3:
	if index >= points.size():
		enemy._begin_return()
		return Vector3.ZERO
	var spot := points[index]
	var at := enemy.global_position
	if not enemy.stationary and not enemy._agent.is_navigation_finished() \
			and Vector2(spot.x - at.x, spot.z - at.z).length() > 0.6:
		var direction := enemy._path_direction(delta)
		if direction != Vector3.ZERO:
			return direction * enemy.stats.patrol_speed * SPEED
	# Sur place : regard qui balaie les alentours, puis point suivant.
	if enemy.stationary:
		enemy._face(spot - at, delta)
	else:
		enemy.rotation.y += delta * 1.1 * sin(look_left * 2.2)
	look_left -= delta
	if look_left <= 0.0:
		index += 1
		look_left = LOOK_TIME
		if index < points.size() and not enemy.stationary:
			enemy._agent.target_position = points[index]
	return Vector3.ZERO
