@tool
extends RefCounted
## Scénario du point 8.4 d : événements scriptés et zones de déclenchement.
## Sur une carte qui a déjà des renforts (Front, Convoi), liste les fiches du
## dock et les remarques de la vérification. Sur le Terrain d'essai, pose un
## pick-up qui arrive et des renforts, trace leurs zones, règle les fiches
## du dock, redimensionne une zone à la poignée, vérifie, enregistre (pour
## l'essai en jeu) et capture la carte (`editor_84d_<carte>.png`).

const Events := preload("res://addons/mission_editor/events.gd")
const Gizmos := preload("res://addons/mission_editor/gizmos.gd")


static func run(tree: SceneTree, out: String) -> void:
	var plugin = Engine.get_meta(&"mission_editor")
	var root := EditorInterface.get_edited_scene_root()
	var dock: Control = plugin.get("_dock")
	if root.name != "Sandbox":
		_list(root, dock)
		await _report(plugin)
		return
	var arrival: Node3D = plugin.place("arrival", Vector3(30, 0, -30), 225.0)[0]
	var zone: Node3D = plugin.place("trigger_zone", Vector3(4, 0, 6), 0.0, Vector3(12, 0, 0))[0]
	print("TEST pick-up %s ; zone %s : taille %s, centre %s, event %s → %s" % [arrival.name, zone.name, zone.get("size"), zone.position, zone.get("event"), Events.event_of(zone)])
	# Renforts, puis une zone tracée depuis leur fiche.
	var raid: Node3D = plugin.place("reinforcements", Vector3(-30, 0, -30), 135.0)[0]
	plugin.draw_zone_for(raid)
	print("TEST outil après « Tracer une zone » : %s, événement visé %s" % [plugin.get("_tool"), plugin.zone_event(root).name])
	var zone2: Node3D = plugin.place("trigger_zone", Vector3(-12, 0, -6), 0.0, Vector3(-4, 0, -14))[0]
	plugin.call("_cancel_tool")
	print("TEST zone %s → %s" % [zone2.name, Events.event_of(zone2).name])
	for k in 3:
		await tree.process_frame
	# Fiche du dock : délai et nombre de soldats.
	var rows: Dictionary = dock.get("_event_rows")
	var card: Dictionary = rows[raid]
	(card["delay"] as SpinBox).value = 15.0
	(card["count"] as SpinBox).value = 3.0
	(card["objective"] as OptionButton).select(0)
	(card["objective"] as OptionButton).item_selected.emit(0)
	for k in 3:
		await tree.process_frame
	print("TEST fiche réglée : délai %s, soldats %s, objectif « %s », annoncé %s" % [raid.get("delay"), raid.get("count"), raid.get("start_objective"), raid.get("announce")])
	_list(root, dock)
	# Poignée : coin sud-est tiré de 4 m vers l'est (coin opposé fixe).
	var moved := Gizmos.moved_zone(zone, 2, zone.global_transform * Vector3(8, 0, 4))
	plugin.get("_gizmos").set_zone(zone, moved[0], moved[1], zone.get("size"), zone.global_position)
	print("TEST coin tiré : taille %s, centre %s" % [zone.get("size"), zone.global_position])
	var history: UndoRedo = plugin.get_undo_redo().get_history_undo_redo(plugin.get_undo_redo().get_object_history_id(root))
	history.undo()
	print("TEST annulé : taille %s, centre %s" % [zone.get("size"), zone.global_position])
	history.redo()
	# Une zone orpheline : erreur dans le rapport.
	var orphan: Node3D = plugin.place("trigger_zone", Vector3(30, 0, 20), 0.0, Vector3(34, 0, 24))[0]
	orphan.set("event", NodePath(""))
	await _report(plugin)
	history.undo()
	# Arrivées au coin du terrain : hors du sol. Rapprochées du centre.
	arrival.position = Vector3(22, 0, -22)
	raid.position = Vector3(-22, 0, -22)
	print("TEST rapprochés du centre :")
	await _report(plugin)
	await _capture(root, out + "/editor_84d_%s.png" % root.name.to_lower())
	EditorInterface.save_scene()
	for k in 5:
		await tree.process_frame
	var text := FileAccess.get_file_as_string(root.scene_file_path)
	var start := text.find("[node name=\"TriggerZone\"")
	print("TEST enregistrée :\n%s" % text.substr(start, 420).replace("\n", "\nTEST   "))


static func _list(root: Node, dock: Control) -> void:
	var rows: Dictionary = dock.get("_event_rows")
	for event: Node in rows:
		print("TEST fiche %s : %s" % [event.name, (rows[event]["summary"] as Label).text])


static func _report(plugin: Variant) -> void:
	var report: Array = await plugin.check()
	for item: Dictionary in report:
		var text: String = item["text"]
		if text.contains("Renforts") or text.contains("Reinforcements") or text.contains("TriggerZone") or text.contains("ArrivingTechnical") or text.contains("déclench") or text.contains("Aucun problème"):
			print("TEST   [%s] %s" % [item["level"], text])


static func _capture(root: Node, path: String) -> void:
	var holder := SubViewport.new()
	holder.size = Vector2i(1000, 1000)
	holder.world_3d = (root as Node3D).get_world_3d()
	holder.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	EditorInterface.get_base_control().add_child(holder)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 90.0
	# Repères de l'éditeur (couches hautes) compris.
	camera.cull_mask = 0xFFFFFFFF
	holder.add_child(camera)
	camera.look_at_from_position(Vector3(0, 120, 0.01), Vector3.ZERO)
	var light := DirectionalLight3D.new()
	holder.add_child(light)
	light.rotation = Vector3(-1.1, 0.4, 0.0)
	for k in 8:
		await RenderingServer.frame_post_draw
	holder.get_texture().get_image().save_png(path)
	holder.queue_free()
