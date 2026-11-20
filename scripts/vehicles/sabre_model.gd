class_name SabreModel
extends FacetModel
## Véhicule léger des forces spéciales, d'après l'Arquus Sabre (4×4 ouvert
## dérivé du Sherpa Light), construit en code : capot à facettes, pare-brise,
## caisse ouverte (portières basses, plancher), arceau et tourelleau
## annulaire portant une mitrailleuse de 12,7 mm (`gun_pivot`), mitrailleuses
## de 7,62 mm à l'avant droit et à l'arrière gauche, tube de missile
## antichar, roue de secours, jerricans, sacs et antennes. Les roues tournent
## (`roll`), celles de devant braquent (`steer`). Pour le transport aérien
## (`fold`), l'arceau et le tourelleau s'abaissent, les antennes se rabattent.
##
## Repère : l'avant vers -Z, posé au sol (y = 0) ; 4,9 m de long, 2,2 m de
## large, 2,4 m au sommet de l'arceau.

enum Livery { SAND, OLIVE }

## Roues : centre (x, z), rayon, largeur.
const WHEELS: Array[Vector2] = [Vector2(-0.98, -1.55), Vector2(0.98, -1.55), Vector2(-0.98, 1.55), Vector2(0.98, 1.55)]
const WHEEL_RADIUS := 0.52
const WHEEL_WIDTH := 0.38
## Plancher de la caisse (où se tiennent les opérateurs à bord).
const FLOOR := 0.98
## Caisse ouverte : de la cloison du moteur à l'arrière de l'habitacle.
const CREW_FRONT := -0.95
const CREW_BACK := 1.05
const HALF_WIDTH := 1.05
## Tourelleau : centre de l'anneau.
const RING := Vector3(0.0, 2.2, 0.3)
## Places (position au plancher) : conducteur, tireur de la tourelle,
## chef de bord (avant droit), arrière gauche, arrière droit.
const SEATS: Array[Vector3] = [
	Vector3(-0.5, FLOOR, -0.35), Vector3(0.0, FLOOR, 0.35), Vector3(0.5, FLOOR, -0.35),
	Vector3(-0.55, FLOOR, 0.8), Vector3(0.55, FLOOR, 0.8),
]
## Abaissement de l'arceau replié (m) et inclinaison des antennes rabattues
## vers l'arrière (rad).
const CAGE_DROP := 0.6
const ANTENNA_FOLD := 1.35
## Bouche de la 12,7 dans le repère de son pivot.
const GUN_MUZZLE := Vector3(0.0, 0.08, -1.55)

@export var livery: Livery = Livery.SAND

## Pivot de la 12,7 (bouche vers -Z).
var gun_pivot: Node3D
## Roues (nœuds qui tournent) et pivots de braquage des roues avant.
var wheels: Array[Node3D] = []
var steer_pivots: Array[Node3D] = []
## Arceau et tourelleau (abaissés au transport) ; pied des antennes.
var cage: Node3D
var antennas: Node3D
var is_folded: bool = false


func _ready() -> void:
	_make_materials()
	_build()


## Fait tourner les roues pour une distance parcourue (m, négative en
## marche arrière).
func roll(distance: float) -> void:
	for wheel in wheels:
		wheel.rotate_x(-distance / WHEEL_RADIUS)


## Replie (`folded`) ou déploie l'arceau, le tourelleau et les antennes.
func fold(folded: bool) -> void:
	is_folded = folded
	cage.position.y = -CAGE_DROP if folded else 0.0
	antennas.rotation.x = ANTENNA_FOLD if folded else 0.0


## Braque les roues avant de `angle` (rad, positif vers la gauche).
func steer(angle: float) -> void:
	for pivot in steer_pivots:
		pivot.rotation.y = angle


func _make_materials() -> void:
	var body := Color(0.6, 0.53, 0.38) if livery == Livery.SAND else Color(0.33, 0.36, 0.26)
	_materials[&"body"] = _plain(body, 0.85, 0.1)
	_materials[&"panel"] = _plain(body.darkened(0.18), 0.85, 0.1)
	_materials[&"dark"] = _plain(Color(0.09, 0.09, 0.09), 0.7, 0.3)
	_materials[&"metal"] = _plain(Color(0.22, 0.23, 0.22), 0.5, 0.6)
	_materials[&"tyre"] = _plain(Color(0.05, 0.05, 0.05), 0.95, 0.0)
	_materials[&"hub"] = _plain(body.darkened(0.3), 0.7, 0.2)
	_materials[&"canvas"] = _plain(Color(0.42, 0.4, 0.3), 0.95, 0.0)
	_materials[&"jerrican"] = _plain(Color(0.27, 0.3, 0.2), 0.8, 0.1)
	_materials[&"seat"] = _plain(Color(0.14, 0.13, 0.12), 0.9, 0.0)
	_materials[&"white"] = _glow(Color(1.0, 0.95, 0.85))
	_materials[&"red"] = _glow(Color(0.9, 0.08, 0.05))
	var glass := _plain(Color(0.45, 0.55, 0.6, 0.35), 0.1, 0.3)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	_materials[&"glass"] = glass


func _build() -> void:
	_build_hull()
	_build_crew_area()
	_build_rear()
	_build_side_guns()
	_commit("Body")
	cage = Node3D.new()
	cage.name = "Cage"
	add_child(cage)
	_build_cage()
	_commit("Frame", cage)
	_build_turret()
	_build_antennas()
	for i in WHEELS.size():
		_build_wheel(i)


# --- Pièces -----------------------------------------------------------------

## Châssis, capot à facettes (le moteur à l'avant), calandre, pare-chocs,
## treuil, phares, ailes.
func _build_hull() -> void:
	_box(&"dark", Vector3(0, 0.62, 0.0), Vector3(1.5, 0.3, 4.4))
	# Capot : du pare-chocs à la cloison, il monte vers le pare-brise.
	var hood: Array[PackedVector3Array] = [
		ring(Vector3(0, 0, -2.45), Vector3.RIGHT, Vector3.UP, 0.92, 0.62, 1.12, 0.12, 0.12),
		ring(Vector3(0, 0, -2.3), Vector3.RIGHT, Vector3.UP, 1.04, 0.56, 1.28, 0.14, 0.1),
		ring(Vector3(0, 0, CREW_FRONT), Vector3.RIGHT, Vector3.UP, 1.08, 0.56, 1.42, 0.12, 0.1),
	]
	_loft(hood, func(_section: int, _segment: int) -> StringName: return &"body")
	# Calandre à lames, phares, pare-chocs et treuil.
	for i in 5:
		_box(&"dark", Vector3(0, 0.76 + i * 0.075, -2.47), Vector3(0.9, 0.035, 0.03))
	for side: float in [-1.0, 1.0]:
		_box(&"white", Vector3(side * 0.72, 1.0, -2.46), Vector3(0.2, 0.12, 0.03))
		_box(&"dark", Vector3(side * 0.72, 1.0, -2.44), Vector3(0.26, 0.18, 0.03))
	_box(&"dark", Vector3(0, 0.5, -2.56), Vector3(2.0, 0.2, 0.18))
	_box(&"metal", Vector3(0, 0.5, -2.68), Vector3(0.5, 0.16, 0.1))
	# Ailes au-dessus des roues, débordant de la caisse.
	for wheel in WHEELS:
		var side := signf(wheel.x)
		_box(&"panel", Vector3(side * 1.1, 1.14, wheel.y), Vector3(0.3, 0.06, 1.3))
		_box(&"panel", Vector3(side * 1.22, 1.02, wheel.y), Vector3(0.06, 0.2, 1.3))
	# Bas de caisse entre les roues (marchepied).
	for side: float in [-1.0, 1.0]:
		_box(&"dark", Vector3(side * 1.08, 0.55, 0.0), Vector3(0.12, 0.08, 1.8))


## Habitacle ouvert : plancher, portières basses, cloison, pare-brise,
## tableau de bord, volant, sièges.
func _build_crew_area() -> void:
	var length := CREW_BACK - CREW_FRONT
	var middle := (CREW_BACK + CREW_FRONT) * 0.5
	_box(&"panel", Vector3(0, FLOOR - 0.04, middle), Vector3(HALF_WIDTH * 2.0, 0.08, length))
	for side: float in [-1.0, 1.0]:
		# Portières basses en deux parties, poignée.
		_box(&"body", Vector3(side * HALF_WIDTH, 1.12, middle), Vector3(0.08, 0.56, length))
		_box(&"panel", Vector3(side * (HALF_WIDTH + 0.045), 1.12, middle - 0.02), Vector3(0.01, 0.5, 0.02))
		_box(&"dark", Vector3(side * (HALF_WIDTH + 0.05), 1.28, -0.45), Vector3(0.03, 0.04, 0.16))
		_box(&"dark", Vector3(side * (HALF_WIDTH + 0.05), 1.28, 0.55), Vector3(0.03, 0.04, 0.16))
	# Tableau de bord et volant.
	_box(&"dark", Vector3(0, 1.48, CREW_FRONT + 0.12), Vector3(2.0, 0.14, 0.26))
	_cylinder(&"dark", Vector3(-0.5, 1.42, -0.62), Vector3(-0.5, 1.5, -0.7), 0.17, 10)
	# Pare-brise incliné dans son cadre.
	var glass_bottom := 1.5
	var glass_top := 1.98
	_quad(&"glass", Vector3(-0.98, glass_bottom, CREW_FRONT + 0.02), Vector3(0.98, glass_bottom, CREW_FRONT + 0.02),
		Vector3(0.98, glass_top, CREW_FRONT + 0.16), Vector3(-0.98, glass_top, CREW_FRONT + 0.16), Vector3(0, 1.7, 0.5))
	for side: float in [-1.0, 1.0]:
		_cylinder(&"dark", Vector3(side * 1.0, 1.42, CREW_FRONT), Vector3(side * 1.0, glass_top + 0.03, CREW_FRONT + 0.17), 0.035, 6)
	_cylinder(&"dark", Vector3(-1.0, glass_top + 0.03, CREW_FRONT + 0.17), Vector3(1.0, glass_top + 0.03, CREW_FRONT + 0.17), 0.035, 6)
	_box(&"dark", Vector3(0, glass_bottom, CREW_FRONT + 0.02), Vector3(2.0, 0.05, 0.05))
	# Sièges baquets (le tireur de la tourelle est debout).
	for i in SEATS.size():
		if i == 1:
			continue
		var seat := SEATS[i]
		_box(&"seat", seat + Vector3(0, 0.22, 0.05), Vector3(0.46, 0.12, 0.46))
		_box(&"seat", seat + Vector3(0, 0.55, 0.3), Vector3(0.46, 0.6, 0.1))
		_box(&"dark", seat + Vector3(0, 0.08, 0.05), Vector3(0.36, 0.16, 0.36))


## Arceau de sécurité, rails latéraux et tourelleau annulaire.
func _build_cage() -> void:
	var top := 2.25
	var hoop_z := CREW_BACK - 0.05
	for side: float in [-1.0, 1.0]:
		_cylinder(&"metal", Vector3(side * 1.0, FLOOR, hoop_z), Vector3(side * 0.96, top, hoop_z), 0.045, 8)
		# Rail du haut du pare-brise à l'arceau, renfort en diagonale.
		_cylinder(&"metal", Vector3(side * 1.0, 2.01, CREW_FRONT + 0.17), Vector3(side * 0.96, top, hoop_z), 0.04, 8)
		_cylinder(&"metal", Vector3(side * 0.96, top, hoop_z), Vector3(side * 0.62, RING.y, RING.z), 0.035, 6)
	_cylinder(&"metal", Vector3(-0.96, top, hoop_z), Vector3(0.96, top, hoop_z), 0.045, 8)
	# Anneau du tourelleau (octogone de tubes) et bouclier bas devant.
	var corners := 10
	for i in corners:
		var a := TAU * i / corners
		var b := TAU * (i + 1) / corners
		_cylinder(&"metal", RING + Vector3(cos(a), 0, sin(a)) * 0.62, RING + Vector3(cos(b), 0, sin(b)) * 0.62, 0.05, 6)
	_cylinder(&"metal", RING + Vector3(0.62, 0, 0), Vector3(1.0, 2.01, RING.z - 0.2), 0.035, 6)
	_cylinder(&"metal", RING + Vector3(-0.62, 0, 0), Vector3(-1.0, 2.01, RING.z - 0.2), 0.035, 6)


## Plateau arrière : ridelles, roue de secours, jerricans, sacs, tube de
## missile, antennes, feux.
func _build_rear() -> void:
	var front := CREW_BACK
	var back := 2.45
	var middle := (front + back) * 0.5
	_box(&"panel", Vector3(0, FLOOR + 0.02, middle), Vector3(HALF_WIDTH * 2.0, 0.08, back - front))
	for side: float in [-1.0, 1.0]:
		_box(&"body", Vector3(side * HALF_WIDTH, 1.18, middle), Vector3(0.08, 0.42, back - front))
		# Jerricans le long des ridelles.
		for i in 2:
			_box(&"jerrican", Vector3(side * (HALF_WIDTH + 0.12), 1.15, front + 0.45 + i * 0.4), Vector3(0.16, 0.46, 0.34))
			_box(&"dark", Vector3(side * (HALF_WIDTH + 0.12), 1.41, front + 0.45 + i * 0.4), Vector3(0.05, 0.05, 0.1))
		_box(&"red", Vector3(side * 0.8, 0.95, back + 0.01), Vector3(0.16, 0.1, 0.03))
	_box(&"body", Vector3(0, 1.15, back), Vector3(HALF_WIDTH * 2.0, 0.36, 0.08))
	# Roue de secours sur le hayon.
	_cylinder(&"tyre", Vector3(0.35, 1.1, back + 0.05), Vector3(0.35, 1.1, back + 0.35), WHEEL_RADIUS * 0.95, 14)
	_cylinder(&"hub", Vector3(0.35, 1.1, back + 0.34), Vector3(0.35, 1.1, back + 0.37), 0.26, 10)
	# Sacs et caisses arrimés, tube du missile antichar sur le côté gauche.
	_box(&"canvas", Vector3(0.3, 1.25, middle - 0.1), Vector3(0.7, 0.45, 0.5))
	_box(&"canvas", Vector3(0.25, 1.62, middle - 0.05), Vector3(0.5, 0.3, 0.4))
	_box(&"jerrican", Vector3(-0.35, 1.2, middle + 0.3), Vector3(0.55, 0.36, 0.45))
	_cylinder(&"jerrican", Vector3(-0.62, 1.48, front + 0.1), Vector3(-0.62, 1.48, back - 0.05), 0.11, 10)
	_cylinder(&"dark", Vector3(-0.62, 1.48, front + 0.05), Vector3(-0.62, 1.48, front + 0.12), 0.125, 10)


## Mitrailleuses de 7,62 mm sur bras pivotants : chef de bord (avant droit,
## vers l'avant) et arrière gauche (vers l'arrière).
func _build_side_guns() -> void:
	for gun: Array in [[Vector3(1.0, 1.45, -0.55), Vector3(0.25, 0.0, -1.0)], [Vector3(-1.0, 1.45, 1.2), Vector3(-0.35, 0.0, 1.0)]]:
		var mount: Vector3 = gun[0]
		var aim: Vector3 = (gun[1] as Vector3).normalized()
		_cylinder(&"metal", mount, mount + Vector3.UP * 0.3, 0.03, 6)
		var breech := mount + Vector3.UP * 0.34
		_box(&"dark", breech, Vector3(0.1, 0.12, 0.1))
		_cylinder(&"dark", breech - aim * 0.25, breech + aim * 0.35, 0.05, 6)
		_cylinder(&"dark", breech + aim * 0.35, breech + aim * 1.05, 0.022, 6)
		_box(&"jerrican", breech + Vector3(0, -0.12, 0) + aim.cross(Vector3.UP) * 0.1, Vector3(0.1, 0.12, 0.16))


## Mitrailleuse de 12,7 mm sur son pivot, au centre de l'anneau : affût,
## boîtier, canon à cache-flamme, poignées, caisse de munitions, bouclier.
func _build_turret() -> void:
	gun_pivot = Node3D.new()
	gun_pivot.name = "GunPivot"
	gun_pivot.position = RING + Vector3.UP * 0.05
	cage.add_child(gun_pivot)
	_cylinder(&"metal", Vector3(0, -0.05, 0), Vector3(0, 0.0, 0), 0.12, 10)
	_box(&"dark", Vector3(0, 0.08, -0.15), Vector3(0.2, 0.18, 0.7))
	_cylinder(&"dark", Vector3(0, 0.08, -0.5), Vector3(0, 0.08, -1.45), 0.045, 8)
	_cylinder(&"dark", Vector3(0, 0.08, -1.4), Vector3(0, 0.08, -1.56), 0.07, 8)
	_box(&"dark", Vector3(0, 0.08, 0.28), Vector3(0.28, 0.05, 0.05))
	_box(&"jerrican", Vector3(0.18, 0.02, -0.15), Vector3(0.14, 0.2, 0.3))
	_box(&"panel", Vector3(0, 0.12, -0.62), Vector3(0.62, 0.42, 0.04))
	_commit("Gun", gun_pivot)


## Antennes aux coins arrière, sur un pied commun qui les rabat.
func _build_antennas() -> void:
	antennas = Node3D.new()
	antennas.name = "Antennas"
	antennas.position = Vector3(0, 1.4, 2.35)
	add_child(antennas)
	for side: float in [-1.0, 1.0]:
		_cylinder(&"dark", Vector3(side * 0.95, 0, 0), Vector3(side * 0.98, 2.0, 0.04), 0.012, 4)
	_commit("Whips", antennas)


## Roue `index` : pivot de braquage (roues avant), roue qui tourne (pneu,
## jante, moyeu), suspension.
func _build_wheel(index: int) -> void:
	var at := WHEELS[index]
	var side := signf(at.x)
	var steer := Node3D.new()
	steer.name = "Steer%d" % index
	steer.position = Vector3(at.x, WHEEL_RADIUS, at.y)
	add_child(steer)
	if at.y < 0.0:
		steer_pivots.append(steer)
	var wheel := Node3D.new()
	wheel.name = "Wheel%d" % index
	steer.add_child(wheel)
	wheels.append(wheel)
	var half := WHEEL_WIDTH * 0.5
	_cylinder(&"tyre", Vector3(-half, 0, 0), Vector3(half, 0, 0), WHEEL_RADIUS, 16)
	# Crampons : barrettes en travers de la bande de roulement.
	for i in 12:
		var a := TAU * i / 12.0
		var around := Vector3(0, sin(a), cos(a)) * (WHEEL_RADIUS + 0.01)
		_box(&"tyre", around, Vector3(WHEEL_WIDTH * 0.9, 0.05, 0.05))
	_cylinder(&"hub", Vector3(side * half, 0, 0), Vector3(side * (half + 0.02), 0, 0), WHEEL_RADIUS * 0.55, 10)
	_cylinder(&"dark", Vector3(side * (half + 0.02), 0, 0), Vector3(side * (half + 0.07), 0, 0), 0.1, 8)
	_commit("Tyre", wheel)
	# Bras de suspension vers le châssis (fixe).
	_cylinder(&"dark", Vector3(-side * 0.1, 0, 0), Vector3(-side * 0.32, 0.12, 0), 0.05, 6)
	_commit("Arm", steer)
