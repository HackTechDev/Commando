extends LevelTest
## Niveau construit à partir de la carte UFO:AI `training_a` (fichiers
## externes : test ignoré s'ils sont absents).


func before_each() -> void:
	super()
	if not _map_available():
		return
	await load_level(TRAINING_A)


func _map_available() -> bool:
	return FileAccess.file_exists(AssetPaths.maps_dir().path_join("training_a.map"))


func _skip_without_map() -> bool:
	if _map_available():
		return false
	pending("Carte introuvable : %s" % AssetPaths.maps_dir().path_join("training_a.map"))
	return true


func test_map_geometry_is_built_and_textured() -> void:
	if _skip_without_map():
		return
	var map: UfoMapLevel = node("NavigationRegion3D/Map")
	# 1 024 unités, une case de 32 unités = 1,2 m.
	assert_almost_eq(map.map_bounds.size.x, 38.4, 0.01, "38,4 m de côté")
	var mesh := (map.get_node("Geometry") as MeshInstance3D).mesh
	assert_gt(mesh.get_surface_count(), 10, "un matériau par texture")
	for i in mesh.get_surface_count():
		var material := mesh.surface_get_material(i) as StandardMaterial3D
		assert_not_null(material.albedo_texture, "texture de %s" % material.resource_name)
	for body in ["Ground", "Walls", "Clip"]:
		assert_gt(map.get_node(body).get_child_count(), 0, "collisions %s" % body)
	assert_eq(map.get_node("Walls").collision_layer, 2, "les murs masquent la vue")
	assert_eq(map.get_node("Clip").collision_layer, 1, "les murs invisibles ne la masquent pas")


func test_units_and_sentries_are_placed() -> void:
	if _skip_without_map():
		return
	assert_eq(get_tree().get_nodes_in_group(&"enemies").size(), 8, "une sentinelle par position alien")
	for unit in node("Units").get_children():
		assert_almost_eq((unit as Node3D).global_position.y, 0.0, 0.01, "%s au sol" % unit.name)
		assert_true((unit as CharacterBody3D).is_on_floor())
	# (La position de la caméra n'est pas testée : sans affichage, la souris
	# est au bord de l'écran et la fait défiler.)
	var bounds: AABB = node("CameraRig").bounds
	var map: UfoMapLevel = node("NavigationRegion3D/Map")
	assert_almost_eq(bounds.size.x, map.map_bounds.size.x, 0.01, "caméra limitée à la carte")
	assert_almost_eq(bounds.position.z, map.map_bounds.position.z, 0.01)


func test_operator_crosses_the_map() -> void:
	if _skip_without_map():
		return
	# Buts : les postes des sentinelles, aux quatre coins de la carte, une
	# fois les sentinelles retirées.
	var goals: Array[Vector3] = []
	for enemy in node("Enemies").get_children():
		goals.append(enemy.global_position)
		enemy.free()
	var alpha: Commando = node("Units/Alpha")
	# Couloirs d'une case : il faut des cellules de navigation fines.
	for goal in [goals[0], goals[3], goals[7]]:
		alpha.move_to(goal, true)
		var arrived := func() -> bool: return flat_distance(alpha.global_position, goal) < 1.2 and alpha.velocity.length() < 0.1
		assert_gt(await frames_until(arrived, 1500), -1, "arrivé en %s" % goal)


func test_sentry_spots_an_operator_in_front() -> void:
	if _skip_without_map():
		return
	var sentry: Enemy = node("Enemies/Sentry4")
	var alpha: Commando = node("Units/Alpha")
	alpha.global_position = sentry.global_position + Vector3(0, 0, -4)
	assert_gt(await frames_until(func() -> bool: return sentry.state == Enemy.State.ALERT, 240), -1, "alerte")


func test_map_crates_are_game_crates() -> void:
	if _skip_without_map():
		return
	var crates := _map_crates()
	# Cubes d'une case posés au sol, rien dessus ; piles et caisses à
	# couvercle restent du décor.
	assert_eq(crates.size(), 9)
	for crate in crates:
		assert_almost_eq(crate.top_height, 1.2, 0.001, "%s : hauteur des caisses du jeu" % crate.name)
		assert_almost_eq(crate.half_extent, 0.6, 0.001)
		assert_almost_eq(crate.global_position.y, 0.0, 0.01, "posée au sol")
		var mesh := (crate.get_node("MeshInstance3D") as MeshInstance3D).mesh
		assert_not_null((mesh.surface_get_material(0) as StandardMaterial3D).albedo_texture, "textures de la carte")


func test_climb_map_crate_and_hop_to_its_neighbour() -> void:
	if _skip_without_map():
		return
	var alpha: Commando = node("Units/Alpha")
	# Deux caisses collées près du départ.
	var first: Climbable = node("NavigationRegion3D/Map/MapCrate1")
	var second: Climbable = node("NavigationRegion3D/Map/MapCrate3")
	assert_true(first.is_adjacent_to(second))
	for crate in [first, second]:
		assert_true(alpha.climb(crate, true))
		var perched := func() -> bool: return alpha.perched_on == crate and not alpha._hopping
		assert_gt(await frames_until(perched, 1500), -1, "perché sur %s" % crate.name)
		assert_almost_eq(alpha.global_position.y, 1.2, 0.05)


func test_push_and_pull_map_crate() -> void:
	if _skip_without_map():
		return
	for enemy in node("Enemies").get_children():
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
	var alpha: Commando = node("Units/Alpha")
	# Caisse dégagée sur ses quatre côtés.
	var crate: Climbable = node("NavigationRegion3D/Map/MapCrate2")
	assert_eq(crate.get_access_points().size(), 4)
	var start := crate.global_position
	assert_true(alpha.handle_crate(crate, start + Vector3.LEFT * 2.0))
	assert_gt(await frames_until(alpha.is_handling_crate, 1500), -1, "caisse saisie")
	alpha.move_to(start + Vector3.RIGHT, false)
	await frames(200)
	assert_almost_eq(crate.global_position, start + Vector3.RIGHT, Vector3.ONE * 0.05, "poussée d'1 m")
	alpha.move_to(start, false)
	await frames(200)
	assert_almost_eq(crate.global_position, start, Vector3.ONE * 0.05, "ramenée en la tirant")


func test_map_barrels_are_movable_props() -> void:
	if _skip_without_map():
		return
	var barrels := _map_barrels()
	assert_eq(barrels.size(), 22, "tous les bidons de la carte")
	var alpha: Commando = node("Units/Alpha")
	var space := alpha.get_world_3d().direct_space_state
	for barrel in barrels:
		assert_true(barrel.movable)
		assert_false(barrel.can_stand_on, "%s : on ne monte pas dessus" % barrel.name)
		assert_almost_eq(barrel.top_height, 1.2, 0.001)
		assert_almost_eq(barrel.global_position.y, 0.0, 0.01, "posé au sol")
		assert_is((barrel.get_node("CollisionShape3D") as CollisionShape3D).shape, CylinderShape3D)
		var mesh := (barrel.get_node("MeshInstance3D") as MeshInstance3D).mesh
		assert_not_null((mesh.surface_get_material(0) as StandardMaterial3D).albedo_texture, "textures de la carte")
		assert_null(Climbable.find_at(get_tree(), barrel.get_top_position()), "un clic sur le dessus ne fait pas grimper")
		# Plus de mur invisible sous le bidon (découpé s'il couvrait aussi du décor).
		var query := PhysicsShapeQueryParameters3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.0, 1.0, 1.0)
		query.shape = box
		query.transform = Transform3D(Basis(), barrel.global_position + Vector3.UP * 0.6)
		query.collision_mask = 1
		query.exclude = [barrel.get_rid()]
		assert_eq(space.intersect_shape(query, 1).size(), 0, "%s : mur invisible retiré" % barrel.name)
	assert_false(alpha.climb(barrels[0], false), "on ne grimpe pas sur un bidon")


func test_push_and_pull_map_barrel() -> void:
	if _skip_without_map():
		return
	for enemy in node("Enemies").get_children():
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
	var alpha: Commando = node("Units/Alpha")
	# Bidon dégagé sur ses quatre côtés.
	var barrel: Climbable = null
	for candidate in _map_barrels():
		if candidate.get_access_points().size() == 4:
			barrel = candidate
			break
	assert_not_null(barrel)
	var start := barrel.global_position
	var side := barrel.get_side_toward(alpha.global_position)
	assert_true(alpha.handle_crate(barrel, barrel.get_access_point(side)))
	assert_gt(await frames_until(alpha.is_handling_crate, 2000), -1, "bidon saisi")
	alpha.move_to(start - side, false)
	await frames(200)
	assert_almost_eq(barrel.global_position, start - side, Vector3.ONE * 0.05, "poussé d'1 m")
	alpha.move_to(start, false)
	await frames(200)
	assert_almost_eq(barrel.global_position, start, Vector3.ONE * 0.05, "ramené en le tirant")


func test_wall_tops_become_ledges() -> void:
	if _skip_without_map():
		return
	var ledges := _ledges()
	assert_gt(ledges.size(), 50, "dessus des murs découpés en cases")
	for ledge in ledges:
		assert_false(ledge.movable)
		assert_false(ledge.climbable_from_ground, "trop haut depuis le sol")
		assert_between(ledge.get_top_position().y, 2.2, 2.45, "mur bas : %s" % ledge.name)
	var crate: Climbable = node("NavigationRegion3D/Map/MapCrate1")
	var ledge := _ledge_next_to(crate)
	assert_not_null(ledge, "mur contre la caisse")
	assert_same(Climbable.find_at(get_tree(), ledge.get_top_position()), ledge, "désignée par un clic sur le mur")
	var alpha: Commando = node("Units/Alpha")
	assert_false(alpha.handle_crate(ledge, ledge.global_position), "un mur ne se pousse pas")


func test_climb_from_crate_onto_wall_and_back_down() -> void:
	if _skip_without_map():
		return
	var alpha: Commando = node("Units/Alpha")
	var crate: Climbable = node("NavigationRegion3D/Map/MapCrate1")
	var ledge := _ledge_next_to(crate)
	assert_true(alpha.climb(crate, true))
	assert_gt(await frames_until(func() -> bool: return alpha.perched_on == crate and not alpha._hopping, 1500), -1, "sur la caisse")
	assert_true(alpha.climb(ledge, false))
	assert_gt(await frames_until(func() -> bool: return alpha.perched_on == ledge and not alpha._hopping, 600), -1, "sur le mur")
	assert_almost_eq(alpha.global_position.y, ledge.get_top_position().y, 0.05)
	assert_null(crate.occupant, "caisse libérée")
	# Redescente par la caisse, pas en sautant du mur.
	var goal := crate.get_access_point(crate.get_side_toward(crate.global_position + Vector3.BACK * 3.0))
	alpha.move_to(goal, false)
	var via_crate := false
	for i in 900:
		await wait_physics_frames(1)
		for other in _map_crates():
			via_crate = via_crate or other.occupant == alpha
		if alpha.perched_on == null and not alpha._hopping:
			break
	assert_true(via_crate, "repassé par une caisse")
	assert_null(alpha.perched_on)
	assert_lt(alpha.global_position.y, 0.1, "au sol")
	assert_null(ledge.occupant)


func test_ledge_ordered_from_the_ground_goes_through_a_crate() -> void:
	if _skip_without_map():
		return
	var alpha: Commando = node("Units/Alpha")
	var ledge := _ledge_next_to(node("NavigationRegion3D/Map/MapCrate1"))
	assert_true(alpha.climb(ledge, true))
	assert_gt(await frames_until(func() -> bool: return alpha.perched_on == ledge and not alpha._hopping, 2000), -1, "sur le mur")


func test_jump_down_from_wall_without_crate() -> void:
	if _skip_without_map():
		return
	var alpha: Commando = node("Units/Alpha")
	var bravo: Commando = node("Units/Bravo")
	var ledge := _ledge_with_ground_below()
	assert_not_null(ledge, "mur contre une caisse, sol dégagé au pied")
	assert_true(alpha.climb(ledge, true))
	assert_gt(await frames_until(func() -> bool: return alpha.perched_on == ledge and not alpha._hopping, 2000), -1, "sur le mur")
	# Plus aucune caisse libre pour redescendre : il saute.
	for crate in _map_crates():
		crate.occupant = bravo
	var noises: Array[StringName] = []
	var listener := func(_at: Vector3, _radius: float, type: StringName) -> void: noises.append(type)
	EventBus.noise_emitted.connect(listener)
	alpha.move_to(ledge.get_access_points()[0], false)
	var jumped := false
	var lowest_hips := INF
	for i in 600:
		await wait_physics_frames(1)
		jumped = jumped or alpha._model.climb_jump and alpha._model.climb_progress >= 0.0
		if alpha._model.climb_progress >= 0.0:
			lowest_hips = minf(lowest_hips, alpha._model._hips.position.y)
		if alpha.perched_on == null and not alpha._hopping:
			break
	EventBus.noise_emitted.disconnect(listener)
	for crate in _map_crates():
		crate.occupant = null
	assert_true(jumped, "animation de saut")
	assert_lt(lowest_hips, 0.6, "réception accroupie")
	assert_has(noises, &"jump", "bruit de réception")
	assert_lt(alpha.global_position.y, 0.1, "au sol")
	assert_null(ledge.occupant)


func _map_crates() -> Array[Climbable]:
	var crates: Array[Climbable] = []
	for node_ in node("NavigationRegion3D/Map").get_children():
		if node_ is Climbable and node_.name.begins_with("MapCrate"):
			crates.append(node_)
	return crates


func _map_barrels() -> Array[Climbable]:
	var barrels: Array[Climbable] = []
	for node_ in node("NavigationRegion3D/Map").get_children():
		if node_ is Climbable and node_.name.begins_with("MapBarrel"):
			barrels.append(node_)
	return barrels


func _ledges() -> Array[Climbable]:
	var ledges: Array[Climbable] = []
	for node_ in node("NavigationRegion3D/Map").get_children():
		if node_ is Climbable and not node_.movable:
			ledges.append(node_)
	return ledges


## Corniche voisine d'une caisse, d'où l'on peut sauter au sol.
func _ledge_with_ground_below() -> Climbable:
	for ledge in _ledges():
		if ledge.get_access_points().is_empty():
			continue
		for crate in _map_crates():
			if crate.can_reach(ledge):
				return ledge
	return null


## Corniche qu'on atteint en grimpant depuis le dessus de `crate`.
func _ledge_next_to(crate: Climbable) -> Climbable:
	for ledge in _ledges():
		if crate.can_reach(ledge):
			return ledge
	return null
