extends LevelTest
## Lampes qu'on éteint (`StreetLamp`) : lumière qui montre les opérateurs la
## nuit, ampoule brisée par une balle et changée par un garde, courant coupé
## par le groupe électrogène.

const NIGHT := "res://scenes/levels/night/night.tscn"

var lamps: Array[Node] = []


func before_each() -> void:
	super()
	await load_level(NIGHT)
	lamps = level.get_tree().get_nodes_in_group(StreetLamp.GROUP)


func test_lamps_are_adopted_and_light_a_disc() -> void:
	assert_eq(lamps.size(), 5)
	var lamp := lamps[0] as StreetLamp
	var foot := lamp.lamp.global_position
	assert_true(StreetLamp.lit_at(level.get_tree(), foot + Vector3.UP))
	assert_false(StreetLamp.lit_at(level.get_tree(), foot + Vector3(20, 1, 0)))


func test_guards_see_farther_in_the_light() -> void:
	var guard := node("Enemies/GatePatrol") as Enemy
	var unit := level.get_tree().get_nodes_in_group(&"commandos")[0] as Commando
	assert_lt(guard._vision.config.far_range, guard._day_vision.far_range, "vue réduite la nuit")
	var spot := guard.global_position - guard.global_basis.z * (guard._vision.config.far_range + 1.5)
	unit.global_position = spot
	await wait_physics_frames(1)
	for item in lamps:
		(item as StreetLamp).set_broken(true)
	assert_eq(guard._sight_zone(unit), VisionComponent.Zone.NONE, "dans le noir, trop loin")
	var lamp := lamps[0] as StreetLamp
	lamp.set_broken(false)
	lamp.lamp.global_position = Vector3(spot.x, lamp.lamp.global_position.y, spot.z)
	await wait_physics_frames(1)
	assert_eq(guard._sight_zone(unit), VisionComponent.Zone.FAR, "dans la lumière, vu de loin")


func test_shot_bulb_goes_dark_and_a_guard_replaces_it() -> void:
	var lamp := lamps[0] as StreetLamp
	lamp.take_shot(30.0, lamp.global_position, Vector3.ZERO)
	assert_true(lamp.broken)
	assert_false(lamp.is_lit())
	await wait_seconds(StreetLamp.CALL_DELAY + 0.5)
	assert_not_null(lamp._repairer, "un garde vient voir")
	assert_true(lamp._repairer.is_on_errand())
	var turns: int = await frames_until(func() -> bool: return not lamp.broken, 60 * 40)
	assert_gt(turns, -1, "ampoule changée")
	assert_true(lamp.is_lit())


func test_generator_cuts_all_lamps_and_one_guard_comes() -> void:
	var generator := node("NavigationRegion3D/Generator") as SabotageTarget
	generator.destroy()
	for item in lamps:
		assert_false((item as StreetLamp).is_lit())
	await wait_seconds(StreetLamp.CALL_DELAY + 0.5)
	var busy := level.get_tree().get_nodes_in_group(&"enemies").filter(func(e: Enemy) -> bool: return e.is_on_errand())
	assert_eq(busy.size(), 1, "un seul garde va voir le groupe électrogène")
