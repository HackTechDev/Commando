class_name Climbable
extends StaticBody3D
## Obstacle sur lequel un opérateur peut se tenir : caisse, ou case du dessus
## d'un mur (corniche, accessible seulement depuis un obstacle voisin).
## Une seule unité à la fois peut s'y tenir. Sert aussi aux objets qu'on
## déplace sans monter dessus (bidons : `can_stand_on` faux).

## Écart et dénivelé maximaux pour passer directement d'un objet à son voisin.
const MAX_GAP := 0.35
const MAX_STEP_HEIGHT := 0.3
## Dénivelé maximal pour grimper (ou redescendre) d'un objet à son voisin.
const MAX_CLIMB_HEIGHT := 1.3
## Écart de hauteur toléré pour reconnaître le dessus d'un objet visé.
const TOP_TOLERANCE := 0.15
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
## Texture remplaçant celle de la scène (variante de caisse), en chemin
## relatif au dossier de textures externe (`TextureLibrary`), ou vide.
@export var skin: String = ""
## Faux si l'on ne peut pas monter dessus (bidon : on le pousse, on le tire).
@export var can_stand_on: bool = true
## Faux pour un objet fixe (corniche) : ni poussé ni tiré.
@export var movable: bool = true
## Faux si l'on ne peut y monter que depuis un objet voisin (trop haut pour
## grimper depuis le sol). On peut toujours en sauter, faute d'autre chemin.
@export var climbable_from_ground: bool = true

## Unité actuellement dessus (ou en train d'y monter).
var occupant: Commando
## Unité qui la pousse ou la tire.
var handler: Commando
## Détruite par une explosion (invisible, sans collision).
var is_broken: bool = false
var _layer_before_break: int = 0

## Souffle d'une explosion : en deçà de cette part du rayon, l'objet est
## détruit ; au-delà (jusqu'au rayon), il est projeté d'au plus `BLAST_PUSH` m.
const BLAST_DESTROY_RATIO := 0.45
const BLAST_PUSH := 2.5
const BLAST_SLIDE_TIME := 0.3


func _enter_tree() -> void:
	if movable:
		add_to_group(QuickSave.GROUP)


func _ready() -> void:
	if skin.is_empty():
		return
	# Même matériau, autre texture : copie propre à cette caisse, que le
	# niveau texturera à son chargement.
	for child in get_children():
		var mesh := child as MeshInstance3D
		if mesh == null:
			continue
		var material := mesh.get_active_material(0) as StandardMaterial3D
		if material:
			material = material.duplicate() as StandardMaterial3D
			material.set_meta(&"albedo_source", skin)
			mesh.material_override = material


## Position des pieds d'une unité debout sur l'objet.
func get_top_position() -> Vector3:
	return global_position + Vector3.UP * top_height


## Vrai si `other` touche cet objet par un côté et que leurs dessus sont à
## peu près à la même hauteur : on peut alors passer de l'un à l'autre à pied.
func is_adjacent_to(other: Climbable) -> bool:
	if other == null or other == self or not can_stand_on or not other.can_stand_on:
		return false
	var top := get_top_position()
	var other_top := other.get_top_position()
	if absf(top.y - other_top.y) > MAX_STEP_HEIGHT:
		return false
	var distance := Vector2(top.x - other_top.x, top.z - other_top.z).length()
	return distance <= half_extent + other.half_extent + MAX_GAP


## Vrai si l'on peut passer de cet objet à `other` sans toucher le sol : à
## pied s'ils sont voisins (`is_adjacent_to`), sinon en grimpant ou en
## redescendant, s'ils se touchent par un côté et que le dénivelé le permet.
func can_reach(other: Climbable) -> bool:
	if other == null or other == self or not can_stand_on or not other.can_stand_on:
		return false
	var top := get_top_position()
	var other_top := other.get_top_position()
	if absf(top.y - other_top.y) > MAX_CLIMB_HEIGHT:
		return false
	var distance := Vector2(top.x - other_top.x, top.z - other_top.z).length()
	return distance <= half_extent + other.half_extent + MAX_GAP


## Vrai si `point` (dans le monde) est sur le dessus de l'objet.
func has_top_point(point: Vector3) -> bool:
	if absf(point.y - get_top_position().y) > TOP_TOLERANCE:
		return false
	var local := global_transform.affine_inverse() * point
	return absf(local.x) <= half_extent and absf(local.z) <= half_extent


## Objet du groupe `climbables` dont le dessus contient `point`, ou null.
static func find_at(tree: SceneTree, point: Vector3) -> Climbable:
	for node in tree.get_nodes_in_group(&"climbables"):
		var climbable := node as Climbable
		if climbable and climbable.can_stand_on and climbable.has_top_point(point):
			return climbable
	return null


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


## Souffle d'une explosion de rayon `radius` au point `from` : l'objet
## (caisse, bidon) est détruit tout près, projeté plus loin, jusqu'au premier
## obstacle. Un objet tenu ou occupé ne bouge pas. Renvoie vrai s'il a été
## touché.
func blast(from: Vector3, radius: float) -> bool:
	if not movable or is_broken or occupant != null or handler != null:
		return false
	var away := global_position - from
	away.y = 0.0
	var distance := away.length()
	if distance > radius:
		return false
	if distance < radius * BLAST_DESTROY_RATIO:
		var box := AABB(global_position - Vector3(half_extent, 0.0, half_extent), Vector3(half_extent * 2.0, top_height, half_extent * 2.0))
		Debris.burst(get_parent(), box, from, _color(), 16)
		Sfx.play_at(&"fall", global_position + Vector3.UP * 0.5, 0.0)
		_set_broken(true)
		return true
	var direction := away.normalized() if distance > 0.01 else Vector3.FORWARD
	var push := BLAST_PUSH * (1.0 - distance / radius)
	var goal := global_position
	var step := 0.1
	var travelled := step
	while travelled <= push:
		var next := global_position + direction * travelled
		if not is_free_at(next, []):
			break
		goal = next
		travelled += step
	if goal.distance_to(global_position) < 0.05:
		return true
	var tween := create_tween()
	tween.tween_property(self, "global_position", goal, BLAST_SLIDE_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(EventBus.navigation_obstacle_moved.emit)
	return true


## Couleur des éclats : bois d'une caisse, tôle d'un bidon.
func _color() -> Color:
	return Color(0.45, 0.33, 0.2) if can_stand_on else Color(0.32, 0.36, 0.3)


func _set_broken(broken: bool) -> void:
	if broken == is_broken:
		return
	is_broken = broken
	# Hors des couches lues par la navigation (une forme désactivée y compte).
	if broken:
		_layer_before_break = collision_layer
		collision_layer = 0
	else:
		collision_layer = _layer_before_break
	for child in get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).set_deferred(&"disabled", broken)
		elif child is VisualInstance3D:
			(child as VisualInstance3D).visible = not broken
	if broken:
		remove_from_group(&"climbables")
	else:
		add_to_group(&"climbables")
	EventBus.navigation_obstacle_moved.emit()


## Sauvegarde rapide (`QuickSave`) : place et orientation (caisses
## déplacées), objet détruit.
func save_state() -> Dictionary:
	return {"transform": global_transform, "broken": is_broken}


func load_state(data: Dictionary) -> void:
	_set_broken(data.get("broken", false))
	var saved: Transform3D = data.get("transform", global_transform)
	if saved.is_equal_approx(global_transform):
		return
	global_transform = saved
	EventBus.navigation_obstacle_moved.emit()
