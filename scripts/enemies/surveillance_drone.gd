@tool
class_name SurveillanceDrone
extends StaticBody3D
## Drone de surveillance : petit quadricoptère en ronde aérienne, en boucle
## sur un chemin (`patrol_path`) à `altitude` m. Sa caméra regarde droit
## vers le bas : un disque au sol (`FOOTPRINT` m de rayon) montre ce qu'il
## voit, toits et hauteurs compris ; seuls un toit au-dessus de la tête,
## une cachette ou un mur en surplomb en protègent. Un opérateur à
## découvert dans le disque (pas un opérateur déguisé qui passe pour un
## garde) est repéré au bout de `SPOT_TIME` s : les gardes proches
## accourent.
##
## Une balle (tir libre, de préférence au silencieux) l'abat : il tombe et
## s'écrase. Un brouilleur (`Commando.use_jammer`) l'aveugle et le fige sur
## place `JAM_TIME` s : il fait du surplace, plus facile à abattre.
##
## Corps de la couche des obstacles (visée du tir libre) : à placer hors de
## la région de navigation (sous `Enemies`), pour qu'il n'entre pas dans le
## maillage.

const GROUP := &"drones"
const FOOTPRINT := 8.0
## Avance du disque devant le drone (m).
const LOOK_AHEAD := 1.5
const SPOT_TIME := 1.0
const ALARM_COOLDOWN := 10.0
const ALARM_RADIUS := 40.0
const JAM_TIME := 15.0
const TURN_RATE := 2.0
## Taille du modèle, et de la boîte touchée par les balles (généreuse : il
## est loin et bouge).
const MODEL_SCALE := 1.6
const HIT_SIZE := Vector3(1.8, 0.6, 1.8)
const FALL_GRAVITY := 14.0
const CRASH_NOISE := 14.0
const MASK_OCCLUDERS := 0b10
const MASK_GROUND := 0b01
const LAYER := 0b10

@export var patrol_path: NodePath
@export var altitude: float = 12.0
@export var speed: float = 4.5

var travelled: float = 0.0
var exposure: float = 0.0
## Abattu : il tombe, puis gît au sol.
var destroyed: bool = false
var jammed_left: float = 0.0
var model: Node3D
var _rotors: Array[Node3D] = []
var _led: MeshInstance3D
var _led_material: StandardMaterial3D
var _curve: Curve3D
var _path: Path3D
var _cooldown: float = 0.0
var _disc: MeshInstance3D
var _disc_material: StandardMaterial3D
var _spot := Vector3.ZERO
var _fall_speed: float = 0.0
var _landed: bool = false
var _time: float = 0.0


func _ready() -> void:
	model = build_model()
	add_child(model)
	model.scale = Vector3.ONE * MODEL_SCALE
	if Engine.is_editor_hint():
		place_preview.call_deferred()
		return
	add_to_group(GROUP)
	add_to_group(QuickSave.GROUP)
	collision_layer = LAYER
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = HIT_SIZE
	shape.shape = box
	add_child(shape)
	_disc = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = FOOTPRINT
	disc.bottom_radius = FOOTPRINT
	disc.height = 0.04
	disc.radial_segments = 40
	disc.rings = 1
	_disc.mesh = disc
	_disc_material = StandardMaterial3D.new()
	_disc_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_disc_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_disc_material.albedo_color = Color(0.55, 0.85, 1.0, 0.14)
	_disc.material_override = _disc_material
	_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_disc.top_level = true
	add_child(_disc)
	_path = get_node_or_null(patrol_path) as Path3D
	if _path:
		_curve = _path.curve
	_place(0.0)


## Quadricoptère : corps, quatre bras, rotors, caméra en boule, feu.
func build_model() -> Node3D:
	var root := Node3D.new()
	root.name = "DroneModel"
	var dark := _mat(Color(0.16, 0.17, 0.18), 0.5)
	var grey := _mat(Color(0.38, 0.4, 0.42), 0.6)
	_box(root, Vector3(0.34, 0.12, 0.46), Vector3.ZERO, grey)
	_box(root, Vector3(0.26, 0.05, 0.3), Vector3(0, 0.08, 0), dark)
	for i in 4:
		var angle := PI / 4.0 + i * PI / 2.0
		var dir := Vector3(sin(angle), 0.0, cos(angle))
		var arm := _box(root, Vector3(0.05, 0.04, 0.5), dir * 0.25, dark)
		arm.rotation.y = angle
		var tip := dir * 0.48
		_box(root, Vector3(0.07, 0.08, 0.07), tip + Vector3.UP * 0.02, dark)
		var rotor := Node3D.new()
		rotor.position = tip + Vector3.UP * 0.08
		root.add_child(rotor)
		var blur := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = 0.2
		disc.bottom_radius = 0.2
		disc.height = 0.006
		disc.radial_segments = 20
		blur.mesh = disc
		var blur_material := _mat(Color(0.1, 0.1, 0.1, 0.35), 0.5)
		blur_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		blur.material_override = blur_material
		rotor.add_child(blur)
		_box(rotor, Vector3(0.38, 0.01, 0.03), Vector3.ZERO, dark)
		_rotors.append(rotor)
		# Pieds.
		_box(root, Vector3(0.02, 0.14, 0.02), dir * 0.16 + Vector3.DOWN * 0.11, dark)
	var camera := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.07
	ball.height = 0.14
	camera.mesh = ball
	camera.material_override = _mat(Color(0.05, 0.05, 0.06), 0.2)
	camera.position = Vector3(0, -0.09, -0.14)
	root.add_child(camera)
	_led = MeshInstance3D.new()
	var dot := SphereMesh.new()
	dot.radius = 0.03
	dot.height = 0.06
	_led.mesh = dot
	_led_material = _mat(Color(1.0, 0.15, 0.1), 0.3)
	_led_material.emission_enabled = true
	_led_material.emission = Color(1.0, 0.15, 0.1)
	_led_material.emission_energy_multiplier = 3.0
	_led.material_override = _led_material
	_led.position = Vector3(0, 0.0, 0.25)
	root.add_child(_led)
	return root


static func _mat(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material


static func _box(parent: Node3D, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = at
	parent.add_child(mesh)
	return mesh


## Éditeur : montre le drone au début de son trajet, à son altitude (le
## nœud, enregistré, ne bouge pas).
func place_preview() -> void:
	var path := get_node_or_null(patrol_path) as Path3D
	if model == null or path == null or path.curve == null or path.curve.point_count == 0:
		return
	var start := path.to_global(path.curve.get_point_position(0))
	model.global_position = start + Vector3.UP * altitude


## Centre du disque vu par la caméra, au sol.
func spot() -> Vector3:
	return _spot


## Aveuglé par un brouilleur.
func is_jammed() -> bool:
	return jammed_left > 0.0


## Ce que voit la caméra (abattu ou brouillé : rien).
func is_watching() -> bool:
	return not destroyed and not is_jammed()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	for rotor in _rotors:
		rotor.rotation.y += delta * (0.0 if destroyed else 40.0)
	if destroyed:
		_fall(delta)
		return
	_cooldown = maxf(_cooldown - delta, 0.0)
	jammed_left = maxf(jammed_left - delta, 0.0)
	_place(0.0 if is_jammed() else delta)
	# Brouillé : il vacille sur place, feu orange clignotant, disque éteint.
	if is_jammed():
		model.rotation = Vector3(sin(_time * 7.0) * 0.12, 0.0, cos(_time * 5.0) * 0.12)
		_led_material.emission = Color(1.0, 0.6, 0.1) if fmod(_time, 0.4) < 0.2 else Color.BLACK
		_disc.visible = false
		exposure = 0.0
		return
	model.rotation = Vector3(-0.12, 0.0, 0.0)
	_led_material.emission = Color(1.0, 0.15, 0.1) if fmod(_time, 1.2) < 0.15 else Color(0.25, 0.03, 0.02)
	_disc.visible = true
	_watch(delta)


## Avance le long du chemin (boucle), cap vers la suite, disque au sol.
func _place(delta: float) -> void:
	if _curve and _curve.point_count >= 2:
		var length := _curve.get_baked_length()
		travelled = fposmod(travelled + speed * delta, length)
		var here := _path.to_global(_curve.sample_baked(travelled))
		var ahead := _path.to_global(_curve.sample_baked(fposmod(travelled + 3.0, length)))
		global_position = Vector3(here.x, here.y + altitude, here.z)
		var heading := Vector3(ahead.x - here.x, 0.0, ahead.z - here.z)
		if heading.length() > 0.01 and delta > 0.0:
			global_rotation.y = lerp_angle(global_rotation.y, atan2(-heading.x, -heading.z), minf(TURN_RATE * delta, 1.0))
		elif heading.length() > 0.01 and _spot == Vector3.ZERO:
			global_rotation.y = atan2(-heading.x, -heading.z)
	_spot = _ground_at(global_position - global_basis.z * LOOK_AHEAD)
	_disc.global_position = _spot + Vector3.UP * 0.07


func _ground_at(point: Vector3) -> Vector3:
	var from := Vector3(point.x, global_position.y - 1.0, point.z)
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * (altitude + 40.0), MASK_GROUND | MASK_OCCLUDERS, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit["position"] if not hit.is_empty() else Vector3(point.x, 0.0, point.z)


## Opérateurs à découvert dans le disque : exposition, puis alerte.
func _watch(delta: float) -> void:
	var seen: Commando
	for node in get_tree().get_nodes_in_group(&"commandos"):
		var unit := node as Commando
		if unit and exposed(unit):
			seen = unit
			break
	if seen and _cooldown <= 0.0:
		exposure = minf(exposure + delta / SPOT_TIME, 1.0)
		if exposure >= 1.0:
			_raise_alarm(seen)
	else:
		exposure = maxf(exposure - delta / SPOT_TIME, 0.0)
	var calm := Color(0.55, 0.85, 1.0)
	var color := calm.lerp(Color(1.0, 0.25, 0.15), exposure if _cooldown <= 0.0 else 1.0)
	color.a = 0.14 + 0.14 * exposure
	_disc_material.albedo_color = color


## Vrai si `unit` est dans le disque, à découvert, vu d'en haut.
func exposed(unit: Commando) -> bool:
	if unit.is_dead or unit.airborne_in or unit.riding or unit.passes_as_guard():
		return false
	var flat := Vector2(unit.global_position.x - _spot.x, unit.global_position.z - _spot.z)
	if flat.length() > FOOTPRINT:
		return false
	var chest := unit.global_position + Vector3.UP * 0.6
	if HidingSpot.at(get_tree(), chest) != null:
		return false
	for roof in get_tree().get_nodes_in_group(&"roofs"):
		if roof is Roof and (roof as Roof).covers(unit.global_position + Vector3.UP * 0.3):
			return false
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.DOWN * 0.5, chest, MASK_OCCLUDERS, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## Repéré : les gardes proches accourent vers l'opérateur.
func _raise_alarm(unit: Commando) -> void:
	exposure = 0.0
	_cooldown = ALARM_COOLDOWN
	unit.flash_message("Repéré par le drone")
	Sfx.play_at(&"alert", unit.global_position + Vector3.UP, 0.0)
	EventBus.unit_spotted.emit(unit, self)
	EventBus.noise_emitted.emit(unit.global_position, ALARM_RADIUS, &"help")


## Brouilleur : aveugle et figé `seconds` s.
func jam(seconds: float = JAM_TIME) -> void:
	if destroyed:
		return
	jammed_left = maxf(jammed_left, seconds)
	Sfx.play_at(&"zap", global_position, -6.0)


## Une balle le touche : il tombe.
func take_shot(_damage: float, at: Vector3, _from: Vector3) -> void:
	if destroyed:
		return
	destroyed = true
	_disc.visible = false
	_led_material.emission = Color.BLACK
	collision_layer = 0
	Sfx.play_at(&"impact", at, -2.0)


## Chute, puis écrasement au sol (bruit entendu alentour).
func _fall(delta: float) -> void:
	if _landed:
		return
	_fall_speed += FALL_GRAVITY * delta
	model.rotation += Vector3(1.5, 2.5, 0.8) * delta
	var ground := _ground_at(global_position) if is_inside_tree() else Vector3.ZERO
	var next := global_position.y - _fall_speed * delta
	if next <= ground.y + 0.15:
		_landed = true
		global_position.y = ground.y + 0.15
		model.rotation = Vector3(0.0, model.rotation.y, 2.6)
		Sfx.play_at(&"thump", global_position, 0.0)
		EventBus.noise_emitted.emit(global_position, CRASH_NOISE, &"impact")
		return
	global_position.y = next


func save_state() -> Dictionary:
	return {"travelled": travelled, "cooldown": _cooldown, "destroyed": destroyed, "jammed": jammed_left, "position": global_position, "landed": _landed}


func load_state(data: Dictionary) -> void:
	travelled = data.get("travelled", travelled)
	_cooldown = data.get("cooldown", 0.0)
	jammed_left = data.get("jammed", 0.0)
	exposure = 0.0
	var was: bool = data.get("destroyed", false)
	if was and not destroyed:
		destroyed = true
		_disc.visible = false
		collision_layer = 0
		_led_material.emission = Color.BLACK
	if destroyed:
		global_position = data.get("position", global_position)
		_landed = data.get("landed", true)
		return
	_place(0.0)
