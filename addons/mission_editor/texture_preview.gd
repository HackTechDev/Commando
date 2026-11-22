@tool
extends RefCounted
## Aperçu des textures externes (`TextureLibrary`) dans l'éditeur : elles sont
## posées sur les matériaux de la scène ouverte, puis retirées avant chaque
## enregistrement (elles ne doivent pas entrer dans le `.tscn`) et reposées
## après. Chaque changement est noté avec la valeur d'avant pour être annulé
## exactement.

## [{"material": Material, "property": StringName, "before": Variant}]
var _changes: Array[Dictionary] = []


## Pose les textures demandées par les matériaux de `root`.
func apply(root: Node) -> void:
	revert()
	if root == null:
		return
	var materials: Array[Material] = []
	for node in root.find_children("*", "GeometryInstance3D", true, false):
		for material in _materials_of(node as GeometryInstance3D):
			if not materials.has(material):
				materials.append(material)
	var paths: Array[String] = []
	for material in materials:
		for key: StringName in TextureLibrary.SLOTS:
			if material.has_meta(key):
				paths.append(str(material.get_meta(key)))
	TextureLibrary.load_textures(paths)
	for material in materials:
		for key: StringName in TextureLibrary.SLOTS:
			if not material.has_meta(key):
				continue
			var texture := TextureLibrary.get_texture(str(material.get_meta(key)))
			if texture == null:
				continue
			if material is BaseMaterial3D:
				_change(material, _texture_property(TextureLibrary.SLOTS[key]), texture)
			elif material is ShaderMaterial and TextureLibrary.SHADER_SLOTS.has(key):
				var slot: Array = TextureLibrary.SHADER_SLOTS[key]
				_change(material, StringName("shader_parameter/" + slot[0]), texture)
				if slot[1] != &"":
					_change(material, StringName("shader_parameter/" + slot[1]), true)


## Remet les matériaux comme avant `apply`.
func revert() -> void:
	for i in range(_changes.size() - 1, -1, -1):
		var change := _changes[i]
		var material: Material = change["material"]
		if is_instance_valid(material):
			material.set(change["property"], change["before"])
	_changes.clear()


## Nombre de propriétés modifiées (vérifications).
func count() -> int:
	return _changes.size()


func _change(material: Material, property: StringName, value: Variant) -> void:
	_changes.append({"material": material, "property": property, "before": material.get(property)})
	material.set(property, value)


## Propriété d'un `BaseMaterial3D` pour l'emplacement `slot`.
static func _texture_property(slot: BaseMaterial3D.TextureParam) -> StringName:
	match slot:
		BaseMaterial3D.TEXTURE_NORMAL:
			return &"normal_texture"
		BaseMaterial3D.TEXTURE_ROUGHNESS:
			return &"roughness_texture"
		BaseMaterial3D.TEXTURE_EMISSION:
			return &"emission_texture"
	return &"albedo_texture"


static func _materials_of(geometry: GeometryInstance3D) -> Array[Material]:
	var found: Array[Material] = []
	if geometry.material_override:
		found.append(geometry.material_override)
	var mesh_instance := geometry as MeshInstance3D
	if mesh_instance:
		for i in mesh_instance.get_surface_override_material_count():
			var material := mesh_instance.get_surface_override_material(i)
			if material and not found.has(material):
				found.append(material)
		if mesh_instance.mesh:
			for i in mesh_instance.mesh.get_surface_count():
				var material := mesh_instance.mesh.surface_get_material(i)
				if material and not found.has(material):
					found.append(material)
	return found
