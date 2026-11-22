@tool
extends RefCounted
## Scénario de l'étape 4 : pose d'unités, de rondes, de civils, d'objectifs
## et de l'extraction ; trajets à poignées ; informations de la mission et
## cibles des objectifs ; repères dans la vue 3D de l'éditeur.

static func run(tree: SceneTree, out: String) -> void:
	var plugin: EditorPlugin = Engine.get_meta(&"mission_editor")
	var root := EditorInterface.get_edited_scene_root()
	var dock: Control = plugin.get("_dock")
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 60.0
	var holder := SubViewport.new()
	holder.size = Vector2i(1000, 1000)
	holder.world_3d = root.get_world_3d()
	EditorInterface.get_base_control().add_child(holder)
	holder.add_child(camera)
	camera.look_at_from_position(Vector3(0, 80, 0.01), Vector3.ZERO)
	var history: UndoRedo = plugin.get_undo_redo().get_history_undo_redo(plugin.get_undo_redo().get_object_history_id(root))

	_place(plugin, camera, "operator", [Vector3(-20, 0, 22)])
	var delta := root.get_node_or_null(^"Units/Delta")
	print("TEST opérateur : %s, numéro %s, nom affiché %s" % [delta.name if delta else "absent", delta.get("unit_index") if delta else "-", delta.get("display_name") if delta else "-"])

	_place(plugin, camera, "patrol", [Vector3(10, 0, 10), Vector3(20, 0, 10)])
	var route := root.get_node_or_null(^"PatrolPaths/Route1") as Path3D
	var walker := root.get_node("Enemies").get_children()[-1]
	print("TEST ronde : chemin %s (%d points), garde %s, patrol_path %s, est Enemy %s" % [route.name if route else "absent", route.curve.point_count if route else 0, walker.name, walker.get("patrol_path"), walker is Enemy])

	_place(plugin, camera, "technical", [Vector3(-25, 0, -25), Vector3(-5, 0, -25)])
	var truck := root.get_node("Enemies").get_children()[-1]
	print("TEST pick-up : %s, patrol_path %s" % [truck.name, truck.get("patrol_path")])

	_place(plugin, camera, "passerby", [Vector3(-10, 0, 25), Vector3(10, 0, 25)])
	_place(plugin, camera, "traffic", [Vector3(-26, 0, -12), Vector3(26, 0, 26)])
	var car := root.get_node("Decor").get_children()[-1] as Node3D
	# Les repères d'un nœud posé sont créés une image plus tard.
	for k in 3:
		await tree.process_frame
	print("TEST voiture : %s, %d points, gizmos %d" % [car.name, car.get("points").size(), car.get_gizmos().size()])
	# Sélection de la voiture : le dock montre son trajet ; ajout d'un point.
	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(car)
	for k in 3:
		await tree.process_frame
	print("TEST trajet dans le dock : %s, visible %s" % [dock.get("_route_label").text, dock.get("_route_box").visible])
	dock.emit_signal(&"route_point_added")
	print("TEST point ajouté : %d points" % car.get("points").size())
	history.undo()
	print("TEST ajout annulé : %d points" % car.get("points").size())
	# Poignée 0 déplacée de (x, z) à (0, 0) puis validée, puis annulée.
	var gizmo := car.get_gizmos()[0] as EditorNode3DGizmo
	var gizmos: EditorNode3DGizmoPlugin = plugin.get("_gizmos")
	var first: Vector3 = car.get("points")[0]
	gizmos._set_handle(gizmo, 0, false, camera, camera.unproject_position(Vector3(2.2, 0, -1.9)))
	gizmos._commit_handle(gizmo, 0, false, first, false)
	print("TEST poignée : %s → %s" % [first, car.get("points")[0]])
	history.undo()
	print("TEST poignée annulée : %s" % car.get("points")[0])

	_place(plugin, camera, "documents", [Vector3(18, 0, -18)])
	_place(plugin, camera, "generator", [Vector3(24, 0, -10)])
	_place(plugin, camera, "extraction", [Vector3(-24, 0, 4)])
	print("TEST extraction : %s" % root.get_node_or_null(^"ExtractionZone"))
	_place(plugin, camera, "guard", [Vector3(0, 0, -8)])

	# Informations : objectifs et cibles.
	var info: MissionInfo = plugin.get("_info")
	print("TEST informations : %s" % (info.title if info else "aucune"))
	if info:
		info.objectives.append(MissionObjective.make("documents", "Récupérer les documents"))
		info.objectives.append(MissionObjective.make("sabotage", "Saboter le groupe électrogène"))
		info.objectives.append(MissionObjective.make("depot", "Incendier le dépôt"))
	plugin.call("_refresh_dock")
	await tree.process_frame
	for line in dock.get("_info_box").get_children():
		if line is Button or line is Label:
			print("TEST objectif : %s" % line.text)

	# Repères : vue 3D de l'éditeur cadrée sur la carte, de nuit.
	plugin.call("_on_night_toggled", true)
	EditorInterface.set_main_screen_editor("3D")
	EditorInterface.get_selection().clear()
	for node in [walker, car]:
		EditorInterface.get_selection().add_node(node)
	# La caméra de la vue de l'éditeur garde la position donnée tant que
	# personne ne la déplace.
	var view_camera := EditorInterface.get_editor_viewport_3d(0).get_camera_3d()
	view_camera.look_at_from_position(Vector3(38, 52, 44), Vector3(0, 0, 4))
	view_camera.fov = 50.0
	for k in 20:
		await RenderingServer.frame_post_draw
		view_camera.look_at_from_position(Vector3(38, 52, 44), Vector3(0, 0, 4))
	var viewport := EditorInterface.get_editor_viewport_3d(0)
	viewport.get_texture().get_image().save_png(out + "/editor_step4_gizmos.png")
	plugin.call("_on_night_toggled", false)
	holder.queue_free()
	if info:
		info.objectives.resize(info.objectives.size() - 3)
	EditorInterface.save_scene()
	for k in 5:
		await tree.process_frame
	print("TEST enregistrée")


static func _place(plugin: EditorPlugin, camera: Camera3D, id: String, points: Array) -> void:
	plugin.call("_on_tool_selected", id)
	for point: Vector3 in points:
		var screen := camera.unproject_position(point)
		var motion := InputEventMouseMotion.new()
		motion.position = screen
		plugin._forward_3d_gui_input(camera, motion)
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		press.position = screen
		plugin._forward_3d_gui_input(camera, press)
	plugin.call("_finish_route")
	plugin.call("_cancel_tool")


static func _find(node: Node, type: String) -> Node:
	if node.get_class() == type:
		return node
	for child in node.get_children():
		var found := _find(child, type)
		if found:
			return found
	return null
