extends GutTest
## Menu de démarrage : liste des niveaux, lancement, retour au menu.

var _saved_maps_env := ""


## Réglages propres aux tests : la dernière carte jouée du joueur ne
## change pas l'ordre des cartes.
const SETTINGS_FILE := "user://test_settings.cfg"


func before_each() -> void:
	_saved_maps_env = OS.get_environment("COMMANDO_MAPS")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_FILE))
	Settings.use_file(SETTINGS_FILE)


func after_each() -> void:
	OS.set_environment("COMMANDO_MAPS", _saved_maps_env)
	Settings.use_file(Settings.PATH)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_FILE))
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


## « Jouer » sur le niveau `index`, puis « Lancer la mission » dans la
## préparation.
## Rang du niveau `title` dans le catalogue (et le menu).
static func _index_of(title: String) -> int:
	for i in LevelCatalog.LEVELS.size():
		if LevelCatalog.LEVELS[i]["title"] == title:
			return i
	return -1


func _launch(menu: MainMenu, index: int) -> void:
	_play_buttons(menu)[index].pressed.emit()
	assert_true(menu.briefing.visible, "préparation de la mission ouverte")
	(menu.briefing.find_child("Launch", true, false) as Button).pressed.emit()


## Attend que la scène courante s'appelle `scene_name`.
func _wait_scene(scene_name: String) -> bool:
	for i in 600:
		await get_tree().process_frame
		var scene := get_tree().current_scene
		if scene and scene.name == scene_name:
			if scene is LevelRoot and not scene.is_level_ready:
				await wait_for_signal(scene.level_ready, 30.0)
			await wait_physics_frames(10)
			return true
	return false


func test_catalog_scenes_exist() -> void:
	assert_gt(LevelCatalog.LEVELS.size(), 1)
	for level in LevelCatalog.LEVELS:
		assert_true(ResourceLoader.exists(level["scene"]), level["scene"])


func test_menu_lists_every_level() -> void:
	var menu := await _open_menu()
	# Catalogue, puis les autres cartes UFO:AI du dossier.
	assert_eq(_play_buttons(menu).size(), LevelCatalog.all_levels().size())


func test_missing_map_greys_out_its_level() -> void:
	OS.set_environment("COMMANDO_MAPS", "/nulle/part")
	var menu := await _open_menu()
	var buttons := _play_buttons(menu)
	for i in LevelCatalog.LEVELS.size():
		var needs_map: bool = LevelCatalog.LEVELS[i].has("map")
		assert_eq(buttons[i].disabled, needs_map, LevelCatalog.LEVELS[i]["title"])


func test_play_sandbox_then_back_to_menu() -> void:
	var menu := await _open_menu()
	_launch(menu, _index_of("Terrain d'essai"))
	assert_true(await _wait_scene("Sandbox"), "terrain d'essai lancé")
	assert_eq(get_tree().get_nodes_in_group(&"commandos").size(), 3)
	var menu_button: Button = get_tree().current_scene.find_children("Menu", "Button", true, false)[0]
	menu_button.pressed.emit()
	await wait_process_frames(2)
	var hud: Hud = get_tree().current_scene.find_children("*", "Hud", true, false)[0]
	assert_true(hud.menu_dialog.visible, "confirmation demandée")
	hud.menu_dialog.get_ok_button().pressed.emit()
	assert_true(await _wait_scene("MainMenu"), "retour au menu")
	assert_false(get_tree().paused, "menu pas en pause")
	assert_eq(get_tree().get_nodes_in_group(&"commandos").size(), 0, "niveau libéré")
	assert_eq(SelectionManager.selected.size(), 0, "sélection vidée")
	assert_eq(GameState.alert_level, GameState.AlertLevel.CALM)


## Le bouton `button_name` de `scene` demande confirmation : Annuler reprend
## le jeu, la confirmation lève la pause et exécute l'action.
func _check_confirmation(scene: Node, button_name: String, dialog: ConfirmDialog) -> void:
	var calls := [0]
	dialog.action = func() -> void:
		calls[0] += 1
		assert_false(get_tree().paused, "pause levée avant l'action")
	var button: Button = scene.find_children(button_name, "Button", true, false)[0]
	button.pressed.emit()
	await wait_process_frames(2)
	assert_true(dialog.visible, "fenêtre de confirmation ouverte")
	assert_true(get_tree().paused, "jeu en pause pendant la question")
	assert_eq(calls[0], 0, "pas encore confirmé")
	assert_true(dialog.get_cancel_button().has_focus(), "Annuler par défaut")
	dialog.get_cancel_button().pressed.emit()
	await wait_process_frames(2)
	assert_false(dialog.visible, "fermée par Annuler")
	assert_false(get_tree().paused, "le jeu reprend")
	assert_eq(calls[0], 0, "Annuler n'exécute rien")
	button.pressed.emit()
	await wait_process_frames(2)
	dialog.get_ok_button().pressed.emit()
	assert_eq(calls[0], 1, "confirmé")


func test_quit_from_menu_asks_confirmation() -> void:
	var menu := await _open_menu()
	await _check_confirmation(menu, "Quit", menu.quit_dialog)


func test_menu_from_game_asks_confirmation() -> void:
	var menu := await _open_menu()
	_launch(menu, _index_of("Terrain d'essai"))
	assert_true(await _wait_scene("Sandbox"), "terrain d'essai lancé")
	var hud: Hud = get_tree().current_scene.find_children("*", "Hud", true, false)[0]
	assert_null(hud.find_child("Quit", true, false), "pas de bouton « Quitter » en jeu (menu pause)")
	await _check_confirmation(hud, "Menu", hud.menu_dialog)


func test_briefing_shows_preview_objectives_and_edits_outfits() -> void:
	var menu := await _open_menu()
	_play_buttons(menu)[_index_of("Escorte")].pressed.emit()
	var objectives := menu.briefing.find_child("Objectives", true, false)
	await wait_process_frames(1)
	var texts := objectives.get_children().map(func(label: Label) -> String: return label.text)
	assert_true(texts.any(func(text: String) -> bool: return text.contains("VIP")), "objectifs de l'escorte : %s" % [texts])
	var preview := menu.briefing.find_child("BriefingPreview", true, false)
	assert_eq(preview.get_child_count(), 1, "aperçu ou cadre d'attente")
	(menu.briefing.find_child("Edit2", true, false) as Button).pressed.emit()
	await wait_process_frames(2)
	assert_not_null(menu.operator_editor, "éditeur ouvert sur place")
	assert_eq(menu.operator_editor.current, 1, "sur Bravo")
	assert_eq(get_tree().current_scene, menu, "sans quitter le menu")
	(menu.operator_editor.find_child("Back", true, false) as Button).pressed.emit()
	await wait_process_frames(2)
	assert_null(menu.operator_editor, "refermé")
	assert_true(menu.briefing.visible, "retour à la préparation")
