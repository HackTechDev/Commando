@tool
extends RefCounted
## Scénario du point 8.3 a : carte de couverture des gardes. Écrit aussi
## les cases vues par chaque garde posté (`coverage_<carte>.json`), pour la
## comparaison avec les cases calculées dans le jeu lancé.

const Coverage := preload("res://addons/mission_editor/coverage.gd")

static func run(tree: SceneTree, out: String) -> void:
	var plugin = Engine.get_meta(&"mission_editor")
	var root := EditorInterface.get_edited_scene_root()
	var dock: Control = plugin.get("_dock")
	var started := Time.get_ticks_msec()
	dock.get("_coverage").button_pressed = true
	var cells: Dictionary = plugin.call("refresh_coverage")
	print("TEST %s de jour : %d cases vues (%d proches) en %d ms, dessin %s" % [root.name, cells.size(), _near(cells), Time.get_ticks_msec() - started, plugin.get("_coverage")])
	# Cases vues par chaque garde posté, depuis sa place.
	var dump := {}
	var space := (root as Node3D).get_world_3d().direct_space_state
	for guard in root.find_children("*", "", true, true):
		if not guard is Enemy or guard.get("blind") or (guard.get("patrol_path") != null and not str(guard.get("patrol_path")).is_empty()):
			continue
		var seen := {}
		var config: VisionConfig = guard.get_node("VisionComponent").get("config")
		Coverage._look(space, (guard as Node3D).global_transform, config, seen)
		dump[String(guard.name)] = seen.keys().map(func(k: Vector2i) -> Array: return [k.x, k.y, seen[k]])
	var file := FileAccess.open(out + "/coverage_%s.json" % root.scene_file_path.get_file().get_basename(), FileAccess.WRITE)
	file.store_string(JSON.stringify(dump))
	file.close()
	print("TEST gardes postés exportés : %s" % [dump.keys()])
	await _capture(root, out + "/editor_83a_%s_day.png" % root.name.to_lower())
	# Nuit : recalcul automatique après l'action (historique).
	plugin.call("_on_night_toggled", true)
	for k in 3:
		await tree.process_frame
	var night: Dictionary = Coverage.compute(root)
	print("TEST de nuit : %d cases vues (%d proches), cases dessinées %d" % [night.size(), _near(night), (plugin.get("_coverage") as MeshInstance3D).mesh.get_faces().size() / 6])
	await _capture(root, out + "/editor_83a_%s_night.png" % root.name.to_lower())
	plugin.get_undo_redo().get_history_undo_redo(plugin.get_undo_redo().get_object_history_id(root)).undo()
	for k in 3:
		await tree.process_frame
	print("TEST nuit annulée : case du dock %s, cases dessinées %d" % [dock.get("_night").button_pressed, (plugin.get("_coverage") as MeshInstance3D).mesh.get_faces().size() / 6])
	EditorInterface.save_scene()
	for k in 5:
		await tree.process_frame
	var text := FileAccess.get_file_as_string(root.scene_file_path)
	print("TEST enregistrée ; dessin dans le fichier : %s ; dessin toujours affiché : %s" % [text.contains("MissionEditorCoverage"), is_instance_valid(plugin.get("_coverage"))])


static func _near(cells: Dictionary) -> int:
	return cells.values().filter(func(e: Array) -> bool: return e[0] == 2).size()


static func _capture(root: Node, path: String) -> void:
	var holder := SubViewport.new()
	holder.size = Vector2i(1000, 1000)
	holder.world_3d = (root as Node3D).get_world_3d()
	holder.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	EditorInterface.get_base_control().add_child(holder)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 95.0
	holder.add_child(camera)
	camera.look_at_from_position(Vector3(0, 120, 0.01), Vector3.ZERO)
	var light := DirectionalLight3D.new()
	holder.add_child(light)
	light.rotation = Vector3(-1.1, 0.4, 0.0)
	for k in 8:
		await RenderingServer.frame_post_draw
	holder.get_texture().get_image().save_png(path)
	holder.queue_free()
