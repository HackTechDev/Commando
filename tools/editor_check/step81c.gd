@tool
extends RefCounted
## Scénario des points 8.1 c et 8.1 d : rondes tracées point par point
## (double-clic ou Entrée pour finir, Retour arrière, abandon au clic
## droit) et leurs repères dans la vue 3D (capture `editor_81c.png`).

static func run(tree: SceneTree, out: String) -> void:
	var plugin = Engine.get_meta(&"mission_editor")
	var root := EditorInterface.get_edited_scene_root()
	var history: UndoRedo = plugin.get_undo_redo().get_history_undo_redo(plugin.get_undo_redo().get_object_history_id(root))
	var holder := SubViewport.new()
	holder.size = Vector2i(1000, 1000)
	holder.world_3d = root.get_world_3d()
	EditorInterface.get_base_control().add_child(holder)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 60.0
	camera.cull_mask = 0xFFFFFFFF
	holder.add_child(camera)
	camera.look_at_from_position(Vector3(0, 80, 0.01), Vector3.ZERO)
	var enemies := root.get_node("Enemies")
	var paths_before := _paths(root)

	# Garde en ronde : quatre points, un retiré au passage, double-clic.
	plugin.call("_on_tool_selected", "patrol")
	_click(plugin, camera, Vector3(-20, 0, -10))
	_click(plugin, camera, Vector3(-5, 0, -10))
	_click(plugin, camera, Vector3(-5, 0, 10))
	print("TEST statut à 3 points : %s" % plugin.get("_dock").get("_status").text)
	_key(plugin, camera, KEY_BACKSPACE)
	_click(plugin, camera, Vector3(-8, 0, 5))
	_click(plugin, camera, Vector3(-20, 0, 5))
	_click(plugin, camera, Vector3(-20, 0, 5), true)
	var walker := enemies.get_children()[-1] as Node3D
	var path := root.get_node("PatrolPaths").get_children()[-1] as Path3D
	print("TEST ronde %s, cap %.0f°, chemin %s : %s" % [walker.name, -rad_to_deg(walker.rotation.y), path.name, _points(path)])
	print("TEST outil toujours actif : %s, tracé vide : %s" % [plugin.get("_tool"), (plugin.get("_trace") as PackedVector3Array).is_empty()])

	# Pick-up armé : trois points, Entrée.
	plugin.call("_on_tool_selected", "technical")
	for point: Vector3 in [Vector3(5, 0, -15), Vector3(20, 0, -15), Vector3(20, 0, 0)]:
		_click(plugin, camera, point)
	_key(plugin, camera, KEY_ENTER)
	var truck := enemies.get_children()[-1] as Node3D
	print("TEST pick-up %s, chemin %s" % [truck.name, _points(truck.get_node(truck.get("patrol_path")) as Path3D)])

	# Passant : trois points, Entrée.
	plugin.call("_on_tool_selected", "passerby")
	for point: Vector3 in [Vector3(5, 0, 15), Vector3(15, 0, 15), Vector3(15, 0, 22)]:
		_click(plugin, camera, point)
	_key(plugin, camera, KEY_ENTER)
	var passerby := root.get_node("Decor").get_children()[-1] as Node3D
	print("TEST passant %s, points %s" % [passerby.name, passerby.get("points")])

	# Un seul point puis Entrée : rien ; clic droit : tracé abandonné, outil
	# gardé ; second clic droit : outil arrêté.
	var count := enemies.get_child_count()
	plugin.call("_on_tool_selected", "patrol")
	_click(plugin, camera, Vector3(25, 0, 25))
	_key(plugin, camera, KEY_ENTER)
	print("TEST un point puis Entrée : gardes %d → %d" % [count, enemies.get_child_count()])
	_click(plugin, camera, Vector3(25, 0, 25))
	_click(plugin, camera, Vector3(28, 0, 25))
	_right(plugin, camera)
	print("TEST clic droit : outil « %s », tracé vide %s, gardes %d" % [plugin.get("_tool"), (plugin.get("_trace") as PackedVector3Array).is_empty(), enemies.get_child_count()])
	_right(plugin, camera)
	print("TEST second clic droit : outil « %s »" % plugin.get("_tool"))

	# Annulation du pick-up : son chemin part avec lui.
	history.undo()
	history.undo()
	print("TEST deux annulations : chemins %d (avant le scénario %d, plus la ronde)" % [_paths(root), paths_before])
	history.redo()
	history.redo()

	# Chemin modifié (outils de Godot) : le repère suit.
	path.curve.add_point(Vector3(-25, 0, -2))
	# Garde écarté de son premier point : trait pointillé jusqu'au chemin.
	walker.position += Vector3(-6, 0, -6)
	for k in 3:
		await tree.process_frame
	var light := DirectionalLight3D.new()
	holder.add_child(light)
	light.rotation = Vector3(-0.9, 0.5, 0.0)
	holder.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	camera.size = 64.0
	for k in 8:
		await RenderingServer.frame_post_draw
	holder.get_texture().get_image().save_png(out + "/editor_81c.png")
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.look_at_from_position(Vector3(-30, 30, 35), Vector3(-10, 0, 0))
	for k in 6:
		await RenderingServer.frame_post_draw
	holder.get_texture().get_image().save_png(out + "/editor_81c_side.png")
	holder.queue_free()
	EditorInterface.save_scene()
	for k in 5:
		await tree.process_frame
	print("TEST enregistrée")


static func _paths(root: Node) -> int:
	var holder := root.get_node_or_null("PatrolPaths")
	return holder.get_child_count() if holder else 0


static func _points(path: Path3D) -> Array:
	var points := []
	for i in path.curve.point_count:
		points.append(path.to_global(path.curve.get_point_position(i)))
	return points


static func _click(plugin: Object, camera: Camera3D, at: Vector3, double := false) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = camera.unproject_position(at)
	plugin._forward_3d_gui_input(camera, motion)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.double_click = double
	press.position = motion.position
	plugin._forward_3d_gui_input(camera, press)


static func _right(plugin: Object, camera: Camera3D) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_RIGHT
	press.pressed = true
	plugin._forward_3d_gui_input(camera, press)


static func _key(plugin: Object, camera: Camera3D, key: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = true
	plugin._forward_3d_gui_input(camera, event)
