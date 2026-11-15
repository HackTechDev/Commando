@tool
class_name LowWall
extends StaticBody3D
## Muret qu'on enjambe : il arrête la marche (et les balles comme la vue
## d'une unité accroupie derrière), mais des liens de navigation
## (`TraversalLink`) le traversent tous les `link_spacing` mètres. Centré sur
## son origine, sa longueur suit X.

@export var length: float = 4.0:
	set(value):
		length = value
		_rebuild()
@export var height: float = 1.0:
	set(value):
		height = value
		_rebuild()
@export var thickness: float = 0.3:
	set(value):
		thickness = value
		_rebuild()
@export var link_spacing: float = 2.0
## Distance des extrémités des liens à l'axe du muret.
@export var link_reach: float = 0.8
## Texture (chemin relatif au dossier de textures externe, `TextureLibrary`).
@export var texture: String = "tex_ctp1/bricks_g_1.jpg"


func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for child in get_children():
		if child.name.begins_with("Link") or child.name in [&"Shape", &"Mesh"]:
			remove_child(child)
			child.queue_free()
	var size := Vector3(length, height, thickness)
	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position.y = height * 0.5
	add_child(shape)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.72, 0.66, 0.6)
	material.roughness = 0.95
	material.uv1_scale = Vector3(0.9, 0.9, 0.9)
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if not texture.is_empty():
		material.set_meta(&"albedo_source", texture)
	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	box_mesh.material = material
	mesh.mesh = box_mesh
	mesh.position.y = height * 0.5
	add_child(mesh)
	if Engine.is_editor_hint():
		return
	var count := maxi(1, int(length / link_spacing))
	for i in count:
		var x := (float(i) + 0.5) / count * length - length * 0.5
		var link := TraversalLink.new()
		link.name = "Link%d" % i
		link.kind = TraversalLink.Kind.VAULT
		link.height = height
		link.start_position = Vector3(x, 0.0, link_reach)
		link.end_position = Vector3(x, 0.0, -link_reach)
		add_child(link)
