@tool
class_name Ladder
extends Node3D
## Échelle appuyée contre un mur, jusqu'au toit (ou à une plateforme) qu'il
## porte. Repère : le mur est derrière (vers -Z), sa face en z = 0 ; on monte
## face à -Z. Construit son maillage et le lien de navigation (`TraversalLink`)
## entre le sol, devant, et le toit, en haut.

## Hauteur du toit au-dessus du pied de l'échelle.
@export var height: float = 3.0:
	set(value):
		height = value
		_rebuild()
## Distance du point d'arrivée au bord du toit (sur le maillage de navigation).
@export var top_inset: float = 0.7
## Distance du point de départ, au sol, à la face du mur.
@export var foot_distance: float = 0.7

const WIDTH := 0.46
const RAIL := 0.045
const RUNG_SPACING := 0.3
## L'échelle dépasse du toit, pour s'y agripper.
const OVERHANG := 0.9

var link: TraversalLink


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for child in get_children():
		if child.name in [&"Mesh", &"Link"]:
			remove_child(child)
			child.queue_free()
	_build_mesh()
	if Engine.is_editor_hint():
		return
	link = TraversalLink.new()
	link.name = "Link"
	link.kind = TraversalLink.Kind.LADDER
	link.face_distance = foot_distance
	link.start_position = Vector3(0.0, 0.0, foot_distance)
	link.end_position = Vector3(0.0, height, -top_inset)
	add_child(link)


func _build_mesh() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.42, 0.44, 0.4)
	material.metallic = 0.6
	material.roughness = 0.55
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top := height + OVERHANG
	# Pied un peu écarté du mur, haut appuyé dessus.
	var foot_gap := 0.12
	for side: float in [-1.0, 1.0]:
		_add_beam(surface, Vector3(side * WIDTH * 0.5, 0.0, foot_gap), Vector3(side * WIDTH * 0.5, top, 0.04), RAIL)
	var rung := RUNG_SPACING
	while rung < top - 0.1:
		var z := lerpf(foot_gap, 0.04, rung / top)
		_add_beam(surface, Vector3(-WIDTH * 0.5, rung, z), Vector3(WIDTH * 0.5, rung, z), RAIL * 0.7)
		rung += RUNG_SPACING
	surface.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	mesh.mesh = surface.commit()
	mesh.material_override = material
	add_child(mesh)


## Barre de section carrée `size` de `from` à `to`.
static func _add_beam(surface: SurfaceTool, from: Vector3, to: Vector3, size: float) -> void:
	var axis := (to - from).normalized()
	var helper := Vector3.FORWARD if absf(axis.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var u := axis.cross(helper).normalized() * size * 0.5
	var v := axis.cross(u).normalized() * size * 0.5
	var corners: Array[Vector3] = [u + v, u - v, -u - v, -u + v]
	for i in 4:
		var a := corners[i]
		var b := corners[(i + 1) % 4]
		surface.add_vertex(from + a)
		surface.add_vertex(to + a)
		surface.add_vertex(to + b)
		surface.add_vertex(from + a)
		surface.add_vertex(to + b)
		surface.add_vertex(from + b)
	for end: Vector3 in [from, to]:
		var flip := end == from
		surface.add_vertex(end + corners[0])
		surface.add_vertex(end + (corners[2] if flip else corners[1]))
		surface.add_vertex(end + (corners[1] if flip else corners[2]))
		surface.add_vertex(end + corners[0])
		surface.add_vertex(end + (corners[3] if flip else corners[2]))
		surface.add_vertex(end + (corners[2] if flip else corners[3]))
