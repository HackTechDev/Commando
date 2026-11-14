extends LevelTest
## Caisses déplaçables : saisie, poussée, traction, blocage, navigation
## recalculée.

var _crate_noises := 0


func before_each() -> void:
	super()
	_crate_noises = 0
	await load_level()
	park(node("Enemies/Soldier1"), Vector3(25, 0, 25))
	park(node("Enemies/TrainingDummy"))
	EventBus.noise_emitted.connect(_on_noise)


func after_each() -> void:
	EventBus.noise_emitted.disconnect(_on_noise)
	super()


func _on_noise(_at: Vector3, _radius: float, kind: StringName) -> void:
	if kind == &"crate":
		_crate_noises += 1


## Attend que la caisse soit immobile depuis 20 images.
func _wait_still(crate: Node3D) -> void:
	var last := crate.global_position
	var still := 0
	for i in 600:
		await get_tree().physics_frame
		still = still + 1 if crate.global_position.distance_to(last) < 0.0001 else 0
		last = crate.global_position
		if still > 20:
			return


func test_push_pull_and_release() -> void:
	var alpha: Commando = node("Units/Alpha")
	var model: SoldierModel = alpha.get_node("SoldierModel")
	var crate: Climbable = node("NavigationRegion3D/Crate4")
	var start := crate.global_position
	assert_true(alpha.handle_crate(crate, start + Vector3.LEFT))
	assert_gt(await frames_until(alpha.is_handling_crate, 600), -1, "caisse saisie")
	assert_true(model.crate_grip)
	assert_almost_eq(model._sling, 1.0, 0.01, "mains libres : arme à la bretelle")
	assert_eq(crate.handler, alpha)

	alpha.move_to(start + Vector3.RIGHT * 2.0, false)
	await _wait_still(crate)
	assert_almost_eq(crate.global_position, start + Vector3(2, 0, 0), Vector3.ONE * 0.05, "poussée de 2 m")
	assert_false(model.crate_pull)
	assert_gt(_crate_noises, 0, "la caisse fait du bruit")

	var pushed := crate.global_position
	alpha.move_to(pushed + Vector3.LEFT * 1.5, false)
	await _wait_still(crate)
	assert_almost_eq(crate.global_position, pushed + Vector3(-1.5, 0, 0), Vector3.ONE * 0.05, "tirée de 1,5 m")
	assert_true(model.crate_pull)

	await frames(60)
	assert_eq(crate.get_access_points().size(), 4, "navigation recalculée autour de la caisse")
	assert_false(node("NavigationRegion3D").is_baking())

	alpha.stop()
	await frames(60)
	assert_false(model.crate_grip)
	assert_null(crate.handler)
	assert_almost_eq(model._sling, 0.0, 0.01, "arme reprise en main")


func test_crate_stops_against_another_crate() -> void:
	var alpha: Commando = node("Units/Alpha")
	var crate: Climbable = node("NavigationRegion3D/Crate3")
	var start := crate.global_position
	assert_true(alpha.handle_crate(crate, start + Vector3.RIGHT * 2.0))
	assert_gt(await frames_until(alpha.is_handling_crate, 900), -1, "caisse saisie")
	alpha.move_to(start + Vector3.LEFT * 3.0, false)
	await _wait_still(crate)
	# Les caisses 1 et 3 sont à 0,1 m l'une de l'autre.
	assert_almost_eq((crate.global_position - start).length(), 0.1, 0.02, "arrêtée au contact de la caisse 1")
