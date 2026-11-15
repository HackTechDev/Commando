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
	var knife: ThrownKnife = _knives()[0]
	assert_true(knife.is_planted(), "planté dans le corps")
	await frames(90)
	var model: SoldierModel = dummy.get_node("SoldierModel")
	assert_true(model.is_ancestor_of(knife), "il suit le corps dans sa chute")
	assert_lt(knife.global_position.y, 0.6, "sur le corps au sol")
	assert_lt(flat_distance(knife.global_position, dummy.global_position), 1.6, "sur le corps, pas à côté")

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


func test_a_pebble_draws_an_enemy_to_look() -> void:
	var alpha: Commando = node("Units/Alpha")
	var dummy: Enemy = node("Enemies/TrainingDummy")
	var soldier: Enemy = node("Enemies/Soldier1")
	park(dummy, Vector3(25, 0, 25))
	for unit in ["Units/Alpha", "Units/Bravo", "Units/Charlie"]:
		hide_from_enemies(node(unit))
	soldier.set_physics_process(true)
	soldier.global_position = Vector3(-10, 0, 4)
	# Le caillou tombe à 5 m de lui ; Alpha le lance de 8 m.
	var spot := soldier.global_position + Vector3(0, 0, 5)
	alpha.global_position = spot + Vector3(8, 0, 0)
	await frames(5)
	var knives := alpha.throwing_knives
	assert_true(alpha.throw_pebble(spot), "ordre accepté")
	assert_gt(await frames_until(func() -> bool: return soldier.investigating, 200), -1, "il entend le caillou")
	assert_eq(alpha.throwing_knives, knives, "pas un couteau")
	assert_eq(soldier.state, Enemy.State.SUSPICIOUS, "méfiant, pas en alerte")
	assert_gt(await frames_until(func() -> bool: return flat_distance(soldier.global_position, spot) < 1.0, 600), -1, "il va voir")
	assert_gt(await frames_until(func() -> bool: return soldier.state == Enemy.State.PATROL, 1200), -1, "puis reprend sa ronde")


func test_throw_key_on_the_ground_throws_a_pebble() -> void:
	var alpha: Commando = node("Units/Alpha")
	var controller: PlayerController = node("HUD/PlayerController")
	SelectionManager.select([alpha] as Array[Commando], false)
	controller.toggle_pending_action(PlayerController.ACTION_THROW)
	var spot := alpha.global_position + Vector3(4, 0, 0)
	var at := get_viewport().get_camera_3d().unproject_position(spot)
	controller._use_pending_action(at)
	assert_true(alpha._order is GrenadeOrder and (alpha._order as GrenadeOrder).pebble, "caillou en route")
	var landed := func() -> bool:
		for node in level.get_children():
			if node is Pebble and node.has_landed():
				return true
		return false
	assert_gt(await frames_until(landed, 300), -1, "caillou tombé")
