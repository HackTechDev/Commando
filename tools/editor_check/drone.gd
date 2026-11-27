@tool
extends RefCounted
## Scénario du drone de surveillance dans la palette : pose un drone sur
## une ronde de quatre points, vérifie le trajet, que le modèle construit
## n'est pas enregistré, la vérification de la carte, puis annule.

const Palette := preload("res://addons/mission_editor/palette.gd")


static func run(tree: SceneTree, out: String) -> void:
	var plugin = Engine.get_meta(&"mission_editor")
	var root := EditorInterface.get_edited_scene_root()
	var entry := Palette.find("drone")
	print("TEST entrée : « %s », %s, sous %s, outil %s" % [entry.get("label"), entry.get("category"), entry.get("parent"), entry.get("tool")])
	var route := PackedVector3Array([Vector3(-15, 0, -15), Vector3(15, 0, -15), Vector3(15, 0, 15), Vector3(-15, 0, 15)])
	var nodes: Array = plugin.place("drone", route[0], 0.0, Vector3.INF, route)
	for k in 10:
		await tree.process_frame
	var drone: Node3D = null
	var path: Path3D = null
	for node: Node in nodes:
		if node is SurveillanceDrone:
			drone = node
		elif node is Path3D:
			path = node
	print("TEST drone %s sous %s, trajet %s (%d points), relié %s" % [drone != null, drone.get_parent().name if drone else "?", path != null, path.curve.point_count if path else 0, drone.get_node_or_null(drone.get("patrol_path")) == path if drone else false])
	var built := drone.get_children().filter(func(n: Node) -> bool: return n.owner == null).size()
	print("TEST pièces construites (non enregistrées) : %d ; modèle à %s" % [built, drone.get("model").global_position if drone.get("model") else Vector3.INF])
	var report: Array = await plugin.check()
	var mine := report.filter(func(line: Variant) -> bool: return str(line).contains("Drone"))
	print("TEST vérification : %d remarques, dont %d sur le drone" % [report.size(), mine.size()])
	for line in mine:
		print("TEST   %s" % [line])
	var undo := plugin.get_undo_redo() as EditorUndoRedoManager
	undo.get_history_undo_redo(undo.get_object_history_id(root)).undo()
	print("TEST après annulation : drone présent %s" % [is_instance_valid(drone) and drone.is_inside_tree()])
