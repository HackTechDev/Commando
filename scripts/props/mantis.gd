@tool
class_name Mantis
extends Node3D
## Le Mantis : transporteur lourd à décollage vertical, posé sur ses jambes
## de train (images d'inspiration : `CommandoAsset/vehicles/mantis`). Décor
## fixe construit en code, création originale :
## - un long fuselage à section carrée, dont le ventre est une grande soute
##   de 28 × 11 m (5,2 m sous plafond) où tiennent plusieurs gros véhicules
##   (Sabre, hexapode, pick-up) ; on y entre par la rampe arrière, large de
##   toute la soute (`ramp_open`), ou à pied par la porte latérale tribord
##   et son marchepied ;
## - en tête, la cabine de pilotage en coin, vitrée sur l'avant, comme la
##   tête d'une mante ;
## - sur le dos, une échine de carénages et deux grosses nacelles moteur
##   orientables, tenues par des bras repliés comme les pattes avant d'une
##   mante ; on passe dessous (2,2 m) ;
## - à l'arrière, des ailerons en flèche et une poutre de queue relevée,
##   au-dessus de la rampe.
##
## Quand un opérateur est dans la soute, elle s'affiche en coupe : le toit,
## l'échine et le haut des flancs s'effacent en fondu (les clics les
## traversent, `is_revealed_body`) ; ils restent solides (vue, balles). Un
## corps déposé dans la soute est à l'abri des regards
## (`Enemy.is_hidden_body`).
##
## Rampe en jeu : un opérateur au tableau de commande, près de la porte
## latérale (`PANEL_REACH`), l'abaisse ou la relève (`set_ramp_down`, menu
## de bord) ; relevée, elle ferme la soute. Personne ne doit se tenir dessus
## ni à son pied (`is_ramp_blocked`).
##
## Extraction (`extraction`) : un opérateur dans la soute fait décoller
## l'appareil (`take_off`) quand tous les opérateurs vivants sont à bord
## (dans la soute, à pied ou dans un véhicule garé), que les véhicules
## demandés (`required_cargo`) y sont garés et que les autres objectifs
## sont remplis. Rampe relevée, moteurs lancés (bruit qui alerte), il monte
## à la verticale puis s'éloigne, emportant tout ce qui est dans la soute :
## l'objectif `objective_id` est rempli, la mission réussie.
##
## Arrivée avec des renforts (`arrives`) : absent au début, il arrive au bout
## de `arrival_time` s (ou `ALARM_DELAY` s après une alerte générale, si
## `arrive_on_alarm`) ; la radio ennemie, interceptée, l'annonce
## `ARRIVAL_WARNING` s avant. Il approche nez en avant, se pose (pas sur un
## opérateur), abaisse la rampe, et `reinforcements` soldats en descendent
## pour prendre position autour de `reinforcement_target` (ou foncer vers
## l'alerte en cours). Posé, c'est un Mantis comme un autre.
##
## Repère : centré sur le milieu de la soute, au sol ; nez vers -X, rampe
## vers +X. Plancher, rampe et marchepied sont des sols (couche 1 : la
## navigation les suit) ; le reste arrête le passage, la vue et les balles
## (couche 2). Chaque pièce est un corps à part, pour que l'occlusion
## (`OcclusionFader`) n'estompe que celle qui cache un opérateur.

const GROUP := &"mantis"
## Sols (marche, clics, navigation) et obstacles (vue, balles). Plancher,
## rampe abaissée et marchepied sont sur la seule couche du sol : les
## véhicules (`VehicleClearance`, couche des obstacles) y montent même en
## abordant la rampe de biais.
const LAYER_FLOOR := 0b01
const LAYER_OBSTACLE := 0b10
## Dessus du plancher de la soute.
const FLOOR_TOP := 0.6
## Soute : x de -10 à 18, z de -5,5 à 5,5 (intérieur).
const HOLD := Rect2(-10.0, -5.5, 28.0, 11.0)
## Plafond de la soute et dessus du toit.
const CEILING := 5.8
const ROOF_TOP := 6.3
const WALL := 0.5
## Hauteur (au-dessus du sol) jusqu'à laquelle les flancs restent affichés
## en coupe.
const CUT_HEIGHT := 3.2
## Longueur de la rampe arrière (de la soute au sol).
const RAMP_LENGTH := 5.0
## Porte latérale (flanc +Z) : x de début et largeur, hauteur de passage.
const DOOR_X := -5.0
const DOOR_WIDTH := 1.6
const DOOR_HEIGHT := 2.4
## Nacelles : centre (x, |z|, y), rayon, longueur.
const NACELLE := Vector3(-3.5, 11.2, 6.2)
const NACELLE_RADIUS := 2.4
const NACELLE_LENGTH := 7.2
const FADE_TIME := 0.3
const CHECK_INTERVAL := 0.1
## Tableau de commande de la rampe (près de la porte latérale) et portée.
const PANEL := Vector3(-5.9, 0.6, 5.3)
const PANEL_REACH := 2.2
const RAMP_TIME := 2.0
## Décollage : mise en route, montée verticale, puis départ nez en avant.
const SPIN_UP := 3.0
const LIFT_HEIGHT := 12.0
const LIFT_TIME := 4.0
const CLIMB_HEIGHT := 50.0
const CLIMB_DISTANCE := 90.0
const CLIMB_TIME := 7.0
const ENGINE_NOISE := 45.0
const NOISE_INTERVAL := 1.5
## Arrivée : approche (distance, hauteur, durée), descente, annonce radio,
## délai après une alerte générale.
const APPROACH_DISTANCE := 110.0
const APPROACH_HEIGHT := 40.0
const APPROACH_TIME := 14.0
const DESCENT_TIME := 5.0
const ARRIVAL_WARNING := 30.0
const ALARM_DELAY := 20.0
## Renforts : écart entre deux départs (s), rayon autour du point visé (m).
const UNLOAD_STAGGER := 0.8
const POST_SPREAD := 4.0
const ENEMY_SCENE := "res://scenes/enemies/enemy.tscn"

const SAND := Color(0.72, 0.6, 0.36)
const SAND_DARK := Color(0.55, 0.45, 0.27)
const RUST := Color(0.45, 0.3, 0.2)
const STEEL := Color(0.4, 0.41, 0.42)
const DARK := Color(0.1, 0.1, 0.1)
const INTERIOR := Color(0.36, 0.37, 0.35)
const YELLOW := Color(0.92, 0.72, 0.12)
const GLASS := Color(0.14, 0.2, 0.24)
const LAMP := Color(1.0, 0.86, 0.62)

## Rampe arrière abaissée (vrai) ou relevée, soute fermée (faux).
@export var ramp_open: bool = true:
	set(value):
		ramp_open = value
		_queue_rebuild()
## Immatriculation peinte sur le nez.
@export var hull_number: String = "M-3":
	set(value):
		hull_number = value
		_queue_rebuild()
## Éclairage de la soute (plafonniers).
@export var hold_lights: bool = true:
	set(value):
		hold_lights = value
		_queue_rebuild()

## On peut le voler : décollage avec l'équipe (`take_off`), qui termine la
## mission.
@export var extraction: bool = false
## Objectif rempli au décollage avec l'équipe.
@export var objective_id: StringName = &"mantis_stolen"
## Véhicules (Sabre, hexapode) qui doivent être garés dans la soute pour
## décoller.
@export var required_cargo: Array[NodePath] = []
@export_group("Arrivée avec renforts")
## Absent au début : il arrive en cours de mission avec des renforts.
@export var arrives: bool = false
## Arrivée (s de jeu depuis le début).
@export_range(0.0, 3600.0, 5.0) var arrival_time: float = 300.0
## Une alerte générale avance l'arrivée (`ALARM_DELAY` s après).
@export var arrive_on_alarm: bool = true
## Soldats qui descendent la rampe.
@export_range(0, 8) var reinforcements: int = 4
## Point autour duquel ils prennent position (vide : devant la rampe).
@export var reinforcement_target: NodePath

## Vrai quand la soute est affichée en coupe (un opérateur dedans).
var is_cut: bool = false
## Rampe abaissée (état en jeu ; `ramp_open` est l'état de départ).
var ramp_down: bool = true
## Rampe en mouvement.
var ramp_moving: bool = false
var ramp_body: StaticBody3D
## Pas encore arrivé (`arrives`), en approche, en train de décoller.
var is_away: bool = false
var is_inbound: bool = false
var is_flying: bool = false
## Arrivé avec ses renforts.
var arrived: bool = false
## Temps (s) avant l'arrivée.
var arrival_left: float = 0.0
var _warned: bool = false
var _solid: bool = true
var _landing := Transform3D.IDENTITY
var _exhausts: Array[MeshInstance3D] = []
## Emportés en vol : nœud -> place dans le repère de l'appareil.
var _carried: Dictionary = {}
var _spawned: Array[Enemy] = []
var _noise_left: float = 0.0

var _rebuild_queued: bool = false
var _materials: Dictionary = {}
## Corps et maillages effacés en coupe (toit, échine, haut des flancs).
var _cut_bodies: Array[StaticBody3D] = []
var _cut_meshes: Array[MeshInstance3D] = []
var _fade: float = 0.0
var _check_left: float = 0.0


## Mantis dont la soute contient `point`, ou null.
static func at(tree: SceneTree, point: Vector3) -> Mantis:
	for node in tree.get_nodes_in_group(GROUP):
		var ship := node as Mantis
		if ship and ship.contains(point):
			return ship
	return null


## Vrai si `collider` est une partie effacée d'un Mantis vu en coupe.
static func is_revealed_body(collider: Object) -> bool:
	var body := collider as Node
	if body == null or not body.has_meta(&"mantis"):
		return false
	var ship := body.get_meta(&"mantis") as Mantis
	return ship != null and ship.is_cut and ship._cut_bodies.has(body)


## Vrai si `collider` est une pièce effacée en coupe (toit, échine, haut des
## flancs), coupe affichée ou non : la visée de l'éditeur de mission les
## traverse pour poser dans la soute.
static func is_cut_body(collider: Object) -> bool:
	var body := collider as Node
	if body == null or not body.has_meta(&"mantis"):
		return false
	var ship := body.get_meta(&"mantis") as Mantis
	return ship != null and ship._cut_bodies.has(body)


## Vrai si `point` est dans la soute (entre les flancs, sous le plafond),
## appareil posé.
func contains(point: Vector3) -> bool:
	if is_away or is_inbound or is_flying:
		return false
	var local := to_local(point)
	return HOLD.has_point(Vector2(local.x, local.z)) and local.y > FLOOR_TOP - 0.5 and local.y < CEILING


## Hauteur du plancher de la soute sous (x, z) du monde, ou -INF.
func floor_at(point: Vector3) -> float:
	var local := to_local(point)
	return global_position.y + FLOOR_TOP if HOLD.has_point(Vector2(local.x, local.z)) else -INF


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group(GROUP)
	add_to_group(QuickSave.GROUP)


func _ready() -> void:
	_build()
	if Engine.is_editor_hint():
		return
	_landing = global_transform
	if arrives:
		is_away = true
		arrival_left = arrival_time
		visible = false
		_set_solid(false)
		ramp_down = false
		_pose_ramp(0.0)
		GameState.alert_level_changed.connect(_on_alert_changed)


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
	_cut_bodies.clear()
	_cut_meshes.clear()
	_build()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if is_away:
		_count_down(delta)
		return
	if is_flying or is_inbound:
		_carry()
		_noise_left -= delta
		if _noise_left <= 0.0 and is_flying:
			_noise_left = NOISE_INTERVAL
			EventBus.noise_emitted.emit(global_position, ENGINE_NOISE, &"help")
	_check_left -= delta
	if _check_left <= 0.0:
		_check_left = CHECK_INTERVAL
		var occupied := false
		for node in get_tree().get_nodes_in_group(&"commandos"):
			var unit := node as Commando
			if unit and not unit.is_dead and contains(unit.global_position + Vector3.UP * 0.3):
				occupied = true
				break
		is_cut = occupied
	var goal := 1.0 if is_cut else 0.0
	if not is_equal_approx(_fade, goal):
		_fade = move_toward(_fade, goal, delta / FADE_TIME)
		for mesh in _cut_meshes:
			MeshFade.apply(mesh, _fade)
			mesh.visible = _fade < 0.999


# --- Rampe ------------------------------------------------------------------------

## Point du tableau de commande de la rampe (monde).
func panel_point() -> Vector3:
	return to_global(PANEL)


## Vrai si `unit` est assez près du tableau pour manœuvrer la rampe.
func at_panel(unit: Node3D) -> bool:
	return unit.global_position.distance_to(panel_point()) <= PANEL_REACH and contains(unit.global_position + Vector3.UP * 0.3)


## Raison pour laquelle `unit` ne peut pas manœuvrer la rampe (vide : c'est
## possible).
func ramp_problem(unit: Node3D = null) -> String:
	if is_away or is_inbound or is_flying:
		return "en vol"
	if ramp_moving:
		return "rampe en mouvement"
	if unit and not at_panel(unit):
		return "au tableau près de la porte"
	if is_ramp_blocked():
		return "quelqu'un sur la rampe"
	return ""


## Abaisse (`down`) ou relève la rampe, depuis le tableau (`unit`, null :
## sans condition de place). Renvoie faux si rien ne change.
func set_ramp_down(down: bool, unit: Node3D = null) -> bool:
	if down == ramp_down or ramp_problem(unit) != "":
		return false
	_set_ramp(down, true)
	return true


func _set_ramp(down: bool, animate: bool) -> void:
	ramp_down = down
	Sfx.play_at(&"clink", to_global(Vector3(HOLD.end.x, FLOOR_TOP + 1.0, 0)), -2.0)
	if not animate:
		_pose_ramp(1.0 if down else 0.0)
		_ramp_changed()
		return
	ramp_moving = true
	# Relevée : obstacle dès le départ ; abaissée : sol à l'arrivée.
	var tween := create_tween()
	tween.tween_method(_pose_ramp, 0.0 if down else 1.0, 1.0 if down else 0.0, RAMP_TIME).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func() -> void:
		ramp_moving = false
		_ramp_changed())


func _ramp_changed() -> void:
	EventBus.navigation_obstacle_moved.emit()
	EventBus.sight_blockers_changed.emit()


## Vrai si une unité ou un véhicule se tient sur la rampe ou à son pied.
func is_ramp_blocked() -> bool:
	var reach := HOLD.end.x + RAMP_LENGTH + 0.5
	for group: StringName in [&"commandos", Enemy.ALL_GROUP, &"vips", Sabre.GROUP]:
		for node in get_tree().get_nodes_in_group(group):
			var unit := node as Node3D
			if unit == null or (unit is Commando and (unit as Commando).riding != null):
				continue
			var local := to_local(unit.global_position)
			var margin := 2.6 if unit is Sabre else 0.4
			if local.x > HOLD.end.x - 0.4 - margin * 0.5 and local.x < reach + margin \
					and absf(local.z) < HOLD.size.y * 0.5 + 0.4 and local.y < FLOOR_TOP + 1.5:
				return true
	return false


# --- Décollage ----------------------------------------------------------------------

## Opérateurs vivants dans la soute (à pied ou dans un véhicule garé).
func passengers() -> Array[Commando]:
	var aboard: Array[Commando] = []
	for node in get_tree().get_nodes_in_group(&"commandos"):
		var unit := node as Commando
		if unit and not unit.is_dead and contains(unit.global_position + Vector3.UP * 0.3):
			aboard.append(unit)
	return aboard


## Raison pour laquelle on ne peut pas décoller (vide : c'est possible).
func take_off_problem() -> String:
	if not extraction:
		return "appareil verrouillé"
	if is_away or is_inbound:
		return "pas encore posé"
	if is_flying:
		return "déjà en vol"
	if ramp_moving:
		return "rampe en mouvement"
	var aboard := passengers()
	if aboard.is_empty():
		return "personne à bord"
	for node in get_tree().get_nodes_in_group(&"commandos"):
		var unit := node as Commando
		if unit and not unit.is_dead and not aboard.has(unit):
			return "tous les opérateurs à bord"
	for path in required_cargo:
		var vehicle := get_node_or_null(path) as Node3D
		if vehicle == null or not contains(vehicle.global_position + Vector3.UP * 0.3):
			return "%s dans la soute" % (String(path.get_name(path.get_name_count() - 1)) if vehicle == null else vehicle.name)
	if ramp_down and is_ramp_blocked():
		return "quelqu'un sur la rampe"
	var objectives := get_tree().get_first_node_in_group(Objectives.GROUP) as Objectives
	if objectives and not objectives.done_except(String(objective_id)):
		return "objectifs en cours"
	return ""


## Décolle avec tout ce qui est dans la soute (`pilot` aux commandes) :
## rampe relevée, moteurs lancés, montée verticale, départ. Renvoie faux si
## c'est impossible (`take_off_problem`).
func take_off(pilot: Commando = null) -> bool:
	if take_off_problem() != "":
		return false
	if pilot:
		pilot.stop()
	# Avant `is_flying` : la soute ne contient plus rien en vol.
	_grab_cargo()
	is_flying = true
	if ramp_down:
		_set_ramp(false, true)
	_set_jets(true)
	_noise_left = 0.0
	var flight := create_tween()
	flight.tween_interval(maxf(SPIN_UP, RAMP_TIME + 0.2))
	flight.tween_callback(func() -> void: _set_solid(false))
	flight.tween_property(self, "global_position", global_position + Vector3.UP * LIFT_HEIGHT, LIFT_TIME).set_trans(Tween.TRANS_SINE)
	var goal := global_position + Vector3.UP * (LIFT_HEIGHT + CLIMB_HEIGHT) - global_basis.x * CLIMB_DISTANCE
	flight.tween_property(self, "global_position", goal, CLIMB_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	flight.tween_callback(_flown_away)
	return true


## Tout ce qui est dans la soute part avec l'appareil : opérateurs, VIP,
## ennemis (corps compris) et véhicules garés, figés.
func _grab_cargo() -> void:
	_carried.clear()
	for group: StringName in [&"commandos", &"vips", Enemy.ALL_GROUP, Sabre.GROUP]:
		for node in get_tree().get_nodes_in_group(group):
			var thing := node as Node3D
			if thing == null or _carried.has(thing) or not contains(thing.global_position + Vector3.UP * 0.3):
				continue
			if thing is Commando:
				(thing as Commando).stop()
			thing.process_mode = Node.PROCESS_MODE_DISABLED
			_carried[thing] = global_transform.affine_inverse() * thing.global_transform


func _carry() -> void:
	for thing: Node3D in _carried:
		if is_instance_valid(thing):
			thing.global_transform = global_transform * (_carried[thing] as Transform3D)


func _flown_away() -> void:
	_carry()
	if objective_id != &"":
		EventBus.objective_completed.emit(objective_id)
	EventBus.mission_ended.emit(true, "RÉUSSITE — Mantis volé, équipe extraite")


func _set_jets(on: bool) -> void:
	for jet in _exhausts:
		if is_instance_valid(jet):
			jet.visible = on


## Corps solides (posé) ou fantômes (absent, en vol) : la navigation est
## recalculée.
func _set_solid(solid: bool) -> void:
	_solid = solid
	for child in get_children():
		var body := child as StaticBody3D
		if body == null:
			continue
		if not body.has_meta(&"layer"):
			body.set_meta(&"layer", body.collision_layer)
		body.collision_layer = int(body.get_meta(&"layer")) if solid else 0
	if ramp_body:
		_pose_ramp(1.0 if ramp_down else 0.0)
	EventBus.navigation_obstacle_moved.emit()
	EventBus.sight_blockers_changed.emit()


# --- Arrivée avec renforts --------------------------------------------------------

func _count_down(delta: float) -> void:
	arrival_left -= delta
	if not _warned and arrival_left <= ARRIVAL_WARNING:
		_warned = true
		EventBus.radio_message.emit("(ennemie) le Mantis %s arrive avec des renforts dans %d secondes." % [hull_number, ceili(maxf(arrival_left, 0.0))])
	if arrival_left <= 0.0:
		_fly_in()


func _on_alert_changed(level: GameState.AlertLevel) -> void:
	if level == GameState.AlertLevel.ALARM and is_away and arrive_on_alarm and arrival_left > ALARM_DELAY:
		arrival_left = ALARM_DELAY
		_warned = true
		EventBus.radio_message.emit("(ennemie) alerte : le Mantis %s décolle avec des renforts, arrivée dans %d secondes." % [hull_number, int(ALARM_DELAY)])


## Approche nez en avant jusqu'au-dessus de sa place.
func _fly_in() -> void:
	is_away = false
	is_inbound = true
	visible = true
	_set_jets(true)
	var forward := -_landing.basis.x.normalized()
	var hover := _landing.origin + Vector3.UP * LIFT_HEIGHT
	global_position = hover - forward * APPROACH_DISTANCE + Vector3.UP * (APPROACH_HEIGHT - LIFT_HEIGHT)
	var flight := create_tween()
	flight.tween_property(self, "global_position", hover, APPROACH_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	flight.tween_callback(_over_landing)


## Au-dessus de sa place : il attend qu'aucun opérateur ne soit dessous,
## puis descend.
func _over_landing() -> void:
	if _commando_below():
		get_tree().create_timer(0.5, false).timeout.connect(_over_landing)
		return
	var flight := create_tween()
	flight.tween_property(self, "global_position", _landing.origin, DESCENT_TIME).set_trans(Tween.TRANS_SINE)
	flight.tween_callback(_touched_down)


func _footprint_has(point: Vector3) -> bool:
	var local := _landing.affine_inverse() * point
	return local.x > HOLD.position.x - 9.5 and local.x < HOLD.end.x + RAMP_LENGTH \
			and absf(local.z) < HOLD.size.y * 0.5 + WALL + 2.0


func _commando_below() -> bool:
	for node in get_tree().get_nodes_in_group(&"commandos"):
		var unit := node as Commando
		if unit and not unit.is_dead and _footprint_has(unit.global_position):
			return true
	return false


## Posé : solide, renforts dans la soute, rampe abaissée, puis ils
## descendent.
func _touched_down() -> void:
	is_inbound = false
	arrived = true
	global_transform = _landing
	_set_jets(false)
	# Ennemis restés dessous : écartés sur le côté.
	for node in get_tree().get_nodes_in_group(Enemy.ALL_GROUP):
		var enemy := node as Node3D
		if enemy and _footprint_has(enemy.global_position):
			var local := to_local(enemy.global_position)
			local.z = (HOLD.size.y * 0.5 + WALL + 2.5) * (1.0 if local.z >= 0.0 else -1.0)
			enemy.global_position = to_global(local)
	_set_solid(true)
	EventBus.radio_message.emit("(ennemie) le Mantis %s s'est posé : %d hommes débarquent." % [hull_number, reinforcements])
	_spawn_reinforcements()
	_set_ramp(true, true)
	get_tree().create_timer(RAMP_TIME + 0.6, false).timeout.connect(_unload)


## Point autour duquel les renforts prennent position.
func reinforcement_goal() -> Vector3:
	var target := get_node_or_null(reinforcement_target) as Node3D if not reinforcement_target.is_empty() else null
	if target:
		return target.global_position
	return to_global(Vector3(HOLD.end.x + RAMP_LENGTH + 8.0, 0, 0))


## Postes des renforts : en cercle autour du point visé, tournés vers
## l'extérieur. (monde, cap)
func reinforcement_posts() -> Array:
	var posts: Array = []
	var goal := reinforcement_goal()
	for i in reinforcements:
		var angle := TAU * float(i) / maxf(1.0, float(reinforcements))
		var out := Vector3(cos(angle), 0, sin(angle))
		posts.append([goal + out * POST_SPREAD, atan2(-out.x, -out.z)])
	return posts


## Soldats en rangs dans la soute, près de la rampe.
func _spawn_reinforcements() -> void:
	var scene := load(ENEMY_SCENE) as PackedScene
	var parent := get_tree().current_scene.get_node_or_null(^"Enemies") if get_tree().current_scene else null
	if parent == null:
		parent = get_parent()
	for i in reinforcements:
		var enemy := scene.instantiate() as Enemy
		enemy.stationary = true
		enemy.name = "%sTrooper%d" % [name, i + 1]
		parent.add_child(enemy)
		enemy.global_position = to_global(Vector3(HOLD.end.x - 2.0 - float(i / 2) * 1.6, FLOOR_TOP, -1.2 if i % 2 == 0 else 1.2))
		enemy.global_rotation.y = global_rotation.y - PI * 0.5
		_spawned.append(enemy)


## Les renforts descendent la rampe, l'un après l'autre : vers leur poste,
## ou vers l'alerte en cours.
func _unload() -> void:
	var posts := reinforcement_posts()
	for i in _spawned.size():
		var enemy := _spawned[i]
		if not is_instance_valid(enemy) or enemy.is_dead:
			continue
		var post: Array = posts[i]
		get_tree().create_timer(UNLOAD_STAGGER * i, false).timeout.connect(_send_trooper.bind(enemy, post[0], post[1]))


static func _send_trooper(enemy: Enemy, at: Vector3, yaw: float) -> void:
	if not is_instance_valid(enemy) or enemy.is_dead:
		return
	enemy.set_post(at, yaw)
	if GameState.alert_level == GameState.AlertLevel.ALARM:
		enemy.hear_alarm(at)
	elif enemy.state == Enemy.State.PATROL:
		enemy.walking_home = true
		enemy._begin_return()


# --- Sauvegarde rapide ------------------------------------------------------------

func save_state() -> Dictionary:
	return {"ramp": ramp_down, "away": is_away, "left": arrival_left, "warned": _warned,
		"arrived": arrived or is_inbound}


## Un Mantis en approche est rechargé posé ; ses renforts reviennent à leur
## poste (ceux tombés entre-temps reviennent aussi).
func load_state(data: Dictionary) -> void:
	arrival_left = data.get("left", arrival_left)
	_warned = data.get("warned", false)
	if data.get("arrived", false) and arrives and not arrived:
		is_away = false
		is_inbound = false
		arrived = true
		visible = true
		global_transform = _landing
		_set_jets(false)
		_set_solid(true)
		_spawn_reinforcements()
		var posts := reinforcement_posts()
		for i in _spawned.size():
			_spawned[i].global_position = posts[i][0]
			_spawned[i].global_rotation.y = posts[i][1]
			_spawned[i].set_post(posts[i][0], posts[i][1])
	var down: bool = data.get("ramp", ramp_down)
	if down != ramp_down and not is_away:
		_set_ramp(down, false)


func _build() -> void:
	_exhausts.clear()
	_build_floor()
	_build_ramp()
	_build_walls()
	_build_roof()
	_build_cockpit()
	_build_interior()
	for side: float in [-1.0, 1.0]:
		_build_nacelle(side)
		_build_wing(side)
	_build_tail()
	_build_gear()


# --- Soute -----------------------------------------------------------------------

## Plancher (du sol au dessus de la soute), rampe et marchepied.
func _build_floor() -> void:
	var body := _body("HoldFloor", LAYER_FLOOR)
	var x0 := HOLD.position.x
	var x1 := HOLD.end.x
	var half := HOLD.size.y * 0.5 + WALL
	_collide(body, Vector3(x1 - x0, FLOOR_TOP, half * 2.0), Vector3((x0 + x1) * 0.5, FLOOR_TOP * 0.5, 0))
	_mesh(body, Vector3(x1 - x0, FLOOR_TOP, half * 2.0), Vector3((x0 + x1) * 0.5, FLOOR_TOP * 0.5, 0), _mat(SAND_DARK))
	# Dessus du plancher : tôle striée, rails d'arrimage, bandes jaunes au
	# bord de la rampe.
	_mesh(body, Vector3(x1 - x0, 0.02, HOLD.size.y), Vector3((x0 + x1) * 0.5, FLOOR_TOP + 0.01, 0), _mat(INTERIOR))
	for z: float in [-3.6, -1.2, 1.2, 3.6]:
		_mesh(body, Vector3(x1 - x0 - 0.6, 0.03, 0.12), Vector3((x0 + x1) * 0.5, FLOOR_TOP + 0.02, z), _mat(DARK))
	for i in 8:
		var z := HOLD.position.y + 0.7 + i * 1.375
		_mesh(body, Vector3(0.5, 0.03, 0.6), Vector3(x1 - 0.3, FLOOR_TOP + 0.025, z), _mat(YELLOW if i % 2 == 0 else DARK))
	# Marchepied de la porte latérale.
	var steps := _body("DoorSteps", LAYER_FLOOR)
	var door_mid := DOOR_X + DOOR_WIDTH * 0.5
	_slab(steps, Vector3(door_mid, FLOOR_TOP, half), Vector3(door_mid, 0.0, half + 2.2), DOOR_WIDTH, 0.2, _mat(STEEL, 0.5))


## Rampe arrière, articulée au bord du plancher : abaissée, c'est un sol en
## pente douce jusqu'au terrain ; relevée, elle ferme la soute (obstacle).
## Repère du corps : la charnière, rampe couchée le long de +X, dessus à
## y = 0 ; on la fait pivoter autour de Z.
func _build_ramp() -> void:
	ramp_body = _body("Ramp", LAYER_FLOOR)
	ramp_body.position = Vector3(HOLD.end.x, FLOOR_TOP, 0)
	var length := Vector2(RAMP_LENGTH, FLOOR_TOP).length()
	var width := HOLD.size.y
	_box(ramp_body, Vector3(length, 0.25, width), Vector3(length * 0.5, -0.125, 0), _mat(SAND_DARK))
	_mesh(ramp_body, Vector3(length - 0.2, 0.02, width - 0.6), Vector3(length * 0.5, 0.01, 0), _mat(INTERIOR))
	# Chevrons antidérapants, bandes jaunes au bout, charnières.
	for i in 5:
		_mesh(ramp_body, Vector3(0.12, 0.03, width - 1.2), Vector3(0.8 + i * 0.9, 0.025, 0), _mat(DARK))
	for i in 6:
		_mesh(ramp_body, Vector3(0.35, 0.03, 0.9), Vector3(length - 0.25, 0.025, -width * 0.5 + 0.9 + i * 1.84), _mat(YELLOW if i % 2 == 0 else DARK))
	for z: float in [-4.5, -1.5, 1.5, 4.5]:
		_cylinder(ramp_body, 0.18, 0.9, Vector3(0, -0.12, z), _mat(STEEL, 0.4), Basis(Vector3.RIGHT, PI * 0.5))
	ramp_down = ramp_open
	_pose_ramp(1.0 if ramp_down else 0.0)


## Angle de la rampe : 0 relevée (verticale), 1 abaissée (bout au sol).
func _pose_ramp(open: float) -> void:
	var down := -atan2(FLOOR_TOP, RAMP_LENGTH)
	ramp_body.rotation = Vector3(0, 0, lerpf(PI * 0.5, down, open))
	ramp_body.collision_layer = 0 if not _solid else (LAYER_FLOOR if open > 0.99 else LAYER_OBSTACLE)


## Flancs et cloison avant, en deux étages : le bas reste affiché en coupe,
## le haut s'efface.
func _build_walls() -> void:
	var low := _body("WallsLow", LAYER_OBSTACLE)
	var high := _body("WallsHigh", LAYER_OBSTACLE)
	_mark_cut(high)
	var x0 := HOLD.position.x
	var x1 := HOLD.end.x
	var zw := HOLD.size.y * 0.5 + WALL * 0.5
	var low_h := CUT_HEIGHT
	var high_h := ROOF_TOP - CUT_HEIGHT
	# Flanc bâbord (-Z), plein.
	_box(low, Vector3(x1 - x0, low_h, WALL), Vector3((x0 + x1) * 0.5, low_h * 0.5, -zw), _mat(SAND))
	# Flanc tribord (+Z), percé de la porte.
	var door_end := DOOR_X + DOOR_WIDTH
	_box(low, Vector3(DOOR_X - x0, low_h, WALL), Vector3((x0 + DOOR_X) * 0.5, low_h * 0.5, zw), _mat(SAND))
	_box(low, Vector3(x1 - door_end, low_h, WALL), Vector3((door_end + x1) * 0.5, low_h * 0.5, zw), _mat(SAND))
	_box(low, Vector3(DOOR_WIDTH, FLOOR_TOP, WALL), Vector3(DOOR_X + DOOR_WIDTH * 0.5, FLOOR_TOP * 0.5, zw), _mat(SAND))
	var lintel := FLOOR_TOP + DOOR_HEIGHT
	_box(low, Vector3(DOOR_WIDTH, low_h - lintel, WALL), Vector3(DOOR_X + DOOR_WIDTH * 0.5, (lintel + low_h) * 0.5, zw), _mat(SAND))
	# Encadrement jaune de la porte et feu au-dessus.
	for x: float in [DOOR_X - 0.06, door_end + 0.06]:
		_mesh(low, Vector3(0.12, DOOR_HEIGHT, 0.1), Vector3(x, FLOOR_TOP + DOOR_HEIGHT * 0.5, zw + WALL * 0.5), _mat(YELLOW))
	_mesh(low, Vector3(0.3, 0.15, 0.12), Vector3(DOOR_X + DOOR_WIDTH * 0.5, lintel + 0.25, zw + WALL * 0.5), _glow(LAMP, 2.0))
	# Cloison avant (cabine derrière).
	_box(low, Vector3(WALL, low_h, HOLD.size.y + WALL * 2.0), Vector3(x0 - WALL * 0.5, low_h * 0.5, 0), _mat(SAND))
	# Haut des flancs et de la cloison.
	for z: float in [-zw, zw]:
		_box(high, Vector3(x1 - x0, high_h, WALL), Vector3((x0 + x1) * 0.5, CUT_HEIGHT + high_h * 0.5, z), _mat(SAND))
	_box(high, Vector3(WALL, high_h, HOLD.size.y + WALL * 2.0), Vector3(x0 - WALL * 0.5, CUT_HEIGHT + high_h * 0.5, 0), _mat(SAND))
	# Bandes de camouflage en biais sur les flancs (extérieur).
	for z: float in [-1.0, 1.0]:
		for i in 6:
			var x := x0 + 2.5 + i * 4.6
			var band := Basis(Vector3.BACK, deg_to_rad(28.0))
			var parent := low if i % 2 == 0 else high
			var y := 1.8 if i % 2 == 0 else 4.6
			_mesh(parent, Vector3(1.0, 2.6, 0.03), Vector3(x, y, z * (zw + WALL * 0.5 + 0.01)), _mat(RUST), band)
	# Réservoirs en nacelle le long du bas des flancs (après la porte).
	for side: float in [-1.0, 1.0]:
		var tank := PackedVector2Array([Vector2(zw, 0.9), Vector2(zw + 0.9, 1.2), Vector2(zw + 0.9, 2.3), Vector2(zw, 2.7)])
		var mirrored := PackedVector2Array()
		for point in tank:
			mirrored.append(Vector2(point.x * side, point.y))
		_prism(low, mirrored, -1.6, 12.5, [Vector3.BACK, Vector3.UP, Vector3.RIGHT], _mat(SAND_DARK))
		_collide(low, Vector3(14.1, 1.8, 0.9), Vector3(5.45, 1.8, side * (zw + 0.45)))
		for x: float in [0.5, 4.5, 8.5]:
			_mesh(low, Vector3(0.12, 1.2, 0.06), Vector3(x, 1.75, side * (zw + 0.93)), _mat(DARK))
	# Couples (membrures) intérieurs.
	var x := x0 + 3.5
	while x < x1 - 1.0:
		for z: float in [-1.0, 1.0]:
			_mesh(low, Vector3(0.25, CUT_HEIGHT - FLOOR_TOP, 0.2), Vector3(x, (CUT_HEIGHT + FLOOR_TOP) * 0.5, z * (HOLD.size.y * 0.5 - 0.1)), _mat(STEEL, 0.5))
			_mesh(high, Vector3(0.25, CEILING - CUT_HEIGHT, 0.2), Vector3(x, (CEILING + CUT_HEIGHT) * 0.5, z * (HOLD.size.y * 0.5 - 0.1)), _mat(STEEL, 0.5))
		x += 3.5


## Toit, cadre arrière et échine dorsale.
func _build_roof() -> void:
	var roof := _body("Roof", LAYER_OBSTACLE)
	_mark_cut(roof)
	var x0 := HOLD.position.x
	var x1 := HOLD.end.x + 0.6
	var half := HOLD.size.y * 0.5 + WALL
	_box(roof, Vector3(x1 - x0, ROOF_TOP - CEILING, half * 2.0), Vector3((x0 + x1) * 0.5, (CEILING + ROOF_TOP) * 0.5, 0), _mat(SAND))
	# Cadre de la rampe.
	for z: float in [-half + 0.3, half - 0.3]:
		_mesh(roof, Vector3(0.6, CEILING - CUT_HEIGHT, 0.6), Vector3(x1 - 0.3, (CEILING + CUT_HEIGHT) * 0.5, z), _mat(SAND_DARK))
	# Échine : carénage à pans coupés, prises d'air, trappes.
	var spine := PackedVector2Array([Vector2(-3.4, 0.0), Vector2(-2.6, 1.3), Vector2(2.6, 1.3), Vector2(3.4, 0.0)])
	var shape := PackedVector2Array()
	for point in spine:
		shape.append(point + Vector2(0, ROOF_TOP))
	_prism(roof, shape, x0 - 1.5, x1 - 2.0, [Vector3.BACK, Vector3.UP, Vector3.RIGHT], _mat(SAND))
	_collide(roof, Vector3(x1 - x0 - 0.5, 1.3, 6.4), Vector3((x0 + x1) * 0.5 - 1.75, ROOF_TOP + 0.65, 0))
	for i in 5:
		var x := x0 + 1.5 + i * 5.2
		_mesh(roof, Vector3(2.2, 0.08, 1.6), Vector3(x, ROOF_TOP + 1.34, -1.2 if i % 2 == 0 else 1.2), _mat(SAND_DARK))
		_mesh(roof, Vector3(1.0, 2.0, 0.04), Vector3(x + 1.6, ROOF_TOP + 1.33, 0), _mat(RUST), Basis(Vector3.RIGHT, PI * 0.5) * Basis(Vector3.BACK, deg_to_rad(30.0)))
	for z: float in [-1.0, 1.0]:
		_mesh(roof, Vector3(3.0, 0.7, 0.9), Vector3(x0 + 4.0, ROOF_TOP + 1.3, z * 1.9), _mat(SAND_DARK))
		_mesh(roof, Vector3(0.05, 0.5, 0.7), Vector3(x0 + 2.48, ROOF_TOP + 1.3, z * 1.9), _mat(DARK))
	# Chanfreins des arêtes du toit.
	var edge := PackedVector2Array([Vector2(half - 1.2, ROOF_TOP), Vector2(half, ROOF_TOP - 1.0), Vector2(half + 0.15, ROOF_TOP - 1.0), Vector2(half + 0.15, ROOF_TOP), Vector2(half - 1.2, ROOF_TOP + 0.05)])
	for side: float in [-1.0, 1.0]:
		var mirrored := PackedVector2Array()
		for point in edge:
			mirrored.append(Vector2(point.x * side, point.y))
		_prism(roof, mirrored, x0, x1, [Vector3.BACK, Vector3.UP, Vector3.RIGHT], _mat(SAND_DARK))
	# Feux anticollision.
	_mesh(roof, Vector3(0.25, 0.2, 0.25), Vector3(x0 + 8.0, ROOF_TOP + 1.42, 0), _glow(Color(1.0, 0.2, 0.15), 2.5))


## Cabine de pilotage en coin, devant la soute.
func _build_cockpit() -> void:
	var body := _body("Cockpit", LAYER_OBSTACLE)
	var x0 := HOLD.position.x - WALL
	# Profil (x, y), extrudé en z : nez en coin, menton relevé.
	var profile := PackedVector2Array([Vector2(x0, 0.4), Vector2(x0, ROOF_TOP), Vector2(x0 - 3.0, ROOF_TOP), Vector2(x0 - 6.8, 4.0), Vector2(x0 - 8.6, 2.2), Vector2(x0 - 7.6, 1.0), Vector2(x0 - 4.0, 0.4)])
	_prism(body, profile, -3.8, 3.8, [Vector3.RIGHT, Vector3.UP, Vector3.BACK], _mat(SAND))
	# Joues plus étroites qui avancent le nez (tête de mante).
	var cheek := PackedVector2Array([Vector2(x0 - 3.0, ROOF_TOP - 0.4), Vector2(x0 - 6.4, 3.9), Vector2(x0 - 8.2, 2.2), Vector2(x0 - 3.0, 1.2)])
	for z: float in [-1.0, 1.0]:
		_prism(body, cheek, z * 3.8, z * 4.6, [Vector3.RIGHT, Vector3.UP, Vector3.BACK], _mat(SAND_DARK))
	_collide(body, Vector3(8.6, 5.8, 9.2), Vector3(x0 - 4.3, 3.3, 0))
	# Verrière : bandeau vitré sur le pan incliné, montants.
	var slope := atan2(ROOF_TOP - 4.0, 3.8)
	var glass_at := Vector3(x0 - 4.9, 5.15, 0)
	_mesh(body, Vector3(3.2, 0.06, 6.4), glass_at + Vector3(-0.05, 0.03, 0), _mat(GLASS, 0.15), Basis(Vector3.BACK, slope))
	for z: float in [-2.2, -0.75, 0.75, 2.2]:
		_mesh(body, Vector3(3.3, 0.1, 0.14), glass_at + Vector3(-0.05, 0.09, z), _mat(SAND_DARK), Basis(Vector3.BACK, slope))
	# Hublots bas du nez et projecteurs.
	var chin := atan2(4.0 - 2.2, 1.8)
	_mesh(body, Vector3(1.2, 0.05, 3.0), Vector3(x0 - 7.75, 3.15, 0), _mat(GLASS, 0.15), Basis(Vector3.BACK, chin))
	for z: float in [-2.6, 2.6]:
		_mesh(body, Vector3(0.1, 0.35, 0.5), Vector3(x0 - 8.4, 1.9, z), _glow(LAMP, 2.2))
	# Immatriculation sur les joues.
	for side: float in [-1.0, 1.0]:
		_label(body, hull_number, Vector3(x0 - 2.0, 3.6, side * 4.62), side, 0.02)
	# Antennes et sonde.
	_strut(body, Vector3(x0 - 1.0, ROOF_TOP, 0), Vector3(x0 - 1.0, ROOF_TOP + 1.6, 0), 0.04, _mat(STEEL, 0.4))
	_strut(body, Vector3(x0 - 8.0, 2.4, 0), Vector3(x0 - 10.0, 2.3, 0), 0.05, _mat(STEEL, 0.4))


## Aménagement de la soute : pont roulant, caisses arrimées, plafonniers,
## tableau près de la porte.
func _build_interior() -> void:
	var body := _body("HoldFittings", LAYER_OBSTACLE)
	var x0 := HOLD.position.x
	# Rack de caisses contre la cloison avant (bâbord), sanglé.
	_box(body, Vector3(1.6, 1.4, 3.2), Vector3(x0 + 0.85, FLOOR_TOP + 0.7, -3.7), _mat(Color(0.3, 0.34, 0.24)))
	_box(body, Vector3(1.6, 1.0, 1.4), Vector3(x0 + 0.85, FLOOR_TOP + 1.9, -4.5), _mat(Color(0.3, 0.34, 0.24)))
	for z: float in [-4.6, -2.9]:
		_mesh(body, Vector3(1.7, 1.5, 0.08), Vector3(x0 + 0.85, FLOOR_TOP + 0.75, z), _mat(YELLOW))
	# Tableau de commande de la rampe, près de la porte.
	_mesh(body, Vector3(0.8, 0.6, 0.12), Vector3(DOOR_X - 0.9, FLOOR_TOP + 1.4, HOLD.size.y * 0.5 - 0.08), _mat(DARK))
	_mesh(body, Vector3(0.6, 0.12, 0.04), Vector3(DOOR_X - 0.9, FLOOR_TOP + 1.5, HOLD.size.y * 0.5 - 0.15), _glow(Color(0.3, 0.9, 0.4), 1.5))
	# Pont roulant : deux rails sous le plafond (effacés en coupe) et un
	# chariot.
	var crane := _body("Crane", 0)
	_mark_cut(crane)
	for z: float in [-4.6, 4.6]:
		_mesh(crane, Vector3(HOLD.size.x - 0.6, 0.35, 0.3), Vector3(HOLD.get_center().x, CEILING - 0.2, z), _mat(STEEL, 0.5))
	_mesh(crane, Vector3(0.5, 0.4, 9.2), Vector3(-2.0, CEILING - 0.6, 0), _mat(YELLOW))
	_strut(crane, Vector3(-2.0, CEILING - 0.8, 0.5), Vector3(-2.0, 3.6, 0.5), 0.03, _mat(DARK))
	_mesh(crane, Vector3(0.3, 0.3, 0.3), Vector3(-2.0, 3.5, 0.5), _mat(DARK))
	# Plafonniers.
	for i in 4:
		var x := x0 + 3.5 + i * 7.0
		_mesh(crane, Vector3(1.6, 0.1, 0.3), Vector3(x, CEILING - 0.06, 0), _glow(LAMP, 2.0))
		if hold_lights:
			var light := OmniLight3D.new()
			light.name = "HoldLamp%d" % (i + 1)
			light.light_color = LAMP
			light.light_energy = 1.4
			light.omni_range = 8.0
			light.omni_attenuation = 1.2
			light.position = Vector3(x, CEILING - 0.6, 0)
			add_child(light)


# --- Nacelles, ailerons, queue, train --------------------------------------------

## Nacelle moteur du côté `side` (-1 bâbord, 1 tribord), sur son bras replié.
func _build_nacelle(side: float) -> void:
	var body := _body("Nacelle%s" % ("L" if side < 0.0 else "R"), LAYER_OBSTACLE)
	var center := Vector3(NACELLE.x, NACELLE.z, side * NACELLE.y)
	# Nacelle presque verticale (posé), entrée d'air vers le haut.
	var tilt := Basis(Vector3.BACK, deg_to_rad(-12.0))
	_cylinder(body, NACELLE_RADIUS, NACELLE_LENGTH, center, _mat(SAND), tilt)
	_cylinder(body, NACELLE_RADIUS * 1.06, 0.6, center + tilt * Vector3(0, NACELLE_LENGTH * 0.5 - 0.3, 0), _mat(SAND_DARK), tilt)
	_cylinder(body, NACELLE_RADIUS * 0.82, 0.08, center + tilt * Vector3(0, NACELLE_LENGTH * 0.5 + 0.02, 0), _mat(DARK), tilt)
	_cylinder(body, NACELLE_RADIUS * 0.35, 0.3, center + tilt * Vector3(0, NACELLE_LENGTH * 0.5 + 0.1, 0), _mat(STEEL, 0.4), tilt)
	_cylinder(body, NACELLE_RADIUS * 0.75, 0.7, center + tilt * Vector3(0, -NACELLE_LENGTH * 0.5 - 0.3, 0), _mat(DARK), tilt)
	# Jet de poussée, allumé en vol.
	var jet := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = NACELLE_RADIUS * 0.7
	cone.bottom_radius = NACELLE_RADIUS * 0.15
	cone.height = 3.0
	jet.mesh = cone
	jet.material_override = _glow(Color(1.0, 0.6, 0.3), 3.0)
	jet.transform = Transform3D(tilt, center + tilt * Vector3(0, -NACELLE_LENGTH * 0.5 - 2.1, 0))
	jet.visible = is_flying or is_inbound
	body.add_child(jet)
	_exhausts.append(jet)
	# Plaques de blindage en biais et bandes.
	for k in 3:
		var y := -1.8 + k * 1.8
		_cylinder(body, NACELLE_RADIUS * 1.02, 0.25, center + tilt * Vector3(0, y, 0), _mat(RUST if k == 1 else SAND_DARK), tilt)
	_collide(body, Vector3(NACELLE_RADIUS * 2.2, NACELLE_LENGTH, NACELLE_RADIUS * 2.2), center, tilt)
	# Bras : épaule sur le toit, coude haut, avant-bras jusqu'au moyeu ; un
	# second bras, plus fin, double le premier (patte de mante).
	var shoulder := Vector3(NACELLE.x - 1.0, ROOF_TOP + 0.5, side * (HOLD.size.y * 0.5 - 0.3))
	var elbow := Vector3(NACELLE.x + 2.0, ROOF_TOP + 5.2, side * (NACELLE.y - 3.4))
	var hub := center + Vector3(0.6, 2.2, -side * NACELLE_RADIUS * 0.95)
	_cylinder(body, 0.8, 1.8, shoulder, _mat(SAND_DARK), Basis(Vector3.RIGHT, PI * 0.5))
	for offset: float in [-0.4, 0.4]:
		var shift := Vector3(offset, 0, 0)
		_strut(body, shoulder + shift, elbow + shift, 0.32, _mat(SAND))
		_strut(body, elbow + shift, hub + shift, 0.28, _mat(SAND))
	_cylinder(body, 0.6, 1.5, elbow, _mat(STEEL, 0.5), Basis(Vector3.BACK, PI * 0.5))
	_cylinder(body, 0.65, 1.2, hub, _mat(STEEL, 0.5), Basis(Vector3.BACK, PI * 0.5))
	var shoulder2 := shoulder + Vector3(3.2, 0.0, 0)
	var elbow2 := elbow + Vector3(2.6, -1.4, side * 0.4)
	_strut(body, shoulder2, elbow2, 0.2, _mat(SAND_DARK))
	_strut(body, elbow2, hub + Vector3(1.4, -0.6, 0), 0.18, _mat(SAND_DARK))
	_cylinder(body, 0.35, 0.9, elbow2, _mat(STEEL, 0.5), Basis(Vector3.BACK, PI * 0.5))
	# Vérins hydrauliques le long des bras.
	_strut(body, shoulder + Vector3(1.0, 0.3, 0), elbow + Vector3(0.8, -1.0, 0), 0.13, _mat(STEEL, 0.4))
	_strut(body, elbow + Vector3(-0.6, -0.4, 0), hub + Vector3(-0.6, 0.6, 0), 0.11, _mat(STEEL, 0.4))
	_collide(body, Vector3(1.6, 5.2, 1.6), (shoulder + elbow) * 0.5)


## Aileron en flèche du côté `side`, à mi-hauteur de l'arrière.
func _build_wing(side: float) -> void:
	var body := _body("Wing%s" % ("L" if side < 0.0 else "R"), LAYER_OBSTACLE)
	var root := HOLD.size.y * 0.5 + WALL
	var y := 4.2
	# Profil (x, z) : bord d'attaque en flèche.
	var plan := PackedVector2Array([Vector2(7.0, root), Vector2(15.0, root), Vector2(16.5, root + 6.5), Vector2(13.5, root + 6.5)])
	var shape := PackedVector2Array()
	for point in plan:
		shape.append(Vector2(point.x, point.y * side))
	_prism(body, shape, y, y + 0.3, [Vector3.RIGHT, Vector3.BACK, Vector3.UP], _mat(SAND))
	_collide(body, Vector3(5.0, 0.3, 6.5), Vector3(13.0, y + 0.15, side * (root + 3.25)))
	# Réacteur d'appoint sous l'aile, et bande.
	var jet := Vector3(12.0, y - 0.7, side * (root + 2.4))
	_cylinder(body, 0.55, 3.2, jet, _mat(SAND_DARK), Basis(Vector3.BACK, PI * 0.5))
	_cylinder(body, 0.42, 0.1, jet + Vector3(1.62, 0, 0), _mat(DARK), Basis(Vector3.BACK, PI * 0.5))
	_mesh(body, Vector3(0.8, 0.04, 6.0), Vector3(14.2, y + 0.32, side * (root + 3.1)), _mat(RUST), Basis(Vector3.UP, side * deg_to_rad(-12.0)))


## Poutre de queue relevée au-dessus de la rampe, et dérive repliée.
func _build_tail() -> void:
	var body := _body("Tail", LAYER_OBSTACLE)
	var start := Vector3(HOLD.end.x - 1.0, ROOF_TOP + 0.6, 0)
	var end := Vector3(HOLD.end.x + 11.0, ROOF_TOP + 3.0, 0)
	var axis := end - start
	var basis := Basis(Vector3.BACK, atan2(axis.y, axis.x))
	_mesh(body, Vector3(axis.length(), 1.2, 2.0), (start + end) * 0.5, _mat(SAND), basis)
	_collide(body, Vector3(axis.length(), 1.2, 2.0), (start + end) * 0.5, basis)
	_mesh(body, Vector3(axis.length() * 0.6, 0.3, 2.06), start + axis * 0.55 + Vector3(0, 0.2, 0), _mat(RUST), basis)
	# Dérive : plan incliné en arrière, et empennages.
	var fin := PackedVector2Array([Vector2(end.x - 3.0, end.y), Vector2(end.x + 0.5, end.y), Vector2(end.x + 1.5, end.y + 3.2), Vector2(end.x - 0.5, end.y + 3.2)])
	_prism(body, fin, -0.15, 0.15, [Vector3.RIGHT, Vector3.UP, Vector3.BACK], _mat(SAND_DARK))
	var plane := PackedVector2Array([Vector2(end.x - 2.6, -0.8), Vector2(end.x + 0.2, -0.8), Vector2(end.x + 0.8, -4.0), Vector2(end.x - 0.6, -4.0)])
	for side: float in [-1.0, 1.0]:
		var mirrored := PackedVector2Array()
		for point in plane:
			mirrored.append(Vector2(point.x, point.y * side))
		_prism(body, mirrored, end.y - 0.1, end.y + 0.1, [Vector3.RIGHT, Vector3.BACK, Vector3.UP], _mat(SAND))
	_mesh(body, Vector3(0.2, 0.2, 0.2), Vector3(end.x + 1.3, end.y + 3.3, 0), _glow(Color(1.0, 0.2, 0.15), 2.5))


## Jambes de train et patins.
func _build_gear() -> void:
	var gear := Node3D.new()
	gear.name = "Gear"
	add_child(gear)
	var half := HOLD.size.y * 0.5 + WALL
	for x: float in [-13.0, -4.0, 7.0, 15.5]:
		for side: float in [-1.0, 1.0]:
			var hip := Vector3(x, 1.6, side * half)
			var foot := Vector3(x + 0.4, 0.2, side * (half + 1.9))
			_strut(gear, hip, foot, 0.2, _mat(STEEL, 0.5))
			_strut(gear, hip + Vector3(0.9, -0.4, 0), foot, 0.1, _mat(STEEL, 0.4))
			_cylinder(gear, 0.55, 0.2, foot - Vector3(0, 0.1, 0), _mat(DARK))
			_mesh(gear, Vector3(1.1, 0.5, 0.25), hip, _mat(SAND_DARK))


# --- Outils ----------------------------------------------------------------------

func _body(name_hint: String, layer: int) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = name_hint
	body.collision_layer = layer
	body.collision_mask = 0
	add_child(body)
	return body


## Corps effacé avec la coupe : ses maillages, présents et à venir.
func _mark_cut(body: StaticBody3D) -> void:
	body.set_meta(&"mantis", self)
	_cut_bodies.append(body)
	body.child_entered_tree.connect(func(child: Node) -> void:
		if child is MeshInstance3D:
			_cut_meshes.append(child))


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


## Dalle inclinée dont le dessus va de `high` à `low` (milieux des bords),
## large de `width` et épaisse de `thickness` (rampe, marchepied).
func _slab(body: StaticBody3D, high: Vector3, low: Vector3, width: float, thickness: float, material: Material, solid: bool = true) -> void:
	var forward := (low - high).normalized()
	var flat := Vector3(forward.x, 0.0, forward.z).normalized()
	var side := Vector3.UP.cross(flat).normalized()
	var up := forward.cross(side)
	var basis := Basis(side, up, forward)
	var size_ := Vector3(width, thickness, high.distance_to(low))
	var at := (high + low) * 0.5 - up * thickness * 0.5
	if solid:
		_collide(body, size_, at, basis)
	_mesh(body, size_, at, material, basis)


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
	tube.radial_segments = 16
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


## Inscription peinte sur un flanc tourné vers ±Z (`side`).
func _label(parent: Node3D, text: String, at: Vector3, side: float, pixel: float) -> void:
	var label := Label3D.new()
	label.text = text
	label.pixel_size = pixel
	label.font_size = 96
	label.outline_size = 0
	label.modulate = Color(0.15, 0.13, 0.1)
	label.double_sided = false
	label.shaded = true
	label.transform = Transform3D(Basis.IDENTITY if side > 0.0 else Basis(Vector3.UP, PI), at)
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
	material.emission_energy_multiplier = energy
	material.emission = color
	_materials[key] = material
	return material
