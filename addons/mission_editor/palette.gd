@tool
extends RefCounted
## Éléments que le greffon pose sur une carte, rangés par catégorie, comme
## `tools/mapkit.py` (`MapBuilder`) les écrit : nœud, script ou scène,
## parent (`NavigationRegion3D` pour ce qui découpe la navigation, `Decor`
## pour le reste…) et réglages par défaut.
##
## Une entrée : {"id", "label", "category", "parent", "tool"} où `tool` vaut
## "point" (un clic), "line" (deux clics : début et fin) ou "route" (un
## clic par point, double-clic ou Entrée pour finir) ; "ground": true
## pour ce qui se pose toujours au sol (revêtements, bâtiments, civils…),
## les autres se posent aussi sur les toits et les étages ; "rect": true
## pour un tracé à deux clics qui donne un rectangle (coins opposés).

const CATEGORIES: Array[String] = ["Décor", "Relief et plans", "Obstacles", "Équipe", "Ravitaillement", "Ennemis", "Événements", "Civils", "Objectifs", "Extraction et véhicules"]

## Revêtements posés à la ligne : couleur, hauteur, largeur par défaut.
const SURFACES := {
	"road": {"color": Color(0.19, 0.19, 0.2), "y": 0.016, "width": 9.0},
	"sidewalk": {"color": Color(0.55, 0.54, 0.5), "y": 0.008, "width": 2.5},
	"track": {"color": Color(0.5, 0.42, 0.3), "y": 0.01, "width": 4.5},
}

const WALL_LENGTH := 6.0
## Barrière : largeur par défaut, et écart des murets de part et d'autre
## (au-delà de la demi-largeur), comme `MapBuilder.barrier`.
const BARRIER_WIDTH := 4.6
const BARRIER_POST := 1.85
## Noms des opérateurs, dans l'ordre de `unit_index`.
const OPERATOR_NAMES: Array[String] = ["Alpha", "Bravo", "Charlie", "Delta", "Echo", "Foxtrot"]
## Rayon des virages d'une boucle de voitures (m), comme `MapBuilder.traffic`.
const CAR_TURN := 4.0
## Métadonnée provisoire : parent d'un nœud, quand ce n'est pas celui de
## l'entrée (retirée avant la pose).
const PARENT_META := &"_mission_editor_parent"
## Pick-up qui arrive : délai (s) entre l'entrée dans la zone et son arrivée.
const ARRIVAL_DELAY := 8.0
## Plus petit côté d'une zone de déclenchement (m).
const ZONE_MIN := 2.0
## Plus petit côté d'un plateau ou d'une pièce (m).
const PLAN_MIN := 2.0

const ENEMY_SCENE := "res://scenes/enemies/enemy.tscn"
const COMMANDO_SCENE := "res://scenes/units/commando.tscn"
const VIP_SCENE := "res://scenes/units/vip.tscn"


## Toutes les entrées, dans l'ordre d'affichage.
static func entries() -> Array[Dictionary]:
	return [
		{"ground": true, "id": "building", "label": "Bâtiment", "category": "Décor", "parent": "NavigationRegion3D", "tool": "point"},
		{"id": "wall_line", "label": "Mur (tracé)", "category": "Décor", "parent": "NavigationRegion3D", "tool": "line"},
		{"id": "wall", "label": "Mur de 6 m", "category": "Décor", "parent": "NavigationRegion3D", "tool": "point"},
		{"id": "low_wall", "label": "Muret", "category": "Décor", "parent": "NavigationRegion3D", "tool": "point"},
		{"id": "crate", "label": "Caisse", "category": "Décor", "parent": "NavigationRegion3D", "tool": "point"},
		{"id": "heavy_crate", "label": "Caisse lourde (à deux)", "category": "Décor", "parent": "NavigationRegion3D", "tool": "point"},
		{"ground": true, "id": "bush", "label": "Haie / buisson", "category": "Décor", "parent": "Decor", "tool": "point"},
		{"id": "lamp", "label": "Lampadaire", "category": "Décor", "parent": "Lamps", "tool": "point"},
		{"ground": true, "id": "pine", "label": "Sapin enneigé", "category": "Décor", "parent": "NavigationRegion3D", "tool": "point"},
		{"id": "snowfall", "label": "Chute de neige", "category": "Décor", "parent": "Decor", "tool": "point"},
		{"id": "rainfall", "label": "Pluie", "category": "Décor", "parent": "Decor", "tool": "point"},
		{"id": "ladder", "label": "Échelle", "category": "Décor", "parent": "NavigationRegion3D", "tool": "point"},
		{"ground": true, "id": "tower", "label": "Immeuble à étages", "category": "Décor", "parent": "NavigationRegion3D", "tool": "point"},
		{"ground": true, "id": "road", "label": "Route", "category": "Décor", "parent": "Decor", "tool": "line"},
		{"ground": true, "id": "sidewalk", "label": "Trottoir", "category": "Décor", "parent": "Decor", "tool": "line"},
		{"ground": true, "id": "track", "label": "Piste", "category": "Décor", "parent": "Decor", "tool": "line"},
		{"id": "terrace", "label": "Plateau", "category": "Relief et plans", "parent": "NavigationRegion3D", "tool": "line", "rect": true},
		{"id": "plan_room", "label": "Pièce", "category": "Relief et plans", "parent": "NavigationRegion3D", "tool": "line", "rect": true},
		{"id": "plan_door", "label": "Porte", "category": "Relief et plans", "parent": "NavigationRegion3D", "tool": "point"},
		{"id": "plan_window", "label": "Fenêtre", "category": "Relief et plans", "parent": "NavigationRegion3D", "tool": "point"},
		{"id": "plan_stairs", "label": "Escalier", "category": "Relief et plans", "parent": "NavigationRegion3D", "tool": "point"},
		{"id": "mine", "label": "Mine", "category": "Obstacles", "parent": "NavigationRegion3D", "tool": "point"},
		{"id": "ied", "label": "Engin improvisé", "category": "Obstacles", "parent": "NavigationRegion3D", "tool": "point"},
		{"ground": true, "id": "barrier", "label": "Barrière", "category": "Obstacles", "parent": "NavigationRegion3D", "tool": "point"},
		{"id": "operator", "label": "Opérateur", "category": "Équipe", "parent": "Units", "tool": "point"},
		{"id": "vip", "label": "VIP", "category": "Équipe", "parent": "Units", "tool": "point"},
		{"id": "supply_ammo", "label": "Chargeurs", "category": "Ravitaillement", "parent": "Pickups", "tool": "point"},
		{"id": "supply_grenades", "label": "Grenades", "category": "Ravitaillement", "parent": "Pickups", "tool": "point"},
		{"id": "supply_smoke", "label": "Fumigènes", "category": "Ravitaillement", "parent": "Pickups", "tool": "point"},
		{"id": "supply_medkit", "label": "Trousse de soins", "category": "Ravitaillement", "parent": "Pickups", "tool": "point"},
		{"id": "guard", "label": "Garde posté", "category": "Ennemis", "parent": "Enemies", "tool": "point"},
		{"id": "patrol", "label": "Garde en ronde", "category": "Ennemis", "parent": "Enemies", "tool": "route"},
		{"id": "technical", "label": "Pick-up armé", "category": "Ennemis", "parent": "Enemies", "tool": "route"},
		{"id": "aircraft", "label": "Avion ennemi", "category": "Ennemis", "parent": "Enemies", "tool": "route"},
		{"id": "reinforcements", "label": "Renforts", "category": "Événements", "parent": "Enemies", "tool": "point"},
		{"id": "arrival", "label": "Pick-up qui arrive", "category": "Événements", "parent": "Enemies", "tool": "point"},
		{"ground": true, "id": "trigger_zone", "label": "Zone de déclenchement", "category": "Événements", "parent": "Triggers", "tool": "line", "rect": true},
		{"ground": true, "id": "guest", "label": "Invité", "category": "Civils", "parent": "NavigationRegion3D", "tool": "point"},
		{"ground": true, "id": "passerby", "label": "Passant", "category": "Civils", "parent": "Decor", "tool": "route"},
		{"ground": true, "id": "traffic", "label": "Boucle de voitures", "category": "Civils", "parent": "Decor", "tool": "line"},
		{"id": "documents", "label": "Porteur des documents", "category": "Objectifs", "parent": "Enemies", "tool": "point"},
		{"id": "generator", "label": "Groupe électrogène", "category": "Objectifs", "parent": "NavigationRegion3D", "tool": "point"},
		{"id": "fuel_depot", "label": "Dépôt de carburant", "category": "Objectifs", "parent": "NavigationRegion3D", "tool": "point"},
		{"id": "extraction", "label": "Zone d'extraction", "category": "Extraction et véhicules", "parent": ".", "tool": "point"},
		{"id": "tiltrotor", "label": "Convertible d'extraction", "category": "Extraction et véhicules", "parent": "NavigationRegion3D", "tool": "point"},
		{"id": "sabre", "label": "Sabre", "category": "Extraction et véhicules", "parent": "NavigationRegion3D", "tool": "point"},
		{"id": "hexapod", "label": "Hexapode", "category": "Extraction et véhicules", "parent": "NavigationRegion3D", "tool": "point"},
		{"ground": true, "id": "pad", "label": "Aire de poser", "category": "Extraction et véhicules", "parent": "Decor", "tool": "point"},
	]


static func find(id: String) -> Dictionary:
	for entry in entries():
		if entry["id"] == id:
			return entry
	return {}


## Couches visées pour poser en hauteur : sol et décor (toits, planchers,
## dessus des murs).
const SURFACE_MASK := 0b11
## Surface assez horizontale pour y poser (normale vers le haut).
const FLAT := 0.7


## Point de pose sous la position `screen` : la première surface
## horizontale du décor touchée par le rayon de la vue (toit, plancher,
## dessus d'un mur), les faces verticales étant traversées ; à défaut, le
## sol (`ground_point`). x et z aimantés à la grille de pas `step`.
static func surface_point(camera: Camera3D, screen: Vector2, step: float, world: World3D) -> Vector3:
	var origin := camera.project_ray_origin(screen)
	var direction := camera.project_ray_normal(screen)
	var space := world.direct_space_state if world else null
	if space:
		var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 2000.0, SURFACE_MASK)
		var skipped: Array[RID] = []
		for attempt in 8:
			query.exclude = skipped
			var hit := space.intersect_ray(query)
			if hit.is_empty():
				break
			if (hit["normal"] as Vector3).y >= FLAT:
				var point: Vector3 = hit["position"]
				if step > 0.0:
					point = Vector3(snappedf(point.x, step), point.y, snappedf(point.z, step))
				return point
			skipped.append(hit["rid"])
	return ground_point(camera, screen, step)


## Point du sol (plan y = 0) sous la position `screen` de la vue `camera`,
## aimanté à la grille de pas `step` (0 : sans grille) ; INF si le rayon ne
## touche pas le sol.
static func ground_point(camera: Camera3D, screen: Vector2, step: float) -> Vector3:
	var origin := camera.project_ray_origin(screen)
	var direction := camera.project_ray_normal(screen)
	var hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(origin, direction)
	if hit == null:
		return Vector3.INF
	var point: Vector3 = hit
	if step > 0.0:
		point = Vector3(snappedf(point.x, step), 0.0, snappedf(point.z, step))
	return point


## Nœuds à poser pour `id`, au point `at` (sol), cap `facing` (degrés, 0 =
## nord), ou de `at` à `to` pour un outil « ligne ». Les nœuds ne sont pas
## encore dans l'arbre ; `scene_root` sert à retrouver ce qui est déjà
## présent (maillages des revêtements, opérateurs, noms des rondes). Un nœud
## à ranger ailleurs que sous le parent de l'entrée porte `PARENT_META`.
## `route` : points d'un tracé « route » (à défaut, `at` puis `to`).
static func make(id: String, at: Vector3, facing: float, to: Vector3, scene_root: Node, route: PackedVector3Array = PackedVector3Array()) -> Array[Node3D]:
	var nodes: Array[Node3D] = []
	if route.size() < 2:
		route = PackedVector3Array([at, to])
	at = route[0]
	var ahead := route[1]
	match id:
		"building":
			var building := _scripted("Node3D", "res://scripts/props/building.gd", "Building")
			building.set("size", Vector2(8, 6))
			building.set("doors", [Vector3(0, 0, 0)] as Array[Vector3])
			nodes.append(building)
		"wall":
			nodes.append(_instance("res://scenes/props/wall.tscn", "Wall"))
		"low_wall":
			nodes.append(_instance("res://scenes/props/low_wall.tscn", "LowWall"))
		"crate":
			nodes.append(_instance("res://scenes/props/crate.tscn", "Crate"))
		"heavy_crate":
			var heavy := _instance("res://scenes/props/crate.tscn", "HeavyCrate")
			heavy.set("heavy", true)
			nodes.append(heavy)
		"ladder":
			nodes.append(_instance("res://scenes/props/ladder.tscn", "Ladder"))
		"bush":
			var bush := _scripted("Node3D", "res://scripts/props/hiding_spot.gd", "Bush")
			bush.set("size", Vector2(3, 2.4))
			nodes.append(bush)
		"lamp":
			nodes.append(_lamp())
		"pine":
			var pine := _scripted("StaticBody3D", "res://scripts/props/snow_pine.gd", "Pine")
			pine.set("variant", randi() % 8)
			nodes.append(pine)
		"snowfall":
			nodes.append(_scripted("Node3D", "res://scripts/levels/snowfall.gd", "Snowfall"))
		"rainfall":
			nodes.append(_scripted("Node3D", "res://scripts/levels/rainfall.gd", "Rainfall"))
		"tower":
			var tower := _scripted("Node3D", "res://scripts/props/tower.gd", "Tower")
			tower.set("storeys", 3)
			tower.set("size", Vector2(14, 10))
			nodes.append(tower)
		"supply_ammo", "supply_grenades", "supply_smoke", "supply_medkit":
			var kinds := {"supply_ammo": ["Ammo", 0, 2], "supply_grenades": ["Grenades", 1, 2], "supply_smoke": ["Smoke", 2, 2], "supply_medkit": ["Medkit", 3, 1]}
			var spec: Array = kinds[id]
			var supply := _scripted("Node3D", "res://scripts/props/supply_pickup.gd", spec[0])
			supply.set("kind", spec[1])
			supply.set("amount", spec[2])
			nodes.append(supply)
		"mine", "ied":
			var mine := _scripted("Node3D", "res://scripts/props/landmine.gd", "Mine" if id == "mine" else "Ied")
			if id == "ied":
				mine.set("improvised", true)
			nodes.append(mine)
		"barrier":
			# Barrière en travers de la route (cap = sens de la route), un
			# muret de chaque côté.
			var frame := Transform3D(Basis(Vector3.UP, -deg_to_rad(facing)), at)
			var barrier := _scripted("Node3D", "res://scripts/props/road_barrier.gd", "Barrier")
			barrier.set("width", BARRIER_WIDTH)
			barrier.transform = frame
			nodes.append(barrier)
			for side in [-1.0, 1.0]:
				var post := _instance("res://scenes/props/low_wall.tscn", "LowWall")
				post.transform = Transform3D(frame.basis, at + frame.basis.x * side * (BARRIER_WIDTH * 0.5 + BARRIER_POST))
				nodes.append(post)
			return nodes
		"aircraft":
			var sky := _patrol_path(scene_root, route)
			var plane := _scripted("Node3D", "res://scripts/enemies/enemy_aircraft.gd", "Gunship")
			plane.set("patrol_path", NodePath("../../PatrolPaths/%s" % sky.name))
			nodes.append(sky)
			nodes.append(plane)
			return nodes
		"reinforcements":
			var reinforcements := _scripted("Node3D", "res://scripts/levels/reinforcements.gd", "Reinforcements")
			var target := _reinforcement_target(scene_root)
			if target:
				reinforcements.set("target", NodePath("../../NavigationRegion3D/%s" % target.name))
			nodes.append(reinforcements)
		"arrival":
			# Pick-up seul, sans annonce, appelé par une zone de déclenchement
			# (tracée ensuite) ; il fonce vers la zone.
			var arrival := _scripted("Node3D", "res://scripts/levels/reinforcements.gd", "ArrivingTechnical")
			arrival.set("start_objective", &"")
			arrival.set("objective_id", &"")
			arrival.set("delay", ARRIVAL_DELAY)
			arrival.set("count", 0)
			arrival.set("technical", true)
			arrival.set("announce", false)
			nodes.append(arrival)
		"terrace":
			var terrace := _scripted("Node3D", "res://scripts/props/terrace.gd", "Terrace")
			terrace.set("size", Vector2(maxf(absf(to.x - at.x), PLAN_MIN), maxf(absf(to.z - at.z), PLAN_MIN)))
			terrace.transform = Transform3D(Basis.IDENTITY, Vector3((at.x + to.x) * 0.5, minf(at.y, to.y), (at.z + to.z) * 0.5))
			nodes.append(terrace)
			return nodes
		"plan_room":
			# Premier bâtiment dessiné : centré sur sa première pièce (les
			# suivantes s'y ajoutent, `plugin.plan_edit`).
			var plan := _scripted("Node3D", "res://scripts/props/drawn_building.gd", "DrawnBuilding")
			var extent := Vector2(maxf(absf(to.x - at.x), PLAN_MIN), maxf(absf(to.z - at.z), PLAN_MIN))
			plan.set("rooms", [Rect2(-extent * 0.5, extent)] as Array[Rect2])
			plan.set("room_storeys", PackedInt32Array([0]))
			plan.transform = Transform3D(Basis.IDENTITY, Vector3((at.x + to.x) * 0.5, minf(at.y, to.y), (at.z + to.z) * 0.5))
			nodes.append(plan)
			return nodes
		"trigger_zone":
			# Rectangle de coins `at` et `to` ; l'événement est relié par le
			# greffon (`event`).
			var zone := _scripted("Area3D", "res://scripts/levels/trigger_zone.gd", "TriggerZone")
			zone.set("size", Vector2(maxf(absf(to.x - at.x), ZONE_MIN), maxf(absf(to.z - at.z), ZONE_MIN)))
			zone.transform = Transform3D(Basis.IDENTITY, Vector3((at.x + to.x) * 0.5, minf(at.y, to.y), (at.z + to.z) * 0.5))
			nodes.append(zone)
			return nodes
		"pad":
			var pad := MeshInstance3D.new()
			pad.name = "Pad"
			pad.mesh = _pad_mesh(scene_root)
			pad.transform = Transform3D(Basis.IDENTITY, at + Vector3.UP * 0.02)
			nodes.append(pad)
			return nodes
		"wall_line":
			var length := at.distance_to(to)
			var count := maxi(1, ceili(length / WALL_LENGTH))
			var yaw := _yaw(at, to) - PI / 2.0
			for i in count:
				var wall := _instance("res://scenes/props/wall.tscn", "Wall")
				wall.transform = Transform3D(Basis(Vector3.UP, yaw), at.lerp(to, (i + 0.5) / count))
				nodes.append(wall)
			return nodes
		"road", "sidewalk", "track":
			nodes.append(_surface(id, at, to, scene_root))
			return nodes
		"operator":
			var index := _operator_count(scene_root) + 1
			var unit := _instance(COMMANDO_SCENE, OPERATOR_NAMES[mini(index, 6) - 1])
			unit.set("unit_index", mini(index, 6))
			unit.set("display_name", String(unit.name))
			nodes.append(unit)
		"vip":
			nodes.append(_instance(VIP_SCENE, "Vip"))
		"guard", "documents":
			var guard := _instance(ENEMY_SCENE, "Guard" if id == "guard" else "Courier")
			guard.set("stationary", true)
			if id == "documents":
				guard.set("documents", true)
			nodes.append(guard)
		"patrol":
			var path := _patrol_path(scene_root, route)
			var walker := _instance(ENEMY_SCENE, "Patrol")
			walker.transform = Transform3D(Basis(Vector3.UP, _yaw(at, ahead)), at)
			walker.set("patrol_path", path)
			nodes.append(path)
			nodes.append(walker)
			return nodes
		"technical":
			var road := _patrol_path(scene_root, route)
			var truck := _scripted("StaticBody3D", "res://scripts/enemies/technical.gd", "Technical")
			truck.transform = Transform3D(Basis(Vector3.UP, _yaw(at, ahead)), at)
			truck.set("patrol_path", NodePath("../../PatrolPaths/%s" % road.name))
			nodes.append(road)
			nodes.append(truck)
			return nodes
		"guest":
			var guest := _scripted("StaticBody3D", "res://scripts/props/guest.gd", "Guest")
			guest.set("look_seed", randi() % 100003)
			nodes.append(guest)
		"passerby":
			var walker := _scripted("Node3D", "res://scripts/props/passerby.gd", "Passerby")
			walker.set("points", route)
			walker.set("look_seed", randi() % 100003)
			nodes.append(walker)
			return nodes
		"traffic":
			var car := _scripted("AnimatableBody3D", "res://scripts/props/traffic_car.gd", "Car")
			car.set("points", car_loop(at, to))
			car.set("look_seed", randi() % 100003)
			nodes.append(car)
			return nodes
		"generator", "fuel_depot":
			var target := _scripted("StaticBody3D", "res://scripts/props/sabotage_target.gd", "Generator" if id == "generator" else "FuelDepot")
			if id == "fuel_depot":
				target.set("fuel", true)
				target.set("objective_id", &"depot")
			nodes.append(target)
		"extraction":
			var zone := _scripted("Area3D", "res://scripts/levels/extraction_zone.gd", "ExtractionZone")
			zone.set("objective_id", &"extracted")
			nodes.append(zone)
		"tiltrotor":
			var aircraft := _scripted("StaticBody3D", "res://scripts/props/tiltrotor.gd", "Extraction")
			aircraft.set("objective_id", &"extracted")
			aircraft.set("extraction", true)
			aircraft.set("insertion", true)
			nodes.append(aircraft)
		"sabre":
			nodes.append(_scripted("StaticBody3D", "res://scripts/props/sabre.gd", "Sabre"))
		"hexapod":
			nodes.append(_scripted("StaticBody3D", "res://scripts/props/hexapod.gd", "Hexapod"))
	for node in nodes:
		node.transform = Transform3D(Basis(Vector3.UP, -deg_to_rad(facing)), at)
	return nodes


## Boucle de circulation dans le rectangle de coins `a` et `c`, virages
## arrondis, parcourue dans le sens inverse des aiguilles d'une montre vu
## de dessus (nord, ouest, sud, est).
static func car_loop(a: Vector3, c: Vector3) -> PackedVector3Array:
	var x0 := minf(a.x, c.x)
	var x1 := maxf(a.x, c.x)
	var z0 := minf(a.z, c.z)
	var z1 := maxf(a.z, c.z)
	var corners: Array[Vector3] = [Vector3(x1, 0, z1), Vector3(x1, 0, z0), Vector3(x0, 0, z0), Vector3(x0, 0, z1)]
	var radius := minf(CAR_TURN, minf(x1 - x0, z1 - z0) * 0.5)
	var points := PackedVector3Array()
	for i in corners.size():
		var before := corners[i - 1]
		var corner := corners[i]
		var after := corners[(i + 1) % corners.size()]
		var p0 := corner + (before - corner).normalized() * radius
		var p2 := corner + (after - corner).normalized() * radius
		for k in 5:
			var t := k / 4.0
			points.append(p0 * (1 - t) * (1 - t) + corner * 2.0 * (1 - t) * t + p2 * t * t)
	return points


## Cap (radians, rotation autour de Y) pour regarder de `a` vers `b`.
static func _yaw(a: Vector3, b: Vector3) -> float:
	return atan2(-(b.x - a.x), -(b.z - a.z))


static func _instance(path: String, base_name: String) -> Node3D:
	# Instance d'éditeur : seules les propriétés changées seront enregistrées.
	var node := (load(path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
	node.name = base_name
	return node


static func _scripted(type: String, script: String, base_name: String) -> Node3D:
	var node := ClassDB.instantiate(type) as Node3D
	node.set_script(load(script))
	node.name = base_name
	return node


## Cible des renforts : le dépôt de la carte (`depot`), sinon la première
## cible de sabotage ; null s'il n'y en a pas (à régler dans l'inspecteur).
static func _reinforcement_target(scene_root: Node) -> Node:
	var region := scene_root.get_node_or_null(^"NavigationRegion3D") if scene_root else null
	if region == null:
		return null
	var targets := region.get_children().filter(func(n: Node) -> bool: return n is SabotageTarget)
	for target: Node in targets:
		if target.get("objective_id") == &"depot":
			return target
	return targets[0] if not targets.is_empty() else null


## Disque de l'aire de poser (7 m de rayon), partagé comme les revêtements.
static func _pad_mesh(scene_root: Node) -> Mesh:
	if scene_root:
		for node in scene_root.find_children("*", "MeshInstance3D", true, false):
			var mesh := (node as MeshInstance3D).mesh
			if mesh and mesh.resource_name == "pad":
				return mesh
	var disc := CylinderMesh.new()
	disc.resource_name = "pad"
	disc.top_radius = 7.0
	disc.bottom_radius = 7.0
	disc.height = 0.04
	disc.radial_segments = 32
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 0.31, 0.3)
	material.roughness = 1.0
	disc.material = material
	return disc


static func _operator_count(scene_root: Node) -> int:
	var units := scene_root.get_node_or_null(^"Units") if scene_root else null
	if units == null:
		return 0
	return units.get_children().filter(func(n: Node) -> bool: return n.scene_file_path == COMMANDO_SCENE).size()


## Emprise du terrain (maillages de `NavigationRegion3D/Ground`, sinon la
## carte UFO:AI de fond une fois construite) ; AABB vide sans terrain.
static func ground_bounds(root: Node) -> AABB:
	var ground := root.get_node_or_null(^"NavigationRegion3D/Ground") if root else null
	var bounds := AABB()
	if ground == null:
		var maps := root.find_children("*", "UfoMapLevel", true, false) if root else []
		if not maps.is_empty() and maps[0].get("is_built"):
			bounds = maps[0].get("map_bounds")
		return bounds
	var found := false
	for item in ground.find_children("*", "VisualInstance3D", true, false):
		var box: AABB = (item as VisualInstance3D).global_transform * (item as VisualInstance3D).get_aabb()
		bounds = box if not found else bounds.merge(box)
		found = true
	return bounds


## Chemin de ronde par les points `route` sous `PatrolPaths`, au premier
## nom libre (le garde ou le pick-up le désigne par ce nom).
static func _patrol_path(scene_root: Node, route: PackedVector3Array) -> Path3D:
	var path := Path3D.new()
	var holder := scene_root.get_node_or_null(^"PatrolPaths") if scene_root else null
	var index := 1
	while holder and holder.has_node(NodePath("Route%d" % index)):
		index += 1
	path.name = "Route%d" % index
	var curve := Curve3D.new()
	for point in route:
		curve.add_point(point)
	path.curve = curve
	path.set_meta(PARENT_META, "PatrolPaths")
	return path


static func _lamp() -> Node3D:
	var lamp := Node3D.new()
	lamp.name = "Lamp"
	var post := MeshInstance3D.new()
	post.name = "Post"
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.06
	cylinder.bottom_radius = 0.09
	cylinder.height = 4.0
	cylinder.radial_segments = 8
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.22, 0.23, 0.24)
	steel.metallic = 0.6
	steel.roughness = 0.5
	cylinder.material = steel
	post.mesh = cylinder
	post.position.y = 2.0
	lamp.add_child(post)
	var bulb := MeshInstance3D.new()
	bulb.name = "Bulb"
	var sphere := SphereMesh.new()
	sphere.radius = 0.18
	sphere.height = 0.36
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1, 0.85, 0.55)
	glow.emission_enabled = true
	glow.emission = Color(1, 0.8, 0.5)
	glow.emission_energy_multiplier = 3.0
	sphere.material = glow
	bulb.mesh = sphere
	bulb.position.y = 4.05
	lamp.add_child(bulb)
	var light := OmniLight3D.new()
	light.name = "Light"
	light.light_color = Color(1, 0.8, 0.52)
	light.light_energy = 2.2
	light.omni_range = 9.0
	light.omni_attenuation = 1.4
	light.position.y = 3.9
	lamp.add_child(light)
	return lamp


## Bande de revêtement `kind` de `a` à `b`, prolongée d'une demi-largeur à
## chaque bout (les virages se recouvrent), comme `MapBuilder.track`.
static func _surface(kind: String, a: Vector3, b: Vector3, scene_root: Node) -> Node3D:
	var spec: Dictionary = SURFACES[kind]
	var width: float = spec["width"]
	var along := Vector3(b.x - a.x, 0.0, b.z - a.z)
	var length := maxf(along.length(), 0.1)
	var dir := along / length
	var start := a - dir * width * 0.5
	var stop := b + dir * width * 0.5
	var node := MeshInstance3D.new()
	node.name = {"road": "Road", "sidewalk": "Sidewalk", "track": "Track"}[kind]
	node.mesh = _surface_mesh(kind, scene_root)
	var side := Vector3(dir.z, 0.0, -dir.x) * width
	node.transform = Transform3D(Basis(side, Vector3.UP, stop - start), (start + stop) * 0.5 + Vector3.UP * float(spec["y"]))
	return node


## Maillage unité du revêtement `kind` : celui que la carte utilise déjà
## (même nom de ressource), sinon un nouveau.
static func _surface_mesh(kind: String, scene_root: Node) -> Mesh:
	var resource_name := "surface_" + kind
	if scene_root:
		for node in scene_root.find_children("*", "MeshInstance3D", true, false):
			var mesh := (node as MeshInstance3D).mesh
			if mesh and mesh.resource_name == resource_name:
				return mesh
	var box := BoxMesh.new()
	box.resource_name = resource_name
	box.size = Vector3(1, 0.02, 1)
	var material := StandardMaterial3D.new()
	material.albedo_color = SURFACES[kind]["color"]
	material.roughness = 1.0
	box.material = material
	return box
