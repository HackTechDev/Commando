extends LevelTest
## Pause tactique (ordres possibles pendant la pause) et ordres simultanés
## (préparés un par un, lancés ensemble).

var controller: PlayerController
var alpha: Commando
var bravo: Commando


func _setup() -> void:
	await load_level()
	controller = node("HUD/PlayerController")
	alpha = node("Units/Alpha")
	bravo = node("Units/Bravo")
	park(node("Enemies/Soldier1"))
	park(node("Enemies/TrainingDummy"))
	hide_from_enemies(node("Units/Charlie"))


func after_each() -> void:
	get_tree().paused = false
	SelectionManager.set_planning(false)
	super()


func _press(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	controller._unhandled_input(event)


func _process_frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func test_orders_given_during_the_tactical_pause_start_when_it_ends() -> void:
	await _setup()
	_press(&"tactical_pause")
	assert_true(get_tree().paused)
	assert_true(controller.tactical_paused)
	assert_true(controller.get_node("Banner").visible, "bandeau de pause")
	var start := alpha.global_position
	SelectionManager.select([alpha] as Array[Commando])
	SelectionManager.order_move(Vector3(0, 0, 8), false)
	await _process_frames(30)
	assert_lt(flat_distance(alpha.global_position, start), 0.01, "rien ne bouge en pause")
	_press(&"tactical_pause")
	assert_false(get_tree().paused)
	var moved := await frames_until(func() -> bool: return flat_distance(alpha.global_position, start) > 1.0, 300)
	assert_gt(moved, -1, "l'ordre part à la reprise")


func test_tactical_pause_does_not_override_another_pause() -> void:
	await _setup()
	get_tree().paused = true
	controller.set_tactical_pause(true)
	assert_false(controller.tactical_paused)
	get_tree().paused = false


func test_simultaneous_orders_are_planned_then_executed_together() -> void:
	await _setup()
	_press(&"plan_orders")
	assert_true(SelectionManager.planning)
	var alpha_start := alpha.global_position
	var bravo_start := bravo.global_position
	SelectionManager.select([alpha] as Array[Commando])
	SelectionManager.order_move(Vector3(-4, 0, 8), false)
	SelectionManager.select([bravo] as Array[Commando])
	SelectionManager.order_move(Vector3(4, 0, 8), false)
	# Un nouvel ordre remplace le précédent pour la même unité.
	SelectionManager.order_move(Vector3(5, 0, 8), true)
	assert_eq(SelectionManager.planned_orders().size(), 2)
	assert_eq(SelectionManager.planned_orders()[bravo]["point"], Vector3(5, 0, 8))
	await frames(20)
	assert_lt(flat_distance(alpha.global_position, alpha_start), 0.01, "ordres en attente")
	assert_lt(flat_distance(bravo.global_position, bravo_start), 0.01)
	_press(&"execute_orders")
	assert_false(SelectionManager.planning)
	assert_true(SelectionManager.planned_orders().is_empty())
	var both := await frames_until(func() -> bool:
		return flat_distance(alpha.global_position, alpha_start) > 1.0 and flat_distance(bravo.global_position, bravo_start) > 1.0, 300)
	assert_gt(both, -1, "les deux partent ensemble")


func test_leaving_planning_discards_the_orders() -> void:
	await _setup()
	_press(&"plan_orders")
	SelectionManager.select([alpha] as Array[Commando])
	var start := alpha.global_position
	SelectionManager.order_move(Vector3(0, 0, 8), false)
	_press(&"plan_orders")
	assert_false(SelectionManager.planning)
	assert_true(SelectionManager.planned_orders().is_empty())
	_press(&"execute_orders")
	await frames(30)
	assert_lt(flat_distance(alpha.global_position, start), 0.01, "abandonnés")


func test_detonation_and_dive_are_planned_too() -> void:
	await _setup()
	alpha.explosives = 1
	assert_true(alpha.plant_explosive())
	assert_gt(await frames_until(func() -> bool: return not ExplosiveCharge.planted_by(get_tree(), alpha).is_empty(), 300), -1, "charge posée")
	await frames(5)
	alpha.global_position += Vector3(0, 0, 12)
	bravo.global_position += Vector3(0, 0, 14)
	await frames(5)
	_press(&"plan_orders")
	SelectionManager.select([alpha] as Array[Commando])
	assert_gt(SelectionManager.detonate_explosives(), 0, "mise à feu préparée")
	SelectionManager.select([bravo] as Array[Commando])
	assert_true(SelectionManager.dive(bravo.global_position + Vector3(3, 0, 0)), "roulade préparée")
	assert_eq(SelectionManager.planned_orders()[alpha]["kind"], &"detonate")
	assert_eq(SelectionManager.planned_orders()[bravo]["kind"], &"dive")
	await frames(10)
	assert_eq(ExplosiveCharge.planted_by(get_tree(), alpha).size(), 1, "pas encore sautée")
	assert_ne(bravo.posture, SoldierModel.Posture.PRONE, "pas encore plongé")
	_press(&"execute_orders")
	assert_true(bravo.is_diving(), "roulade lancée")
	assert_eq(ExplosiveCharge.planted_by(get_tree(), alpha).size(), 0, "sautée")
	assert_gt(await frames_until(func() -> bool: return bravo.posture == SoldierModel.Posture.PRONE, 200), -1, "plongé en même temps")
