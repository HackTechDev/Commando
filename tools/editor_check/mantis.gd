@tool
extends RefCounted
## Scénario du Mantis dans la palette : pose les versions rampe abaissée et
## relevée, vérifie qu'elles sont construites mais que seul le nœud est
## enregistré, pose un garde dans la soute (visée en hauteur) et un Sabre
## dans la soute fermée (remarque de la vérification), annule, et
## photographie la carte (`editor_mantis.png`).

const Palette := preload("res://addons/mission_editor/palette.gd")


static func run(tree: SceneTree, out: String) -> void:
	var plugin = Engine.get_meta(&"mission_editor")
	var root := EditorInterface.get_edited_scene_root()
	for id: String in ["mantis", "mantis_closed"]:
		var entry := Palette.find(id)
		print("TEST entrée %s : « %s », %s, sous %s" % [id, entry.get("label"), entry.get("category"), entry.get("parent")])
	var open: Node3D = plugin.place("mantis", Vector3(-20, 0, -30), 0.0)[0]
	var closed: Node3D = plugin.place("mantis_closed", Vector3(20, 0, 30), 90.0)[0]
	for k in 10:
		await tree.process_frame
	for ship: Node3D in [open, closed]:
		var built := ship.get_children().filter(func(n: Node) -> bool: return n.owner == null).size()
		print("TEST %s : parent %s, rampe %s, cap %.0f°, %d pièces construites, rampe construite %s" % [ship.name, ship.get_parent().name, ship.get("ramp_open"), rad_to_deg(ship.rotation.y), built, ship.has_node("Ramp")])
	var packed := PackedScene.new()
	packed.pack(root)
	var state := packed.get_state()
	var saved := 0
	for i in state.get_node_count():
		if String(state.get_node_path(i)).contains("Mantis"):
			saved += 1
	print("TEST nœuds enregistrés pour les Mantis : %d (attendu 2)" % saved)
	# Garde posé dans la soute ouverte, visé comme par le greffon (caméra au
	# dessus du toit) : la visée traverse le toit jusqu'au plancher.
	var eye := Camera3D.new()
	root.add_child(eye)
	var top := open.to_global(Vector3(4, 0, 2))
	eye.look_at_from_position(top + Vector3(30, 40, 30), top)
	var spot := Palette.surface_point(eye, eye.unproject_position(top + Vector3.UP * Mantis.FLOOR_TOP), 0.0, (root as Node3D).get_world_3d())
	eye.queue_free()
	print("TEST visée sur la soute : %s" % spot.snapped(Vector3.ONE * 0.01))
	var guard: Node3D = plugin.place("guard", spot, 0.0)[0]
	print("TEST garde dans la soute en %s (hauteur attendue %.1f)" % [guard.global_position.snapped(Vector3.ONE * 0.01), Mantis.FLOOR_TOP])
	var sabre: Node3D = plugin.place("sabre", closed.to_global(Vector3(0, Mantis.FLOOR_TOP, 0)), 90.0)[0]
	var report: Array = await plugin.check()
	print("TEST vérification : %d remarques" % report.size())
	for line in report:
		if String(line["text"]).contains("Mantis") or String(line["text"]).contains("soute"):
			print("TEST   %s" % [line["text"]])
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1200, 900)
	viewport.world_3d = (root as Node3D).get_world_3d()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	EditorInterface.get_base_control().add_child(viewport)
	var light := DirectionalLight3D.new()
	viewport.add_child(light)
	light.rotation = Vector3(-0.9, 0.5, 0.0)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 110.0
	camera.far = 2000.0
	viewport.add_child(camera)
	camera.look_at_from_position(Vector3(1.0, 1.4, 1.0).normalized() * 400.0, Vector3.ZERO)
	camera.current = true
	for k in 8:
		await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("%s/editor_mantis.png" % out)
	viewport.queue_free()
	var undo := plugin.get_undo_redo() as EditorUndoRedoManager
	for k in 4:
		undo.get_history_undo_redo(undo.get_object_history_id(root)).undo()
	print("TEST après annulation : Mantis présents %s, garde %s, Sabre %s" % [is_instance_valid(open) and open.is_inside_tree(), guard.is_inside_tree(), sabre.is_inside_tree()])
