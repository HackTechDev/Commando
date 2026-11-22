@tool
extends RefCounted
## Scénario du point 8.1 a : éléments ajoutés à la palette (mine, engin
## improvisé, barrière, immeuble, avion ennemi, renforts, aire de poser).
## À lancer sur une carte qui a un dépôt (Convoi de nuit).

static func run(tree: SceneTree, out: String) -> void:
	var plugin = Engine.get_meta(&"mission_editor")
	var root := EditorInterface.get_edited_scene_root()
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 100.0
	var holder := SubViewport.new()
	holder.size = Vector2i(1000, 1000)
	holder.world_3d = root.get_world_3d()
	EditorInterface.get_base_control().add_child(holder)
	holder.add_child(camera)
	camera.look_at_from_position(Vector3(0, 120, 0.01), Vector3.ZERO)
	var steps: Array = [
		["mine", [Vector3(-6, 0, -4)]],
		["ied", [Vector3(-3, 0, -4)]],
		["barrier", [Vector3(0, 0, 4)], 2],
		["tower", [Vector3(-30, 0, -30)]],
		["aircraft", [Vector3(-40, 0, 0), Vector3(40, 0, 0)]],
		["reinforcements", [Vector3(40, 0, 40)]],
		["pad", [Vector3(30, 0, -40)]],
	]
	for step: Array in steps:
		plugin.call("_on_tool_selected", step[0])
		for k in (step[2] if step.size() > 2 else 0):
			_key(plugin, camera, KEY_R)
		for point: Vector3 in step[1]:
			_click(plugin, camera, point)
		plugin.call("_finish_route")
		plugin.call("_cancel_tool")
	var region := root.get_node("NavigationRegion3D")
	var enemies := root.get_node("Enemies")
	var last := func(parent: Node, prefix: String) -> Node:
		var found := parent.get_children().filter(func(n: Node) -> bool: return String(n.name).begins_with(prefix))
		return found[-1] if not found.is_empty() else null
	var mine: Node = last.call(region, "Mine")
	var ied: Node = last.call(region, "Ied")
	var barrier: Node3D = last.call(region, "Barrier")
	var tower: Node = last.call(region, "Tower")
	var plane: Node = last.call(enemies, "Gunship")
	var reinforcements: Node = last.call(enemies, "Reinforcements")
	var pad: Node3D = last.call(root.get_node("Decor"), "Pad")
	print("TEST mine %s (improvisée %s), engin %s (improvisé %s)" % [mine.name, mine.get("improvised"), ied.name, ied.get("improvised")])
	var posts := region.get_children().slice(-6).filter(func(n: Node) -> bool: return String(n.name).begins_with("LowWall") and n.position.distance_to(barrier.position) < 6.0)
	print("TEST barrière %s, cap %.0f°, murets %s" % [barrier.name, -rad_to_deg(barrier.rotation.y), posts.map(func(n: Node3D) -> Vector3: return n.position.snapped(Vector3.ONE * 0.01))])
	print("TEST immeuble %s, %d étages, enfants construits %d" % [tower.name, tower.get("storeys"), tower.get_child_count()])
	print("TEST avion %s, trajet %s → %s" % [plane.name, plane.get("patrol_path"), plane.get_node_or_null(plane.get("patrol_path"))])
	print("TEST renforts %s, cible %s → %s" % [reinforcements.name, reinforcements.get("target"), reinforcements.get_node_or_null(reinforcements.get("target"))])
	print("TEST aire %s en %s, maillage %s" % [pad.name, pad.position, pad.mesh.resource_name])
	for item: Dictionary in await plugin.check():
		print("TEST   [%s] %s" % [item["level"], item["text"]])
	camera.size = 110.0
	var light := DirectionalLight3D.new()
	holder.add_child(light)
	light.rotation = Vector3(-0.9, 0.5, 0.0)
	camera.look_at_from_position(Vector3(50, 70, 50), Vector3(0, 0, 0))
	holder.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	for k in 8:
		await RenderingServer.frame_post_draw
	holder.get_texture().get_image().save_png(out + "/editor_81a.png")
	holder.queue_free()
	EditorInterface.save_scene()
	for k in 5:
		await tree.process_frame
	print("TEST enregistrée")


static func _click(plugin: Object, camera: Camera3D, at: Vector3) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = camera.unproject_position(at)
	plugin._forward_3d_gui_input(camera, press)


static func _key(plugin: Object, camera: Camera3D, key: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = true
	plugin._forward_3d_gui_input(camera, event)
