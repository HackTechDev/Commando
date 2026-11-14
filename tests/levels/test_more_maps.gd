extends LevelTest
## Niveaux construits à partir des cartes UFO:AI `training_b` et
## `fighter_crash` (fichiers externes : tests ignorés s'ils sont absents).

const LEVELS := {
	"training_b.map": LevelTest.TRAINING_B,
	"fighter_crash.map": LevelTest.FIGHTER_CRASH,
}


func _map_path(map_name: String) -> String:
	return AssetPaths.maps_dir().path_join(map_name)


## Charge le niveau de `map_name`, ou le marque en attente si la carte manque.
func _load(map_name: String) -> bool:
	if not FileAccess.file_exists(_map_path(map_name)):
		pending("Carte introuvable : %s" % _map_path(map_name))
		return false
	await load_level(LEVELS[map_name])
	return true


func test_levels_are_built_and_populated() -> void:
	for map_name: String in LEVELS:
		if not await _load(map_name):
			continue
		var map: UfoMapLevel = node("NavigationRegion3D/Map")
		var mesh := (map.get_node("Geometry") as MeshInstance3D).mesh
		assert_gt(mesh.get_surface_count(), 10, "%s : géométrie texturée" % map_name)
		var navigation_map: RID = (level as Node3D).get_world_3d().navigation_map
		for unit: Commando in node("Units").get_children():
			assert_true(unit.is_on_floor(), "%s : %s au sol" % [map_name, unit.name])
			var on_mesh := NavigationServer3D.map_get_closest_point(navigation_map, unit.global_position)
			assert_lt(on_mesh.distance_to(unit.global_position), 0.3, "%s : %s sur la navigation" % [map_name, unit.name])
		var sentries := node("Enemies").get_children()
		assert_eq(sentries.size(), 12, "%s : sentinelles limitées à 12" % map_name)
		# Toutes atteignables à pied depuis le départ.
		var start: Vector3 = node("Units/Alpha").global_position
		for sentry: Node3D in sentries:
			var path := NavigationServer3D.map_get_path(navigation_map, start, sentry.global_position, true)
			assert_gt(path.size(), 0, "%s : chemin vers %s" % [map_name, sentry.name])
			if path.size() > 0:
				assert_lt(path[path.size() - 1].distance_to(sentry.global_position), 0.5, "%s : %s atteignable" % [map_name, sentry.name])


func test_sentries_are_spread_over_the_map() -> void:
	# 85 postes possibles sur training_b : les 12 retenus couvrent la carte.
	if not await _load("training_b.map"):
		return
	var map: UfoMapLevel = node("NavigationRegion3D/Map")
	var sentries := node("Enemies").get_children()
	var closest := INF
	var spread := AABB(sentries[0].global_position, Vector3.ZERO)
	for i in sentries.size():
		spread = spread.expand(sentries[i].global_position)
		for j in range(i + 1, sentries.size()):
			closest = minf(closest, flat_distance(sentries[i].global_position, sentries[j].global_position))
	assert_gt(closest, 8.0, "pas deux sentinelles côte à côte")
	assert_gt(spread.size.x, map.map_bounds.size.x * 0.8, "réparties d'un bout à l'autre")
	assert_gt(spread.size.z, map.map_bounds.size.z * 0.6)


func test_operator_reaches_the_farthest_sentry_post() -> void:
	# Relief en terrasses (fighter_crash) : pentes, petites marches.
	for map_name: String in LEVELS:
		if not await _load(map_name):
			continue
		var alpha: Commando = node("Units/Alpha")
		var goal: Vector3 = alpha.global_position
		for enemy: Node3D in node("Enemies").get_children():
			if flat_distance(enemy.global_position, alpha.global_position) > flat_distance(goal, alpha.global_position):
				goal = enemy.global_position
		for enemy in node("Enemies").get_children():
			enemy.free()
		alpha.move_to(goal, true)
		var arrived := func() -> bool: return flat_distance(alpha.global_position, goal) < 1.2 and alpha.velocity.length() < 0.1
		assert_gt(await frames_until(arrived, 3000), -1, "%s : arrivé en %s" % [map_name, goal])


func test_operator_climbs_and_descends_narrow_stairs() -> void:
	# Escaliers de 0,9 m de large (marches de 15 cm) entre les tranchées et
	# le terrain de training_b.
	if not await _load("training_b.map"):
		return
	for enemy in node("Enemies").get_children():
		enemy.free()
	var alpha: Commando = node("Units/Alpha")
	var trips := [
		# Du fond d'une tranchée (-2,4 m) jusqu'en haut des marches.
		[Vector3(-28.4, -2.4, 25.8), Vector3(-33.8, -0.5, 25.8)],
		# Du terrain (0 m) jusqu'au palier en contrebas (-1,2 m).
		[Vector3(-46.2, 0.0, -17.5), Vector3(-46.2, -1.2, -23.0)],
	]
	for trip: Array in trips:
		alpha.global_position = trip[0]
		alpha.velocity = Vector3.ZERO
		await frames(5)
		var goal: Vector3 = trip[1]
		alpha.move_to(goal, false)
		var arrived := func() -> bool: return flat_distance(alpha.global_position, goal) < 0.8 and absf(alpha.global_position.y - goal.y) < 0.3
		assert_gt(await frames_until(arrived, 900), -1, "escalier pris : %s → %s (arrivé en %s)" % [trip[0], goal, alpha.global_position])
		await frames(30)
		assert_almost_eq(alpha._model.position.y, 0.0, 0.01, "modèle recalé sur le corps à l'arrêt")


func test_roof_fades_when_an_operator_is_inside() -> void:
	# Les bâtiments de training_b ont un toit qui s'efface quand un opérateur
	# entre, et réapparaît quand il sort.
	if not await _load("training_b.map"):
		return
	for enemy in node("Enemies").get_children():
		enemy.free()
	var roofs := level.find_children("Roof*", "Roof", true, false)
	assert_gte(roofs.size(), 8, "toits repérés")
	var roof: Roof = null
	for candidate: Roof in roofs:
		if candidate.covers(Vector3(-9.6, 0.0, -12.6)):
			roof = candidate
	assert_not_null(roof, "toit du bâtiment visé")
	if roof == null:
		return
	assert_false(roof.is_revealed(), "toit affiché au départ")
	assert_eq(roof.view.transparency, 0.0)
	var alpha: Commando = node("Units/Alpha")
	var outside := alpha.global_position
	var inside := Vector3(-9.6, 0.05, -12.6)
	alpha.global_position = inside
	alpha.velocity = Vector3.ZERO
	await frames(60)
	assert_true(roof.is_revealed(), "toit effacé, opérateur dedans")
	assert_almost_eq(roof.view.transparency, 1.0, 0.01)
	assert_true(Roof.is_revealed_body(roof.body), "les clics traversent le toit effacé")
	for other: Roof in roofs:
		if other != roof:
			assert_false(other.is_revealed(), "les autres toits restent affichés : %s" % other.name)
	# Le toit effacé reste solide : on peut toujours s'y tenir.
	var bravo: Commando = node("Units/Bravo")
	var top := roof.areas[0].get_center()
	bravo.global_position = Vector3(top.x, roof.ceiling + 1.5, top.y)
	bravo.velocity = Vector3.ZERO
	await frames(60)
	assert_gt(bravo.global_position.y, roof.ceiling, "debout sur le toit effacé (%s)" % bravo.global_position)
	alpha.global_position = outside
	await frames(60)
	assert_false(roof.is_revealed(), "toit réaffiché, opérateur sorti")
	assert_eq(roof.view.transparency, 0.0)
	assert_false(Roof.is_revealed_body(roof.body))
