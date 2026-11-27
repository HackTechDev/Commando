extends LevelTest
## Carte « Le Mantis » : le transporteur lourd (`Mantis`), sa soute
## praticable (rampe et porte latérale), la coupe du toit, la rampe manœuvrée
## au tableau, le décollage avec l'équipe et les véhicules, et le second
## Mantis qui arrive avec des renforts.

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


## Opérateurs et ennemis hors jeu, pour les manœuvres sans alerte.
func _clear_enemies() -> void:
	for enemy in level.get_tree().get_nodes_in_group(Enemy.ALL_GROUP):
		park(enemy as Enemy)
	var truck := node("Enemies/Technical") as Node3D
	truck.process_mode = Node.PROCESS_MODE_DISABLED
	truck.global_position = Vector3(-60, 0, 70)


func test_vehicles_can_drive_into_the_hold() -> void:
	await frames(5)
	var parking := {"NavigationRegion3D/Hexapod": Vector3(-4, Mantis.FLOOR_TOP, 0), "NavigationRegion3D/Sabre": Vector3(10, Mantis.FLOOR_TOP, -2.5)}
	for path: String in parking:
		var vehicle := node(path) as Sabre
		var goal: Vector3 = parking[path]
		assert_false(ship.contains(vehicle.global_position + Vector3.UP * 0.3), "%s dehors au départ" % vehicle.name)
		var route := VehicleNavigation.path(vehicle, vehicle.global_position, goal, vehicle.nav_radius())
		assert_false(route.is_empty(), "%s : chemin" % vehicle.name)
		var end := route[route.size() - 1]
		assert_lt(Vector2(end.x - goal.x, end.z - goal.z).length(), 1.0, "%s : jusque dans la soute" % vehicle.name)


func test_ramp_is_worked_from_the_panel() -> void:
	_clear_enemies()
	var alpha := node("Units/Alpha") as Commando
	alpha.global_position = Vector3(10, Mantis.FLOOR_TOP, 2)
	await frames(2)
	assert_eq(ship.ramp_problem(alpha), "au tableau près de la porte")
	assert_false(ship.set_ramp_down(false, alpha))
	alpha.global_position = ship.panel_point() + Vector3(0.6, 0, -0.4)
	await frames(2)
	assert_eq(ship.ramp_problem(alpha), "")
	assert_true(ship.set_ramp_down(false, alpha), "rampe relevée")
	await frames_until(func() -> bool: return not ship.ramp_moving, 300)
	assert_false(ship.ramp_down)
	assert_eq(ship.ramp_body.collision_layer, Mantis.LAYER_OBSTACLE, "relevée : elle ferme la soute")
	assert_true(ship.set_ramp_down(true, alpha), "rampe abaissée")
	await frames_until(func() -> bool: return not ship.ramp_moving, 300)
	assert_eq(ship.ramp_body.collision_layer, Mantis.LAYER_FLOOR, "abaissée : un sol")
	# Quelqu'un sur la rampe : on ne la relève pas.
	(node("Units/Bravo") as Commando).global_position = Vector3(20.5, 0.4, 0)
	await frames(2)
	assert_eq(ship.ramp_problem(alpha), "quelqu'un sur la rampe")


func test_take_off_needs_team_cargo_and_objectives() -> void:
	_clear_enemies()
	assert_true(ship.extraction)
	assert_eq(ship.take_off_problem(), "tous les opérateurs à bord")
	var spots := [Vector3(2, 0.6, 3), Vector3(3, 0.6, 3), Vector3(4, 0.6, 3)]
	var units := level.get_tree().get_nodes_in_group(&"commandos")
	for i in units.size():
		(units[i] as Node3D).global_position = spots[i]
	await frames(2)
	assert_eq(ship.take_off_problem(), "Sabre dans la soute")
	var sabre := node("NavigationRegion3D/Sabre") as Node3D
	var hexapod := node("NavigationRegion3D/Hexapod") as Node3D
	hexapod.global_position = Vector3(-4, Mantis.FLOOR_TOP, 0)
	sabre.global_position = Vector3(10, Mantis.FLOOR_TOP, -2.5)
	await frames(2)
	assert_eq(ship.take_off_problem(), "objectifs en cours", "la citerne d'abord")
	var fuel := node("NavigationRegion3D/FuelBowser") as SabotageTarget
	fuel.blast(fuel.global_position, 4.0)
	assert_eq(ship.take_off_problem(), "")
	var ended := []
	EventBus.mission_ended.connect(func(ok: bool, _message: String) -> void: ended.append(ok))
	assert_true(ship.take_off(units[0] as Commando))
	await frames(400)
	assert_gt(ship.global_position.y, 3.0, "il décolle")
	assert_gt(sabre.global_position.y, 3.0, "le Sabre part avec lui")
	assert_gt((units[0] as Node3D).global_position.y, 3.0, "l'équipe aussi")
	await frames_until(func() -> bool: return not ended.is_empty(), 900)
	assert_eq(ended, [true], "mission réussie")
	var objectives := level.get_tree().get_first_node_in_group(Objectives.GROUP) as Objectives
	assert_eq(objectives.status_of("mantis_stolen"), Objectives.Status.DONE)


func test_second_mantis_lands_with_reinforcements() -> void:
	var m7 := node("NavigationRegion3D/Mantis7") as Mantis
	assert_true(m7.is_away, "absent au début")
	assert_false(m7.visible)
	assert_false(m7.contains(m7.to_global(Vector3(0, 1, 0))))
	var radio := []
	EventBus.radio_message.connect(func(text: String) -> void: radio.append(text))
	m7.arrival_left = 1.0
	await frames_until(func() -> bool: return m7.arrived, 60 * 30)
	assert_true(m7.arrived, "posé")
	assert_true(m7.visible)
	assert_eq(m7._spawned.size(), 4, "quatre renforts")
	assert_true(radio.any(func(text: String) -> bool: return text.contains("M-7")), "annoncé par radio")
	await frames_until(func() -> bool: return m7.ramp_down and not m7.ramp_moving, 300)
	await frames(60 * 6)
	var goal := m7.reinforcement_goal()
	for enemy in m7._spawned:
		assert_false(m7.contains(enemy.global_position + Vector3.UP * 0.3), "%s a quitté la soute" % enemy.name)
		assert_lt(enemy.home_position().distance_to(goal), Mantis.POST_SPREAD + 0.1, "%s : poste autour du point visé" % enemy.name)


func test_alarm_brings_the_second_mantis_sooner() -> void:
	var m7 := node("NavigationRegion3D/Mantis7") as Mantis
	assert_gt(m7.arrival_left, Mantis.ALARM_DELAY)
	m7._on_alert_changed(GameState.AlertLevel.ALARM)
	assert_almost_eq(m7.arrival_left, Mantis.ALARM_DELAY, 0.01)


func test_fuel_bowser_completes_its_objective() -> void:
	var objectives := level.get_tree().get_first_node_in_group(Objectives.GROUP) as Objectives
	var target := node("NavigationRegion3D/FuelBowser") as SabotageTarget
	assert_eq(objectives.status_of("fuel"), Objectives.Status.PENDING)
	target.blast(target.global_position, 4.0)
	assert_eq(objectives.status_of("fuel"), Objectives.Status.DONE)
