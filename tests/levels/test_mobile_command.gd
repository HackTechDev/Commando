extends LevelTest
## Carte « Centre mobile 07 » : les deux versions du centre de commandement
## (`CommandCenter`), praticables par la navigation, et leurs objectifs.

const MAP := "res://scenes/levels/mobile_command/mobile_command.tscn"
const START := Vector3(-64, 0, 66)

var deployed: CommandCenter
var closed: CommandCenter


func before_each() -> void:
	super()
	await load_level(MAP)
	deployed = node("NavigationRegion3D/CommandCenter07")
	closed = node("NavigationRegion3D/CommandCenter12")


## Point de navigation le plus proche de `to`, et fin du chemin depuis le
## départ des opérateurs : un chemin complet finit sur ce point.
func _reach(to: Vector3) -> Array[Vector3]:
	var map := (level as Node3D).get_world_3d().navigation_map
	var from := NavigationServer3D.map_get_closest_point(map, START)
	var goal := NavigationServer3D.map_get_closest_point(map, to)
	var path := NavigationServer3D.map_get_path(map, from, goal, true)
	var end := path[path.size() - 1] if not path.is_empty() else Vector3.INF
	return [goal, end]


func test_two_versions_of_the_command_center() -> void:
	assert_true(deployed.deployed)
	assert_false(closed.deployed)
	assert_not_null(deployed.ops_room, "salle des opérations sur le pont")
	assert_null(closed.ops_room)
	assert_true(deployed.ops_room.is_in_group(Tower.GROUP))


func test_decks_room_roof_and_balcony_are_reachable() -> void:
	var spots := {
		"pont": Vector3(5, CommandCenter.DECK_TOP, -14),
		"salle": Vector3(10.5, CommandCenter.DECK_TOP, -24),
		"toit": Vector3(12, CommandCenter.DECK_TOP + CommandCenter.OPS_HEIGHT, -21.5),
		"sous le pont": Vector3(5, 0, -14),
		"plateau replié": Vector3(46, CommandCenter.DECK_TOP, 30),
		"coursive": Vector3(45.1, CommandCenter.BALCONY_TOP, 26),
	}
	for name: String in spots:
		var spot: Vector3 = spots[name]
		var reach := _reach(spot)
		assert_lt(absf(reach[0].y - spot.y), 0.6, "%s : navigation à la bonne hauteur" % name)
		assert_lt(reach[1].distance_to(reach[0]), 0.1, "%s : chemin complet depuis le départ" % name)


func test_floor_heights() -> void:
	assert_almost_eq(deployed.floor_at(Vector3(5, 3, -14)), CommandCenter.DECK_TOP, 0.01)
	assert_almost_eq(deployed.floor_at(Vector3(10, 6, -24)), CommandCenter.DECK_TOP + CommandCenter.OPS_HEIGHT, 0.01)
	assert_eq(deployed.floor_at(Vector3(5, 0, 20)), -INF)
	# Centre replié tourné d'un quart de tour : la coursive est à l'ouest.
	assert_almost_eq(closed.floor_at(Vector3(45.1, 5.5, 26)), CommandCenter.BALCONY_TOP, 0.01)


func test_guards_stand_on_the_decks() -> void:
	frames(30)
	assert_gt((node("Enemies/DeckSentry") as Node3D).global_position.y, 2.2)
	assert_gt((node("Enemies/RoofSentry") as Node3D).global_position.y, 5.4)
	assert_gt((node("Enemies/ClosedBalconyGuard") as Node3D).global_position.y, 4.8)


func test_generators_complete_their_objectives() -> void:
	var objectives := level.get_tree().get_first_node_in_group(Objectives.GROUP) as Objectives
	for spec: Array in [["NavigationRegion3D/CommandCenter07/OpsGenerator", "power_deployed"], ["NavigationRegion3D/CommandCenter12/BedGenerator", "power_closed"]]:
		var target := node(spec[0]) as SabotageTarget
		assert_eq(objectives.status_of(spec[1]), Objectives.Status.PENDING)
		target.blast(target.global_position, 4.0)
		assert_eq(objectives.status_of(spec[1]), Objectives.Status.DONE, spec[1])
