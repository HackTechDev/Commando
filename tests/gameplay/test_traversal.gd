extends LevelTest
## Escalade généralisée (terrain d'essai) : échelle du bunker, muret, et
## ennemis qui empruntent les mêmes passages ou tirent sur un opérateur perché.

const ROOF := Vector3(20, 3, 10)
const LADDER_FOOT := Vector3(16.8, 0, 10)

var alpha: Commando


func _setup() -> void:
	await load_level()
	alpha = node("Units/Alpha")
	park(node("Enemies/Soldier1"))
	park(node("Enemies/TrainingDummy"), Vector3(-25, 0, -25))
	for name in ["Bravo", "Charlie"]:
		hide_from_enemies(node("Units/" + name))


func test_operator_climbs_the_ladder_to_the_roof_and_back() -> void:
	await _setup()
	alpha.global_position = Vector3(13, 0, 10)
	alpha.move_to(ROOF, false)
	var on_ladder := await frames_until(func() -> bool: return alpha._model.ladder_phase >= 0.0, 400)
	assert_gt(on_ladder, -1, "sur l'échelle")
	assert_true(alpha.is_traversing())
	assert_true(alpha._model.weapon_slung, "arme à la bretelle pour grimper")
	var up := await frames_until(func() -> bool:
		return not alpha.is_traversing() and flat_distance(alpha.global_position, ROOF) < 0.6, 900)
	assert_gt(up, -1, "sur le toit")
	assert_almost_eq(alpha.global_position.y, ROOF.y, 0.2)
	alpha.move_to(Vector3(13, 0, 10), false)
	var down := await frames_until(func() -> bool:
		return flat_distance(alpha.global_position, Vector3(13, 0, 10)) < 0.6, 900)
	assert_gt(down, -1, "redescendu")
	assert_almost_eq(alpha.global_position.y, 0.0, 0.2)
	assert_eq(alpha._model.ladder_phase, -1.0)


func test_operator_vaults_over_the_low_wall() -> void:
	await _setup()
	alpha.global_position = Vector3(20, 0, 4.5)
	var target := Vector3(20, 0, -0.5)
	alpha.move_to(target, false)
	var vaulting := await frames_until(func() -> bool: return alpha._model.climb_progress >= 0.0, 300)
	assert_gt(vaulting, -1, "il enjambe le muret")
	var highest := [0.0]
	var arrived := await frames_until(func() -> bool:
		highest[0] = maxf(highest[0], alpha.global_position.y)
		return flat_distance(alpha.global_position, target) < 0.5, 600)
	assert_gt(arrived, -1, "de l'autre côté")
	assert_gt(highest[0], 0.8, "passé par-dessus")


func test_enemy_takes_the_ladder() -> void:
	await _setup()
	var enemy: Enemy = node("Enemies/Soldier1")
	hide_from_enemies(alpha)
	enemy.global_position = Vector3(12, 0, 10)
	enemy.stationary = false
	enemy.set_physics_process(true)
	enemy._waypoints = [ROOF] as Array[Vector3]
	enemy._waypoint_index = 0
	enemy.patrol_behavior.pause_left = 0.0
	enemy._agent.target_position = ROOF
	var climbed := await frames_until(func() -> bool: return enemy.is_traversing(), 400)
	assert_gt(climbed, -1, "il grimpe")
	var up := await frames_until(func() -> bool:
		return not enemy.is_traversing() and enemy.global_position.y > ROOF.y - 0.2, 900)
	assert_gt(up, -1, "sur le toit")


func test_enemy_shoots_an_operator_on_the_roof_from_below() -> void:
	await _setup()
	var enemy: Enemy = node("Enemies/Soldier1")
	alpha.global_position = ROOF
	await frames(10)
	enemy.global_position = Vector3(12, 0, 10)
	enemy.rotation.y = -PI / 2.0
	enemy.stationary = false
	enemy.set_physics_process(true)
	var health := alpha.health.health
	var hurt := await frames_until(func() -> bool: return alpha.health.health < health, 900)
	assert_gt(hurt, -1, "touché sur son toit")
	assert_gt(flat_distance(enemy.global_position, alpha.global_position), 3.0, "tire d'en bas, sans venir dessous")
	assert_false(enemy.is_attacking(), "pas de coup au corps à corps")
