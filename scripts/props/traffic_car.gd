@tool
class_name TrafficCar
extends AnimatableBody3D
## Voiture civile (décor) : une berline qui roule en boucle sur un tracé de
## rues (déjà décalé sur la voie de droite et arrondi aux virages par
## `MapBuilder.traffic`). Elle ralentit puis s'arrête devant quelqu'un
## (opérateur, garde, VIP, passant) ou derrière une autre voiture, et
## repart. Elle ne passe jamais à travers une unité ; un passant ou une autre
## voiture, au bout de `MAX_WAIT` (pas d'embouteillage sans fin).
## Comme les figurants, elle ne voit rien et ne fait pas de bruit qui compte.
## Mais sa caisse est solide (couche des obstacles qui cachent la vue,
## comme un mur) : elle arrête le regard et les balles, et un opérateur
## accroupi ou couché derrière elle est à l'abri, tant qu'elle reste là.

const GROUP := &"traffic"
## Accélération et freinage (m/s²).
const ACCEL := 3.0
const BRAKE := 8.0
## Zone surveillée devant la voiture : distance (m) et demi-largeur (m).
const LOOK_AHEAD := 7.5
const HALF_WIDTH := 1.3
## Attente maximale (s) devant un obstacle.
const MAX_WAIT := 5.0
const TURN_SPEED := 3.0
const WHEEL_RADIUS := 0.32
## Couche des obstacles qui cachent la vue (murs, Sabre).
const LAYER_OCCLUDERS := 0b10
## Unités : la voiture les attend sans limite (elle ne les traverse pas).
const UNIT_GROUPS: Array[StringName] = [&"commandos", &"enemies", &"vips"]
## « S'abriter derrière » : la voiture reste arrêtée tant qu'un opérateur
## abrité est à moins de `HOLD_REACH` m, et au moins `HOLD_ARRIVAL` s (le
## temps qu'ils arrivent).
const HOLD_REACH := 3.5
const HOLD_ARRIVAL := 12.0
const HALF_WIDTH_BODY := 0.89
## Arrêtée (`halted`) depuis `HONK_DELAY` s, elle klaxonne, puis toutes les
## `HONK_INTERVAL` s : bruit qui attire les gardes à `HORN_NOISE` m, qui
## viennent voir à la portière du conducteur (sans donner l'alerte).
const HONK_DELAY := 5.0
const HONK_INTERVAL := 7.0
const HORN_NOISE := 22.0

## Coup de klaxon en `at` (point où les gardes viennent voir).
signal honked(at: Vector3)
## Demi-longueur de la voiture (m), du centre au pare-chocs.
const HALF_LENGTH := 2.2

## Boucle, au sol, dans le repère du parent.
@export var points: PackedVector3Array = PackedVector3Array()
## Distance (m) parcourue au départ le long de la boucle.
@export var start_at: float = 0.0
## Vitesse de croisière (m/s).
@export var cruise: float = 7.0
@export var look_seed: int = 0
## Éditeur : décalage appliqué aux enfants pour l'aperçu (`place_preview`).
var _preview_frame := Transform3D.IDENTITY

const BODY_COLORS: Array[Color] = [
	Color(0.75, 0.75, 0.73), Color(0.08, 0.08, 0.09), Color(0.55, 0.08, 0.08), Color(0.12, 0.2, 0.42),
	Color(0.85, 0.85, 0.82), Color(0.3, 0.32, 0.33), Color(0.2, 0.3, 0.22), Color(0.6, 0.5, 0.3),
]

var speed: float = 0.0
var _lengths: PackedFloat32Array = PackedFloat32Array()
var _total: float = 0.0
var _at: float = 0.0
var _waited: float = 0.0
var _wheels: Array[Node3D] = []
## Opérateurs abrités derrière la voiture (elle les attend), et depuis
## combien de temps (s).
var _holders: Array[Commando] = []
var _held_for: float = 0.0
## Arrêtée pour une unité, un abri ou une voiture elle-même arrêtée ainsi :
## les voitures derrière l'attendent sans limite.
var halted: bool = false
## Empreinte de la boucle : deux voitures de la même boucle se suivent le
## long du tracé (y compris dans les virages).
var _loop_key: int = 0
## Temps passé arrêtée (`halted`) avant le prochain coup de klaxon.
var _stopped_for: float = 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		# Aperçu au début de la boucle, sans déplacer le nœud (enregistré) :
		# la caisse est construite puis décalée.
		_build()
		place_preview()
		return
	add_to_group(GROUP)
	collision_layer = LAYER_OCCLUDERS
	collision_mask = 0
	sync_to_physics = false
	# Caisse jusqu'au ras du sol (un opérateur couché derrière est caché),
	# habitacle jusqu'au toit (1,38 m : un opérateur debout dépasse).
	_add_shape(Vector3(1.78, 0.74, 4.3), Vector3(0, 0.49, 0))
	_add_shape(Vector3(1.6, 0.55, 2.1), Vector3(0, 1.1, 0.25))
	_build()
	_lengths.append(0.0)
	for i in range(1, points.size() + 1):
		_total += points[i - 1].distance_to(points[i % points.size()])
		_lengths.append(_total)
	_at = fposmod(start_at, maxf(_total, 0.01))
	_loop_key = hash(points)
	if points.size() >= 2:
		position = _place(_at)
		rotation.y = _heading(_at)
	speed = cruise


## Éditeur : place la voiture au début de la boucle, en décalant ses enfants
## (le nœud, enregistré, ne bouge pas).
func place_preview() -> void:
	if points.size() < 2:
		return
	var heading := points[1] - points[0]
	var frame := Transform3D(Basis(Vector3.UP, atan2(-heading.x, -heading.z)), points[0] - position)
	var change := frame * _preview_frame.affine_inverse()
	for child in get_children():
		if child is Node3D:
			(child as Node3D).transform = change * (child as Node3D).transform
	_preview_frame = frame


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if points.size() < 2 or _total <= 0.0:
		return
	var held := _update_hold(delta)
	var unit_gap := minf(minf(_gap_ahead(UNIT_GROUPS), _halted_car_gap()), _vehicle_gap())
	var other_gap := _gap_ahead([Passerby.GROUP, GROUP])
	halted = held or unit_gap < LOOK_AHEAD
	var gap := 0.0 if held else unit_gap
	if other_gap < LOOK_AHEAD and _waited < MAX_WAIT:
		gap = minf(gap, other_gap)
	var target := cruise
	if gap < LOOK_AHEAD:
		# Freine pour s'arrêter à 1,5 m de l'obstacle.
		target = clampf((gap - 1.5) * 1.5, 0.0, cruise)
	if speed < 0.2 and target < 0.2 and unit_gap >= LOOK_AHEAD:
		_waited += delta
	elif other_gap >= LOOK_AHEAD:
		_waited = 0.0
	speed = move_toward(speed, target, (ACCEL if target > speed else BRAKE) * delta)
	var step := speed * delta
	_at = fposmod(_at + step, _total)
	position = _place(_at)
	rotation.y = rotate_toward(rotation.y, _heading(_at + 1.5), TURN_SPEED * delta * maxf(speed / cruise, 0.3))
	for wheel in _wheels:
		wheel.rotation.x -= step / WHEEL_RADIUS
	_update_horn(delta)


## Klaxonne quand elle reste bloquée (`HONK_DELAY`, puis `HONK_INTERVAL`).
func _update_horn(delta: float) -> void:
	if not halted or speed > 0.2:
		_stopped_for = 0.0
		return
	_stopped_for += delta
	if _stopped_for >= HONK_DELAY:
		_stopped_for = HONK_DELAY - HONK_INTERVAL
		honk()


## Coup de klaxon : les gardes à portée viennent voir à la portière du
## conducteur (côté gauche), au bord de la caisse.
func honk() -> void:
	var at := global_position - global_basis.x * (HALF_WIDTH_BODY + 0.9) - global_basis.z * 0.4
	at = NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, at)
	Sfx.play_at(&"horn", global_position + Vector3.UP * 0.8)
	EventBus.noise_emitted.emit(at, HORN_NOISE, &"distraction")
	honked.emit(at)


## Vrai tant que des opérateurs s'abritent derrière la voiture : près
## d'elle, ou depuis moins de `HOLD_ARRIVAL` s.
func _update_hold(delta: float) -> bool:
	if _holders.is_empty():
		return false
	_held_for += delta
	_holders = _holders.filter(func(unit: Commando) -> bool:
		return is_instance_valid(unit) and not unit.is_dead and unit.riding == null and unit.airborne_in == null)
	var near := _holders.any(func(unit: Commando) -> bool: return unit.global_position.distance_to(global_position) <= HOLD_REACH)
	if not near and _held_for > HOLD_ARRIVAL:
		_holders.clear()
	return not _holders.is_empty()


## Distance au pare-chocs d'une voiture arrêtée (`halted`) devant, dans la
## voie (`INF` sinon).
func _halted_car_gap() -> float:
	var forward := -global_basis.z
	var right := global_basis.x
	var nearest := INF
	for node in get_tree().get_nodes_in_group(GROUP):
		var other := node as TrafficCar
		if other == null or other == self or not other.halted:
			continue
		var ahead := _car_ahead(other, forward, right)
		if ahead < nearest:
			nearest = ahead
	return nearest


## Distance de pare-chocs à pare-chocs jusqu'à `other` s'il est devant, dans
## la voie (`INF` sinon) : le long du tracé pour une voiture de la même
## boucle, en ligne droite pour une autre.
func _car_ahead(other: TrafficCar, forward: Vector3, right: Vector3) -> float:
	if other._loop_key == _loop_key:
		var along := fposmod(other._at - _at, _total) - HALF_LENGTH * 2.0
		return maxf(along, 0.0) if along < LOOK_AHEAD else INF
	var offset := other.global_position - global_position
	var ahead := offset.dot(forward) - HALF_LENGTH * 2.0
	if ahead > -0.5 and absf(offset.dot(right)) < HALF_WIDTH:
		return maxf(ahead, 0.0)
	return INF


## Envoie `units` s'abriter derrière la voiture, accroupis : elle pile et
## les attend. Les places sont prises là où elle s'arrêtera.
func take_cover(units: Array[Commando], run: bool) -> bool:
	if units.is_empty():
		return false
	var stop := speed * speed / (2.0 * BRAKE)
	var frame := Transform3D(Basis(Vector3.UP, _heading(_at + stop + 1.5) if stop > 0.1 else rotation.y), _place(_at + stop))
	var threat := CoverSpots.threat_direction(get_tree(), frame.origin, -frame.basis.z)
	var spots := CoverSpots.points(get_world_3d(), frame, HALF_WIDTH_BODY, HALF_LENGTH, threat, units.size())
	CoverSpots.send(units, spots, run)
	_holders = units.duplicate()
	_held_for = 0.0
	last_cover_spots = spots
	return true


## Places attribuées au dernier « S'abriter derrière » (repères au sol).
var last_cover_spots: Array[Vector3] = []


## Distance (m) du pare-chocs avant au premier membre des groupes `groups`
## qui se trouve devant la voiture, dans sa voie (`INF` s'il n'y en a pas).
## Distance de pare-chocs jusqu'au véhicule de l'équipe ou ennemi (Sabre,
## hexapode, pick-up armé) le plus proche dans la voie, `INF` sinon : la
## voiture l'attend sans limite, comme une unité (pas de collision).
func _vehicle_gap() -> float:
	var forward := -global_basis.z
	var right := global_basis.x
	var nearest := INF
	for group: StringName in [Sabre.GROUP, Technical.GROUP]:
		for node in get_tree().get_nodes_in_group(group):
			var other := node as Node3D
			if other == null or not other.is_inside_tree() or not other.visible:
				continue
			var box: AABB = (other as Sabre).footprint() if other is Sabre else Technical.FOOTPRINT
			# Demi-diagonale de l'emprise : le véhicule peut être de biais.
			var reach := Vector2(box.size.x, box.size.z).length() * 0.5
			var offset := other.global_position - global_position
			if absf(offset.y) > 2.0:
				continue
			var ahead := offset.dot(forward) - HALF_LENGTH - reach
			if ahead > -HALF_LENGTH - reach and ahead < nearest and absf(offset.dot(right)) < HALF_WIDTH_BODY + reach:
				nearest = maxf(ahead, 0.0)
	return nearest


func _gap_ahead(groups: Array[StringName]) -> float:
	var forward := -global_basis.z
	var right := global_basis.x
	var nearest := INF
	for group: StringName in groups:
		for node in get_tree().get_nodes_in_group(group):
			var other := node as Node3D
			if other == null or other == self:
				continue
			if group == GROUP:
				nearest = minf(nearest, _car_ahead(other as TrafficCar, forward, right))
				continue
			var offset := other.global_position - global_position
			# Mesuré depuis le pare-chocs avant.
			var ahead := offset.dot(forward) - HALF_LENGTH
			if ahead > -0.5 and ahead < nearest and absf(offset.dot(right)) < HALF_WIDTH:
				nearest = maxf(ahead, 0.0)
	return nearest


func _place(at: float) -> Vector3:
	at = fposmod(at, _total)
	var segment := _segment(at)
	var a := points[segment]
	var b := points[(segment + 1) % points.size()]
	var span := _lengths[segment + 1] - _lengths[segment]
	return a.lerp(b, 0.0 if span <= 0.0 else (at - _lengths[segment]) / span)


## Cap (rotation y) vers le point du tracé situé à la distance `at`.
func _heading(at: float) -> float:
	var forward := _place(at) - position
	if forward.length() < 0.01:
		return rotation.y
	return atan2(-forward.x, -forward.z)


func _segment(at: float) -> int:
	for i in range(_lengths.size() - 1):
		if at <= _lengths[i + 1]:
			return i
	return _lengths.size() - 2


## Berline : caisse, capot et coffre plus bas, habitacle vitré sous un toit,
## pare-chocs, phares et feux, quatre roues (avant vers -Z).
func _build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = look_seed
	var paint := StandardMaterial3D.new()
	paint.albedo_color = BODY_COLORS[rng.randi() % BODY_COLORS.size()]
	paint.roughness = 0.3
	paint.metallic = 0.5
	var glass := _material(Color(0.1, 0.13, 0.17), 0.1, 0.6)
	var dark := _material(Color(0.07, 0.07, 0.07), 0.8, 0.0)
	var tyre := _material(Color(0.05, 0.05, 0.05), 0.9, 0.0)
	var rim := _material(Color(0.7, 0.71, 0.72), 0.3, 0.8)
	var head := _material(Color(1.0, 0.96, 0.85), 0.2, 0.0)
	head.emission_enabled = true
	head.emission = Color(1.0, 0.95, 0.8)
	head.emission_energy_multiplier = 0.6
	var tail := _material(Color(0.7, 0.05, 0.04), 0.3, 0.0)
	tail.emission_enabled = true
	tail.emission = Color(0.8, 0.05, 0.03)
	tail.emission_energy_multiplier = 0.5
	var body := Node3D.new()
	body.name = "Body"
	add_child(body)
	_box(body, Vector3(1.78, 0.5, 4.3), Vector3(0, 0.6, 0), paint)
	# Capot et coffre légèrement bombés, habitacle en retrait vers l'arrière.
	_box(body, Vector3(1.7, 0.08, 1.2), Vector3(0, 0.88, -1.45), paint).rotation.x = -0.06
	_box(body, Vector3(1.7, 0.08, 0.8), Vector3(0, 0.88, 1.7), paint)
	var cabin := _box(body, Vector3(1.6, 0.48, 2.1), Vector3(0, 1.08, 0.25), glass)
	cabin.scale = Vector3(1.0, 1.0, 1.0)
	_box(body, Vector3(1.62, 0.07, 1.6), Vector3(0, 1.35, 0.3), paint)
	# Montants du pare-brise et de la lunette (bandes de carrosserie).
	for z: float in [-0.75, 1.25]:
		_box(body, Vector3(1.62, 0.48, 0.08), Vector3(0, 1.08, z), paint)
	_box(body, Vector3(1.62, 0.44, 0.06), Vector3(0, 1.08, 0.3), paint)
	for z: float in [-2.17, 2.17]:
		_box(body, Vector3(1.82, 0.18, 0.12), Vector3(0, 0.42, z), dark)
	for side: float in [-1.0, 1.0]:
		_box(body, Vector3(0.36, 0.12, 0.04), Vector3(0.6 * side, 0.68, -2.16), head)
		_box(body, Vector3(0.34, 0.12, 0.04), Vector3(0.62 * side, 0.7, 2.16), tail)
		# Rétroviseurs.
		_box(body, Vector3(0.14, 0.09, 0.08), Vector3(0.88 * side, 1.0, -0.65), paint)
		for z: float in [-1.35, 1.35]:
			var wheel := Node3D.new()
			wheel.position = Vector3(0.8 * side, WHEEL_RADIUS, z)
			add_child(wheel)
			var tread := CylinderMesh.new()
			tread.top_radius = WHEEL_RADIUS
			tread.bottom_radius = WHEEL_RADIUS
			tread.height = 0.22
			var t := _mesh(wheel, tread, tyre)
			t.rotation.z = PI / 2.0
			var cap := CylinderMesh.new()
			cap.top_radius = 0.18
			cap.bottom_radius = 0.18
			cap.height = 0.23
			var c := _mesh(wheel, cap, rim)
			c.rotation.z = PI / 2.0
			# Rayon visible : la roue se voit tourner.
			_box(wheel, Vector3(0.235, 0.05, 0.3), Vector3.ZERO, dark)
			_wheels.append(wheel)


func _add_shape(size: Vector3, at: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = at
	add_child(shape)


func _material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material


func _box(parent: Node3D, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := _mesh(parent, mesh, material)
	instance.position = at
	return instance


func _mesh(parent: Node3D, mesh: Mesh, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)
	return instance
