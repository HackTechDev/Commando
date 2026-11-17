class_name Grenade
extends Node3D
## Grenade lancée par un opérateur : vole en cloche jusqu'au point visé,
## roule un instant, puis explose (`Explosion`) ; fumigène (`smoke`), elle
## libère à la place un nuage (`SmokeCloud`) qui coupe la vue des ennemis.

## Vitesse horizontale (m/s) et flèche de la cloche par mètre parcouru.
const SPEED := 10.0
const ARC_PER_METER := 0.22
const MIN_FLIGHT := 0.35

var _from: Vector3
var _to: Vector3
var _duration: float = 1.0
var _time: float = 0.0
var _fuse: float = 1.0
var _radius: float = 4.0
var _damage: float = 150.0
var _noise: float = 30.0
var _landed: bool = false
var smoke: bool = false
var _ball: MeshInstance3D


## Lance une grenade de `from` vers `to`, avec les réglages de `stats`.
static func spawn(parent: Node, from: Vector3, to: Vector3, stats: UnitStats, is_smoke: bool = false) -> Grenade:
	var grenade := Grenade.new()
	grenade.smoke = is_smoke
	grenade._from = from
	grenade._to = to
	var flat := Vector2(to.x - from.x, to.z - from.z).length()
	grenade._duration = maxf(flat / SPEED, MIN_FLIGHT)
	grenade._fuse = stats.grenade_fuse
	grenade._radius = stats.grenade_radius
	grenade._damage = stats.grenade_damage
	grenade._noise = stats.explosion_noise_radius
	parent.add_child(grenade)
	grenade.global_position = from
	return grenade


## Vrai une fois la grenade retombée (elle explose `fuse` secondes après).
func has_landed() -> bool:
	return _landed


func _ready() -> void:
	_ball = MeshInstance3D.new()
	var material := StandardMaterial3D.new()
	if smoke:
		var can := CylinderMesh.new()
		can.top_radius = 0.035
		can.bottom_radius = 0.035
		can.height = 0.14
		_ball.mesh = can
		material.albedo_color = Color(0.42, 0.45, 0.4)
	else:
		var sphere := SphereMesh.new()
		sphere.radius = 0.045
		sphere.height = 0.09
		_ball.mesh = sphere
		material.albedo_color = Color(0.2, 0.24, 0.16)
	material.roughness = 0.6
	_ball.material_override = material
	add_child(_ball)


func _physics_process(delta: float) -> void:
	_time += delta
	if not _landed:
		var t := minf(_time / _duration, 1.0)
		var flat := Vector2(_to.x - _from.x, _to.z - _from.z).length()
		global_position = _from.lerp(_to, t) + Vector3.UP * 4.0 * flat * ARC_PER_METER * t * (1.0 - t)
		_ball.rotation.x += delta * 15.0
		if t >= 1.0:
			_landed = true
			_time = 0.0
			Sfx.play_at(&"clink", global_position, -8.0)
		return
	if _time >= _fuse:
		if smoke:
			SmokeCloud.spawn(get_parent(), global_position)
		else:
			Explosion.detonate(get_parent(), global_position, _radius, _damage, _noise)
		queue_free()
