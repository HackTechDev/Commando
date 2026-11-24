class_name VehicleClearance
extends RefCounted
## Collisions des véhicules qui avancent par déplacement direct (Sabre,
## hexapode, pick-up armé) : avant chaque pas, l'emprise du véhicule (une
## boîte dans son repère) est essayée à sa future place contre la couche
## des obstacles (murs, bâtiments, immeubles, murets, caisses, poteaux,
## autres véhicules, convertible). Une mine repérée (obstacle de
## navigation) ne compte pas : le véhicule la traite à part.
##
## `step` choisit le pas : le cap voulu d'abord ; contre un obstacle, il
## braque plus fort d'un côté ou de l'autre pour le longer (le côté le plus
## proche du cap voulu) ; il peut aussi glisser de côté (un marcheur, en
## crabe, franchement) ; sinon il tourne seulement, ou reste sur place
## (bloqué).
## Un corps que le véhicule touche déjà au départ (sortie de la soute du
## convertible, véhicule posé contre un mur) est ignoré, pour qu'il puisse
## s'en dégager.

const MASK := 0b10
const MAX_RESULTS := 16


## Vrai si la boîte `box` (repère du véhicule) placée en `frame` touche un
## obstacle autre que ceux de `exclude`.
static func hits(vehicle: Node3D, frame: Transform3D, box: AABB, exclude: Array[RID]) -> bool:
	return not touching(vehicle, frame, box, exclude).is_empty()


## Obstacles (RID) que touche la boîte `box` placée en `frame`.
static func touching(vehicle: Node3D, frame: Transform3D, box: AABB, exclude: Array[RID]) -> Array[RID]:
	var shape := BoxShape3D.new()
	shape.size = box.size
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = frame * Transform3D(Basis(), box.get_center())
	query.collision_mask = MASK
	query.exclude = exclude
	query.margin = 0.0
	var found: Array[RID] = []
	for result in vehicle.get_world_3d().direct_space_state.intersect_shape(query, MAX_RESULTS):
		var collider := result.get("collider") as Node
		if collider and collider.get_parent() is Landmine:
			continue
		found.append(result["rid"])
	return found


## Pas suivant du véhicule : rotation voulue `turn` (rad, déjà bornée au
## braquage de l'image), avance `distance` (m) ; `max_turn` : braquage
## maximal de l'image, pour longer un obstacle ; `crab` : décalage latéral
## permis (rad, de la direction d'avance ; 0 : aucun). Renvoie la nouvelle
## transformation, ou `null` s'il ne peut ni avancer ni tourner.
static func step(vehicle: Node3D, box: AABB, exclude: Array[RID], turn: float, max_turn: float, distance: float, crab: float = 0.0) -> Variant:
	var start := vehicle.global_transform
	var ignored: Array[RID] = exclude.duplicate()
	ignored.append_array(touching(vehicle, start, box, exclude))
	var wanted_turn := turn
	var tries: Array[Array] = [[turn, 0.0]]
	if distance > 0.001:
		for steer: float in [max_turn, -max_turn]:
			if not is_equal_approx(steer, turn):
				tries.append([steer, 0.0])
		if crab > 0.0:
			for share: float in [0.5, 1.0]:
				tries.append([turn, crab * share])
				tries.append([turn, -crab * share])
	tries.sort_custom(func(a: Array, b: Array) -> bool:
		return absf(a[0] - wanted_turn) + absf(a[1]) < absf(b[0] - wanted_turn) + absf(b[1]))
	for attempt in tries:
		var frame := _moved(start, attempt[0], distance, attempt[1])
		if not hits(vehicle, frame, box, ignored):
			return frame
	# Pas de place pour avancer : il tourne sur place, s'il le peut.
	var turned := _moved(start, turn, 0.0, 0.0)
	if absf(turn) > 0.0001 and not hits(vehicle, turned, box, ignored):
		return turned
	return null


static func _moved(start: Transform3D, turn: float, distance: float, sideways: float) -> Transform3D:
	var basis := start.basis.rotated(Vector3.UP, turn)
	var forward := -basis.z
	var side := basis.x
	var direction := (forward * cos(sideways) + side * sin(sideways)).normalized()
	return Transform3D(basis, start.origin + direction * distance * (cos(sideways) if sideways != 0.0 else 1.0))
