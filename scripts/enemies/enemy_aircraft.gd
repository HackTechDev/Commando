@tool
class_name EnemyAircraft
extends Node3D
## Convertible ennemi en patrouille : il suit en boucle un chemin
## (`patrol_path`) à `altitude` m. Sous lui, un cercle au sol montre ce qu'il
## voit : de jour, sous et devant l'appareil ; de nuit, la tache de son
## projecteur, qui balaie de part et d'autre. Un opérateur à découvert dans
## le cercle (ni dans une cachette, ni sous un toit, ni masqué par un mur)
## est repéré au bout de `SPOT_TIME` s : l'alerte est donnée autour de lui.
## Hors d'atteinte : on ne peut que l'éviter.

const GROUP := &"enemy_aircraft"
## Rayon du cercle de détection (m), de jour et de nuit (projecteur).
const DAY_RADIUS := 10.0
const NIGHT_RADIUS := 7.0
## Avance du cercle devant l'appareil (m) ; balayage du projecteur (m, s).
const LOOK_AHEAD := 6.0
const SWEEP := 6.0
const SWEEP_PERIOD := 7.0
## Temps d'exposition pour être repéré (s), puis délai avant une nouvelle
## alerte (s), rayon de l'alerte (m).
const SPOT_TIME := 0.5
const ALARM_COOLDOWN := 10.0
const ALARM_RADIUS := 45.0
## Vitesse de virage (rad/s, lissage du cap).
const TURN_RATE := 1.2
const MASK_OCCLUDERS := 0b10
const MASK_GROUND := 0b11

@export var patrol_path: NodePath
@export var altitude: float = 25.0
@export var speed: float = 7.0
@export var tail_number: String = "66"

## Avancement le long du chemin (m) ; exposition en cours (0 à 1).
var travelled: float = 0.0
var exposure: float = 0.0
var model: TiltrotorModel
var _curve: Curve3D
var _path: Path3D
var _cooldown: float = 0.0
var _sweep_time: float = 0.0
var _night: bool = false
var _disc: MeshInstance3D
var _disc_material: StandardMaterial3D
var _light: SpotLight3D
var _spot := Vector3.ZERO


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group(GROUP)
	add_to_group(QuickSave.GROUP)


func _ready() -> void:
	if Engine.is_editor_hint():
		model = TiltrotorModel.new()
		model.livery = TiltrotorModel.Livery.GREY
		model.tail_number = tail_number
		add_child(model)
		model.scale = Vector3.ONE * Tiltrotor.SCALE
		model.set_ramp_closed(true)
		place_preview.call_deferred()
		return
	_night = LevelRoot.is_night(self)
	model = TiltrotorModel.new()
	model.livery = TiltrotorModel.Livery.GREY
	model.tail_number = tail_number
	model.rotor_speed = Tiltrotor.FLIGHT_ROTOR_SPEED
	add_child(model)
	model.scale = Vector3.ONE * Tiltrotor.SCALE
	model.set_ramp_closed(true)
	_disc = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.04
	disc.radial_segments = 40
	disc.rings = 1
	_disc.mesh = disc
	_disc_material = StandardMaterial3D.new()
	_disc_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_disc_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_disc_material.albedo_color = Color(1.0, 0.95, 0.7, 0.16)
	_disc.material_override = _disc_material
	_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_disc.top_level = true
	add_child(_disc)
	_disc.scale = Vector3(radius(), 1.0, radius())
	if _night:
		_light = SpotLight3D.new()
		_light.light_color = Color(1.0, 0.96, 0.85)
		_light.light_energy = 6.0
		_light.spot_range = altitude * 2.5
		_light.shadow_enabled = true
		_light.top_level = true
		add_child(_light)
	_path = get_node_or_null(patrol_path) as Path3D
	if _path:
		_curve = _path.curve
	_place(0.0)


## Rayon du cercle de détection (m).
func radius() -> float:
	return NIGHT_RADIUS if _night else DAY_RADIUS


## Centre du cercle de détection, au sol.
func spot() -> Vector3:
	return _spot


## Éditeur : montre l'avion au début de son trajet, à son altitude, tourné
## vers le point suivant (le nœud, enregistré, ne bouge pas).
func place_preview() -> void:
	var path := get_node_or_null(patrol_path) as Path3D
	if model == null or path == null or path.curve == null or path.curve.point_count == 0:
		return
	var curve := path.curve
	var start := path.to_global(curve.get_point_position(0))
	var ahead := path.to_global(curve.get_point_position(1)) if curve.point_count > 1 else start + Vector3.FORWARD
	var heading := ahead - start
	model.global_transform = Transform3D(Basis(Vector3.UP, atan2(-heading.x, -heading.z)), start + Vector3.UP * altitude)
	model.scale = Vector3.ONE * Tiltrotor.SCALE


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_cooldown = maxf(_cooldown - delta, 0.0)
	_sweep_time += delta
	_place(delta)
	_watch(delta)


## Avance le long du chemin (boucle), cap vers la suite, cercle au sol.
func _place(delta: float) -> void:
	if _curve and _curve.point_count >= 2:
		var length := _curve.get_baked_length()
		travelled = fposmod(travelled + speed * delta, length)
		var here := _path.to_global(_curve.sample_baked(travelled))
		var ahead := _path.to_global(_curve.sample_baked(fposmod(travelled + 4.0, length)))
		global_position = Vector3(here.x, here.y + altitude, here.z)
		var heading := Vector3(ahead.x - here.x, 0.0, ahead.z - here.z)
		if heading.length() > 0.01:
			var yaw := atan2(-heading.x, -heading.z)
			global_rotation.y = yaw if delta == 0.0 else lerp_angle(global_rotation.y, yaw, minf(TURN_RATE * delta, 1.0))
	var forward := -global_basis.z
	var side := global_basis.x
	var aim := global_position + forward * LOOK_AHEAD
	if _night:
		aim += side * sin(_sweep_time * TAU / SWEEP_PERIOD) * SWEEP
	_spot = _ground_at(aim)
	_disc.global_position = _spot + Vector3.UP * 0.06
	if _light:
		var from := global_position + Vector3.DOWN * 0.5 + forward * 4.0
		_light.global_position = from
		_light.look_at(_spot, Vector3.FORWARD if absf((_spot - from).normalized().y) > 0.99 else Vector3.UP)
		var reach := from.distance_to(_spot)
		_light.spot_range = reach + 6.0
		_light.spot_angle = rad_to_deg(atan(radius() / maxf(reach, 1.0)))


func _ground_at(point: Vector3) -> Vector3:
	var from := Vector3(point.x, global_position.y - 2.0, point.z)
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * (altitude + 40.0), MASK_GROUND)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit["position"] if not hit.is_empty() else Vector3(point.x, 0.0, point.z)


## Opérateurs à découvert dans le cercle : exposition, puis alerte.
func _watch(delta: float) -> void:
	var seen: Commando
	for node in get_tree().get_nodes_in_group(&"commandos"):
		var unit := node as Commando
		if unit and _exposed(unit):
			seen = unit
			break
	if seen and _cooldown <= 0.0:
		exposure = minf(exposure + delta / SPOT_TIME, 1.0)
		if exposure >= 1.0:
			_raise_alarm(seen)
	else:
		exposure = maxf(exposure - delta / SPOT_TIME, 0.0)
	var alarm := Color(1.0, 0.25, 0.15)
	var calm := Color(1.0, 0.95, 0.7)
	var color := calm.lerp(alarm, exposure if _cooldown <= 0.0 else 1.0)
	color.a = 0.16 + 0.14 * exposure
	_disc_material.albedo_color = color


## Vrai si `unit` est dans le cercle, ni caché ni à couvert, vu d'en haut.
func _exposed(unit: Commando) -> bool:
	if unit.is_dead or unit.airborne_in or unit.riding:
		return false
	var flat := Vector2(unit.global_position.x - _spot.x, unit.global_position.z - _spot.z)
	if flat.length() > radius():
		return false
	var chest := unit.global_position + Vector3.UP * 0.6
	if HidingSpot.at(get_tree(), chest) != null:
		return false
	for roof in get_tree().get_nodes_in_group(&"roofs"):
		if roof is Roof and (roof as Roof).covers(unit.global_position + Vector3.UP * 0.3):
			return false
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.DOWN * 1.0, chest, MASK_OCCLUDERS)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## Repéré : l'alerte part autour de l'opérateur, les gardes accourent.
func _raise_alarm(unit: Commando) -> void:
	exposure = 0.0
	_cooldown = ALARM_COOLDOWN
	unit.flash_message("Repéré par l'appareil ennemi")
	Sfx.play_at(&"alert", unit.global_position + Vector3.UP, 0.0)
	EventBus.unit_spotted.emit(unit, self)
	EventBus.noise_emitted.emit(unit.global_position, ALARM_RADIUS, &"help")


## Sauvegarde rapide (`QuickSave`).
func save_state() -> Dictionary:
	return {"travelled": travelled, "cooldown": _cooldown}


func load_state(data: Dictionary) -> void:
	travelled = data.get("travelled", travelled)
	_cooldown = data.get("cooldown", 0.0)
	exposure = 0.0
	_place(0.0)
