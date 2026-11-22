extends GutTest
## Ressources externes : dossiers (`AssetPaths`), textures (`TextureLibrary`),
## catalogue des niveaux (`LevelCatalog`).

var _saved_env: Dictionary = {}
var _tmp_dir := ""


func before_each() -> void:
	for name in ["COMMANDO_TEXTURES", "COMMANDO_MAPS"]:
		_saved_env[name] = OS.get_environment(name)
	TextureLibrary.clear()
	# Petit dossier de textures de test, sous user://.
	_tmp_dir = ProjectSettings.globalize_path("user://test_textures")
	DirAccess.make_dir_recursive_absolute(_tmp_dir.path_join("tex_test"))
	var image := Image.create(8, 4, false, Image.FORMAT_RGB8)
	image.fill(Color.RED)
	image.save_png(_tmp_dir.path_join("tex_test/red.png"))
	OS.set_environment("COMMANDO_TEXTURES", _tmp_dir)


func after_each() -> void:
	for name in _saved_env:
		OS.set_environment(name, _saved_env[name])
	TextureLibrary.clear()
	DirAccess.remove_absolute(_tmp_dir.path_join("tex_test/red.png"))
	DirAccess.remove_absolute(_tmp_dir.path_join("tex_test"))
	DirAccess.remove_absolute(_tmp_dir)


func test_environment_overrides_setting() -> void:
	assert_eq(AssetPaths.textures_dir(), _tmp_dir)


func test_relative_dir_starts_from_project() -> void:
	OS.set_environment("COMMANDO_MAPS", "../Ailleurs/cartes")
	var project := ProjectSettings.globalize_path("res://")
	assert_eq(AssetPaths.maps_dir(), project.path_join("../Ailleurs/cartes").simplify_path())


func test_find_file_with_or_without_extension() -> void:
	assert_eq(TextureLibrary.find_file("tex_test/red.png"), _tmp_dir.path_join("tex_test/red.png"))
	assert_eq(TextureLibrary.find_file("tex_test/red"), _tmp_dir.path_join("tex_test/red.png"), "extension devinée (cartes UFO:AI)")
	assert_eq(TextureLibrary.find_file("tex_test/absent"), "")


func test_texture_is_loaded_with_mipmaps_and_cached() -> void:
	var texture := TextureLibrary.get_texture("tex_test/red")
	assert_not_null(texture)
	assert_eq(texture.get_size(), Vector2(8, 4))
	assert_true(texture.get_image().has_mipmaps())
	assert_same(TextureLibrary.get_texture("tex_test/red"), texture, "mise en cache")


func test_missing_texture_is_null() -> void:
	assert_null(TextureLibrary.get_texture("tex_test/absent"))


func test_apply_to_tree_fills_materials_from_metadata() -> void:
	var material := StandardMaterial3D.new()
	material.set_meta(&"albedo_source", "tex_test/red")
	material.set_meta(&"normal_source", "tex_test/absent")
	var mesh := BoxMesh.new()
	mesh.material = material
	var root: Node3D = autofree(Node3D.new())
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	root.add_child(instance)
	TextureLibrary.apply_to_tree(root)
	assert_not_null(material.albedo_texture)
	assert_null(material.normal_texture, "texture absente : emplacement vide")


func test_level_needing_a_missing_map_is_unavailable() -> void:
	OS.set_environment("COMMANDO_MAPS", "/nulle/part")
	for level in LevelCatalog.levels():
		var reason := LevelCatalog.unavailable_reason(level)
		if level.has("map"):
			assert_string_contains(reason, "Carte introuvable")
		else:
			assert_eq(reason, "", level["title"])
