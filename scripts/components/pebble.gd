class_name Pebble
extends Node3D
## Caillou lancé pour faire diversion : vole en cloche jusqu'au point visé,
## y tombe avec un bruit sec (`&"distraction"`) qui attire les ennemis
## proches, puis disparaît.

const SPEED := 11.0
const ARC_PER_METER := 0.18
const MIN_FLIGHT := 0.3
## Rayon (m) dans lequel les ennemis entendent le caillou tomber.
const NOISE_RADIUS := 7.0
## Temps (s) pendant lequel le caillou reste visible au sol.
const LINGER := 4.0

var _from: Vector3
var _to: Vector3
var _duration: float = 1.0
var _time: float = 0.0
var _landed: bool = false
var _stone: MeshInstance3D


## Lance un caillou de `from` vers `to`.
static func spawn(parent: Node, from: Vector3, to: Vector3) -> Pebble:
	var pebble := Pebble.new()
	pebble._from = from
	pebble._to = to
	pebble._duration = maxf(Vector2(to.x - from.x, to.z - from.z).length() / SPEED, MIN_FLIGHT)
	parent.add_child(pebble)
	pebble.global_position = from
	return pebble


## Vrai une fois le caillou retombé.
func has_landed() -> bool:
	return _landed


func _ready() -> void:
	_stone = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.035
	sphere.height = 0.055
	_stone.mesh = sphere
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.45, 0.43, 0.4)
	material.roughness = 0.95
	_stone.material_override = material
	add_child(_stone)


func _physics_process(delta: float) -> void:
	_time += delta
	if _landed:
		if _time >= LINGER:
			queue_free()
		return
	var t := minf(_time / _duration, 1.0)
	var flat := Vector2(_to.x - _from.x, _to.z - _from.z).length()
	global_position = _from.lerp(_to, t) + Vector3.UP * 4.0 * flat * ARC_PER_METER * t * (1.0 - t)
	_stone.rotation.x += delta * 12.0
	if t >= 1.0:
		_landed = true
		_time = 0.0
		Sfx.play_at(&"clink", global_position, -2.0)
		EventBus.noise_emitted.emit(global_position, NOISE_RADIUS, &"distraction")
