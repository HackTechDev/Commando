extends LevelTest
## Bouclier balistique : levé, il arrête les tirs ennemis venant de face,
## pour son porteur comme pour ceux qui s'abritent derrière lui.

var alpha: Commando
var bravo: Commando
var enemy: Enemy


func _setup() -> void:
	await load_level()
	alpha = node("Units/Alpha")
	bravo = node("Units/Bravo")
	enemy = node("Enemies/Soldier1")
	park(node("Enemies/TrainingDummy"))
	hide_from_enemies(node("Units/Charlie"))
	alpha.shields = 1


## Place l'ennemi (immobile) à `distance` m devant (ou derrière) Alpha,
## tourné vers lui.
func _enemy_facing_alpha(distance: float) -> void:
	alpha.global_position = Vector3(0, 0, 2)
	alpha.rotation.y = 0.0
	enemy.stationary = true
	enemy.global_position = alpha.global_position + Vector3(0, 0, -distance)
	enemy.rotation.y = 0.0 if distance < 0.0 else PI


func test_shield_draws_the_sidearm_and_slows_down() -> void:
	await _setup()
	assert_not_null(alpha._model.find_child("Shield", true, false), "bouclier dans le dos")
	assert_false(bravo.set_shield(true), "pas de bouclier")
	var walk := alpha.stats.walk_speed
	assert_true(alpha.set_shield(true))
	assert_true(alpha.using_secondary, "arme de poing en main")
	assert_almost_eq(alpha._current_speed(), alpha.stats.walk_speed * Commando.SHIELD_SPEED, 0.01)
	assert_lt(alpha._current_speed(), walk, "plus lent")
	alpha.move_to(Vector3(0, 0, -2), true)
	assert_almost_eq(alpha._current_speed(), alpha.stats.walk_speed * Commando.SHIELD_SPEED, 0.01, "pas de course")
	# Carabine à la bretelle, puis bouclier devant lui.
	assert_gt(await frames_until(func() -> bool: return alpha._model.is_shield_up(), 150), -1, "levé devant lui")
	alpha.toggle_posture(SoldierModel.Posture.PRONE)
	assert_false(alpha.shield_raised, "baissé pour ramper")
	alpha.toggle_posture(SoldierModel.Posture.PRONE)
	assert_true(alpha.set_shield(true))
	alpha.switch_weapon()
	assert_false(alpha.shield_raised, "l'arme principale se tient à deux mains")
	alpha.shields = 0
	assert_null(alpha._model.find_child("Shield", true, false))


func test_raised_shield_stops_enemy_fire() -> void:
	await _setup()
	hide_from_enemies(bravo)
	_enemy_facing_alpha(8.0)
	alpha.set_shield(true)
	await frames(30)
	var health := alpha.health.health
	await frames(400)
	assert_gt(enemy.shots_blocked, 2, "balles arrêtées")
	assert_eq(alpha.health.health, health, "aucune blessure")


func test_shield_covers_a_teammate_behind() -> void:
	await _setup()
	_enemy_facing_alpha(8.0)
	bravo.global_position = alpha.global_position + Vector3(0, 0, 1.2)
	# L'ennemi ne voit que Bravo, abrité derrière Alpha.
	hide_from_enemies(alpha)
	alpha.set_shield(true)
	await frames(30)
	var health := bravo.health.health
	await frames(400)
	assert_gt(enemy.shots_blocked, 2)
	assert_eq(bravo.health.health, health, "Bravo protégé")


func test_shield_does_not_protect_from_behind() -> void:
	await _setup()
	hide_from_enemies(bravo)
	_enemy_facing_alpha(-8.0)
	alpha.set_shield(true)
	await frames(30)
	var health := alpha.health.health
	var hurt := await frames_until(func() -> bool: return alpha.health.health < health, 600)
	assert_gt(hurt, -1, "touché dans le dos")
	assert_eq(enemy.shots_blocked, 0)
