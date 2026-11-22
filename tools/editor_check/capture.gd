@tool
extends EditorPlugin
## Ouvre chaque scène de CAPTURE_SCENES (séparées par des virgules) dans
## l'éditeur, la photographie vue de dessus en biais (OUT/editor_<nom>.png),
## puis quitte. Sert à vérifier ce que l'éditeur affiche.

func _enter_tree() -> void:
	var scenes := OS.get_environment("CAPTURE_SCENES")
	if scenes.is_empty():
		return
	_run.call_deferred(scenes.split(","))


func _run(scenes: PackedStringArray) -> void:
	var out := OS.get_environment("OUT")
	var size := float(OS.get_environment("CAPTURE_SIZE")) if OS.get_environment("CAPTURE_SIZE") != "" else 0.0
	var tree := get_tree()
	# L'éditeur ne redessine que sur changement : la capture attendrait
	# indéfiniment une image.
	OS.low_processor_usage_mode = false
	for i in 30:
		await tree.process_frame
	for scene in scenes:
		print("CAPTURE ouverture ", scene)
		EditorInterface.open_scene_from_path(scene)
		print("CAPTURE ouverte ", scene)
		for i in 60:
			await tree.process_frame
		var root := EditorInterface.get_edited_scene_root() as Node3D
		# Cartes UFO:AI : construites sur plusieurs images.
		var since := Time.get_ticks_msec()
		while root and Time.get_ticks_msec() - since < 90000 and root.find_children("*", "UfoMapLevel", true, false).any(func(n: Node) -> bool: return not n.get("is_built")):
			await tree.process_frame
		print("CAPTURE attente %.1f s" % ((Time.get_ticks_msec() - since) / 1000.0))
		if root == null:
			print("CAPTURE pas de racine 3D : ", scene)
			continue
		var bounds := _bounds(root)
		print("CAPTURE %s : %d nœuds, étendue %s" % [scene, _count(root), bounds.size])
		var viewport := SubViewport.new()
		viewport.size = Vector2i(1200, 900)
		viewport.world_3d = root.get_world_3d()
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		EditorInterface.get_base_control().add_child(viewport)
		var light := DirectionalLight3D.new()
		viewport.add_child(light)
		light.rotation = Vector3(-0.9, 0.5, 0.0)
		var camera := Camera3D.new()
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		var center := bounds.get_center()
		var extent := maxf(bounds.size.x, bounds.size.z)
		camera.size = size if size > 0.0 else extent * 0.8
		camera.far = 2000.0
		viewport.add_child(camera)
		var focus := Vector3(center.x, 0.0, center.z)
		var focus_env := OS.get_environment("CAPTURE_FOCUS")
		if focus_env != "":
			var parts := focus_env.split(" ")
			focus = Vector3(float(parts[0]), 0.0, float(parts[1]))
		camera.look_at_from_position(focus + Vector3(1.0, 1.4, 1.0).normalized() * 400.0, focus)
		camera.current = true
		for k in 8:
			await RenderingServer.frame_post_draw
		var name := scene.get_file().get_basename()
		viewport.get_texture().get_image().save_png("%s/editor_%s.png" % [out, name])
		viewport.queue_free()
		var test := OS.get_environment("CAPTURE_TEST")
		if test != "":
			await load("res://addons/capture/%s.gd" % test).run(tree, out)
		if OS.get_environment("CAPTURE_SAVE") == "1":
			EditorInterface.save_scene()
			for k in 5:
				await tree.process_frame
			print("CAPTURE enregistrée : ", scene)
	print("CAPTURE terminé")
	EditorInterface.get_base_control().get_tree().quit()


func _count(node: Node) -> int:
	var total := 1
	for child in node.get_children():
		total += _count(child)
	return total


func _bounds(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for node in root.find_children("*", "VisualInstance3D", true, false):
		var visual := node as VisualInstance3D
		if not visual.is_visible_in_tree():
			continue
		var b := visual.global_transform * visual.get_aabb()
		if b.size.length() > 500.0:
			continue
		box = b if first else box.merge(b)
		first = false
	return box
