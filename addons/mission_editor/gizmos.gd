@tool
extends EditorNode3DGizmoPlugin
## Repères de l'éditeur de mission dans la vue 3D :
## - cône de vue de chaque garde (`VisionConfig` : zones proche et
##   lointaine, réduite la nuit comme en jeu, `LevelRoot.NIGHT_SIGHT`) ;
## - trajets des passants et des boucles de voitures, avec une poignée par
##   point (déplacement aimanté à la grille, annulable) ;
## - portée des bruits : klaxon des voitures, moteur du Sabre ;
## - rondes des gardes, pick-ups et avions, dans la couleur du greffon :
##   chemin avec le sens de marche et le retour au premier point, trait
##   pointillé de l'unité à son premier point. Les chemins sont des `Path3D`,
##   que l'éditeur Godot sait modifier (poignées, ajout et retrait de
##   points) ; le repère suit en direct ;
## - limites de la caméra (`CameraRig.bounds`) : cadre au sol, une poignée
##   au milieu de chaque bord, aimantée à la grille et gardée sur le terrain.

const Palette := preload("res://addons/mission_editor/palette.gd")

const GRID_STEP := 0.5
## Hauteur des repères au-dessus du sol (m).
const LIFT := 0.06
## Couleur du greffon (tracés en cours de pose, rondes).
const PATROL_COLOR := Color(0.4, 1.0, 0.5)
## Pointillés du trait unité-chemin : longueur d'un tiret et d'un pas (m).
const DASH := 0.5
const DASH_STEP := 1.0
## Limites de la caméra : couleur, plus petit côté (m), distance (m) à
## laquelle un bord se colle à celui du terrain.
const BOUNDS_COLOR := Color(0.55, 0.75, 1.0)
const BOUNDS_MIN := 10.0
const BOUNDS_SNAP := 1.0
const BOUNDS_HANDLES: Array[String] = ["Bord ouest des limites de la caméra", "Bord est des limites de la caméra", "Bord nord des limites de la caméra", "Bord sud des limites de la caméra"]
## Largeur des bandes et taille des chevrons du sens de marche (m).
const BAND := 0.3
const CHEVRON := 1.2

## Greffon : historique d'annulation, grille.
var plugin: EditorPlugin


func _init() -> void:
	create_material("near", Color(1.0, 0.85, 0.2, 0.32))
	create_material("far", Color(1.0, 0.85, 0.2, 0.13))
	create_material("edge", Color(1.0, 0.8, 0.2))
	create_material("route", Color(0.35, 0.8, 1.0))
	create_material("noise", Color(1.0, 0.45, 0.3))
	create_material("patrol", Color(PATROL_COLOR, 0.85))
	create_material("patrol_back", Color(PATROL_COLOR, 0.4))
	create_material("bounds", Color(BOUNDS_COLOR, 0.8))
	create_handle_material("handles")


func _get_gizmo_name() -> String:
	return "Éditeur de mission"


func _has_gizmo(node: Node3D) -> bool:
	return node is Enemy or node is Passerby or node is TrafficCar or node is Sabre or node is Technical or node is EnemyAircraft or node is CameraRig


func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	var node := gizmo.get_node_3d()
	_draw_patrol(gizmo, node)
	if node is CameraRig:
		_draw_bounds(gizmo, node)
	elif node is Enemy:
		_draw_cone(gizmo, node)
	elif node is Passerby or node is TrafficCar:
		_draw_route(gizmo, node)
		if node is TrafficCar and node.get("points").size() > 0:
			_draw_circle(gizmo, node.get("points")[0] - node.position, TrafficCar.HORN_NOISE)
	elif node is Sabre:
		_draw_circle(gizmo, Vector3.ZERO, Sabre.ENGINE_NOISE)


# --- Cône de vue ------------------------------------------------------------

func _draw_cone(gizmo: EditorNode3DGizmo, enemy: Node3D) -> void:
	if enemy.get("blind"):
		return
	var vision := enemy.get_node_or_null(^"VisionComponent")
	var config := vision.get("config") as VisionConfig if vision else null
	if config == null:
		return
	var near := config.near_range
	var far := config.far_range
	var root := enemy.owner
	if root is LevelRoot and root.get("night"):
		far = maxf(near, far * LevelRoot.NIGHT_SIGHT)
	var half := deg_to_rad(config.fov_degrees) * 0.5
	var steps := 24
	var arc_near := PackedVector3Array()
	var arc_far := PackedVector3Array()
	for i in steps + 1:
		var angle := -half + 2.0 * half * i / steps
		var dir := Vector3(sin(angle), 0.0, -cos(angle))
		arc_near.append(dir * near + Vector3.UP * LIFT)
		arc_far.append(dir * far + Vector3.UP * LIFT)
	var center := Vector3.UP * LIFT
	var near_faces := PackedVector3Array()
	var far_faces := PackedVector3Array()
	var edges := PackedVector3Array()
	for i in steps:
		near_faces.append_array([center, arc_near[i + 1], arc_near[i]])
		far_faces.append_array([arc_near[i], arc_near[i + 1], arc_far[i + 1], arc_near[i], arc_far[i + 1], arc_far[i]])
		edges.append_array([arc_far[i], arc_far[i + 1], arc_near[i], arc_near[i + 1]])
	edges.append_array([center, arc_far[0], center, arc_far[steps]])
	gizmo.add_mesh(_faces(near_faces), get_material("near", gizmo))
	gizmo.add_mesh(_faces(far_faces), get_material("far", gizmo))
	gizmo.add_lines(edges, get_material("edge", gizmo))


static func _faces(vertices: PackedVector3Array) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


# --- Rondes -----------------------------------------------------------------

## Chemin de ronde suivi par `node` (garde, pick-up, avion), ou null.
static func patrol_of(node: Node) -> Path3D:
	var value: Variant = node.get("patrol_path")
	if value is Path3D:
		return value
	if value is NodePath and not (value as NodePath).is_empty():
		return node.get_node_or_null(value) as Path3D
	return null


## La ronde revient-elle au premier point en marchant (garde, pick-up) ?
## L'avion, lui, reprend son trajet au début.
static func patrol_loops(node: Node) -> bool:
	return not node is EnemyAircraft


func _draw_patrol(gizmo: EditorNode3DGizmo, node: Node3D) -> void:
	var path := patrol_of(node)
	if path == null or path.curve == null or path.curve.point_count == 0:
		return
	# Le repère suit les modifications du chemin (outils de Godot).
	var redraw := Callable(node, &"update_gizmos")
	if not path.curve.changed.is_connected(redraw):
		path.curve.changed.connect(redraw)
	var to_local := node.global_transform.affine_inverse()
	var points := PackedVector3Array()
	for i in path.curve.point_count:
		points.append(path.to_global(path.curve.get_point_position(i)) + Vector3.UP * LIFT)
	var faces := PackedVector3Array()
	for i in points.size() - 1:
		_band(faces, points[i], points[i + 1], BAND, true)
	for point in points:
		_square(faces, point, BAND * 1.6)
	var back := PackedVector3Array()
	if patrol_loops(node) and points.size() > 2:
		_band(back, points[-1], points[0], BAND, true)
	# De l'unité à son premier point, en pointillés.
	var origin := node.global_position + Vector3.UP * LIFT
	var reach := origin.distance_to(points[0])
	var distance := 0.0
	while distance < reach:
		_band(back, origin.lerp(points[0], distance / reach), origin.lerp(points[0], minf(distance + DASH, reach) / reach), BAND * 0.8, false)
		distance += DASH_STEP
	gizmo.add_mesh(_faces(_local(faces, to_local)), get_material("patrol", gizmo))
	if not back.is_empty():
		gizmo.add_mesh(_faces(_local(back, to_local)), get_material("patrol_back", gizmo))


static func _local(vertices: PackedVector3Array, to_local: Transform3D) -> PackedVector3Array:
	var local := PackedVector3Array()
	for vertex in vertices:
		local.append(to_local * vertex)
	return local


## Bande au sol de `a` à `b`, de largeur `width` ; avec un chevron plein en
## son milieu, pointé vers `b`, si `arrow`.
static func _band(faces: PackedVector3Array, a: Vector3, b: Vector3, width: float, arrow: bool) -> void:
	var flat := Vector3(b.x - a.x, 0.0, b.z - a.z)
	if flat.length() < 0.01:
		return
	var ahead := flat.normalized()
	var side := ahead.cross(Vector3.UP) * width * 0.5
	faces.append_array([a - side, a + side, b + side, a - side, b + side, b - side])
	if not arrow or flat.length() < CHEVRON * 2.0:
		return
	var tip := (a + b) * 0.5 + ahead * CHEVRON * 0.5 + Vector3.UP * 0.01
	var wing := ahead.cross(Vector3.UP) * CHEVRON * 0.6
	faces.append_array([tip, tip - ahead * CHEVRON + wing, tip - ahead * CHEVRON - wing])


static func _square(faces: PackedVector3Array, at: Vector3, size: float) -> void:
	var h := size * 0.5
	var c := [at + Vector3(-h, 0.01, -h), at + Vector3(h, 0.01, -h), at + Vector3(h, 0.01, h), at + Vector3(-h, 0.01, h)]
	faces.append_array([c[0], c[1], c[2], c[0], c[2], c[3]])


# --- Limites de la caméra ----------------------------------------------------

func _draw_bounds(gizmo: EditorNode3DGizmo, rig: Node3D) -> void:
	var box: AABB = rig.get("bounds")
	var to_local := rig.global_transform.affine_inverse()
	var y := LIFT * 2.0
	var corners: Array[Vector3] = [Vector3(box.position.x, y, box.position.z), Vector3(box.end.x, y, box.position.z),
		Vector3(box.end.x, y, box.end.z), Vector3(box.position.x, y, box.end.z)]
	var faces := PackedVector3Array()
	for i in 4:
		_band(faces, corners[i], corners[(i + 1) % 4], BAND, false)
	gizmo.add_mesh(_faces(_local(faces, to_local)), get_material("bounds", gizmo))
	gizmo.add_handles(_local(PackedVector3Array(bounds_handles(box)), to_local), get_material("handles", gizmo), PackedInt32Array())


## Poignées des bords (ouest, est, nord, sud), dans le monde.
static func bounds_handles(box: AABB) -> Array[Vector3]:
	var center := box.get_center()
	var y := LIFT * 2.0
	return [Vector3(box.position.x, y, center.z), Vector3(box.end.x, y, center.z), Vector3(center.x, y, box.position.z), Vector3(center.x, y, box.end.z)]


## Limites `box` dont le bord `edge` (ouest, est, nord, sud) passe par
## `point` : gardées sur le terrain `terrain` (s'il existe), collées à son
## bord à moins de `BOUNDS_SNAP`, au moins `BOUNDS_MIN` de côté.
static func moved_bounds(box: AABB, edge: int, point: Vector3, terrain: AABB) -> AABB:
	var x0 := box.position.x
	var x1 := box.end.x
	var z0 := box.position.z
	var z1 := box.end.z
	var has_terrain := terrain.size != Vector3.ZERO
	var low_x := terrain.position.x if has_terrain else -INF
	var high_x := terrain.end.x if has_terrain else INF
	var low_z := terrain.position.z if has_terrain else -INF
	var high_z := terrain.end.z if has_terrain else INF
	match edge:
		0:
			x0 = clampf(_stick(point.x, low_x), low_x, x1 - BOUNDS_MIN)
		1:
			x1 = clampf(_stick(point.x, high_x), x0 + BOUNDS_MIN, high_x)
		2:
			z0 = clampf(_stick(point.z, low_z), low_z, z1 - BOUNDS_MIN)
		3:
			z1 = clampf(_stick(point.z, high_z), z0 + BOUNDS_MIN, high_z)
	return AABB(Vector3(x0, box.position.y, z0), Vector3(x1 - x0, box.size.y, z1 - z0))


static func _stick(value: float, edge: float) -> float:
	return edge if absf(value - edge) < BOUNDS_SNAP else value


# --- Trajets ----------------------------------------------------------------

## Le trajet est-il une boucle (voitures, passants en boucle) ?
static func is_loop(node: Node3D) -> bool:
	return node is TrafficCar or bool(node.get("loop"))


func _draw_route(gizmo: EditorNode3DGizmo, node: Node3D) -> void:
	var points: PackedVector3Array = node.get("points")
	if points.is_empty():
		return
	var local := PackedVector3Array()
	for point in points:
		local.append(point - node.position + Vector3.UP * LIFT)
	var lines := PackedVector3Array()
	for i in local.size() - 1:
		lines.append_array([local[i], local[i + 1]])
	if is_loop(node) and local.size() > 2:
		lines.append_array([local[-1], local[0]])
	gizmo.add_lines(lines, get_material("route", gizmo))
	gizmo.add_handles(local, get_material("handles", gizmo), PackedInt32Array())


func _get_handle_name(gizmo: EditorNode3DGizmo, handle_id: int, _secondary: bool) -> String:
	if gizmo.get_node_3d() is CameraRig:
		return BOUNDS_HANDLES[handle_id]
	return "Point %d" % (handle_id + 1)


func _get_handle_value(gizmo: EditorNode3DGizmo, handle_id: int, _secondary: bool) -> Variant:
	if gizmo.get_node_3d() is CameraRig:
		return gizmo.get_node_3d().get("bounds")
	return (gizmo.get_node_3d().get("points") as PackedVector3Array)[handle_id]


func _set_handle(gizmo: EditorNode3DGizmo, handle_id: int, _secondary: bool, camera: Camera3D, screen_pos: Vector2) -> void:
	var node := gizmo.get_node_3d()
	var snap: bool = plugin.call("grid_enabled") if plugin else true
	var point := Palette.ground_point(camera, screen_pos, GRID_STEP if snap else 0.0)
	if point == Vector3.INF:
		return
	if node is CameraRig:
		node.set("bounds", moved_bounds(node.get("bounds"), handle_id, point, Palette.ground_bounds(node.owner if node.owner else node.get_parent())))
		node.update_gizmos()
		return
	var points: PackedVector3Array = node.get("points")
	points[handle_id] = point
	node.set("points", points)
	node.call("place_preview")
	node.update_gizmos()


func _commit_handle(gizmo: EditorNode3DGizmo, handle_id: int, _secondary: bool, restore: Variant, cancel: bool) -> void:
	var node := gizmo.get_node_3d()
	if node is CameraRig:
		if cancel:
			node.set("bounds", restore)
			node.update_gizmos()
		else:
			set_bounds(node, node.get("bounds"), restore, "Déplacer une limite de la caméra")
		return
	var points: PackedVector3Array = node.get("points")
	var before := points.duplicate()
	before[handle_id] = restore
	if cancel:
		set_points(node, before)
		return
	var undo := plugin.get_undo_redo()
	undo.create_action("Déplacer un point du trajet")
	# Les opérations portent sur le nœud : l'action va dans l'historique de
	# sa scène.
	undo.add_do_property(node, &"points", points)
	undo.add_undo_property(node, &"points", before)
	for method: StringName in [&"place_preview", &"update_gizmos"]:
		undo.add_do_method(node, method)
		undo.add_undo_method(node, method)
	undo.commit_action()


## Limites de la caméra `rig` passées de `before` à `after`, en une action
## annulable `label`.
func set_bounds(rig: Node3D, after: AABB, before: AABB, label: String) -> void:
	var undo := plugin.get_undo_redo()
	undo.create_action(label)
	undo.add_do_property(rig, &"bounds", after)
	undo.add_undo_property(rig, &"bounds", before)
	undo.add_do_method(rig, &"update_gizmos")
	undo.add_undo_method(rig, &"update_gizmos")
	undo.commit_action()


## Change les points du trajet de `node` et met son aperçu à jour.
func set_points(node: Node3D, points: PackedVector3Array) -> void:
	node.set("points", points)
	node.call("place_preview")
	node.update_gizmos()


# --- Bruits -----------------------------------------------------------------

func _draw_circle(gizmo: EditorNode3DGizmo, center: Vector3, radius: float) -> void:
	var lines := PackedVector3Array()
	var steps := 48
	for i in steps:
		var a := TAU * i / steps
		var b := TAU * (i + 1) / steps
		lines.append_array([center + Vector3(cos(a), 0.0, sin(a)) * radius + Vector3.UP * LIFT,
			center + Vector3(cos(b), 0.0, sin(b)) * radius + Vector3.UP * LIFT])
	gizmo.add_lines(lines, get_material("noise", gizmo))
