class_name EnemyWatch
extends EnemyBehavior
## Méfiant, sans enquête en cours (jauge qui monte, ou bruit observé de
## loin) : il s'arrête et regarde vers ce qui l'a intrigué
## (`Enemy._last_seen`).


func update(delta: float) -> Vector3:
	enemy._face(enemy._last_seen - enemy.global_position, delta)
	return Vector3.ZERO
