class_name EnemyStunned
extends EnemyBehavior
## Assommé : au sol, aveugle, `left` secondes ; ligoté (`Enemy.tied`), ou
## couché sur le plateau d'un véhicule, il ne se réveille pas. Au réveil (`Enemy._wake_up`), il donne
## l'alerte sur place.

## Perte de connaissance restante (s).
var left: float = 0.0
var _pinned: bool = false


func takes_over() -> bool:
	return true


func update(delta: float) -> Vector3:
	# Coincé sous une caisse : il ne se relèvera pas tant qu'elle y est.
	var pinned := enemy.is_pinned()
	if pinned != _pinned:
		_pinned = pinned
		enemy._update_feedback()
	if enemy.on_vehicle == null and not enemy.tied and not pinned:
		left -= delta
	if left <= 0.0:
		enemy._wake_up()
	return Vector3.ZERO
