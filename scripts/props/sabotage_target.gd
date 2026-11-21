class_name SabotageTarget
extends StaticBody3D
## Cible de sabotage : groupe électrogène sur patins (capot, réservoir,
## échappement, armoire électrique). Une charge qui explose tout près le
## détruit (`blast`) : objectif `objective_id` rempli, et les lumières
## alimentées (`lights`) s'éteignent.

const GROUP := &"sabotage_targets"
## Part du rayon d'une explosion qui détruit la cible (en plus de sa
## demi-longueur).
const BLAST_SHARE := 0.8
const SIZE := Vector3(2.4, 1.6, 1.3)

## Objectif rempli à sa destruction (vide : aucun).
@export var objective_id: StringName = &"sabotage"
## Nœud dont les lumières (OmniLight3D, SpotLight3D) et les ampoules
## (« Bulb ») s'éteignent avec lui.
@export var lights: NodePath

var is_destroyed: bool = false
var _parts: Array[MeshInstance3D] = []


func _enter_tree() -> void:
	add_to_group(GROUP)
	add_to_group(QuickSave.GROUP)


func _ready() -> void:
	collision_layer = 0b10
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = SIZE
	shape.shape = box
	shape.position = Vector3(0, SIZE.y * 0.5, 0)
	add_child(shape)
	var olive := _mat(Color(0.32, 0.36, 0.26))
	var dark := _mat(Color(0.12, 0.12, 0.12))
	var steel := _mat(Color(0.45, 0.46, 0.47), 0.5)
	var warning := _mat(Color(0.85, 0.65, 0.1))
	_box(Vector3(2.5, 0.12, 1.35), Vector3(0, 0.06, 0), dark)
	_box(Vector3(1.6, 1.25, 1.2), Vector3(-0.35, 0.75, 0), olive)
	_box(Vector3(0.7, 1.1, 1.0), Vector3(0.8, 0.67, 0), olive)
	_box(Vector3(0.05, 0.6, 0.7), Vector3(1.16, 0.8, 0), steel)
	_box(Vector3(0.06, 0.18, 0.4), Vector3(1.18, 1.25, 0), warning)
	_box(Vector3(1.2, 0.08, 1.0), Vector3(-0.35, 1.42, 0), dark)
	for z: float in [-0.61, 0.61]:
		for x: float in [-0.9, -0.6, -0.3, 0.0, 0.3]:
			_box(Vector3(0.18, 0.7, 0.02), Vector3(x, 0.8, z), dark)
	_box(Vector3(0.1, 0.6, 0.1), Vector3(-0.9, 1.65, 0.35), dark)
	_box(Vector3(0.9, 0.35, 0.5), Vector3(-0.35, 0.3, 0.0), steel)


func _box(size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = material
	mesh.position = at
	add_child(mesh)
	_parts.append(mesh)
	return mesh


func _mat(color: Color, metallic: float = 0.1) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = 0.7
	return material


## Souffle d'une explosion à `at` : détruit tout près.
func blast(at: Vector3, radius: float) -> void:
	if is_destroyed:
		return
	var flat := Vector3(at.x - global_position.x, 0.0, at.z - global_position.z)
	if flat.length() <= radius * BLAST_SHARE + SIZE.x * 0.5:
		destroy()


## Détruit : carcasse noircie, lumières éteintes, objectif rempli.
func destroy() -> void:
	if is_destroyed:
		return
	_set_destroyed(true)
	if objective_id != &"":
		EventBus.objective_completed.emit(objective_id)


func _set_destroyed(value: bool) -> void:
	is_destroyed = value
	for part in _parts:
		var material := part.material_override as StandardMaterial3D
		if material == null:
			continue
		if not part.has_meta(&"color"):
			part.set_meta(&"color", material.albedo_color)
		var color: Color = part.get_meta(&"color")
		material.albedo_color = color.darkened(0.75) if value else color
	var source := get_node_or_null(lights)
	if source == null:
		return
	for node in source.find_children("*", "Light3D", true, false):
		(node as Light3D).visible = not value
	for node in source.find_children("Bulb", "MeshInstance3D", true, false):
		(node as MeshInstance3D).visible = not value


## Sauvegarde rapide (`QuickSave`).
func save_state() -> Dictionary:
	return {"destroyed": is_destroyed}


func load_state(data: Dictionary) -> void:
	var destroyed: bool = data.get("destroyed", false)
	if destroyed != is_destroyed:
		_set_destroyed(destroyed)
