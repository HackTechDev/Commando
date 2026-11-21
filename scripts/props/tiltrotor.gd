class_name Tiltrotor
extends StaticBody3D
## Convertible posé au sol (`TiltrotorModel`) : obstacle (marche, vue, balles)
## et cible de sabotage. Une explosion proche de la coque (charge, grenade)
## le détruit : le réservoir saute à son tour (souffle autour de l'appareil),
## l'épave brûle, l'objectif `objective_id` est rempli et, si `ends_mission`,
## la mission est réussie peu après.
##
## On entre dans la soute par la rampe arrière : la coque est creuse (parois,
## toit, plancher), la navigation monte la rampe. Un opérateur à bord rend
## la coque translucide ; les clics la traversent alors (`is_revealed_body`)
## pour atteindre le plancher. Un corps déposé dans la soute est caché.
##
## À bord, un opérateur peut relever la rampe (`set_ramp_closed` : elle arrête
## alors la marche, la vue et les balles ; la navigation est recalculée) ou
## prendre les commandes (`take_off`) quand tous les opérateurs vivants sont
## dans la soute : rampe relevée, rotors lancés (bruit qui alerte), l'appareil
## décolle avec eux, l'objectif est rempli et la mission réussie.
##
## Vol stationnaire (`rise` / `land`) : l'appareil monte à `HOVER_HEIGHT`
## avec les opérateurs à bord (`Commando.airborne_in` : en vol, ils ne
## font que tirer, et seulement porte ouverte). La porte (rampe) s'ouvre
## et se ferme en l'air ; porte ouverte, un opérateur descend en rappel
## (`rappel`) le long d'une corde jusqu'au premier sol sous la rampe
## (terrain, toit, caisse). En vol stationnaire, l'appareil se déplace
## (`fly_to`) : il pivote, vole jusqu'au point visé et s'arrête le bout de la
## rampe au-dessus ; il ne se pose que sur un terrain plat. Il change de
## palier (`change_altitude`, `HOVER_LEVELS`) : plus il vole haut, moins le
## bruit des rotors porte au sol (`rotor_noise_radius`), mais plus la corde
## est longue. En vol, les rotors s'entendent en continu.
##
## Hélitreuillage (`request_winch`) : porte ouverte en vol stationnaire, un
## opérateur au sol (ou sur un toit) rejoint le pied de la corde et y est
## treuillé jusqu'à la soute ; un VIP qui se tient au pied de la corde l'est
## aussi.
##
## Extraction (`extraction`) : l'appareil n'est pas là au début de la
## mission. Un opérateur l'appelle (`call_in`) : il arrive en vol, bruyant
## (les ennemis accourent), attend au-dessus de son point de pose que la place
## soit libre, se pose et abaisse la rampe. Il repart seul quand tous les
## opérateurs vivants (et les VIP) sont à bord et que les autres objectifs
## sont remplis : l'objectif `objective_id` est rempli, la mission réussie.
##
## Insertion (`insertion`) : la mission commence en vol stationnaire au
## plus haut palier au-dessus de la place de l'appareil, toute l'équipe en
## soute, porte ouverte. On le déplace, on descend en rappel ; un point trop
## proche des sentinelles les alerte (bruit des rotors). Soute vide, on le
## renvoie par radio (`dismiss`) : il s'en va, et revient à l'appel s'il est
## aussi l'appareil d'extraction.
##
## Tir depuis la soute en vol : un fusil de précision porte plus loin
## grâce à la hauteur (`Commando.fire_range`), mais les vibrations réduisent
## la précision, surtout juste après un mouvement (`steadiness`).
##
## Diversion (`divert`) : l'appareil parti (extraction pas encore appelée,
## insertion renvoyée), on le fait passer une fois en rase-mottes au-dessus
## d'un point de la carte : le bruit attire les sentinelles alentour, qui
## vont voir (bruit `distraction`), pendant que l'équipe passe ailleurs.
##
## Ravitaillement (`resupply`) : la soute emporte `supplies` lots ; un
## opérateur à bord y reprend sa dotation de départ (munitions, grenades,
## fumigènes, trousses de soins, charges).
##
## Documents (`documents_objective`) : rapporter à bord ceux d'un officier
## (`Enemy.documents`), sur un opérateur ou avec le corps.
##
## Évacuation (`evacuate`) : un opérateur blessé à bord quitte la mission,
## sauvé ; il ne compte pas comme perdu.
##
## Course contre la montre (`pickup_window`) : appelée, l'extraction ne se
## pose pas ; elle reste en vol stationnaire, porte ouverte, le temps donné,
## pour treuiller l'équipe, et repart dès que tout le monde est à bord, ou à
## la fin du temps (échec s'il manque quelqu'un).
##
## Élingage (`sling`, `drop_load`) : en vol stationnaire, l'appareil
## accroche sous ses crochets une caisse déplaçable ou un Sabre vide, le
## transporte, et le dépose ailleurs (bloquer une porte, créer un abri).
##
## Riposte : en l'air (`is_in_air`), l'appareil est une cible pour les
## ennemis armés qui le voient (`Enemy`). Chaque balle lui ôte une part de
## ses dégâts (`BULLET_SHARE`) sur `STRUCTURE` points, une roquette
## (`Enemy.launcher`) `ROCKET_DAMAGE` ; sous la moitié, il
## fume ; à zéro, il est hors d'usage (`is_disabled`) : il se pose en urgence
## à la verticale (ou sur sa zone, en approche) et ne revole plus.
##
## Canon latéral : un opérateur à bord le sert (`man_gun`). Il tire alors
## seul, par rafales, sur le premier ennemi debout qu'il voit du côté droit à
## moins de `GUN_RANGE` ; les balles arrêtées par une caisse ou un mur
## fragile les abîment (un abri ne protège pas longtemps). Très bruyant.
##
## Vol de nuit (`LevelRoot.night`) : tous feux éteints (`blacked_out`). Les
## ennemis ne le voient qu'à `BLACKOUT_SIGHT` (le bruit des rotors porte
## toujours), sauf quelques secondes après une rafale du canon. Un
## stroboscope infrarouge, visible seulement en vision nocturne, le signale à
## l'équipe.
##
## Soute à véhicule : un Sabre peut s'y garer (`cargo`, voir `Sabre.load_into`)
## ; l'appareil l'emporte avec son équipage, comme ses passagers.
##
## Repère : celui du modèle (avant vers -Z, posé au sol), agrandi de `SCALE`.

const GROUP := &"vehicles"
## Mise à l'échelle du modèle (et de ses formes).
const SCALE := 1.25
const CHECK_INTERVAL := 0.1
const LAYER_OCCLUDERS := 0b10
## Une explosion détruit l'appareil si la coque est à moins de cette part de
## son rayon d'effet.
const BLAST_SHARE := 0.6
## Explosion du réservoir : rayon, dégâts au centre, bruit.
const FUEL_RADIUS := 7.0
const FUEL_DAMAGE := 140.0
const FUEL_NOISE := 45.0
## Délai (s) entre la destruction et la fin de mission.
const END_DELAY := 3.0
## Durée (s) du mouvement de la rampe.
const RAMP_TIME := 1.2
## Décollage : mise en route des rotors (s), vitesse finale (tours/s),
## bruit des rotors (rayon), montée (s, m) et fin de mission après.
const SPIN_UP := 3.0
const FLIGHT_ROTOR_SPEED := 5.0
const ROTOR_NOISE := 40.0
const CLIMB_TIME := 6.0
const CLIMB_HEIGHT := 45.0
const CLIMB_DISTANCE := 60.0
## Vol stationnaire : hauteur (m), durée de la montée ou de la descente (s),
## vitesse de descente en rappel (m/s).
const HOVER_HEIGHT := 10.0
const HOVER_TIME := 4.0
## Paliers de vol stationnaire (m au-dessus du sol), part du bruit des rotors
## qui porte encore au plus haut, intervalle du bruit en vol stationnaire (s).
const HOVER_LEVELS: Array[float] = [10.0, 20.0, 30.0]
const HIGH_NOISE_SHARE := 0.4
const HOVER_NOISE_INTERVAL := 2.0
## Déplacement en vol stationnaire : vitesse (m/s), temps pour pivoter
## d'un radian (s), écart toléré entre le centre et les extrémités de
## l'appareil pour se poser (m).
const FLY_SPEED := 9.0
const TURN_TIME := 0.9
const LANDING_TOLERANCE := 0.4
## Tir depuis la soute en vol : précision gardée appareil stabilisé, juste
## après un mouvement, et temps de stabilisation (s).
const HOVER_STEADINESS := 0.85
const MOVING_STEADINESS := 0.45
const SETTLE_TIME := 4.0
## Hélitreuillage : vitesse de montée (m/s), distance au pied de la corde
## (à plat, en hauteur) à laquelle on est accroché.
const WINCH_SPEED := 1.8
const WINCH_REACH := 1.3
const WINCH_HEIGHT := 1.2
const RAPPEL_SPEED := 2.5
## Extraction : arrivée depuis l'arrière (distance, hauteur au départ, s),
## intervalle du bruit des rotors pendant l'approche, attente (s) avant de
## repartir une fois tout le monde à bord.
const APPROACH_DISTANCE := 70.0
const APPROACH_HEIGHT := 30.0
const APPROACH_TIME := 14.0
const APPROACH_NOISE_INTERVAL := 1.5
const DEPART_DELAY := 1.5
## Élingage : portée horizontale autour des crochets ou du pied de la corde
## (m), longueur des élingues (m), durée de levée ou de dépose (s), point
## médian des crochets (repère de l'appareil), hauteur d'un Sabre (m).
const SLING_REACH := 4.0
const SLING_LENGTH := 3.0
const SLING_TIME := 2.5
const SLING_HOOKS: Array[Vector3] = [Vector3(0.0, 0.55, -3.0), Vector3(0.0, 0.55, 4.4)]
const SLING_SABRE_HEIGHT := 2.6
## Diversion : hauteur du passage, demi-longueur du trajet (m), vitesse
## (m/s), rayon et intervalle du bruit.
const DIVERSION_HEIGHT := 15.0
const DIVERSION_REACH := 70.0
const DIVERSION_SPEED := 16.0
const DIVERSION_NOISE := 34.0
const DIVERSION_NOISE_INTERVAL := 0.8
## Riposte : points de structure, part des dégâts d'une balle encaissée, part
## de la structure sous laquelle il fume, durée de la descente d'urgence (s).
const STRUCTURE := 400.0
const BULLET_SHARE := 0.25
## Dégâts d'une roquette qui touche (`take_rocket`) : deux suffisent.
const ROCKET_DAMAGE := 230.0
const SMOKE_SHARE := 0.5
const EMERGENCY_TIME := 2.5
## Canon latéral : portée, dégâts, rafale (coups, intervalle, pause en s),
## écart (m par m de distance), bruit, vitesse de visée (rad/s), recherche
## de cible (s), tolérance de visée (rad) : réglages de `MountedGun`.
const GUN_RANGE := 40.0
const GUN_DAMAGE := 45.0
const GUN_BURST := 6
const GUN_ROUND_INTERVAL := 0.09
const GUN_BURST_PAUSE := 0.9
const GUN_SPREAD := 0.035
const GUN_NOISE := 50.0
const GUN_TURN_SPEED := 3.0
const GUN_SEARCH_INTERVAL := 0.3
const GUN_AIM_TOLERANCE := 0.12
## Bouche du canon dans le repère de son pivot.
const GUN_MUZZLE := Vector3(0.0, 0.02, -1.62)
## Vol tous feux éteints : distance à laquelle un ennemi le voit, durée
## (s) pendant laquelle une rafale du canon le trahit, cadence du
## stroboscope infrarouge (période, éclair, s).
const BLACKOUT_SIGHT := 14.0
const MUZZLE_REVEAL := 3.0
const STROBE_PERIOD := 1.2
const STROBE_FLASH := 0.12
## Point visé par les tireurs (repère du modèle, avant mise à l'échelle).
const AIM_POINT := Vector3(0.0, 2.2, 0.5)

@export var livery: TiltrotorModel.Livery = TiltrotorModel.Livery.OLIVE
@export var tail_number: String = "07"
@export_range(2, 6) var blade_count: int = 3
## Tours par seconde des rotors (0 : arrêtés).
@export var rotor_speed: float = 0.0
@export var objective_id: StringName = &"aircraft_destroyed"
@export var ends_mission: bool = true
## Objectifs remplis en atteignant le vol stationnaire, et à la première
## descente en rappel (vides : aucun).
@export var hover_objective: StringName = &""
@export var rappel_objective: StringName = &""
## Appareil d'extraction : absent jusqu'à l'appel (`call_in`).
@export var extraction: bool = false
## La mission commence à bord, en vol stationnaire (voir plus haut).
@export var insertion: bool = false
## Objectif rempli quand des documents d'officier arrivent à bord : un
## opérateur qui les porte, ou le corps de l'officier (vide : aucun).
@export var documents_objective: StringName = &""
## Extraction en vol stationnaire pendant ce temps (s), sans se poser
## (0 : elle se pose normalement).
@export var pickup_window: float = 0.0
## Lots de ravitaillement dans la soute (un par opérateur ravitaillé).
@export var supplies: int = 3

var is_destroyed: bool = false
var model: TiltrotorModel
## Boîtes de la coque (repère local) : fuselage, ailes, nacelles.
var hull_boxes: Array[AABB] = []
## Plancher de la soute et rampe : corps à part, que les clics atteignent à
## travers la coque translucide.
var floor_body: StaticBody3D
var _fire: Node3D
var _check_left: float = 0.0
var is_ramp_closed: bool = false
var is_flying: bool = false
## En vol stationnaire (monté, pas encore reposé).
var is_airborne: bool = false
## Montée ou descente du vol stationnaire en cours.
var is_moving: bool = false
## Hauteur du sol sous l'appareil (au décollage).
var ground_y: float = 0.0
## Hauteur du vol stationnaire au-dessus de `ground_y` (un des `HOVER_LEVELS`).
var hover_height: float = HOVER_HEIGHT
## Temps (s) avant que l'appareil, arrivé d'un mouvement, soit stabilisé.
var _settle_left: float = 0.0
var _rope: MeshInstance3D
var _rappelling: int = 0
## Unités en cours de treuillage, et opérateurs en route vers la corde
## (unité -> vrai).
var _winching: int = 0
var _winch_requests: Dictionary = {}
var _ramp_shape: CollisionShape3D
## Passagers pendant le vol : unité (opérateur ou VIP) -> position dans le
## repère de l'appareil.
var _passengers: Dictionary = {}
## Extraction : pas encore appelé (caché, sans collision), en approche.
var is_away: bool = false
var is_inbound: bool = false
## Point de pose (position de l'appareil dans la scène).
var _landing: Vector3
var _landing_yaw: float = 0.0
## Passage de diversion en cours ; diversion déjà faite (une par mission).
var _documents_aboard: bool = false
## Charge élinguée (caisse ou Sabre), ou null ; place sous les crochets
## (repère de l'appareil), place au sol (départ ou dépose), avancement
## (0 au sol, 1 suspendue), sens (+1 levée, -1 dépose, 0 immobile).
var slung_load: Node3D
## Course contre la montre : temps restant (s), dernier décompte annoncé.
var pickup_left: float = 0.0
var _pickup_told: int = -1
var _sling_hang := Transform3D.IDENTITY
var _sling_ground := Transform3D.IDENTITY
var _sling_progress: float = 0.0
var _sling_dir: int = 0
var _sling_saved: Dictionary = {}
var _sling_cables: Array[MeshInstance3D] = []
var is_diverting: bool = false
var diversion_used: bool = false
var _flight: Tween
var _noise_left: float = 0.0
var _depart_left: float = DEPART_DELAY
## Tout le monde est à bord mais des objectifs restent : déjà signalé.
var _told_pending: bool = false
var structure: float = STRUCTURE
## Abattu : hors d'usage, il ne revole plus.
var is_disabled: bool = false
var _smoke: Node3D
var _gauge: Label3D
## Vol de nuit : feux de position éteints.
var blacked_out: bool = false
var _revealed_left: float = 0.0
var _strobe_time: float = 0.0
## Opérateur qui sert le canon latéral (null : personne).
var gunner: Commando
## Véhicule garé dans la soute (null : aucun).
var cargo: Sabre
var _gun: MountedGun


func _enter_tree() -> void:
	add_to_group(GROUP)
	add_to_group(QuickSave.GROUP)


func _ready() -> void:
	collision_layer = LAYER_OCCLUDERS
	collision_mask = 0
	model = TiltrotorModel.new()
	model.name = "Model"
	model.livery = livery
	model.tail_number = tail_number
	model.blade_count = blade_count
	model.rotor_speed = rotor_speed
	add_child(model)
	model.scale = Vector3.ONE * SCALE
	var half := TiltrotorModel.CABIN_HALF_WIDTH
	# Coque creuse : nez (cockpit), parois, toit, dessus de la queue.
	_add_box(self, AABB(Vector3(-1.75, 0.0, -8.3), Vector3(3.5, 3.6, TiltrotorModel.CABIN_FRONT + 8.3)))
	for side: float in [-1.0, 1.0]:
		var inner := half if side > 0.0 else -2.1
		_add_box(self, AABB(Vector3(inner, TiltrotorModel.FLOOR, TiltrotorModel.CABIN_FRONT), Vector3(2.1 - half, 3.6 - TiltrotorModel.FLOOR, 7.6 - TiltrotorModel.CABIN_FRONT)))
	_add_box(self, AABB(Vector3(-2.1, TiltrotorModel.CABIN_CEILING, TiltrotorModel.CABIN_FRONT), Vector3(4.2, 0.4, TiltrotorModel.CABIN_BACK - TiltrotorModel.CABIN_FRONT)))
	_add_box(self, AABB(Vector3(-1.6, 2.75, TiltrotorModel.CABIN_BACK), Vector3(3.2, 0.75, 8.4 - TiltrotorModel.CABIN_BACK)))
	# Ailes, de part et d'autre du fuselage (pas dans la soute).
	for z in TiltrotorModel.WINGS:
		var span := absf(TiltrotorModel.NACELLES[0 if z < 0.0 else 2].x)
		for side: float in [-1.0, 1.0]:
			var from := 2.1 if side > 0.0 else -span
			_add_box(self, AABB(Vector3(from, TiltrotorModel.WING_HEIGHT - 0.3, z - 1.2), Vector3(span - 2.1, 0.6, 2.4)))
	for at in TiltrotorModel.NACELLES:
		var nacelle := TiltrotorModel.NACELLE_HALF
		_add_box(self, AABB(Vector3(at.x - nacelle.x, 0.0, at.y - nacelle.y), Vector3(nacelle.x * 2.0, TiltrotorModel.NACELLE_TOP, nacelle.y * 2.0)))
	# Plancher (jusqu'au sol : on ne passe pas sous l'appareil) et rampe.
	floor_body = StaticBody3D.new()
	floor_body.name = "Floor"
	floor_body.collision_layer = LAYER_OCCLUDERS
	floor_body.collision_mask = 0
	add_child(floor_body)
	_add_box(floor_body, AABB(Vector3(-2.1, 0.0, TiltrotorModel.CABIN_FRONT), Vector3(4.2, TiltrotorModel.FLOOR, TiltrotorModel.CABIN_BACK - TiltrotorModel.CABIN_FRONT)))
	_ramp_shape = CollisionShape3D.new()
	_ramp_shape.name = "Ramp"
	var slab := BoxShape3D.new()
	slab.size = Vector3(TiltrotorModel.RAMP_HALF_WIDTH * 2.0, 0.1, TiltrotorModel.ramp_length()) * SCALE
	_ramp_shape.shape = slab
	floor_body.add_child(_ramp_shape)
	_ramp_shape.transform = _ramp_transform(false)
	_landing = global_position
	_gun = MountedGun.new(self, model.door_gun, GUN_MUZZLE)
	_gun.reach = GUN_RANGE
	_gun.damage = GUN_DAMAGE
	_gun.burst = GUN_BURST
	_gun.round_interval = GUN_ROUND_INTERVAL
	_gun.burst_pause = GUN_BURST_PAUSE
	_gun.spread = GUN_SPREAD
	_gun.noise = GUN_NOISE
	_gun.turn_speed = GUN_TURN_SPEED
	_gun.aim_tolerance = GUN_AIM_TOLERANCE
	_gun.search_interval = GUN_SEARCH_INTERVAL
	_gun.covers = gun_covers
	_gun.excluded = body_rids
	# Les éclairs du canon trahissent l'appareil, même tous feux éteints.
	_gun.on_burst = func() -> void: _revealed_left = MUZZLE_REVEAL
	blacked_out = LevelRoot.is_night(self)
	model.set_lights(not blacked_out)
	_landing_yaw = global_rotation.y
	if insertion:
		_start_insertion.call_deferred()
	elif extraction:
		_go_away()


## Forme de la rampe (repère local), relevée ou abaissée, autour de sa
## charnière (au bord du plancher, rotation sur X comme dans le modèle).
func _ramp_transform(closed: bool) -> Transform3D:
	var angle := TiltrotorModel.RAMP_CLOSED_ANGLE if closed else TiltrotorModel.RAMP_OPEN_ANGLE
	var length := TiltrotorModel.ramp_length() * (TiltrotorModel.RAMP_CLOSED_LENGTH if closed else 1.0)
	var hinge := Vector3(0, TiltrotorModel.FLOOR, TiltrotorModel.CABIN_BACK) * SCALE
	return Transform3D(Basis(Vector3.RIGHT, angle), hinge) * Transform3D(Basis.IDENTITY, Vector3(0, -0.05, length * SCALE * 0.5))


## Ajoute à `body` une forme pour la boîte `box` (repère du modèle, avant
## mise à l'échelle) ; la garde pour `distance_to_hull`.
func _add_box(body: StaticBody3D, box: AABB) -> void:
	var scaled := AABB(box.position * SCALE, box.size * SCALE)
	hull_boxes.append(scaled)
	var shape := CollisionShape3D.new()
	var cube := BoxShape3D.new()
	cube.size = scaled.size
	shape.shape = cube
	shape.position = scaled.get_center()
	body.add_child(shape)


## Soute (repère local) : du plancher au plafond, de la cloison au haut de
## la rampe.
func cabin_box() -> AABB:
	return AABB(Vector3(-TiltrotorModel.CABIN_HALF_WIDTH, TiltrotorModel.FLOOR - 0.3, TiltrotorModel.CABIN_FRONT) * SCALE,
		Vector3(TiltrotorModel.CABIN_HALF_WIDTH * 2.0, TiltrotorModel.CABIN_CEILING - TiltrotorModel.FLOOR + 0.3, TiltrotorModel.CABIN_BACK - TiltrotorModel.CABIN_FRONT) * SCALE)


## Vrai si `point` (monde) est dans la soute.
func cabin_contains(point: Vector3) -> bool:
	return not is_away and cabin_box().has_point(to_local(point))


## Place de la `index`-ième unité qui embarque : les unes derrière les
## autres, dans l'axe de la soute, de l'avant vers la rampe.
func cabin_point(index: int = 0) -> Vector3:
	# Un véhicule garé à l'avant : les places commencent derrière lui.
	var front := TiltrotorModel.CABIN_FRONT + 1.0
	if cargo:
		front = (Sabre.STOW_Z + 3.6) / SCALE
	var z := lerpf(front, TiltrotorModel.CABIN_BACK - 0.8, fposmod(index * 0.3, 1.0))
	return to_global(Vector3(0, TiltrotorModel.FLOOR, z) * SCALE)


## Appareil dont la soute contient `point`, ou null.
static func cabin_at(tree: SceneTree, point: Vector3) -> Tiltrotor:
	for node in tree.get_nodes_in_group(GROUP):
		var aircraft := node as Tiltrotor
		if aircraft and aircraft.cabin_contains(point):
			return aircraft
	return null


## Vrai si `collider` est la coque d'un appareil translucide (opérateur à
## bord) : les clics la traversent jusqu'au plancher.
static func is_revealed_body(collider: Object) -> bool:
	var aircraft := collider as Tiltrotor
	return aircraft != null and aircraft.model.is_cut()


## Relève (`closed`) ou abaisse la rampe. Renvoie faux si rien n'a changé
## (déjà dans cet état, appareil détruit ou en vol, quelqu'un sur la rampe).
func set_ramp_closed(closed: bool, animate: bool = true) -> bool:
	if closed == is_ramp_closed or is_destroyed or is_flying or is_moving or is_away or is_inbound:
		return false
	if is_ramp_blocked():
		return false
	_apply_ramp(closed, animate)
	Sfx.play_at(&"clink", to_global(Vector3(0, TiltrotorModel.FLOOR, TiltrotorModel.CABIN_BACK) * SCALE), -4.0)
	return true


func _apply_ramp(closed: bool, animate: bool) -> void:
	is_ramp_closed = closed
	if closed and _rope:
		_rope.queue_free()
		_rope = null
	model.set_ramp_closed(closed, RAMP_TIME if animate else 0.0)
	_ramp_shape.transform = _ramp_transform(closed)
	EventBus.navigation_obstacle_moved.emit()
	EventBus.sight_blockers_changed.emit()


## Vrai si une unité se tient sur la rampe (ou sous elle, à son pied).
func is_ramp_blocked() -> bool:
	for group: StringName in [&"commandos", Enemy.ALL_GROUP, &"vips"]:
		for node in get_tree().get_nodes_in_group(group):
			var unit := node as Node3D
			if unit == null:
				continue
			var local := to_local(unit.global_position) / SCALE
			if absf(local.x) < TiltrotorModel.RAMP_HALF_WIDTH + 0.4 \
					and local.z > TiltrotorModel.CABIN_BACK - 0.3 and local.z < TiltrotorModel.RAMP_END + 0.4 \
					and local.y < TiltrotorModel.FLOOR + 0.5:
				return true
	return false


## Opérateurs vivants dans la soute.
func passengers() -> Array[Commando]:
	var aboard: Array[Commando] = []
	for node in get_tree().get_nodes_in_group(&"commandos"):
		var unit := node as Commando
		if unit and not unit.is_dead and cabin_contains(unit.global_position + Vector3.UP * 0.3):
			aboard.append(unit)
	return aboard


## Raison pour laquelle on ne peut pas décoller (vide : c'est possible).
func take_off_problem() -> String:
	if is_destroyed:
		return "appareil détruit"
	if is_flying:
		return "déjà en vol"
	if is_away or is_inbound:
		return "pas encore arrivé"
	if is_disabled:
		return "appareil endommagé"
	if is_airborne or is_moving:
		return "atterrir d'abord"
	var aboard := passengers()
	if aboard.is_empty():
		return "personne à bord"
	for node in get_tree().get_nodes_in_group(&"commandos"):
		var unit := node as Commando
		if unit and not unit.is_dead and not aboard.has(unit):
			return "tous les opérateurs à bord"
	if not is_ramp_closed and is_ramp_blocked():
		return "quelqu'un sur la rampe"
	return ""


## `pilot` prend les commandes : rampe relevée, rotors lancés, puis
## décollage avec les passagers ; objectif rempli, mission réussie.
## Renvoie faux si c'est impossible (`take_off_problem`).
func take_off(pilot: Commando) -> bool:
	if take_off_problem() != "":
		return false
	if not is_ramp_closed:
		_apply_ramp(true, true)
	is_flying = true
	for unit in passengers():
		unit.stop()
		_passengers[unit] = _local_transform(unit)
	for vip in vips_aboard():
		_passengers[vip] = _local_transform(vip)
	if pilot:
		pilot.stop()
	if cargo:
		_passengers[cargo] = _local_transform(cargo)
	EventBus.noise_emitted.emit(global_position, ROTOR_NOISE, &"help")
	var flight := create_tween()
	flight.tween_property(model, "rotor_speed", FLIGHT_ROTOR_SPEED, SPIN_UP).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	flight.tween_callback(_lift_passengers)
	var goal := global_position + Vector3.UP * CLIMB_HEIGHT - global_basis.z * CLIMB_DISTANCE
	flight.tween_property(self, "global_position", goal, CLIMB_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	flight.tween_callback(_flown_away)
	return true


## Corps de l'appareil (coque, plancher et rampe), que les tirs depuis la
## soute ignorent porte ouverte.
func body_rids() -> Array[RID]:
	return [get_rid(), floor_body.get_rid()]


## Raison pour laquelle on ne peut pas monter en vol stationnaire (vide :
## c'est possible).
func rise_problem() -> String:
	if is_destroyed:
		return "appareil détruit"
	if is_away or is_inbound:
		return "pas encore arrivé"
	if is_disabled:
		return "appareil endommagé"
	if is_flying or is_airborne or is_moving:
		return "déjà en vol"
	if passengers().is_empty():
		return "personne à bord"
	if not is_ramp_closed and is_ramp_blocked():
		return "quelqu'un sur la rampe"
	return ""


## Monte en vol stationnaire à `HOVER_HEIGHT` avec les opérateurs à bord.
func rise() -> bool:
	if rise_problem() != "":
		return false
	ground_y = global_position.y
	hover_height = HOVER_LEVELS[0]
	_move_to_height(ground_y + hover_height, true)
	return true


## Raison pour laquelle on ne peut pas atterrir (vide : c'est possible).
func land_problem() -> String:
	if not is_airborne or is_moving:
		return "pas en vol"
	if _rappelling > 0:
		return "rappel en cours"
	if _winching > 0:
		return "treuillage en cours"
	if slung_load:
		return "charge élinguée"
	if pickup_left > 0.0:
		return "ne se pose pas"
	if _someone_below():
		return "quelqu'un sous l'appareil"
	if not _flat_below():
		return "terrain impropre"
	return ""


## Se repose au sol avec les opérateurs restés à bord.
func land() -> bool:
	if land_problem() != "":
		return false
	if _rope:
		_rope.queue_free()
		_rope = null
	_move_to_height(ground_y, false)
	return true


## Monte (`up`) ou descend jusqu'à `height`, rotors lancés ; les passagers
## suivent, physique suspendue.
func _move_to_height(height: float, up: bool) -> void:
	is_moving = true
	is_airborne = false
	_carry(passengers())
	EventBus.noise_emitted.emit(Vector3(global_position.x, ground_y, global_position.z), rotor_noise_radius(), &"help")
	_flight = create_tween()
	if up and model.rotor_speed < FLIGHT_ROTOR_SPEED - 0.01:
		_flight.tween_property(model, "rotor_speed", FLIGHT_ROTOR_SPEED, SPIN_UP * 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_flight.tween_property(self, "global_position:y", height, HOVER_TIME).set_trans(Tween.TRANS_SINE)
	if not up:
		_flight.tween_property(model, "rotor_speed", 0.0, SPIN_UP * 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_flight.tween_callback(_arrived.bind(up))


func _arrived(up: bool) -> void:
	is_moving = false
	_settle_left = SETTLE_TIME
	is_airborne = up
	for unit: Node3D in _passengers:
		if is_instance_valid(unit) and unit is CharacterBody3D:
			unit.process_mode = Node.PROCESS_MODE_INHERIT
			(unit as CharacterBody3D).velocity = Vector3.ZERO
	_passengers.clear()
	for unit in passengers():
		unit.airborne_in = self if up else null
	# Le sol sous l'appareil se libère (ou se referme) pour la navigation.
	EventBus.navigation_obstacle_moved.emit()
	EventBus.sight_blockers_changed.emit()
	if up and hover_objective != &"":
		EventBus.objective_completed.emit(hover_objective)


## Passagers emportés : ils suivent l'appareil, physique suspendue.
func _carry(units: Array[Commando]) -> void:
	for unit in units:
		unit.stop()
		unit.airborne_in = null
		unit.process_mode = Node.PROCESS_MODE_DISABLED
		_passengers[unit] = _local_transform(unit)
	# Le véhicule garé dans la soute suit aussi.
	if cargo:
		_passengers[cargo] = _local_transform(cargo)


## Place de `node` dans le repère de l'appareil.
func _local_transform(node: Node3D) -> Transform3D:
	return global_transform.affine_inverse() * node.global_transform


## Vrai si une unité se tient au sol sous l'emprise de l'appareil (sans les
## ennemis si `friends_only`).
func _someone_below(friends_only: bool = false) -> bool:
	var groups: Array[StringName] = [&"commandos", &"vips"]
	if not friends_only:
		groups.append(Enemy.ALL_GROUP)
	for group: StringName in groups:
		for node in get_tree().get_nodes_in_group(group):
			var unit := node as Node3D
			if unit == null or (unit is Commando and (unit as Commando).airborne_in == self):
				continue
			var local := to_local(unit.global_position)
			for box in hull_boxes:
				if local.x > box.position.x - 0.5 and local.x < box.end.x + 0.5 \
						and local.z > box.position.z - 0.5 and local.z < box.end.z + 0.5 \
						and local.y < -1.0:
					return true
	return false


## Bout de la rampe abaissée (monde), où s'accroche la corde de rappel.
func ramp_tip() -> Vector3:
	return model.ramp_pivot.to_global(Vector3(0, 0, TiltrotorModel.ramp_length()))


## Pied de la corde : premier sol (terrain, toit, caisse) sous le bout de la
## rampe.
func rope_foot() -> Vector3:
	var tip := ramp_tip()
	return _surface_below(tip, Vector3(tip.x, ground_y, tip.z))


## Premier sol sous `from` (l'appareil ignoré), ou `fallback`.
func _surface_below(from: Vector3, fallback: Vector3) -> Vector3:
	var start := Vector3(from.x, maxf(from.y, global_position.y + 6.0), from.z)
	var query := PhysicsRayQueryParameters3D.create(start, start + Vector3.DOWN * 300.0, 0b11, body_rids())
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit["position"] if not hit.is_empty() else fallback


## Vrai si le sol sous l'appareil est plat : nez, queue et nacelles au
## niveau du centre.
func _flat_below() -> bool:
	var center := _surface_below(global_position, Vector3.INF)
	if center == Vector3.INF:
		return false
	for local: Vector3 in [Vector3(0, 0, -8.0), Vector3(0, 0, 8.0), Vector3(-5.2, 0, 4.4), Vector3(5.2, 0, 4.4), Vector3(-4.8, 0, -3.0), Vector3(4.8, 0, -3.0)]:
		var point := _surface_below(to_global(local * SCALE), Vector3.INF)
		if point == Vector3.INF or absf(point.y - center.y) > LANDING_TOLERANCE:
			return false
	ground_y = center.y
	return true


## Rayon (m) du bruit des rotors au sol : plein jusqu'au premier palier, il
## décroît avec la hauteur jusqu'à `HIGH_NOISE_SHARE` au dernier.
func rotor_noise_radius() -> float:
	var floor_y := _landing.y if is_inbound else ground_y
	var height := global_position.y - floor_y
	var low := HOVER_LEVELS[0]
	var high := HOVER_LEVELS[HOVER_LEVELS.size() - 1]
	return ROTOR_NOISE * lerpf(1.0, HIGH_NOISE_SHARE, clampf((height - low) / (high - low), 0.0, 1.0))


## Précision gardée par un tireur à bord (voir `Commando.steadiness`) :
## réduite en vol, davantage tant que l'appareil se stabilise.
func steadiness() -> float:
	if not is_airborne:
		return 1.0
	return lerpf(HOVER_STEADINESS, MOVING_STEADINESS, _settle_left / SETTLE_TIME)


## Palier voisin (plus haut si `up`), ou -1 s'il n'y en a pas.
func next_altitude(up: bool) -> float:
	var index := HOVER_LEVELS.find(hover_height)
	if index < 0:
		index = 0
	index += 1 if up else -1
	return HOVER_LEVELS[index] if index >= 0 and index < HOVER_LEVELS.size() else -1.0


## Monte (`up`) ou descend d'un palier en vol stationnaire. Renvoie faux si
## c'est impossible.
func change_altitude(up: bool) -> bool:
	var height := next_altitude(up)
	if height < 0.0 or fly_problem() != "":
		return false
	if _rope:
		_rope.queue_free()
		_rope = null
	hover_height = height
	_move_to_height(ground_y + hover_height, true)
	return true


## Raison pour laquelle l'appareil ne peut pas se déplacer (vide : c'est
## possible).
func fly_problem() -> String:
	if is_disabled:
		return "appareil endommagé"
	if not is_airborne or is_moving:
		return "pas en vol stationnaire"
	if _rappelling > 0:
		return "rappel en cours"
	if _winching > 0:
		return "treuillage en cours"
	if _sling_dir != 0:
		return "élingage en cours"
	if pickup_left > 0.0:
		return "attend l'équipe sur place"
	return ""


## Vole en vol stationnaire jusqu'au-dessus de `point` : pivote vers lui,
## avance, et s'arrête le bout de la rampe au-dessus du point (pour y
## descendre en rappel). Renvoie faux si c'est impossible.
func fly_to(point: Vector3) -> bool:
	if fly_problem() != "":
		return false
	var flat := point - global_position
	flat.y = 0.0
	if flat.length() < 1.0:
		return false
	var yaw := atan2(-flat.x, -flat.z)
	var turn := wrapf(yaw - global_rotation.y, -PI, PI)
	var goal := point - Basis(Vector3.UP, yaw) * Vector3(0, 0, TiltrotorModel.RAMP_END * SCALE)
	var below := _surface_below(Vector3(goal.x, global_position.y, goal.z), Vector3(goal.x, ground_y, goal.z))
	var height := hover_height
	goal.y = maxf(point.y, below.y) + height
	is_moving = true
	is_airborne = false
	if _rope:
		_rope.queue_free()
		_rope = null
	_carry(passengers())
	_noise_left = 0.0
	_flight = create_tween()
	if absf(turn) > 0.01:
		_flight.tween_property(self, "global_rotation:y", global_rotation.y + turn, absf(turn) * TURN_TIME).set_trans(Tween.TRANS_SINE)
	var travel := Vector2(goal.x - global_position.x, goal.z - global_position.z).length()
	_flight.tween_property(self, "global_position", goal, maxf(travel / FLY_SPEED, 1.5)).set_trans(Tween.TRANS_SINE)
	_flight.tween_callback(func() -> void:
		ground_y = goal.y - height
		_arrived(true))
	return true


## Raison pour laquelle `unit` ne peut pas descendre en rappel (vide :
## c'est possible).
func rappel_problem(unit: Commando) -> String:
	if not is_airborne or is_moving:
		return "au sol"
	if is_ramp_closed:
		return "ouvrir la porte d'abord"
	if unit == null or unit.airborne_in != self:
		return "pas à bord"
	return ""


## `unit` rejoint le bout de la rampe et descend le long de la corde
## jusqu'au sol, physique suspendue.
func rappel(unit: Commando) -> bool:
	if rappel_problem(unit) != "":
		return false
	var tip := ramp_tip()
	var foot := rope_foot()
	_show_rope(tip, foot)
	unit.stop()
	unit.airborne_in = null
	unit.process_mode = Node.PROCESS_MODE_DISABLED
	_rappelling += 1
	if unit.posture != SoldierModel.Posture.STANDING:
		unit.toggle_posture(SoldierModel.Posture.STANDING)
	var start := unit.global_position
	var out := _rope_out()
	# Sous la corde : les mains au point d'attache, puis glissade jusqu'au sol.
	var hang := tip + out * SoldierModel.ROPE_GAP + Vector3.DOWN * SoldierModel.ROPE_HAND_HEIGHT
	var landing := foot + out * SoldierModel.ROPE_GAP
	var descent := create_tween()
	descent.tween_property(unit, "global_position", tip + Vector3.UP * 0.1, clampf(start.distance_to(tip) / 3.5, 0.4, 2.0))
	descent.tween_callback(func() -> void: _grab_rope(unit, SoldierModel.RopeMove.FAST_ROPE, out))
	descent.tween_property(unit, "global_position", hang, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	descent.tween_property(unit, "global_position", landing, maxf(hang.y - landing.y, 0.1) / RAPPEL_SPEED).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	descent.tween_callback(func() -> void:
		_rappelling -= 1
		_grab_rope(unit, SoldierModel.RopeMove.NONE, out)
		unit.process_mode = Node.PROCESS_MODE_INHERIT
		unit.velocity = Vector3.ZERO
		if rappel_objective != &"":
			EventBus.objective_completed.emit(rappel_objective))
	return true


# --- Hélitreuillage -------------------------------------------------------------

## Raison pour laquelle on ne peut pas treuiller (vide : c'est possible).
func winch_problem() -> String:
	if is_disabled:
		return "appareil endommagé"
	if not is_airborne or is_moving:
		return "pas en vol stationnaire"
	if is_ramp_closed:
		return "porte fermée"
	return ""


## Envoie `unit` (au sol) au pied de la corde pour y être treuillé. Renvoie
## faux si c'est impossible.
func request_winch(unit: Commando, run: bool) -> bool:
	if winch_problem() != "" or unit == null or unit.is_dead or unit.airborne_in or unit.riding:
		return false
	var foot := rope_foot()
	_show_rope(ramp_tip(), foot)
	_winch_requests[unit] = true
	var map := get_world_3d().navigation_map
	unit.move_to(NavigationServer3D.map_get_closest_point(map, foot), run)
	return true


## Accroche les opérateurs arrivés au pied de la corde, et les VIP qui s'y
## tiennent.
func _update_winch() -> void:
	if not _rope or winch_problem() != "":
		_winch_requests.clear()
		return
	var foot := rope_foot()
	for unit: Commando in _winch_requests.keys():
		if not is_instance_valid(unit) or unit.is_dead or unit.airborne_in:
			_winch_requests.erase(unit)
			continue
		if _at_rope_foot(unit, foot):
			_winch_requests.erase(unit)
			_hoist(unit)
		elif not unit.is_walking() and unit._agent.target_position.distance_to(foot) > 2.0:
			# Un autre ordre l'emmène ailleurs.
			_winch_requests.erase(unit)
	for node in get_tree().get_nodes_in_group(&"vips"):
		var vip := node as Vip
		if vip and not vip.is_dead and not vip.is_evacuated and vip.process_mode != Node.PROCESS_MODE_DISABLED and _at_rope_foot(vip, foot):
			_hoist(vip)


func _at_rope_foot(unit: Node3D, foot: Vector3) -> bool:
	var flat := Vector2(unit.global_position.x - foot.x, unit.global_position.z - foot.z).length()
	return flat <= WINCH_REACH and absf(unit.global_position.y - foot.y) <= WINCH_HEIGHT


## Treuille `unit` le long de la corde jusqu'au bout de la rampe, puis dans
## la soute, physique suspendue.
func _hoist(unit: CharacterBody3D) -> void:
	if unit is Commando:
		(unit as Commando).stop()
	unit.process_mode = Node.PROCESS_MODE_DISABLED
	unit.velocity = Vector3.ZERO
	_winching += 1
	var tip := ramp_tip()
	var foot := rope_foot()
	var seat := cabin_point(passengers().size() + _winching)
	Sfx.play_at(&"clink", foot + Vector3.UP, -4.0)
	var out := _rope_out()
	_grab_rope(unit, SoldierModel.RopeMove.HOIST, out)
	# Pendu au crochet, mains sous le point d'attache, puis hissé sur la rampe.
	var hooked := Vector3(foot.x, unit.global_position.y, foot.z) + out * SoldierModel.ROPE_GAP
	var top := tip + out * SoldierModel.ROPE_GAP + Vector3.DOWN * (SoldierModel.ROPE_HAND_HEIGHT - 0.1)
	var lift := create_tween()
	lift.tween_property(unit, "global_position", hooked, 0.3)
	lift.tween_property(unit, "global_position", top, maxf(top.y - hooked.y, 0.5) / WINCH_SPEED).set_trans(Tween.TRANS_SINE)
	lift.tween_callback(func() -> void: _grab_rope(unit, SoldierModel.RopeMove.NONE, out))
	lift.tween_property(unit, "global_position", tip + Vector3.UP * 0.05, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	lift.tween_property(unit, "global_position", seat, clampf(tip.distance_to(seat) / 3.0, 0.4, 2.5))
	lift.tween_callback(func() -> void:
		_winching -= 1
		unit.process_mode = Node.PROCESS_MODE_INHERIT
		unit.velocity = Vector3.ZERO
		if unit is Commando and is_airborne:
			(unit as Commando).airborne_in = self)


## Direction horizontale du bout de la rampe vu du centre de l'appareil :
## l'unité sur la corde se tient de ce côté, face à l'appareil.
func _rope_out() -> Vector3:
	var out := ramp_tip() - global_position
	out.y = 0.0
	return out.normalized() if out.length() > 0.1 else global_basis.z


## Met `unit` (opérateur ou VIP) dans la pose de la corde `move` (ou l'en
## sort avec `NONE`), face à la corde. Son traitement est suspendu pendant
## le trajet : son modèle continue de s'animer (sauf en pause).
func _grab_rope(unit: Node3D, move: SoldierModel.RopeMove, out: Vector3) -> void:
	if not is_instance_valid(unit):
		return
	var model := unit.get(&"_model") as SoldierModel
	if move != SoldierModel.RopeMove.NONE:
		unit.global_rotation.y = atan2(out.x, out.z)
	if model == null:
		return
	model.rope_move = move
	model.process_mode = Node.PROCESS_MODE_PAUSABLE if move != SoldierModel.RopeMove.NONE else Node.PROCESS_MODE_INHERIT


## Corde de rappel, du bout de la rampe au sol.
func _show_rope(tip: Vector3, foot: Vector3) -> void:
	if _rope:
		return
	_rope = MeshInstance3D.new()
	_rope.name = "Rope"
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.025
	cylinder.bottom_radius = 0.025
	cylinder.height = tip.y - foot.y
	cylinder.radial_segments = 6
	_rope.mesh = cylinder
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.55, 0.5, 0.38)
	material.roughness = 0.9
	_rope.material_override = material
	add_child(_rope)
	_rope.global_position = (tip + foot) * 0.5


## Les passagers suivent l'appareil (leur physique est suspendue) ; en vol,
## la coque redevient opaque.
func _lift_passengers() -> void:
	model.set_cutaway(false)
	for unit: Node3D in _passengers:
		if is_instance_valid(unit) and unit is CharacterBody3D:
			unit.process_mode = Node.PROCESS_MODE_DISABLED


func _flown_away() -> void:
	if objective_id != &"":
		EventBus.objective_completed.emit(objective_id)
	if ends_mission:
		EventBus.mission_ended.emit(true, "RÉUSSITE — équipe extraite" if extraction else "RÉUSSITE — appareil volé")


## VIP vivants, pas encore évacués, dans la soute.
func vips_aboard() -> Array[Vip]:
	var aboard: Array[Vip] = []
	for node in get_tree().get_nodes_in_group(&"vips"):
		var vip := node as Vip
		if vip and not vip.is_dead and not vip.is_evacuated and cabin_contains(vip.global_position + Vector3.UP * 0.3):
			aboard.append(vip)
	return aboard


# --- Canon latéral ------------------------------------------------------------

## Raison pour laquelle `unit` ne peut pas servir le canon (vide : c'est
## possible).
func gun_problem(unit: Commando) -> String:
	if is_destroyed:
		return "appareil détruit"
	if is_flying:
		return "en partance"
	if unit == null or unit.is_dead or not _is_aboard(unit):
		return "pas à bord"
	if gunner and gunner != unit and _gunner_ok():
		return "%s le sert déjà" % gunner.display_name
	return ""


## `unit` prend le canon : il tire seul sur les ennemis en vue.
func man_gun(unit: Commando) -> bool:
	if gun_problem(unit) != "":
		return false
	gunner = unit
	_gun.reset()
	unit.stop()
	unit.flash_message("Canon latéral : feu à volonté")
	return true


## Le servant lâche le canon.
func leave_gun() -> void:
	gunner = null
	_gun.reset()


func _is_aboard(unit: Commando) -> bool:
	return unit.airborne_in == self or cabin_contains(unit.global_position + Vector3.UP * 0.3)


func _gunner_ok() -> bool:
	return is_instance_valid(gunner) and not gunner.is_dead and _is_aboard(gunner)


## Bouche du canon (monde).
func gun_muzzle() -> Vector3:
	return _gun.muzzle()


## Vrai si `point` est dans le champ du canon : côté droit, vers l'avant ou
## le travers, à portée.
func gun_covers(point: Vector3) -> bool:
	var pivot := model.door_gun.global_position
	if pivot.distance_to(point) > GUN_RANGE:
		return false
	var local := (global_basis.inverse() * (point - pivot)).normalized()
	return local.x > 0.2 and local.z < 0.35


## Stroboscope infrarouge : éclairs réguliers, vol de nuit, appareil visible,
## pas détruit, et seulement à travers les jumelles de vision nocturne.
func _update_strobe(delta: float) -> void:
	var lit := blacked_out and visible and not is_destroyed and NightVision.viewing
	if lit:
		_strobe_time = fmod(_strobe_time + delta, STROBE_PERIOD)
	model.ir_strobe.visible = lit and _strobe_time < STROBE_FLASH


func _update_gun(delta: float) -> void:
	if gunner and not _gunner_ok():
		leave_gun()
	_gun.update(delta, gunner != null and not is_destroyed and not is_flying and not is_away and not is_inbound)


# --- Riposte ------------------------------------------------------------------

## Vrai si l'appareil est en l'air, à portée des tirs ennemis (approche,
## montée, vol stationnaire, descente ; pas en partance).
func is_in_air() -> bool:
	return not is_destroyed and not is_flying and not is_away and (is_inbound or is_moving or is_airborne)


## Distance à laquelle un tireur ennemi voit l'appareil, au plus `reach` :
## courte tous feux éteints, sauf juste après une rafale du canon.
func sight_range(reach: float) -> float:
	if blacked_out and _revealed_left <= 0.0:
		return minf(reach, BLACKOUT_SIGHT)
	return reach


## Point visé par les tireurs (monde).
func aim_point() -> Vector3:
	return to_global(AIM_POINT * SCALE)


## Vrai si un tireur en `eye` voit l'appareil à moins de `reach` (la coque
## est le premier obstacle sur la ligne).
func exposed_to(eye: Vector3, reach: float) -> bool:
	var target := aim_point()
	if eye.distance_to(target) > sight_range(reach):
		return false
	var query := PhysicsRayQueryParameters3D.create(eye, target, LAYER_OCCLUDERS)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit["collider"] == self or hit["collider"] == floor_body


## Une balle tirée de `from` frappe l'appareil en `at` : étincelles, structure
## entamée ; à zéro, il est abattu.
func take_hit(damage: float, at: Vector3, from: Vector3) -> void:
	if not is_in_air() or is_disabled:
		return
	ShotImpact.spark(get_parent() as Node3D, at, from)
	Sfx.play_at(&"ricochet", at, -4.0)
	structure = maxf(structure - damage * BULLET_SHARE, 0.0)
	_show_damage()
	if structure <= 0.0:
		_shot_down()


## Une roquette explose contre la coque (`Rocket`) : lourds dégâts.
func take_rocket(at: Vector3) -> void:
	if not is_in_air() or is_disabled:
		return
	structure = maxf(structure - ROCKET_DAMAGE, 0.0)
	_show_damage()
	if structure <= 0.0:
		_shot_down()


## Fumée sous la moitié de la structure, jauge dès la première balle.
func _show_damage() -> void:
	if structure < STRUCTURE and _gauge == null:
		_gauge = Label3D.new()
		_gauge.name = "Structure"
		_gauge.fixed_size = true
		_gauge.font_size = 26
		_gauge.outline_size = 8
		_gauge.pixel_size = 0.0012
		_gauge.outline_modulate = Color(0.0, 0.0, 0.0, 0.8)
		_gauge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_gauge.no_depth_test = true
		_gauge.shaded = false
		_gauge.position = Vector3(0.0, 5.5, 0.0)
		add_child(_gauge)
	if _gauge:
		var share := structure / STRUCTURE
		_gauge.text = "Abattu" if is_disabled else "Structure %d %%" % ceili(share * 100.0)
		_gauge.modulate = Color(1.0, 0.35, 0.25) if share <= SMOKE_SHARE else Color(1.0, 0.85, 0.4)
	if structure <= STRUCTURE * SMOKE_SHARE and _smoke == null:
		_smoke = _make_fire()
		_smoke.name = "Smoke"
		# Fumée seule : ni flammes, ni lueur.
		for child in _smoke.get_children():
			if child.name != "Smoke":
				child.queue_free()
		add_child(_smoke)


## Abattu : descente d'urgence à la verticale avec ceux à bord (ou, en
## approche, droit sur la zone de pose), rotors au ralenti ; hors d'usage.
func _shot_down() -> void:
	is_disabled = true
	_drop_load_now()
	if pickup_left > 0.0:
		pickup_left = 0.0
		_fail_extraction()
	_show_damage()
	if _flight:
		_flight.kill()
	if _rope:
		_rope.queue_free()
		_rope = null
	for unit in passengers():
		unit.flash_message("Appareil touché : atterrissage d'urgence")
	_flight = create_tween()
	if is_inbound:
		_flight.tween_property(self, "global_position", _landing, EMERGENCY_TIME * 1.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_flight.parallel().tween_property(model, "rotor_speed", 0.6, EMERGENCY_TIME * 1.6)
		_flight.tween_callback(_touched_down)
		return
	if is_diverting:
		# Abattu pendant une diversion : il tombe là où il est.
		is_diverting = false
		ground_y = _surface_below(global_position, Vector3(global_position.x, ground_y, global_position.z)).y
	is_moving = true
	is_airborne = false
	_carry(passengers())
	_flight.tween_property(self, "global_position:y", ground_y, EMERGENCY_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_flight.parallel().tween_property(model, "rotor_speed", 0.6, EMERGENCY_TIME)
	_flight.tween_callback(_crash_landed)


## Posé en urgence : les passagers reprennent pied, rotors arrêtés.
func _crash_landed() -> void:
	Sfx.play_at(&"fall", global_position + Vector3.UP, 0.0)
	EventBus.noise_emitted.emit(global_position, FUEL_NOISE, &"gunshot")
	_arrived(false)
	model.rotor_speed = 0.0
	_fail_extraction()


## Appareil d'extraction hors d'usage : plus moyen de repartir.
func _fail_extraction() -> void:
	if extraction:
		get_tree().create_timer(END_DELAY, false).timeout.connect(func() -> void:
			EventBus.mission_ended.emit(false, "ÉCHEC — appareil d'extraction abattu"))


# --- Extraction ---------------------------------------------------------------

## Pas encore appelé : caché, sans collision (la navigation passe sur son
## point de pose).
func _go_away() -> void:
	is_away = true
	visible = false
	_set_solid(false)


func _set_solid(solid: bool) -> void:
	collision_layer = LAYER_OCCLUDERS if solid else 0
	floor_body.collision_layer = LAYER_OCCLUDERS if solid else 0
	EventBus.navigation_obstacle_moved.emit()
	EventBus.sight_blockers_changed.emit()


# --- Insertion -------------------------------------------------------------------

## Début de mission : en vol stationnaire au plus haut palier, porte ouverte,
## toute l'équipe en soute.
func _start_insertion() -> void:
	ground_y = global_position.y
	hover_height = HOVER_LEVELS[HOVER_LEVELS.size() - 1]
	global_position.y = ground_y + hover_height
	model.rotor_speed = FLIGHT_ROTOR_SPEED
	model.set_cutaway(true)
	is_airborne = true
	var index := 0
	for node in get_tree().get_nodes_in_group(&"commandos"):
		var unit := node as Commando
		if unit and not unit.is_dead:
			unit.global_position = cabin_point(index)
			unit.velocity = Vector3.ZERO
			unit.airborne_in = self
			index += 1
	_noise_left = HOVER_NOISE_INTERVAL
	EventBus.navigation_obstacle_moved.emit()
	EventBus.sight_blockers_changed.emit()


## Raison pour laquelle on ne peut pas renvoyer l'appareil (vide : c'est
## possible).
func dismiss_problem() -> String:
	if is_destroyed or is_away or is_inbound or is_flying:
		return "pas disponible"
	if is_disabled:
		return "appareil endommagé"
	if not is_airborne or is_moving:
		return "pas en vol stationnaire"
	if _rappelling > 0 or _winching > 0:
		return "corde occupée"
	if slung_load:
		return "charge élinguée"
	if not passengers().is_empty() or not vips_aboard().is_empty():
		return "encore du monde à bord"
	return ""


## Appareil d'insertion qu'on peut renvoyer, ou null.
static func dismissable(tree: SceneTree) -> Tiltrotor:
	for node in tree.get_nodes_in_group(GROUP):
		var aircraft := node as Tiltrotor
		if aircraft and aircraft.insertion and not aircraft.is_away and not aircraft.is_inbound and not aircraft.is_destroyed:
			return aircraft
	return null


## Renvoie l'appareil, soute vide : il prend de la hauteur et s'éloigne. S'il
## est aussi l'appareil d'extraction, on peut le rappeler ensuite.
func dismiss() -> bool:
	if dismiss_problem() != "":
		return false
	is_moving = true
	is_airborne = false
	if _rope:
		_rope.queue_free()
		_rope = null
	_apply_ramp(true, true)
	leave_gun()
	_flight = create_tween()
	var goal := global_position + Vector3.UP * CLIMB_HEIGHT - global_basis.z * CLIMB_DISTANCE
	_flight.tween_property(self, "global_position", goal, CLIMB_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_flight.tween_callback(func() -> void:
		is_moving = false
		insertion = false
		model.rotor_speed = 0.0
		global_position = _landing
		global_rotation.y = _landing_yaw
		_go_away())
	return true


# --- Ravitaillement ---------------------------------------------------------------

## Raison pour laquelle `unit` ne peut pas se ravitailler (vide : c'est
## possible).
func resupply_problem(unit: Commando) -> String:
	if unit == null or not _is_aboard(unit):
		return "pas à bord"
	if supplies <= 0:
		return "soute vide"
	if unit.missing_supplies().is_empty():
		return "rien ne manque"
	return ""


## `unit`, à bord, reprend sa dotation de départ dans un lot de la soute.
func resupply(unit: Commando) -> bool:
	if resupply_problem(unit) != "":
		return false
	var taken := unit.resupply()
	supplies -= 1
	var parts: Array[String] = []
	for key: String in taken:
		parts.append("%s +%d" % [key, taken[key]])
	unit.flash_message("Ravitaillé : " + ", ".join(parts))
	return true


# --- Course contre la montre -----------------------------------------------------

## Au-dessus du point de pose : vol stationnaire, porte ouverte, décompte.
func _start_pickup() -> void:
	is_inbound = false
	ground_y = _landing.y
	hover_height = HOVER_HEIGHT
	is_airborne = true
	_settle_left = SETTLE_TIME
	_set_solid(true)
	_apply_ramp(false, true)
	pickup_left = pickup_window
	_pickup_told = -1


## Décompte : annonce toutes les 10 s, puis chaque seconde à la fin ; départ
## dès que toute l'équipe est à bord, ou à la fin du temps.
func _update_pickup(delta: float) -> void:
	if is_disabled:
		return
	pickup_left = maxf(pickup_left - delta, 0.0)
	var seconds := ceili(pickup_left)
	if seconds != _pickup_told and (seconds % 10 == 0 or seconds <= 5) and seconds > 0:
		_pickup_told = seconds
		for node in get_tree().get_nodes_in_group(&"commandos"):
			(node as Commando).flash_message("Extraction : départ dans %d s" % seconds)
	var everyone := _team_aboard()
	if (everyone and _winching == 0 and _ready_objectives()) or pickup_left <= 0.0:
		_leave_pickup(everyone and _winching == 0)


## Tous les opérateurs vivants (et les VIP) à bord.
func _team_aboard() -> bool:
	var aboard := passengers()
	for node in get_tree().get_nodes_in_group(&"commandos"):
		var unit := node as Commando
		if unit and not unit.is_dead and not aboard.has(unit):
			return false
	for node in get_tree().get_nodes_in_group(&"vips"):
		var vip := node as Vip
		if vip and not vip.is_dead and not vip.is_evacuated and not vips_aboard().has(vip):
			return false
	return not aboard.is_empty()


func _ready_objectives() -> bool:
	var objectives := get_tree().get_first_node_in_group(Objectives.GROUP) as Objectives
	return objectives == null or objectives.done_except(String(objective_id))


## Fin de l'attente : l'appareil repart avec ceux qui sont à bord. Réussite
## si toute l'équipe y est et les objectifs remplis, sinon échec.
func _leave_pickup(everyone: bool) -> void:
	pickup_left = 0.0
	_winch_requests.clear()
	if _rope:
		_rope.queue_free()
		_rope = null
	var success := everyone and _ready_objectives()
	is_airborne = false
	is_flying = true
	for unit in passengers():
		unit.stop()
		unit.airborne_in = null
		_passengers[unit] = _local_transform(unit)
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	for vip in vips_aboard():
		_passengers[vip] = _local_transform(vip)
		vip.process_mode = Node.PROCESS_MODE_DISABLED
	_apply_ramp(true, true)
	model.set_cutaway(false)
	var flight := create_tween()
	var goal := global_position + Vector3.UP * CLIMB_HEIGHT - global_basis.z * CLIMB_DISTANCE
	flight.tween_property(self, "global_position", goal, CLIMB_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if success:
		flight.tween_callback(_flown_away)
	else:
		var message := "ÉCHEC — l'appareil est reparti sans toute l'équipe" if not everyone else "ÉCHEC — appareil reparti, objectifs inachevés"
		flight.tween_callback(func() -> void: EventBus.mission_ended.emit(false, message))


# --- Élingage --------------------------------------------------------------------

## Charge qu'on peut élinguer sous l'appareil (caisse déplaçable libre,
## Sabre vide), la plus proche des crochets ou du pied de la corde, ou null.
func sling_candidate() -> Node3D:
	var hooks := to_global((SLING_HOOKS[0] + SLING_HOOKS[1]) * 0.5)
	var spots: Array[Vector3] = [hooks, rope_foot()]
	var best: Node3D
	var best_distance := SLING_REACH
	var candidates: Array[Node] = get_tree().get_nodes_in_group(Sabre.GROUP)
	for node in get_tree().get_nodes_in_group(QuickSave.GROUP):
		if node is Climbable:
			candidates.append(node)
	for node in candidates:
		var load := node as Node3D
		if not _can_sling(load):
			continue
		for spot in spots:
			var flat := Vector2(load.global_position.x - spot.x, load.global_position.z - spot.z).length()
			if flat < best_distance:
				best_distance = flat
				best = load
	return best


func _can_sling(load: Node3D) -> bool:
	var crate := load as Climbable
	if crate:
		return crate.movable and not crate.is_broken and crate.occupant == null and crate.handler == null and crate.visible
	var sabre := load as Sabre
	if sabre:
		return sabre.stowed_in == null and sabre.slung_by == null and not sabre.is_driving \
			and not sabre.is_maneuvering() and sabre.seats.count(null) == sabre.seats.size()
	return false


## Raison pour laquelle on ne peut pas élinguer (vide : c'est possible).
func sling_problem() -> String:
	if is_disabled:
		return "appareil endommagé"
	if not is_airborne or is_moving:
		return "pas en vol stationnaire"
	if slung_load:
		return "déjà une charge"
	if sling_candidate() == null:
		return "rien à élinguer sous l'appareil"
	return ""


## Accroche la charge la plus proche et la hisse sous les crochets.
func sling() -> bool:
	if sling_problem() != "":
		return false
	var load := sling_candidate()
	slung_load = load
	_sling_ground = load.global_transform
	var height := SLING_SABRE_HEIGHT if load is Sabre else (load as Climbable).top_height
	var hang := Vector3((SLING_HOOKS[0].x + SLING_HOOKS[1].x) * 0.5, SLING_HOOKS[0].y - SLING_LENGTH - height,
		(SLING_HOOKS[0].z + SLING_HOOKS[1].z) * 0.5)
	var yaw := load.global_rotation.y - global_rotation.y
	_sling_hang = Transform3D(Basis(Vector3.UP, yaw), hang)
	_attach_load(load)
	_sling_progress = 0.0
	_sling_dir = 1
	Sfx.play_at(&"clink", load.global_position + Vector3.UP, 0.0)
	return true


## Charge hors du monde physique pendant le transport : sans collision, ni
## poussée, ni montée dessus.
func _attach_load(load: Node3D) -> void:
	var body := load as CollisionObject3D
	_sling_saved = {"layer": body.collision_layer}
	var crate := load as Climbable
	if crate:
		_sling_saved["movable"] = crate.movable
		_sling_saved["stand"] = crate.can_stand_on
		crate.movable = false
		crate.can_stand_on = false
	var sabre := load as Sabre
	if sabre:
		sabre.slung_by = self
	body.collision_layer = 0
	EventBus.navigation_obstacle_moved.emit()
	EventBus.sight_blockers_changed.emit()
	for hook in SLING_HOOKS:
		var cable := MeshInstance3D.new()
		var tube := CylinderMesh.new()
		tube.top_radius = 0.035
		tube.bottom_radius = 0.035
		tube.height = 1.0
		tube.radial_segments = 6
		cable.mesh = tube
		var dark := StandardMaterial3D.new()
		dark.albedo_color = Color(0.12, 0.12, 0.1)
		cable.material_override = dark
		add_child(cable)
		_sling_cables.append(cable)


## Raison pour laquelle on ne peut pas larguer (vide : c'est possible).
func drop_problem() -> String:
	if slung_load == null:
		return "pas de charge"
	if _sling_dir != 0:
		return "élingage en cours"
	if not is_airborne or is_moving:
		return "pas en vol stationnaire"
	return ""


## Dépose la charge au sol (ou sur un toit) sous l'appareil.
func drop_load() -> bool:
	if drop_problem() != "":
		return false
	var at := slung_load.global_position
	var ground := _surface_below(at, Vector3(at.x, ground_y, at.z))
	_sling_ground = Transform3D(slung_load.global_basis, ground)
	_sling_dir = -1
	return true


## Levée, transport, dépose : la charge suit l'appareil, élingues tendues.
func _update_sling(delta: float) -> void:
	if slung_load == null:
		return
	if not is_instance_valid(slung_load):
		_release_load()
		return
	_sling_progress = clampf(_sling_progress + _sling_dir * delta / SLING_TIME, 0.0, 1.0)
	var hanging := global_transform * _sling_hang
	var eased := ease(_sling_progress, -1.8)
	slung_load.global_transform = _sling_ground.interpolate_with(hanging, eased)
	if _sling_dir > 0 and _sling_progress >= 1.0:
		_sling_dir = 0
	elif _sling_dir < 0 and _sling_progress <= 0.0:
		slung_load.global_transform = _sling_ground
		Sfx.play_at(&"fall", slung_load.global_position + Vector3.UP * 0.5, -4.0)
		_release_load()
		return
	var height := SLING_SABRE_HEIGHT if slung_load is Sabre else (slung_load as Climbable).top_height
	var top := to_local(slung_load.global_position + Vector3.UP * height)
	for index in _sling_cables.size():
		_stretch(_sling_cables[index], SLING_HOOKS[index], top)


## Élingue entre `from` et `to` (repère de l'appareil).
func _stretch(cable: MeshInstance3D, from: Vector3, to: Vector3) -> void:
	var span := to - from
	var length := maxf(span.length(), 0.01)
	var along := span / length
	var side := along.cross(Vector3.BACK)
	if side.length() < 0.1:
		side = Vector3.RIGHT
	side = side.normalized()
	cable.transform = Transform3D(Basis(side, along * length, side.cross(along)), from + span * 0.5)


## La charge reprend sa place dans le monde (collision, poussée).
func _release_load() -> void:
	for cable in _sling_cables:
		cable.queue_free()
	_sling_cables.clear()
	_sling_dir = 0
	_sling_progress = 0.0
	var load := slung_load
	slung_load = null
	if not is_instance_valid(load):
		return
	(load as CollisionObject3D).collision_layer = _sling_saved.get("layer", LAYER_OCCLUDERS)
	var crate := load as Climbable
	if crate:
		crate.movable = _sling_saved.get("movable", true)
		crate.can_stand_on = _sling_saved.get("stand", true)
	var sabre := load as Sabre
	if sabre:
		sabre.slung_by = null
	EventBus.navigation_obstacle_moved.emit()
	EventBus.sight_blockers_changed.emit()


## Sauvegarde rapide : la charge reprend place sous les crochets (après le
## chargement de son propre état).
func _resling(path: NodePath, hang: Transform3D) -> void:
	var load := get_node_or_null(path) as Node3D
	if load == null or slung_load:
		return
	slung_load = load
	_sling_hang = hang
	_attach_load(load)
	_sling_ground = global_transform * hang
	_sling_progress = 1.0
	_sling_dir = 0


## Abattu ou rechargé avec une charge : elle tombe sous l'appareil.
func _drop_load_now() -> void:
	if slung_load == null:
		return
	if is_instance_valid(slung_load):
		var at := slung_load.global_position
		slung_load.global_transform = Transform3D(slung_load.global_basis, _surface_below(at, Vector3(at.x, ground_y, at.z)))
	_release_load()


# --- Documents -------------------------------------------------------------------

## Documents arrivés à bord (opérateur qui les porte, corps de l'officier) :
## objectif `documents_objective` rempli.
func _check_documents() -> void:
	if documents_objective == &"" or _documents_aboard:
		return
	var found := false
	for unit in passengers():
		if unit.has_documents:
			found = true
	for node in get_tree().get_nodes_in_group(Enemy.DOCUMENTS_GROUP):
		var officer := node as Enemy
		if officer and officer.documents and officer.is_body() and cabin_contains(officer.body_center()):
			found = true
	if found:
		_documents_aboard = true
		for unit in passengers():
			unit.flash_message("Documents à bord")
		EventBus.objective_completed.emit(documents_objective)


# --- Évacuation des blessés -----------------------------------------------------

## Raison pour laquelle `unit` ne peut pas être évacué (vide : c'est
## possible).
func evacuation_problem(unit: Commando) -> String:
	if unit == null or not _is_aboard(unit):
		return "pas à bord"
	if not unit.is_wounded():
		return "pas assez blessé"
	if is_destroyed or is_disabled:
		return "appareil endommagé"
	var others := get_tree().get_nodes_in_group(&"commandos").filter(func(node: Node) -> bool:
		return node != unit and not (node as Commando).is_dead)
	if others.is_empty():
		return "dernier opérateur"
	return ""


## Évacue `unit`, blessé et à bord : il quitte la mission, sauvé.
func evacuate(unit: Commando) -> bool:
	if evacuation_problem(unit) != "":
		return false
	if gunner == unit:
		leave_gun()
	unit.evacuate()
	return true


# --- Diversion -------------------------------------------------------------------

## Raison pour laquelle on ne peut pas faire diversion (vide : c'est
## possible).
func diversion_problem() -> String:
	if is_destroyed:
		return "appareil détruit"
	if is_disabled:
		return "appareil endommagé"
	if diversion_used:
		return "diversion déjà faite"
	if not is_away:
		return "appareil sur zone"
	return ""


## Appareil parti qui peut faire diversion (ou qui l'a déjà faite), ou null.
static func diverter(tree: SceneTree) -> Tiltrotor:
	for node in tree.get_nodes_in_group(GROUP):
		var aircraft := node as Tiltrotor
		if aircraft and aircraft.is_away and not aircraft.is_destroyed:
			return aircraft
	return null


## Passage en rase-mottes au-dessus de `point`, venu du côté de la zone de
## pose et filant au-delà ; il repart ensuite. Renvoie faux si c'est
## impossible.
func divert(point: Vector3) -> bool:
	if diversion_problem() != "":
		return false
	var across := Vector3(point.x - _landing.x, 0.0, point.z - _landing.z)
	if across.length() < 1.0:
		across = -global_basis.z
	across = across.normalized()
	var height := Vector3.UP * (point.y + DIVERSION_HEIGHT)
	var start := Vector3(point.x, 0.0, point.z) - across * DIVERSION_REACH + height
	var finish := Vector3(point.x, 0.0, point.z) + across * DIVERSION_REACH + height
	diversion_used = true
	is_away = false
	is_diverting = true
	is_moving = true
	visible = true
	_set_solid(true)
	_apply_ramp(true, false)
	model.rotor_speed = FLIGHT_ROTOR_SPEED
	global_position = start
	global_rotation.y = atan2(-across.x, -across.z)
	ground_y = point.y
	_noise_left = 0.0
	_flight = create_tween()
	_flight.tween_property(self, "global_position", finish, DIVERSION_REACH * 2.0 / DIVERSION_SPEED)
	_flight.tween_callback(_end_diversion)
	return true


## Fin du passage : l'appareil repart, de nouveau à appeler.
func _end_diversion() -> void:
	is_diverting = false
	is_moving = false
	model.rotor_speed = 0.0
	global_position = _landing
	global_rotation.y = _landing_yaw
	_go_away()


## Raison pour laquelle on ne peut pas appeler l'appareil (vide : c'est
## possible).
func call_problem() -> String:
	if not extraction:
		return "pas d'extraction prévue"
	if is_destroyed:
		return "appareil détruit"
	if is_inbound:
		return "déjà en route"
	if not is_away:
		return "déjà sur place"
	return ""


## Appareil d'extraction encore à appeler sur cette carte, ou null.
static func awaiting_call(tree: SceneTree) -> Tiltrotor:
	for node in tree.get_nodes_in_group(GROUP):
		var aircraft := node as Tiltrotor
		if aircraft and aircraft.extraction and (aircraft.is_away or aircraft.is_inbound):
			return aircraft
	return null


## Appelle l'appareil : il arrive de l'arrière, rotors lancés, jusqu'au-dessus
## de son point de pose. Renvoie faux si c'est impossible (`call_problem`).
func call_in() -> bool:
	if call_problem() != "":
		return false
	is_away = false
	is_inbound = true
	visible = true
	global_rotation.y = _landing_yaw
	_apply_ramp(true, false)
	model.rotor_speed = FLIGHT_ROTOR_SPEED
	var hover := _landing + Vector3.UP * HOVER_HEIGHT
	global_position = hover + global_basis.z * APPROACH_DISTANCE + Vector3.UP * (APPROACH_HEIGHT - HOVER_HEIGHT)
	_noise_left = 0.0
	_flight = create_tween()
	_flight.tween_property(self, "global_position", hover, APPROACH_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_flight.tween_callback(_over_landing)
	return true


## Au-dessus du point de pose : il attend que la place soit libre, puis
## descend.
func _over_landing() -> void:
	if not is_inbound:
		return
	if pickup_window > 0.0:
		_start_pickup()
		return
	# Il ne se pose pas sur les siens ; les ennemis attirés dessous s'écartent.
	if _someone_below(true):
		get_tree().create_timer(0.5, false).timeout.connect(_over_landing)
		return
	ground_y = _landing.y
	_flight = create_tween()
	_flight.tween_property(self, "global_position:y", ground_y, HOVER_TIME).set_trans(Tween.TRANS_SINE)
	# Posé dès le contact (plus une cible) ; les rotors ralentissent ensuite.
	_flight.tween_callback(_touched_down)
	_flight.tween_property(model, "rotor_speed", 0.0, SPIN_UP * 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Posé : solide, rampe abaissée pour l'embarquement.
func _touched_down() -> void:
	is_inbound = false
	global_position = _landing
	_push_enemies_out()
	_set_solid(true)
	if is_disabled:
		Sfx.play_at(&"fall", global_position + Vector3.UP, 0.0)
		model.rotor_speed = 0.0
		_fail_extraction()
		return
	_apply_ramp(false, true)


## Ennemis sous l'emprise de l'appareil : écartés sur le côté le plus proche.
func _push_enemies_out() -> void:
	var reach := 0.0
	for box in hull_boxes:
		reach = maxf(reach, maxf(absf(box.position.x), absf(box.end.x)))
	for node in get_tree().get_nodes_in_group(Enemy.ALL_GROUP):
		var enemy := node as Enemy
		if enemy == null:
			continue
		var local := to_local(enemy.global_position)
		if distance_to_hull(enemy.global_position * Vector3(1, 0, 1) + Vector3.UP * (global_position.y + 0.5)) > 0.6:
			continue
		local.x = (reach + 0.8) * (1.0 if local.x >= 0.0 else -1.0)
		enemy.global_position = to_global(local)


## Vrai si tout le monde peut partir : opérateurs vivants et VIP à bord,
## autres objectifs remplis.
func _ready_to_leave() -> bool:
	if take_off_problem() != "":
		_told_pending = false
		return false
	for node in get_tree().get_nodes_in_group(&"vips"):
		var vip := node as Vip
		if vip and not vip.is_dead and not vip.is_evacuated and not vips_aboard().has(vip):
			return false
	var objectives := get_tree().get_first_node_in_group(Objectives.GROUP) as Objectives
	if objectives and not objectives.done_except(String(objective_id)):
		if not _told_pending:
			_told_pending = true
			for unit in passengers():
				unit.flash_message("Extraction : objectifs en cours")
		return false
	return true


func _physics_process(delta: float) -> void:
	for unit: Node3D in _passengers:
		if is_instance_valid(unit):
			unit.global_transform = global_transform * (_passengers[unit] as Transform3D)
	_update_gun(delta)
	_update_sling(delta)
	if is_airborne:
		_update_winch()
	_revealed_left = maxf(_revealed_left - delta, 0.0)
	_settle_left = maxf(_settle_left - delta, 0.0)
	_update_strobe(delta)
	if is_diverting and not is_disabled:
		# Passage bruyant : les sentinelles vont voir.
		_noise_left -= delta
		if _noise_left <= 0.0:
			_noise_left = DIVERSION_NOISE_INTERVAL
			EventBus.noise_emitted.emit(Vector3(global_position.x, ground_y, global_position.z), DIVERSION_NOISE, &"distraction")
	elif (is_inbound or is_moving or is_airborne) and not is_destroyed:
		# Bruit des rotors au sol sous l'appareil : les ennemis accourent.
		_noise_left -= delta
		if _noise_left <= 0.0:
			_noise_left = HOVER_NOISE_INTERVAL if is_airborne else APPROACH_NOISE_INTERVAL
			var floor_y := _landing.y if is_inbound else ground_y
			EventBus.noise_emitted.emit(Vector3(global_position.x, floor_y, global_position.z), rotor_noise_radius(), &"help")
	if is_flying or is_away or is_inbound:
		return
	if pickup_left > 0.0:
		# Documents treuillés à bord : l'objectif compte aussi en vol.
		_check_documents()
		_update_pickup(delta)
		return
	_check_left -= delta
	if _check_left > 0.0:
		return
	_check_left = CHECK_INTERVAL
	if extraction and not is_destroyed and not is_airborne and not is_moving:
		if _ready_to_leave():
			_depart_left -= CHECK_INTERVAL
			if _depart_left <= 0.0:
				take_off(null)
				return
		else:
			_depart_left = DEPART_DELAY
	_check_documents()
	var aboard := false
	for node in get_tree().get_nodes_in_group(&"commandos"):
		var unit := node as Commando
		if unit and not unit.is_dead and cabin_contains(unit.global_position + Vector3.UP * 0.3):
			aboard = true
			break
	if aboard != model.is_cut():
		model.set_cutaway(aboard)


## Distance de `point` (monde) à la coque.
func distance_to_hull(point: Vector3) -> float:
	var local := to_local(point)
	var best := INF
	for box in hull_boxes:
		var nearest := local.clamp(box.position, box.end)
		best = minf(best, local.distance_to(nearest))
	return best


## Explosion de rayon `radius` en `at` (`Explosion`) : détruit l'appareil si
## elle est assez près de la coque.
func blast(at: Vector3, radius: float) -> void:
	if is_away or is_inbound:
		return
	if not is_destroyed and distance_to_hull(at) <= radius * BLAST_SHARE:
		destroy()


## Détruit l'appareil : réservoir qui saute, épave en feu, objectif rempli.
func destroy() -> void:
	if is_destroyed or is_flying or is_airborne or is_moving or is_away or is_inbound:
		return
	_set_wrecked()
	# Réservoirs dans les flancs : une explosion de chaque côté, hors de la
	# coque (creuse, elle arrêterait le souffle parti du centre).
	for side: float in [-1.0, 1.0]:
		var tank := to_global(Vector3(side * (TiltrotorModel.CABIN_HALF_WIDTH + 0.6) * SCALE + side * 0.4, 1.2, 0.5 * SCALE))
		Explosion.detonate(get_parent(), tank, FUEL_RADIUS, FUEL_DAMAGE, FUEL_NOISE)
	if extraction:
		# Plus d'appareil pour repartir : la mission est perdue.
		get_tree().create_timer(END_DELAY, false).timeout.connect(func() -> void:
			EventBus.mission_ended.emit(false, "ÉCHEC — appareil d'extraction détruit"))
		return
	EventBus.objective_completed.emit(objective_id)
	if ends_mission:
		get_tree().create_timer(END_DELAY, false).timeout.connect(func() -> void:
			EventBus.mission_ended.emit(true, "RÉUSSITE — appareil détruit"))


## Sauvegarde rapide (`QuickSave`).
func save_state() -> Dictionary:
	return {"destroyed": is_destroyed, "ramp_closed": is_ramp_closed, "airborne": is_airborne, "ground_y": ground_y,
		"position": global_position if not is_moving else Vector3.INF, "yaw": global_rotation.y, "hover_height": hover_height,
		"away": is_away or is_inbound or is_diverting, "diversion_used": diversion_used, "supplies": supplies, "pickup_left": pickup_left, "documents_aboard": _documents_aboard,
		"sling": String(slung_load.get_path()) if slung_load and _sling_dir >= 0 else "",
		"sling_hang": _sling_hang, "structure": structure, "disabled": is_disabled, "insertion": insertion}


func load_state(data: Dictionary) -> void:
	# Extraction : en approche, l'appareil est rendu « pas encore appelé ».
	var away: bool = data.get("away", false)
	if away != (is_away or is_inbound or is_diverting):
		if _flight:
			_flight.kill()
		is_inbound = false
		if is_diverting:
			is_diverting = false
			is_moving = false
			global_position = _landing
			global_rotation.y = _landing_yaw
		if away:
			_go_away()
		else:
			is_away = false
			visible = true
			global_position = _landing
			model.rotor_speed = 0.0
			_set_solid(true)
	var saved_position: Vector3 = data.get("position", Vector3.INF)
	if saved_position != Vector3.INF and not (is_away or is_inbound):
		if _flight and not is_inbound:
			_flight.kill()
			is_moving = false
		global_position = saved_position
		global_rotation.y = data.get("yaw", global_rotation.y)
	hover_height = data.get("hover_height", HOVER_HEIGHT)
	insertion = data.get("insertion", insertion)
	diversion_used = data.get("diversion_used", diversion_used)
	supplies = data.get("supplies", supplies)
	pickup_left = data.get("pickup_left", 0.0) if data.get("airborne", false) else 0.0
	_documents_aboard = data.get("documents_aboard", _documents_aboard)
	_release_load()
	var sling_path := String(data.get("sling", ""))
	if sling_path != "":
		_resling.call_deferred(NodePath(sling_path), data.get("sling_hang", _sling_hang))
	if data.get("destroyed", false) and not is_destroyed:
		_set_wrecked()
	structure = data.get("structure", STRUCTURE)
	is_disabled = data.get("disabled", false)
	if structure < STRUCTURE:
		_show_damage()
	var closed: bool = data.get("ramp_closed", false)
	if closed != is_ramp_closed:
		_apply_ramp(closed, false)
	var airborne: bool = data.get("airborne", false)
	if airborne != is_airborne and not is_moving:
		ground_y = data.get("ground_y", ground_y if is_airborne else global_position.y)
		if saved_position == Vector3.INF:
			global_position.y = ground_y + (hover_height if airborne else 0.0)
		is_airborne = airborne
		model.rotor_speed = FLIGHT_ROTOR_SPEED if airborne else rotor_speed
		if _rope and not airborne:
			_rope.queue_free()
			_rope = null
		EventBus.navigation_obstacle_moved.emit()
	# Équipage : les opérateurs restaurés dans la soute (après eux).
	_assign_crew.call_deferred()


func _assign_crew() -> void:
	for node in get_tree().get_nodes_in_group(&"commandos"):
		var unit := node as Commando
		if unit:
			var aboard := is_airborne and not unit.is_dead and cabin_contains(unit.global_position + Vector3.UP * 0.3)
			if aboard:
				unit.airborne_in = self
			elif unit.airborne_in == self:
				unit.airborne_in = null


func _set_wrecked() -> void:
	is_destroyed = true
	model.set_wrecked()
	_fire = _make_fire()
	add_child(_fire)


## Flammes et colonne de fumée sur l'épave.
func _make_fire() -> Node3D:
	var fire := Node3D.new()
	fire.name = "Fire"
	fire.position = Vector3(0.0, 3.0, 0.5)
	var flames := CPUParticles3D.new()
	flames.name = "Flames"
	flames.amount = 48
	flames.lifetime = 0.9
	flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	flames.emission_box_extents = Vector3(1.2, 0.3, 3.5)
	flames.direction = Vector3.UP
	flames.spread = 15.0
	flames.gravity = Vector3(0, 2.5, 0)
	flames.initial_velocity_min = 1.0
	flames.initial_velocity_max = 2.5
	flames.scale_amount_min = 0.6
	flames.scale_amount_max = 1.2
	var flame_mesh := SphereMesh.new()
	flame_mesh.radius = 0.35
	flame_mesh.height = 0.7
	flame_mesh.radial_segments = 8
	flame_mesh.rings = 4
	var flame_material := StandardMaterial3D.new()
	flame_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame_material.vertex_color_use_as_albedo = true
	flame_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flame_mesh.material = flame_material
	flames.mesh = flame_mesh
	var flame_colors := Gradient.new()
	flame_colors.set_color(0, Color(1.0, 0.55, 0.12, 0.95))
	flame_colors.set_color(1, Color(0.9, 0.2, 0.05, 0.0))
	flames.color_ramp = flame_colors
	fire.add_child(flames)
	var smoke := CPUParticles3D.new()
	smoke.name = "Smoke"
	smoke.amount = 40
	smoke.lifetime = 5.0
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	smoke.emission_sphere_radius = 1.2
	smoke.direction = Vector3.UP
	smoke.spread = 12.0
	smoke.gravity = Vector3(0.4, 1.2, 0)
	smoke.initial_velocity_min = 0.8
	smoke.initial_velocity_max = 1.6
	smoke.scale_amount_min = 1.0
	smoke.scale_amount_max = 2.2
	smoke.position.y = 1.0
	var smoke_mesh := SphereMesh.new()
	smoke_mesh.radius = 0.6
	smoke_mesh.height = 1.2
	smoke_mesh.radial_segments = 8
	smoke_mesh.rings = 4
	var smoke_material := flame_material.duplicate() as StandardMaterial3D
	smoke_mesh.material = smoke_material
	smoke.mesh = smoke_mesh
	var smoke_colors := Gradient.new()
	smoke_colors.set_color(0, Color(0.12, 0.11, 0.1, 0.7))
	smoke_colors.set_color(1, Color(0.3, 0.3, 0.3, 0.0))
	smoke.color_ramp = smoke_colors
	fire.add_child(smoke)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.2)
	light.light_energy = 3.0
	light.omni_range = 9.0
	fire.add_child(light)
	return fire
