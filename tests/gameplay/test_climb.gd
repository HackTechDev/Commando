extends LevelTest
## Escalade des caisses : monter, passer d'une caisse à sa voisine, redescendre,
## arme passée à la bretelle avant de grimper.


func before_each() -> void:
	super()
	await load_level()
	park(node("Enemies/Soldier1"))


func test_climb_walk_to_neighbour_and_descend() -> void:
	var alpha: Commando = node("Units/Alpha")
	var crate1: Climbable = node("NavigationRegion3D/Crate1")
	var crate2: Climbable = node("NavigationRegion3D/Crate2")

	assert_true(alpha.climb(crate1, false), "ordre d'escalade accepté")
	var perched := func() -> bool: return alpha.perched_on == crate1 and not alpha._hopping
	assert_gt(await frames_until(perched, 900), -1, "perché sur la caisse 1")
	assert_almost_eq(alpha.global_position.y, 1.2, 0.05, "debout sur le dessus")
	assert_eq(crate1.occupant, alpha)

	assert_true(alpha.climb(crate2, false), "passage vers la caisse voisine")
	perched = func() -> bool: return alpha.perched_on == crate2 and not alpha._hopping
	assert_gt(await frames_until(perched, 600), -1, "perché sur la caisse 2")
	assert_almost_eq(alpha.global_position.y, 1.2, 0.05)
	assert_null(crate1.occupant, "la caisse 1 est libérée")

	var goal := Vector3(-12, 0, 9)
	alpha.move_to(goal, false)
	var arrived := func() -> bool:
		return alpha.perched_on == null and not alpha._hopping and alpha.global_position.distance_to(goal) < 0.6
	assert_gt(await frames_until(arrived, 900), -1, "redescendu et arrivé")
	assert_null(crate2.occupant, "la caisse 2 est libérée")


func test_weapon_slung_before_climbing_then_back_in_hands() -> void:
	var alpha: Commando = node("Units/Alpha")
	var model: SoldierModel = alpha.get_node("SoldierModel")
	var crate: Climbable = node("NavigationRegion3D/Crate4")
	# Au pied de la caisse : l'opérateur doit d'abord passer l'arme à la bretelle.
	alpha.global_position = crate.get_nearest_access(alpha.global_position)["point"]
	await frames(5)
	alpha.climb(crate, false)

	var climb_started := func() -> bool: return model.climb_progress >= 0.0
	assert_gt(await frames_until(climb_started, 600), 10, "le geste de bretelle précède l'escalade")
	assert_almost_eq(model._sling, 1.0, 0.01, "arme à la bretelle au début de l'escalade")
	var perched := func() -> bool: return alpha.perched_on == crate and not alpha._hopping
	assert_gt(await frames_until(perched, 600), -1, "perché")
	await frames(60)
	assert_true(model.is_weapon_ready(), "arme reprise en main une fois en haut")


func test_cannot_climb_a_crate_held_by_another_operator() -> void:
	var alpha: Commando = node("Units/Alpha")
	var bravo: Commando = node("Units/Bravo")
	park(node("Enemies/TrainingDummy"), Vector3(25, 0, 25))
	var crate: Climbable = node("NavigationRegion3D/Crate4")
	assert_true(alpha.handle_crate(crate, crate.global_position + Vector3.LEFT))
	assert_gt(await frames_until(alpha.is_handling_crate, 600), -1, "caisse saisie")
	assert_false(bravo.climb(crate, false), "escalade refusée")


func test_jump_trajectory_rises_then_falls_to_the_ground() -> void:
	var previous := Commando._jump_progress(0.0)
	assert_eq(previous, Vector2.ZERO)
	var highest := 0.0
	for i in range(1, 101):
		var progress := Commando._jump_progress(i / 100.0)
		assert_gte(progress.x, previous.x - 0.0001, "toujours vers l'avant")
		highest = minf(highest, progress.y)
		previous = progress
	assert_lt(highest, 0.0, "impulsion vers le haut")
	assert_eq(Commando._jump_progress(Commando.JUMP_LANDING), Vector2.ONE, "au sol à la réception")
