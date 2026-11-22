class_name EnemyInvestigate
extends EnemyBehavior
## Enquête sur un bruit (méfiant) : il va voir au pas d'où il vient
## (`Enemy._last_seen`), regarde autour de lui, puis rentre (`EnemyReturn`).
## Bruit faible (`look_only`) ou poste fixe : il se tourne seulement vers le
## bruit et le surveille.

## Il regarde autour de lui ce temps (s), une fois sur place.
const LOOK_TIME := 3.0

## Bruit faible : il se tourne vers lui sans y aller.
var look_only: bool = false
## Temps restant (s) à regarder autour de lui.
var look_left: float = 0.0


func activity() -> Enemy.Activity:
	return Enemy.Activity.INVESTIGATE


## Nouvelle enquête sur un bruit en `at` ; `ongoing` : une enquête est déjà
## en route (un bruit faible ne l'annule pas).
func begin(at: Vector3, faint: bool, ongoing: bool) -> void:
	if not (faint and ongoing and not look_only):
		look_only = faint
	look_left = LOOK_TIME
	if not look_only:
		enemy._agent.target_position = at


func update(delta: float) -> Vector3:
	var agent := enemy._agent
	if agent.target_position.distance_to(enemy._last_seen) > 0.3:
		agent.target_position = enemy._last_seen
	if not enemy.stationary and not look_only and not agent.is_navigation_finished():
		var direction := enemy._path_direction(delta)
		if direction != Vector3.ZERO:
			return direction * enemy.stats.patrol_speed
	# Poste fixe, ou bruit faible : il ne s'en va pas, mais se tourne vers le
	# bruit et le surveille.
	if enemy.stationary or look_only:
		enemy._face(enemy._last_seen - enemy.global_position, delta)
		look_left -= delta
		if look_left <= 0.0:
			enemy._end_activity()
		return Vector3.ZERO
	# Sur place : il balaie les alentours du regard, puis rentre.
	look_left -= delta
	enemy.rotation.y += delta * 0.9 * sin(look_left * 1.6)
	if look_left <= 0.0:
		enemy._begin_return()
	return Vector3.ZERO
