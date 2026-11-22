@tool
class_name SnowPine
extends StaticBody3D
## Sapin enneigé (décor des cartes polaires) : étages de branches coniques,
## poudrés de neige. Seul le tronc arrête le passage, la vue et les balles
## (couche des occultants) ; le feuillage s'efface quand il cache un
## opérateur (`OcclusionFader`).

## Couche du tronc : obstacle (vue, balles), comme les murs.
const LAYER := 0b10
const TRUNK_RADIUS := 0.22
const FOLIAGE := Color(0.13, 0.24, 0.17)
const SNOW := Color(0.9, 0.93, 0.96)
const BARK := Color(0.28, 0.2, 0.14)

## Hauteur totale (m).
@export var height: float = 5.0:
	set(value):
		height = value
		_queue_rebuild()
## Variation de forme (étages, teinte), d'un sapin à l'autre.
@export var variant: int = 0:
	set(value):
		variant = value
		_queue_rebuild()

var _rebuild_queued: bool = false


func _ready() -> void:
	# En jeu seulement : dans l'éditeur, la scène enregistrée ne change pas.
	if not Engine.is_editor_hint():
		collision_layer = LAYER
		collision_mask = 0
	_build()


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


func _build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(variant)
	var trunk_height := height * 0.3
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = TRUNK_RADIUS
	cylinder.height = trunk_height + 0.6
	shape.shape = cylinder
	shape.position = Vector3(0, cylinder.height * 0.5, 0)
	add_child(shape)
	_cone(0.12, 0.18, trunk_height + 0.4, (trunk_height + 0.4) * 0.5, _material(BARK))
	var foliage := _material(FOLIAGE.lightened(rng.randf_range(-0.05, 0.08)))
	var snow := _material(SNOW)
	var tiers := 3 + variant % 2
	var crown := height - trunk_height
	for i in tiers:
		var t := float(i) / float(tiers)
		var radius := lerpf(1.45, 0.55, t) * height / 5.0
		var tier := crown / float(tiers) * 1.5
		var base := trunk_height + crown * t * 0.85
		_cone(0.0, radius, tier, base + tier * 0.5, foliage)
		# Neige sur le haut de l'étage.
		_cone(0.0, radius * 0.72, tier * 0.55, base + tier * 0.72, snow)


func _cone(top: float, bottom: float, length: float, center: float, material: StandardMaterial3D) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = length
	mesh.radial_segments = 9
	mesh.rings = 1
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = Vector3(0, center, 0)
	add_child(instance)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	return material
