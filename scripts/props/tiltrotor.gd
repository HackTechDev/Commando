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
## (`rappel`) le long d'une corde jusqu'au sol.
##
## Extraction (`extraction`) : l'appareil n'est pas là au début de la
## mission. Un opérateur l'appelle (`call_in`) : il arrive en vol, bruyant
## (les ennemis accourent), attend au-dessus de son point de pose que la place
## soit libre, se pose et abaisse la rampe. Il repart seul quand tous les
## opérateurs vivants (et les VIP) sont à bord et que les autres objectifs
## sont remplis : l'objectif `objective_id` est rempli, la mission réussie.
##
## Riposte : en l'air (`is_in_air`), l'appareil est une cible pour les
## ennemis armés qui le voient (`Enemy`). Chaque balle lui ôte une part de
## ses dégâts (`BULLET_SHARE`) sur `STRUCTURE` points ; sous la moitié, il
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
const RAPPEL_SPEED := 2.5
## Extraction : arrivée depuis l'arrière (distance, hauteur au départ, s),
## intervalle du bruit des rotors pendant l'approche, attente (s) avant de
## repartir une fois tout le monde à bord.
const APPROACH_DISTANCE := 70.0
const APPROACH_HEIGHT := 30.0
const APPROACH_TIME := 14.0
const APPROACH_NOISE_INTERVAL := 1.5
const DEPART_DELAY := 1.5
## Riposte : points de structure, part des dégâts d'une balle encaissée, part
## de la structure sous laquelle il fume, durée de la descente d'urgence (s).
const STRUCTURE := 400.0
const BULLET_SHARE := 0.25
const SMOKE_SHARE := 0.5
const EMERGENCY_TIME := 2.5
## Canon latéral : portée, dégâts, rafale (coups, intervalle, pause en s),
## écart (m par m de distance), bruit, vitesse de visée (rad/s), recherche
## de cible (s), tolérance de visée (rad), couches touchées (murs, caisses,
## ennemis debout ou au sol).
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
const MASK_GUN := 0b11011
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
var _rope: MeshInstance3D
var _rappelling: int = 0
var _ramp_shape: CollisionShape3D
## Passagers pendant le vol : unité (opérateur ou VIP) -> position dans le
## repère de l'appareil.
var _passengers: Dictionary = {}
## Extraction : pas encore appelé (caché, sans collision), en approche.
var is_away: bool = false
var is_inbound: bool = false
## Point de pose (position de l'appareil dans la scène).
var _landing: Vector3
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
var _gun_target: Enemy
var _gun_search_left: float = 0.0
var _gun_rounds_left: int = 0
var _gun_cooldown: float = 0.0


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
	blacked_out = LevelRoot.is_night(self)
	model.set_lights(not blacked_out)
	if extraction:
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
	var z := lerpf(TiltrotorModel.CABIN_FRONT + 1.0, TiltrotorModel.CABIN_BACK - 0.8, fposmod(index * 0.3, 1.0))
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
		_passengers[unit] = to_local(unit.global_position)
	for vip in vips_aboard():
		_passengers[vip] = to_local(vip.global_position)
	if pilot:
		pilot.stop()
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
	_move_to_height(ground_y + HOVER_HEIGHT, true)
	return true


## Raison pour laquelle on ne peut pas atterrir (vide : c'est possible).
func land_problem() -> String:
	if not is_airborne or is_moving:
		return "pas en vol"
	if _rappelling > 0:
		return "rappel en cours"
	if _someone_below():
		return "quelqu'un sous l'appareil"
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
	EventBus.noise_emitted.emit(global_position, ROTOR_NOISE, &"help")
	_flight = create_tween()
	if up:
		_flight.tween_property(model, "rotor_speed", FLIGHT_ROTOR_SPEED, SPIN_UP * 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_flight.tween_property(self, "global_position:y", height, HOVER_TIME).set_trans(Tween.TRANS_SINE)
	if not up:
		_flight.tween_property(model, "rotor_speed", 0.0, SPIN_UP * 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_flight.tween_callback(_arrived.bind(up))


func _arrived(up: bool) -> void:
	is_moving = false
	is_airborne = up
	for unit: CharacterBody3D in _passengers:
		if is_instance_valid(unit):
			unit.process_mode = Node.PROCESS_MODE_INHERIT
			unit.velocity = Vector3.ZERO
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
		_passengers[unit] = to_local(unit.global_position)


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
	var foot := Vector3(tip.x, ground_y, tip.z)
	_show_rope(tip, foot)
	unit.stop()
	unit.airborne_in = null
	unit.process_mode = Node.PROCESS_MODE_DISABLED
	_rappelling += 1
	var start := unit.global_position
	var descent := create_tween()
	descent.tween_property(unit, "global_position", tip + Vector3.UP * 0.1, clampf(start.distance_to(tip) / 3.5, 0.4, 2.0))
	descent.tween_property(unit, "global_position", foot, (tip.y - foot.y) / RAPPEL_SPEED).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	descent.tween_callback(func() -> void:
		_rappelling -= 1
		unit.process_mode = Node.PROCESS_MODE_INHERIT
		unit.velocity = Vector3.ZERO
		if rappel_objective != &"":
			EventBus.objective_completed.emit(rappel_objective))
	return true


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
	for unit: CharacterBody3D in _passengers:
		if is_instance_valid(unit):
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
	_gun_target = null
	_gun_search_left = 0.0
	unit.stop()
	unit.flash_message("Canon latéral : feu à volonté")
	return true


## Le servant lâche le canon.
func leave_gun() -> void:
	gunner = null
	_gun_target = null
	_gun_rounds_left = 0


func _is_aboard(unit: Commando) -> bool:
	return unit.airborne_in == self or cabin_contains(unit.global_position + Vector3.UP * 0.3)


func _gunner_ok() -> bool:
	return is_instance_valid(gunner) and not gunner.is_dead and _is_aboard(gunner)


## Bouche du canon (monde).
func gun_muzzle() -> Vector3:
	return model.door_gun.to_global(GUN_MUZZLE)


## Vrai si `point` est dans le champ du canon : côté droit, vers l'avant ou
## le travers, à portée.
func gun_covers(point: Vector3) -> bool:
	var pivot := model.door_gun.global_position
	if pivot.distance_to(point) > GUN_RANGE:
		return false
	var local := (global_basis.inverse() * (point - pivot)).normalized()
	return local.x > 0.2 and local.z < 0.35


## Vrai si le canon peut tirer sur `enemy` : en vue, ou seulement derrière
## une caisse ou un mur fragile que ses balles rongent.
func _gun_can_reach(enemy: Enemy) -> bool:
	var aim := enemy.global_position + Vector3.UP * 1.0
	if not gun_covers(aim):
		return false
	var query := PhysicsRayQueryParameters3D.create(gun_muzzle(), aim, MASK_GUN, body_rids())
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	var collider := hit["collider"] as Node
	return collider == enemy or (collider != null and collider.has_method(&"take_shot"))


func _update_gun(delta: float) -> void:
	if gunner and not _gunner_ok():
		leave_gun()
	if gunner == null or is_destroyed or is_flying or is_away or is_inbound:
		return
	_gun_cooldown -= delta
	_gun_search_left -= delta
	if _gun_target and (not is_instance_valid(_gun_target) or _gun_target.is_dead or _gun_target.state == Enemy.State.STUNNED):
		_gun_target = null
	if _gun_search_left <= 0.0:
		_gun_search_left = GUN_SEARCH_INTERVAL
		if _gun_target == null or not _gun_can_reach(_gun_target):
			_gun_target = _find_gun_target()
	if _gun_target == null:
		_gun_rounds_left = 0
		return
	# Le canon pivote vers la cible.
	var pivot := model.door_gun
	var aim := _gun_target.global_position + Vector3.UP * 1.0
	var wanted := model.global_basis.inverse() * (aim - pivot.global_position)
	if wanted.length_squared() < 0.01:
		return
	var goal := Quaternion(Basis.looking_at(wanted.normalized(), Vector3.UP))
	pivot.quaternion = pivot.quaternion.slerp(goal, minf(1.0, delta * GUN_TURN_SPEED * 2.0))
	var barrel := -(pivot.global_basis.z.normalized())
	if barrel.angle_to((aim - pivot.global_position).normalized()) > GUN_AIM_TOLERANCE or _gun_cooldown > 0.0:
		return
	if _gun_rounds_left <= 0:
		_gun_rounds_left = GUN_BURST
		EventBus.noise_emitted.emit(global_position, GUN_NOISE, &"gunshot")
	# Les éclairs du canon trahissent l'appareil, même tous feux éteints.
	_revealed_left = MUZZLE_REVEAL
	_gun_rounds_left -= 1
	_gun_cooldown = GUN_ROUND_INTERVAL if _gun_rounds_left > 0 else GUN_BURST_PAUSE
	_fire_gun_round(aim)


## Stroboscope infrarouge : éclairs réguliers, vol de nuit, appareil visible,
## pas détruit, et seulement à travers les jumelles de vision nocturne.
func _update_strobe(delta: float) -> void:
	var lit := blacked_out and visible and not is_destroyed and NightVision.viewing
	if lit:
		_strobe_time = fmod(_strobe_time + delta, STROBE_PERIOD)
	model.ir_strobe.visible = lit and _strobe_time < STROBE_FLASH


## Ennemi debout le plus proche que le canon peut atteindre, ou null.
func _find_gun_target() -> Enemy:
	var best: Enemy = null
	var best_distance := INF
	var pivot := model.door_gun.global_position
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead or enemy.state == Enemy.State.STUNNED:
			continue
		var distance := pivot.distance_to(enemy.global_position)
		if distance < best_distance and _gun_can_reach(enemy):
			best = enemy
			best_distance = distance
	return best


## Un coup vers `aim`, avec un écart qui croît avec la distance : la balle
## blesse le premier ennemi touché, ou abîme le premier objet destructible.
func _fire_gun_round(aim: Vector3) -> void:
	var muzzle := gun_muzzle()
	var spread := GUN_SPREAD * muzzle.distance_to(aim)
	aim += Vector3(randf_range(-spread, spread), randf_range(-spread, spread) * 0.6, randf_range(-spread, spread))
	var direction := (aim - muzzle).normalized()
	var query := PhysicsRayQueryParameters3D.create(muzzle, aim + direction * ShotImpact.MISS_RANGE, MASK_GUN, body_rids())
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var scene := get_tree().current_scene as Node3D
	if scene == null:
		scene = get_parent() as Node3D
	var end := aim + direction * 4.0
	if not hit.is_empty():
		end = hit["position"]
		var target := hit["collider"] as Node
		if target is Enemy and not (target as Enemy).is_dead:
			ShotImpact.hit(scene, target as Node3D, end, muzzle, GUN_DAMAGE, false)
			(target as Enemy).take_hit(GUN_DAMAGE, muzzle)
		else:
			ShotImpact.burst(scene, end, hit["normal"], ShotImpact.DUST, 10, 2.2)
			if target and target.has_method(&"take_shot"):
				target.call(&"take_shot", GUN_DAMAGE, end, muzzle)
	Tracer.spawn(scene, muzzle, end, Color(1.0, 0.75, 0.35))
	Sfx.play_at(&"shot", muzzle, 2.0)


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
			unit.global_position = to_global(_passengers[unit])
	_update_gun(delta)
	_revealed_left = maxf(_revealed_left - delta, 0.0)
	_update_strobe(delta)
	if is_inbound:
		# Bruit des rotors au sol sous l'appareil : les ennemis accourent.
		_noise_left -= delta
		if _noise_left <= 0.0:
			_noise_left = APPROACH_NOISE_INTERVAL
			EventBus.noise_emitted.emit(Vector3(global_position.x, _landing.y, global_position.z), ROTOR_NOISE, &"help")
	if is_flying or is_away or is_inbound:
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
		"away": is_away or is_inbound, "structure": structure, "disabled": is_disabled}


func load_state(data: Dictionary) -> void:
	# Extraction : en approche, l'appareil est rendu « pas encore appelé ».
	var away: bool = data.get("away", false)
	if away != (is_away or is_inbound) and extraction:
		if _flight:
			_flight.kill()
		is_inbound = false
		if away:
			_go_away()
		else:
			is_away = false
			visible = true
			global_position = _landing
			model.rotor_speed = 0.0
			_set_solid(true)
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
		global_position.y = ground_y + (HOVER_HEIGHT if airborne else 0.0)
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
