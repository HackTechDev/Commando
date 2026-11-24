class_name ExplosiveCharge
extends Node3D
## Charge explosive posée au sol par un opérateur (K), qui la fait sauter à
## distance (L). Un voyant rouge clignote tant qu'elle est armée. Posée à
## retardement (Maj + K), elle saute d'elle-même au bout de `TIMED_FUSE`
## secondes : compte à rebours affiché, voyant qui clignote de plus en plus
## vite, bips des dernières secondes ; la mise à feu à distance reste
## possible.

const BLINK_PERIOD := 0.8
## Retard d'une charge à retardement (s).
const TIMED_FUSE := 10.0

## Opérateur qui l'a posée (il est seul à pouvoir la déclencher).
var planter: Commando
var _radius: float = 5.0
var _damage: float = 300.0
var _noise: float = 30.0
var _light: MeshInstance3D
var _time: float = 0.0
## Retard restant (s), ou négatif : mise à feu à distance seulement.
var fuse: float = -1.0
var _countdown: Label3D
var _last_beep: int = -1


## Pose une charge de `planter` à `at` ; à retardement si `delay` > 0.
static func plant(parent: Node, at: Vector3, by: Commando, delay: float = -1.0) -> ExplosiveCharge:
	var charge := ExplosiveCharge.new()
	charge.planter = by
	charge.fuse = delay
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
	if fuse > 0.0:
		_countdown = Label3D.new()
		_countdown.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_countdown.no_depth_test = true
		_countdown.fixed_size = true
		_countdown.pixel_size = 0.0018
		_countdown.font_size = 26
		_countdown.outline_size = 8
		_countdown.modulate = Color(1.0, 0.45, 0.35)
		_countdown.position = Vector3(0, 0.6, 0)
		add_child(_countdown)


## Vrai pour une charge à retardement.
func is_timed() -> bool:
	return fuse > 0.0


func _process(delta: float) -> void:
	_time += delta
	var period := BLINK_PERIOD
	if is_timed():
		fuse -= delta
		if fuse <= 0.0:
			detonate()
			return
		# Plus vite à l'approche de l'explosion.
		period = lerpf(0.15, BLINK_PERIOD, clampf(fuse / TIMED_FUSE, 0.0, 1.0))
		_countdown.text = "%d" % ceili(fuse)
		var second := ceili(fuse)
		if second <= 3 and second != _last_beep:
			_last_beep = second
			Sfx.play_at(&"arm", global_position + Vector3.UP * 0.2, -10.0)
	_light.visible = fmod(_time, period) < period * 0.4


## Fait sauter la charge.
func detonate() -> void:
	if is_queued_for_deletion():
		return
	Explosion.detonate(get_parent(), global_position, _radius, _damage, _noise)
	queue_free()
