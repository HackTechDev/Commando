extends LevelTest
## Transitions de posture : immobilité pendant le passage au sol, reptation,
## actions lancées depuis la position couchée, mort pendant une transition.

const PRONE := SoldierModel.Posture.PRONE
const STANDING := SoldierModel.Posture.STANDING


func before_each() -> void:
	super()
	await load_level()
	park(node("Enemies/Soldier1"))


func test_going_prone_stops_then_crawls() -> void:
	var alpha: Commando = node("Units/Alpha")
	var model: SoldierModel = alpha.get_node("SoldierModel")
	alpha.move_to(alpha.global_position + Vector3(4, 0, 0), false)
	await frames(20)
	alpha.toggle_posture(PRONE)
	var start := alpha.global_position
	var transition := await frames_until(func() -> bool: return not model.is_changing_posture(), 300)
	assert_gt(transition, 30, "la transition est animée")
	assert_almost_eq(alpha.global_position.distance_to(start), 0.0, 0.01, "immobile pendant la transition")
	await frames(60)
	assert_gt(alpha.global_position.distance_to(start), 0.5, "reprend son chemin en rampant")
	assert_almost_eq(model._crawl, 1.0, 0.01, "animation de reptation")


func test_knife_from_prone_stands_up_first() -> void:
	var alpha: Commando = node("Units/Alpha")
	var dummy: Enemy = node("Enemies/TrainingDummy")
	alpha.toggle_posture(PRONE)
	await frames(80)
	alpha.global_position = dummy.global_position + Vector3(2.5, 0, 0)
	await frames(5)
	alpha.melee(dummy, Commando.MeleeKind.KNIFE)
	assert_gt(await frames_until(func() -> bool: return dummy.is_dead, 400), -1, "mannequin tué")
	await frames(30)
	assert_eq(alpha.posture, STANDING, "s'est relevé pour frapper")
	assert_false(alpha.get_node("SoldierModel").is_changing_posture())


func test_climb_from_prone() -> void:
	var bravo: Commando = node("Units/Bravo")
	bravo.toggle_posture(PRONE)
	await frames(80)
	bravo.climb(node("NavigationRegion3D/Crate4"), false)
	var perched := func() -> bool: return bravo.perched_on != null and not bravo._hopping
	assert_gt(await frames_until(perched, 900), -1, "perché")
	assert_eq(bravo.posture, STANDING)
	assert_almost_eq(bravo.get_node("SoldierModel")._body.rotation.x, 0.0, 0.05, "debout sur la caisse")


func test_death_during_transition_falls_flat() -> void:
	var charlie: Commando = node("Units/Charlie")
	var model: SoldierModel = charlie.get_node("SoldierModel")
	charlie.toggle_posture(PRONE)
	await frames(20)
	charlie.health.take_damage(1000.0)
	await frames(120)
	assert_true(charlie.is_dead)
	assert_false(model.is_changing_posture())
	assert_almost_eq(model._body.rotation.x, -PI / 2.0, 0.05, "à plat ventre")


func test_dive_ends_prone_a_few_meters_away() -> void:
	var alpha: Commando = node("Units/Alpha")
	hide_from_enemies(alpha)
	alpha.global_position = Vector3(-14, 0, 2)
	await frames(5)
	var start := alpha.global_position
	var toward := start + Vector3(6, 0, 0)
	assert_true(alpha.dive(toward), "roulade")
	assert_true(alpha.is_diving())
	assert_eq(alpha.posture, SoldierModel.Posture.PRONE, "couché dès l'envol")
	assert_false(alpha.dive(toward), "pas deux à la fois")
	var landed := func() -> bool: return not alpha.is_diving()
	assert_gt(await frames_until(landed, int(SoldierModel.DIVE_TIME * 60) + 20), -1, "geste terminé")
	assert_almost_eq(flat_distance(alpha.global_position, start), DiveGesture.DISTANCE, 0.3, "plongé vers le curseur")
	assert_gt(alpha.global_position.x, start.x + 2.0, "dans la bonne direction")
	await frames(5)
	assert_false(alpha._model.is_changing_posture(), "déjà allongé")
	assert_eq(alpha.posture, SoldierModel.Posture.PRONE)
	assert_false(alpha.dive(start), "pas de roulade depuis la position couchée")
