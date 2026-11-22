@tool
extends RefCounted
## Scénario du point 8.4 c : objectifs modifiés dans le dock. Sur la mission
## ouverte : texte modifié, identifiant changé (texte proposé qui suit),
## ordre, ajout, retrait, annulation et rétablissement, enregistrement de
## `mission.tres` avec la scène, journal du jeu relu dans le catalogue, et
## capture du dock (`editor_84c_dock.png`).


static func run(tree: SceneTree, out: String) -> void:
	var plugin = Engine.get_meta(&"mission_editor")
	var root := EditorInterface.get_edited_scene_root()
	var dock: Control = plugin.get("_dock")
	var info: MissionInfo = plugin.get("_info")
	print("TEST départ : %s" % _list(info))
	var rows: Array = dock.get("_objective_rows")
	print("TEST lignes du dock : %d, états %s" % [rows.size(), rows.map(func(r: Dictionary) -> String: return (r["mark"] as Button).text)])
	# Texte de la 3e ligne, validé par Entrée.
	var text: LineEdit = rows[2]["text"]
	text.text = "Ne perdre personne"
	text.text_submitted.emit(text.text)
	await _frames(tree)
	print("TEST texte modifié : %s" % _list(info))
	# Ligne 3 → no_alert : le texte n'était plus celui proposé, il reste.
	rows = dock.get("_objective_rows")
	var choice: OptionButton = rows[2]["choice"]
	choice.select(MissionObjective.KNOWN_IDS.find("no_alert"))
	choice.item_selected.emit(MissionObjective.KNOWN_IDS.find("no_alert"))
	await _frames(tree)
	print("TEST identifiant changé : %s" % _list(info))
	# Ajout de « sabotage » : texte proposé, cible absente (⚠).
	var add: OptionButton
	for child in (dock.get("_info_box") as Node).get_children():
		if child is OptionButton and (child as OptionButton).get_item_text(0).begins_with("+"):
			add = child
	var item := -1
	for i in add.item_count:
		if add.get_item_text(i) == "sabotage":
			item = i
	add.item_selected.emit(item)
	await _frames(tree)
	rows = dock.get("_objective_rows")
	print("TEST ajouté : %s ; états %s" % [_list(info), rows.map(func(r: Dictionary) -> String: return (r["mark"] as Button).text)])
	# Le nouvel objectif → premier (trois fois ↑ : boutons de sa ligne).
	for k in 3:
		rows = dock.get("_objective_rows")
		var last: HBoxContainer = (rows[rows.size() - 1 - k]["mark"] as Button).get_parent()
		(last.get_child(2) as Button).pressed.emit()
		await _frames(tree)
	print("TEST remonté en tête : %s" % _list(info))
	# Retrait du dernier.
	rows = dock.get("_objective_rows")
	((rows[rows.size() - 1]["mark"] as Button).get_parent().get_child(4) as Button).pressed.emit()
	await _frames(tree)
	print("TEST retiré : %s" % _list(info))
	var history: UndoRedo = plugin.get_undo_redo().get_history_undo_redo(plugin.get_undo_redo().get_object_history_id(root))
	history.undo()
	await _frames(tree)
	print("TEST annulé (Ctrl+Z de la scène) : %s ; lignes %d" % [_list(info), (dock.get("_objective_rows") as Array).size()])
	history.redo()
	await _frames(tree)
	print("TEST rétabli : %s" % _list(info))
	await _capture_dock(dock, out + "/editor_84c_dock.png")
	EditorInterface.save_scene()
	for k in 5:
		await tree.process_frame
	var saved := load(MissionInfo.path_for(root.scene_file_path)) as MissionInfo
	var text_file := FileAccess.get_file_as_string(MissionInfo.path_for(root.scene_file_path))
	print("TEST mission.tres enregistré : %s" % ", ".join(Array(text_file.split("\n")).filter(func(l: String) -> bool: return l.begins_with("id = ")).map(func(l: String) -> String: return l.trim_prefix("id = "))))
	LevelCatalog.reload()
	var entry := LevelCatalog.find(root.scene_file_path)
	print("TEST catalogue du jeu (%s) : %s" % [entry.get("title", "introuvable"), (entry.get("objectives", []) as Array).map(func(o: Dictionary) -> String: return "%s « %s »" % [o["id"], o["text"]])])


static func _list(info: MissionInfo) -> String:
	return ", ".join(info.objectives.map(func(o: MissionObjective) -> String: return "%s « %s »" % [o.id, o.text]))


static func _frames(tree: SceneTree) -> void:
	for k in 3:
		await tree.process_frame


static func _capture_dock(dock: Control, path: String) -> void:
	# Onglet « Mission » au premier plan.
	var child: Node = dock
	while child.get_parent() and not child.get_parent() is TabContainer:
		child = child.get_parent()
	var tabs := child.get_parent() as TabContainer
	if tabs:
		tabs.current_tab = child.get_index()
	print("TEST onglet : %s" % [tabs.get_tab_title(tabs.current_tab) if tabs else "pas d'onglets"])
	var scroll: ScrollContainer = dock.get("_scroll")
	scroll.scroll_vertical = 0
	for k in 4:
		await RenderingServer.frame_post_draw
	var image := dock.get_viewport().get_texture().get_image()
	var area := Rect2i(dock.get_global_rect())
	image.get_region(area.intersection(Rect2i(Vector2i.ZERO, image.get_size()))).save_png(path)
