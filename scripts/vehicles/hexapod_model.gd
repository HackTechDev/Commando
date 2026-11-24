@tool
class_name HexapodModel
extends SabreModel
## Marcheur hexapode blindé (`Hexapod`), construit en code : caisse sur six
## pattes articulées (hanche, cuisse, jambe), cabine de pilotage vitrée à
## l'avant, gatling à six canons sur le toit de la cabine (`gun_pivot`) et
## radar tournant derrière elle.
##
## Marche réaliste, déduite du mouvement réel du véhicule (`_process`) :
## - allure en tripode alterné : trois pieds au sol (avant et arrière d'un
##   côté, milieu de l'autre) pendant que les trois autres se lèvent et se
##   reposent plus loin, en anticipant le déplacement ; à l'arrêt, les pieds
##   restés en arrière se recalent ;
## - chaque pied posé reste fixe au sol (il ne glisse pas) ; la pose cherche
##   le sol (rayon vers le bas) ;
## - les pattes sont résolues en cinématique inverse (deux segments, genou
##   en l'air, comme un insecte) ;
## - la caisse suit les pieds : hauteur et assiette (tangage, roulis) selon
##   le terrain, léger rebond à chaque foulée et balancement vers le tripode
##   porteur ; elle s'incline un peu vers l'avant en marche.
## Un pied qui touche le sol émet `foot_down` (bruit, poussière).
##
## Hérite de `SabreModel` pour servir de modèle à `Hexapod` (un `Sabre`) :
## ni roues, ni arceau, ni 7,62.
##
## Repère : l'avant vers -Z, posé au sol (y = 0) ; 5 m d'envergure de
## pattes, 3,4 m au sommet du radar.

signal foot_down(at: Vector3)

## Hauteur de la caisse au repos (centre).
const BODY_HEIGHT := 1.35
## Pattes : hanches (repère de la caisse), longueurs de la hanche, de la
## cuisse et de la jambe, pieds au repos (repère du modèle, au sol).
const HIPS: Array[Vector3] = [
	Vector3(-0.85, -0.05, -0.95), Vector3(0.85, -0.05, -0.95),
	Vector3(-0.9, -0.05, 0.05), Vector3(0.9, -0.05, 0.05),
	Vector3(-0.85, -0.05, 1.05), Vector3(0.85, -0.05, 1.05),
]
const COXA := 0.35
const FEMUR := 1.05
const TIBIA := 1.5
const REST_FEET: Array[Vector3] = [
	Vector3(-2.2, 0.0, -1.85), Vector3(2.2, 0.0, -1.85),
	Vector3(-2.5, 0.0, 0.05), Vector3(2.5, 0.0, 0.05),
	Vector3(-2.2, 0.0, 1.95), Vector3(2.2, 0.0, 1.95),
]
## Tripodes : avant gauche, milieu droit, arrière gauche ; et l'inverse.
const TRIPODS: Array[Array] = [[0, 3, 4], [1, 2, 5]]
## Pas : écart (m) qui déclenche une foulée en marche, ou un recalage à
## l'arrêt ; anticipation (s) ; durée d'une foulée (s) au pas lent et au
## plus vite ; hauteur du pied levé (m).
const STEP_TRIGGER := 0.32
const SETTLE_TRIGGER := 0.1
const LEAD := 0.45
const SWING_SLOW := 0.5
const SWING_FAST := 0.3
const LIFT := 0.32
## Gatling : bouche dans le repère du pivot ; vitesse de rotation des
## canons (rad/s). Radar : tours par seconde.
const GATLING_MUZZLE := Vector3(0.0, 0.0, -1.45)
const BARREL_SPIN := 28.0
const RADAR_TURNS := 0.5
## Places (cabine et compartiment, dans le repère du modèle) : pilote,
## servant de la gatling, trois passagers.
const CREW_SEATS: Array[Vector3] = [
	Vector3(-0.3, 1.15, -0.7), Vector3(0.3, 1.15, -0.7), Vector3(-0.4, 1.15, 0.4),
	Vector3(0.4, 1.15, 0.4), Vector3(0.0, 1.15, 0.9),
]
const MASK_GROUND := 1

## Caisse (elle porte la cabine, la gatling et le radar).
var body: Node3D
var radar: Node3D
var barrels: Node3D
## Canons qui tournent encore (s) ; radar en marche.
var spin_left: float = 0.0
var radar_on: bool = true
## Effondré (épave) : la caisse tombe, les pattes s'écartent.
var collapsed: bool = false

var _coxae: Array[Node3D] = []
var _femurs: Array[Node3D] = []
var _tibias: Array[Node3D] = []
## Pieds : position (monde), foulée en cours (départ, arrivée, avancement).
var _feet: Array[Vector3] = []
var _from: Array[Vector3] = []
var _to: Array[Vector3] = []
var _swing: Array[float] = []
var _swinging_group: int = -1
var _last_group: int = 1
var _swing_time: float = SWING_SLOW
var _last_transform: Transform3D
var _velocity := Vector3.ZERO
var _turn_rate: float = 0.0
var _still_time: float = 0.0
var _started: bool = false
var _drop: float = 0.0


func _ready() -> void:
	_make_hex_materials()
	_build_hexapod()
	_rest_pose()


# --- Interface de `SabreModel` (sans objet ici) ------------------------------------

func roll(_distance: float) -> void:
	pass


func fold(_folded: bool) -> void:
	is_folded = false


func steer(_angle: float) -> void:
	pass


## Fait tourner les canons de la gatling un moment (une rafale).
func spin() -> void:
	spin_left = 0.8


## Épave : la caisse s'affaisse sur ses pattes.
func collapse() -> void:
	collapsed = true
	radar_on = false


# --- Construction ------------------------------------------------------------------

func _make_hex_materials() -> void:
	_materials[&"armor"] = _plain(Color(0.36, 0.39, 0.33), 0.75, 0.25)
	_materials[&"panel"] = _plain(Color(0.29, 0.31, 0.26), 0.8, 0.2)
	_materials[&"dark"] = _plain(Color(0.1, 0.1, 0.1), 0.65, 0.4)
	_materials[&"metal"] = _plain(Color(0.3, 0.31, 0.32), 0.4, 0.75)
	_materials[&"piston"] = _plain(Color(0.72, 0.74, 0.76), 0.25, 0.9)
	_materials[&"rubber"] = _plain(Color(0.06, 0.06, 0.06), 0.95, 0.0)
	_materials[&"stripe"] = _plain(Color(0.85, 0.62, 0.1), 0.6, 0.1)
	_materials[&"red"] = _glow(Color(0.95, 0.1, 0.05))
	_materials[&"green"] = _glow(Color(0.2, 0.95, 0.35))
	var glass := _plain(Color(0.25, 0.4, 0.45, 0.55), 0.05, 0.5)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	_materials[&"glass"] = glass


func _build_hexapod() -> void:
	body = Node3D.new()
	body.name = "Body"
	body.position = Vector3(0.0, BODY_HEIGHT, 0.0)
	add_child(body)
	_build_hull()
	_build_cabin()
	_commit("Hull", body)
	_build_gatling()
	_build_radar()
	for i in HIPS.size():
		_build_leg(i)


## Caisse blindée : plaques chanfreinées, ventre sombre, logements des
## hanches, bloc moteur à l'arrière, bandes de signalisation.
func _build_hull() -> void:
	_box(&"armor", Vector3(0.0, 0.0, 0.1), Vector3(1.7, 0.62, 2.7))
	_box(&"panel", Vector3(0.0, 0.36, 0.15), Vector3(1.5, 0.1, 2.5))
	_box(&"dark", Vector3(0.0, -0.4, 0.1), Vector3(1.3, 0.2, 2.3))
	# Chanfreins latéraux du dessus.
	for side: float in [-1.0, 1.0]:
		_quad(&"armor", Vector3(side * 0.85, 0.31, -1.25), Vector3(side * 0.75, 0.41, -1.15), Vector3(side * 0.75, 0.41, 1.4), Vector3(side * 0.85, 0.31, 1.45), Vector3(0.0, 0.0, 0.1))
		# Jupe le long du flanc, au-dessus des hanches.
		_box(&"panel", Vector3(side * 0.88, 0.12, 0.1), Vector3(0.08, 0.32, 2.4))
		_box(&"stripe", Vector3(side * 0.925, 0.12, -1.0), Vector3(0.02, 0.08, 0.5))
	for hip in HIPS:
		_cylinder(&"metal", hip + Vector3(0.0, -0.18, 0.0), hip + Vector3(0.0, 0.2, 0.0), 0.2, 12)
	# Bloc moteur et grilles à l'arrière, feux.
	_box(&"panel", Vector3(0.0, 0.5, 1.05), Vector3(1.2, 0.3, 0.8))
	for i in 4:
		_box(&"dark", Vector3(-0.42 + i * 0.28, 0.66, 1.05), Vector3(0.18, 0.02, 0.7))
	_box(&"dark", Vector3(0.0, 0.05, 1.47), Vector3(1.0, 0.4, 0.06))
	for side: float in [-1.0, 1.0]:
		_box(&"red", Vector3(side * 0.62, 0.22, 1.48), Vector3(0.14, 0.06, 0.03))


## Cabine de pilotage à l'avant : caisson, verrière à facettes, bandeau de
## phares, échelle d'accès.
func _build_cabin() -> void:
	var center := Vector3(0.0, 0.72, -0.55)
	_box(&"armor", center + Vector3(0.0, 0.0, 0.2), Vector3(1.3, 0.62, 0.9))
	# Nez incliné de la cabine : verrière (avant et côtés) dans un cadre.
	var a := Vector3(-0.62, 0.41, -1.3)
	var b := Vector3(0.62, 0.41, -1.3)
	var c := Vector3(0.6, 1.03, -0.95)
	var d := Vector3(-0.6, 1.03, -0.95)
	_quad(&"glass", a, b, c, d, center)
	for side: float in [-1.0, 1.0]:
		var low_front := Vector3(side * 0.62, 0.41, -1.3)
		var top_front := Vector3(side * 0.6, 1.03, -0.95)
		_tri(&"glass", low_front, top_front, Vector3(side * 0.65, 0.41, -0.85), center)
		_tri(&"glass", top_front, Vector3(side * 0.65, 1.03, -0.85), Vector3(side * 0.65, 0.41, -0.85), center)
		_cylinder(&"dark", low_front, top_front, 0.035, 6)
	_cylinder(&"dark", a, b, 0.035, 6)
	_cylinder(&"dark", c, d, 0.035, 6)
	_box(&"panel", Vector3(0.0, 1.06, -0.45), Vector3(1.32, 0.08, 1.2))
	# Bandeau de phares sous la verrière.
	_box(&"dark", Vector3(0.0, 0.33, -1.33), Vector3(1.1, 0.1, 0.06))
	# Échelons d'accès à l'arrière.
	for i in 3:
		_box(&"metal", Vector3(0.0, -0.25 - i * 0.28, 1.52), Vector3(0.5, 0.04, 0.05))


## Gatling à six canons sur un tourelleau, au toit de la cabine : boîtier,
## caisson de munitions, bande, canons en barillet (`barrels`, qui tournent
## au tir).
func _build_gatling() -> void:
	_cylinder(&"metal", Vector3(0.0, 1.1, -0.6), Vector3(0.0, 1.22, -0.6), 0.34, 14)
	_commit("TurretRing", body)
	gun_pivot = Node3D.new()
	gun_pivot.name = "GunPivot"
	gun_pivot.position = Vector3(0.0, 1.42, -0.6)
	body.add_child(gun_pivot)
	_box(&"panel", Vector3(0.0, -0.1, 0.0), Vector3(0.36, 0.14, 0.5))
	_box(&"dark", Vector3(0.0, 0.03, 0.05), Vector3(0.28, 0.24, 0.55))
	_box(&"armor", Vector3(0.3, 0.0, 0.12), Vector3(0.26, 0.3, 0.42))
	_cylinder(&"dark", Vector3(0.18, 0.08, 0.05), Vector3(0.03, 0.08, -0.15), 0.04, 6)
	_cylinder(&"metal", Vector3(0.0, 0.03, -0.22), Vector3(0.0, 0.03, -0.32), 0.13, 12)
	_commit("Gatling", gun_pivot)
	barrels = Node3D.new()
	barrels.name = "Barrels"
	barrels.position = Vector3(0.0, 0.03, -0.3)
	gun_pivot.add_child(barrels)
	for i in 6:
		var angle := TAU * i / 6.0
		var offset := Vector3(cos(angle), sin(angle), 0.0) * 0.075
		_cylinder(&"metal", offset, offset + Vector3(0.0, 0.0, -1.1), 0.024, 6)
	for z: float in [-0.35, -1.05]:
		_cylinder(&"dark", Vector3(0.0, 0.0, z + 0.03), Vector3(0.0, 0.0, z - 0.03), 0.11, 12)
	_commit("Cluster", barrels)


## Radar : mât sur l'arrière du toit de la cabine, antenne plate inclinée
## qui tourne (`radar`), voyant.
func _build_radar() -> void:
	_cylinder(&"metal", Vector3(0.0, 1.1, 0.0), Vector3(0.0, 1.85, 0.0), 0.05, 8)
	_cylinder(&"dark", Vector3(0.0, 1.02, 0.0), Vector3(0.0, 1.12, 0.0), 0.16, 10)
	_commit("RadarMast", body)
	radar = Node3D.new()
	radar.name = "Radar"
	radar.position = Vector3(0.0, 1.9, 0.0)
	body.add_child(radar)
	var dish := Node3D.new()
	dish.name = "Dish"
	dish.rotation.x = deg_to_rad(-20.0)
	radar.add_child(dish)
	_box(&"panel", Vector3(0.0, 0.08, 0.0), Vector3(1.0, 0.36, 0.05))
	_box(&"metal", Vector3(0.0, 0.08, 0.04), Vector3(0.9, 0.28, 0.02))
	for i in 5:
		_box(&"dark", Vector3(-0.36 + i * 0.18, 0.08, -0.03), Vector3(0.02, 0.3, 0.01))
	_cylinder(&"metal", Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.08, -0.3), 0.015, 5)
	_box(&"red", Vector3(0.0, 0.29, 0.0), Vector3(0.05, 0.04, 0.05))
	_commit("Antenna", dish)


## Patte `index` : hanche qui pivote (axe vertical), cuisse et jambe (axe
## horizontal) ; chaque segment pointe vers son +X.
func _build_leg(index: int) -> void:
	var side := -1.0 if HIPS[index].x < 0.0 else 1.0
	var coxa := Node3D.new()
	coxa.name = "Coxa%d" % index
	coxa.position = HIPS[index]
	body.add_child(coxa)
	_box(&"metal", Vector3(COXA * 0.5, 0.0, 0.0), Vector3(COXA, 0.18, 0.2))
	_commit("Hip", coxa)
	var femur := Node3D.new()
	femur.name = "Femur"
	femur.position = Vector3(COXA, 0.0, 0.0)
	coxa.add_child(femur)
	_cylinder(&"dark", Vector3(0.0, 0.0, -0.13), Vector3(0.0, 0.0, 0.13), 0.12, 10)
	_box(&"armor", Vector3(FEMUR * 0.5, 0.02, 0.0), Vector3(FEMUR, 0.17, 0.2))
	_box(&"panel", Vector3(FEMUR * 0.45, 0.12, 0.0), Vector3(FEMUR * 0.7, 0.05, 0.16))
	# Vérin hydraulique sous la cuisse.
	_cylinder(&"dark", Vector3(0.12, -0.12, 0.0), Vector3(FEMUR * 0.55, -0.12, 0.0), 0.045, 8)
	_cylinder(&"piston", Vector3(FEMUR * 0.55, -0.12, 0.0), Vector3(FEMUR * 0.88, -0.08, 0.0), 0.028, 8)
	_box(&"stripe", Vector3(FEMUR * 0.8, 0.02, 0.105 * side), Vector3(0.18, 0.1, 0.01))
	_commit("Thigh", femur)
	var tibia := Node3D.new()
	tibia.name = "Tibia"
	tibia.position = Vector3(FEMUR, 0.0, 0.0)
	femur.add_child(tibia)
	_cylinder(&"metal", Vector3(0.0, 0.0, -0.12), Vector3(0.0, 0.0, 0.12), 0.1, 10)
	_box(&"armor", Vector3(TIBIA * 0.42, 0.0, 0.0), Vector3(TIBIA * 0.84, 0.14, 0.16))
	_cylinder(&"piston", Vector3(TIBIA * 0.8, 0.0, 0.0), Vector3(TIBIA - 0.12, 0.0, 0.0), 0.04, 8)
	# Pied : patin articulé.
	_cylinder(&"rubber", Vector3(TIBIA - 0.06, 0.0, 0.0), Vector3(TIBIA, 0.0, 0.0), 0.16, 10)
	_commit("Shin", tibia)
	_coxae.append(coxa)
	_femurs.append(femur)
	_tibias.append(tibia)


# --- Marche ------------------------------------------------------------------------

## Pose de repos (éditeur, départ) : pieds à leur place, caisse à hauteur.
func _rest_pose() -> void:
	_feet.clear()
	_from.clear()
	_to.clear()
	_swing.clear()
	for i in REST_FEET.size():
		var foot := to_global(REST_FEET[i]) if is_inside_tree() else REST_FEET[i]
		_feet.append(foot)
		_from.append(foot)
		_to.append(foot)
		_swing.append(-1.0)
	if is_inside_tree():
		_solve_legs()


func _process(delta: float) -> void:
	if not is_inside_tree() or _feet.is_empty():
		return
	if Engine.is_editor_hint():
		for i in REST_FEET.size():
			_feet[i] = to_global(REST_FEET[i])
		body.position = Vector3(0.0, BODY_HEIGHT, 0.0)
		body.rotation = Vector3.ZERO
		_solve_legs()
		return
	if not _started:
		_started = true
		_last_transform = global_transform
		for i in REST_FEET.size():
			_feet[i] = _ground(to_global(REST_FEET[i]))
	_measure(delta)
	if collapsed:
		_drop = move_toward(_drop, 1.0, delta * 1.5)
	else:
		_update_gait(delta)
	_pose_body(delta)
	_solve_legs()
	if radar_on:
		radar.rotate_y(TAU * RADAR_TURNS * delta)
	if spin_left > 0.0:
		spin_left -= delta
		barrels.rotate_z(BARREL_SPIN * delta * clampf(spin_left / 0.3, 0.2, 1.0))


## Vitesse et rotation réelles du véhicule (lissées).
func _measure(delta: float) -> void:
	if delta <= 0.0:
		return
	var moved := global_position - _last_transform.origin
	moved.y = 0.0
	var turned := wrapf(global_rotation.y - _last_transform.basis.get_euler().y, -PI, PI)
	_velocity = _velocity.lerp(moved / delta, minf(1.0, delta * 8.0))
	_turn_rate = lerpf(_turn_rate, turned / delta, minf(1.0, delta * 8.0))
	_last_transform = global_transform
	if _velocity.length() < 0.05 and absf(_turn_rate) < 0.05:
		_still_time += delta
	else:
		_still_time = 0.0


## Où poser le pied `index` : sa place de repos, là où sera le véhicule un
## peu plus tard (`LEAD`), au sol.
func _target(index: int, lead: float) -> Vector3:
	var future := Transform3D(global_basis.rotated(Vector3.UP, _turn_rate * lead), global_position + _velocity * lead)
	return _ground(future * REST_FEET[index])


## Point du sol à la verticale de `point` (le point lui-même s'il n'y en a
## pas).
func _ground(point: Vector3) -> Vector3:
	var from := point + Vector3.UP * 2.5
	var query := PhysicsRayQueryParameters3D.create(from, point + Vector3.DOWN * 3.0, MASK_GROUND)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit["position"] if not hit.is_empty() else point


## Tripode alterné : quand aucun groupe n'est en l'air, celui dont un pied
## a pris le plus de retard (au-delà du seuil) se lève, et ses pieds filent
## vers leur prochaine place ; les autres restent plantés.
func _update_gait(delta: float) -> void:
	var speed := _velocity.length() + absf(_turn_rate) * 1.5
	if _swinging_group >= 0:
		var landed := true
		for index: int in TRIPODS[_swinging_group]:
			_swing[index] = minf(_swing[index] + delta / _swing_time, 1.0)
			var t := _swing[index]
			var eased := t * t * (3.0 - 2.0 * t)
			# La cible suit encore le véhicule pendant la foulée.
			_to[index] = _to[index].lerp(_target(index, LEAD * (1.0 - t)), minf(1.0, delta * 6.0))
			var foot := _from[index].lerp(_to[index], eased)
			foot.y += sin(t * PI) * LIFT * clampf(_from[index].distance_to(_to[index]) / 0.6, 0.4, 1.0)
			_feet[index] = foot
			if t < 1.0:
				landed = false
		if landed:
			for index: int in TRIPODS[_swinging_group]:
				_feet[index] = _to[index]
				_swing[index] = -1.0
				foot_down.emit(_to[index])
			_last_group = _swinging_group
			_swinging_group = -1
		return
	var moving := speed > 0.08
	if not moving and _still_time < 0.3:
		return
	var threshold := STEP_TRIGGER if moving else SETTLE_TRIGGER
	var worst := [0.0, 0.0]
	for group in TRIPODS.size():
		for index: int in TRIPODS[group]:
			var wanted := _target(index, LEAD if moving else 0.0)
			var gap := Vector2(wanted.x - _feet[index].x, wanted.z - _feet[index].z).length()
			worst[group] = maxf(worst[group], gap)
	# En marche, les tripodes alternent ; à l'arrêt, le plus en retard d'abord.
	var next := 1 - _last_group if moving else (0 if worst[0] >= worst[1] else 1)
	if worst[next] < threshold:
		next = 1 - next
		if worst[next] < threshold:
			return
	_swinging_group = next
	_swing_time = lerpf(SWING_SLOW, SWING_FAST, clampf(speed / 3.0, 0.0, 1.0))
	for index: int in TRIPODS[next]:
		_from[index] = _feet[index]
		_to[index] = _target(index, LEAD if moving else 0.0)
		_swing[index] = 0.0


## Caisse : hauteur et assiette d'après les pieds, rebond pendant la
## foulée, balancement vers le tripode porteur, penchée en avant en marche.
func _pose_body(delta: float) -> void:
	var local_feet: Array[Vector3] = []
	for foot in _feet:
		local_feet.append(to_local(foot))
	var front := (local_feet[0].y + local_feet[1].y) * 0.5
	var rear := (local_feet[4].y + local_feet[5].y) * 0.5
	var left := (local_feet[0].y + local_feet[2].y + local_feet[4].y) / 3.0
	var right := (local_feet[1].y + local_feet[3].y + local_feet[5].y) / 3.0
	var ground := 0.0
	for foot in local_feet:
		ground += foot.y
	ground /= local_feet.size()
	var bob := 0.0
	var sway := 0.0
	if _swinging_group >= 0:
		var t: float = _swing[TRIPODS[_swinging_group][0]]
		bob = sin(t * PI) * 0.045
		# Le poids passe sur le tripode porteur : milieu à gauche ou à droite.
		sway = sin(t * PI) * 0.04 * (1.0 if _swinging_group == 0 else -1.0)
	var forward_speed := (-global_basis.z).dot(_velocity)
	var height := lerpf(BODY_HEIGHT + bob, 0.55, _drop) + ground * 0.6
	var goal_position := Vector3(sway, height, 0.0)
	var goal_rotation := Vector3(
		atan2(front - rear, 3.4) - clampf(forward_speed, -3.0, 3.0) * 0.012,
		0.0,
		atan2(right - left, 4.0) - _turn_rate * 0.02 + _drop * 0.12)
	var k := minf(1.0, delta * 7.0)
	body.position = body.position.lerp(goal_position, k)
	body.rotation = body.rotation.lerp(goal_rotation, k)


## Cinématique inverse de chaque patte : la hanche s'oriente vers le pied,
## cuisse et jambe (genou en l'air) l'atteignent ; hors de portée, la patte
## se tend vers lui.
func _solve_legs() -> void:
	for i in _coxae.size():
		var coxa := _coxae[i]
		var hip := HIPS[i]
		var target := body.to_local(_feet[i]) if is_inside_tree() else _feet[i] - body.position
		if collapsed:
			# Épave : pattes écartées, à plat.
			target = hip + Vector3(signf(hip.x) * 1.9, -0.55 * _drop - 0.1, hip.z * 0.6)
		var flat := Vector2(target.x - hip.x, target.z - hip.z)
		coxa.rotation = Vector3(0.0, atan2(-flat.y, flat.x), 0.0)
		var local := coxa.transform.affine_inverse() * target
		var q := Vector2(local.x - COXA, local.y)
		var d := clampf(q.length(), 0.2, FEMUR + TIBIA - 0.02)
		var base := atan2(q.y, q.x)
		var hip_angle := acos(clampf((FEMUR * FEMUR + d * d - TIBIA * TIBIA) / (2.0 * FEMUR * d), -1.0, 1.0))
		var knee := acos(clampf((FEMUR * FEMUR + TIBIA * TIBIA - d * d) / (2.0 * FEMUR * TIBIA), -1.0, 1.0))
		_femurs[i].rotation = Vector3(0.0, 0.0, base + hip_angle)
		_tibias[i].rotation = Vector3(0.0, 0.0, -(PI - knee))
