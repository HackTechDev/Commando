class_name EnemyStunned
extends EnemyBehavior
## Assommé : au sol, aveugle, `left` secondes ; ligoté sur le plateau d'un
## véhicule, il ne se réveille pas. Au réveil (`Enemy._wake_up`), il donne
## l'alerte sur place.

## Perte de connaissance restante (s).
var left: float = 0.0


func takes_over() -> bool:
	return true


func update(delta: float) -> Vector3:
	if enemy.on_vehicle == null:
		left -= delta
	if left <= 0.0:
		enemy._wake_up()
	return Vector3.ZERO
