@tool
extends RefCounted
## Vérification d'une carte ouverte dans l'éditeur (bouton « Vérifier ») :
## équipe, informations de la mission et cibles des objectifs, rondes,
## nombre de gardes, et chemins à pied depuis le départ de l'équipe vers
## chaque cible et vers l'extraction (navigation calculée dans l'éditeur,
## comme `build/shots/check_map.sh` le fait en jeu), avec les passages que
## le jeu crée au lancement : échelles, portes (même verrouillées : on les
## crochète ou on les fait sauter), murets, fenêtres (`link_ends`) ; à
## défaut, par une corde de grappin (`GrapnelRope.plan`, le calcul du jeu),
## si un grappin est emporté.
## Contrôles de placement : opérateurs vus par un garde dès le départ,
## unités dans un obstacle ou les unes dans les autres, caisses et cibles
## qui se chevauchent, éléments hors du terrain ou loin des limites de la
## caméra, points de ronde hors de la zone praticable ou inaccessibles.
## Événements scriptés : chacun déclenché (objectif de la mission ou zone),
## zones reliées à un événement et atteignables à pied.
##
## Chaque problème : {"level": "error" | "warning" | "ok", "text", "nodes"}.
## `check` est une coroutine (la navigation est prête après quelques images).

const MissionTargets := preload("res://addons/mission_editor/mission_targets.gd")
const Coverage := preload("res://addons/mission_editor/coverage.gd")
const Gizmos := preload("res://addons/mission_editor/gizmos.gd")
const Palette := preload("res://addons/mission_editor/palette.gd")
const Events := preload("res://addons/mission_editor/events.gd")

## Au-delà, la carte devient lente (72 gardes : 10 images/s).
const MAX_ENEMIES := 40
const MAX_OPERATORS := 6
## Une cible plus loin que cela (m) de la zone praticable, mesuré depuis le
## bord de son emprise au sol (convertible, bâtiment…), n'est pas atteignable.
const REACH := 2.0
## Corde de grappin : points d'arrivée essayés autour de la cible (pas et
## rayon de la grille, nombre au plus), directions et distances de lancer.
const ROPE_GRID := 3.0
const ROPE_RADIUS := 24.0
const ROPE_TOPS := 60
const ROPE_DIRECTIONS := 12
const ROPE_DISTANCES: Array[float] = [2.0, 4.0, 6.0, 8.0, 10.0]
## Images d'attente au plus pour que la carte de navigation soit prête.
const SYNC_FRAMES := 120
## Couches du sol et du décor (obstacles où une unité ne peut pas être).
const MASK_SOLID := 0b11
## Volume d'une unité pour le contrôle « dans un obstacle » : cylindre
## au-dessus des pieds (le sol n'est pas touché).
const UNIT_RADIUS := 0.25
const UNIT_FOOT := 0.3
const UNIT_HEIGHT := 1.2
## Deux unités plus proches que cela (m, à plat) se chevauchent.
const UNIT_SPACING := 0.6
## Réduction des caisses et cibles avant de chercher un chevauchement
## (des caisses qui se touchent ou s'empilent sont voulues).
const SHRINK := 0.9
## Hauteur visée sur un opérateur au départ (debout, comme le jeu).
const STANDING_HEIGHT := 1.4
## Marge (m) au-delà des limites de la caméra (`CameraRig.bounds`, centre
## de la vue) : un élément plus loin ne peut pas être montré au centre ni
## près du bord de l'écran.
const CAMERA_MARGIN := 10.0
## Un point de ronde plus loin que cela (m) de la zone praticable n'y est pas.
const PATROL_REACH := 1.0


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
	_check_events(root, report)
	_check_placement(root, operators, report)
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


## Événements scriptés et zones de déclenchement.
static func _check_events(root: Node, report: Array[Dictionary]) -> void:
	var ids: Array[String] = []
	var path := MissionInfo.path_for(root.scene_file_path)
	if ResourceLoader.exists(path):
		for objective in (load(path) as MissionInfo).objectives:
			if objective:
				ids.append(String(objective.id))
	for event in Events.events(root):
		var zones := Events.zones_of(root, event)
		var start: StringName = event.get("start_objective")
		if start == &"" and zones.is_empty():
			report.append(_item("warning", "%s : rien ne le déclenche (ni objectif, ni zone de déclenchement)." % event.name, [event]))
		elif start != &"" and not String(start) in ids:
			report.append(_item("warning" if zones.is_empty() else "ok", "%s : l'objectif déclencheur « %s » n'est pas un objectif de la mission%s." % [event.name, start, "" if zones.is_empty() else " (ses zones le déclenchent)"], [event]))
		var target: NodePath = event.get("target")
		if not target.is_empty() and event.get_node_or_null(target) == null:
			report.append(_item("error", "%s : sa cible %s n'existe pas." % [event.name, target], [event]))
		elif target.is_empty() and zones.is_empty():
			report.append(_item("error", "%s : pas de cible (target) vers laquelle foncer, ni de zone." % event.name, [event]))
		if int(event.get("count")) <= 0 and not event.get("technical"):
			report.append(_item("warning", "%s : personne n'arrive (aucun soldat, pas de pick-up)." % event.name, [event]))
		# Arrivée sur le terrain : soldats côte à côte, pick-up devant.
		var terrain := Palette.ground_bounds(root)
		if terrain.size != Vector3.ZERO:
			var outside := Reinforcements.spawn_spots(event.global_transform, event.get("count"), event.get("technical")).filter(func(spot: Vector3) -> bool:
				return spot.x < terrain.position.x + 1.0 or spot.x > terrain.end.x - 1.0 or spot.z < terrain.position.z + 1.0 or spot.z > terrain.end.z - 1.0)
			if not outside.is_empty():
				report.append(_item("error", "%s : %d arrivant%s hors du terrain (ils tomberaient) ; rapprochez le point du centre ou tournez-le." % [event.name, outside.size(), "s" if outside.size() > 1 else ""], [event]))
	for zone in Events.zones(root):
		var linked: NodePath = zone.get("event")
		if Events.event_of(zone) == null:
			report.append(_item("error", "%s : %s." % [zone.name, "ne déclenche rien (event vide)" if linked.is_empty() else "son événement %s n'existe pas ou ne se déclenche pas" % linked], [zone]))


static func _check_enemies(root: Node, report: Array[Dictionary]) -> void:
	var enemies := root.find_children("*", "", true, true).filter(func(n: Node) -> bool: return n is Enemy)
	if enemies.size() > MAX_ENEMIES:
		report.append(_item("warning", "%d gardes : au-delà de %d, la carte risque d'être lente." % [enemies.size(), MAX_ENEMIES], enemies))
	for node in root.find_children("*", "", true, true):
		if node is Reinforcements:
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
	var links := _create_links(root, map)
	# La carte est synchronisée par le serveur de navigation, à l'image, et
	# la région y entre après coup (calcul en arrière-plan) : prête quand
	# elle porte le point le plus proche du départ.
	var ready := false
	var tree := root.get_tree()
	var start_at := start.global_position
	for k in SYNC_FRAMES:
		await tree.physics_frame
		# Scène fermée pendant l'attente (autre scène ouverte) : abandon.
		if not is_instance_valid(root) or not root.is_inside_tree():
			_free(map, nav_region, links)
			return
		if NavigationServer3D.map_get_iteration_id(map) > 0 \
				and NavigationServer3D.map_get_closest_point_owner(map, start_at) == nav_region:
			ready = true
			break
	if not ready:
		report.append(_item("warning", "Navigation pas prête : chemins non vérifiés."))
		_free(map, nav_region, links)
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
		elif zone is TriggerZone and Events.event_of(zone):
			goals[zone] = goals.get(zone, []) + ["déclenche %s" % Events.event_of(zone).name]
	var blocked := 0
	var roped := 0
	for node: Node3D in goals:
		var target := node.global_position
		if node is Passerby or node is TrafficCar:
			continue
		var near := NavigationServer3D.map_get_closest_point(map, target)
		var path := NavigationServer3D.map_get_path(map, from, near, true)
		var reached := not path.is_empty() and path[path.size() - 1].distance_to(near) < 0.5
		var flat := 0.0 if node is TriggerZone and node.call(&"covers", near) else _distance_to_footprint(node, near)
		if not reached or flat > REACH:
			var rope := _rope_route(root, map, from, near)
			if not rope.is_empty():
				roped += 1
				var foot: Vector3 = rope["foot"]
				report.append(_item("ok", "%s (%s) : atteint par une corde de grappin, lancée depuis (%.0f, %.0f) jusqu'à %.1f m (grappin à emporter)." % [node.name, ", ".join(goals[node]), foot.x, foot.z, (rope["top"] as Vector3).y - foot.y], [node]))
				continue
			blocked += 1
			report.append(_item("warning", "%s (%s) : pas de chemin depuis %s, même avec une corde de grappin." % [node.name, ", ".join(goals[node]), start.name], [node]))
	if blocked == 0 and not goals.is_empty():
		report.append(_item("ok", "Chemins depuis %s : %d cibles atteignables%s (%d passages : échelles, portes, murets, fenêtres)." % [start.name, goals.size(), ", dont %d par une corde de grappin" % roped if roped > 0 else "", links.size()]))
	_check_patrols(root, map, report)
	_free(map, nav_region, links)


## Points des rondes (gardes et pick-ups) : chacun sur la zone praticable et
## rejoint depuis le précédent, de l'unité au premier point puis jusqu'au
## retour au premier. Un seul avertissement par ronde.
static func _check_patrols(root: Node, map: RID, report: Array[Dictionary]) -> void:
	for node in root.find_children("*", "", true, true):
		if not (node is Enemy or node is Technical):
			continue
		var path := Gizmos.patrol_of(node)
		if path == null or path.curve == null or path.curve.point_count < 2:
			continue
		var points := PackedVector3Array()
		for i in path.curve.point_count:
			points.append(path.to_global(path.curve.get_point_position(i)))
		var problem := ""
		for i in points.size():
			var near := NavigationServer3D.map_get_closest_point(map, points[i])
			if Vector2(near.x - points[i].x, near.z - points[i].z).length() > PATROL_REACH or absf(near.y - points[i].y) > PATROL_REACH:
				problem = "point %d hors de la zone praticable" % (i + 1)
				break
		if problem.is_empty():
			var stops: Array = [(node as Node3D).global_position]
			stops.append_array(Array(points))
			if points.size() > 2:
				stops.append(points[0])
			for i in stops.size() - 1:
				var a := NavigationServer3D.map_get_closest_point(map, stops[i])
				var b := NavigationServer3D.map_get_closest_point(map, stops[i + 1])
				var route := NavigationServer3D.map_get_path(map, a, b, true)
				if route.is_empty() or route[route.size() - 1].distance_to(b) > 0.5:
					problem = ("premier point inaccessible depuis sa place" if i == 0 else
						"point %d inaccessible depuis le point %d" % [(i % points.size()) + 1, i])
					break
		if not problem.is_empty():
			report.append(_item("warning", "%s : ronde %s, %s." % [node.name, path.name, problem], [node, path]))


# --- Placement ----------------------------------------------------------------

static func _check_placement(root: Node, operators: Array, report: Array[Dictionary]) -> void:
	var space := (root as Node3D).get_world_3d().direct_space_state
	# Carte UFO:AI qui place l'équipe au lancement sur ses départs
	# (`UfoMapLevel.units_parent`), pas où la scène la met ; une carte de
	# fond (sans `units_parent`) laisse l'équipe où elle est posée.
	var placed_later := root.find_children("*", "UfoMapLevel", true, false).any(func(map: Node) -> bool: return not (map.get("units_parent") as NodePath).is_empty())
	if not placed_later:
		_check_sight(root, operators, space, report)
	var units := root.find_children("*", "", true, true).filter(func(n: Node) -> bool:
		return (n is Commando and not placed_later) or n is Vip or n is Enemy or n is Guest)
	_check_units(units, space, report)
	var props := root.find_children("*", "", true, true).filter(func(n: Node) -> bool: return n is Climbable or n is SabotageTarget)
	_check_props(props, space, report)
	_check_bounds(root, placed_later, report)


## Opérateurs vus par un garde dès le départ (sauf insertion en vol :
## l'équipe commence à bord).
static func _check_sight(root: Node, operators: Array, space: PhysicsDirectSpaceState3D, report: Array[Dictionary]) -> void:
	for aircraft in root.find_children("*", "", true, true):
		if aircraft is Tiltrotor and aircraft.get("insertion"):
			return
	var night: bool = root.get("night")
	for guard in root.find_children("*", "", true, true):
		var config := Coverage.config_of(guard, night)
		if config == null:
			continue
		for unit: Node3D in operators:
			var level := Coverage.sees(space, (guard as Node3D).global_transform, config, unit.global_position, STANDING_HEIGHT)
			if level > 0:
				report.append(_item("warning", "%s est vu par %s dès le départ (zone %s)." % [unit.name, guard.name, "proche" if level == 2 else "lointaine"], [unit, guard]))


## Unités dans un obstacle (mur, caisse, bâtiment…) ou les unes dans les
## autres.
static func _check_units(units: Array, space: PhysicsDirectSpaceState3D, report: Array[Dictionary]) -> void:
	var shape := CylinderShape3D.new()
	shape.radius = UNIT_RADIUS
	shape.height = UNIT_HEIGHT
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = MASK_SOLID
	for unit: Node3D in units:
		query.transform = Transform3D(Basis.IDENTITY, unit.global_position + Vector3.UP * (UNIT_FOOT + UNIT_HEIGHT * 0.5))
		query.exclude = _bodies(unit)
		var hits := space.intersect_shape(query, 1)
		if not hits.is_empty():
			var other := hits[0]["collider"] as Node
			report.append(_item("warning", "%s est dans un obstacle (%s)." % [unit.name, _label(other)], [unit, other] if other else [unit]))
	for i in units.size():
		for j in range(i + 1, units.size()):
			var a := (units[i] as Node3D).global_position
			var b := (units[j] as Node3D).global_position
			if Vector2(a.x - b.x, a.z - b.z).length() < UNIT_SPACING and absf(a.y - b.y) < UNIT_HEIGHT:
				report.append(_item("warning", "%s et %s se chevauchent." % [units[i].name, units[j].name], [units[i], units[j]]))


## Caisses et cibles de sabotage qui en chevauchent d'autres ou un mur
## (formes réduites : se toucher ou s'empiler est permis).
static func _check_props(props: Array, space: PhysicsDirectSpaceState3D, report: Array[Dictionary]) -> void:
	var seen := {}
	for prop: Node3D in props:
		for owner_shape in prop.find_children("*", "CollisionShape3D", true, false):
			var box := (owner_shape as CollisionShape3D).shape as BoxShape3D
			if box == null or (owner_shape as CollisionShape3D).disabled:
				continue
			var smaller := BoxShape3D.new()
			smaller.size = box.size * SHRINK
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = smaller
			query.collision_mask = MASK_SOLID
			query.transform = (owner_shape as CollisionShape3D).global_transform.orthonormalized()
			query.exclude = _bodies(prop)
			var hits := space.intersect_shape(query, 1)
			if hits.is_empty():
				continue
			var other := hits[0]["collider"] as Node
			var key := [prop, other] if prop.get_instance_id() < (other.get_instance_id() if other else 0) else [other, prop]
			if seen.has(key):
				break
			seen[key] = true
			report.append(_item("warning", "%s chevauche %s." % [prop.name, _label(other)], [prop, other] if other else [prop]))
			break


## Éléments hors du terrain (sol `NavigationRegion3D/Ground`) ou loin des
## limites de la caméra.
static func _check_bounds(root: Node, placed_later: bool, report: Array[Dictionary]) -> void:
	var ground := Palette.ground_bounds(root)
	var rig := root.get_node_or_null(^"CameraRig")
	var camera: Variant = rig.get("bounds") if rig else null
	var items := root.find_children("*", "", true, true).filter(func(n: Node) -> bool:
		return (n is Commando and not placed_later) or n is Vip or n is Enemy or n is Technical or n is Guest or n is Climbable \
			or n is SabotageTarget or n is Tiltrotor or n is Sabre or n is Landmine or n is ExtractionZone)
	for node: Node3D in items:
		var spots: Array = [node.global_position]
		var path := Gizmos.patrol_of(node) if not node is EnemyAircraft else null
		if path and path.curve:
			for i in path.curve.point_count:
				spots.append(path.to_global(path.curve.get_point_position(i)))
		for spot: Vector3 in spots:
			var where := "" if spot == node.global_position else " (ronde %s)" % path.name
			if ground.size != Vector3.ZERO and not _inside(ground, spot, 0.0):
				report.append(_item("warning", "%s%s est hors du terrain." % [node.name, where], [node]))
				break
			if camera is AABB and not _inside(camera, spot, CAMERA_MARGIN):
				report.append(_item("warning", "%s%s est à plus de %d m des limites de la caméra (CameraRig.bounds) : on ne pourra pas le voir." % [node.name, where, int(CAMERA_MARGIN)], [node, rig]))
				break


static func _inside(box: AABB, point: Vector3, margin: float) -> bool:
	return point.x >= box.position.x - margin and point.x <= box.end.x + margin \
		and point.z >= box.position.z - margin and point.z <= box.end.z + margin


## Corps de collision de `node` et de ses enfants (à ne pas compter).
static func _bodies(node: Node) -> Array[RID]:
	var rids: Array[RID] = []
	for item in [node] + node.find_children("*", "CollisionObject3D", true, false):
		if item is CollisionObject3D:
			rids.append((item as CollisionObject3D).get_rid())
	return rids


## Nom lisible d'un obstacle touché : le nœud de la carte qui le porte.
static func _label(node: Node) -> String:
	if node == null:
		return "obstacle"
	var owner_node := node
	while owner_node.owner and owner_node.owner != owner_node.get_tree().edited_scene_root and owner_node.get_parent():
		owner_node = owner_node.get_parent()
	return String(owner_node.name)


## Corde de grappin qui mène de la zone atteinte depuis `from` à celle de
## `goal` (points de la carte `map`) : {"foot", "top"} du premier lancer
## trouvé (`GrapnelRope.plan`), ou vide. Une seule corde, pas de chaîne.
static func _rope_route(root: Node, map: RID, from: Vector3, goal: Vector3) -> Dictionary:
	var world := (root as Node3D).get_world_3d()
	var space := world.direct_space_state
	# Points d'arrivée : la zone de la cible, autour d'elle.
	var tops: Array[Vector3] = [goal]
	var seen := {}
	var steps := int(ROPE_RADIUS / ROPE_GRID)
	for dx in range(-steps, steps + 1):
		for dz in range(-steps, steps + 1):
			var point := NavigationServer3D.map_get_closest_point(map, goal + Vector3(dx * ROPE_GRID, 0.0, dz * ROPE_GRID))
			var key := Vector3i(point.snapped(Vector3.ONE * ROPE_GRID * 0.5))
			if seen.has(key) or point.y - from.y < GrapnelRope.MIN_HEIGHT or not _joins(map, point, goal):
				continue
			seen[key] = true
			tops.append(point)
	tops.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.distance_squared_to(from) < b.distance_squared_to(from))
	var reachable := {}
	for top: Vector3 in tops.slice(0, ROPE_TOPS):
		for i in ROPE_DIRECTIONS:
			var angle := TAU * i / ROPE_DIRECTIONS
			for distance: float in ROPE_DISTANCES:
				var guess := top + Vector3(cos(angle), 0.0, sin(angle)) * distance
				var foot := NavigationServer3D.map_get_closest_point(map, Vector3(guess.x, from.y, guess.z))
				if top.y - foot.y < GrapnelRope.MIN_HEIGHT:
					continue
				var key := Vector3i(foot.snapped(Vector3.ONE * 0.5) * 2.0)
				if not reachable.has(key):
					reachable[key] = _joins(map, from, foot)
				if not reachable[key]:
					continue
				# `plan` attend, comme en jeu, des points sur les surfaces (la
				# navigation flotte un peu au-dessus).
				var route := GrapnelRope.plan(world, _surface(space, foot), _surface(space, top), map)
				if route["ok"] and _joins(map, from, route["foot"]):
					return route
	return {}


## Point `point` de la navigation ramené sur la surface au-dessous.
static func _surface(space: PhysicsDirectSpaceState3D, point: Vector3) -> Vector3:
	var height := GrapnelRope._ground_height(space, point, point.y + 0.5, point.y - 2.0)
	return Vector3(point.x, height, point.z) if not is_nan(height) else point


## Un chemin mène-t-il de `a` à `b` sur la carte `map` ?
static func _joins(map: RID, a: Vector3, b: Vector3) -> bool:
	var end := NavigationServer3D.map_get_closest_point(map, b)
	var path := NavigationServer3D.map_get_path(map, NavigationServer3D.map_get_closest_point(map, a), end, true)
	return not path.is_empty() and path[path.size() - 1].distance_to(end) < 0.5


## Distance horizontale (m) du point `point` à l'emprise au sol de `node`
## (maillages qu'il affiche, construits par son script compris) ; à défaut,
## à sa position.
static func _distance_to_footprint(node: Node3D, point: Vector3) -> float:
	var bounds := AABB()
	var found := false
	var items: Array = [node]
	items.append_array(node.find_children("*", "VisualInstance3D", true, false))
	for item in items:
		if not item is VisualInstance3D:
			continue
		var box: AABB = (item as VisualInstance3D).global_transform * (item as VisualInstance3D).get_aabb()
		bounds = box if not found else bounds.merge(box)
		found = true
	if not found:
		return Vector2(point.x - node.global_position.x, point.z - node.global_position.z).length()
	var dx := maxf(maxf(bounds.position.x - point.x, point.x - bounds.end.x), 0.0)
	var dz := maxf(maxf(bounds.position.z - point.z, point.z - bounds.end.z), 0.0)
	return Vector2(dx, dz).length()


## Passages de navigation (`TraversalLink`) que le jeu crée au lancement,
## recréés dans la carte `map` d'après les nœuds qui les décrivent
## (`link_ends`, y compris les portes et fenêtres construites par les
## bâtiments).
static func _create_links(root: Node, map: RID) -> Array[RID]:
	var links: Array[RID] = []
	for node in root.find_children("*", "Node3D", true, false):
		if not node.has_method(&"link_ends"):
			continue
		var frame := (node as Node3D).global_transform
		for ends: PackedVector3Array in node.call(&"link_ends"):
			var link := NavigationServer3D.link_create()
			NavigationServer3D.link_set_map(link, map)
			NavigationServer3D.link_set_bidirectional(link, true)
			NavigationServer3D.link_set_start_position(link, frame * ends[0])
			NavigationServer3D.link_set_end_position(link, frame * ends[1])
			links.append(link)
	return links


static func _free(map: RID, region: RID, links: Array[RID]) -> void:
	for link in links:
		NavigationServer3D.free_rid(link)
	NavigationServer3D.free_rid(region)
	NavigationServer3D.free_rid(map)
