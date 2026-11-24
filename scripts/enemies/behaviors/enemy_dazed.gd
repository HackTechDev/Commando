class_name EnemyDazed
extends EnemyBehavior
## Assourdi (grenade assourdissante, `Enemy.daze`) : aveuglé et sonné, il
## reste sur place les bras devant le visage, ne voit rien et ne tire pas,
## `Enemy.dazed_left` secondes. On peut le désarmer, l'assommer ou le saisir
## sans qu'il se défende. Remis, il est en alerte vers l'endroit de la
## détonation.


func takes_over() -> bool:
	return true


func enter() -> void:
	enemy._vision.visible = false
	enemy._vision.set_physics_process(false)
	enemy._model.aiming = false
	enemy._model.guard_up = true
	enemy._model.move_ratio = 0.0


func exit() -> void:
	enemy._model.guard_up = false
	if not enemy.is_dead and not enemy.is_stunned():
		enemy._vision.visible = not enemy.blind
		enemy._vision.set_physics_process(true)


func update(delta: float) -> Vector3:
	enemy.dazed_left -= delta
	enemy._apply_velocity(Vector3.ZERO)
	if enemy.dazed_left <= 0.0:
		enemy._recover_from_daze()
	return Vector3.ZERO
