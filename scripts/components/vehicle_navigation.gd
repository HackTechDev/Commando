class_name VehicleNavigation
extends Node
## Chemins des véhicules (Sabre, hexapode, pick-up armé). Le maillage de
## navigation de la carte est fait pour un homme (rayon 0,5 m) : il frôle
## les murs et passe entre des obstacles où un véhicule ne tient pas. Chaque
## véhicule a donc sa propre carte de navigation, générée depuis la même
## géométrie avec un rayon à sa taille (`radius`), et sans son propre corps
## (il ne bloque pas son départ). Le serveur de navigation ne prend une
## carte qu'à sa synchronisation (image de physique suivante) : chaque
## véhicule prépare donc la sienne au chargement (`prepare`), et toutes sont
## régénérées, une fois par image au plus, après un changement du décor
## (caisse déplacée, véhicule garé : `EventBus.navigation_obstacle_moved`).
## Une carte sans véhicule ne paie rien.
##
## Un seul nœud par niveau, créé à la première demande à côté de la région
## de navigation de la carte.

const NODE_NAME := "VehicleNavigation"

var _region: NavigationRegion3D
## Par véhicule (id d'instance) : {map, region, mesh, radius, dirty}.
var _maps: Dictionary = {}
var _rebake_queued: bool = false


## Chemin de `from` à `to` pour `vehicle`, de rayon `radius` (vide s'il n'y
## en a pas). Les deux bouts sont ramenés au plus près sur la carte du
## véhicule.
## Carte pas encore prête : chemin du maillage des fantassins, cette fois.
static func path(vehicle: Node3D, from: Vector3, to: Vector3, radius: float) -> PackedVector3Array:
	var navigation := of(vehicle)
	if navigation and navigation._ready_map(vehicle, radius).is_valid():
		var map := navigation._ready_map(vehicle, radius)
		var start := NavigationServer3D.map_get_closest_point(map, from)
		var end := NavigationServer3D.map_get_closest_point(map, to)
		return NavigationServer3D.map_get_path(map, start, end, true)
	var world := vehicle.get_world_3d().navigation_map
	return NavigationServer3D.map_get_path(world, NavigationServer3D.map_get_closest_point(world, from), to, true)


## Prépare la carte de `vehicle` (rayon `radius`), dès que le niveau est
## prêt : elle servira à partir de l'image de physique suivante.
static func prepare(vehicle: Node3D, radius: float) -> void:
	var tree := vehicle.get_tree()
	await tree.process_frame
	while is_instance_valid(vehicle) and vehicle.is_inside_tree():
		var level := _level_of(vehicle) as LevelRoot
		if level == null or level.is_level_ready:
			break
		await tree.process_frame
	if not is_instance_valid(vehicle) or not vehicle.is_inside_tree():
		return
	var navigation := of(vehicle)
	if navigation:
		navigation._map_for(vehicle, radius)


static func _level_of(node: Node) -> Node:
	var level := node.get_parent()
	while level and not level is LevelRoot:
		level = level.get_parent()
	return level if level else node.get_tree().current_scene


## Le nœud du niveau de `node` (créé au besoin), ou null hors d'un niveau
## qui a une région de navigation.
static func of(node: Node) -> VehicleNavigation:
	var level := _level_of(node)
	if level == null or not level.is_node_ready():
		return null
	var existing := level.get_node_or_null(NODE_NAME) as VehicleNavigation
	if existing:
		return existing
	var regions := level.find_children("*", "NavigationRegion3D", true, false)
	if regions.is_empty() or (regions[0] as NavigationRegion3D).navigation_mesh == null:
		return null
	var created := VehicleNavigation.new()
	created.name = NODE_NAME
	created._region = regions[0]
	level.add_child(created)
	return created


func _ready() -> void:
	EventBus.navigation_obstacle_moved.connect(_on_obstacle_moved)


func _exit_tree() -> void:
	for entry: Dictionary in _maps.values():
		NavigationServer3D.free_rid(entry["region"])
		NavigationServer3D.free_rid(entry["map"])
	_maps.clear()


func _on_obstacle_moved() -> void:
	for entry: Dictionary in _maps.values():
		entry["dirty"] = true
	if not _rebake_queued:
		_rebake_queued = true
		_rebake_all.call_deferred()


## Régénère toutes les cartes marquées (une fois pour plusieurs changements
## dans la même image).
func _rebake_all() -> void:
	_rebake_queued = false
	for key: int in _maps.keys():
		var vehicle := instance_from_id(key) as Node3D
		if vehicle and vehicle.is_inside_tree():
			_map_for(vehicle, _maps[key]["radius"])


## Carte du véhicule déjà synchronisée (RID vide sinon) ; la crée ou la
## régénère au besoin pour les demandes suivantes.
func _ready_map(vehicle: Node3D, radius: float) -> RID:
	var entry: Dictionary = _maps.get(vehicle.get_instance_id(), {})
	var map: RID = _map_for(vehicle, radius)
	if entry.is_empty() or Engine.get_physics_frames() <= int(_maps[vehicle.get_instance_id()]["created"]):
		return RID()
	return map


## Carte du véhicule, régénérée si le décor a changé depuis.
func _map_for(vehicle: Node3D, radius: float) -> RID:
	var key := vehicle.get_instance_id()
	var entry: Dictionary = _maps.get(key, {})
	if entry.is_empty():
		var map := NavigationServer3D.map_create()
		var source := _region.navigation_mesh
		NavigationServer3D.map_set_cell_size(map, source.cell_size)
		NavigationServer3D.map_set_cell_height(map, source.cell_height)
		NavigationServer3D.map_set_up(map, Vector3.UP)
		NavigationServer3D.map_set_use_async_iterations(map, false)
		NavigationServer3D.map_set_active(map, true)
		var region := NavigationServer3D.region_create()
		NavigationServer3D.region_set_map(region, map)
		NavigationServer3D.region_set_transform(region, _region.global_transform)
		entry = {"map": map, "region": region, "radius": radius, "dirty": true, "created": Engine.get_physics_frames()}
		_maps[key] = entry
		vehicle.tree_exited.connect(_forget.bind(key), CONNECT_ONE_SHOT)
	if entry["dirty"] or not is_equal_approx(entry["radius"], radius):
		entry["radius"] = radius
		entry["dirty"] = false
		NavigationServer3D.region_set_navigation_mesh(entry["region"], _bake(vehicle, radius))
		NavigationServer3D.map_force_update(entry["map"])
	return entry["map"]


func _forget(key: int) -> void:
	var entry: Dictionary = _maps.get(key, {})
	if entry.is_empty():
		return
	NavigationServer3D.free_rid(entry["region"])
	NavigationServer3D.free_rid(entry["map"])
	_maps.erase(key)


## Maillage de la carte pour un véhicule de rayon `radius`, sans le corps du
## véhicule lui-même (sa couche est retirée le temps de lire la géométrie).
func _bake(vehicle: Node3D, radius: float) -> NavigationMesh:
	var mesh := _region.navigation_mesh.duplicate() as NavigationMesh
	mesh.agent_radius = radius
	var source := NavigationMeshSourceGeometryData3D.new()
	var body := vehicle as CollisionObject3D
	var layer := body.collision_layer if body else 0
	if body:
		body.collision_layer = 0
	NavigationServer3D.parse_source_geometry_data(mesh, source, _region)
	if body:
		body.collision_layer = layer
	NavigationServer3D.bake_from_source_geometry_data(mesh, source)
	return mesh
