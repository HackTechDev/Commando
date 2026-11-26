@tool
extends RefCounted
## Scénario du centre de commandement dans la palette : pose les versions
## repliée et déployée, vérifie qu'elles sont construites mais que seul le
## nœud est enregistré (pas les pièces construites), pose un garde sur le
## pont déployé (visée en hauteur), annule, et photographie la carte
## (`editor_command_center.png`).

const Palette := preload("res://addons/mission_editor/palette.gd")


static func run(tree: SceneTree, out: String) -> void:
	var plugin = Engine.get_meta(&"mission_editor")
	var root := EditorInterface.get_edited_scene_root()
	var ids := ["command_center", "command_center_deployed"]
	for id: String in ids:
		var entry := Palette.find(id)
		print("TEST entrée %s : « %s », %s, sous %s" % [id, entry.get("label"), entry.get("category"), entry.get("parent")])
	var closed: Node3D = plugin.place("command_center", Vector3(-25, 0, -25), 0.0)[0]
	var deployed: Node3D = plugin.place("command_center_deployed", Vector3(20, 0, 15), 90.0)[0]
	for k in 10:
		await tree.process_frame
	for center: Node3D in [closed, deployed]:
		var built := center.get_children().filter(func(n: Node) -> bool: return n.owner == null).size()
		print("TEST %s : parent %s, déployé %s, cap %.0f°, %d pièces construites, salle %s" % [center.name, center.get_parent().name, center.get("deployed"), rad_to_deg(center.rotation.y), built, center.get("ops_room") != null])
	# Ce qui serait enregistré : le nœud seul.
	var packed := PackedScene.new()
	packed.pack(root)
	var state := packed.get_state()
	var saved := 0
	for i in state.get_node_count():
		var path := String(state.get_node_path(i))
		if path.contains("CommandCenter"):
			saved += 1
	print("TEST nœuds enregistrés pour les centres : %d (attendu 2)" % saved)
	# Garde posé sur le pont : rayon vertical, comme la visée du greffon.
	var space: PhysicsDirectSpaceState3D = (root as Node3D).get_world_3d().direct_space_state
	var top := deployed.to_global(Vector3(5, 0, 6))
	var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(top + Vector3.UP * 50.0, top - Vector3.UP * 5.0, Palette.SURFACE_MASK))
	var spot: Vector3 = hit.get("position", Vector3.INF)
	var guard: Node3D = plugin.place("guard", spot, 0.0)[0]
	print("TEST garde posé sur le pont en %s (hauteur attendue %.1f)" % [guard.global_position.snapped(Vector3.ONE * 0.01), CommandCenter.DECK_TOP])
	var report: Array = await plugin.check()
	print("TEST vérification : %d remarques" % report.size())
	for line in report.slice(0, 6):
		print("TEST   %s" % [line])
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
	camera.size = 90.0
	camera.far = 2000.0
	viewport.add_child(camera)
	camera.look_at_from_position(Vector3(1.0, 1.4, 1.0).normalized() * 400.0, Vector3.ZERO)
	camera.current = true
	for k in 8:
		await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("%s/editor_command_center.png" % out)
	viewport.queue_free()
	# Annulation : les trois poses disparaissent.
	var undo := plugin.get_undo_redo() as EditorUndoRedoManager
	for k in 3:
		undo.get_history_undo_redo(undo.get_object_history_id(root)).undo()
	print("TEST après annulation : centres présents %s, garde présent %s" % [is_instance_valid(closed) and closed.is_inside_tree(), guard.is_inside_tree()])
