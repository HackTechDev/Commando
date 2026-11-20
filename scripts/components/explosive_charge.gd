class_name ExplosiveCharge
extends Node3D
## Charge explosive posée au sol par un opérateur (K), qui la fait sauter à
## distance (L). Un voyant rouge clignote tant qu'elle est armée.

const BLINK_PERIOD := 0.8

## Opérateur qui l'a posée (il est seul à pouvoir la déclencher).
var planter: Commando
var _radius: float = 5.0
var _damage: float = 300.0
var _noise: float = 30.0
var _light: MeshInstance3D
var _time: float = 0.0


## Pose une charge de `planter` à `at`.
static func plant(parent: Node, at: Vector3, by: Commando) -> ExplosiveCharge:
	var charge := ExplosiveCharge.new()
	charge.planter = by
	charge._radius = by.stats.explosive_radius
	charge._damage = by.stats.explosive_damage
	charge._noise = by.stats.explosion_noise_radius
	parent.add_child(charge)
	charge.global_position = at
	return charge


## Charges posées par `unit` et encore en place.
static func planted_by(tree: SceneTree, unit: Commando) -> Array[ExplosiveCharge]:
	var result: Array[ExplosiveCharge] = []
	if tree == null:
		return result
	for node in tree.get_nodes_in_group(&"explosive_charges"):
		var charge := node as ExplosiveCharge
		if charge and charge.planter == unit and not charge.is_queued_for_deletion():
			result.append(charge)
	return result


func _ready() -> void:
	add_to_group(&"explosive_charges")
	var block := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.22, 0.1, 0.14)
	block.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.62, 0.55, 0.38)
	material.roughness = 0.85
	block.material_override = material
	block.position.y = 0.05
	add_child(block)
	_light = MeshInstance3D.new()
	var bulb := SphereMesh.new()
	bulb.radius = 0.018
	bulb.height = 0.036
	_light.mesh = bulb
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(1.0, 0.15, 0.1)
	_light.material_override = glow
	_light.position = Vector3(0.06, 0.11, 0.0)
	add_child(_light)


func _process(delta: float) -> void:
	_time += delta
	_light.visible = fmod(_time, BLINK_PERIOD) < BLINK_PERIOD * 0.4


## Fait sauter la charge.
func detonate() -> void:
	if is_queued_for_deletion():
		return
	Explosion.detonate(get_parent(), global_position, _radius, _damage, _noise)
	queue_free()
