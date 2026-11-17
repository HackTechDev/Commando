extends LevelTest
## Grenade fumigène (nuage qui coupe la vue des ennemis) et gestes de lancer
## (par-dessus l'épaule, à la cuillère, du poignet).


func before_each() -> void:
	super()
	var roster := OperatorRoster.new()
	roster.operators[0].smoke_grenades = 2
	roster.operators[0].grenades = 1
	OperatorRoster.use(roster)
	await load_level()
	park(node("Enemies/TrainingDummy"), Vector3(25, 0, 25))


func after_each() -> void:
	OperatorRoster.use(OperatorRoster.new())
	super()


func _clouds() -> Array[Node]:
	return get_tree().get_nodes_in_group(SmokeCloud.GROUP)


func test_smoke_cloud_hides_an_operator_from_a_sentry() -> void:
	var alpha: Commando = node("Units/Alpha")
	var soldier: Enemy = node("Enemies/Soldier1")
	soldier.stationary = true
	var vision: VisionComponent = soldier.get_node("VisionComponent")
	alpha.global_position = soldier.global_position - soldier.global_basis.z * 9.0
	await frames(3)
	assert_ne(vision.check(alpha), VisionComponent.Zone.NONE, "vu sans fumée")
	hide_from_enemies(alpha)
	var middle := soldier.global_position - soldier.global_basis.z * 4.5
	assert_eq(alpha.smoke_grenades, 2)
	assert_true(alpha.throw_smoke(middle), "ordre accepté")
	assert_gt(await frames_until(func() -> bool: return not _clouds().is_empty(), 400), -1, "nuage formé")
	assert_eq(alpha.smoke_grenades, 1, "un fumigène lancé")
	assert_eq(alpha.grenades, 1, "la grenade explosive reste")
	var cloud: SmokeCloud = _clouds()[0]
	assert_lt(flat_distance(cloud.global_position, middle), 0.5, "au point visé")
	await frames(int(SmokeCloud.GROW_TIME * 60.0) + 10)
	assert_eq(vision.check(alpha), VisionComponent.Zone.NONE, "caché par la fumée")
	assert_false(soldier.is_dead, "la fumée ne blesse pas")
	# Le nuage se dissipe.
	cloud._time = SmokeCloud.LIFETIME - 0.1
	await frames(10)
	assert_eq(_clouds().size(), 0, "dissipé")
	assert_ne(vision.check(alpha), VisionComponent.Zone.NONE, "de nouveau vu")


func test_cloud_blocks_lines_through_it_only() -> void:
	var cloud := SmokeCloud.spawn(get_tree().current_scene, Vector3(30, 0, 30))
	cloud._time = SmokeCloud.GROW_TIME
	var eye := Vector3(1.7, 1.6, 0)
	assert_true(SmokeCloud.blocks_sight(get_tree(), Vector3(20, 1.6, 30), Vector3(40, 1.0, 30)), "à travers")
	assert_true(SmokeCloud.blocks_sight(get_tree(), Vector3(30, 1.6, 30), Vector3(50, 1.0, 50)), "depuis l'intérieur")
	assert_false(SmokeCloud.blocks_sight(get_tree(), Vector3(20, 1.6, 40), Vector3(40, 1.0, 40)), "à côté")
	assert_false(SmokeCloud.blocks_sight(get_tree(), eye, eye + Vector3(5, 0, 0)), "loin")
	cloud._time = 0.0
	assert_false(SmokeCloud.blocks_sight(get_tree(), Vector3(20, 1.6, 30), Vector3(40, 1.0, 30)), "pas encore épais")
	cloud.queue_free()


func test_no_smoke_left_refuses_the_order() -> void:
	var bravo: Commando = node("Units/Bravo")
	assert_eq(bravo.smoke_grenades, 0)
	assert_false(bravo.throw_smoke(bravo.global_position + Vector3(4, 0, 0)))
	assert_eq(bravo.hint_text(), "Plus de fumigène")


func test_throw_style_depends_on_object_and_distance() -> void:
	assert_eq(ThrowGesture.style_for(SoldierModel.ThrowObject.GRENADE, 10.0), SoldierModel.ThrowStyle.OVERHAND, "loin : par-dessus l'épaule")
	assert_eq(ThrowGesture.style_for(SoldierModel.ThrowObject.SMOKE, 3.0), SoldierModel.ThrowStyle.LOB, "près : à la cuillère")
	assert_eq(ThrowGesture.style_for(SoldierModel.ThrowObject.PEBBLE, 10.0), SoldierModel.ThrowStyle.FLICK, "caillou : du poignet")
	assert_eq(ThrowGesture.style_for(SoldierModel.ThrowObject.KNIFE, 5.0), SoldierModel.ThrowStyle.KNIFE)
	for style: SoldierModel.ThrowStyle in SoldierModel.THROWS:
		var toss: Dictionary = SoldierModel.THROWS[style]
		var times: Array[float] = toss["times"]
		assert_eq((toss["left"] as Array).size(), times.size(), "%d : main gauche" % style)
		assert_eq((toss["right"] as Array).size(), times.size(), "%d : main droite" % style)
		assert_between(SoldierModel.throw_release(style), 0.3, 0.8)


func test_grenade_is_held_then_released_with_the_overhand_throw() -> void:
	var alpha: Commando = node("Units/Alpha")
	hide_from_enemies(alpha)
	var model: SoldierModel = alpha.get_node("SoldierModel")
	var spot := alpha.global_position + Vector3(0, 0, -10)
	assert_true(alpha.throw_smoke(spot))
	assert_gt(await frames_until(func() -> bool: return alpha.is_throwing(), 200), -1, "geste commencé")
	assert_eq(model.throw_style, SoldierModel.ThrowStyle.OVERHAND)
	assert_eq(model.throw_object, SoldierModel.ThrowObject.SMOKE)
	await frames(5)
	assert_true(model._hand_smoke.visible, "fumigène en main")
	assert_false(model._hand_grenade.visible)
	assert_gt(await frames_until(func() -> bool: return not model._hand_smoke.visible, 200), -1, "lâché")
	assert_gt(model.throw_progress, SoldierModel.throw_release(SoldierModel.ThrowStyle.OVERHAND) - 0.05, "à l'instant du lâcher")
	assert_eq(alpha.smoke_grenades, 1)
	assert_gt(await frames_until(func() -> bool: return not alpha.is_throwing(), 200), -1, "geste fini")


func test_smoke_count_is_saved_and_bounded() -> void:
	var alpha: Commando = node("Units/Alpha")
	var before := alpha.save_state()
	alpha.smoke_grenades = 0
	alpha.load_state(before)
	assert_eq(alpha.smoke_grenades, 2, "rechargé")
	var profile := OperatorProfile.from_dict({"smoke_grenades": 99}, 0)
	assert_eq(profile.smoke_grenades, GearCatalog.EQUIPMENT[&"smoke_grenades"]["max"], "nombre borné")
