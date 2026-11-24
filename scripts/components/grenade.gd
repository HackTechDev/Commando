class_name Grenade
extends Node3D
## Grenade lancée par un opérateur : vole en cloche jusqu'au point visé,
## roule un instant, puis explose (`Explosion`) ; fumigène (`smoke`), elle
## libère à la place un nuage (`SmokeCloud`) qui coupe la vue des ennemis ;
## assourdissante (`stun`), un éclair et une détonation qui sonnent les
## ennemis proches (`StunBurst`).

## Vitesse horizontale (m/s) et flèche de la cloche par mètre parcouru.
const SPEED := 10.0
const ARC_PER_METER := 0.22
const MIN_FLIGHT := 0.35
## Obus de 40 mm (lance-grenades M320) : plus rapide, trajectoire plus
## tendue, il éclate à l'impact (au sol ou contre un obstacle en vol).
const LAUNCHED_SPEED := 26.0
const LAUNCHED_ARC := 0.07
const LAUNCHED_RADIUS := 3.5
const LAUNCHED_DAMAGE := 140.0
## Ce qui arrête un obus en vol : sol et obstacles.
const MASK_IMPACT := 0b11

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
var stun: bool = false
## Obus tiré au lance-grenades (`launch`).
var launched: bool = false
## Obus lacrymogène : libère un nuage de gaz (`GasCloud`).
var gas: bool = false
## Corps que l'obus traverse (véhicule du tireur).
var _exclude: Array[RID] = []
var _ball: MeshInstance3D


## Lance une grenade de `from` vers `to`, avec les réglages de `stats`.
static func spawn(parent: Node, from: Vector3, to: Vector3, stats: UnitStats, is_smoke: bool = false, is_stun: bool = false) -> Grenade:
	var grenade := Grenade.new()
	grenade.smoke = is_smoke
	grenade.stun = is_stun
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


## Tire un obus de 40 mm `kind` (`Commando.SHELLS`) de `from` vers `to`
## (lance-grenades M320) : il éclate à l'impact, ou y libère son nuage (il
## traverse les corps de `exclude`).
static func launch(parent: Node, from: Vector3, to: Vector3, stats: UnitStats, exclude: Array[RID] = [], kind: StringName = Commando.SHELL_EXPLOSIVE) -> Grenade:
	var shell := spawn(parent, from, to, stats, kind == Commando.SHELL_SMOKE)
	shell.gas = kind == Commando.SHELL_GAS
	shell.launched = true
	shell._exclude = exclude
	var flat := Vector2(to.x - from.x, to.z - from.z).length()
	shell._duration = maxf(flat / LAUNCHED_SPEED, 0.1)
	shell._fuse = 0.0
	shell._radius = LAUNCHED_RADIUS
	shell._damage = LAUNCHED_DAMAGE
	return shell


## Vrai une fois la grenade retombée (elle explose `fuse` secondes après).
func has_landed() -> bool:
	return _landed


func _ready() -> void:
	_ball = MeshInstance3D.new()
	var material := StandardMaterial3D.new()
	if smoke or stun:
		var can := CylinderMesh.new()
		can.top_radius = 0.035
		can.bottom_radius = 0.035
		can.height = 0.14
		_ball.mesh = can
		material.albedo_color = Color(0.2, 0.22, 0.24) if stun else Color(0.42, 0.45, 0.4)
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
		var arc := LAUNCHED_ARC if launched else ARC_PER_METER
		var next := _from.lerp(_to, t) + Vector3.UP * 4.0 * flat * arc * t * (1.0 - t)
		if launched:
			var query := PhysicsRayQueryParameters3D.create(global_position, next, MASK_IMPACT, _exclude)
			var hit := get_world_3d().direct_space_state.intersect_ray(query)
			if not hit.is_empty():
				# Contre un mur : il éclate un peu en avant de la paroi.
				global_position = hit["position"] + (hit["normal"] as Vector3) * 0.15
				_burst()
				return
		global_position = next
		_ball.rotation.x += delta * 15.0
		if launched and t >= 1.0:
			_burst()
			return
		if t >= 1.0:
			_landed = true
			_time = 0.0
			Sfx.play_at(&"clink", global_position, -8.0)
		return
	if _time >= _fuse:
		_burst()


## Fin de la grenade : explosion, nuage ou éclair, selon son type.
func _burst() -> void:
	if gas:
		GasCloud.spawn(get_parent(), global_position)
	elif smoke:
		SmokeCloud.spawn(get_parent(), global_position)
	elif stun:
		StunBurst.detonate(get_parent(), global_position, _noise)
	else:
		Explosion.detonate(get_parent(), global_position, _radius, _damage, _noise)
	queue_free()
