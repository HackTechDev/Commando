extends LevelTest
## Corps à corps à plusieurs : second assaillant qui prend la cible de flanc
## et profite de sa parade ; coéquipiers qui viennent aider.


func before_each() -> void:
	super()
	await load_level()


## Alpha au contact du soldat (désarmé, en alerte) ; le mannequin, rendu
## mobile et en alerte, sera le second assaillant.
func _two_attackers() -> Array:
	var alpha: Commando = node("Units/Alpha")
	var soldier: Enemy = node("Enemies/Soldier1")
	var dummy: Enemy = node("Enemies/TrainingDummy")
	alpha.health.reset(100000.0)
	for unit in ["Units/Bravo", "Units/Charlie"]:
		node(unit).global_position += Vector3(30, 0, 30)
	soldier.armed = false
	soldier.stationary = true
	alpha.global_position = soldier.global_position - soldier.global_basis.z * 1.0
	dummy.global_position = alpha.global_position + Vector3(0, 0, 5)
	dummy.stationary = false
	dummy.look_at(alpha.global_position, Vector3.UP)
	await frames(3)
	soldier.detection = 1.0
	dummy.detection = 1.0
	dummy._last_seen = alpha.global_position
	return [alpha, soldier, dummy]


func test_second_attacker_goes_for_the_flank() -> void:
	var units := await _two_attackers()
	var alpha: Commando = units[0]
	var soldier: Enemy = units[1]
	var dummy: Enemy = units[2]
	await frames(10)
	assert_eq(dummy._target, alpha, "le mannequin voit Alpha")
	var flank := dummy.flank_point()
	assert_ne(flank, Vector3.INF, "un camarade est déjà au contact")
	var from_soldier := soldier.global_position - alpha.global_position
	var from_flank := flank - alpha.global_position
	from_soldier.y = 0.0
	from_flank.y = 0.0
	assert_almost_eq(rad_to_deg(from_soldier.angle_to(from_flank)), EnemyBrawler.FLANK_ANGLE, 1.0, "de flanc")
	assert_lt(flat_distance(dummy._agent.target_position, flank), 0.6, "il s'y rend")
	assert_eq(soldier.flank_point(), Vector3.INF, "le premier frappe de face")


func test_second_attacker_strikes_through_a_parry() -> void:
	var units := await _two_attackers()
	var alpha: Commando = units[0]
	var soldier: Enemy = units[1]
	var dummy: Enemy = units[2]
	# Le mannequin juste à côté d'Alpha, face à lui, encore en récupération.
	dummy.stationary = true
	dummy.global_position = alpha.global_position + alpha.global_basis.x * 1.0
	dummy.look_at(alpha.global_position, Vector3.UP)
	await frames(2)
	dummy.brawler.cooldown = 10.0
	var hp := alpha.health.health
	# Alpha pare le coup du soldat (touche pressée à temps).
	assert_gt(await frames_until(soldier.is_attacking, 200), -1, "le soldat frappe")
	alpha.ready_parry()
	assert_gt(await frames_until(alpha.is_defending, 60), -1, "Alpha pare")
	assert_gt(await frames_until(dummy.is_attacking, 10), -1, "le second en profite aussitôt")
	assert_gt(await frames_until(func() -> bool: return alpha.health.health < hp, 60), -1, "son coup passe")


func test_idle_teammates_come_to_help() -> void:
	var alpha: Commando = node("Units/Alpha")
	var bravo: Commando = node("Units/Bravo")
	var charlie: Commando = node("Units/Charlie")
	var soldier: Enemy = node("Enemies/Soldier1")
	park(node("Enemies/TrainingDummy"), Vector3(25, 0, 25))
	alpha.health.reset(100000.0)
	soldier.armed = false
	soldier.stationary = true
	alpha.global_position = soldier.global_position - soldier.global_basis.z * 1.0
	# Dans le dos du soldat : il ne les voit pas.
	bravo.global_position = soldier.global_position + soldier.global_basis.z * 4.0
	charlie.global_position = soldier.global_position + soldier.global_basis.z * 15.0
	await frames(3)
	bravo.stop()
	charlie.stop()
	soldier.detection = 1.0
	assert_gt(await frames_until(soldier.is_attacking, 200), -1, "le soldat frappe Alpha")
	assert_gt(await frames_until(func() -> bool: return bravo.melee_target() == soldier, 60), -1, "Bravo accourt")
	assert_null(charlie.melee_target(), "Charlie est trop loin")
	assert_gt(await frames_until(soldier.is_stunned, 600), -1, "Bravo l'assomme")
