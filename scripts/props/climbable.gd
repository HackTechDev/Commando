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
## Caisse lourde (cerclée de fer) : il faut être deux pour la pousser, la
## tirer ou la faire pivoter.
@export var heavy: bool = false
## Faux si l'on ne peut y monter que depuis un objet voisin (trop haut pour
## grimper depuis le sol). On peut toujours en sauter, faute d'autre chemin.
@export var climbable_from_ground: bool = true

## Unité actuellement dessus (ou en train d'y monter).
var occupant: Commando
## Unité qui la pousse ou la tire (la première, qui mène le mouvement).
var handler: Commando
## Toutes les unités qui la tiennent (deux au plus, pour une caisse lourde).
var handlers: Array[Commando] = []
## Détruite par une explosion (invisible, sans collision).
var is_broken: bool = false
var _layer_before_break: int = 0
## Dégâts de balles encaissés (tir libre), jusqu'à `toughness()`.
var damage_taken: float = 0.0

## Souffle d'une explosion : en deçà de cette part du rayon, l'objet est
## détruit ; au-delà (jusqu'au rayon), il est projeté d'au plus `BLAST_PUSH` m.
const BLAST_DESTROY_RATIO := 0.45
const BLAST_PUSH := 2.5
const BLAST_SLIDE_TIME := 0.3
## Chute d'un rebord : au-delà de ce vide sous son centre, la caisse tombe.
## Hauteur de chute à partir de laquelle elle tue l'ennemi qu'elle écrase
## (en deçà, il est assommé) ; dégâts à un opérateur écrasé ; portée du
## fracas.
const FALL_MIN := 0.3
const CRUSH_KILL_HEIGHT := 1.5
const CRUSH_OPERATOR_DAMAGE := 60.0
const FALL_NOISE_RADIUS := 16.0
const MASK_SUPPORT := 0b11

## En train de tomber d'un rebord.
var falling: bool = false


func _enter_tree() -> void:
	if movable:
		add_to_group(QuickSave.GROUP)


func _ready() -> void:
	if heavy:
		_add_straps()
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


## Caisse lourde : deux cerclages de fer, bien visibles.
func _add_straps() -> void:
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.16, 0.17, 0.18)
	iron.metallic = 0.7
	iron.roughness = 0.45
	for offset in [-0.3, 0.3]:
		for vertical in [false, true]:
			var band := MeshInstance3D.new()
			var box := BoxMesh.new()
			var size := half_extent * 2.0 + 0.03
			box.size = Vector3(0.09, top_height + 0.03, size) if vertical else Vector3(size, 0.09, size)
			band.mesh = box
			band.material_override = iron
			band.position = Vector3(offset * half_extent * 2.0, top_height * 0.5, 0) if vertical else Vector3(0, top_height * (0.5 + offset * 0.8), 0)
			band.name = "Strap"
			add_child(band)


## Vrai si `unit` peut la saisir : libre, déjà tenue par lui, ou caisse
## lourde tenue par un seul.
func can_take(unit: Commando) -> bool:
	return handlers.is_empty() or unit in handlers or (heavy and handlers.size() < 2)


## Assez de bras pour la déplacer.
func can_move() -> bool:
	return not heavy or handlers.size() >= 2


func add_handler(unit: Commando) -> void:
	if not unit in handlers:
		handlers.append(unit)
	handler = handlers[0]


func remove_handler(unit: Commando) -> void:
	handlers.erase(unit)
	handler = handlers[0] if not handlers.is_empty() else null


## Côtés déjà tenus (directions dans le monde).
func taken_sides(except: Commando = null) -> Array[Vector3]:
	var sides: Array[Vector3] = []
	for unit in handlers:
		if unit == except or not is_instance_valid(unit):
			continue
		var order: Variant = unit._order
		if order is CrateHoldOrder or order is CrateApproachOrder:
			sides.append(order.side)
	return sides


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


## Vrai si `point` (dans le monde) est sous l'objet : dans son emprise au
## sol, entre sa base et son dessus.
func covers(point: Vector3) -> bool:
	if is_broken or point.y < global_position.y - 0.3 or point.y > global_position.y + top_height:
		return false
	var local := global_transform.affine_inverse() * point
	return absf(local.x) <= half_extent and absf(local.z) <= half_extent


## Caisse posée sur `point` (un corps glissé dessous, un ennemi coincé), ou
## null.
static func covering(tree: SceneTree, point: Vector3) -> Climbable:
	for node in tree.get_nodes_in_group(&"climbables"):
		var crate := node as Climbable
		if crate and crate.movable and crate.covers(point):
			return crate
	return null


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


## Côté praticable, libre (pas déjà tenu, `taken_sides`), le plus proche de
## `near` ; `Vector3.ZERO` s'il n'y en a aucun.
func get_free_side_toward(near: Vector3, unit: Commando) -> Vector3:
	var taken := taken_sides(unit)
	if taken.is_empty():
		return get_side_toward(near)
	var best := Vector3.ZERO
	var best_distance := INF
	for local_side in SIDES:
		var side := _world_side(local_side)
		if taken.any(func(other: Vector3) -> bool: return other.dot(side) > 0.9):
			continue
		var access := get_access_point(side)
		if not _is_reachable(access):
			continue
		var distance := Vector2(access.x - near.x, access.z - near.z).length()
		if distance < best_distance:
			best_distance = distance
			best = side
	return best


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
## (hormis celles de `exclude`). Un ennemi assommé, au sol, ne l'arrête pas :
## elle passe par-dessus et le coince (`covering`).
## `basis` : orientation à essayer (la sienne par défaut).
func is_free_at(at: Vector3, exclude: Array[RID], basis: Variant = null) -> bool:
	var shape := BoxShape3D.new()
	shape.size = Vector3(half_extent * 2.0 - 0.01, top_height - 0.04, half_extent * 2.0 - 0.01)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(basis as Basis if basis != null else global_basis, at + Vector3.UP * (top_height * 0.5 + 0.02))
	query.collision_mask = MASK_BLOCKERS
	var excluded: Array[RID] = [get_rid()]
	excluded.append_array(exclude)
	query.exclude = excluded
	for hit in get_world_3d().direct_space_state.intersect_shape(query, 8):
		var body := hit["collider"] as Enemy
		if body == null or not body.is_stunned():
			return false
	return true


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
	tween.tween_callback(check_support)
	return true


## Hauteur du premier appui (sol, mur, autre caisse) sous le centre de
## l'objet ; sa propre base s'il n'y a rien dessous.
func support_height() -> float:
	var from := global_position + Vector3.UP * 0.05
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 40.0, MASK_SUPPORT)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return (hit["position"] as Vector3).y if not hit.is_empty() else global_position.y


## Poussée au-delà d'un rebord (centre dans le vide) : elle tombe, écrase ce
## qui est dessous (`_land`). Renvoie vrai si elle tombe. Un objet occupé ne
## tombe pas.
func check_support() -> bool:
	if not movable or is_broken or falling or occupant != null:
		return false
	var below := support_height()
	var drop := global_position.y - below
	if drop < FALL_MIN:
		return false
	falling = true
	if handler:
		handler.release_crate()
	var tween := create_tween()
	tween.tween_property(self, "global_position:y", below, sqrt(2.0 * drop / 9.8)).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(_land.bind(drop))
	return true


## Les objets restés en l'air (posés sur une caisse déplacée ou détruite)
## tombent.
static func settle_all(tree: SceneTree) -> void:
	for node in tree.get_nodes_in_group(&"climbables"):
		var crate := node as Climbable
		if crate and crate.movable and crate.handler == null:
			crate.check_support()


## Fin de chute de `drop` m : fracas, ennemis écrasés dessous (tués de
## haut, assommés sinon), opérateurs blessés.
func _land(drop: float) -> void:
	falling = false
	Sfx.play_at(&"fall", global_position + Vector3.UP * 0.4, 2.0)
	EventBus.noise_emitted.emit(global_position, FALL_NOISE_RADIUS, &"crate")
	for node in get_tree().get_nodes_in_group(Enemy.ALL_GROUP):
		var enemy := node as Enemy
		if enemy and not enemy.is_dead and _under(enemy.global_position):
			if drop >= CRUSH_KILL_HEIGHT:
				enemy.health.take_damage(enemy.health.health + 1.0)
			elif not enemy.is_stunned():
				enemy.knock_out()
	for node in get_tree().get_nodes_in_group(&"commandos"):
		var unit := node as Commando
		if unit and not unit.is_dead and _under(unit.global_position):
			unit.health.take_damage(CRUSH_OPERATOR_DAMAGE)
	EventBus.navigation_obstacle_moved.emit()
	# Sur un autre rebord ? Elle continue. Ce qui était posé dessus suit.
	check_support()
	settle_all.call_deferred(get_tree())


## Vrai si une unité aux pieds `at` (rayon d'environ 0,35 m) est sous
## l'emprise de l'objet posé.
func _under(at: Vector3) -> bool:
	if absf(at.y - global_position.y) > 0.6:
		return false
	var local := global_transform.affine_inverse() * at
	return absf(local.x) <= half_extent + 0.35 and absf(local.z) <= half_extent + 0.35


## Points de résistance aux balles : une caisse tient plus qu'un bidon.
func toughness() -> float:
	return 220.0 if can_stand_on else 110.0


## Balle qui frappe l'objet (tir libre) : détruit une fois `toughness()`
## atteint. Un objet fixe (corniche) ou occupé n'est pas touché.
func take_shot(damage: float, at: Vector3, from: Vector3) -> void:
	if not movable or is_broken or occupant != null or handler != null:
		return
	damage_taken += damage
	if damage_taken >= toughness():
		var box := AABB(global_position - Vector3(half_extent, 0.0, half_extent), Vector3(half_extent * 2.0, top_height, half_extent * 2.0))
		Debris.burst(get_parent(), box, from, _color(), 12)
		Sfx.play_at(&"fall", global_position + Vector3.UP * 0.5, -2.0)
		_set_broken(true)


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
	if broken and is_inside_tree():
		settle_all.call_deferred(get_tree())


## Sauvegarde rapide (`QuickSave`) : place et orientation (caisses
## déplacées), objet détruit.
func save_state() -> Dictionary:
	return {"transform": global_transform, "broken": is_broken, "damage": damage_taken}


func load_state(data: Dictionary) -> void:
	_set_broken(data.get("broken", false))
	damage_taken = data.get("damage", 0.0)
	var saved: Transform3D = data.get("transform", global_transform)
	if saved.is_equal_approx(global_transform):
		return
	global_transform = saved
	EventBus.navigation_obstacle_moved.emit()
