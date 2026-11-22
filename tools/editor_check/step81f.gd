@tool
extends RefCounted
## Scénario du point 8.1 f : limites de la caméra affichées, réglées par
## poignées et calées sur le terrain (capture `editor_81f.png`).

const Palette := preload("res://addons/mission_editor/palette.gd")

static func run(tree: SceneTree, out: String) -> void:
	var plugin = Engine.get_meta(&"mission_editor")
	var root := EditorInterface.get_edited_scene_root()
	var history: UndoRedo = plugin.get_undo_redo().get_history_undo_redo(plugin.get_undo_redo().get_object_history_id(root))
	var rig := root.get_node("CameraRig") as Node3D
	var holder := SubViewport.new()
	holder.size = Vector2i(1000, 1000)
	holder.world_3d = root.get_world_3d()
	EditorInterface.get_base_control().add_child(holder)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 75.0
	camera.cull_mask = 0xFFFFFFFF
	holder.add_child(camera)
	camera.look_at_from_position(Vector3(0, 100, 0.01), Vector3.ZERO)
	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(rig)
	for k in 3:
		await tree.process_frame
	var gizmos: EditorNode3DGizmoPlugin = plugin.get("_gizmos")
	var gizmo: EditorNode3DGizmo = null
	for item in rig.get_gizmos():
		if (item as EditorNode3DGizmo).get_plugin() == gizmos:
			gizmo = item
	print("TEST terrain %s, limites %s, repère %s" % [Palette.ground_bounds(root), rig.get("bounds"), gizmo != null])
	var original: AABB = rig.get("bounds")
	# Ouest vers x = -20,3 (grille) ; est au-delà du terrain ; nord à 0,6 m
	# du bord du terrain (collé) ; sud au-delà du nord (côté minimal).
	var terrain := Palette.ground_bounds(root)
	var drags: Array = [[0, Vector3(-20.3, 0, 0)], [1, Vector3(terrain.end.x + 15, 0, 0)], [2, Vector3(0, 0, terrain.position.z + 0.6)], [3, Vector3(0, 0, -40)]]
	for drag: Array in drags:
		var restore: AABB = rig.get("bounds")
		gizmos._set_handle(gizmo, drag[0], false, camera, camera.unproject_position(drag[1]))
		gizmos._commit_handle(gizmo, drag[0], false, restore, false)
		print("TEST %s vers %s : %s" % [gizmos._get_handle_name(gizmo, drag[0], false), drag[1], rig.get("bounds")])
	for k in 4:
		history.undo()
	print("TEST quatre annulations : %s (avant %s)" % [rig.get("bounds"), original])
	# Bord ouest déplacé puis annulé en cours de geste (Échap).
	gizmos._set_handle(gizmo, 0, false, camera, camera.unproject_position(Vector3(-10, 0, 0)))
	gizmos._commit_handle(gizmo, 0, false, original, true)
	print("TEST geste annulé : %s" % rig.get("bounds"))
	rig.set("bounds", AABB(Vector3(-10, 0, -15), Vector3(25, 0, 20)))
	var fitted: AABB = plugin.fit_camera_bounds()
	print("TEST calées sur le terrain : %s" % fitted)
	history.undo()
	print("TEST calage annulé : %s" % rig.get("bounds"))
	history.redo()
	# Capture : limites réduites à l'ouest pour voir le cadre et le terrain.
	gizmos._set_handle(gizmo, 0, false, camera, camera.unproject_position(Vector3(-15, 0, 0)))
	gizmos._commit_handle(gizmo, 0, false, fitted, false)
	var light := DirectionalLight3D.new()
	holder.add_child(light)
	light.rotation = Vector3(-0.9, 0.5, 0.0)
	holder.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	for k in 8:
		await RenderingServer.frame_post_draw
	holder.get_texture().get_image().save_png(out + "/editor_81f.png")
	holder.queue_free()
	EditorInterface.save_scene()
	for k in 5:
		await tree.process_frame
	var text := FileAccess.get_file_as_string(root.scene_file_path)
	print("TEST enregistrée : %s" % Array(text.split("\n")).filter(func(l: String) -> bool: return l.begins_with("bounds")))
