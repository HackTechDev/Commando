class_name TextureLibrary
extends RefCounted
## Textures lues à la volée depuis le dossier de textures externe (hors du
## projet, donc non importées par Godot), au chargement d'un niveau.
##
## Un matériau (`BaseMaterial3D`) demande une texture par une métadonnée
## contenant son chemin relatif au dossier de textures, par exemple
## `metadata/albedo_source = "tex_nature/grass_mowed_green_a.jpg"`.
## `apply_to_tree` parcourt un niveau, décode toutes les images demandées en
## parallèle puis les affecte aux matériaux.
##
## Dossier : variable d'environnement `COMMANDO_TEXTURES`, sinon le réglage
## de projet `commando/assets/texture_dir`. Un chemin relatif part du
## dossier du projet (éditeur) ou de l'exécutable (jeu exporté).

const SETTING := "commando/assets/texture_dir"
const DEFAULT_DIR := "../CommandoAsset/textures"
const ENV_VAR := "COMMANDO_TEXTURES"
## Métadonnée du matériau → emplacement de texture qu'elle remplit.
const SLOTS := {
	&"albedo_source": BaseMaterial3D.TEXTURE_ALBEDO,
	&"normal_source": BaseMaterial3D.TEXTURE_NORMAL,
	&"roughness_source": BaseMaterial3D.TEXTURE_ROUGHNESS,
}

## Chemin relatif → texture (null si le fichier manque ou est illisible).
static var _cache: Dictionary = {}


## Dossier absolu des textures.
static func root_dir() -> String:
	var dir := OS.get_environment(ENV_VAR)
	if dir.is_empty():
		dir = str(ProjectSettings.get_setting(SETTING, DEFAULT_DIR))
	if dir.is_absolute_path():
		return dir
	var base := ProjectSettings.globalize_path("res://")
	if not OS.has_feature("editor"):
		base = OS.get_executable_path().get_base_dir()
	return base.path_join(dir).simplify_path()


## Affecte leurs textures externes à tous les matériaux de `root` et de ses
## descendants (scènes instanciées comprises).
static func apply_to_tree(root: Node) -> void:
	var materials: Array[BaseMaterial3D] = []
	for node in root.find_children("*", "GeometryInstance3D", true, false):
		for material in _materials_of(node as GeometryInstance3D):
			if not materials.has(material):
				materials.append(material)
	var paths: Array[String] = []
	for material in materials:
		for key: StringName in SLOTS:
			if material.has_meta(key):
				paths.append(str(material.get_meta(key)))
	load_textures(paths)
	for material in materials:
		for key: StringName in SLOTS:
			if material.has_meta(key):
				material.set_texture(SLOTS[key], get_texture(str(material.get_meta(key))))


## Charge en parallèle les textures de `paths` absentes du cache.
static func load_textures(paths: Array[String]) -> void:
	var todo: Array[String] = []
	var root := root_dir()
	for path in paths:
		if _cache.has(path) or todo.has(path):
			continue
		if not FileAccess.file_exists(root.path_join(path)):
			push_warning("Texture introuvable : %s" % root.path_join(path))
			_cache[path] = null
			continue
		todo.append(path)
	if todo.is_empty():
		return
	# Décodage et mipmaps (le plus long) dans les fils de travail ; la
	# création des textures reste dans le fil principal.
	var images: Array = []
	images.resize(todo.size())
	var decode := func(i: int) -> void:
		var image := Image.load_from_file(root.path_join(todo[i]))
		if image != null and not image.is_empty():
			image.generate_mipmaps()
			images[i] = image
	var task := WorkerThreadPool.add_group_task(decode, todo.size())
	WorkerThreadPool.wait_for_group_task_completion(task)
	for i in todo.size():
		var image: Image = images[i]
		if image == null:
			push_warning("Texture illisible : %s" % root.path_join(todo[i]))
			_cache[todo[i]] = null
		else:
			_cache[todo[i]] = ImageTexture.create_from_image(image)


## Texture déjà chargée (ou chargée maintenant) pour `path`, ou null.
static func get_texture(path: String) -> Texture2D:
	if not _cache.has(path):
		load_textures([path])
	return _cache.get(path)


## Oublie les textures chargées (les matériaux gardent les leurs).
static func clear() -> void:
	_cache.clear()


static func _materials_of(geometry: GeometryInstance3D) -> Array[BaseMaterial3D]:
	var found: Array[BaseMaterial3D] = []
	var override := geometry.material_override as BaseMaterial3D
	if override:
		found.append(override)
	var mesh_instance := geometry as MeshInstance3D
	if mesh_instance and mesh_instance.mesh:
		for i in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.get_active_material(i) as BaseMaterial3D
			if material and not found.has(material):
				found.append(material)
	return found
