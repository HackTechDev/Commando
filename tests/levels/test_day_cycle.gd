extends LevelTest
## Heure qui avance (`DayCycle`) sur « Nuit sans lune » : obscurité selon
## l'heure, annonces avant l'aube, jour qui allonge la vue des gardes et
## manque le bonus « repartir avant l'aube ».

const NIGHT := "res://scenes/levels/night/night.tscn"


func before_each() -> void:
	super()
	await load_level(NIGHT)


func _go_to(clock: OperationClock, hour: float) -> void:
	clock.elapsed = (hour - clock.start_hour()) * 60.0 / clock.time_flow
	await wait_seconds(DayCycle.REFRESH_INTERVAL * 2.0 + 0.1)


func test_darkness_follows_the_hour() -> void:
	assert_eq(DayCycle.darkness_at(1.75), 1.0)
	assert_eq(DayCycle.darkness_at(12.0), 0.0)
	assert_almost_eq(DayCycle.darkness_at((DayCycle.DAWN_START + DayCycle.DAWN_END) * 0.5), 0.5, 0.01)
	assert_almost_eq(DayCycle.darkness_at((DayCycle.DUSK_START + DayCycle.DUSK_END) * 0.5), 0.5, 0.01)


func test_clock_advances_with_time_flow() -> void:
	var clock := OperationClock.of(level.get_tree())
	assert_gt(clock.time_flow, 0.0)
	assert_almost_eq(clock.start_hour(), 1.75, 0.01)
	clock.elapsed = 60.0
	assert_almost_eq(clock.current_hour(), 1.75 + clock.time_flow, 0.001)


func test_dawn_warnings_sight_and_bonus() -> void:
	var root := level as LevelRoot
	var clock := OperationClock.of(level.get_tree())
	var guard := node("Enemies/GatePatrol") as Enemy
	var radio := level.get_tree().root.find_child("RadioLog", true, false) as RadioLog
	var night_range := guard._vision.config.far_range
	assert_lt(night_range, guard._day_vision.far_range)
	await _go_to(clock, 4.6)
	assert_true(radio.lines().any(func(line: String) -> bool: return line.contains("30 minutes")))
	assert_true(LevelRoot.is_night(guard))
	await _go_to(clock, 7.0)
	assert_eq(root.darkness(), 0.0)
	assert_false(LevelRoot.is_night(guard))
	await wait_seconds(Enemy.SIGHT_CHECK_INTERVAL + 0.2)
	assert_almost_eq(guard._vision.config.far_range, guard._day_vision.far_range, 0.01, "de jour, vue entière")
	assert_false((level.get_node("NightVision") as NightVision).active, "jumelles relevées")
	var objectives := level.get_tree().get_first_node_in_group(Objectives.GROUP) as Objectives
	assert_eq(objectives.status_of("before_dawn"), Objectives.Status.FAILED)
