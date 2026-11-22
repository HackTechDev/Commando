class_name EnemyDisarmed
extends EnemyBehavior
## Désarmé : mains en l'air, inoffensif mais conscient ; il ne quitte pas
## des yeux celui qui l'a désarmé.


func takes_over() -> bool:
	return true


func update(delta: float) -> Vector3:
	var model := enemy._model
	model.aiming = false
	model.guard_up = false
	var disarmer := enemy._disarmer
	if is_instance_valid(disarmer):
		enemy._face(disarmer.global_position - enemy.global_position, delta)
		model.look_target = disarmer.global_position + Vector3.UP * 1.4
	enemy._apply_velocity(Vector3.ZERO)
	return Vector3.ZERO
