extends LevelTest
## Niveaux construits à partir des cartes UFO:AI `training_b` et
## `fighter_crash` (fichiers externes : tests ignorés s'ils sont absents).

const LEVELS := {
	"training_b.map": LevelTest.TRAINING_B,
	"fighter_crash.map": LevelTest.FIGHTER_CRASH,
}
const TEST_ROOF_CACHE := "user://test_roof_cache"


func after_each() -> void:
	super()
	UfoMapLevel.roof_cache_dir = UfoMapLevel.ROOF_CACHE_DIR


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


func test_half_of_the_sentries_patrol_around_their_post() -> void:
	if not await _load("training_b.map"):
		return
	var sentries := node("Enemies").get_children()
	var patrollers: Array[Enemy] = []
	for node in sentries:
		var sentry := node as Enemy
		if sentry.patrol_points().size() > 1:
			patrollers.append(sentry)
			assert_false(sentry.stationary, "%s : n'est plus fixe" % sentry.name)
		else:
			assert_true(sentry.stationary, "%s : reste à son poste" % sentry.name)
	assert_between(patrollers.size(), sentries.size() / 3, sentries.size() * 2 / 3, "environ une sur deux")
	var nav_map := get_tree().root.get_world_3d().navigation_map
	for sentry in patrollers:
		var points := sentry.patrol_points()
		for point in points:
			assert_lt(absf(point.y - points[0].y), 0.61, "%s : même étage" % sentry.name)
			assert_lt(flat_distance(point, points[0]), 13.0, "%s : autour du poste" % sentry.name)
	# Ils se mettent en route.
	var walker := patrollers[0]
	hide_from_enemies(node("Units/Alpha"))
	hide_from_enemies(node("Units/Bravo"))
	hide_from_enemies(node("Units/Charlie"))
	var post := walker.global_position
	assert_gt(await frames_until(func() -> bool: return flat_distance(walker.global_position, post) > 2.0, 600), -1, "en ronde")


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
	assert_eq(roof.materials[0].get_shader_parameter(&"reveal"), 0.0)
	var alpha: Commando = node("Units/Alpha")
	var outside := alpha.global_position
	var inside := Vector3(-9.6, 0.05, -12.6)
	alpha.global_position = inside
	alpha.velocity = Vector3.ZERO
	await frames(60)
	assert_true(roof.is_revealed(), "toit effacé, opérateur dedans")
	assert_almost_eq(roof.materials[0].get_shader_parameter(&"reveal"), 1.0, 0.01, "effacé dans le shader")
	assert_true(Roof.is_revealed_body(roof.body), "les clics traversent le toit effacé")
	for other: Roof in roofs:
		if other != roof and not other.below.has(roof):
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
	assert_eq(roof.materials[0].get_shader_parameter(&"reveal"), 0.0)
	assert_false(Roof.is_revealed_body(roof.body))


func test_station_roofs_fade_floor_by_floor() -> void:
	# La gare de fighter_crash a un étage : au rez-de-chaussée, l'étage et
	# son toit s'effacent ; à l'étage, seul le toit.
	if not await _load("fighter_crash.map"):
		return
	for enemy in node("Enemies").get_children():
		enemy.free()
	var roofs := level.find_children("Roof*", "Roof", true, false)
	assert_gte(roofs.size(), 4, "toits des bâtiments repérés")
	var ground := Vector3(10.35, -2.9, 3.9)
	var lower: Roof = null
	for roof: Roof in roofs:
		if roof.covers(ground):
			lower = roof
	assert_not_null(lower, "plafond du rez-de-chaussée de la gare")
	if lower == null:
		return
	var upper: Roof = null
	for roof: Roof in roofs:
		if roof.below.has(lower):
			upper = roof
	assert_not_null(upper, "toit de l'étage, au-dessus")
	if upper == null:
		return
	var alpha: Commando = node("Units/Alpha")
	alpha.global_position = ground + Vector3.UP * 0.05
	alpha.velocity = Vector3.ZERO
	await frames(60)
	assert_true(lower.is_revealed(), "rez-de-chaussée visible")
	assert_true(upper.is_revealed(), "étage effacé aussi")
	var top := upper.areas[upper.areas.size() / 2].get_center()
	alpha.global_position = Vector3(top.x, upper.ceilings[upper.areas.size() / 2] - 1.0, top.y)
	alpha.velocity = Vector3.ZERO
	await frames(60)
	assert_true(upper.covers(alpha.global_position), "opérateur à l'étage (%s)" % alpha.global_position)
	assert_true(upper.is_revealed(), "toit de l'étage effacé")
	assert_false(lower.is_revealed(), "plancher de l'étage affiché")


func test_view_level_hides_the_upper_floors() -> void:
	# Niveau de vue choisi au clavier : l'étage, puis le rez-de-chaussée de la
	# gare de fighter_crash s'affichent sans personne dedans.
	if not await _load("fighter_crash.map"):
		return
	for enemy in node("Enemies").get_children():
		enemy.free()
	var roofs := level.find_children("Roof*", "Roof", true, false)
	var lower: Roof = null
	for roof: Roof in roofs:
		if roof.covers(Vector3(10.35, -2.9, 3.9)):
			lower = roof
	var upper: Roof = null
	for roof: Roof in roofs:
		if lower and roof.below.has(lower):
			upper = roof
	assert_not_null(upper, "gare à étage")
	if upper == null:
		return
	assert_eq(lower.storey(), 0)
	assert_eq(upper.storey(), 1)
	var count := Roof.storey_count(get_tree())
	assert_gte(count, 2)
	var controller: PlayerController = node("HUD/PlayerController")
	await frames(20)
	assert_false(upper.is_revealed(), "personne dans la gare")
	controller.step_view_level(-1)
	assert_eq(Roof.view_level, count - 1, "dernier étage")
	while Roof.view_level > 1:
		controller.step_view_level(-1)
	await frames(20)
	assert_true(upper.is_revealed(), "toit de l'étage effacé")
	assert_false(lower.is_revealed(), "plancher de l'étage affiché")
	assert_true(controller.get_node("Banner").visible, "étage annoncé")
	controller.step_view_level(-1)
	assert_eq(Roof.view_level, 0)
	controller.step_view_level(-1)
	assert_eq(Roof.view_level, 0, "on ne descend pas plus bas")
	await frames(20)
	assert_true(lower.is_revealed(), "rez-de-chaussée visible")
	for i in count:
		controller.step_view_level(1)
	assert_eq(Roof.view_level, -1, "au-dessus du dernier étage : tout affiché")
	await frames(40)
	assert_false(upper.is_revealed())
	assert_false(controller.get_node("Banner").visible)


## Toit de la tranchée couverte d'Entraînement B (le plus bas).
func _trench_roof() -> Roof:
	var roofs := level.find_children("Roof*", "Roof", true, false)
	roofs.sort_custom(func(a: Roof, b: Roof) -> bool: return a.ceiling < b.ceiling)
	return roofs[0] if not roofs.is_empty() else null


func test_roofs_reveal_only_what_covers_the_inside() -> void:
	# Une dalle de terrain qui couvre une tranchée ne s'efface qu'au-dessus
	# d'elle ; les clics ne la traversent que là.
	if not await _load("training_b.map"):
		return
	var roof := _trench_roof()
	assert_false(roof.materials.is_empty(), "matériaux propres au toit")
	var area := roof.areas[0]
	var inside := Vector3(area.get_center().x, roof.ceiling, area.get_center().y)
	assert_true(roof.reveals_point(inside))
	var far := inside + Vector3(Roof.REVEAL_MARGIN + 20.0, 0.0, 0.0)
	assert_false(roof.reveals_point(far), "terrain voisin gardé")
	roof._fade = 1.0
	assert_true(Roof.is_revealed_body(roof.body, inside))
	assert_false(Roof.is_revealed_body(roof.body, far))
	roof._fade = 0.0


func test_roof_reveals_under_the_mouse() -> void:
	if not await _load("training_b.map"):
		return
	for enemy in node("Enemies").get_children():
		enemy.free()
	var roof := _trench_roof()
	# Les contrôleurs suivent la vraie souris : on les remplace.
	var controllers := get_tree().root.find_children("*", "PlayerController", true, false)
	for controller in controllers:
		controller.set_process(false)
	await frames(10)
	assert_false(roof.is_revealed(), "personne dessous")
	Roof.hovered = roof
	var revealed := await frames_until(func() -> bool: return roof.is_revealed(), 120)
	assert_gt(revealed, 20, "pas tout de suite : délai de survol")
	assert_eq(roof.materials[0].get_shader_parameter(&"reveal"), roof._fade)
	Roof.hovered = null
	# Le fondu suit les images d'affichage (`Roof._process`).
	var hidden := -1
	for i in 600:
		await get_tree().process_frame
		if not roof.is_revealed():
			hidden = i
			break
	assert_gt(hidden, -1, "réaffiché quand la souris s'en va")


func test_scenery_fades_around_operators() -> void:
	if not await _load("training_b.map"):
		return
	await frames(2)
	var alpha: Commando = node("Units/Alpha")
	assert_gte(WorldMaterial.see_through_points.size(), 1)
	assert_true(WorldMaterial.see_through_points.has(alpha.global_position), "position d'Alpha transmise au décor")
	alpha.health.take_damage(1000.0)
	await frames(2)
	assert_false(WorldMaterial.see_through_points.has(alpha.global_position), "pas pour un mort")


func test_roof_detection_is_cached_per_map() -> void:
	if not await _load("training_b.map"):
		return
	# Cache propre au test : celui du joueur reste intact.
	UfoMapLevel.roof_cache_dir = TEST_ROOF_CACHE
	_clear_test_cache()
	await _load("training_b.map")
	var map: UfoMapLevel = node("NavigationRegion3D/Map")
	assert_false(map.roofs_from_cache, "premier chargement : repérage")
	var first := level.find_children("Roof*", "Roof", true, false).size()
	await _load("training_b.map")
	map = node("NavigationRegion3D/Map")
	assert_true(map.roofs_from_cache, "ensuite : lu dans le cache")
	assert_eq(level.find_children("Roof*", "Roof", true, false).size(), first)
	_clear_test_cache()


func _clear_test_cache() -> void:
	if not DirAccess.dir_exists_absolute(TEST_ROOF_CACHE):
		return
	for file in DirAccess.get_files_at(TEST_ROOF_CACHE):
		DirAccess.remove_absolute(TEST_ROOF_CACHE.path_join(file))
