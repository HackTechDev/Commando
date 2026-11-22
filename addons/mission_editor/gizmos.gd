@tool
extends EditorNode3DGizmoPlugin
## Repères de l'éditeur de mission dans la vue 3D :
## - cône de vue de chaque garde (`VisionConfig` : zones proche et
##   lointaine, réduite la nuit comme en jeu, `LevelRoot.NIGHT_SIGHT`) ;
## - trajets des passants et des boucles de voitures, avec une poignée par
##   point (déplacement aimanté à la grille, annulable) ;
## - portée des bruits : klaxon des voitures, moteur du Sabre.
## Les rondes des gardes sont des `Path3D`, que l'éditeur Godot sait déjà
## modifier (poignées, ajout et retrait de points).

const Palette := preload("res://addons/mission_editor/palette.gd")

const GRID_STEP := 0.5
## Hauteur des repères au-dessus du sol (m).
const LIFT := 0.06

## Greffon : historique d'annulation, grille.
var plugin: EditorPlugin


func _init() -> void:
	create_material("near", Color(1.0, 0.85, 0.2, 0.32))
	create_material("far", Color(1.0, 0.85, 0.2, 0.13))
	create_material("edge", Color(1.0, 0.8, 0.2))
	create_material("route", Color(0.35, 0.8, 1.0))
	create_material("noise", Color(1.0, 0.45, 0.3))
	create_handle_material("handles")


func _get_gizmo_name() -> String:
	return "Éditeur de mission"


func _has_gizmo(node: Node3D) -> bool:
	return node is Enemy or node is Passerby or node is TrafficCar or node is Sabre


func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	var node := gizmo.get_node_3d()
	if node is Enemy:
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


func _get_handle_name(_gizmo: EditorNode3DGizmo, handle_id: int, _secondary: bool) -> String:
	return "Point %d" % (handle_id + 1)


func _get_handle_value(gizmo: EditorNode3DGizmo, handle_id: int, _secondary: bool) -> Variant:
	return (gizmo.get_node_3d().get("points") as PackedVector3Array)[handle_id]


func _set_handle(gizmo: EditorNode3DGizmo, handle_id: int, _secondary: bool, camera: Camera3D, screen_pos: Vector2) -> void:
	var node := gizmo.get_node_3d()
	var snap: bool = plugin.call("grid_enabled") if plugin else true
	var point := Palette.ground_point(camera, screen_pos, GRID_STEP if snap else 0.0)
	if point == Vector3.INF:
		return
	var points: PackedVector3Array = node.get("points")
	points[handle_id] = point
	node.set("points", points)
	node.call("place_preview")
	node.update_gizmos()


func _commit_handle(gizmo: EditorNode3DGizmo, handle_id: int, _secondary: bool, restore: Variant, cancel: bool) -> void:
	var node := gizmo.get_node_3d()
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
