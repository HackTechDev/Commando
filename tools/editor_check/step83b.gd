@tool
extends RefCounted
## Scénario du point 8.3 b : rondes et trajets animés dans l'éditeur.
## Écrit les positions calculées (`timeline_<carte>.json`) pour la
## comparaison avec le jeu, vérifie lecture, barre de temps, retour au
## début et enregistrement, et capture la carte à 20 s
## (`editor_83b_<carte>.png`).

const Timeline := preload("res://addons/mission_editor/timeline.gd")
const TIMES: Array[float] = [5.0, 10.0, 20.0, 40.0]

static func run(tree: SceneTree, out: String) -> void:
	var plugin = Engine.get_meta(&"mission_editor")
	var root := EditorInterface.get_edited_scene_root()
	var dock: Control = plugin.get("_dock")
	var movers := Timeline.movers(root)
	print("TEST %s : %s" % [root.name, movers.map(func(n: Node) -> String: return "%s (%s)" % [n.name, Timeline.kind(n)])])
	var dump := {}
	for node in movers:
		dump[String(root.get_path_to(node))] = TIMES.map(func(t: float) -> Array:
			var spot := Timeline.pose(node, t).origin
			return [spot.x, spot.y, spot.z])
	var file := FileAccess.open(out + "/timeline_%s.json" % root.scene_file_path.get_file().get_basename(), FileAccess.WRITE)
	file.store_string(JSON.stringify(dump))
	file.close()
	# Lecture une seconde à × 4 : le temps avance d'environ 4 s.
	plugin.set("_time_speed", 4.0)
	dock.get("_play").button_pressed = true
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 1000:
		await tree.process_frame
	print("TEST lecture : en cours %s, temps %.1f s, barre %.1f, silhouettes %d" % [plugin.get("_playing"), plugin.get("_time"), dock.get("_time_slider").value, (plugin.get("_ghosts") as Node).get_child_count()])
	dock.get("_play").button_pressed = false
	# Barre de temps : 20 s.
	dock.get("_time_slider").value = 20.0
	var first: Node3D = movers[0]
	var ghost: Node3D = plugin.get("_ghost_of")[first]
	print("TEST barre à 20 s : %s en %s (calcul %s)" % [first.name, ghost.global_position.snapped(Vector3.ONE * 0.01), Timeline.pose(first, 20.0).origin.snapped(Vector3.ONE * 0.01)])
	await _capture(root, out + "/editor_83b_%s.png" % root.name.to_lower())
	# Une modification (nuit) : silhouettes refaites, cônes réduits.
	plugin.call("_on_night_toggled", not root.get("night"))
	for k in 3:
		await tree.process_frame
	print("TEST après une modification : silhouettes %d, temps %.1f" % [(plugin.get("_ghosts") as Node).get_child_count(), plugin.get("_time")])
	plugin.get_undo_redo().get_history_undo_redo(plugin.get_undo_redo().get_object_history_id(root)).undo()
	EditorInterface.save_scene()
	for k in 5:
		await tree.process_frame
	var text := FileAccess.get_file_as_string(root.scene_file_path)
	print("TEST enregistrée ; silhouettes dans le fichier : %s" % text.contains(Timeline.NAME))
	dock.get("_time_slider").value = 0.0
	plugin.reset_timeline()
	print("TEST retour au début : silhouettes %s, temps %.1f, barre %.1f" % [plugin.get("_ghosts"), plugin.get("_time"), dock.get("_time_slider").value])


static func _capture(root: Node, path: String) -> void:
	var holder := SubViewport.new()
	holder.size = Vector2i(1000, 1000)
	holder.world_3d = (root as Node3D).get_world_3d()
	holder.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	EditorInterface.get_base_control().add_child(holder)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 100.0
	holder.add_child(camera)
	camera.look_at_from_position(Vector3(0, 120, 0.01), Vector3.ZERO)
	var light := DirectionalLight3D.new()
	holder.add_child(light)
	light.rotation = Vector3(-1.1, 0.4, 0.0)
	for k in 8:
		await RenderingServer.frame_post_draw
	holder.get_texture().get_image().save_png(path)
	holder.queue_free()
