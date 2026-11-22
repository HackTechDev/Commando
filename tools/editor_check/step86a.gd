@tool
extends RefCounted
## Scénario du point 8.6 a : relief et bâtiment dessiné, sur le Terrain
## d'essai. Pose un plateau (rampe au sud), dessine un bâtiment de deux
## pièces au rez-de-chaussée et une à l'étage (portes, fenêtres, escalier),
## essaie une porte loin des murs, annule et rétablit, met une extraction
## sur le plateau et une à l'étage, vérifie les chemins, enregistre (pour
## l'essai en jeu) et capture la carte (`editor_86a.png`).


static func run(tree: SceneTree, out: String) -> void:
	var plugin = Engine.get_meta(&"mission_editor")
	var root := EditorInterface.get_edited_scene_root()
	var dock: Control = plugin.get("_dock")
	var terrace: Node3D = plugin.place("terrace", Vector3(-20, 0, -20), 0.0, Vector3(-10, 0, -12))[0]
	for k in 3:
		await tree.process_frame
	print("TEST plateau %s : centre %s, taille %s, hauteur %s, rampes %s" % [terrace.name, terrace.position, terrace.get("size"), terrace.get("height"), terrace.get("ramps")])
	var top := _surface(root, Vector3(-15, 0, -16))
	var ramp := _surface(root, Vector3(-15, 0, -10))
	print("TEST dessus touché à %.2f m ; mi-rampe (z = -10) à %.2f m" % [top, ramp])
	# Bâtiment : deux pièces au rez-de-chaussée, une à l'étage.
	(dock.get("_plan_storey") as SpinBox).value = 0
	var plan: Node3D = plugin.place("plan_room", Vector3(8, 0, -20), 0.0, Vector3(16, 0, -12))[0]
	print("TEST bâtiment %s créé en %s, pièces %s, étages %s" % [plan.name, plan.position, plan.get("rooms"), plan.get("room_storeys")])
	plugin.place("plan_room", Vector3(16, 0, -20), 0.0, Vector3(22, 0, -14))
	plugin.place("plan_door", Vector3(12, 0, -12), 0.0)
	plugin.place("plan_door", Vector3(16, 0, -17), 0.0)
	plugin.place("plan_window", Vector3(8, 0, -16), 0.0)
	plugin.place("plan_stairs", Vector3(10, 0, -13.5), 0.0)
	(dock.get("_plan_storey") as SpinBox).value = 1
	plugin.place("plan_room", Vector3(8, 0, -20), 0.0, Vector3(16, 0, -12))
	plugin.place("plan_window", Vector3(16, 3.2, -16), 0.0)
	var refused: Array = plugin.place("plan_door", Vector3(12, 3.2, -16), 0.0)
	print("TEST porte au milieu d'une pièce : %s (%s)" % ["refusée" if refused.is_empty() else "posée", plugin.get("_status_note")])
	for k in 3:
		await tree.process_frame
	print("TEST pièces %s, étages %s" % [plan.get("rooms"), plan.get("room_storeys")])
	print("TEST ouvertures %s ; volées %s ; niveaux %d, parties %d" % [plan.get("openings"), plan.get("stairs"), plan.get("storeys"), (plan.get("_parts") as Array).size()])
	print("TEST dock : %s" % (dock.get("_plan_label") as Label).text)
	print("TEST étage du point (12, 1, -16) : %d ; (12, 4.2, -16) : %d ; (20, 4.2, -17) (toit) : %d ; dehors : %d" % [plan.storey_of(Vector3(12, 1, -16)), plan.storey_of(Vector3(12, 4.2, -16)), plan.storey_of(Vector3(20, 3.4, -17)), plan.storey_of(Vector3(0, 1, 0))])
	var history: UndoRedo = plugin.get_undo_redo().get_history_undo_redo(plugin.get_undo_redo().get_object_history_id(root))
	history.undo()
	for k in 3:
		await tree.process_frame
	print("TEST annulé : ouvertures %d" % (plan.get("openings") as Array).size())
	history.redo()
	for k in 3:
		await tree.process_frame
	print("TEST rétabli : ouvertures %d, parties %d" % [(plan.get("openings") as Array).size(), (plan.get("_parts") as Array).size()])
	var upstairs := _surface(root, Vector3(13, 0, -16), 5.0)
	print("TEST sol de l'étage touché à %.2f m" % upstairs)
	# Extractions : sur le plateau, à l'étage.
	for spot: Vector3 in [Vector3(-15, top, -17), Vector3(13.5, upstairs, -16), Vector3(19, 0, -17)]:
		var zone: Node3D = plugin.place("extraction", spot, 0.0)[0]
		print("TEST %s en %s" % [zone.name, zone.global_position])
	var report: Array = await plugin.check()
	for item: Dictionary in report:
		print("TEST   [%s] %s" % [item["level"], item["text"]])
	await _capture(root, out + "/editor_86a.png", Vector3(0, 0, -16))
	EditorInterface.save_scene()
	for k in 5:
		await tree.process_frame
	print("TEST enregistrée")


## Hauteur de la première surface sous (x, z), sous `below` m (pour viser
## un étage sous un toit).
static func _surface(root: Node, at: Vector3, below: float = 40.0) -> float:
	var from := Vector3(at.x, below, at.z)
	var query := PhysicsRayQueryParameters3D.create(from, Vector3(at.x, -1, at.z), 0b11)
	var hit := (root as Node3D).get_world_3d().direct_space_state.intersect_ray(query)
	return (hit["position"] as Vector3).y if not hit.is_empty() else -1.0


static func _capture(root: Node, path: String, focus: Vector3) -> void:
	var holder := SubViewport.new()
	holder.size = Vector2i(1200, 900)
	holder.world_3d = (root as Node3D).get_world_3d()
	holder.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	EditorInterface.get_base_control().add_child(holder)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 40.0
	camera.far = 2000.0
	holder.add_child(camera)
	camera.look_at_from_position(focus + Vector3(1.0, 1.4, 1.0).normalized() * 300.0, focus)
	var light := DirectionalLight3D.new()
	holder.add_child(light)
	light.rotation = Vector3(-1.1, 0.4, 0.0)
	for k in 8:
		await RenderingServer.frame_post_draw
	holder.get_texture().get_image().save_png(path)
	holder.queue_free()
