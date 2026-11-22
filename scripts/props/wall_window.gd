@tool
class_name WallWindow
extends StaticBody3D
## Fenêtre sans vitre dans un mur : l'allège (en bas) et le linteau (en haut)
## arrêtent la marche ; la vue et les balles passent par l'ouverture, au-dessus
## de l'allège (une unité accroupie derrière reste cachée). Un lien de
## navigation (`TraversalLink`, muret) l'enjambe. Repère : l'ouverture suit X,
## centrée, le mur est épais selon Z.

const LAYER_OCCLUDERS := 0b10
## Distance des extrémités du lien au milieu du mur.
const LINK_REACH := 0.95

@export var width: float = 1.2
## Hauteur du mur, de l'allège et du haut de l'ouverture.
@export var wall_height: float = 3.0
@export var sill: float = 0.9
@export var top: float = 2.1
@export var thickness: float = 0.3
@export var color := Color(0.72, 0.66, 0.6)
@export var texture: String = "tex_ctp1/bricks_g_1.jpg"

## Linteau (au-dessus de la hauteur de coupe d'un `Building`).
var lintel: MeshInstance3D
var link: TraversalLink


func _ready() -> void:
	collision_layer = LAYER_OCCLUDERS
	collision_mask = 0
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	if not texture.is_empty():
		material.set_meta(&"albedo_source", texture)
	_part(material, 0.0, sill)
	lintel = _part(material, top, wall_height)
	# Appui de fenêtre, plus clair.
	var ledge := MeshInstance3D.new()
	var slab := BoxMesh.new()
	slab.size = Vector3(width, 0.05, thickness + 0.1)
	ledge.mesh = slab
	var stone := StandardMaterial3D.new()
	stone.albedo_color = color.lightened(0.25)
	ledge.material_override = stone
	ledge.position.y = sill + 0.025
	add_child(ledge)
	if Engine.is_editor_hint():
		return
	link = TraversalLink.new()
	link.name = "Link"
	link.kind = TraversalLink.Kind.VAULT
	link.height = sill
	link.start_position = Vector3(0.0, 0.0, LINK_REACH)
	link.end_position = Vector3(0.0, 0.0, -LINK_REACH)
	add_child(link)


## Bloc plein de `bottom` à `top_y` (forme et maillage).
func _part(material: Material, bottom: float, top_y: float) -> MeshInstance3D:
	if top_y - bottom <= 0.01:
		return null
	var size := Vector3(width, top_y - bottom, thickness)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position.y = (bottom + top_y) * 0.5
	add_child(shape)
	var mesh := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = size
	mesh.mesh = cube
	mesh.material_override = material
	mesh.position.y = shape.position.y
	add_child(mesh)
	return mesh


## Bâtiment vu en coupe : le linteau s'efface.
func set_cutaway(cut: bool) -> void:
	if lintel:
		lintel.visible = not cut
