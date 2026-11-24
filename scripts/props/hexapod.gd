@tool
class_name Hexapod
extends Sabre
## Marcheur hexapode blindé (`HexapodModel`) : un véhicule à pattes, cabine
## fermée, cinq places (pilote, servant de la gatling, trois passagers).
##
## Reprend du `Sabre` l'embarquement (clic droit), la conduite par clic
## droit au sol avec points de passage, le menu de bord, la tourelle (feu à
## volonté ou tir désigné), le leurre au ralenti, la réparation, l'abri et
## la sauvegarde. Diffère par :
## - la marche (`_drive`) : lente (`WALK_SPEED`), il pivote sur place dans
##   les virages serrés au lieu de braquer ; il recule vers un point proche
##   derrière lui, ou pour se dégager quand il n'a pas la place de pivoter ; la caisse suit ses pattes
##   (`HexapodModel`, tripode alterné) ; chaque foulée sonne et s'entend
##   (`STEP_NOISE`) ;
## - l'équipage, enfermé dans la caisse : invisible, protégé (les balles
##   visant un passager frappent le blindage) ; les sentinelles repèrent
##   le marcheur lui-même (`sight_zone`), de loin, haut comme il est ;
## - la gatling à six canons sur le toit de la cabine : longues rafales,
##   cadence élevée, très bruyante ;
## - le radar au-dessus de la cabine : avec un équipage, chaque balayage
##   (`RADAR_SWEEP`) signale les ennemis à `RADAR_RANGE` m, même derrière
##   les murs (échos rouges au sol, qui s'effacent) ;
## - le blindage (`ARMOR`) : les balles ne font qu'une part de leurs dégâts ;
##   une patte touchée le ralentit (`LEG_CHANCE`) ; le moteur est à l'arrière.
## Ni plateau, ni ravitaillement, ni missile, ni 7,62, ni transport aérien.

const WALK_SPEED := 2.6
const WALK_TURN := 0.9
## Au-delà de cet écart de cap (rad), il pivote sur place avant d'avancer.
const PIVOT_ANGLE := 0.55
## Marche arrière : vitesse (m/s) ; il recule droit vers un point derrière
## lui (écart de cap au-delà de `Sabre.REVERSE_ANGLE`) s'il reste moins de
## `WALK_BACK_RANGE` m à faire ; coincé (pas la place de pivoter), il recule
## au moins `WALK_BACK_HOLD` s pour se dégager.
const WALK_BACK_SPEED := 1.3
const WALK_BACK_RANGE := 10.0
const WALK_BACK_HOLD := 1.0
const LEG_SHARE := 0.55
const ARMOR := 0.35
const LEG_CHANCE := 0.2
## Bruit d'une foulée (rayon, m) ; bruit du moteur (servo) en marche.
const STEP_NOISE := 14.0
const SERVO_NOISE := 20.0
## Vue des sentinelles : portée lointaine plus longue (il dépasse de tout).
const SIGHT_FACTOR := 1.4
## Gatling.
const GATLING_RANGE := 42.0
const GATLING_DAMAGE := 28.0
const GATLING_BURST := 18
const GATLING_ROUND_INTERVAL := 0.045
const GATLING_BURST_PAUSE := 0.9
const GATLING_SPREAD := 0.045
const GATLING_NOISE := 60.0
## Radar : période de balayage (s), portée (m), durée d'un écho (s).
const RADAR_SWEEP := 2.0
const RADAR_RANGE := 40.0
const ECHO_TIME := 1.8
## Descente et montée : par l'arrière, entre les pattes.
const REAR_EXIT := Vector3(0.0, 0.0, 2.9)
const HALF := 0.9
## Pattes (collision) : demi-épaisseur autour de la ligne hanche-pied (m),
## bas de la boîte (au-dessus du sol).
const LEG_HALF := 0.3
const LEG_FLOOR := 0.1

var _radar_left: float = 0.0
var _step_sound_left: float = 0.0


func _ready() -> void:
	model = HexapodModel.new()
	model.name = "Model"
	add_child(model)
	if Engine.is_editor_hint():
		return
	missiles = 0
	supplies = 0
	collision_layer = LAYER_OCCLUDERS
	collision_mask = 0
	var y := HexapodModel.BODY_HEIGHT
	# Caisse et cabine (les pattes, mobiles, ne bloquent rien).
	_add_box(AABB(Vector3(-0.85, y - 0.4, -1.3), Vector3(1.7, 0.85, 2.8)))
	_add_box(AABB(Vector3(-0.65, y + 0.4, -1.3), Vector3(1.3, 0.7, 1.25)))
	# Pattes : de la hanche au pied, chacune arrête les véhicules, les
	# hommes et les balles (une balle qui la touche peut l'abîmer).
	for i in HexapodModel.HIPS.size():
		var hip := HexapodModel.HIPS[i] + Vector3.UP * y
		var foot := HexapodModel.REST_FEET[i]
		var low := Vector3(minf(hip.x, foot.x), LEG_FLOOR, minf(hip.z, foot.z) - LEG_HALF)
		var high := Vector3(maxf(hip.x, foot.x), y + 0.1, maxf(hip.z, foot.z) + LEG_HALF)
		_add_box(AABB(low, high - low))
	var hexa := model as HexapodModel
	_gun = MountedGun.new(self, hexa.gun_pivot, HexapodModel.GATLING_MUZZLE)
	_gun.reach = GATLING_RANGE
	_gun.damage = GATLING_DAMAGE
	_gun.burst = GATLING_BURST
	_gun.round_interval = GATLING_ROUND_INTERVAL
	_gun.burst_pause = GATLING_BURST_PAUSE
	_gun.spread = GATLING_SPREAD
	_gun.noise = GATLING_NOISE
	_gun.turn_speed = 2.2
	_gun.tracer_color = Color(1.0, 0.55, 0.25)
	_gun.excluded = body_rids
	_gun.on_burst = hexa.spin
	hexa.foot_down.connect(_on_foot_down)
	_night = LevelRoot.is_night(self)
	_build_headlights()
	VehicleNavigation.prepare(self, nav_radius())
	for i in _lamps.size():
		_lamps[i].position = Vector3(-0.4 + 0.8 * i, y + 0.33, -1.36)


func _hexa() -> HexapodModel:
	return model as HexapodModel


# --- Places ---------------------------------------------------------------------

func _seat_point(index: int) -> Vector3:
	return to_global(HexapodModel.CREW_SEATS[index])


## Dans la caisse : invisible, accroupi.
func _place(unit: Commando, index: int) -> void:
	unit.velocity = Vector3.ZERO
	unit.global_position = _seat_point(index)
	unit.global_rotation = Vector3(0.0, global_rotation.y, 0.0)
	unit.posture = SoldierModel.Posture.CROUCHED
	unit.visible = false


func _place_vip(vip: Vip, index: int) -> void:
	vip.velocity = Vector3.ZERO
	vip.global_position = _seat_point(index)
	vip.global_rotation = Vector3(0.0, global_rotation.y, 0.0)
	vip.posture = SoldierModel.Posture.CROUCHED
	vip.visible = false


func _carry_crew() -> void:
	for index in seats.size():
		var unit := seats[index]
		if unit:
			unit.global_position = _seat_point(index)
			unit.global_rotation = Vector3(0.0, global_rotation.y, 0.0)
		var vip := vip_seats[index]
		if vip:
			vip.global_position = _seat_point(index)
			vip.global_rotation = Vector3(0.0, global_rotation.y, 0.0)


## Point de sortie, derrière le marcheur, décalé selon la place.
func _exit_point(index: int) -> Vector3:
	var offset := Vector3((index % 3 - 1) * 0.7, 0.0, 0.0)
	return _on_navmesh(to_global(REAR_EXIT + offset))


func dismount(unit: Commando) -> bool:
	var index := seat_of(unit)
	if index < 0 or is_driving:
		return false
	seats[index] = null
	if index == GUNNER_SEAT:
		set_gun_firing(false)
	unit.riding = null
	unit.visible = true
	unit.global_position = _exit_point(index)
	unit.velocity = Vector3.ZERO
	unit.posture = SoldierModel.Posture.STANDING
	return true


func dismount_vip(vip: Vip) -> bool:
	var index := vip_seats.find(vip)
	if index < 0 or is_driving:
		return false
	vip_seats[index] = null
	vip.riding = null
	vip.visible = true
	vip.process_mode = Node.PROCESS_MODE_INHERIT
	vip.global_position = _exit_point(index)
	vip.velocity = Vector3.ZERO
	vip.posture = SoldierModel.Posture.STANDING
	return true


func boarding_point(_from: Vector3) -> Vector3:
	return _on_navmesh(to_global(REAR_EXIT))


# --- Marche -----------------------------------------------------------------------

## Marche vers le point suivant du chemin : pivote sur place si le cap est
## trop écarté, sinon avance en corrigeant ; plus lent sur une patte touchée,
## tous feux éteints de nuit, et à l'approche du dernier point.
func _drive(delta: float) -> void:
	if driver() == null or driver().is_dead:
		stop_driving()
		return
	_noise_left -= delta
	if _noise_left <= 0.0:
		_noise_left = NOISE_INTERVAL
		EventBus.noise_emitted.emit(global_position, SERVO_NOISE, &"distraction")
	if _path_index >= _path.size():
		_carry_crew()
		return
	var next := _path[_path_index]
	var to_next := next - global_position
	to_next.y = 0.0
	var forward := -global_basis.z
	var turn := forward.signed_angle_to(to_next.normalized(), Vector3.UP)
	var step := clampf(turn, -WALK_TURN * delta, WALK_TURN * delta)
	var reverse := _should_reverse(turn, step, delta) and to_next.length() > WAYPOINT_REACH
	if (_unit_behind() if reverse else _is_blocked()):
		_blocked_left -= delta
		if _blocked_left <= 0.0:
			driver().flash_message("Passage bloqué")
			stop_driving()
		return
	_blocked_left = BLOCK_GIVE_UP
	if to_next.length() <= WAYPOINT_REACH:
		_path_index += 1
		if _path_index >= _path.size() and not _next_waypoint():
			stop_driving()
			if dismount_on_arrival:
				assault_dismount()
		return
	var speed := 0.0 if absf(turn) > PIVOT_ANGLE else WALK_SPEED * (1.0 - absf(turn) / PIVOT_ANGLE * 0.6)
	if reverse:
		# À reculons : c'est l'arrière qu'il oriente vers le point.
		var back_turn := (-forward).signed_angle_to(to_next.normalized(), Vector3.UP)
		step = clampf(back_turn, -WALK_TURN * delta, WALK_TURN * delta)
		speed = -WALK_BACK_SPEED * (1.0 - clampf(absf(back_turn) / PI, 0.0, 0.6))
	if _night and not headlights:
		speed *= NIGHT_DARK_SHARE
	if tire_flat:
		speed *= LEG_SHARE
	if _path_index == _path.size() - 1:
		speed = signf(speed) * minf(absf(speed), maxf(to_next.length() * 1.2, 0.8))
	var barrier := RoadBarrier.ahead(self) if not reverse else null
	if barrier:
		barrier.smash(self, speed)
		if is_wrecked or not is_driving:
			return
	if not reverse and Landmine.under(self, MINE_LOOKAHEAD, true):
		driver().flash_message("Mine devant : la contourner ou la désamorcer")
		stop_driving()
		return
	if _advance(step, WALK_TURN * delta, speed * delta, delta) < 0.0:
		return
	global_position.y = lerpf(global_position.y, _ground_height(), minf(1.0, delta * 3.0))
	var mine := Landmine.under(self)
	if mine:
		mine.detonate(self)
		if is_wrecked or not is_driving:
			return
	_carry_crew()


## Vrai s'il doit reculer : point derrière lui tout près du but, ou pas la
## place de pivoter vers un point qui n'est pas devant (il recule alors un
## moment pour se dégager).
func _should_reverse(turn: float, step: float, delta: float) -> bool:
	if _reverse_left > 0.0:
		_reverse_left -= delta
		return absf(turn) > PIVOT_ANGLE
	if absf(turn) > REVERSE_ANGLE and _remaining() <= WALK_BACK_RANGE:
		return true
	if absf(turn) > PIVOT_ANGLE and VehicleClearance.step(self, footprint(), body_rids(), step, 0.0, 0.0) == null:
		_reverse_left = WALK_BACK_HOLD
		return true
	return false


## Un pied touche le sol : choc sourd (pas plus d'un son par foulée) et
## bruit qui porte.
func _on_foot_down(at: Vector3) -> void:
	if _step_sound_left > 0.0:
		return
	_step_sound_left = 0.15
	Sfx.play_at(&"stomp", at, -4.0, 0.1)
	EventBus.noise_emitted.emit(at, STEP_NOISE, &"distraction")


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_step_sound_left -= delta
	# Un passager tombé ressort de la caisse (le `Sabre` libère sa place).
	for unit in seats:
		if unit and is_instance_valid(unit) and unit.is_dead:
			unit.visible = true
	super(delta)
	_update_radar(delta)


# --- Radar ------------------------------------------------------------------------

## Avec un équipage, à chaque balayage : écho au sol sous chaque ennemi
## debout à portée, visible à travers les murs.
func _update_radar(delta: float) -> void:
	_hexa().radar_on = not is_wrecked and not crew().is_empty()
	if not _hexa().radar_on:
		return
	_radar_left -= delta
	if _radar_left > 0.0:
		return
	_radar_left = RADAR_SWEEP
	for node in get_tree().get_nodes_in_group(Enemy.ALL_GROUP):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead or enemy.is_stunned():
			continue
		if enemy.global_position.distance_to(global_position) <= RADAR_RANGE:
			radar_echo(get_tree().current_scene if get_tree().current_scene else get_parent(), enemy.global_position)


## Écho radar : anneau rouge au sol, par-dessus le décor, qui s'efface.
static func radar_echo(parent: Node, at: Vector3) -> void:
	var ring := MeshInstance3D.new()
	ring.name = "RadarEcho"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.45
	torus.outer_radius = 0.6
	torus.rings = 24
	torus.ring_segments = 4
	ring.mesh = torus
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(1.0, 0.2, 0.15, 0.85)
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.no_depth_test = true
	ring.material_override = glow
	ring.scale = Vector3(1.0, 0.05, 1.0)
	parent.add_child(ring)
	ring.global_position = at + Vector3.UP * 0.1
	var tween := ring.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector3(1.6, 0.05, 1.6), ECHO_TIME)
	tween.tween_property(glow, "albedo_color:a", 0.0, ECHO_TIME)
	tween.chain().tween_callback(ring.queue_free)


# --- Vue des sentinelles ---------------------------------------------------------

## L'équipage est caché dans la caisse : c'est le marcheur que la sentinelle
## voit (de plus loin qu'un homme, `SIGHT_FACTOR`), la nuit seulement de
## près tous feux éteints.
func sight_zone(_zone: VisionComponent.Zone, vision: VisionComponent) -> VisionComponent.Zone:
	var center := global_position + Vector3.UP * (HexapodModel.BODY_HEIGHT + 0.3)
	var local := vision.to_local(center)
	var flat := Vector2(local.x, local.z)
	var far := vision.config.far_range * SIGHT_FACTOR
	if _night:
		far = HEADLIGHT_SIGHT if headlights else vision.config.near_range * 1.5
	if flat.length() > far or absf(atan2(flat.x, -flat.y)) > deg_to_rad(vision.config.fov_degrees) * 0.5:
		return VisionComponent.Zone.NONE
	var eye := vision.global_position + Vector3.UP * vision.config.eye_height
	var query := PhysicsRayQueryParameters3D.create(eye, center, LAYER_OCCLUDERS, body_rids())
	if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
		return VisionComponent.Zone.NONE
	return VisionComponent.Zone.NEAR if flat.length() <= vision.config.near_range else VisionComponent.Zone.FAR


# --- Dégâts ----------------------------------------------------------------------

## Blindage : une part des dégâts. Une balle basse peut toucher une patte
## (ralenti) ; à l'arrière, elle abîme le moteur.
func take_shot(damage: float, at: Vector3, _from: Vector3) -> void:
	if is_wrecked:
		return
	var local := to_local(at)
	if local.y < HexapodModel.BODY_HEIGHT - 0.45 and GameRng.chance(self, LEG_CHANCE):
		_puncture()
	if local.z > 0.6:
		_hit_engine(damage * ARMOR)
	_damage(damage * ARMOR)


## Les balles tirées sur un passager frappent toujours le blindage.
func shields_rider(damage: float, from: Vector3) -> bool:
	if is_wrecked:
		return false
	var toward := to_local(from)
	toward.y = 0.0
	toward = toward.normalized() if toward.length() > 0.1 else Vector3.FORWARD
	var at := Vector3(toward.x * HALF, HexapodModel.BODY_HEIGHT + GameRng.of(self).randf_range(-0.2, 0.6), clampf(toward.z * 1.3, -1.3, 1.4))
	take_shot(damage, to_global(at), from)
	return true


func blast(at: Vector3, radius: float) -> void:
	if is_wrecked:
		return
	var distance := maxf(at.distance_to(global_position + Vector3.UP * HexapodModel.BODY_HEIGHT) - 1.8, 0.0)
	if distance > radius:
		return
	var share := 1.0 - distance / radius
	_hit_engine(ENGINE_TOUGHNESS * 0.5 * share)
	if share > 0.4:
		_puncture()
	_damage(STRUCTURE * 0.3 * share)


func _puncture() -> void:
	if tire_flat:
		return
	tire_flat = true
	_announce("Patte touchée : marche ralentie")


func _set_wreck_look() -> void:
	super()
	_hexa().collapse()


func _wreck() -> void:
	if is_wrecked:
		return
	for unit in crew():
		unit.visible = true
	super()


# --- Collisions -----------------------------------------------------------------

## Emprise : la caisse et toute l'envergure des pattes, pieds compris
## (avec la marge d'une foulée), presque au ras du sol.
func footprint() -> AABB:
	return AABB(Vector3(-2.75, 0.15, -2.25), Vector3(5.5, 2.6, 4.55))


## Un marcheur se décale franchement en crabe pour longer un obstacle.
func _can_crab() -> float:
	return 0.6


## Rayon pour ses chemins : l'envergure des pattes.
func nav_radius() -> float:
	return 2.8


# --- Ce que le marcheur ne fait pas ----------------------------------------------

func side_gun_of(_unit: Commando) -> int:
	return -1


func missile_problem(_unit: Commando) -> String:
	return "pas de missile"


func resupply_problem(_unit: Commando) -> String:
	return "pas de ravitaillement"


func bed_problem(_unit: Commando) -> String:
	return "pas de plateau"


func unload_problem() -> String:
	return "pas de plateau"


func load_problem(_aircraft: Tiltrotor) -> String:
	return "trop grand pour la soute"


func set_coasting(_value: bool) -> bool:
	return false


func cover_points(count: int) -> Array[Vector3]:
	return CoverSpots.points(get_world_3d(), global_transform, HALF + 0.4, 2.2, threat_direction(), count)
