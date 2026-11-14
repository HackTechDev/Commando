extends GutTest
## Menu de démarrage : liste des niveaux, lancement, retour au menu.

var _saved_maps_env := ""


func before_each() -> void:
	_saved_maps_env = OS.get_environment("COMMANDO_MAPS")


func after_each() -> void:
	OS.set_environment("COMMANDO_MAPS", _saved_maps_env)
	get_tree().paused = false
	var scene := get_tree().current_scene
	if is_instance_valid(scene):
		get_tree().root.remove_child(scene)
		scene.free()


func _open_menu() -> MainMenu:
	var menu := (load(LevelCatalog.MENU_SCENE) as PackedScene).instantiate() as MainMenu
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
	await wait_process_frames(2)
	return menu


func _play_buttons(menu: Node) -> Array:
	return menu.find_children("*", "Button", true, false).filter(func(b: Button) -> bool: return b.text == "Jouer")


## Attend que la scène courante s'appelle `scene_name`.
func _wait_scene(scene_name: String) -> bool:
	for i in 600:
		await get_tree().process_frame
		var scene := get_tree().current_scene
		if scene and scene.name == scene_name:
			await wait_physics_frames(10)
			return true
	return false


func test_catalog_scenes_exist() -> void:
	assert_gt(LevelCatalog.LEVELS.size(), 1)
	for level in LevelCatalog.LEVELS:
		assert_true(ResourceLoader.exists(level["scene"]), level["scene"])


func test_menu_lists_every_level() -> void:
	var menu := await _open_menu()
	assert_eq(_play_buttons(menu).size(), LevelCatalog.LEVELS.size())


func test_missing_map_greys_out_its_level() -> void:
	OS.set_environment("COMMANDO_MAPS", "/nulle/part")
	var menu := await _open_menu()
	var buttons := _play_buttons(menu)
	for i in LevelCatalog.LEVELS.size():
		var needs_map: bool = LevelCatalog.LEVELS[i].has("map")
		assert_eq(buttons[i].disabled, needs_map, LevelCatalog.LEVELS[i]["title"])


func test_play_sandbox_then_back_to_menu() -> void:
	var menu := await _open_menu()
	_play_buttons(menu)[0].pressed.emit()
	assert_true(await _wait_scene("Sandbox"), "terrain d'essai lancé")
	assert_eq(get_tree().get_nodes_in_group(&"commandos").size(), 3)
	var menu_button: Button = get_tree().current_scene.find_children("Menu", "Button", true, false)[0]
	menu_button.pressed.emit()
	assert_true(await _wait_scene("MainMenu"), "retour au menu")
	assert_eq(get_tree().get_nodes_in_group(&"commandos").size(), 0, "niveau libéré")
	assert_eq(SelectionManager.selected.size(), 0, "sélection vidée")
	assert_eq(GameState.alert_level, GameState.AlertLevel.CALM)


## Le bouton « Quitter » de `scene` demande confirmation : Annuler reprend le
## jeu, Quitter quitte.
func _check_quit_confirmation(scene: Node, dialog: QuitDialog) -> void:
	var quit_calls := [0]
	dialog.quit_action = func() -> void: quit_calls[0] += 1
	var quit_button: Button = scene.find_children("Quit", "Button", true, false)[0]
	quit_button.pressed.emit()
	await wait_process_frames(2)
	assert_true(dialog.visible, "fenêtre de confirmation ouverte")
	assert_true(get_tree().paused, "jeu en pause pendant la question")
	assert_eq(quit_calls[0], 0, "pas encore quitté")
	assert_true(dialog.get_cancel_button().has_focus(), "Annuler par défaut")
	dialog.get_cancel_button().pressed.emit()
	await wait_process_frames(2)
	assert_false(dialog.visible, "fermée par Annuler")
	assert_false(get_tree().paused, "le jeu reprend")
	assert_eq(quit_calls[0], 0, "Annuler ne quitte pas")
	quit_button.pressed.emit()
	await wait_process_frames(2)
	dialog.get_ok_button().pressed.emit()
	assert_eq(quit_calls[0], 1, "Quitter quitte")


func test_quit_from_menu_asks_confirmation() -> void:
	var menu := await _open_menu()
	await _check_quit_confirmation(menu, menu.quit_dialog)


func test_quit_from_game_asks_confirmation() -> void:
	var menu := await _open_menu()
	_play_buttons(menu)[0].pressed.emit()
	assert_true(await _wait_scene("Sandbox"), "terrain d'essai lancé")
	var hud: Hud = get_tree().current_scene.find_children("*", "Hud", true, false)[0]
	await _check_quit_confirmation(hud, hud.quit_dialog)
