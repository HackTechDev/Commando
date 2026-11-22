extends GutTest
## Menu, suite (5.5) : autres cartes UFO:AI, dernière carte jouée, aperçus.

const FILE := "user://test_settings.cfg"

var _menu: MainMenu


func before_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FILE))
	Settings.use_file(FILE)


func after_each() -> void:
	if is_instance_valid(_menu):
		_menu.free()
	Settings.use_file(Settings.PATH)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FILE))


func _open_menu() -> MainMenu:
	_menu = (load(LevelCatalog.MENU_SCENE) as PackedScene).instantiate() as MainMenu
	add_child(_menu)
	return _menu


func test_other_ufo_maps_are_offered() -> void:
	var extras := LevelCatalog.extra_levels()
	if not DirAccess.dir_exists_absolute(AssetPaths.maps_dir()):
		pending("dossier des cartes absent")
		return
	for level in extras:
		assert_eq(level["scene"], LevelCatalog.GENERIC_SCENE)
		assert_true(String(level["map"]).ends_with(".map"))
		for known in LevelCatalog.levels():
			assert_ne(level["map"], known.get("map", ""), "pas de doublon avec le catalogue")
	var menu := _open_menu()
	for level in extras:
		assert_not_null(menu.play_button(LevelCatalog.key_of(level)), "carte %s proposée" % level["map"])


func test_last_played_map_comes_first() -> void:
	var escort: Dictionary = LevelCatalog.levels()[1]
	Settings.set_last_level(LevelCatalog.key_of(escort))
	var menu := _open_menu()
	var first := menu.get_node("%Levels").get_child(0)
	assert_eq(first.get_meta(&"key"), LevelCatalog.key_of(escort), "en tête de liste")
	assert_true(menu.play_button(LevelCatalog.key_of(escort)).has_focus(), "sélectionnée")


func test_generic_level_builds_the_requested_map() -> void:
	var extras := LevelCatalog.extra_levels()
	if extras.is_empty():
		pending("aucune carte hors catalogue")
		return
	UfoMapLevel.requested_map = extras[0]["map"]
	assert_eq(LevelCatalog.title_of(LevelCatalog.GENERIC_SCENE), extras[0]["title"])
	assert_eq(LevelCatalog.key_for(LevelCatalog.GENERIC_SCENE, extras[0]["map"]), extras[0]["map"])
	assert_eq(LevelCatalog.find(extras[0]["map"])["title"], extras[0]["title"])
	UfoMapLevel.requested_map = ""


func test_preview_file_is_named_after_the_level() -> void:
	assert_eq(LevelPreview.file_for("res://scenes/levels/escort/escort.tscn"), "user://previews/escort.png")
	assert_eq(LevelPreview.file_for("dam.map"), "user://previews/dam.png")
