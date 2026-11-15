class_name TextureLibrary
extends RefCounted
## Textures lues à la volée depuis le dossier de textures externe (hors du
## projet, donc non importées par Godot), au chargement d'un niveau.
##
## Un matériau (`BaseMaterial3D`, ou `ShaderMaterial` du décor, voir
## `SHADER_SLOTS`) demande une texture par une métadonnée
## contenant son chemin relatif au dossier de textures, par exemple
## `metadata/albedo_source = "tex_nature/grass_mowed_green_a.jpg"`.
## `apply_to_tree` parcourt un niveau, décode toutes les images demandées en
## parallèle puis les affecte aux matériaux.
##
## Dossier : voir `AssetPaths.textures_dir` (réglage de projet
## `commando/assets/texture_dir`, variable d'environnement
## `COMMANDO_TEXTURES`). Un chemin sans extension (cartes UFO:AI) désigne le
## premier fichier trouvé parmi `EXTENSIONS`.

const EXTENSIONS: Array[String] = ["png", "jpg", "jpeg", "tga", "webp"]
## Métadonnée du matériau → emplacement de texture qu'elle remplit.
const SLOTS := {
	&"albedo_source": BaseMaterial3D.TEXTURE_ALBEDO,
	&"normal_source": BaseMaterial3D.TEXTURE_NORMAL,
	&"roughness_source": BaseMaterial3D.TEXTURE_ROUGHNESS,
	&"emission_source": BaseMaterial3D.TEXTURE_EMISSION,
}

## Métadonnée → paramètre d'un `ShaderMaterial` (`WorldMaterial`) ; une
## texture posée active aussi l'option correspondante (`use_normal`…).
const SHADER_SLOTS := {
	&"albedo_source": [&"albedo_texture", &""],
	&"normal_source": [&"normal_texture", &"use_normal"],
	&"emission_source": [&"emission_texture", &"use_emission"],
}

## Chemin relatif → texture (null si le fichier manque ou est illisible).
static var _cache: Dictionary = {}


## Dossier absolu des textures.
static func root_dir() -> String:
	return AssetPaths.textures_dir()


## Fichier (chemin absolu) de la texture `path`, ou vide s'il n'existe pas.
static func find_file(path: String) -> String:
	var full := root_dir().path_join(path)
	if not path.get_extension().is_empty() and FileAccess.file_exists(full):
		return full
	for extension in EXTENSIONS:
		if FileAccess.file_exists(full + "." + extension):
			return full + "." + extension
	return ""


## Affecte leurs textures externes à tous les matériaux de `root` et de ses
## descendants (scènes instanciées comprises).
static func apply_to_tree(root: Node) -> void:
	var materials: Array[Material] = []
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
			if not material.has_meta(key):
				continue
			var texture := get_texture(str(material.get_meta(key)))
			if material is BaseMaterial3D:
				(material as BaseMaterial3D).set_texture(SLOTS[key], texture)
			elif material is ShaderMaterial and SHADER_SLOTS.has(key):
				var slot: Array = SHADER_SLOTS[key]
				material.set_shader_parameter(slot[0], texture)
				if slot[1] != &"":
					material.set_shader_parameter(slot[1], texture != null)


## Charge en parallèle les textures de `paths` absentes du cache.
static func load_textures(paths: Array[String]) -> void:
	var todo: Array[String] = []
	var files: Array[String] = []
	for path in paths:
		if _cache.has(path) or todo.has(path):
			continue
		var file := find_file(path)
		if file.is_empty():
			push_warning("Texture introuvable : %s" % root_dir().path_join(path))
			_cache[path] = null
			continue
		todo.append(path)
		files.append(file)
	if todo.is_empty():
		return
	# Décodage et mipmaps (le plus long) dans les fils de travail ; la
	# création des textures reste dans le fil principal.
	var images: Array = []
	images.resize(todo.size())
	var decode := func(i: int) -> void:
		var image := Image.load_from_file(files[i])
		if image != null and not image.is_empty():
			image.generate_mipmaps()
			images[i] = image
	var task := WorkerThreadPool.add_group_task(decode, todo.size())
	WorkerThreadPool.wait_for_group_task_completion(task)
	for i in todo.size():
		var image: Image = images[i]
		if image == null:
			push_warning("Texture illisible : %s" % files[i])
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


static func _materials_of(geometry: GeometryInstance3D) -> Array[Material]:
	var found: Array[Material] = []
	var override := geometry.material_override
	if override:
		found.append(override)
	var mesh_instance := geometry as MeshInstance3D
	if mesh_instance and mesh_instance.mesh:
		for i in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.get_active_material(i)
			if material and not found.has(material):
				found.append(material)
	return found
