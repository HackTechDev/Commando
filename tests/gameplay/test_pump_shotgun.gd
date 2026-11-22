extends LevelTest
## Fusil à pompe : dégâts qui baissent avec la distance, pompe manœuvrée
## après chaque tir, magasin tubulaire.


func after_each() -> void:
	super.after_each()
	OperatorRoster.use(OperatorRoster.new())


func test_damage_falls_off_with_distance() -> void:
	var base := UnitStats.new()
	var pump := GearCatalog.apply_weapon(base, &"pump_shotgun")
	assert_eq(pump.damage_at(0.0), pump.fire_damage, "plein effet à bout portant")
	assert_eq(pump.damage_at(pump.fire_range), pump.fire_damage_far, "au plus loin")
	assert_eq(pump.damage_at(50.0), pump.fire_damage_far, "pas moins au-delà")
	assert_gt(pump.damage_at(3.0), pump.damage_at(6.0), "décroît en chemin")
	var carbine := GearCatalog.apply_weapon(base, &"carbine")
	assert_eq(carbine.damage_at(carbine.fire_range), carbine.fire_damage, "les autres armes ne faiblissent pas")
	assert_true(GearCatalog.WEIGHTS.has(&"pump_shotgun"), "poids")


func test_a_close_shot_hurts_more_than_a_far_one() -> void:
	var roster := OperatorRoster.new()
	roster.operators[0].primary = &"pump_shotgun"
	OperatorRoster.use(roster)
	await load_level()
	var alpha: Commando = node("Units/Alpha")
	var dummy: Enemy = node("Enemies/TrainingDummy")
	park(node("Enemies/Soldier1"))
	# À découvert face au mannequin : aucune couverture ne s'en mêle (2.12).
	alpha.global_position = dummy.global_position + Vector3(0, 0, 4)
	await frames(2)
	assert_eq(alpha.ammo_in_magazine, 5, "magasin tubulaire de 5")
	var stats := own_stats(alpha)
	stats.hit_chance_near = 1.0
	stats.hit_chance_far = 1.0
	dummy.health.max_health = 1000.0
	dummy.health.health = 1000.0
	alpha._fire(dummy, 1.0)
	var near := 1000.0 - dummy.health.health
	alpha._fire(dummy, stats.fire_range)
	var far := 1000.0 - near - dummy.health.health
	assert_almost_eq(near, stats.damage_at(1.0), 0.01, "presque plein effet de près")
	assert_almost_eq(far, stats.fire_damage_far, 0.01, "plombs dispersés de loin")
	assert_gt(near, far * 2.0)


func test_the_pump_is_worked_after_each_shot() -> void:
	var model := SoldierModel.new()
	model.silent = true
	add_child_autofree(model)
	var outfit := OperatorProfile.defaults(0)
	outfit.primary = &"pump_shotgun"
	model.outfit = outfit
	var pump: Node3D = model.find_child("Pump", true, false)
	assert_not_null(pump, "garde-main mobile")
	assert_not_null(model.find_child("TubeMagazine", true, false), "magasin tubulaire")
	var hand: Node3D = model.find_child("ShoulderL", true, false).find_child("Hand", true, false)
	_run(model, 0.5)
	var rest := pump.position.z
	var hand_rest := hand.global_position
	model.play_shot()
	var travel := 0.0
	var hand_travel := 0.0
	for i in 60:
		model._process(1.0 / 60.0)
		travel = maxf(travel, pump.position.z - rest)
		hand_travel = maxf(hand_travel, hand.global_position.distance_to(hand_rest))
	assert_gt(travel, 0.06, "la pompe recule")
	assert_gt(hand_travel, 0.05, "la main gauche la suit")
	assert_almost_eq(pump.position.z, rest, 0.001, "puis revient en place")


func _run(model: SoldierModel, seconds: float) -> void:
	for i in int(seconds * 60.0):
		model._process(1.0 / 60.0)
