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
## Passagers pendant le vol : unité -> position dans le repère de l'appareil.
var _passengers: Dictionary = {}


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
	return cabin_box().has_point(to_local(point))


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
	if closed == is_ramp_closed or is_destroyed or is_flying or is_moving:
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
	var flight := create_tween()
	if up:
		flight.tween_property(model, "rotor_speed", FLIGHT_ROTOR_SPEED, SPIN_UP * 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	flight.tween_property(self, "global_position:y", height, HOVER_TIME).set_trans(Tween.TRANS_SINE)
	if not up:
		flight.tween_property(model, "rotor_speed", 0.0, SPIN_UP * 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	flight.tween_callback(_arrived.bind(up))


func _arrived(up: bool) -> void:
	is_moving = false
	is_airborne = up
	var crew: Array[Commando] = []
	for unit: Commando in _passengers:
		if is_instance_valid(unit):
			unit.process_mode = Node.PROCESS_MODE_INHERIT
			unit.velocity = Vector3.ZERO
			crew.append(unit)
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


## Vrai si une unité se tient au sol sous l'emprise de l'appareil.
func _someone_below() -> bool:
	for group: StringName in [&"commandos", Enemy.ALL_GROUP, &"vips"]:
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
	for unit: Commando in _passengers:
		if is_instance_valid(unit):
			unit.process_mode = Node.PROCESS_MODE_DISABLED


func _flown_away() -> void:
	if objective_id != &"":
		EventBus.objective_completed.emit(objective_id)
	if ends_mission:
		EventBus.mission_ended.emit(true, "RÉUSSITE — appareil volé")


func _physics_process(delta: float) -> void:
	for unit: Commando in _passengers:
		if is_instance_valid(unit):
			unit.global_position = to_global(_passengers[unit])
	if is_flying:
		return
	_check_left -= delta
	if _check_left > 0.0:
		return
	_check_left = CHECK_INTERVAL
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
	if not is_destroyed and distance_to_hull(at) <= radius * BLAST_SHARE:
		destroy()


## Détruit l'appareil : réservoir qui saute, épave en feu, objectif rempli.
func destroy() -> void:
	if is_destroyed or is_flying or is_airborne or is_moving:
		return
	_set_wrecked()
	Explosion.detonate(get_parent(), global_position + Vector3.UP * 1.5, FUEL_RADIUS, FUEL_DAMAGE, FUEL_NOISE)
	EventBus.objective_completed.emit(objective_id)
	if ends_mission:
		get_tree().create_timer(END_DELAY, false).timeout.connect(func() -> void:
			EventBus.mission_ended.emit(true, "RÉUSSITE — appareil détruit"))


## Sauvegarde rapide (`QuickSave`).
func save_state() -> Dictionary:
	return {"destroyed": is_destroyed, "ramp_closed": is_ramp_closed, "airborne": is_airborne, "ground_y": ground_y}


func load_state(data: Dictionary) -> void:
	if data.get("destroyed", false) and not is_destroyed:
		_set_wrecked()
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
