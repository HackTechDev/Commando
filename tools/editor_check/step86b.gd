@tool
extends RefCounted
## Scénario du point 8.6 b : nouvelle mission sur fond de carte UFO:AI
## (`UFO_MAP`, par défaut `office.map`). Crée la mission `ufo_essai`,
## attend la construction de la carte, relève l'équipe, l'extraction, la
## caméra et les gardes posés, ajoute une ronde visée sur la carte,
## vérifie, enregistre (pour l'essai en jeu) et capture la carte
## (`editor_86b.png`).

const Palette := preload("res://addons/mission_editor/palette.gd")


static func run(tree: SceneTree, out: String) -> void:
	var plugin = Engine.get_meta(&"mission_editor")
	var dock: Control = plugin.get("_dock")
	var map_file := OS.get_environment("UFO_MAP") if OS.get_environment("UFO_MAP") != "" else "office.map"
	var listed: Array = dock.call("ufo_maps")
	print("TEST fonds proposés : %d cartes UFO:AI (%s…), %s dedans : %s" % [listed.size(), ", ".join(listed.slice(0, 4)), map_file, listed.has(map_file)])
	var started := Time.get_ticks_msec()
	var path: String = await plugin.new_mission("ufo_essai", {"size": Vector2(80, 80), "ground": "grass", "night": false, "ufo_map": map_file, "guards": true})
	var root := EditorInterface.get_edited_scene_root()
	print("TEST %s créée en %d ms, ouverte %s" % [path, Time.get_ticks_msec() - started, root.scene_file_path])
	var map := root.get_node("NavigationRegion3D/Map")
	print("TEST carte %s construite %s, emprise %s ; sol plat retiré : %s" % [map.get("map_file"), map.get("is_built"), map.get("map_bounds"), not root.has_node("NavigationRegion3D/Ground")])
	print("TEST départs : équipe %d, aliens %d" % [(map.get("player_starts") as Array).size(), (map.get("alien_starts") as Array).size()])
	for unit: Node3D in root.get_node("Units").get_children():
		print("TEST   %s en %s" % [unit.name, unit.global_position.snapped(Vector3.ONE * 0.01)])
	print("TEST extraction en %s ; caméra en %s, limites %s" % [root.get_node("ExtractionZone").global_position.snapped(Vector3.ONE * 0.01), root.get_node("CameraRig").global_position.snapped(Vector3.ONE * 0.01), root.get_node("CameraRig").get("bounds")])
	var guards := root.get_node("Enemies").get_children()
	print("TEST gardes posés : %d (%s…)" % [guards.size(), ", ".join(guards.slice(0, 3).map(func(n: Node3D) -> String: return "%s %s" % [n.name, n.global_position.snapped(Vector3.ONE * 0.1)]))])
	print("TEST terrain pour la palette : %s" % Palette.ground_bounds(root))
	# Une ronde sur la carte, entre l'équipe et l'extraction.
	var team: Vector3 = root.get_node("Units/Alpha").global_position
	var far: Vector3 = root.get_node("ExtractionZone").global_position
	var a := team.lerp(far, 0.4)
	var b := team.lerp(far, 0.6)
	var patrol: Array = plugin.place("patrol", a, 0.0, Vector3.INF, PackedVector3Array([a, b]))
	print("TEST ronde %s posée" % patrol[1].name)
	var report: Array = await plugin.check()
	for item: Dictionary in report:
		print("TEST   [%s] %s" % [item["level"], item["text"]])
	EditorInterface.save_scene()
	for k in 5:
		await tree.process_frame
	var text := FileAccess.get_file_as_string(root.scene_file_path)
	var start := text.find("[node name=\"Map\"")
	print("TEST enregistrée (%d octets, %d nœuds) :\nTEST   %s" % [text.length(), text.count("[node "), text.substr(start, 160).replace("\n", "\nTEST   ")])
	await _capture(root, out + "/editor_86b.png", far.lerp(team, 0.5))


static func _capture(root: Node, path: String, focus: Vector3) -> void:
	var holder := SubViewport.new()
	holder.size = Vector2i(1200, 900)
	holder.world_3d = (root as Node3D).get_world_3d()
	holder.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	EditorInterface.get_base_control().add_child(holder)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 70.0
	camera.far = 2000.0
	camera.cull_mask = 0xFFFFFFFF
	holder.add_child(camera)
	camera.look_at_from_position(focus + Vector3(1.0, 1.4, 1.0).normalized() * 400.0, focus)
	var light := DirectionalLight3D.new()
	holder.add_child(light)
	light.rotation = Vector3(-1.1, 0.4, 0.0)
	for k in 8:
		await RenderingServer.frame_post_draw
	holder.get_texture().get_image().save_png(path)
	holder.queue_free()
