@tool
extends RefCounted
## Scénario du point 8.1 b : pose sur les toits et les étages (Kasbah).

static func run(tree: SceneTree, out: String) -> void:
	var plugin = Engine.get_meta(&"mission_editor")
	var root := EditorInterface.get_edited_scene_root()
	var dock: Control = plugin.get("_dock")
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 100.0
	var holder := SubViewport.new()
	holder.size = Vector2i(1000, 1000)
	holder.world_3d = root.get_world_3d()
	EditorInterface.get_base_control().add_child(holder)
	holder.add_child(camera)
	camera.look_at_from_position(Vector3(0, 150, 0.01), Vector3.ZERO)
	var building := root.find_children("*", "Node3D", true, false).filter(func(n: Node) -> bool: return n is Building and n.owner == root)[0] as Node3D
	var tower := root.find_children("*", "Node3D", true, false).filter(func(n: Node) -> bool: return n is Tower and n.owner == root)
	print("TEST bâtiment %s en %s, hauteur des murs %s ; immeubles %s" % [building.name, building.position, building.get("wall_height"), tower.map(func(n: Node3D) -> String: return "%s %s, %d étages" % [n.name, n.position, n.get("storeys")])])
	var roof := building.position + Vector3(0.5, 0, 0.5)
	var cases: Array = [
		["guard", "toit du bâtiment", roof, true],
		["guard", "sol nu", Vector3(-40, 0, -5), true],
		["road", "route au-dessus du bâtiment", roof, true],
		["guard", "toit, case décochée", roof, false],
	]
	if not tower.is_empty():
		cases.insert(1, ["guard", "toit de l'immeuble", (tower[0] as Node3D).position + Vector3(0.5, 0, 0.5), true])
	for case: Array in cases:
		dock.get("_surface").button_pressed = case[3]
		plugin.call("_on_tool_selected", case[0])
		var point: Vector3 = plugin.call("_aim", camera, camera.unproject_position(case[2]))
		print("TEST %s (%s) : %s" % [case[1], case[0], point])
		plugin.call("_cancel_tool")
	dock.get("_surface").button_pressed = true
	# Garde posé sur le toit, puis ronde tracée sur ce toit.
	_place(plugin, camera, "guard", [roof])
	var guard := root.get_node("Enemies").get_children()[-1] as Node3D
	_place(plugin, camera, "patrol", [roof + Vector3(-2, 0, -1.5), roof + Vector3(2, 0, -1.5)])
	var walker := root.get_node("Enemies").get_children()[-1] as Node3D
	var path := root.get_node("PatrolPaths").get_children()[-1] as Path3D
	print("TEST garde posé %s en %s ; ronde %s en %s, chemin %s" % [guard.name, guard.position, walker.name, walker.position, [path.curve.get_point_position(0), path.curve.get_point_position(1)]])
	holder.queue_free()
	EditorInterface.save_scene()
	for k in 5:
		await tree.process_frame
	print("TEST enregistrée")


static func _place(plugin: Object, camera: Camera3D, id: String, points: Array) -> void:
	plugin.call("_on_tool_selected", id)
	for point: Vector3 in points:
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		press.position = camera.unproject_position(point)
		plugin._forward_3d_gui_input(camera, press)
	plugin.call("_cancel_tool")
