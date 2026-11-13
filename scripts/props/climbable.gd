class_name Climbable
extends StaticBody3D
## Obstacle bas sur lequel un opérateur peut grimper (caisse…).
## Une seule unité à la fois peut s'y tenir.

## Écart et dénivelé maximaux pour passer directement d'un objet à son voisin.
const MAX_GAP := 0.35
const MAX_STEP_HEIGHT := 0.3
## Ce qui arrête une caisse qu'on déplace : murs et autres caisses,
## opérateurs, ennemis debout ou assommés (pas le sol).
const MASK_BLOCKERS := 0b11110
const SIDES: Array[Vector3] = [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]

## Hauteur du dessus par rapport à l'origine de l'objet.
@export var top_height: float = 1.2
## Demi-largeur de l'objet (carré au sol).
@export var half_extent: float = 0.6
## Distance entre le bord de l'objet et le point d'où l'on grimpe.
@export var access_margin: float = 0.55
## Texture remplaçant celle de la scène (variante de caisse), ou rien.
@export var skin: Texture2D

## Unité actuellement dessus (ou en train d'y monter).
var occupant: Commando
## Unité qui la pousse ou la tire.
var handler: Commando


func _ready() -> void:
	if skin == null:
		return
	# Même matériau, autre texture : copie propre à cette caisse.
	for child in get_children():
		var mesh := child as MeshInstance3D
		if mesh == null:
			continue
		var material := mesh.get_active_material(0) as StandardMaterial3D
		if material:
			material = material.duplicate() as StandardMaterial3D
			material.albedo_texture = skin
			mesh.material_override = material


## Position des pieds d'une unité debout sur l'objet.
func get_top_position() -> Vector3:
	return global_position + Vector3.UP * top_height


## Vrai si `other` touche cet objet par un côté et que leurs dessus sont à
## peu près à la même hauteur : on peut alors passer de l'un à l'autre à pied.
func is_adjacent_to(other: Climbable) -> bool:
	if other == null or other == self:
		return false
	var top := get_top_position()
	var other_top := other.get_top_position()
	if absf(top.y - other_top.y) > MAX_STEP_HEIGHT:
		return false
	var distance := Vector2(top.x - other_top.x, top.z - other_top.z).length()
	return distance <= half_extent + other.half_extent + MAX_GAP


## Points au sol, un par côté, d'où l'on peut grimper ou redescendre.
## Seuls les points praticables (sur le maillage de navigation) sont renvoyés.
func get_access_points() -> Array[Vector3]:
	var points: Array[Vector3] = []
	for direction in SIDES:
		var point := get_access_point(_world_side(direction))
		if _is_reachable(point):
			points.append(point)
	return points


## Point au sol face au côté `side` (direction unitaire dans le monde).
func get_access_point(side: Vector3) -> Vector3:
	return global_position + side * (half_extent + access_margin)


## Côté praticable (direction unitaire dans le monde, du centre vers
## l'extérieur) le plus proche de `near` ; `Vector3.ZERO` s'il n'y en a aucun.
func get_side_toward(near: Vector3) -> Vector3:
	var best := Vector3.ZERO
	var best_distance := INF
	for direction in SIDES:
		var side := _world_side(direction)
		var point := get_access_point(side)
		if not _is_reachable(point):
			continue
		var distance := Vector2(point.x - near.x, point.z - near.z).length_squared()
		if distance < best_distance:
			best_distance = distance
			best = side
	return best


## Vrai si la caisse tiendrait à `at` sans heurter d'obstacle ni d'unité
## (hormis celles de `exclude`).
func is_free_at(at: Vector3, exclude: Array[RID]) -> bool:
	var shape := BoxShape3D.new()
	shape.size = Vector3(half_extent * 2.0 - 0.01, top_height - 0.04, half_extent * 2.0 - 0.01)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(global_basis, at + Vector3.UP * (top_height * 0.5 + 0.02))
	query.collision_mask = MASK_BLOCKERS
	var excluded: Array[RID] = [get_rid()]
	excluded.append_array(exclude)
	query.exclude = excluded
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _world_side(direction: Vector3) -> Vector3:
	var side := global_basis * direction
	side.y = 0.0
	return side.normalized()


func _is_reachable(point: Vector3) -> bool:
	var closest := NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, point)
	return Vector2(closest.x - point.x, closest.z - point.z).length() < 0.35


## Point d'accès praticable le plus proche de `near`. Renvoie `false` dans
## `found` (clé du dictionnaire) s'il n'y en a aucun.
func get_nearest_access(near: Vector3) -> Dictionary:
	var best := {"found": false, "point": Vector3.ZERO}
	var best_distance := INF
	for point in get_access_points():
		var distance := point.distance_squared_to(Vector3(near.x, point.y, near.z))
		if distance < best_distance:
			best_distance = distance
			best = {"found": true, "point": point}
	return best
