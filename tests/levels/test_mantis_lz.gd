extends LevelTest
## Carte « Le Mantis » : le transporteur lourd (`Mantis`), sa soute
## praticable (rampe et porte latérale), la coupe du toit, et les véhicules
## qui en sortent jusqu'au point de ralliement.

const MAP := "res://scenes/levels/mantis_lz/mantis_lz.tscn"
const START := Vector3(-60, 0, 58)

var ship: Mantis


func before_each() -> void:
	super()
	await load_level(MAP)
	ship = node("NavigationRegion3D/Mantis")


## Point de navigation le plus proche de `to`, et fin du chemin depuis le
## départ des opérateurs : un chemin complet finit sur ce point.
func _reach(to: Vector3) -> Array[Vector3]:
	var map := (level as Node3D).get_world_3d().navigation_map
	var from := NavigationServer3D.map_get_closest_point(map, START)
	var goal := NavigationServer3D.map_get_closest_point(map, to)
	var path := NavigationServer3D.map_get_path(map, from, goal, true)
	var end := path[path.size() - 1] if not path.is_empty() else Vector3.INF
	return [goal, end]


func test_hold_ramp_and_side_door_are_reachable() -> void:
	var spots := {
		"avant de la soute": Vector3(-7, Mantis.FLOOR_TOP, 0),
		"arrière de la soute": Vector3(16, Mantis.FLOOR_TOP, 0),
		"seuil de la porte": Vector3(-4.2, Mantis.FLOOR_TOP, 4.8),
	}
	for name: String in spots:
		var spot: Vector3 = spots[name]
		var reach := _reach(spot)
		assert_lt(absf(reach[0].y - spot.y), 0.6, "%s : navigation à la bonne hauteur" % name)
		assert_lt(reach[1].distance_to(reach[0]), 0.1, "%s : chemin complet depuis le départ" % name)


func test_hold_contains_and_floor() -> void:
	assert_true(ship.contains(Vector3(0, 1, 0)))
	assert_false(ship.contains(Vector3(0, 1, 8)), "hors des flancs")
	assert_false(ship.contains(Vector3(0, 7, 0)), "sur le toit")
	assert_almost_eq(ship.floor_at(Vector3(5, 2, 2)), Mantis.FLOOR_TOP, 0.01)
	assert_eq(ship.floor_at(Vector3(30, 0, 0)), -INF)
	assert_true(ship.is_in_group(Mantis.GROUP))


func test_operator_in_the_hold_cuts_the_roof() -> void:
	# La coupe suit le groupe des opérateurs : Alpha reste visible.
	var alpha := node("Units/Alpha") as Commando
	assert_false(ship.is_cut)
	alpha.global_position = Vector3(6, Mantis.FLOOR_TOP, 1)
	await frames_until(func() -> bool: return ship.is_cut, 60)
	assert_true(ship.is_cut, "soute en coupe")
	var roof := ship.get_node("Roof")
	assert_true(Mantis.is_revealed_body(roof), "le toit laisse passer les clics")
	assert_false(Mantis.is_revealed_body(ship.get_node("WallsLow")), "le bas des flancs reste")


func test_vehicles_fit_in_the_hold() -> void:
	for path: String in ["NavigationRegion3D/Sabre", "NavigationRegion3D/Hexapod"]:
		var vehicle := node(path) as Sabre
		assert_true(ship.contains(vehicle.global_position + Vector3.UP * 0.3), "%s dans la soute" % vehicle.name)


func test_vehicles_have_a_way_out_to_the_rally_point() -> void:
	await frames(5)
	for path: String in ["NavigationRegion3D/Sabre", "NavigationRegion3D/Hexapod"]:
		var vehicle := node(path) as Sabre
		var route := VehicleNavigation.path(vehicle, vehicle.global_position, vehicle.arrival_point, vehicle.nav_radius())
		assert_false(route.is_empty(), "%s : chemin" % vehicle.name)
		var end := route[route.size() - 1]
		assert_lt(Vector2(end.x - vehicle.arrival_point.x, end.z - vehicle.arrival_point.z).length(), 1.0, "%s : jusqu'au ralliement" % vehicle.name)


func test_fuel_bowser_completes_its_objective() -> void:
	var objectives := level.get_tree().get_first_node_in_group(Objectives.GROUP) as Objectives
	var target := node("NavigationRegion3D/FuelBowser") as SabotageTarget
	assert_eq(objectives.status_of("fuel"), Objectives.Status.PENDING)
	target.blast(target.global_position, 4.0)
	assert_eq(objectives.status_of("fuel"), Objectives.Status.DONE)
