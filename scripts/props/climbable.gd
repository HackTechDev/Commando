class_name Climbable
extends StaticBody3D
## Obstacle bas sur lequel un opérateur peut grimper (caisse…).
## Une seule unité à la fois peut s'y tenir.

## Écart et dénivelé maximaux pour passer directement d'un objet à son voisin.
const MAX_GAP := 0.35
const MAX_STEP_HEIGHT := 0.3

## Hauteur du dessus par rapport à l'origine de l'objet.
@export var top_height: float = 1.2
## Demi-largeur de l'objet (carré au sol).
@export var half_extent: float = 0.6
## Distance entre le bord de l'objet et le point d'où l'on grimpe.
@export var access_margin: float = 0.55

## Unité actuellement dessus (ou en train d'y monter).
var occupant: Commando


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
	var map := get_world_3d().navigation_map
	var reach := half_extent + access_margin
	for direction: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		var point := global_position + global_basis * direction * reach
		var closest := NavigationServer3D.map_get_closest_point(map, point)
		if Vector2(closest.x - point.x, closest.z - point.z).length() < 0.35:
			points.append(point)
	return points


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
