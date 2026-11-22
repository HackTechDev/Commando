@tool
extends RefCounted
## Scénario de l'étape 3 : pose d'éléments au clic dans une scène ouverte,
## réglages de la carte, annulation, enregistrement.

static func run(tree: SceneTree, out: String) -> void:
	var plugin: EditorPlugin = Engine.get_meta(&"mission_editor")
	var root := EditorInterface.get_edited_scene_root()
	print("TEST racine %s, greffon %s" % [root.name, plugin != null])
	var dock: Control = plugin.get("_dock")
	print("TEST générateur : %s" % plugin.call("generator_of", root))
	print("TEST dock : titre « %s », avertissement « %s »" % [dock.get("_title").text, dock.get("_warning").text if dock.get("_warning").visible else ""])
	# Vue de dessus pour viser le sol.
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1000, 1000)
	viewport.world_3d = root.get_world_3d()
	EditorInterface.get_base_control().add_child(viewport)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 60.0
	viewport.add_child(camera)
	camera.look_at_from_position(Vector3(0, 80, 0.01), Vector3.ZERO)
	var before := root.find_children("*", "", true, true).size()
	var history: UndoRedo = plugin.get_undo_redo().get_history_undo_redo(plugin.get_undo_redo().get_object_history_id(root))
	# Bâtiment au clic, tourné de 30°.
	plugin.call("_on_tool_selected", "building")
	_key(plugin, camera, KEY_R)
	_key(plugin, camera, KEY_R)
	_click(plugin, camera, Vector3(-10.2, 0, 8.1))
	var building := root.find_children("Building*", "Node3D", true, false)
	building = building.filter(func(n: Node) -> bool: return n.owner == root and n.get_script() == load("res://scripts/props/building.gd"))
	var placed: Node3D = building[-1]
	print("TEST bâtiment : %s sous %s en %s, rotation %.0f°, possédé %s, enfants d'aperçu possédés %d" % [placed.name, placed.get_parent().name, placed.position, rad_to_deg(placed.rotation.y), placed.owner == root,
		placed.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n.owner == root).size()])
	# Route de (-20, 20) à (20, 20) : deux clics.
	plugin.call("_on_tool_selected", "road")
	_click(plugin, camera, Vector3(-20, 0, 20))
	_click(plugin, camera, Vector3(20, 0, 20))
	var road: MeshInstance3D = root.get_node("Decor").get_children().filter(func(n: Node) -> bool: return n is MeshInstance3D and n.mesh and n.mesh.resource_name == "surface_road")[-1]
	print("TEST route : %s, longueur %.1f m, largeur %.1f m, centre %s" % [road.name, road.basis.z.length(), road.basis.x.length(), road.position])
	# Lampadaire (parent Lamps) et tracé de mur de 13 m (3 murs).
	plugin.call("_on_tool_selected", "lamp")
	_click(plugin, camera, Vector3(5, 0, -5))
	plugin.call("_on_tool_selected", "wall_line")
	_click(plugin, camera, Vector3(-15, 0, -15))
	_click(plugin, camera, Vector3(-2, 0, -15))
	var lamp: Node = root.get_node("Lamps").get_children()[-1]
	print("TEST lampadaire : %s, enfants possédés %d" % [lamp.name, lamp.get_children().filter(func(n: Node) -> bool: return n.owner == root).size()])
	var after := root.find_children("*", "", true, true).size()
	print("TEST nœuds : %d → %d" % [before, after])
	# Nuit, puis annulation de la nuit.
	plugin.call("_on_night_toggled", true)
	var env := (root.get_node("WorldEnvironment") as WorldEnvironment).environment
	print("TEST nuit : night %s, fond %s" % [root.get("night"), env.background_color])
	history.undo()
	print("TEST nuit annulée : night %s, fond %s" % [root.get("night"), env.background_color])
	plugin.call("_on_dress_code_selected", &"suit")
	print("TEST tenue : %s" % root.get("dress_code"))
	# Annuler les deux dernières poses (mur, lampadaire), puis rétablir le mur.
	history.undo()
	history.undo()
	history.undo()
	print("TEST après trois annulations : tenue %s, nœuds %d" % [root.get("dress_code"), root.find_children("*", "", true, true).size()])
	history.redo()
	print("TEST lampadaire rétabli : %d lampadaire(s) possédé(s) dans Lamps" % root.get_node("Lamps").get_children().filter(func(n: Node) -> bool: return n.owner == root).size())
	camera.size = 70.0
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var light := DirectionalLight3D.new()
	viewport.add_child(light)
	light.rotation = Vector3(-0.9, 0.5, 0.0)
	camera.look_at_from_position(Vector3(30, 50, 30), Vector3(0, 0, 3))
	for k in 8:
		await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(out + "/editor_step3.png")
	EditorInterface.set_main_screen_editor("3D")
	# Godot 4.7 range le dock dans un EditorDock, onglet du conteneur.
	var tab: Control = dock if dock.get_parent() is TabContainer else dock.get_parent()
	var tabs := tab.get_parent() as TabContainer
	if tabs:
		tabs.current_tab = tabs.get_tab_idx_from_control(tab)
	plugin.call("_on_tool_selected", "wall_line")
	dock.get("_buttons")["wall_line"].button_pressed = true
	plugin.call("_update_status")
	for k in 10:
		await RenderingServer.frame_post_draw
	EditorInterface.get_base_control().get_viewport().get_texture().get_image().save_png(out + "/editor_step3_window.png")
	viewport.queue_free()
	EditorInterface.save_scene()
	for k in 5:
		await tree.process_frame
	print("TEST enregistrée")


static func _click(plugin: EditorPlugin, camera: Camera3D, at: Vector3) -> void:
	var screen := camera.unproject_position(at)
	var motion := InputEventMouseMotion.new()
	motion.position = screen
	plugin._forward_3d_gui_input(camera, motion)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = screen
	plugin._forward_3d_gui_input(camera, press)


static func _key(plugin: EditorPlugin, camera: Camera3D, key: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = true
	plugin._forward_3d_gui_input(camera, event)
