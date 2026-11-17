extends LevelTest
## Tir libre : rafale sur un mur, un objet ou le sol ; les objets
## destructibles cèdent sous les balles.

var _noises: Array = []


func before_each() -> void:
	super()
	_noises.clear()
	await load_level()
	park(node("Enemies/Soldier1"))
	park(node("Enemies/TrainingDummy"), Vector3(25, 0, 25))
	for name in ["Alpha", "Bravo", "Charlie"]:
		hide_from_enemies(node("Units/" + name))
	EventBus.noise_emitted.connect(_on_noise)


func after_each() -> void:
	EventBus.noise_emitted.disconnect(_on_noise)
	SelectionManager.set_planning(false)
	SelectionManager.clear()
	super()


func _on_noise(_at: Vector3, _radius: float, kind: StringName) -> void:
	_noises.append(kind)


func test_a_burst_is_fired_at_the_point() -> void:
	var alpha: Commando = node("Units/Alpha")
	var ammo := alpha.ammo_in_magazine + alpha.ammo_reserve
	var spot := alpha.global_position + Vector3(0, 0, -8)
	assert_true(alpha.fire_at(spot), "ordre accepté")
	assert_gt(await frames_until(func() -> bool: return alpha._model.aiming, 120), -1, "il épaule")
	assert_gt(await frames_until(func() -> bool: return not (alpha._order is FireAtOrder), 600), -1, "rafale terminée")
	assert_eq(ammo - (alpha.ammo_in_magazine + alpha.ammo_reserve), FireAtOrder.BURST, "cinq coups")
	assert_has(_noises, &"gunshot", "on l'entend")


func test_fragile_wall_falls_under_the_bullets() -> void:
	var alpha: Commando = node("Units/Alpha")
	var wall: FragileWall = node("NavigationRegion3D/FragileWall")
	alpha.global_position = wall.global_position + Vector3(0, 0, -7)
	await frames(5)
	var target := wall.global_position + Vector3(0, 1.2, 0)
	for burst in 4:
		if wall.is_broken:
			break
		assert_true(alpha.fire_at(target))
		await frames_until(func() -> bool: return not (alpha._order is FireAtOrder), 600)
	assert_true(wall.is_broken, "le mur a cédé")
	assert_gt(wall.damage_taken, 0.0)


func test_a_crate_is_shot_to_pieces_but_not_an_occupied_one() -> void:
	var alpha: Commando = node("Units/Alpha")
	var crate: Climbable = node("NavigationRegion3D/Crate4")
	alpha.global_position = crate.global_position + Vector3(-7, 0, 0)
	await frames(5)
	var target := crate.global_position + Vector3(0, 0.6, 0)
	for burst in 3:
		if crate.is_broken:
			break
		alpha.fire_at(target)
		await frames_until(func() -> bool: return not (alpha._order is FireAtOrder), 600)
	assert_true(crate.is_broken, "caisse en morceaux")
	var other: Climbable = node("NavigationRegion3D/Crate5")
	other.occupant = node("Units/Bravo")
	other.take_shot(1000.0, other.global_position, alpha.global_position)
	assert_false(other.is_broken, "quelqu'un dessus : elle tient")
	other.occupant = null


func test_an_enemy_in_the_line_of_fire_is_hit() -> void:
	var alpha: Commando = node("Units/Alpha")
	var dummy: Enemy = node("Enemies/TrainingDummy")
	dummy.blind = true
	alpha.global_position = dummy.global_position + Vector3(0, 0, 6)
	await frames(5)
	var hp := dummy.health.health
	seed(3)
	alpha.fire_at(dummy.global_position + Vector3(0, 1.0, -4.0))
	await frames_until(func() -> bool: return not (alpha._order is FireAtOrder), 600)
	assert_lt(dummy.health.health, hp, "touché au passage")


func test_free_fire_can_be_planned() -> void:
	var alpha: Commando = node("Units/Alpha")
	SelectionManager.select([alpha] as Array[Commando])
	SelectionManager.set_planning(true)
	assert_true(SelectionManager.order_fire_at(alpha.global_position + Vector3(0, 0, -6)))
	await frames(10)
	assert_false(alpha._order is FireAtOrder, "en attente")
	SelectionManager.execute_plans()
	assert_true(alpha._order is FireAtOrder, "lancé")
