extends LevelTest
## Lancer de couteau : élimination à distance, couteau à ramasser, lancer raté.


func before_each() -> void:
	super()
	await load_level()
	park(node("Enemies/Soldier1"))


func _knives() -> Array[Node]:
	return get_tree().get_nodes_in_group(&"knife_pickups")


func test_throw_kills_from_seven_meters_then_knife_is_picked_up() -> void:
	var alpha: Commando = node("Units/Alpha")
	var dummy: Enemy = node("Enemies/TrainingDummy")
	alpha.global_position = dummy.global_position + dummy.global_basis.z * 10.0
	await frames(3)
	assert_true(alpha.throw_knife(dummy), "ordre accepté")
	var throw_distance := [-1.0]
	var landed := func() -> bool:
		if alpha.is_throwing() and throw_distance[0] < 0.0:
			throw_distance[0] = flat_distance(alpha.global_position, dummy.global_position)
		return dummy.is_dead and not _knives().is_empty()
	assert_gt(await frames_until(landed, 400), -1, "cible tuée, couteau au sol")
	assert_between(throw_distance[0], 6.0, alpha.stats.throw_range, "lancé dès qu'à portée")
	assert_eq(alpha.throwing_knives, 0)
	assert_false(alpha.throw_knife(dummy), "plus de couteau à lancer")

	alpha.move_to(_knives()[0].global_position, false)
	assert_gt(await frames_until(func() -> bool: return alpha.throwing_knives > 0, 600), -1, "couteau ramassé")
	assert_eq(_knives().size(), 0)


func test_missed_throw_startles_the_target() -> void:
	var alpha: Commando = node("Units/Alpha")
	var dummy: Enemy = node("Enemies/TrainingDummy")
	var stats := own_stats(alpha)
	stats.throw_hit_chance_far = 0.0
	stats.throw_sure_range = 0.0
	alpha.global_position = dummy.global_position + dummy.global_basis.z * 6.8
	await frames(3)
	alpha.throw_knife(dummy)
	assert_gt(await frames_until(func() -> bool: return not _knives().is_empty(), 300), -1, "couteau tombé")
	await frames(10)
	assert_false(dummy.is_dead, "raté")
	assert_eq(dummy.state, Enemy.State.SUSPICIOUS, "la cible entend la lame et se méfie")
	assert_lt(_knives()[0].global_position.distance_to(dummy.global_position), 3.0, "couteau tombé près de lui")
