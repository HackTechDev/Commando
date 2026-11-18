extends LevelTest
## Portes, fenêtres et bâtiment de la sandbox : passage par le seuil (la
## porte s'ouvre), vue en coupe, porte verrouillée (crochetage, clés des
## ennemis), porte qui saute, fenêtre qu'on enjambe.

const BUILDING := Vector3(8, 0, 22)

var alpha: Commando
var building: Building
var front: Door
var back: Door


func before_each() -> void:
	super()
	await load_level()
	alpha = node("Units/Alpha")
	building = node("NavigationRegion3D/Building")
	hide_from_enemies(alpha)
	park(node("Enemies/Soldier1"))
	park(node("Enemies/TrainingDummy"))
	for door in building.built_doors:
		if door.locked:
			back = door
		else:
			front = door
	alpha.global_position = BUILDING + Vector3(0, 0, -6)
	await frames(2)


func _blocked(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, VisionComponent.MASK_OCCLUDERS)
	return not alpha.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _path(from: Vector3, to: Vector3, layers: int) -> PackedVector3Array:
	return NavigationServer3D.map_get_path(alpha.get_world_3d().navigation_map, from, to, true, layers)


func test_building_is_assembled() -> void:
	assert_eq(building.built_doors.size(), 2)
	assert_eq(building.built_windows.size(), 3)
	assert_not_null(front)
	assert_not_null(back)
	assert_true(back.is_locked)
	assert_false(front.is_open)


func test_closed_door_blocks_sight_and_open_door_does_not() -> void:
	var eye := Vector3.UP * 1.5
	var outside := front.global_position + (front.global_position - BUILDING).normalized() * 2.0
	assert_true(_blocked(outside + eye, BUILDING + eye), "porte fermée : vue arrêtée")
	front.open_from(outside)
	await frames(2)
	assert_false(_blocked(outside + eye, BUILDING + eye), "porte ouverte : on voit dedans")
	assert_eq(front.collision_layer, Door.DOOR_LAYER, "battant ouvert : cliquable, rien d'autre")
	assert_lt(front.to_local(front._shape.global_position).z, -0.3, "poussée vers l'intérieur, loin de qui ouvre")


func test_walking_inside_opens_the_door_and_shows_a_cutaway() -> void:
	# Le bâtiment guette les opérateurs (groupe `commandos`) ; les ennemis
	# sont écartés.
	alpha.add_to_group(&"commandos")
	assert_false(building.is_cut)
	assert_gt(_path(alpha.global_position, BUILDING, Door.NAV_EVERYONE).size(), 1, "chemin par la porte")
	alpha.move_to(BUILDING, false)
	assert_gt(await frames_until(func() -> bool: return front.is_open, 600), -1, "la porte s'ouvre au passage")
	assert_gt(await frames_until(func() -> bool: return building.contains(alpha.global_position + Vector3.UP * 0.3), 600), -1, "entré")
	assert_gt(await frames_until(func() -> bool: return building.is_cut, 30), -1, "vue en coupe")
	await frames(30)
	assert_false(building.roof_body.get_child(1).visible, "toit effacé")
	assert_true(Building.is_revealed_body(building.roof_body), "les clics traversent le toit")
	# Ressorti, le bâtiment redevient entier.
	alpha.move_to(BUILDING + Vector3(0, 0, -6), false)
	assert_gt(await frames_until(func() -> bool: return not building.is_cut, 900), -1, "bâtiment entier")


func test_operator_closes_an_open_door() -> void:
	front.open_from(alpha.global_position)
	await frames(30)
	assert_true(alpha.use_door(front))
	assert_gt(await frames_until(func() -> bool: return not front.is_open, 400), -1, "porte refermée")
	assert_true(front.collision_layer & Door.LAYER_OCCLUDERS != 0)


func test_locked_door_must_be_picked() -> void:
	var outside := back.near_side(BUILDING + Vector3(0, 0, 10))
	assert_eq(back.link.navigation_layers, Door.NAV_ENEMIES, "fermée à clé : ennemis seuls")
	var inside := back.near_side(BUILDING)
	var path := _path(outside, inside, Door.NAV_EVERYONE)
	assert_true(path.is_empty() or _path_length(path) > 6.0, "un opérateur fait le tour par l'autre porte")
	assert_lt(_path_length(_path(outside, inside, Door.NAV_EVERYONE | Door.NAV_ENEMIES)), 3.0, "un ennemi passe")
	alpha.global_position = outside + Vector3(0, 0, 0.5)
	await frames(2)
	assert_false(back.toggle_from(alpha.global_position), "on ne l'ouvre pas à la main")
	assert_true(alpha.use_door(back))
	assert_true(await frames_until(func() -> bool: return alpha.is_picking_lock(), 120) > -1, "crochetage")
	assert_eq(alpha.posture, SoldierModel.Posture.CROUCHED)
	assert_true(back.is_locked, "pas encore")
	assert_gt(await frames_until(func() -> bool: return back.is_open, int(DoorOrder.LOCKPICK_TIME * 60) + 120), -1, "crochetée puis ouverte")
	assert_false(back.is_locked)
	assert_eq(back.link.navigation_layers, Door.NAV_EVERYONE)


func test_enemies_have_the_keys() -> void:
	var soldier: Enemy = node("Enemies/Soldier1")
	assert_eq(soldier._agent.navigation_layers & Door.NAV_ENEMIES, Door.NAV_ENEMIES)


func test_explosion_and_bullets_break_doors() -> void:
	back.blast(back.global_position + Vector3(0, 1, 1.5), 4.0)
	assert_true(back.is_broken)
	assert_false(back.is_locked)
	assert_eq(back.collision_layer, 0)
	assert_eq(back.link.navigation_layers, Door.NAV_EVERYONE)
	front.blast(front.global_position + Vector3(0, 1, -20), 4.0)
	assert_false(front.is_broken, "explosion trop loin")
	for i in 20:
		front.take_shot(10.0, front.global_position + Vector3.UP, front.global_position + Vector3(0, 1, -5))
	assert_true(front.is_broken, "criblée de balles")


func test_window_lets_sight_through_above_the_sill() -> void:
	var window := building.built_windows[0]
	var out := window.global_basis.z
	var a := window.global_position + out * 2.0
	var b := window.global_position - out * 2.0
	assert_false(_blocked(a + Vector3.UP * 1.5, b + Vector3.UP * 1.5), "vue par la fenêtre")
	assert_true(_blocked(a + Vector3.UP * 0.5, b + Vector3.UP * 0.5), "allège : accroupi, caché")
	assert_eq(window.link.kind, TraversalLink.Kind.VAULT)
	assert_almost_eq(window.link.height, window.sill, 0.001)


func test_body_inside_is_hidden() -> void:
	assert_not_null(Building.at(get_tree(), BUILDING + Vector3.UP * 0.3))
	assert_null(Building.at(get_tree(), BUILDING + Vector3(0, 0.3, -6)))
	var dummy: Enemy = node("Enemies/TrainingDummy")
	dummy.global_position = BUILDING + Vector3(1, 0, 1)
	dummy.kill_silently()
	await frames(10)
	assert_true(dummy.is_hidden_body())


func test_door_state_is_saved() -> void:
	front.open_from(alpha.global_position)
	var saved := front.save_state()
	front.close()
	front.load_state(saved)
	assert_true(front.is_open)
	var locked := back.save_state()
	back.open_from(alpha.global_position)
	back.load_state(locked)
	assert_true(back.is_locked)
	assert_false(back.is_open)


func _path_length(path: PackedVector3Array) -> float:
	var total := 0.0
	for i in range(1, path.size()):
		total += path[i - 1].distance_to(path[i])
	return total
