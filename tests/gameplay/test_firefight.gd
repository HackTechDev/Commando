extends LevelTest
## Fusillade, rechargement, mort ; perte de connaissance et réveil d'un ennemi.


func before_each() -> void:
	super()
	await load_level()


func test_operator_kills_enemy_reloading_on_the_way() -> void:
	var alpha: Commando = node("Units/Alpha")
	var enemy: Enemy = node("Enemies/Soldier1")
	park(node("Enemies/TrainingDummy"), Vector3(25, 0, 25))
	alpha.health.reset(10000.0)
	alpha.ammo_in_magazine = 2
	alpha.attack(enemy, false)
	var reloaded := [false]
	var dead := func() -> bool:
		if alpha.is_reloading():
			reloaded[0] = true
		return enemy.is_dead
	assert_gt(await frames_until(dead, 1500), -1, "ennemi abattu")
	assert_true(reloaded[0], "rechargement après les deux premières balles")
	await frames(90)
	var model: SoldierModel = enemy.get_node("SoldierModel")
	assert_true(model.is_dead, "modèle mort")
	assert_almost_eq(absf(model._body.rotation.x), PI / 2.0, 0.05, "corps à plat au sol")


func test_enemy_shoots_operator() -> void:
	var alpha: Commando = node("Units/Alpha")
	var enemy: Enemy = node("Enemies/Soldier1")
	park(node("Enemies/TrainingDummy"), Vector3(25, 0, 25))
	enemy.stationary = true
	alpha.global_position = enemy.global_position - enemy.global_basis.z * 8.0
	var hit := func() -> bool: return alpha.health.health < alpha.health.max_health
	assert_gt(await frames_until(hit, 900), -1, "l'ennemi repère l'opérateur et le touche")
	assert_eq(enemy.state, Enemy.State.ALERT)


func test_knocked_out_enemy_falls_then_wakes_up_alert() -> void:
	park(node("Enemies/Soldier1"))
	var dummy: Enemy = node("Enemies/TrainingDummy")
	var model: SoldierModel = dummy.get_node("SoldierModel")
	dummy.knock_out()
	await frames(60)
	assert_true(dummy.is_stunned())
	assert_almost_eq(model._body.rotation.x, 1.56, 0.05, "au sol")
	dummy._stun_left = 0.01
	await frames(120)
	assert_false(dummy.is_stunned())
	assert_eq(dummy.state, Enemy.State.ALERT, "se réveille en alerte")
	assert_almost_eq(model._body.rotation.x, 0.0, 0.05, "debout")
