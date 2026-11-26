@tool
class_name CommandCenter
extends Node3D
## Centre de commandement mobile (images de référence :
## `CommandoAsset/vehicles/commandcenter`) : deux porteurs blindés 8 × 8
## côte à côte, en tête, et une longue remorque sur vérins. Décor fixe,
## construit en code, en deux versions :
## - **replié** (`deployed` faux) : le module de commandement, à section
##   hexagonale, perché sur des colonnes au-dessus du plateau de la
##   remorque, avec ses deux gros caissons d'extrémité (celui de l'avant
##   au-dessus des cabines), sa tour de contrôle et ses antennes. Deux
##   escaliers mènent au plateau, couvert par le module ; un troisième, sur
##   le plateau, mène à la coursive du flanc, devant les portes éclairées ;
## - **déployé** (`deployed` vrai) : les flancs rabattus forment un grand
##   pont de 34 × 20 m sur vérins, bordé de garde-corps jaunes et de jupes,
##   où l'on monte par quatre escaliers. Sur le pont, la salle des
##   opérations (un `Tower` d'un étage : portes, fenêtres, escalier
##   intérieur, coupe) porte un toit-terrasse avec la tourelle de défense
##   rapprochée, la tour de contrôle et un mât d'antennes. On peut se glisser
##   sous le pont (2,1 m de haut) par les bouts et entre les jupes.
##
## Repère : centré sur le milieu du véhicule, au sol ; porteurs vers -X.
## Plateau, pont, coursive et escaliers sont des sols (couches 1 et 2 : la
## navigation les suit, ils arrêtent la vue) ; le reste arrête le passage, la
## vue et les balles (couche 2). Chaque pièce est un corps à part, pour que
## l'occlusion (`OcclusionFader`) n'estompe que celle qui cache un opérateur.

## Sols (marche, clics, navigation) et obstacles (vue, balles).
const LAYER_FLOOR := 0b11
const LAYER_OBSTACLE := 0b10
## Dessus du plateau (replié) ou du pont (déployé), et épaisseur.
const DECK_TOP := 2.4
const DECK_THICKNESS := 0.3
## Plateau replié : x de -12 à 21, z de -4,2 à 4,2.
const BED := Rect2(-12.0, -4.2, 33.0, 8.4)
## Pont déployé : x de -12 à 22, z de -10 à 10.
const DECK := Rect2(-12.0, -10.0, 34.0, 20.0)
## Coursive du module replié (dessus) et son emprise (x, z).
const BALCONY_TOP := 5.0
const BALCONY := Rect2(-9.0, 2.0, 15.0, 1.8)
const RAIL_HEIGHT := 1.0
## Escaliers : pente (degrés, sous celle de la navigation) et largeur (m).
const STAIR_SLOPE := 31.0
const STAIR_WIDTH := 1.6
## Salle des opérations du pont déployé : centre (x, z), emprise, hauteur.
const OPS_CENTER := Vector2(4.0, -4.0)
const OPS_SIZE := Vector2(20.0, 9.0)
const OPS_HEIGHT := 3.2

const OLIVE := Color(0.37, 0.39, 0.25)
const OLIVE_DARK := Color(0.27, 0.29, 0.19)
const STEEL := Color(0.42, 0.43, 0.44)
const DARK := Color(0.1, 0.1, 0.1)
const YELLOW := Color(0.92, 0.72, 0.12)
const LAMP := Color(1.0, 0.68, 0.25)
const GLASS := Color(0.16, 0.22, 0.26)

## Pont déployé (vrai) ou module replié sur la remorque (faux).
@export var deployed: bool = false:
	set(value):
		deployed = value
		_queue_rebuild()
## Numéro peint sur les caissons et les porteurs.
@export var hull_number: String = "07":
	set(value):
		hull_number = value
		_queue_rebuild()

## Salle des opérations (déployé seulement).
var ops_room: Tower

var _rebuild_queued: bool = false
var _materials: Dictionary = {}


func _ready() -> void:
	_build()


## Hauteur du sol praticable du véhicule sous (x, z) du monde (plateau, pont,
## coursive, toit de la salle), ou -INF (pose des unités et des objets).
func floor_at(point: Vector3) -> float:
	var local := to_local(point)
	var at := Vector2(local.x, local.z)
	if deployed:
		var ops := Rect2(OPS_CENTER - OPS_SIZE * 0.5, OPS_SIZE)
		if ops.has_point(at) and local.y > DECK_TOP + OPS_HEIGHT - 0.5:
			return global_position.y + DECK_TOP + OPS_HEIGHT
		return global_position.y + DECK_TOP if DECK.has_point(at) else -INF
	if BALCONY.has_point(at) and local.y > BALCONY_TOP - 0.5:
		return global_position.y + BALCONY_TOP
	return global_position.y + DECK_TOP if BED.has_point(at) else -INF


## Réglage changé dans l'éditeur : reconstruit.
func _queue_rebuild() -> void:
	if not is_node_ready() or _rebuild_queued:
		return
	_rebuild_queued = true
	_rebuild.call_deferred()


func _rebuild() -> void:
	_rebuild_queued = false
	for child in get_children():
		if child.owner == null:
			remove_child(child)
			child.queue_free()
	ops_room = null
	_build()


func _build() -> void:
	for z: float in [-2.0, 2.0]:
		_build_truck(z)
	_build_chassis()
	if deployed:
		_build_deck()
	else:
		_build_bed()
		_build_module()


# --- Porteurs et remorque -------------------------------------------------------

## Porteur 8 × 8 blindé, centré en z, de x = -21,5 à -12,5.
func _build_truck(z: float) -> void:
	var body := _body("Truck%s" % ("L" if z < 0.0 else "R"), LAYER_OBSTACLE)
	body.position = Vector3(-17.0, 0.0, z)
	_collide(body, Vector3(9.0, 3.3, 3.1), Vector3(0, 1.65, 0))
	# Châssis, caisse à nez anguleux, toit à pans coupés.
	_mesh(body, Vector3(8.8, 0.5, 2.5), Vector3(0.1, 0.95, 0), _mat(OLIVE_DARK))
	var profile := PackedVector2Array([Vector2(-4.5, 1.15), Vector2(-4.5, 2.0), Vector2(-3.3, 2.85), Vector2(-1.4, 3.2), Vector2(4.4, 3.2), Vector2(4.4, 1.15)])
	_prism(body, profile, -1.35, 1.35, [Vector3.RIGHT, Vector3.UP, Vector3.BACK], _mat(OLIVE))
	var roof := PackedVector2Array([Vector2(-1.15, 3.2), Vector2(-0.7, 3.45), Vector2(0.7, 3.45), Vector2(1.15, 3.2)])
	_prism(body, roof, -1.6, 4.2, [Vector3.BACK, Vector3.UP, Vector3.RIGHT], _mat(OLIVE))
	# Pare-brise étroit, calandre, phares bleutés, feux orange.
	_mesh(body, Vector3(0.08, 0.32, 2.2), Vector3(-3.95, 2.48, 0), _mat(GLASS, 0.2), Basis(Vector3.BACK, deg_to_rad(-55.0)))
	_mesh(body, Vector3(0.08, 0.35, 2.0), Vector3(-4.53, 1.55, 0), _mat(DARK))
	for side: float in [-1.0, 1.0]:
		_mesh(body, Vector3(0.06, 0.1, 0.32), Vector3(-4.54, 1.25, side * 0.95), _glow(Color(0.55, 0.8, 1.0)))
		_mesh(body, Vector3(0.06, 0.08, 0.2), Vector3(-4.54, 1.95, side * 1.1), _glow(LAMP))
		_label(body, hull_number, Vector3(-2.6, 2.35, side * 1.37), side, 0.012)
	# Quatre essieux.
	for x: float in [-2.7, -1.25, 1.0, 2.45]:
		for side: float in [-1.0, 1.0]:
			_wheel(body, Vector3(x, 0.72, side * 1.12), 0.72)


## Poutre de la remorque et ses huit roues arrière, sous le plateau ou le pont.
func _build_chassis() -> void:
	var body := _body("Chassis", LAYER_OBSTACLE)
	_collide(body, Vector3(33.0, 1.4, 5.0), Vector3(4.5, 1.2, 0))
	_mesh(body, Vector3(33.0, 0.8, 2.2), Vector3(4.5, 1.45, 0), _mat(OLIVE_DARK))
	_mesh(body, Vector3(33.0, 0.25, 4.8), Vector3(4.5, 1.78, 0), _mat(OLIVE_DARK))
	# Attelage vers les porteurs.
	_mesh(body, Vector3(1.6, 0.6, 1.0), Vector3(-12.3, 1.4, -2.0), _mat(STEEL, 0.5))
	_mesh(body, Vector3(1.6, 0.6, 1.0), Vector3(-12.3, 1.4, 2.0), _mat(STEEL, 0.5))
	for x: float in [10.5, 12.0, 13.5, 15.0]:
		for side: float in [-1.0, 1.0]:
			_wheel(body, Vector3(x, 0.72, side * 2.05), 0.72)


# --- Version repliée ------------------------------------------------------------

## Plateau de la remorque : sol en quatre dalles, garde-corps, vérins, deux
## escaliers depuis le sol.
func _build_bed() -> void:
	var tiles := 4
	var width := BED.size.x / tiles
	for i in tiles:
		var tile := _body("Bed%d" % i, LAYER_FLOOR)
		var x := BED.position.x + width * (i + 0.5)
		_box(tile, Vector3(width, DECK_THICKNESS, BED.size.y), Vector3(x, DECK_TOP - DECK_THICKNESS * 0.5, BED.get_center().y), _mat(OLIVE_DARK))
		_mesh(tile, Vector3(width - 0.1, 0.02, BED.size.y - 0.4), Vector3(x, DECK_TOP + 0.01, BED.get_center().y), _mat(STEEL, 0.6))
		# Feux sous la tranche.
		for side: float in [-1.0, 1.0]:
			_mesh(tile, Vector3(0.5, 0.08, 0.04), Vector3(x, DECK_TOP - 0.3, side * (BED.size.y * 0.5 + 0.01)), _glow(LAMP))
	var near_z := BED.end.y
	var far_z := BED.position.y
	# Escaliers : flanc +Z à x = -6, flanc -Z à x = 16.
	_stair(Vector3(-6.0, DECK_TOP, near_z), Vector3.BACK, DECK_TOP)
	_stair(Vector3(16.0, DECK_TOP, far_z), Vector3.FORWARD, DECK_TOP)
	var gap := STAIR_WIDTH + 0.2
	_rail_run("RailBedR", Vector3(BED.position.x, DECK_TOP, near_z - 0.06), Vector3(BED.end.x, DECK_TOP, near_z - 0.06), [Vector2(-6.0 - BED.position.x - gap * 0.5, -6.0 - BED.position.x + gap * 0.5)])
	_rail_run("RailBedL", Vector3(BED.position.x, DECK_TOP, far_z + 0.06), Vector3(BED.end.x, DECK_TOP, far_z + 0.06), [Vector2(16.0 - BED.position.x - gap * 0.5, 16.0 - BED.position.x + gap * 0.5)])
	_rail_run("RailBedBack", Vector3(BED.end.x - 0.06, DECK_TOP, far_z), Vector3(BED.end.x - 0.06, DECK_TOP, near_z), [])
	# Vérins sous le plateau.
	var legs := _body("BedLegs", LAYER_OBSTACLE)
	for x: float in [-10.5, 3.5, 19.5]:
		for side: float in [-1.0, 1.0]:
			_leg(legs, Vector3(x, 0, side * 3.9), DECK_TOP - DECK_THICKNESS)


## Module de commandement replié, au-dessus du plateau : corps central,
## caissons d'extrémité, colonnes, coursive et son escalier, tour, antennes.
func _build_module() -> void:
	var olive := _mat(OLIVE)
	# Corps central à section hexagonale, en retrait côté +Z (coursive).
	var core := _body("Module", LAYER_OBSTACLE)
	_collide(core, Vector3(24.0, 4.2, 5.6), Vector3(1.0, 7.1, -0.8))
	var section := PackedVector2Array([Vector2(-3.6, 5.6), Vector2(-3.0, 5.0), Vector2(1.4, 5.0), Vector2(2.0, 5.6), Vector2(2.0, 8.6), Vector2(1.4, 9.2), Vector2(-3.0, 9.2), Vector2(-3.6, 8.6)])
	_prism(core, section, -11.0, 13.0, [Vector3.BACK, Vector3.UP, Vector3.RIGHT], olive)
	# Joints des panneaux, portes éclairées sur la coursive, hublots côté -Z.
	for x: float in [-6.0, -1.0, 4.0, 9.0]:
		_mesh(core, Vector3(0.08, 4.0, 5.7), Vector3(x, 7.1, -0.8), _mat(OLIVE_DARK))
	for x: float in [-7.0, -2.5, 2.0]:
		_mesh(core, Vector3(1.3, 2.2, 0.06), Vector3(x, 6.1, 2.03), _mat(DARK))
		_mesh(core, Vector3(1.0, 2.0, 0.06), Vector3(x, 6.05, 2.05), _glow(Color(0.95, 0.75, 0.5), 0.8))
		_mesh(core, Vector3(0.3, 0.1, 0.08), Vector3(x, 7.35, 2.05), _glow(LAMP))
	for x: float in [-8.0, -3.0, 2.0, 7.0, 11.0]:
		_mesh(core, Vector3(1.2, 0.5, 0.06), Vector3(x, 7.8, -3.63), _mat(GLASS, 0.2))
	# Panneaux solaires, climatiseurs et antennes sur le toit.
	for x: float in [-5.0, -1.0, 3.0]:
		_mesh(core, Vector3(3.2, 0.08, 2.4), Vector3(x, 9.26, -1.5), _mat(Color(0.12, 0.15, 0.25), 0.3))
	_mesh(core, Vector3(1.4, 0.7, 1.2), Vector3(-9.0, 9.55, -2.0), _mat(OLIVE_DARK))
	_mesh(core, Vector3(1.4, 0.7, 1.2), Vector3(5.5, 9.55, 0.6), _mat(OLIVE_DARK))
	for spot: Vector3 in [Vector3(-3.0, 9.2, 1.0), Vector3(-2.2, 9.2, 1.0), Vector3(6.0, 9.2, -3.0)]:
		_antenna(core, spot, 2.6)
	# Caissons d'extrémité, plus larges et plus hauts, chanfreinés au bout.
	var pod := PackedVector2Array([Vector2(-4.2, 5.4), Vector2(-3.2, 4.4), Vector2(3.2, 4.4), Vector2(4.2, 5.4), Vector2(4.2, 9.4), Vector2(3.2, 10.4), Vector2(-3.2, 10.4), Vector2(-4.2, 9.4)])
	var cap := PackedVector2Array()
	for point in pod:
		cap.append(Vector2(point.x * 0.78, 7.4 + (point.y - 7.4) * 0.78))
	# [nom, début, fin, début et fin du chanfrein].
	for spec: Array in [["PodFront", -21.5, -11.0, -22.5, -21.5], ["PodBack", 13.0, 21.5, 21.5, 22.5]]:
		var box := _body(spec[0], LAYER_OBSTACLE)
		var x0: float = spec[1]
		var x1: float = spec[2]
		_collide(box, Vector3(x1 - x0, 6.0, 8.4), Vector3((x0 + x1) * 0.5, 7.4, 0))
		_prism(box, pod, x0, x1, [Vector3.BACK, Vector3.UP, Vector3.RIGHT], olive)
		_prism(box, cap, spec[3], spec[4], [Vector3.BACK, Vector3.UP, Vector3.RIGHT], olive)
		var middle := (x0 + x1) * 0.5
		for side: float in [-1.0, 1.0]:
			_label(box, hull_number, Vector3(middle - 1.0, 7.6, side * 4.23), side, 0.03)
			_mesh(box, Vector3(1.2, 0.9, 0.06), Vector3(middle + 2.2, 7.6, side * 4.23), _mat(DARK))
			# Feux sous le caisson.
			for k in 3:
				_mesh(box, Vector3(0.4, 0.06, 0.2), Vector3(x0 + 1.5 + k * 3.0, 4.38, side * 2.4), _glow(LAMP))
		_mesh(box, Vector3(2.4, 0.5, 0.06), Vector3(middle, 9.8, 4.15), _mat(DARK))
	# Colonnes du module et du caisson arrière, posées sur le plateau ;
	# vérins obliques du caisson avant, sur les cabines.
	var columns := _body("ModuleColumns", LAYER_OBSTACLE)
	for spot: Vector2 in [Vector2(-8.0, -3.3), Vector2(0.0, -3.3), Vector2(8.0, -3.3), Vector2(14.0, -3.5), Vector2(20.0, -3.5), Vector2(14.0, 3.5), Vector2(20.0, 3.5)]:
		var bottom := DECK_TOP
		var top := 5.0 if spot.x < 13.0 else 4.4
		_collide(columns, Vector3(0.5, top - bottom, 0.5), Vector3(spot.x, (top + bottom) * 0.5, spot.y))
		_cylinder(columns, 0.22, top - bottom, Vector3(spot.x, (top + bottom) * 0.5, spot.y), _mat(STEEL, 0.4))
		_cylinder(columns, 0.3, 0.6, Vector3(spot.x, bottom + 0.3, spot.y), _mat(OLIVE_DARK))
	for z: float in [-2.0, 2.0]:
		for x: float in [-19.5, -14.5]:
			var from := Vector3(x, 3.3, z)
			var to := Vector3(x + 1.2, 4.4, z * 1.4)
			_strut(columns, from, to, 0.13, _mat(STEEL, 0.4))
	# Coursive et escalier depuis le plateau.
	var balcony := _body("Balcony", LAYER_FLOOR)
	_box(balcony, Vector3(BALCONY.size.x, 0.25, BALCONY.size.y), Vector3(BALCONY.get_center().x, BALCONY_TOP - 0.125, BALCONY.get_center().y), _mat(OLIVE_DARK))
	_mesh(balcony, Vector3(BALCONY.size.x, 0.02, BALCONY.size.y - 0.1), Vector3(BALCONY.get_center().x, BALCONY_TOP + 0.01, BALCONY.get_center().y), _mat(STEEL, 0.6))
	for k in 4:
		_mesh(balcony, Vector3(0.4, 0.05, 0.15), Vector3(BALCONY.position.x + 2.0 + k * 3.8, BALCONY_TOP - 0.27, BALCONY.end.y - 0.3), _glow(LAMP))
	_rail_run("RailBalcony", Vector3(BALCONY.position.x, BALCONY_TOP, BALCONY.end.y - 0.06), Vector3(BALCONY.end.x, BALCONY_TOP, BALCONY.end.y - 0.06), [])
	_rail_run("RailBalconyEnd", Vector3(BALCONY.position.x + 0.06, BALCONY_TOP, BALCONY.position.y), Vector3(BALCONY.position.x + 0.06, BALCONY_TOP, BALCONY.end.y), [])
	_stair(Vector3(BALCONY.end.x, BALCONY_TOP, BALCONY.get_center().y), Vector3.RIGHT, BALCONY_TOP - DECK_TOP, BALCONY.size.y - 0.1)
	# Tour de contrôle sur l'arrière du module.
	var tower := _body("ControlTower", LAYER_OBSTACLE)
	_box(tower, Vector3(5.0, 3.4, 4.8), Vector3(10.0, 10.9, -0.8), olive)
	_cab(tower, Vector3(10.0, 12.6, -0.8), Vector2(6.0, 5.6))


# --- Version déployée -----------------------------------------------------------

## Pont déployé : sol en huit dalles, jupes, garde-corps, vérins, escaliers,
## salle des opérations et son toit équipé, conteneurs.
func _build_deck() -> void:
	var tiles_x := 4
	var width := DECK.size.x / tiles_x
	var half := DECK.size.y * 0.5
	for i in tiles_x:
		for j in 2:
			var tile := _body("Deck%d_%d" % [i, j], LAYER_FLOOR)
			var x := DECK.position.x + width * (i + 0.5)
			var z := DECK.position.y + half * (j + 0.5)
			_box(tile, Vector3(width, DECK_THICKNESS, half), Vector3(x, DECK_TOP - DECK_THICKNESS * 0.5, z), _mat(OLIVE_DARK))
			_mesh(tile, Vector3(width - 0.12, 0.02, half - 0.12), Vector3(x, DECK_TOP + 0.01, z), _mat(Color(0.5, 0.5, 0.48), 0.7))
			# Bandes de circulation.
			_mesh(tile, Vector3(width - 0.12, 0.025, 0.12), Vector3(x, DECK_TOP + 0.012, z + (half * 0.5 - 0.6) * (1.0 if j == 1 else -1.0)), _mat(YELLOW))
	# Jupes (flancs rabattus) sous les bords ±Z, entre les vérins.
	var skirt_mat := _mat(OLIVE)
	for side: float in [-1.0, 1.0]:
		for span: Vector2 in [Vector2(-8.0, -3.5), Vector2(1.5, 6.0), Vector2(11.0, 15.5)]:
			var skirt := _body("Skirt", LAYER_OBSTACLE)
			var mid := (span.x + span.y) * 0.5
			var length := span.y - span.x
			_collide(skirt, Vector3(length, 1.0, 1.0), Vector3(mid, 1.4, side * 9.5))
			var trapeze := PackedVector2Array([Vector2(9.0, 0.9), Vector2(9.7, 0.9), Vector2(10.25, DECK_TOP - DECK_THICKNESS), Vector2(9.0, DECK_TOP - DECK_THICKNESS)])
			if side < 0.0:
				trapeze = PackedVector2Array([Vector2(-9.0, 0.9), Vector2(-9.0, DECK_TOP - DECK_THICKNESS), Vector2(-10.25, DECK_TOP - DECK_THICKNESS), Vector2(-9.7, 0.9)])
			_prism(skirt, trapeze, span.x, span.y, [Vector3.BACK, Vector3.UP, Vector3.RIGHT], skirt_mat)
			for k in int(length / 1.5):
				_mesh(skirt, Vector3(0.35, 0.08, 0.05), Vector3(span.x + 0.75 + k * 1.5, 1.6, side * 9.98), _glow(LAMP))
	# Vérins sur le pourtour et sous la poutre.
	var legs := _body("DeckLegs", LAYER_OBSTACLE)
	for x: float in [-10.5, -1.0, 8.5, 20.5]:
		for side: float in [-1.0, 1.0]:
			_leg(legs, Vector3(x, 0, side * 9.3), DECK_TOP - DECK_THICKNESS)
	# Escaliers : deux sur le flanc +Z, un sur le flanc -Z, deux à l'avant.
	var gap := STAIR_WIDTH + 0.2
	var front := DECK.position.x
	var back := DECK.end.x
	_stair(Vector3(-6.0, DECK_TOP, half), Vector3.BACK, DECK_TOP)
	_stair(Vector3(18.0, DECK_TOP, half), Vector3.BACK, DECK_TOP)
	_stair(Vector3(17.5, DECK_TOP, -half), Vector3.FORWARD, DECK_TOP)
	_stair(Vector3(front, DECK_TOP, 7.0), Vector3.LEFT, DECK_TOP)
	_stair(Vector3(front, DECK_TOP, -7.0), Vector3.LEFT, DECK_TOP)
	_rail_run("RailDeckR", Vector3(front, DECK_TOP, half - 0.06), Vector3(back, DECK_TOP, half - 0.06), [_gap_at(-6.0 - front, gap), _gap_at(18.0 - front, gap)])
	_rail_run("RailDeckL", Vector3(front, DECK_TOP, -half + 0.06), Vector3(back, DECK_TOP, -half + 0.06), [_gap_at(17.5 - front, gap)])
	_rail_run("RailDeckBack", Vector3(back - 0.06, DECK_TOP, -half), Vector3(back - 0.06, DECK_TOP, half), [])
	_rail_run("RailDeckFront", Vector3(front + 0.06, DECK_TOP, -half), Vector3(front + 0.06, DECK_TOP, half), [_gap_at(3.0, gap), _gap_at(17.0, gap)])
	_build_ops_room()
	# Conteneurs et caisses fixes sur le pont.
	var cargo := _body("Containers", LAYER_OBSTACLE)
	_container(cargo, Vector3(-9.0, DECK_TOP, -3.0), Vector3(2.4, 2.5, 4.0))
	_container(cargo, Vector3(18.5, DECK_TOP, -5.0), Vector3(5.0, 2.5, 2.4))
	_container(cargo, Vector3(20.0, DECK_TOP, 4.5), Vector3(2.4, 1.3, 2.4))
	_container(cargo, Vector3(-1.0, DECK_TOP, 6.5), Vector3(2.0, 1.1, 1.3))
	_container(cargo, Vector3(9.0, DECK_TOP, 7.2), Vector3(1.3, 1.1, 2.0))


## Salle des opérations (immeuble d'un étage, toit-terrasse) et ce qui
## équipe son toit.
func _build_ops_room() -> void:
	ops_room = Tower.new()
	ops_room.name = "OpsRoom"
	ops_room.storeys = 1
	ops_room.storey_height = OPS_HEIGHT
	ops_room.size = OPS_SIZE
	ops_room.doors = [Vector3(0, -5.0, 0), Vector3(0, 5.0, 0), Vector3(1, 0.0, 0)]
	ops_room.windows = [Vector2(0, -8.0), Vector2(0, 0.0), Vector2(0, 8.0), Vector2(2, -6.0), Vector2(2, 2.0), Vector2(2, 7.0), Vector2(3, 0.0)]
	ops_room.wall_color = OLIVE
	ops_room.wall_texture = ""
	ops_room.floor_color = Color(0.3, 0.31, 0.29)
	ops_room.roof_color = Color(0.4, 0.41, 0.36)
	ops_room.stair_color = STEEL
	ops_room.position = Vector3(OPS_CENTER.x, DECK_TOP, OPS_CENTER.y)
	add_child(ops_room)
	var roof := DECK_TOP + OPS_HEIGHT
	# Pupitres le long du mur sud (repère du véhicule).
	var desks := _body("Consoles", LAYER_OBSTACLE)
	for x: float in [3.5, 6.0, 12.0]:
		_box(desks, Vector3(2.4, 0.8, 0.7), Vector3(x, DECK_TOP + 0.4, -0.15), _mat(OLIVE_DARK))
		_mesh(desks, Vector3(2.0, 0.5, 0.06), Vector3(x, DECK_TOP + 1.1, 0.12), _glow(Color(0.35, 0.7, 1.0), 0.6))
	# Tourelle de défense rapprochée (canon rotatif sur affût).
	var ciws := _body("Ciws", LAYER_OBSTACLE)
	var at := Vector3(-3.0, roof, -1.4)
	_box(ciws, Vector3(2.4, 2.6, 2.4), at + Vector3(0, 1.3, 0), _mat(OLIVE))
	_cylinder(ciws, 0.9, 0.5, at + Vector3(0, 2.85, 0), _mat(STEEL, 0.4))
	_mesh(ciws, Vector3(1.0, 1.6, 1.0), at + Vector3(0, 3.8, 0), _mat(Color(0.82, 0.83, 0.84), 0.4))
	_cylinder(ciws, 0.5, 0.9, at + Vector3(0, 4.9, 0), _mat(Color(0.82, 0.83, 0.84), 0.4))
	_strut(ciws, at + Vector3(0.3, 3.6, 0), at + Vector3(2.4, 4.4, 0), 0.1, _mat(DARK))
	_rail_ring(ciws, at + Vector3(0, 2.6, 0), Vector2(2.4, 2.4))
	# Tour de contrôle et mât d'antennes.
	var tower := _body("ControlTower", LAYER_OBSTACLE)
	var foot := Vector3(10.5, roof, -5.5)
	_box(tower, Vector3(3.2, 4.2, 3.2), foot + Vector3(0, 2.1, 0), _mat(OLIVE))
	_mesh(tower, Vector3(1.0, 2.0, 0.06), foot + Vector3(0, 1.0, 1.63), _mat(DARK))
	_cab(tower, foot + Vector3(0, 4.2, 0), Vector2(4.4, 4.4))
	var mast := _body("Mast", LAYER_OBSTACLE)
	var base := Vector3(5.5, roof, -7.0)
	_collide(mast, Vector3(0.6, 9.0, 0.6), base + Vector3(0, 4.5, 0))
	# Pylône en treillis : quatre montants, entretoises.
	for corner: Vector2 in [Vector2(-1, -1), Vector2(-1, 1), Vector2(1, -1), Vector2(1, 1)]:
		_strut(mast, base + Vector3(corner.x * 0.35, 0, corner.y * 0.35), base + Vector3(corner.x * 0.12, 9.0, corner.y * 0.12), 0.04, _mat(STEEL, 0.5))
	for k in 9:
		var spread := 0.35 - 0.23 * k / 9.0
		_mesh(mast, Vector3(spread * 2.0, 0.04, spread * 2.0), base + Vector3(0, k * 1.0 + 0.5, 0), _mat(STEEL, 0.5))
	for k in 4:
		_mesh(mast, Vector3(1.6 - k * 0.25, 0.08, 0.08), base + Vector3(0, 3.0 + k * 2.0, 0), _mat(STEEL, 0.5))
		_mesh(mast, Vector3(0.2, 0.6, 0.2), base + Vector3(0.7 - k * 0.12, 3.3 + k * 2.0, 0), _mat(OLIVE_DARK))
	_mesh(mast, Vector3(0.15, 0.15, 0.15), base + Vector3(0, 9.1, 0), _glow(Color(1.0, 0.15, 0.1)))
	# Coffres sur le toit (abri).
	var lockers := _body("RoofLockers", LAYER_OBSTACLE)
	_container(lockers, Vector3(1.0, roof, -0.8), Vector3(2.2, 1.0, 1.1))


# --- Pièces ---------------------------------------------------------------------

## Escalier métallique : du bord `head` (au niveau du haut), il descend de
## `rise` m vers `out` (horizontal). Rampe invisible pour la marche et la
## navigation, marches ajourées, limons et mains courantes jaunes.
func _stair(head: Vector3, out: Vector3, rise: float, width: float = STAIR_WIDTH) -> void:
	var run := rise / tan(deg_to_rad(STAIR_SLOPE))
	var foot := head + out * run - Vector3.UP * rise
	var down := (foot - head).normalized()
	var across := out.cross(Vector3.UP).normalized()
	var normal := down.cross(across).normalized()
	if normal.y < 0.0:
		across = -across
		normal = -normal
	var basis := Basis(across, normal, down)
	var length := head.distance_to(foot)
	var body := _body("Stair", LAYER_FLOOR)
	# Prolongée sous le sol au pied, pas au-dessus du palier.
	_collide(body, Vector3(width, 0.2, length + 0.4), (head + foot) * 0.5 + down * 0.2 - normal * 0.1, basis)
	var steel := _mat(Color(0.25, 0.26, 0.27), 0.5)
	var steps := maxi(4, roundi(rise / 0.2))
	for i in steps:
		var center := head + out * (run / steps * (i + 0.5)) - Vector3.UP * (rise / steps * i + 0.03)
		_mesh(body, Vector3(width, 0.06, run / steps + 0.04) if absf(out.x) < 0.5 else Vector3(run / steps + 0.04, 0.06, width), center, steel)
	var yellow := _mat(YELLOW, 0.6)
	for side: float in [-0.5, 0.5]:
		var offset := across * side * width
		_strut(body, head + offset - Vector3.UP * 0.12, foot + offset - Vector3.UP * 0.12, 0.06, steel)
		_strut(body, head + offset + Vector3.UP * RAIL_HEIGHT, foot + offset + Vector3.UP * RAIL_HEIGHT, 0.035, yellow)
		for k in 3:
			var point := head.lerp(foot, (k + 0.5) / 3.0) + offset
			_mesh(body, Vector3(0.05, RAIL_HEIGHT, 0.05), point + Vector3.UP * RAIL_HEIGHT * 0.5, yellow)


## Écart `[début, fin]` de `width` m centré à `at` m le long d'un garde-corps.
func _gap_at(at: float, width: float) -> Vector2:
	return Vector2(at - width * 0.5, at + width * 0.5)


## Garde-corps de `from` à `to` (au niveau du sol qu'il borde), interrompu
## par les écarts `gaps` (distances depuis `from`). Arrête le passage.
func _rail_run(name_hint: String, from: Vector3, to: Vector3, gaps: Array) -> void:
	var body := _body(name_hint, LAYER_OBSTACLE)
	var length := from.distance_to(to)
	var direction := (to - from) / length
	var cuts: Array[Vector2] = []
	var cursor := 0.0
	var sorted := gaps.duplicate()
	sorted.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	for gap: Vector2 in sorted:
		cuts.append(Vector2(cursor, clampf(gap.x, 0.0, length)))
		cursor = clampf(gap.y, 0.0, length)
	cuts.append(Vector2(cursor, length))
	var yellow := _mat(YELLOW, 0.6)
	var basis := Basis(Vector3.UP.cross(direction).normalized(), Vector3.UP, direction)
	for cut in cuts:
		var span := cut.y - cut.x
		if span < 0.2:
			continue
		var middle := from + direction * (cut.x + cut.y) * 0.5
		_collide(body, Vector3(0.12, RAIL_HEIGHT, span), middle + Vector3.UP * RAIL_HEIGHT * 0.5, basis)
		_mesh(body, Vector3(0.06, 0.06, span), middle + Vector3.UP * RAIL_HEIGHT, yellow, basis)
		_mesh(body, Vector3(0.04, 0.04, span), middle + Vector3.UP * RAIL_HEIGHT * 0.5, yellow, basis)
		var posts := maxi(1, ceili(span / 1.6))
		for k in posts + 1:
			var point := from + direction * (cut.x + span * k / posts)
			_mesh(body, Vector3(0.06, RAIL_HEIGHT, 0.06), point + Vector3.UP * RAIL_HEIGHT * 0.5, yellow)


## Garde-corps décoratif autour d'un toit de `size` (x, z) posé en `at`.
func _rail_ring(parent: Node3D, at: Vector3, size_: Vector2) -> void:
	var yellow := _mat(YELLOW, 0.6)
	var y := at.y + RAIL_HEIGHT
	_mesh(parent, Vector3(size_.x, 0.05, 0.05), Vector3(at.x, y, at.z + size_.y * 0.5), yellow)
	_mesh(parent, Vector3(size_.x, 0.05, 0.05), Vector3(at.x, y, at.z - size_.y * 0.5), yellow)
	_mesh(parent, Vector3(0.05, 0.05, size_.y), Vector3(at.x + size_.x * 0.5, y, at.z), yellow)
	_mesh(parent, Vector3(0.05, 0.05, size_.y), Vector3(at.x - size_.x * 0.5, y, at.z), yellow)
	for corner: Vector2 in [Vector2(-1, -1), Vector2(-1, 1), Vector2(1, -1), Vector2(1, 1)]:
		_mesh(parent, Vector3(0.05, RAIL_HEIGHT, 0.05), Vector3(at.x + corner.x * size_.x * 0.5, at.y + RAIL_HEIGHT * 0.5, at.z + corner.y * size_.y * 0.5), yellow)


## Cabine vitrée de tour de contrôle (pans vitrés éclairés, toit, garde-corps,
## antennes, radôme), posée en `at`, d'emprise `size_`.
func _cab(body: StaticBody3D, at: Vector3, size_: Vector2) -> void:
	_box(body, Vector3(size_.x, 1.5, size_.y), at + Vector3(0, 0.75, 0), _mat(OLIVE))
	_mesh(body, Vector3(size_.x + 0.04, 0.7, size_.y + 0.04), at + Vector3(0, 0.85, 0), _glow(Color(0.85, 0.7, 0.45), 0.35))
	_mesh(body, Vector3(size_.x + 0.5, 0.2, size_.y + 0.5), at + Vector3(0, 1.6, 0), _mat(OLIVE_DARK))
	_mesh(body, Vector3(size_.x + 0.6, 0.12, size_.y + 0.6), at + Vector3(0, 0.0, 0), _mat(OLIVE_DARK))
	_rail_ring(body, at + Vector3(0, 1.7, 0), size_ + Vector2(0.3, 0.3))
	_antenna(body, at + Vector3(-size_.x * 0.3, 1.7, -size_.y * 0.3), 3.2)
	_antenna(body, at + Vector3(size_.x * 0.25, 1.7, -size_.y * 0.35), 2.4)
	_antenna(body, at + Vector3(0.0, 1.7, size_.y * 0.3), 3.8)
	var dome := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	dome.mesh = sphere
	dome.material_override = _mat(Color(0.75, 0.74, 0.68))
	dome.position = at + Vector3(size_.x * 0.25, 2.3, size_.y * 0.2)
	body.add_child(dome)


## Antenne fouet de `height` m, feu rouge au sommet.
func _antenna(parent: Node3D, at: Vector3, height: float) -> void:
	_cylinder(parent, 0.05, height, at + Vector3.UP * height * 0.5, _mat(DARK))
	_cylinder(parent, 0.12, 0.4, at + Vector3.UP * 0.2, _mat(OLIVE_DARK))
	_mesh(parent, Vector3(0.1, 0.1, 0.1), at + Vector3.UP * (height + 0.05), _glow(Color(1.0, 0.15, 0.1)))


## Vérin : fût, tige chromée, patin rayé jaune et noir ; arrête le passage.
func _leg(body: StaticBody3D, at: Vector3, top: float) -> void:
	_collide(body, Vector3(0.8, top, 0.8), at + Vector3(0, top * 0.5, 0))
	_cylinder(body, 0.3, top * 0.55, at + Vector3(0, top - top * 0.275, 0), _mat(OLIVE_DARK))
	_cylinder(body, 0.17, top * 0.6, at + Vector3(0, top * 0.35, 0), _mat(Color(0.7, 0.71, 0.72), 0.25))
	_mesh(body, Vector3(1.1, 0.2, 1.1), at + Vector3(0, 0.1, 0), _mat(DARK))
	_mesh(body, Vector3(1.12, 0.07, 1.12), at + Vector3(0, 0.17, 0), _mat(YELLOW))


## Conteneur ou caisse fixe : boîte de `size_` posée en `at` (au sol).
func _container(body: StaticBody3D, at: Vector3, size_: Vector3) -> void:
	_box(body, size_, at + Vector3(0, size_.y * 0.5, 0), _mat(OLIVE_DARK))
	var ribs := maxi(2, roundi(maxf(size_.x, size_.z) / 0.8))
	var long_x := size_.x >= size_.z
	for k in ribs:
		var t := (k + 0.5) / ribs - 0.5
		var offset := Vector3(t * size_.x, 0, 0) if long_x else Vector3(0, 0, t * size_.z)
		_mesh(body, Vector3(0.06, size_.y - 0.1, size_.z + 0.04) if long_x else Vector3(size_.x + 0.04, size_.y - 0.1, 0.06), at + offset + Vector3(0, size_.y * 0.5, 0), _mat(OLIVE))


## Roue : pneu, jante.
func _wheel(parent: Node3D, at: Vector3, radius: float) -> void:
	var tilt := Basis(Vector3.RIGHT, PI * 0.5)
	_cylinder(parent, radius, 0.5, at, _mat(Color(0.08, 0.08, 0.08), 0.95), tilt)
	var outward := signf(at.z) if absf(at.z) > 0.01 else 1.0
	_cylinder(parent, radius * 0.55, 0.06, at + Vector3(0, 0, outward * 0.25), _mat(OLIVE), tilt)


# --- Outils ---------------------------------------------------------------------

func _body(name_hint: String, layer: int) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = name_hint
	body.collision_layer = layer
	body.collision_mask = 0
	add_child(body)
	return body


func _collide(body: StaticBody3D, size_: Vector3, at: Vector3, basis: Basis = Basis.IDENTITY) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size_
	shape.shape = box
	shape.transform = Transform3D(basis, at)
	body.add_child(shape)


## Boîte solide : collision et maillage.
func _box(body: StaticBody3D, size_: Vector3, at: Vector3, material: Material) -> void:
	_collide(body, size_, at)
	_mesh(body, size_, at, material)


func _mesh(parent: Node3D, size_: Vector3, at: Vector3, material: Material, basis: Basis = Basis.IDENTITY) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = size_
	mesh.mesh = cube
	mesh.material_override = material
	mesh.transform = Transform3D(basis, at)
	parent.add_child(mesh)
	return mesh


func _cylinder(parent: Node3D, radius: float, height: float, at: Vector3, material: Material, basis: Basis = Basis.IDENTITY) -> void:
	var mesh := MeshInstance3D.new()
	var tube := CylinderMesh.new()
	tube.top_radius = radius
	tube.bottom_radius = radius
	tube.height = height
	tube.radial_segments = 12
	tube.rings = 1
	mesh.mesh = tube
	mesh.material_override = material
	mesh.transform = Transform3D(basis, at)
	parent.add_child(mesh)


## Barre ronde de `from` à `to`.
func _strut(parent: Node3D, from: Vector3, to: Vector3, radius: float, material: Material) -> void:
	var axis := to - from
	var length := axis.length()
	if length < 0.01:
		return
	var up := axis / length
	var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	var basis := Basis(side, up, side.cross(up))
	_cylinder(parent, radius, length, (from + to) * 0.5, material, basis)


## Prisme : le polygone convexe `shape` (plan u, v) extrudé le long de w, de
## `w0` à `w1` ; `axes` = [u, v, w] dans le repère du parent.
func _prism(parent: Node3D, shape: PackedVector2Array, w0: float, w1: float, axes: Array, material: Material) -> void:
	var u: Vector3 = axes[0]
	var v: Vector3 = axes[1]
	var w: Vector3 = axes[2]
	var count := shape.size()
	var center := Vector2.ZERO
	for point in shape:
		center += point
	center /= count
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var low: Array[Vector3] = []
	var high: Array[Vector3] = []
	for point in shape:
		low.append(u * point.x + v * point.y + w * w0)
		high.append(u * point.x + v * point.y + w * w1)
	for i in count:
		var j := (i + 1) % count
		# Normale de la face : perpendiculaire à l'arête, vers l'extérieur.
		var edge := shape[j] - shape[i]
		var flat := Vector2(edge.y, -edge.x)
		if flat.dot((shape[i] + shape[j]) * 0.5 - center) < 0.0:
			flat = -flat
		var outward := (u * flat.x + v * flat.y).normalized()
		_triangle(tool, low[i], low[j], high[j], outward)
		_triangle(tool, low[i], high[j], high[i], outward)
	var back := -w if w1 > w0 else w
	for i in range(1, count - 1):
		_triangle(tool, low[0], low[i], low[i + 1], back)
		_triangle(tool, high[0], high[i], high[i + 1], -back)
	var mesh := MeshInstance3D.new()
	mesh.mesh = tool.commit()
	mesh.material_override = material
	parent.add_child(mesh)


## Triangle tourné vers `normal` (sens horaire vu de face, convention Godot).
func _triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	if (b - a).cross(c - a).dot(normal) > 0.0:
		var swap := b
		b = c
		c = swap
	for point in [a, b, c]:
		tool.set_normal(normal)
		tool.add_vertex(point)


## Numéro peint sur un flanc tourné vers ±Z (`side`).
func _label(parent: Node3D, text: String, at: Vector3, side: float, pixel: float, tilt: Basis = Basis.IDENTITY) -> void:
	var label := Label3D.new()
	label.text = text
	label.pixel_size = pixel
	label.font_size = 96
	label.outline_size = 0
	label.modulate = Color(0.92, 0.92, 0.88)
	label.double_sided = false
	label.shaded = true
	label.transform = Transform3D(tilt * (Basis.IDENTITY if side > 0.0 else Basis(Vector3.UP, PI)), at)
	parent.add_child(label)


func _mat(color: Color, roughness: float = 0.85) -> StandardMaterial3D:
	var key := "%s/%s" % [color, roughness]
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = 0.15 if roughness < 0.7 else 0.0
	_materials[key] = material
	return material


func _glow(color: Color, energy: float = 1.6) -> StandardMaterial3D:
	var key := "glow/%s/%s" % [color, energy]
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	_materials[key] = material
	return material
