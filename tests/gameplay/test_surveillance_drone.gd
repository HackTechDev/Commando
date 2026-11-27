extends LevelTest
## Drone de surveillance (`SurveillanceDrone`) sur « Centre mobile 07 » :
## ronde, repérage d'en haut, brouilleur, abattu d'une balle.

const MAP := "res://scenes/levels/mobile_command/mobile_command.tscn"

var drone: SurveillanceDrone
var unit: Commando


func before_each() -> void:
	super()
	await load_level(MAP)
	drone = node("Enemies/Drone")
	unit = level.get_tree().get_nodes_in_group(&"commandos")[0]


func test_drone_patrols_at_altitude() -> void:
	var start := drone.global_position
	await wait_seconds(1.0)
	assert_almost_eq(drone.global_position.y, drone.altitude, 0.5)
	assert_gt(drone.global_position.distance_to(start), 2.0, "il avance")


func test_operator_in_the_footprint_is_spotted() -> void:
	unit.global_position = drone.spot()
	assert_true(drone.exposed(unit))
	await wait_seconds(SurveillanceDrone.SPOT_TIME + 0.5)
	assert_eq(GameState.alert_level, GameState.AlertLevel.ALARM)


func test_disguised_operator_is_ignored() -> void:
	unit.wear_disguise({"uniform": Color.TAN, "gear": Color.BROWN, "headwear": &"cap", "headwear_color": Color.DARK_RED})
	unit.global_position = drone.spot()
	assert_false(drone.exposed(unit))


func test_jammer_blinds_and_freezes() -> void:
	unit.jammers = 1
	unit.global_position = Vector3(drone.global_position.x + 5.0, 0.0, drone.global_position.z)
	assert_true(unit.use_jammer())
	assert_eq(unit.jammers, 0)
	assert_true(drone.is_jammed())
	var at := drone.global_position
	unit.global_position = drone.spot()
	await wait_seconds(1.5)
	assert_almost_eq(drone.global_position.distance_to(at), 0.0, 0.05, "figé")
	assert_false(drone.exposed(unit) and drone.is_watching(), "aveuglé")
	assert_ne(GameState.alert_level, GameState.AlertLevel.ALARM)


func test_shot_brings_it_down() -> void:
	drone.take_shot(30.0, drone.global_position, unit.global_position)
	assert_true(drone.destroyed)
	assert_false(drone.is_watching())
	await wait_seconds(2.5)
	assert_lt(drone.global_position.y, 1.0, "écrasé au sol")
