class_name Sabre
extends StaticBody3D
## Véhicule léger des forces spéciales (`SabreModel`), cinq places.
##
## Embarquement : clic droit sur le véhicule ; chaque opérateur sélectionné
## le rejoint (`request_board`) et prend la première place libre : volant,
## chef de bord, arrière gauche, arrière droit, puis tourelle. À bord
## (`Commando.riding`), un opérateur ne marche plus ; à l'arrêt, il tire
## depuis sa place.
##
## Conduite (`drive_to`) : avec quelqu'un au volant, le véhicule suit le
## chemin de navigation jusqu'au point visé, à `SPEED`, plus lentement dans
## les virages ; il s'arrête devant une unité (et renonce au bout de
## `BLOCK_GIVE_UP` s). Le moteur s'entend (`ENGINE_NOISE`). Pendant le
## trajet, les passagers sont emportés (physique suspendue).
##
## 7,62 latérales : le chef de bord (avant droit) et l'arrière gauche
## servent chacun une mitrailleuse (`set_side_firing`), au champ de tir
## limité (avant et droite, arrière et gauche), moins puissante, moins
## bruyante et de moindre portée que la 12,7.
##
## Tourelle : l'opérateur à la place du tireur ouvre le feu à volonté
## (`set_gun_firing`) avec la mitrailleuse de 12,7 (`MountedGun`, tout
## autour du véhicule).
##
## Transport aérien (`load_into`) : clic droit sur un convertible posé,
## rampe abaissée, avec un passager sélectionné. Le Sabre roule jusque
## derrière la rampe, replie arceau et antennes, monte dans la soute et s'y
## gare à l'avant (`stowed_in`). Le convertible l'emporte avec son équipage
## (vol stationnaire, décollage). Pour ressortir : clic droit au sol, appareil
## posé et rampe abaissée ; le Sabre redescend la rampe en marche arrière,
## puis file vers sa destination.
##
## Conduite de nuit (`headlights`) : tous feux éteints, le Sabre roule
## moins vite (`NIGHT_DARK_SHARE`) et les sentinelles ne repèrent son
## équipage que de près (zone proche de leur cône). Phares allumés, il roule
## à pleine vitesse, mais on le voit de loin (`HEADLIGHT_SIGHT`), et ses
## phares éclairent la route.
##
## Dégâts (`take_shot`, `blast`) : une jauge de structure (`STRUCTURE`).
## Une balle près d'une roue peut crever un pneu (vitesse réduite) ; dans le
## capot, elle abîme le moteur, qui fume, puis lâche (immobilisé). À zéro,
## le véhicule est une épave. Un opérateur à pied le répare (`request_repair`)
## en restant quelques secondes à l'avant : pneus et moteur, pas la caisse.
## Les balles tirées sur un passager touchent souvent la carrosserie.
##
## Couvert (`cover_points`) : à l'arrêt, des opérateurs à pied s'abritent
## accroupis derrière la caisse, du côté opposé aux ennemis. Les balles qui
## les visent à travers le véhicule frappent la carrosserie (`blocks_shot`).
##
## Leurre (`set_idling`) : à l'arrêt, le moteur tourne au ralenti, même
## sans personne à bord ; son bruit attire les gardes (bruit `distraction`)
## pendant que l'équipe contourne à pied.
##
## Moteur coupé (`coasting`) : le conducteur avance en roue libre, à
## `COAST_SPEED`, sans aucun bruit, sur `COAST_RANGE` m au plus en tout,
## jusqu'à ce qu'on relance le moteur.
##
## Repère : celui du modèle (avant vers -Z, posé au sol).

const GROUP := &"sabres"
const LAYER_OCCLUDERS := 0b10
## Vitesse en ligne droite (m/s), braquage (rad/s), vitesse minimale dans
## un virage serré (part de `SPEED`), distance à laquelle un point du chemin
## est atteint.
const SPEED := 8.0
const TURN_RATE := 1.8
const SLOW_SHARE := 0.2
const WAYPOINT_REACH := 1.4
## Nuit : vitesse tous feux éteints (part de `SPEED`), distance à laquelle
## les phares allumés font repérer le véhicule (m), portée des phares (m).
const NIGHT_DARK_SHARE := 0.55
const HEADLIGHT_SIGHT := 45.0
const HEADLIGHT_RANGE := 28.0
## Dégâts : structure, part de la vitesse pneu crevé, chance qu'une balle
## près d'une roue crève le pneu, dégâts qui mettent le moteur hors d'usage,
## seuil de fumée (part du moteur), part des balles tirées sur un passager
## qui touchent la carrosserie, durée de réparation (s), distance du
## réparateur au point de réparation (m).
const STRUCTURE := 400.0
const FLAT_SHARE := 0.5
const TIRE_CHANCE := 0.35
const ENGINE_TOUGHNESS := 180.0
const ENGINE_SMOKE := 0.5
const RIDER_COVER := 0.5
const REPAIR_TIME := 6.0
const REPAIR_REACH := 1.4
## Leurre : intervalle du bruit au ralenti (s), distance (m) à laquelle un
## opérateur à pied peut lancer ou couper le moteur.
const IDLE_INTERVAL := 1.5
const IDLE_REACH := 3.5
## Moteur coupé : vitesse en roue libre (m/s) et distance au plus par trajet
## (m).
const COAST_SPEED := 2.0
const COAST_RANGE := 15.0
## Bruit du moteur en marche (rayon, intervalle en s).
const ENGINE_NOISE := 24.0
const NOISE_INTERVAL := 1.0
## Zone devant le véhicule où une unité l'arrête (profondeur, demi-largeur),
## et attente avant de renoncer (s).
const BLOCK_DEPTH := 3.0
const BLOCK_HALF_WIDTH := 1.4
const BLOCK_GIVE_UP := 3.0
## Distance (m) à la portière à laquelle un opérateur qui le rejoint monte.
const BOARD_REACH := 1.3
## Ordre dans lequel les places sont prises (indices de `SabreModel.SEATS`).
const SEAT_ORDER: Array[int] = [0, 2, 3, 4, 1]
const DRIVER_SEAT := 0
const GUNNER_SEAT := 1
## Mitrailleuse de 12,7 : réglages de `MountedGun`.
const GUN_RANGE := 45.0
const GUN_DAMAGE := 60.0
const GUN_BURST := 5
const GUN_ROUND_INTERVAL := 0.12
const GUN_BURST_PAUSE := 1.0
const GUN_SPREAD := 0.03
const GUN_NOISE := 55.0
## Mitrailleuses de 7,62 : place qui sert chacune (`SabreModel.SIDE_GUNS`),
## réglages.
const SIDE_GUN_SEATS: Array[int] = [2, 3]
const SIDE_RANGE := 32.0
const SIDE_DAMAGE := 35.0
const SIDE_BURST := 4
const SIDE_ROUND_INTERVAL := 0.1
const SIDE_BURST_PAUSE := 1.1
const SIDE_SPREAD := 0.04
const SIDE_NOISE := 40.0
## Manœuvres sur la rampe du convertible : vitesse (m/s), écart entre les
## essieux (m), place dans la soute (centre du véhicule, z local de l'appareil,
## nez contre la cloison), point de départ au pied de la rampe (recul depuis
## le bout de la rampe) et alignement.
const RAMP_SPEED := 2.2
const WHEELBASE := 3.1
const STOW_Z := TiltrotorModel.CABIN_FRONT * Tiltrotor.SCALE + 2.85
const RAMP_CLEARANCE := 3.6
const ALIGN_TIME := 1.0
## Arrivée : rayon de la zone autour de `arrival_point`.
const ARRIVAL_RADIUS := 5.0

@export var livery: SabreModel.Livery = SabreModel.Livery.SAND
## Objectif rempli quand le véhicule s'arrête près de `arrival_point`
## (monde) avec quelqu'un au volant (vide : aucun).
@export var arrival_objective: StringName = &""
@export var arrival_point: Vector3 = Vector3.ZERO
## Convertible dans la soute duquel le véhicule commence la mission (vide :
## au sol, à sa place).
@export var start_stowed_in: NodePath

var model: SabreModel
## Occupant de chaque place (null : libre), dans l'ordre de `SabreModel.SEATS`.
var seats: Array[Commando] = [null, null, null, null, null]
var is_driving: bool = false
## La 12,7 tire à volonté (si quelqu'un est à la tourelle).
var gun_firing: bool = false
var _gun: MountedGun
## 7,62 : armes et feu à volonté (dans l'ordre de `SIDE_GUN_SEATS`).
var _side_guns: Array[MountedGun] = []
var side_firing: Array[bool] = [false, false]
var _path := PackedVector3Array()
var _path_index: int = 0
var _blocked_left: float = 0.0
var _noise_left: float = 0.0
var _steer: float = 0.0
## Opérateurs en route pour monter : unité -> vrai.
var _boarders: Dictionary = {}
var _arrived_once: bool = false
## Convertible dans la soute duquel le véhicule est garé (null : au sol).
var stowed_in: Tiltrotor
## Convertible qui le porte sous ses crochets (élingage), ou null.
var slung_by: Tiltrotor
## Suite d'un trajet (montée dans la soute) et manœuvre sur la rampe en cours.
var _then: Callable
var _ramp_tween: Tween
## Moteur coupé : roue libre, silencieuse ; distance qui reste (m).
var coasting: bool = false
## Moteur au ralenti à l'arrêt (leurre).
var idling: bool = false
var _idle_left: float = 0.0
## Phares allumés (de nuit) ; carte de nuit.
var headlights: bool = false
## Dégâts : structure restante, pneu crevé, usure du moteur (1 : hors
## d'usage), épave ; réparateur et temps restant.
var structure: float = STRUCTURE
var tire_flat: bool = false
var engine_damage: float = 0.0
var is_wrecked: bool = false
var _repairer: Commando
var _repair_left: float = 0.0
var _gauge: Label3D
var _smoke: CPUParticles3D
var _night: bool = false
var _lamps: Array[Node3D] = []
var _coast_left: float = 0.0


func _enter_tree() -> void:
	add_to_group(GROUP)
	add_to_group(Explosion.VEHICLES_GROUP)
	add_to_group(QuickSave.GROUP)


func _ready() -> void:
	collision_layer = LAYER_OCCLUDERS
	collision_mask = 0
	model = SabreModel.new()
	model.name = "Model"
	model.livery = livery
	add_child(model)
	var floor_y := SabreModel.FLOOR
	var half := SabreModel.HALF_WIDTH
	# Capot, bas de caisse et plancher, portières et ridelles, hayon, roues.
	_add_box(AABB(Vector3(-1.08, 0.45, -2.6), Vector3(2.16, 0.97, 2.6 + SabreModel.CREW_FRONT)))
	_add_box(AABB(Vector3(-half - 0.05, 0.35, SabreModel.CREW_FRONT), Vector3((half + 0.05) * 2.0, floor_y - 0.35, 2.45 - SabreModel.CREW_FRONT)))
	for side: float in [-1.0, 1.0]:
		var inner := half - 0.04 if side > 0.0 else -half - 0.04
		_add_box(AABB(Vector3(inner, floor_y, SabreModel.CREW_FRONT), Vector3(0.08, 0.42, 2.45 - SabreModel.CREW_FRONT)))
	_add_box(AABB(Vector3(-half, floor_y, 2.41), Vector3(half * 2.0, 0.35, 0.1)))
	for wheel in SabreModel.WHEELS:
		var r := SabreModel.WHEEL_RADIUS
		_add_box(AABB(Vector3(wheel.x - 0.2, 0.0, wheel.y - r), Vector3(0.4, r * 2.0, r * 2.0)))
	_gun = MountedGun.new(self, model.gun_pivot, SabreModel.GUN_MUZZLE)
	_gun.reach = GUN_RANGE
	_gun.damage = GUN_DAMAGE
	_gun.burst = GUN_BURST
	_gun.round_interval = GUN_ROUND_INTERVAL
	_gun.burst_pause = GUN_BURST_PAUSE
	_gun.spread = GUN_SPREAD
	_gun.noise = GUN_NOISE
	_gun.excluded = body_rids
	for index in SIDE_GUN_SEATS.size():
		var side := MountedGun.new(self, model.side_gun_pivots[index], SabreModel.SIDE_MUZZLE)
		side.reach = SIDE_RANGE
		side.damage = SIDE_DAMAGE
		side.burst = SIDE_BURST
		side.round_interval = SIDE_ROUND_INTERVAL
		side.burst_pause = SIDE_BURST_PAUSE
		side.spread = SIDE_SPREAD
		side.noise = SIDE_NOISE
		side.excluded = body_rids
		side.covers = _side_covers.bind(index)
		_side_guns.append(side)
	_night = LevelRoot.is_night(self)
	_build_headlights()
	if not start_stowed_in.is_empty():
		_stow_at_start.call_deferred()


## Phares : deux projecteurs et leurs verres allumés (cachés phares éteints).
func _build_headlights() -> void:
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(1.0, 0.97, 0.85)
	for side: float in [-1.0, 1.0]:
		var lamp := Node3D.new()
		lamp.name = "Headlight"
		lamp.position = Vector3(side * 0.72, 1.0, -2.49)
		add_child(lamp)
		var lens := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.21, 0.13, 0.02)
		lens.mesh = box
		lens.material_override = glow
		lamp.add_child(lens)
		var beam := SpotLight3D.new()
		beam.light_color = Color(1.0, 0.95, 0.82)
		beam.light_energy = 5.0
		beam.spot_range = HEADLIGHT_RANGE
		beam.spot_angle = 24.0
		beam.rotation.x = -0.08
		beam.shadow_enabled = true
		lamp.add_child(beam)
		lamp.visible = false
		_lamps.append(lamp)


## Allume ou éteint les phares.
func set_headlights(on: bool, announce: bool = true) -> bool:
	headlights = on
	for lamp in _lamps:
		lamp.visible = on
	if announce and driver():
		driver().flash_message("Phares allumés : repérables de loin" if on else "Phares éteints")
	return true


## Zone de vue dans laquelle une sentinelle (`vision`) voit un passager, en
## tenant compte de la nuit : tous feux éteints, seulement de près ; phares
## allumés, aussi de loin (`HEADLIGHT_SIGHT`), quelle que soit la posture.
func sight_zone(zone: VisionComponent.Zone, vision: VisionComponent) -> VisionComponent.Zone:
	if not _night:
		return zone
	if not headlights:
		return zone if zone == VisionComponent.Zone.NEAR else VisionComponent.Zone.NONE
	if zone != VisionComponent.Zone.NONE:
		return zone
	var center := global_position + Vector3.UP * 1.2
	var local := vision.to_local(center)
	var flat := Vector2(local.x, local.z)
	if flat.length() > HEADLIGHT_SIGHT or absf(atan2(flat.x, -flat.y)) > deg_to_rad(vision.config.fov_degrees) * 0.5:
		return VisionComponent.Zone.NONE
	var eye := vision.global_position + Vector3.UP * vision.config.eye_height
	var query := PhysicsRayQueryParameters3D.create(eye, center, LAYER_OCCLUDERS, body_rids())
	if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
		return VisionComponent.Zone.NONE
	return VisionComponent.Zone.FAR


## Début de mission dans une soute : garé à l'avant, arceau replié.
func _stow_at_start() -> void:
	var aircraft := get_node_or_null(start_stowed_in) as Tiltrotor
	if aircraft == null or aircraft.cargo != null:
		return
	stowed_in = aircraft
	aircraft.cargo = self
	model.fold(true)
	global_transform = _hold_transform(aircraft, STOW_Z)
	EventBus.navigation_obstacle_moved.emit()


func _add_box(box: AABB) -> void:
	var shape := CollisionShape3D.new()
	var cube := BoxShape3D.new()
	cube.size = box.size
	shape.shape = cube
	shape.position = box.get_center()
	add_child(shape)


## Corps du véhicule, que les tirs depuis ses places ignorent.
func body_rids() -> Array[RID]:
	return [get_rid()]


# --- Places ---------------------------------------------------------------------

## Place de `unit` (-1 : pas à bord).
func seat_of(unit: Commando) -> int:
	return seats.find(unit)


func driver() -> Commando:
	return seats[DRIVER_SEAT]


func gunner() -> Commando:
	return seats[GUNNER_SEAT]


## Opérateurs à bord.
func crew() -> Array[Commando]:
	var aboard: Array[Commando] = []
	for unit in seats:
		if unit:
			aboard.append(unit)
	return aboard


func _free_seat() -> int:
	for index in SEAT_ORDER:
		if seats[index] == null:
			return index
	return -1


## Point de montée le plus proche de `from`, au sol, à côté d'une portière.
func boarding_point(from: Vector3) -> Vector3:
	# Dans la soute : on monte par l'arrière, seul passage libre.
	if stowed_in:
		return _on_navmesh(to_global(Vector3(0, 0, 3.4)))
	var best := Vector3.INF
	for side: float in [-1.0, 1.0]:
		var point := to_global(Vector3(side * (SabreModel.HALF_WIDTH + 0.9), 0.0, 0.1))
		if best == Vector3.INF or from.distance_squared_to(point) < from.distance_squared_to(best):
			best = point
	return _on_navmesh(best)


func _on_navmesh(point: Vector3) -> Vector3:
	var map := get_world_3d().navigation_map
	return NavigationServer3D.map_get_closest_point(map, point)


## Départ du chemin de conduite : un point du sol autour du véhicule (devant
## de préférence). Le dessus du véhicule, cuit dans le maillage de
## navigation, ne compte pas. Vector3.INF si aucun.
func _ground_start(toward: Vector3) -> Vector3:
	var candidates: Array[Vector3] = []
	for local: Vector3 in [Vector3(0, 0, -3.4), Vector3(-2.3, 0, -1.0), Vector3(2.3, 0, -1.0), Vector3(0, 0, 3.4)]:
		var point := _on_navmesh(to_global(local))
		if absf(point.y - global_position.y) < 0.6 and point.distance_to(to_global(local)) < 1.5:
			candidates.append(point)
	if candidates.is_empty():
		return Vector3.INF
	# Le plus proche de la destination : on ne repart pas à contresens.
	candidates.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.distance_squared_to(toward) < b.distance_squared_to(toward))
	return candidates[0]


## Envoie `unit` monter à bord. Renvoie faux si c'est impossible (déjà à
## bord, plus de place, véhicule en route).
func request_board(unit: Commando, run: bool) -> bool:
	if unit == null or unit.is_dead or unit.riding != null or is_driving or slung_by:
		return false
	if _free_seat() < 0 or _boarders.size() >= seats.count(null):
		return false
	_boarders[unit] = true
	unit.move_to(boarding_point(unit.global_position), run)
	return true


## Fait monter `unit` à la première place libre (ou à `index`).
func seat(unit: Commando, index: int = -1) -> bool:
	if index < 0:
		index = _free_seat()
	if index < 0 or seats[index] != null or unit.riding != null:
		return false
	_boarders.erase(unit)
	unit.stop()
	seats[index] = unit
	unit.riding = self
	_place(unit, index)
	Sfx.play_at(&"clink", unit.global_position + Vector3.UP, -6.0)
	return true


## Met `unit` à sa place : debout à la tourelle, assis ailleurs.
func _place(unit: Commando, index: int) -> void:
	unit.velocity = Vector3.ZERO
	unit.global_position = to_global(SabreModel.SEATS[index] + Vector3.UP * 0.02)
	unit.global_rotation = Vector3(0.0, global_rotation.y, 0.0)
	# Arceau replié (transport aérien) : le tireur s'assoit aussi.
	var standing := index == GUNNER_SEAT and not model.is_folded
	unit.posture = SoldierModel.Posture.STANDING if standing else SoldierModel.Posture.CROUCHED


## Fait descendre `unit` à côté de sa place. Renvoie faux en route.
func dismount(unit: Commando) -> bool:
	var index := seat_of(unit)
	if index < 0 or is_driving:
		return false
	seats[index] = null
	if index == GUNNER_SEAT:
		set_gun_firing(false)
	unit.riding = null
	var local := SabreModel.SEATS[index]
	var side := -1.0 if local.x < 0.0 or (local.x == 0.0 and index == GUNNER_SEAT) else 1.0
	# Dans la soute, pas de place sur les côtés : on descend par l'arrière.
	var beside := Vector3(side * 0.7, 0.0, 3.3) if stowed_in else Vector3(side * (SabreModel.HALF_WIDTH + 0.9), 0.0, local.z)
	unit.global_position = _on_navmesh(to_global(beside))
	unit.velocity = Vector3.ZERO
	return true


## Tout le monde descend. Renvoie faux en route.
func dismount_all() -> bool:
	if is_driving:
		return false
	for unit in crew():
		dismount(unit)
	return true


## `unit`, déjà à bord, change de place pour `index` (volant, tourelle).
func move_seat(unit: Commando, index: int) -> bool:
	var from := seat_of(unit)
	if from < 0 or seats[index] != null or is_driving:
		return false
	seats[from] = null
	if from == GUNNER_SEAT:
		set_gun_firing(false)
	seats[index] = unit
	_place(unit, index)
	return true


## Ouvre ou cesse le feu avec la 12,7 (il faut quelqu'un à la tourelle).
func set_gun_firing(firing: bool) -> bool:
	if firing and (gunner() == null or model.is_folded):
		return false
	gun_firing = firing
	if firing:
		gunner().flash_message("12,7 : feu à volonté")
	return true


## Index de la 7,62 servie depuis la place de `unit` (-1 : aucune).
func side_gun_of(unit: Commando) -> int:
	return SIDE_GUN_SEATS.find(seat_of(unit))


## Ouvre ou cesse le feu avec la 7,62 de la place de `unit`.
func set_side_firing(unit: Commando, firing: bool) -> bool:
	var index := side_gun_of(unit)
	if index < 0 or (firing and (stowed_in != null or is_wrecked)):
		return false
	side_firing[index] = firing
	if firing:
		unit.flash_message("7,62 : feu à volonté")
	return true


## Champ de tir de la 7,62 `index` : avant et droite (chef de bord), arrière
## et gauche (arrière gauche).
func _side_covers(point: Vector3, index: int) -> bool:
	var local := to_local(point)
	local.y = 0.0
	if local.length() < 0.5:
		return false
	var dir := local.normalized()
	if index == 0:
		return dir.z < 0.35 and dir.x > -0.35
	return dir.z > -0.35 and dir.x < 0.35


func _update_boarders() -> void:
	for unit: Commando in _boarders.keys():
		if not is_instance_valid(unit) or unit.is_dead or unit.riding != null:
			_boarders.erase(unit)
			continue
		var door := boarding_point(unit.global_position)
		# Un autre ordre l'emmène ailleurs : il ne monte plus.
		if unit._agent.target_position.distance_to(door) > 1.5 and not unit.is_walking():
			_boarders.erase(unit)
			continue
		if unit.global_position.distance_to(door) <= BOARD_REACH:
			if not seat(unit):
				_boarders.erase(unit)


# --- Conduite -------------------------------------------------------------------

## Raison pour laquelle le véhicule ne peut pas rouler (vide : c'est
## possible).
func drive_problem() -> String:
	if slung_by:
		return "élingué"
	if is_wrecked:
		return "épave"
	if engine_damage >= 1.0:
		return "moteur hors d'usage"
	if driver() == null:
		return "personne au volant"
	if is_maneuvering():
		return "manœuvre en cours"
	if stowed_in:
		return _ramp_problem(stowed_in)
	if coasting and _coast_left <= 0.0:
		return "plus d'élan : relancer le moteur"
	return ""


## Vrai pendant une manœuvre sur la rampe d'un convertible.
func is_maneuvering() -> bool:
	return _ramp_tween != null and _ramp_tween.is_running()


## Raison pour laquelle on ne peut pas passer la rampe de `aircraft` (vide :
## c'est possible).
func _ramp_problem(aircraft: Tiltrotor) -> String:
	if aircraft.is_destroyed:
		return "appareil détruit"
	if aircraft.is_flying or aircraft.is_airborne or aircraft.is_moving or aircraft.is_away or aircraft.is_inbound:
		return "appareil en vol"
	if aircraft.is_ramp_closed:
		return "rampe relevée"
	if aircraft.is_ramp_blocked():
		return "quelqu'un sur la rampe"
	return ""


## Roule jusqu'à `target` par le chemin de navigation (en sortant d'abord de
## la soute, si le véhicule y est garé). Renvoie la raison d'un refus (vide :
## en route).
func drive_to(target: Vector3) -> String:
	var problem := drive_problem()
	if problem != "":
		return problem
	if stowed_in:
		var aircraft := stowed_in
		_begin_driving()
		_then = Callable()
		_ramp_move(aircraft, STOW_Z, _ramp_foot_z(aircraft), func() -> void:
			_leave_hold(aircraft)
			if _set_path(target) != "":
				driver().flash_message("Pas de chemin")
				stop_driving())
		return ""
	problem = _set_path(target)
	if problem != "":
		return problem
	_then = Callable()
	_begin_driving()
	return ""


## Chemin de navigation du sol autour du véhicule jusqu'à `target`.
func _set_path(target: Vector3) -> String:
	var map := get_world_3d().navigation_map
	var start := _ground_start(target)
	if start == Vector3.INF:
		return "pas de chemin"
	var path := NavigationServer3D.map_get_path(map, start, target, true)
	if path.size() < 2:
		return "pas de chemin"
	_path = path
	_path_index = 1
	_blocked_left = BLOCK_GIVE_UP
	return ""


## Raison pour laquelle on ne peut pas laisser tourner le moteur (vide :
## c'est possible).
func idle_problem() -> String:
	if is_wrecked:
		return "épave"
	if engine_damage >= 1.0:
		return "moteur hors d'usage"
	if is_driving:
		return "en route"
	if stowed_in or slung_by:
		return "pas au sol"
	return ""


## Laisse tourner le moteur au ralenti (leurre) ou le coupe.
func set_idling(value: bool) -> bool:
	if value and idle_problem() != "":
		return false
	idling = value
	_idle_left = 0.0
	if value:
		Sfx.play_at(&"clink", global_position + Vector3.UP, -4.0)
	return true


## Coupe le moteur (roue libre silencieuse) ou le relance.
func set_coasting(value: bool) -> bool:
	if is_driving or stowed_in:
		return false
	coasting = value
	_coast_left = COAST_RANGE
	if driver():
		driver().flash_message("Moteur coupé : roue libre (%d m)" % int(COAST_RANGE) if value else "Moteur relancé")
	return true


## En route : les passagers sont emportés, physique suspendue.
func _begin_driving() -> void:
	if is_driving:
		return
	is_driving = true
	idling = false
	_arrived_once = false
	for unit in crew():
		unit.stop()
		unit.process_mode = Node.PROCESS_MODE_DISABLED


# --- Transport aérien -----------------------------------------------------------

## Raison pour laquelle le véhicule ne peut pas monter dans `aircraft` (vide :
## c'est possible).
func load_problem(aircraft: Tiltrotor) -> String:
	if stowed_in == aircraft:
		return "déjà dans la soute"
	var problem := drive_problem()
	if problem != "":
		return problem
	problem = _ramp_problem(aircraft)
	if problem != "":
		return problem
	if aircraft.cargo != null:
		return "soute déjà chargée"
	# La moitié avant de la soute doit être libre.
	for group: StringName in [&"commandos", Enemy.ALL_GROUP, &"vips"]:
		for node in get_tree().get_nodes_in_group(group):
			var unit := node as Node3D
			if unit == null or (unit is Commando and (unit as Commando).riding == self) or unit.get(&"is_dead") == true:
				continue
			if aircraft.cabin_contains(unit.global_position + Vector3.UP * 0.3) and aircraft.to_local(unit.global_position).z < STOW_Z + 3.4:
				return "soute encombrée"
	return ""


## Monte dans la soute de `aircraft` : trajet jusque derrière la rampe,
## alignement, montée de la rampe. Renvoie la raison d'un refus (vide : en
## route).
func load_into(aircraft: Tiltrotor) -> String:
	var problem := load_problem(aircraft)
	if problem != "":
		return problem
	var foot := _ramp_foot_z(aircraft)
	var far := _on_navmesh(aircraft.to_global(Vector3(0, 0, foot + 7.0)))
	problem = _set_path(far)
	if problem != "":
		return problem
	var near := aircraft.to_global(Vector3(0, 0, foot + 2.0))
	near.y = far.y
	_path.append(near)
	_begin_driving()
	_then = _climb_in.bind(aircraft)
	return ""


## z local (appareil) du centre du véhicule quand ses roues avant touchent le
## bas de la rampe, plus une marge.
func _ramp_foot_z(aircraft: Tiltrotor) -> float:
	return TiltrotorModel.RAMP_END * Tiltrotor.SCALE + RAMP_CLEARANCE


## Derrière la rampe : alignement dans l'axe, repli de l'arceau, montée
## jusqu'à l'avant de la soute.
func _climb_in(aircraft: Tiltrotor) -> void:
	var problem := load_problem(aircraft)
	if problem != "":
		driver().flash_message("Embarquement impossible : " + problem)
		stop_driving()
		return
	aircraft.cargo = self
	var foot := _ramp_foot_z(aircraft)
	var start := global_transform
	var goal := _hold_transform(aircraft, foot)
	model.fold(true)
	for index in seats.size():
		if seats[index]:
			seats[index].posture = SoldierModel.Posture.CROUCHED
	set_gun_firing(false)
	_ramp_tween = create_tween()
	_ramp_tween.tween_method(func(weight: float) -> void:
		global_transform = start.interpolate_with(goal, weight)
		_carry_crew(), 0.0, 1.0, ALIGN_TIME).set_trans(Tween.TRANS_SINE)
	_ramp_tween.tween_callback(func() -> void:
		_ramp_move(aircraft, foot, STOW_Z, func() -> void:
			stowed_in = aircraft
			stop_driving()))


## Sorti de la soute de `aircraft` (au pied de la rampe).
func _leave_hold(aircraft: Tiltrotor) -> void:
	stowed_in = null
	if aircraft.cargo == self:
		aircraft.cargo = null
	model.fold(false)
	global_position.y = _ground_height()


## Roule sur l'axe de la soute de `aircraft`, de `from_z` à `to_z` (z local
## de l'appareil), en épousant le plancher et la rampe, puis appelle `done`.
func _ramp_move(aircraft: Tiltrotor, from_z: float, to_z: float, done: Callable) -> void:
	var last := [from_z]
	_ramp_tween = create_tween()
	_ramp_tween.tween_method(func(z: float) -> void:
		global_transform = _hold_transform(aircraft, z)
		# Vers l'avant de l'appareil (z qui baisse) : marche avant.
		model.roll(last[0] - z)
		last[0] = z
		_carry_crew(), from_z, to_z, absf(to_z - from_z) / RAMP_SPEED).set_trans(Tween.TRANS_SINE)
	_ramp_tween.tween_callback(done)


## Place du véhicule dans l'axe de la soute de `aircraft`, centre en `z`
## (local), nez vers l'avant de l'appareil : hauteur et assiette suivent le
## plancher, la rampe ou le sol sous chaque essieu.
func _hold_transform(aircraft: Tiltrotor, z: float) -> Transform3D:
	var front := _deck_height(z - WHEELBASE * 0.5)
	var back := _deck_height(z + WHEELBASE * 0.5)
	var pitch := atan2(front - back, WHEELBASE)
	var local := Transform3D(Basis(Vector3.RIGHT, pitch), Vector3(0, (front + back) * 0.5, z))
	return aircraft.global_transform * local


## Hauteur (locale) du plancher de la soute, de la rampe abaissée ou du sol
## au z local `z` de l'appareil.
static func _deck_height(z: float) -> float:
	var hinge := TiltrotorModel.CABIN_BACK * Tiltrotor.SCALE
	var end := TiltrotorModel.RAMP_END * Tiltrotor.SCALE
	var floor_y := TiltrotorModel.FLOOR * Tiltrotor.SCALE
	return floor_y * clampf((end - z) / (end - hinge), 0.0, 1.0)


## Les passagers suivent le véhicule, à leur place.
func _carry_crew() -> void:
	for index in seats.size():
		var unit := seats[index]
		if unit:
			unit.global_position = to_global(SabreModel.SEATS[index] + Vector3.UP * 0.02)
			unit.global_rotation = Vector3(0.0, global_rotation.y, 0.0)


## Arrêt : les passagers reprennent leur place, la navigation contourne de
## nouveau le véhicule.
func stop_driving() -> void:
	if not is_driving:
		return
	is_driving = false
	_then = Callable()
	if _ramp_tween:
		_ramp_tween.kill()
	_path = PackedVector3Array()
	model.steer(0.0)
	for index in seats.size():
		var unit := seats[index]
		if unit:
			unit.process_mode = Node.PROCESS_MODE_INHERIT
			_place(unit, index)
	EventBus.navigation_obstacle_moved.emit()
	EventBus.sight_blockers_changed.emit()
	if arrival_objective != &"" and stowed_in == null and not _arrived_once and global_position.distance_to(arrival_point) <= ARRIVAL_RADIUS:
		_arrived_once = true
		EventBus.objective_completed.emit(arrival_objective)


func _drive(delta: float) -> void:
	if driver() == null or driver().is_dead:
		if is_maneuvering():
			return
		stop_driving()
		return
	_noise_left -= delta
	if _noise_left <= 0.0 and not (coasting and not is_maneuvering()):
		_noise_left = NOISE_INTERVAL
		EventBus.noise_emitted.emit(global_position, ENGINE_NOISE, &"distraction")
	if is_maneuvering() or _path_index >= _path.size():
		_carry_crew()
		return
	if _is_blocked():
		_blocked_left -= delta
		if _blocked_left <= 0.0:
			driver().flash_message("Route bloquée")
			stop_driving()
		return
	_blocked_left = BLOCK_GIVE_UP
	var next := _path[_path_index]
	var to_next := next - global_position
	to_next.y = 0.0
	if to_next.length() <= WAYPOINT_REACH:
		_path_index += 1
		if _path_index >= _path.size():
			if _then.is_valid():
				var follow := _then
				_then = Callable()
				follow.call()
			else:
				stop_driving()
		return
	# Cap vers le point suivant : on braque, et on ralentit d'autant plus que
	# le virage est serré (presque sur place au pied d'un point de côté).
	var forward := -global_basis.z
	var turn := forward.signed_angle_to(to_next.normalized(), Vector3.UP)
	var step := clampf(turn, -TURN_RATE * delta, TURN_RATE * delta)
	rotate_y(step)
	var sharpness := clampf(absf(turn) / 1.2, 0.0, 1.0)
	var speed := SPEED * lerpf(1.0, SLOW_SHARE, sharpness)
	if _night and not headlights:
		speed *= NIGHT_DARK_SHARE
	if tire_flat:
		speed *= FLAT_SHARE
	if coasting:
		speed = minf(speed, COAST_SPEED)
	if _path_index == _path.size() - 1:
		speed = minf(speed, maxf(to_next.length() * 1.5, 1.5))
	var distance := speed * delta
	if coasting:
		_coast_left -= distance
		if _coast_left <= 0.0:
			driver().flash_message("Plus d'élan : relancer le moteur")
			stop_driving()
			return
	global_position += -global_basis.z * distance
	global_position.y = lerpf(global_position.y, _ground_height(), minf(1.0, delta * 4.0))
	_steer = lerpf(_steer, clampf(turn, -0.5, 0.5), minf(1.0, delta * 6.0))
	model.steer(_steer)
	model.roll(distance)
	_carry_crew()


## Hauteur du sol sous le véhicule (le maillage de navigation flotte un peu
## au-dessus).
func _ground_height() -> float:
	var from := global_position + Vector3.UP * 2.0
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 5.0, 1, body_rids())
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return (hit["position"] as Vector3).y if not hit.is_empty() else global_position.y


## Vrai si une unité debout (pas à bord) est devant le véhicule.
func _is_blocked() -> bool:
	for group: StringName in [&"commandos", Enemy.ALL_GROUP, &"vips"]:
		for node in get_tree().get_nodes_in_group(group):
			var unit := node as Node3D
			if unit == null or (unit is Commando and (unit as Commando).riding == self):
				continue
			if unit.get(&"is_dead") == true:
				continue
			var local := to_local(unit.global_position)
			if local.z < -2.2 and local.z > -2.2 - BLOCK_DEPTH and absf(local.x) < BLOCK_HALF_WIDTH and absf(local.y) < 1.5:
				return true
	return false


func _physics_process(delta: float) -> void:
	# Un passager tombé libère sa place.
	for index in seats.size():
		var unit := seats[index]
		if unit and (not is_instance_valid(unit) or unit.is_dead):
			if is_instance_valid(unit):
				unit.riding = null
				unit.process_mode = Node.PROCESS_MODE_INHERIT
			seats[index] = null
			if index == GUNNER_SEAT:
				gun_firing = false
	if is_driving:
		_drive(delta)
	else:
		_update_boarders()
		_update_repair(delta)
		_update_idle(delta)
	_gun.update(delta, gun_firing and gunner() != null and not model.is_folded)
	for index in _side_guns.size():
		var crew_member := seats[SIDE_GUN_SEATS[index]]
		if side_firing[index] and crew_member == null:
			side_firing[index] = false
		_side_guns[index].update(delta, side_firing[index] and stowed_in == null and not is_wrecked)


## Moteur au ralenti : bruit qui attire les gardes, tant qu'il tourne.
func _update_idle(delta: float) -> void:
	if not idling:
		return
	if idle_problem() != "":
		idling = false
		return
	_idle_left -= delta
	if _idle_left <= 0.0:
		_idle_left = IDLE_INTERVAL
		EventBus.noise_emitted.emit(global_position, ENGINE_NOISE, &"distraction")


# --- Dégâts ----------------------------------------------------------------------

## Une balle touche la carrosserie en `at` : structure, pneu, moteur.
func take_shot(damage: float, at: Vector3, _from: Vector3) -> void:
	if is_wrecked:
		return
	var local := to_local(at)
	for wheel in SabreModel.WHEELS:
		if local.y < SabreModel.WHEEL_RADIUS * 2.0 and Vector2(local.x - wheel.x, local.z - wheel.y).length() < 0.75 \
				and randf() < TIRE_CHANCE:
			_puncture()
			break
	if local.z < SabreModel.CREW_FRONT:
		_hit_engine(damage)
	_damage(damage)


## Une balle tirée sur un passager : la carrosserie l'arrête une fois sur
## deux (`RIDER_COVER`), à un point pris au hasard sur la caisse côté tireur.
## Renvoie vrai si elle l'a arrêtée.
func shields_rider(damage: float, from: Vector3) -> bool:
	if is_wrecked or randf() >= RIDER_COVER:
		return false
	var toward := to_local(from)
	toward.y = 0.0
	toward = toward.normalized() if toward.length() > 0.1 else Vector3.FORWARD
	var at := Vector3(toward.x * SabreModel.HALF_WIDTH, randf_range(0.4, 1.3), clampf(toward.z * 2.4, -2.4, 2.4) + randf_range(-0.8, 0.8))
	take_shot(damage, to_global(at), from)
	return true


## Souffle d'une explosion à `at` (rayon `radius`).
func blast(at: Vector3, radius: float) -> void:
	if is_wrecked:
		return
	var distance := maxf(at.distance_to(global_position + Vector3.UP * 0.8) - 1.5, 0.0)
	if distance > radius:
		return
	var share := 1.0 - distance / radius
	_hit_engine(ENGINE_TOUGHNESS * 0.7 * share)
	if share > 0.3:
		_puncture()
	_damage(STRUCTURE * 0.5 * share)


func _puncture() -> void:
	if tire_flat:
		return
	tire_flat = true
	_announce("Pneu crevé : vitesse réduite")


func _hit_engine(damage: float) -> void:
	var before := engine_damage
	engine_damage = minf(engine_damage + damage / ENGINE_TOUGHNESS, 1.0)
	if before < 1.0 and engine_damage >= 1.0:
		_announce("Moteur hors d'usage")
		if is_driving and not is_maneuvering():
			stop_driving()
	elif before < ENGINE_SMOKE and engine_damage >= ENGINE_SMOKE:
		_announce("Moteur touché")


func _damage(amount: float) -> void:
	structure = maxf(structure - amount, 0.0)
	if structure <= 0.0:
		_wreck()
	_show_damage()


func _announce(text: String) -> void:
	var who := crew()
	if not who.is_empty():
		who[0].flash_message(text)


## Épave : l'équipage saute à terre, le véhicule brûle.
func _wreck() -> void:
	if is_wrecked:
		return
	is_wrecked = true
	if is_driving:
		stop_driving()
	gun_firing = false
	for unit in crew():
		dismount(unit)
		unit.health.take_damage(20.0)
	_set_wreck_look()
	Explosion.detonate(get_parent(), global_position + Vector3.UP, 3.0, 0.0, 40.0)


func _set_wreck_look() -> void:
	var char := StandardMaterial3D.new()
	char.albedo_color = Color(0.12, 0.11, 0.1)
	char.roughness = 1.0
	for node in model.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).material_override = char
	model.fold(false)


## Jauge de structure (dès le premier coup), fumée du moteur touché.
func _show_damage() -> void:
	var damaged := structure < STRUCTURE or tire_flat or engine_damage > 0.0
	if damaged and _gauge == null:
		_gauge = Label3D.new()
		_gauge.name = "Structure"
		_gauge.fixed_size = true
		_gauge.font_size = 24
		_gauge.outline_size = 8
		_gauge.pixel_size = 0.0012
		_gauge.outline_modulate = Color(0.0, 0.0, 0.0, 0.8)
		_gauge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_gauge.no_depth_test = true
		_gauge.shaded = false
		_gauge.position = Vector3(0.0, 3.2, 0.0)
		add_child(_gauge)
	if _gauge:
		_gauge.visible = damaged
		var parts: Array[String] = ["Épave" if is_wrecked else "Sabre %d %%" % ceili(structure / STRUCTURE * 100.0)]
		if not is_wrecked:
			if tire_flat:
				parts.append("pneu crevé")
			if engine_damage >= 1.0:
				parts.append("moteur HS")
			elif engine_damage >= ENGINE_SMOKE:
				parts.append("moteur touché")
		_gauge.text = " • ".join(parts)
		_gauge.modulate = Color(1.0, 0.35, 0.25) if is_wrecked or engine_damage >= 1.0 or structure < STRUCTURE * 0.35 else Color(1.0, 0.85, 0.4)
	var smoking := is_wrecked or engine_damage >= ENGINE_SMOKE
	if smoking and _smoke == null:
		_smoke = _make_smoke()
		add_child(_smoke)
	if _smoke:
		_smoke.emitting = smoking
		_smoke.color = Color(0.12, 0.11, 0.1, 0.7) if is_wrecked else Color(0.45, 0.44, 0.42, 0.55)


func _make_smoke() -> CPUParticles3D:
	var smoke := CPUParticles3D.new()
	smoke.name = "Smoke"
	smoke.position = Vector3(0.0, 1.3, -1.8)
	smoke.amount = 24
	smoke.lifetime = 3.0
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	smoke.emission_sphere_radius = 0.4
	smoke.direction = Vector3.UP
	smoke.spread = 15.0
	smoke.gravity = Vector3(0.0, 1.2, 0.0)
	smoke.initial_velocity_min = 0.6
	smoke.initial_velocity_max = 1.2
	smoke.scale_amount_min = 1.0
	smoke.scale_amount_max = 2.2
	var puff := SphereMesh.new()
	puff.radius = 0.3
	puff.height = 0.6
	puff.radial_segments = 8
	puff.rings = 4
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puff.material = material
	smoke.mesh = puff
	return smoke


# --- Couvert ----------------------------------------------------------------------

## Raison pour laquelle on ne peut pas s'abriter derrière (vide : c'est
## possible).
func cover_problem() -> String:
	if is_driving:
		return "en route"
	if stowed_in or slung_by:
		return "pas au sol"
	return ""


## Direction (à plat) des ennemis à craindre vus depuis le véhicule :
## moyenne des ennemis en alerte ou méfiants, sinon le plus proche debout.
func threat_direction() -> Vector3:
	var sum := Vector3.ZERO
	var nearest := Vector3.ZERO
	var nearest_distance := INF
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.state == Enemy.State.STUNNED:
			continue
		var to_enemy := enemy.global_position - global_position
		to_enemy.y = 0.0
		if enemy.state != Enemy.State.PATROL:
			sum += to_enemy.normalized()
		if to_enemy.length() < nearest_distance:
			nearest_distance = to_enemy.length()
			nearest = to_enemy.normalized()
	var direction := sum if sum.length() > 0.1 else nearest
	return direction.normalized() if direction.length() > 0.1 else -global_basis.z


## `count` points au sol, côte à côte, derrière la caisse par rapport aux
## ennemis (`threat_direction`).
func cover_points(count: int) -> Array[Vector3]:
	var threat := threat_direction()
	var local := global_basis.inverse() * threat
	local.y = 0.0
	local = local.normalized()
	# Distance du centre au bord de la caisse dans cette direction.
	var half_length := 2.5
	var edge := minf(SabreModel.HALF_WIDTH / maxf(absf(local.x), 0.01), half_length / maxf(absf(local.z), 0.01))
	var across := Vector3(-threat.z, 0.0, threat.x)
	# Longueur abritée, le long de la caisse vue des ennemis.
	var span := absf(local.x) * half_length * 2.0 + absf(local.z) * SabreModel.HALF_WIDTH * 2.0
	var points: Array[Vector3] = []
	for i in count:
		var offset := 0.0 if count == 1 else lerpf(-0.5, 0.5, float(i) / (count - 1)) * minf(span - 0.6, count * 0.9)
		points.append(_on_navmesh(global_position - threat * (edge + 0.65) + across * offset))
	return points


## Envoie `units` s'abriter derrière le véhicule, accroupis.
func take_cover(units: Array[Commando], run: bool) -> bool:
	if cover_problem() != "" or units.is_empty():
		return false
	var points := cover_points(units.size())
	for i in units.size():
		var unit := units[i]
		unit.move_to(points[i], run)
		if unit.posture != SoldierModel.Posture.CROUCHED:
			unit.toggle_posture(SoldierModel.Posture.CROUCHED)
	return true


## Balle tirée de `from` vers `to` (sur quelqu'un qui n'est pas à bord) :
## si la caisse est sur la trajectoire, elle la prend. Renvoie le Sabre
## touché, ou null.
static func blocks_shot(tree: SceneTree, from: Vector3, to: Vector3, damage: float) -> Sabre:
	var any := tree.get_first_node_in_group(GROUP) as Sabre
	if any == null:
		return null
	var query := PhysicsRayQueryParameters3D.create(from, to, LAYER_OCCLUDERS)
	var hit := any.get_world_3d().direct_space_state.intersect_ray(query)
	var sabre := hit.get("collider") as Sabre
	if sabre == null or sabre.is_wrecked:
		return null
	sabre.take_shot(damage, hit["position"], from)
	return sabre


## Raison pour laquelle on ne peut pas réparer (vide : c'est possible).
func repair_problem() -> String:
	if is_wrecked:
		return "épave"
	if is_driving:
		return "en route"
	if not tire_flat and engine_damage <= 0.0:
		return "rien à réparer"
	return ""


## Point où se tient le réparateur, devant le capot.
func repair_point() -> Vector3:
	return _on_navmesh(to_global(Vector3(0.0, 0.0, -3.3)))


## Envoie `unit` (à pied) réparer à l'avant. Renvoie faux si impossible.
func request_repair(unit: Commando, run: bool) -> bool:
	if repair_problem() != "" or unit == null or unit.is_dead or unit.riding:
		return false
	_repairer = unit
	_repair_left = REPAIR_TIME
	unit.move_to(repair_point(), run)
	return true


## Réparation : le réparateur, arrivé et immobile, travaille `REPAIR_TIME`
## s ; il renonce si on l'envoie ailleurs.
func _update_repair(delta: float) -> void:
	var unit := _repairer
	if unit == null:
		return
	var spot := repair_point()
	if not is_instance_valid(unit) or unit.is_dead or unit.riding or repair_problem() != "" \
			or (unit._agent.target_position.distance_to(spot) > 1.5 and unit.global_position.distance_to(spot) > REPAIR_REACH):
		_repairer = null
		return
	if unit.global_position.distance_to(spot) > REPAIR_REACH or unit.is_walking():
		return
	var before := ceili(_repair_left)
	_repair_left -= delta
	if ceili(_repair_left) != before and _repair_left > 0.0:
		unit.flash_message("Réparation : %d s" % ceili(_repair_left))
		Sfx.play_at(&"clink", unit.global_position + Vector3.UP, -8.0)
	if _repair_left <= 0.0:
		_repairer = null
		tire_flat = false
		engine_damage = 0.0
		unit.flash_message("Sabre réparé (pneus, moteur)")
		_show_damage()


# --- Sauvegarde ---------------------------------------------------------------

## Sauvegarde rapide (`QuickSave`) : place, cap, équipage (par nom).
func save_state() -> Dictionary:
	var names: Array[String] = []
	for unit in seats:
		names.append(String(unit.name) if unit else "")
	return {"position": global_position, "yaw": global_rotation.y, "seats": names, "gun": gun_firing, "coasting": coasting, "headlights": headlights, "idling": idling, "side_firing": side_firing.duplicate(),
		"structure": structure, "tire_flat": tire_flat, "engine": engine_damage, "wrecked": is_wrecked, "coast_left": _coast_left,
		"stowed": String(stowed_in.get_path()) if stowed_in else ""}


func load_state(data: Dictionary) -> void:
	stop_driving()
	for node in get_tree().get_nodes_in_group(Tiltrotor.GROUP):
		var aircraft := node as Tiltrotor
		if aircraft and aircraft.cargo == self:
			aircraft.cargo = null
	stowed_in = get_node_or_null(NodePath(String(data.get("stowed", "")))) as Tiltrotor if String(data.get("stowed", "")) != "" else null
	if stowed_in:
		stowed_in.cargo = self
	model.fold(stowed_in != null)
	_repairer = null
	structure = data.get("structure", STRUCTURE)
	tire_flat = data.get("tire_flat", false)
	engine_damage = data.get("engine", 0.0)
	if data.get("wrecked", false) and not is_wrecked:
		is_wrecked = true
		_set_wreck_look()
	_show_damage()
	idling = data.get("idling", false)
	var sides: Array = data.get("side_firing", [false, false])
	for index in mini(sides.size(), side_firing.size()):
		side_firing[index] = bool(sides[index])
	coasting = data.get("coasting", false)
	set_headlights(data.get("headlights", false), false)
	_coast_left = data.get("coast_left", COAST_RANGE)
	global_position = data.get("position", global_position)
	global_rotation = Vector3(0.0, data.get("yaw", global_rotation.y), 0.0)
	_restore_crew.call_deferred(data.get("seats", []), data.get("gun", false))


func _restore_crew(names: Array, firing: bool) -> void:
	for index in seats.size():
		if seats[index]:
			seats[index].riding = null
		seats[index] = null
	for index in mini(names.size(), seats.size()):
		if String(names[index]) == "":
			continue
		for node in get_tree().get_nodes_in_group(&"commandos"):
			var unit := node as Commando
			if unit and String(unit.name) == String(names[index]) and not unit.is_dead:
				seats[index] = unit
				unit.riding = self
				_place(unit, index)
	gun_firing = firing and gunner() != null and not model.is_folded
	EventBus.navigation_obstacle_moved.emit()
