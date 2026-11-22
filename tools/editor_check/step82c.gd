@tool
extends RefCounted
## Scénario du point 8.2 c : vérification à chaque enregistrement, résumée
## sous le titre du dock (capture `editor_82c_dock.png`).

static func run(tree: SceneTree, out: String) -> void:
	var plugin = Engine.get_meta(&"mission_editor")
	var root := EditorInterface.get_edited_scene_root()
	var dock: Control = plugin.get("_dock")
	var summary: Button = dock.get("_summary")
	print("TEST à l'ouverture : résumé visible %s" % summary.visible)
	EditorInterface.save_scene()
	await _settled(tree, plugin)
	print("TEST après Ctrl+S : %s" % summary.text)
	# Une faute, puis enregistrement.
	plugin.place("wall", Vector3(20, 0, -20), 0.0)
	plugin.place("guard", Vector3(20, 0, -20), 0.0)
	EditorInterface.save_scene()
	await _settled(tree, plugin)
	print("TEST faute enregistrée : %s" % summary.text)
	print("TEST rapport : %s" % (dock.get("_report_box") as Node).get_children().map(func(n: Button) -> String: return n.text))
	# Deux enregistrements dans la même image : le second attend la fin du
	# premier, puis tourne à son tour.
	plugin.call("_check_after_save")
	print("TEST premier lancé : en cours %s" % plugin.get("_checking"))
	plugin.call("_check_after_save")
	print("TEST second : en attente « %s »" % plugin.get("_check_again"))
	for k in 600:
		if String(plugin.get("_check_again")).is_empty():
			break
		await tree.process_frame
	print("TEST second lancé à la fin du premier : en cours %s, attente « %s »" % [plugin.get("_checking"), plugin.get("_check_again")])
	await _settled(tree, plugin)
	print("TEST après les deux : %s" % summary.text)
	# Case décochée : plus de vérification à l'enregistrement.
	dock.get("_on_save").button_pressed = false
	plugin.place("guard", Vector3(20.2, 0, -20), 0.0)
	var before := summary.text
	EditorInterface.save_scene()
	for k in 30:
		await tree.process_frame
	print("TEST case décochée : vérification lancée %s, résumé inchangé %s" % [plugin.get("_checking"), summary.text == before])
	dock.get("_on_save").button_pressed = true
	# Capture du haut du dock.
	var tab: Control = dock if dock.get_parent() is TabContainer else dock.get_parent()
	var tabs := tab.get_parent() as TabContainer
	if tabs:
		tabs.current_tab = tabs.get_tab_idx_from_control(tab)
	for k in 10:
		await RenderingServer.frame_post_draw
	var area := dock.get_global_rect()
	EditorInterface.get_base_control().get_viewport().get_texture().get_image().get_region(
		Rect2i(Vector2i(area.position) - Vector2i(10, 10), Vector2i(area.size.x + 20, 330))).save_png(out + "/editor_82c_dock.png")
	# Autre scène ouverte : le résumé disparaît.
	EditorInterface.open_scene_from_path("res://scenes/levels/night/night.tscn")
	for k in 10:
		await tree.process_frame
	print("TEST autre scène (%s) : résumé visible %s" % [EditorInterface.get_edited_scene_root().name, summary.visible])


## Attend la fin des vérifications lancées par l'enregistrement.
static func _settled(tree: SceneTree, plugin: Object) -> void:
	for k in 5:
		await tree.process_frame
	for k in 600:
		if not plugin.get("_checking") and String(plugin.get("_check_again")).is_empty():
			break
		await tree.process_frame
