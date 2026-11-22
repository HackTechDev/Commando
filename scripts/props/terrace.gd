@tool
class_name Terrace
extends Node3D
## Relief : plateau rectangulaire de `height` m, aux flancs à pic, auquel
## mènent des rampes (`ramps`). Le dessus est un sol où l'on marche (la
## navigation y passe par les rampes) ; les flancs arrêtent la vue et les
## balles, comme un mur. Une échelle posée contre un flanc y fait monter.
##
## Repère : centré sur l'origine, au sol. Côtés comme `Building` : 0 vers
## +Z, 1 vers +X, 2 vers -Z, 3 vers -X ; une rampe se place par son
## décalage le long du côté (de gauche à droite, vu de dehors) et descend
## vers l'extérieur.

## Sol (marche, clics) et obstacle (vue, balles), comme les dalles des
## immeubles.
const LAYER := 0b11
## Pente des rampes (degrés) : sous la pente maximale de la navigation.
const RAMP_SLOPE := 25.0
const RAMP_THICKNESS := 0.3

## Emprise du dessus (x, z) et hauteur (m).
@export var size := Vector2(12.0, 10.0):
	set(value):
		size = value
		_queue_rebuild()
@export var height: float = 2.0:
	set(value):
		height = value
		_queue_rebuild()
## Rampes : (côté, décalage le long du côté).
@export var ramps: Array[Vector2] = [Vector2(0, 0)]:
	set(value):
		ramps = value
		_queue_rebuild()
@export var ramp_width: float = 3.0:
	set(value):
		ramp_width = value
		_queue_rebuild()
@export var color := Color(0.42, 0.5, 0.3)
@export var side_color := Color(0.45, 0.4, 0.33)


var _rebuild_queued: bool = false


func _ready() -> void:
	_build()


## Réglage changé dans l'éditeur (inspecteur, annulation) : reconstruit.
func _queue_rebuild() -> void:
	if not is_node_ready() or _rebuild_queued:
		return
	_rebuild_queued = true
	_rebuild.call_deferred()


func _rebuild() -> void:
	_rebuild_queued = false
	for child in get_children():
		if child.owner == null:
			remove_child(child)
			child.queue_free()
	_build()
	update_gizmos()


func _build() -> void:
	var body := StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = LAYER
	body.collision_mask = 0
	add_child(body)
	var top := _plain(color)
	var flank := _plain(side_color)
	_box(body, Vector3(size.x, height, size.y), Vector3(0, height * 0.5, 0), Basis.IDENTITY, [top, flank])
	for ramp in ramps:
		var spec := ramp_frame(size, height, int(ramp.x), ramp.y, ramp_width)
		if spec.is_empty():
			continue
		_box(body, Vector3(ramp_width, RAMP_THICKNESS, spec["length"]), spec["center"], spec["basis"], [top, flank])


## Rampe du côté `side`, décalée de `offset`, pour un plateau `size` ×
## `height` : {"center", "basis", "length", "foot", "head"} (repère du
## plateau) ; vide si le côté n'existe pas. Le dessus de la rampe va du sol
## (`foot`) au bord du plateau (`head`).
static func ramp_frame(size_: Vector2, height_: float, side: int, offset: float, width: float) -> Dictionary:
	var out: Vector3
	var along: Vector3
	var half: float
	match side:
		0:
			out = Vector3.BACK
			along = Vector3.RIGHT
			half = size_.y * 0.5
		1:
			out = Vector3.RIGHT
			along = Vector3.FORWARD
			half = size_.x * 0.5
		2:
			out = Vector3.FORWARD
			along = Vector3.LEFT
			half = size_.y * 0.5
		3:
			out = Vector3.LEFT
			along = Vector3.BACK
			half = size_.x * 0.5
		_:
			return {}
	var run := height_ / tan(deg_to_rad(RAMP_SLOPE))
	var length := sqrt(run * run + height_ * height_)
	var head := out * half + along * offset + Vector3.UP * height_
	var foot := out * (half + run) + along * offset
	# Repère de la rampe : x en travers, z le long de la pente (vers le bas).
	var down := (foot - head).normalized()
	var across := along
	# Repère direct (x × y = z), normale vers le haut pour chaque côté.
	var normal := down.cross(across).normalized()
	var basis := Basis(across, normal, down)
	var center := (head + foot) * 0.5 - normal * RAMP_THICKNESS * 0.5
	return {"center": center, "basis": basis, "length": length, "foot": foot, "head": head}


## Point le plus haut du relief sous (x, z) du monde, ou -INF (pour la pose
## et la vérification).
func top_at(point: Vector3) -> float:
	var local := to_local(point)
	if absf(local.x) <= size.x * 0.5 and absf(local.z) <= size.y * 0.5:
		return global_position.y + height
	return -INF


func _box(body: StaticBody3D, extent: Vector3, at: Vector3, basis: Basis, materials: Array) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = extent
	shape.shape = box
	shape.transform = Transform3D(basis, at)
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = extent
	mesh.mesh = cube
	mesh.material_override = materials[1]
	mesh.transform = shape.transform
	body.add_child(mesh)
	# Dessus d'une autre couleur que les flancs.
	var cap := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(extent.x, extent.z)
	cap.mesh = plane
	cap.material_override = materials[0]
	cap.transform = Transform3D(basis, at) * Transform3D(Basis.IDENTITY, Vector3.UP * (extent.y * 0.5 + 0.005))
	cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(cap)


func _plain(tint: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 1.0
	return material
