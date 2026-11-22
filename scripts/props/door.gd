@tool
class_name Door
extends StaticBody3D
## Porte pivotante dans l'ouverture d'un mur : fermée, elle arrête la marche,
## la vue et les balles ; ouverte, plus rien. Repère : l'ouverture suit X,
## centrée sur l'origine, le mur est épais selon Z ; la charnière est en
## x = -width / 2.
##
## Le seuil est toujours coupé dans le maillage de navigation (obstacle) : on
## le passe par un lien (`TraversalLink`, sorte `DOOR`) que les unités
## franchissent en ouvrant la porte au besoin (`LinkTraversal`). Verrouillée
## et fermée, la porte réserve ce lien aux ennemis (couche de navigation 2) :
## un opérateur doit la crocheter (`DoorOrder`) ou la faire sauter.

const GROUP := &"doors"
const LAYER_OCCLUDERS := 0b10
## Couche 8 (« Portes ») : seuls les clics la lisent ; une porte ouverte y
## reste pour qu'on puisse la refermer.
const DOOR_LAYER := 1 << 7
## Couches de navigation : 1 pour tout le monde, 2 pour les ennemis seuls.
const NAV_EVERYONE := 0b01
const NAV_ENEMIES := 0b10
## Angle d'ouverture (rad) et durée du pivot (s).
const OPEN_ANGLE := deg_to_rad(100.0)
const SWING_TIME := 0.35
## Distance des extrémités du lien au milieu du mur (rayon des agents compris).
const LINK_REACH := 0.95
## Hauteur jusqu'à laquelle le battant reste affiché quand le bâtiment est
## vu en coupe (`Building`).
const CUT_HEIGHT := 1.2
const COLOR := Color(0.36, 0.25, 0.16)
const LOCKED_COLOR := Color(0.32, 0.33, 0.36)

@export var width: float = 1.1
@export var height: float = 2.1
@export var thickness: float = 0.08
## Épaisseur du mur qui l'entoure (le seuil coupé dans la navigation).
@export var wall_thickness: float = 0.3
@export var locked: bool = false
@export var open: bool = false
## Points de résistance aux balles et aux coups : à zéro, la porte cède.
@export var toughness: float = 160.0

var is_open: bool = false
var is_locked: bool = false
var is_broken: bool = false
var damage_taken: float = 0.0
var link: TraversalLink

var _shape: CollisionShape3D
var _pivot: Node3D
var _lower: MeshInstance3D
var _upper: MeshInstance3D
var _tween: Tween
## Sens du pivot : +1 vers +Z, -1 vers -Z (à l'opposé de qui ouvre).
var _swing: float = 1.0


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group(GROUP)
	add_to_group(QuickSave.GROUP)


func _ready() -> void:
	if Engine.is_editor_hint():
		_build_panel()
		return
	collision_mask = 0
	_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, height, thickness)
	_shape.shape = box
	add_child(_shape)
	_build_panel()
	var obstacle := NavigationObstacle3D.new()
	obstacle.name = "Threshold"
	obstacle.avoidance_enabled = false
	obstacle.affect_navigation_mesh = true
	obstacle.height = height
	add_child(obstacle)
	# Contour dans le repère du monde : l'obstacle ne suit que la position.
	obstacle.top_level = true
	obstacle.global_transform = Transform3D(Basis.IDENTITY, global_position)
	var corners := PackedVector3Array()
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		corners.append(global_basis * Vector3(corner.x * width * 0.5, 0.0, corner.y * wall_thickness * 0.5))
	obstacle.vertices = corners
	link = TraversalLink.new()
	link.name = "Link"
	link.kind = TraversalLink.Kind.DOOR
	link.door = self
	var ends := link_ends()[0]
	link.start_position = ends[0]
	link.end_position = ends[1]
	add_child(link)
	is_locked = locked
	_set_open(open, false)


## Battant : un pivot à la charnière, deux moitiés (sous et au-dessus de la
## hauteur de coupe) et une poignée.
func _build_panel() -> void:
	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	_pivot.position = Vector3(-width * 0.5, 0.0, 0.0)
	add_child(_pivot)
	var material := StandardMaterial3D.new()
	material.albedo_color = LOCKED_COLOR if locked else COLOR
	material.roughness = 0.8
	material.metallic = 0.4 if locked else 0.0
	_lower = _panel_part(material, 0.0, minf(CUT_HEIGHT, height))
	_upper = _panel_part(material, CUT_HEIGHT, height)
	var knob := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.04
	sphere.height = 0.08
	knob.mesh = sphere
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.75, 0.62, 0.3)
	brass.metallic = 0.8
	knob.material_override = brass
	for side: float in [-1.0, 1.0]:
		var handle := knob.duplicate() as MeshInstance3D
		handle.position = Vector3(width - 0.12, 1.0, side * (thickness * 0.5 + 0.03))
		_pivot.add_child(handle)


func _panel_part(material: Material, bottom: float, top: float) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = Vector3(width - 0.02, maxf(top - bottom, 0.01), thickness)
	part.mesh = cube
	part.material_override = material
	part.position = Vector3(width * 0.5, (bottom + top) * 0.5, 0.0)
	_pivot.add_child(part)
	return part


## Vrai si la porte peut être ouverte par un opérateur sans crochetage.
func can_open() -> bool:
	return is_open or is_broken or not is_locked


## Ouvre la porte, battant poussé à l'opposé de `from` (qui ouvre). Une
## porte verrouillée s'ouvre aussi (ennemi qui a la clé, crochetage) : elle
## ne l'est plus.
func open_from(from: Vector3) -> void:
	if is_open or is_broken:
		return
	is_locked = false
	# Un angle positif rabat le battant vers -Z.
	_swing = 1.0 if to_local(from).z > 0.0 else -1.0
	_set_open(true, true)
	Sfx.play_at(&"clink", global_position + Vector3.UP, -6.0)


## Referme la porte. Renvoie faux si quelqu'un est dans le passage.
func close() -> bool:
	if not is_open or is_broken:
		return false
	if is_blocked():
		return false
	_set_open(false, true)
	Sfx.play_at(&"clink", global_position + Vector3.UP, -6.0)
	return true


## Ouvre ou ferme (selon l'état), depuis `from`. Renvoie faux si rien n'a
## changé (porte verrouillée, passage occupé, porte détruite).
func toggle_from(from: Vector3) -> bool:
	if is_broken:
		return false
	if is_open:
		return close()
	if is_locked:
		return false
	open_from(from)
	return true


## Vrai si une unité se tient dans le passage (la porte ne peut se fermer).
func is_blocked() -> bool:
	for group: StringName in [&"commandos", Enemy.ALL_GROUP, &"vips"]:
		for node in get_tree().get_nodes_in_group(group):
			var unit := node as Node3D
			if unit == null:
				continue
			var local := to_local(unit.global_position)
			if absf(local.x) < width * 0.5 + 0.3 and absf(local.z) < wall_thickness * 0.5 + 0.45 and absf(local.y) < 1.0:
				return true
	return false


## Côté du passage (extrémité du lien) le plus proche de `point`.
func near_side(point: Vector3) -> Vector3:
	var start := link.global_start()
	var end := link.global_end()
	return start if point.distance_squared_to(start) <= point.distance_squared_to(end) else end


## Bâtiment vu en coupe : la moitié haute du battant s'efface.
func set_cutaway(cut: bool) -> void:
	_upper.visible = not cut and not is_broken


## Une balle frappe la porte : elle encaisse, et cède à `toughness`.
func take_shot(damage: float, at: Vector3, from: Vector3) -> void:
	if is_broken:
		return
	damage_taken += damage
	if damage_taken >= toughness:
		break_apart(at + (at - from).normalized() * -0.5)


## Explosion de rayon `radius` en `at` : la porte proche vole en éclats.
func blast(at: Vector3, radius: float) -> void:
	if is_broken:
		return
	var local := to_local(at)
	var nearest := Vector3(clampf(local.x, -width * 0.5, width * 0.5), clampf(local.y, 0.0, height), 0.0)
	if local.distance_to(nearest) <= radius * 0.8:
		break_apart(at)


## La porte vole en éclats : le passage reste ouvert à tous.
func break_apart(from: Vector3) -> void:
	if is_broken:
		return
	var box := global_transform * AABB(Vector3(-width * 0.5, 0.0, -thickness * 0.5), Vector3(width, height, thickness))
	_set_broken(true)
	Debris.burst(get_parent(), box, from, COLOR, 16)
	Sfx.play_at(&"fall", global_position + Vector3.UP, 0.0)


## Sauvegarde rapide (`QuickSave`).
func save_state() -> Dictionary:
	return {"open": is_open, "locked": is_locked, "broken": is_broken, "damage": damage_taken, "swing": _swing}


func load_state(data: Dictionary) -> void:
	is_locked = data.get("locked", is_locked)
	damage_taken = data.get("damage", 0.0)
	_swing = data.get("swing", _swing)
	if data.get("broken", false):
		_set_broken(true)
	else:
		_set_open(data.get("open", is_open), false)


func _set_open(value: bool, animate: bool) -> void:
	is_open = value
	var angle := OPEN_ANGLE * _swing if value else 0.0
	if _tween:
		_tween.kill()
	if animate:
		_tween = create_tween()
		_tween.tween_property(_pivot, "rotation:y", angle, SWING_TIME).set_trans(Tween.TRANS_SINE)
	else:
		_pivot.rotation.y = angle
	# Ouverte : le battant ne bloque plus rien, mais reste cliquable (sa forme
	# suit le battant, rangé contre la charnière).
	collision_layer = DOOR_LAYER if value else LAYER_OCCLUDERS | DOOR_LAYER
	var hinge := Vector3(-width * 0.5, height * 0.5, 0.0)
	var panel := Transform3D(Basis(Vector3.UP, angle), hinge) * Transform3D(Basis.IDENTITY, Vector3(width * 0.5, 0.0, 0.0))
	_shape.transform = panel
	_update_link()
	EventBus.sight_blockers_changed.emit()


func _set_broken(broken: bool) -> void:
	is_broken = broken
	if not broken:
		return
	is_open = true
	is_locked = false
	_pivot.visible = false
	collision_layer = 0
	_shape.set_deferred(&"disabled", true)
	_update_link()
	EventBus.sight_blockers_changed.emit()


## Lien du seuil : à tous, sauf porte verrouillée et fermée (ennemis seuls).
func _update_link() -> void:
	if link:
		link.navigation_layers = NAV_ENEMIES if is_locked and not is_open and not is_broken else NAV_EVERYONE


## Extrémités, dans le repère du nœud, des passages (`TraversalLink`) que
## le jeu crée ici ; la vérification de l'éditeur de mission s'en sert aussi.
func link_ends() -> Array[PackedVector3Array]:
	return [PackedVector3Array([Vector3(0.0, 0.0, LINK_REACH), Vector3(0.0, 0.0, -LINK_REACH)])]
