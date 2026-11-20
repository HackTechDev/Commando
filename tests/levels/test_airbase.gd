extends LevelTest
## Carte « Base aérienne » : le convertible (`Tiltrotor`, `TiltrotorModel`)
## et l'objectif de sabotage.

const AIRBASE := "res://scenes/levels/airbase/airbase.tscn"

var aircraft: Tiltrotor
var endings: Array = []


func before_each() -> void:
	super()
	await load_level(AIRBASE)
	aircraft = node("NavigationRegion3D/Tiltrotor")
	endings.clear()
	EventBus.mission_ended.connect(_on_mission_ended)


func after_each() -> void:
	EventBus.mission_ended.disconnect(_on_mission_ended)
	super()


func _on_mission_ended(success: bool, message: String) -> void:
	endings.append([success, message])


## Écarte tous les ennemis et les opérateurs (hors du souffle).
func _clear_area() -> void:
	var spot := Vector3(-30, 0, 30)
	for enemy: Enemy in get_tree().get_nodes_in_group(&"enemies"):
		park(enemy, spot)
		spot.x += 1.5
	for unit_name in ["Alpha", "Bravo", "Charlie"]:
		var unit: Commando = node("Units/" + unit_name)
		hide_from_enemies(unit)
		unit.global_position = Vector3(25, 0, 30) + Vector3(unit.unit_index * 1.5, 0, 0)
	await frames(2)


func test_map_content() -> void:
	assert_eq(get_tree().get_nodes_in_group(&"enemies").size(), 7, "sept soldats")
	assert_eq(aircraft.model.rotors.size(), 4, "quatre rotors")
	assert_eq(aircraft.model.livery, TiltrotorModel.Livery.GREY)
	var alpha: Commando = node("Units/Alpha")
	var charlie: Commando = node("Units/Charlie")
	assert_gte(alpha.explosives, 1, "charge fournie par la mission")
	assert_gte(charlie.explosives, 1)
	assert_eq(LevelCatalog.title_of(AIRBASE), "Base aérienne")


func test_aircraft_is_reachable_and_blocks() -> void:
	var map := aircraft.get_world_3d().navigation_map
	var start: Vector3 = (node("Units/Alpha") as Commando).global_position
	var path := NavigationServer3D.map_get_path(map, start, Vector3(0, 0, 7), true)
	assert_gt(path.size(), 1, "chemin du départ jusqu'à la plateforme")
	assert_lt(path[path.size() - 1].distance_to(Vector3(0, 0, 7)), 1.0)
	var under := NavigationServer3D.map_get_closest_point(map, aircraft.global_position + Vector3(0, 0, 0))
	assert_gt(aircraft.distance_to_hull(under) + 0.01, 0.0, "pas de navigation sous la coque")
	var query := PhysicsRayQueryParameters3D.create(Vector3(-12, 1.5, -4), Vector3(12, 1.5, -4), VisionComponent.MASK_OCCLUDERS)
	assert_false(aircraft.get_world_3d().direct_space_state.intersect_ray(query).is_empty(), "la coque arrête la vue")


func test_distant_blast_spares_the_aircraft() -> void:
	aircraft.blast(aircraft.global_position + Vector3(0, 0, 14), 4.0)
	assert_false(aircraft.is_destroyed)


func test_charge_destroys_the_aircraft_and_ends_the_mission() -> void:
	await _clear_area()
	var alpha: Commando = node("Units/Alpha")
	var charge := ExplosiveCharge.plant(level, aircraft.global_position + Vector3(2.8, 0, 0.5), alpha)
	await frames(2)
	charge.detonate()
	assert_true(aircraft.is_destroyed, "appareil détruit")
	assert_eq(aircraft.model.rotor_speed, 0.0)
	assert_not_null(aircraft.get_node_or_null("Fire"), "l'épave brûle")
	var objectives := level.find_child("Objectives", true, false) as Objectives
	if objectives:
		assert_eq(objectives.status_of("aircraft_destroyed"), Objectives.Status.DONE)
	assert_gt(await frames_until(func() -> bool: return not endings.is_empty(), int(Tiltrotor.END_DELAY * 60) + 60), -1, "fin de mission")
	assert_true(endings[0][0], "réussite")
	assert_false(alpha.is_dead, "loin du souffle")


func test_fuel_blast_hurts_whoever_stayed_close() -> void:
	await _clear_area()
	var bravo: Commando = node("Units/Bravo")
	bravo.global_position = aircraft.global_position + Vector3(3.5, 0, 1.5)
	# Cible du souffle (les ennemis sont écartés).
	bravo.add_to_group(&"commandos")
	await frames(2)
	var health := bravo.health.health
	aircraft.destroy()
	assert_lt(bravo.health.health, health, "le réservoir souffle les alentours")


func test_destroyed_state_is_saved() -> void:
	var saved := aircraft.save_state()
	assert_false(saved["destroyed"])
	aircraft.load_state({"destroyed": true})
	assert_true(aircraft.is_destroyed)
	assert_true(endings.is_empty(), "restaurer une épave ne rejoue pas la fin")


func test_rotors_spin_when_powered() -> void:
	var rotor := aircraft.model.rotors[0]
	var before := rotor.rotation.y
	aircraft.model.rotor_speed = 1.0
	await frames(10)
	assert_ne(rotor.rotation.y, before)
	assert_true(rotor.get_node("Blur").visible == false, "pas de disque flou à basse vitesse")
	aircraft.model.rotor_speed = 5.0
	await frames(2)
	assert_true(rotor.get_node("Blur").visible, "disque flou à pleine vitesse")
