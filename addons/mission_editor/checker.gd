@tool
extends RefCounted
## Vérification d'une carte ouverte dans l'éditeur (bouton « Vérifier ») :
## équipe, informations de la mission et cibles des objectifs, rondes,
## nombre de gardes, et chemins à pied depuis le départ de l'équipe vers
## chaque cible et vers l'extraction (navigation calculée dans l'éditeur,
## comme `build/shots/check_map.sh` le fait en jeu).
##
## Chaque problème : {"level": "error" | "warning" | "ok", "text", "nodes"}.
## `check` est une coroutine (la navigation est prête après quelques images).

const MissionTargets := preload("res://addons/mission_editor/mission_targets.gd")

## Au-delà, la carte devient lente (72 gardes : 10 images/s).
const MAX_ENEMIES := 40
const MAX_OPERATORS := 6
## Une cible plus loin que cela de la zone praticable n'est pas atteignable.
const REACH := 4.0
## Images d'attente au plus pour que la carte de navigation soit prête.
const SYNC_FRAMES := 120


static func check(root: Node) -> Array[Dictionary]:
	var report: Array[Dictionary] = []
	if not root is LevelRoot:
		report.append(_item("error", "La scène ouverte n'est pas une mission (racine LevelRoot)."))
		return report
	var operators := _operators(root)
	if operators.is_empty():
		report.append(_item("error", "Aucun opérateur sous Units : l'équipe n'a pas de point de départ."))
	elif operators.size() > MAX_OPERATORS:
		report.append(_item("error", "%d opérateurs : six au plus." % operators.size(), operators))
	_check_info(root, report)
	_check_enemies(root, report)
	if not operators.is_empty():
		await _check_paths(root, operators[0] as Node3D, report)
	if report.filter(func(item: Dictionary) -> bool: return item["level"] != "ok").is_empty():
		report.push_front(_item("ok", "Aucun problème trouvé."))
	return report


static func _item(level: String, text: String, nodes: Array = []) -> Dictionary:
	return {"level": level, "text": text, "nodes": nodes}


static func _operators(root: Node) -> Array:
	var units := root.get_node_or_null(^"Units")
	if units == null:
		return []
	return units.get_children().filter(func(n: Node) -> bool: return n is Commando)


static func _check_info(root: Node, report: Array[Dictionary]) -> void:
	var path := MissionInfo.path_for(root.scene_file_path)
	if not ResourceLoader.exists(path):
		report.append(_item("warning", "Pas de %s : la mission n'apparaît pas dans le choix des missions." % path.get_file()))
		return
	var info := load(path) as MissionInfo
	if info.title.is_empty():
		report.append(_item("warning", "La mission n'a pas de titre."))
	if info.objectives.is_empty():
		report.append(_item("error", "La mission n'a aucun objectif."))
	var found := MissionTargets.targets(root)
	for objective in info.objectives:
		if objective == null or objective.id.is_empty():
			report.append(_item("error", "Objectif sans identifiant."))
			continue
		if not objective.id in MissionObjective.KNOWN_IDS:
			report.append(_item("warning", "Objectif « %s » : identifiant inconnu du jeu." % objective.id))
		var nodes: Variant = MissionTargets.targets_of(objective.id, found)
		if nodes is Array and (nodes as Array).is_empty():
			report.append(_item("error", "Objectif « %s » (%s) : aucune cible sur la carte." % [objective.text, objective.id]))


static func _check_enemies(root: Node, report: Array[Dictionary]) -> void:
	var enemies := root.find_children("*", "", true, true).filter(func(n: Node) -> bool: return n is Enemy)
	if enemies.size() > MAX_ENEMIES:
		report.append(_item("warning", "%d gardes : au-delà de %d, la carte risque d'être lente." % [enemies.size(), MAX_ENEMIES], enemies))
	for node in root.find_children("*", "", true, true):
		if node is Reinforcements:
			var target: NodePath = node.get("target")
			if target.is_empty() or node.get_node_or_null(target) == null:
				report.append(_item("error", "%s : pas de cible (target) vers laquelle foncer." % node.name, [node]))
			continue
		if not (node is Enemy or node is Technical or node is EnemyAircraft):
			continue
		var value: Variant = node.get("patrol_path")
		if value == null or (value is NodePath and (value as NodePath).is_empty()):
			if node is Technical or node is EnemyAircraft:
				report.append(_item("error", "%s n'a pas de trajet (patrol_path)." % node.name, [node]))
			continue
		var path := value as Path3D if value is Path3D else node.get_node_or_null(value as NodePath) as Path3D
		if path == null:
			report.append(_item("error", "%s : son trajet %s n'existe pas." % [node.name, value], [node]))
		elif path.curve == null or path.curve.point_count < 2:
			report.append(_item("error", "%s : son trajet %s a moins de deux points." % [node.name, path.name], [node, path]))


## Chemins à pied depuis `start` vers chaque cible d'objectif et chaque zone
## d'extraction, sur la navigation calculée dans l'éditeur.
static func _check_paths(root: Node, start: Node3D, report: Array[Dictionary]) -> void:
	var region := root.get_node_or_null(^"NavigationRegion3D") as NavigationRegion3D
	if region == null or region.navigation_mesh == null:
		report.append(_item("error", "Pas de NavigationRegion3D avec un maillage : les unités ne pourront pas se déplacer."))
		return
	var mesh := region.navigation_mesh.duplicate() as NavigationMesh
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(mesh, source, region)
	NavigationServer3D.bake_from_source_geometry_data(mesh, source)
	if mesh.get_polygon_count() == 0:
		report.append(_item("error", "Le calcul de la navigation ne donne aucune zone praticable (sol absent ?)."))
		return
	var map := NavigationServer3D.map_create()
	NavigationServer3D.map_set_cell_size(map, mesh.cell_size)
	NavigationServer3D.map_set_cell_height(map, mesh.cell_height)
	NavigationServer3D.map_set_active(map, true)
	var nav_region := NavigationServer3D.region_create()
	NavigationServer3D.region_set_map(nav_region, map)
	NavigationServer3D.region_set_navigation_mesh(nav_region, mesh)
	# La carte est synchronisée par le serveur de navigation, à l'image, et
	# la région y entre après coup (calcul en arrière-plan) : prête quand
	# elle porte le point le plus proche du départ.
	var ready := false
	for k in SYNC_FRAMES:
		await root.get_tree().physics_frame
		if NavigationServer3D.map_get_iteration_id(map) > 0 \
				and NavigationServer3D.map_get_closest_point_owner(map, start.global_position) == nav_region:
			ready = true
			break
	if not ready:
		report.append(_item("warning", "Navigation pas prête : chemins non vérifiés."))
		NavigationServer3D.free_rid(nav_region)
		NavigationServer3D.free_rid(map)
		return
	var from := NavigationServer3D.map_get_closest_point(map, start.global_position)
	var goals := {}
	var found := MissionTargets.targets(root)
	for id: String in found:
		if id == "all_enemies_down":
			continue
		for node: Node in found[id]:
			if node is Node3D and node != start:
				goals[node] = goals.get(node, []) + [id]
	for zone in root.find_children("*", "", true, true):
		if zone is ExtractionZone:
			goals[zone] = goals.get(zone, []) + ["extraction"]
	var blocked := 0
	for node: Node3D in goals:
		var target := node.global_position
		if node is Passerby or node is TrafficCar:
			continue
		var near := NavigationServer3D.map_get_closest_point(map, target)
		var path := NavigationServer3D.map_get_path(map, from, near, true)
		var reached := not path.is_empty() and path[path.size() - 1].distance_to(near) < 0.5
		var flat := Vector2(near.x - target.x, near.z - target.z).length()
		if not reached or flat > REACH:
			blocked += 1
			report.append(_item("warning", "%s (%s) : pas de chemin à pied depuis %s (échelles, cordes et portes ne sont pas comptées)." % [node.name, ", ".join(goals[node]), start.name], [node]))
	if blocked == 0 and not goals.is_empty():
		report.append(_item("ok", "Chemins à pied depuis %s : %d cibles atteignables." % [start.name, goals.size()]))
	NavigationServer3D.free_rid(nav_region)
	NavigationServer3D.free_rid(map)
