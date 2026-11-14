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
	assert_almost_eq(map.map_bounds.size.x, 40.96, 0.01, "41 m de côté")
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
	for enemy in node("Enemies").get_children():
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
	var alpha: Commando = node("Units/Alpha")
	# Couloirs d'une case : il faut des cellules de navigation fines.
	for goal in [Vector3(14, 0, -14), Vector3(10, 0, 12), Vector3(-16, 0, 16)]:
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
