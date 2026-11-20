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
## Tourelle : l'opérateur à la place du tireur ouvre le feu à volonté
## (`set_gun_firing`) avec la mitrailleuse de 12,7 (`MountedGun`, tout
## autour du véhicule).
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
## Arrivée : rayon de la zone autour de `arrival_point`.
const ARRIVAL_RADIUS := 5.0

@export var livery: SabreModel.Livery = SabreModel.Livery.SAND
## Objectif rempli quand le véhicule s'arrête près de `arrival_point`
## (monde) avec quelqu'un au volant (vide : aucun).
@export var arrival_objective: StringName = &""
@export var arrival_point: Vector3 = Vector3.ZERO

var model: SabreModel
## Occupant de chaque place (null : libre), dans l'ordre de `SabreModel.SEATS`.
var seats: Array[Commando] = [null, null, null, null, null]
var is_driving: bool = false
## La 12,7 tire à volonté (si quelqu'un est à la tourelle).
var gun_firing: bool = false
var _gun: MountedGun
var _path := PackedVector3Array()
var _path_index: int = 0
var _blocked_left: float = 0.0
var _noise_left: float = 0.0
var _steer: float = 0.0
## Opérateurs en route pour monter : unité -> vrai.
var _boarders: Dictionary = {}
var _arrived_once: bool = false


func _enter_tree() -> void:
	add_to_group(GROUP)
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
func _ground_start() -> Vector3:
	for local: Vector3 in [Vector3(0, 0, -3.4), Vector3(-2.3, 0, -1.0), Vector3(2.3, 0, -1.0), Vector3(0, 0, 3.4)]:
		var point := _on_navmesh(to_global(local))
		if absf(point.y - global_position.y) < 0.6 and point.distance_to(to_global(local)) < 1.5:
			return point
	return Vector3.INF


## Envoie `unit` monter à bord. Renvoie faux si c'est impossible (déjà à
## bord, plus de place, véhicule en route).
func request_board(unit: Commando, run: bool) -> bool:
	if unit == null or unit.is_dead or unit.riding != null or is_driving:
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
	unit.posture = SoldierModel.Posture.STANDING if index == GUNNER_SEAT else SoldierModel.Posture.CROUCHED


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
	unit.global_position = _on_navmesh(to_global(Vector3(side * (SabreModel.HALF_WIDTH + 0.9), 0.0, local.z)))
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
	if firing and gunner() == null:
		return false
	gun_firing = firing
	if firing:
		gunner().flash_message("12,7 : feu à volonté")
	return true


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
	if driver() == null:
		return "personne au volant"
	return ""


## Roule jusqu'à `target` par le chemin de navigation. Renvoie la raison d'un
## refus (vide : en route).
func drive_to(target: Vector3) -> String:
	var problem := drive_problem()
	if problem != "":
		return problem
	var map := get_world_3d().navigation_map
	var start := _ground_start()
	if start == Vector3.INF:
		return "pas de chemin"
	var path := NavigationServer3D.map_get_path(map, start, target, true)
	if path.size() < 2:
		return "pas de chemin"
	_path = path
	_path_index = 1
	_blocked_left = BLOCK_GIVE_UP
	if not is_driving:
		is_driving = true
		_arrived_once = false
		for unit in crew():
			unit.stop()
			unit.process_mode = Node.PROCESS_MODE_DISABLED
	return ""


## Arrêt : les passagers reprennent leur place, la navigation contourne de
## nouveau le véhicule.
func stop_driving() -> void:
	if not is_driving:
		return
	is_driving = false
	_path = PackedVector3Array()
	model.steer(0.0)
	for index in seats.size():
		var unit := seats[index]
		if unit:
			unit.process_mode = Node.PROCESS_MODE_INHERIT
			_place(unit, index)
	EventBus.navigation_obstacle_moved.emit()
	EventBus.sight_blockers_changed.emit()
	if arrival_objective != &"" and not _arrived_once and global_position.distance_to(arrival_point) <= ARRIVAL_RADIUS:
		_arrived_once = true
		EventBus.objective_completed.emit(arrival_objective)


func _drive(delta: float) -> void:
	if driver() == null or driver().is_dead:
		stop_driving()
		return
	_noise_left -= delta
	if _noise_left <= 0.0:
		_noise_left = NOISE_INTERVAL
		EventBus.noise_emitted.emit(global_position, ENGINE_NOISE, &"distraction")
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
	if _path_index == _path.size() - 1:
		speed = minf(speed, maxf(to_next.length() * 1.5, 1.5))
	var distance := speed * delta
	global_position += -global_basis.z * distance
	global_position.y = lerpf(global_position.y, _ground_height(), minf(1.0, delta * 4.0))
	_steer = lerpf(_steer, clampf(turn, -0.5, 0.5), minf(1.0, delta * 6.0))
	model.steer(_steer)
	model.roll(distance)
	# Les passagers suivent, à leur place.
	for index in seats.size():
		var unit := seats[index]
		if unit:
			unit.global_position = to_global(SabreModel.SEATS[index] + Vector3.UP * 0.02)
			unit.global_rotation = Vector3(0.0, global_rotation.y, 0.0)


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
	_gun.update(delta, gun_firing and gunner() != null)


# --- Sauvegarde ---------------------------------------------------------------

## Sauvegarde rapide (`QuickSave`) : place, cap, équipage (par nom).
func save_state() -> Dictionary:
	var names: Array[String] = []
	for unit in seats:
		names.append(String(unit.name) if unit else "")
	return {"position": global_position, "yaw": global_rotation.y, "seats": names, "gun": gun_firing}


func load_state(data: Dictionary) -> void:
	stop_driving()
	global_position = data.get("position", global_position)
	global_rotation.y = data.get("yaw", global_rotation.y)
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
	gun_firing = firing and gunner() != null
	EventBus.navigation_obstacle_moved.emit()
