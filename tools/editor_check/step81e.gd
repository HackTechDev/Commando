@tool
extends RefCounted
## Scénario du point 8.1 e : taille du terrain, sol et jour ou nuit choisis
## à la création d'une mission.

static func run(tree: SceneTree, out: String) -> void:
	var plugin = Engine.get_meta(&"mission_editor")
	var dock: Control = plugin.get("_dock")
	var template := FileAccess.get_file_as_string(plugin.TEMPLATE)
	# Réglages par défaut : même scène qu'avant (gabarit, racine renommée).
	var lines := Array(template.split("\n")).filter(func(line: String) -> bool: return not line.begins_with("metadata/generat"))
	var before := "\n".join(lines).replace('[node name="Mission" type="Node3D"]', '[node name="Essai" type="Node3D"]')
	print("TEST réglages du dock : %s" % dock.call("new_mission_options"))
	print("TEST défaut identique à l'ancien texte : %s" % (plugin.mission_text(template, "Essai", dock.call("new_mission_options")) == before))
	var path: String = plugin.new_mission("essai_terrain", {"size": Vector2(120, 60), "ground": "sand", "night": true})
	for k in 10:
		await tree.process_frame
	var root := EditorInterface.get_edited_scene_root()
	var ground := root.get_node("NavigationRegion3D/Ground")
	var mesh := (ground.get_node("MeshInstance3D") as MeshInstance3D).mesh as BoxMesh
	var shape := (ground.get_node("CollisionShape3D") as CollisionShape3D).shape as BoxShape3D
	print("TEST %s : racine %s, nuit %s, sol %s / %s, couleur %s" % [path, root.name, root.get("night"), mesh.size, shape.size, (mesh.material as StandardMaterial3D).albedo_color])
	print("TEST Alpha %s, extraction %s, caméra %s, limites %s" % [root.get_node("Units/Alpha").position, root.get_node("ExtractionZone").position, root.get_node("CameraRig").position, root.get_node("CameraRig").get("bounds")])
	var env := (root.get_node("WorldEnvironment") as WorldEnvironment).environment
	print("TEST fond %s, ambiance %s × %s, soleil %s × %s" % [env.background_color, env.ambient_light_color, env.ambient_light_energy, root.get_node("Sun").light_color, root.get_node("Sun").light_energy])
	print("TEST dock : case Nuit %s" % dock.get("_night").button_pressed)
	for item: Dictionary in await plugin.check():
		print("TEST   [%s] %s" % [item["level"], item["text"]])
	var holder := SubViewport.new()
	holder.size = Vector2i(1200, 700)
	holder.world_3d = root.get_world_3d()
	holder.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	EditorInterface.get_base_control().add_child(holder)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 75.0
	camera.cull_mask = 0xFFFFFFFF
	holder.add_child(camera)
	camera.look_at_from_position(Vector3(0, 100, 0.01), Vector3.ZERO)
	for k in 8:
		await RenderingServer.frame_post_draw
	holder.get_texture().get_image().save_png(out + "/editor_81e.png")
	holder.queue_free()
	# Dock : ligne des réglages du terrain.
	var tab: Control = dock if dock.get_parent() is TabContainer else dock.get_parent()
	var tabs := tab.get_parent() as TabContainer
	if tabs:
		tabs.current_tab = tabs.get_tab_idx_from_control(tab)
	for k in 10:
		await RenderingServer.frame_post_draw
	var window := EditorInterface.get_base_control().get_viewport().get_texture().get_image()
	var area := dock.get_global_rect()
	window.get_region(Rect2i(Vector2i(area.position) - Vector2i(10, 10), Vector2i(area.size.x + 20, 260))).save_png(out + "/editor_81e_dock.png")
	print("TEST largeur du dock %d" % area.size.x)
