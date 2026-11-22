@tool
extends RefCounted
## Scénario de l'étape 5 : « Vérifier » sur la mission ouverte, erreurs
## volontaires, « Nouvelle mission », catalogue, « Essayer ».
## Lancé sur une seule scène : il ouvre ensuite la mission qu'il crée.

const NEW := "essai_editeur"

static func run(tree: SceneTree, out: String) -> void:
	var plugin = Engine.get_meta(&"mission_editor")
	var root := EditorInterface.get_edited_scene_root()
	var started := Time.get_ticks_msec()
	var report: Array = await plugin.check()
	print("TEST vérification de %s en %d ms :" % [root.name, Time.get_ticks_msec() - started])
	_print(report)
	if root.name != "Sandbox":
		return
	# Erreurs volontaires : ronde sans chemin, objectif sans cible.
	var guard := root.get_node("Enemies/Soldier1")
	var path: Variant = guard.get("patrol_path")
	guard.set("patrol_path", NodePath("../../PatrolPaths/Absent"))
	var info: MissionInfo = plugin.get("_info")
	info.objectives.append(MissionObjective.make("depot", "Incendier le dépôt"))
	print("TEST avec erreurs :")
	_print(await plugin.check())
	guard.set("patrol_path", path)
	info.objectives.resize(info.objectives.size() - 1)
	# Nouvelle mission : refus d'un nom invalide, puis création.
	print("TEST nom invalide : « %s »" % plugin.call("new_mission", "Essai Éditeur"))
	var created: String = plugin.call("new_mission", NEW)
	for k in 20:
		await tree.process_frame
	root = EditorInterface.get_edited_scene_root()
	print("TEST nouvelle mission : %s, scène ouverte %s (%s)" % [created, root.scene_file_path, root.name])
	print("TEST déjà existante : « %s »" % plugin.call("new_mission", NEW))
	var titles := LevelCatalog.levels().map(func(e: Dictionary) -> String: return e["title"])
	print("TEST catalogue : %d missions, dernière « %s », nouvelle présente %s" % [titles.size(), titles[-1], "Essai Editeur" in titles])
	_print(await plugin.check())
	# Un garde en ronde et un porteur de documents, puis vérification.
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 80.0
	var holder := SubViewport.new()
	holder.size = Vector2i(1000, 1000)
	holder.world_3d = root.get_world_3d()
	EditorInterface.get_base_control().add_child(holder)
	holder.add_child(camera)
	camera.look_at_from_position(Vector3(0, 80, 0.01), Vector3.ZERO)
	for step: Array in [["patrol", [Vector3(-10, 0, 0), Vector3(10, 0, 0)]], ["documents", [Vector3(15, 0, -15)]], ["wall_line", [Vector3(-20, 0, 10), Vector3(20, 0, 10)]]]:
		plugin.call("_on_tool_selected", step[0])
		for point: Vector3 in step[1]:
			var press := InputEventMouseButton.new()
			press.button_index = MOUSE_BUTTON_LEFT
			press.pressed = true
			press.position = camera.unproject_position(point)
			plugin._forward_3d_gui_input(camera, press)
	plugin.call("_cancel_tool")
	holder.queue_free()
	var mission := plugin.get("_info") as MissionInfo
	mission.objectives.append(MissionObjective.make("documents", "Récupérer les documents"))
	print("TEST après poses :")
	_print(await plugin.check())
	# Dock affiché, avec le résultat.
	EditorInterface.set_main_screen_editor("3D")
	var dock: Control = plugin.get("_dock")
	var tab: Control = dock if dock.get_parent() is TabContainer else dock.get_parent()
	var tabs := tab.get_parent() as TabContainer
	if tabs:
		tabs.current_tab = tabs.get_tab_idx_from_control(tab)
	for k in 10:
		await RenderingServer.frame_post_draw
	EditorInterface.get_base_control().get_viewport().get_texture().get_image().save_png(out + "/editor_step5_window.png")
	# Essayer : enregistre et lance le jeu.
	plugin.call("_on_play_requested")
	for k in 600:
		await tree.process_frame
		if EditorInterface.is_playing_scene():
			break
	print("TEST essai lancé : %s (%s)" % [EditorInterface.is_playing_scene(), EditorInterface.get_playing_scene()])
	await tree.create_timer(12.0).timeout
	print("TEST jeu toujours en cours après 12 s : %s" % EditorInterface.is_playing_scene())
	EditorInterface.stop_playing_scene()
	var saved := load(MissionInfo.path_for(created)) as MissionInfo
	print("TEST mission.tres enregistré : %d objectifs, ordre %d" % [saved.objectives.size(), saved.order])


static func _print(report: Array) -> void:
	for item: Dictionary in report:
		print("TEST   [%s] %s" % [item["level"], item["text"]])
