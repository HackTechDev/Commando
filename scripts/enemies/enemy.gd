class_name Enemy
extends CharacterBody3D
## Soldat ennemi : patrouille, détection progressive et alerte.
##
## Machine à états minimale (jalon M3) :
## - PATROL : suit les points du `patrol_path` avec une pause à chacun
##   (ou garde son poste s'il n'a pas de chemin) ;
## - SUSPICIOUS : la jauge de détection monte, il s'arrête et regarde la cible,
##   ou va voir d'où vient un bruit (activité `INVESTIGATE`) ;
## - ALERT : cible repérée. Il la poursuit jusqu'à portée de tir et tire tant
##   qu'il la voit ; s'il la perd, il court à sa dernière position connue,
##   y attend `alert_memory` secondes, puis fouille les environs (activité
##   `SEARCH`, méfiant) et rentre à sa ronde ou à son poste (`RETURN`),
##   plus vigilant pendant `WARY_TIME` secondes ;
## - STUNNED : assommé, au sol, aveugle, pendant `stun_duration` secondes. Au
##   réveil, il passe en alerte sur place, puis reprend sa patrouille ;
##   au contact de sa cible, il frappe au lieu de tirer ; un coup paré ou
##   esquivé le déséquilibre un instant ; à sec, il charge pour frapper ;
## - GRABBED : saisi par derrière (étranglement, égorgement), immobile et
##   sans réaction ; relâché, il passe en alerte.
##
## Désarmé (`disarm`), il lève les mains et ne fait plus rien, quel que soit
## son état : inoffensif, mais toujours conscient.

enum State { PATROL, SUSPICIOUS, ALERT, STUNNED, GRABBED }
## Ce qu'il fait, en plus de son état de vigilance (`State`) :
## - INVESTIGATE : il va voir d'où vient un bruit (méfiant) et regarde autour ;
## - SEARCH : cible perdue, il fouille autour du dernier point connu (méfiant) ;
## - RETURN : fouille finie, il rentre à sa ronde ou à son poste (calme).
enum Activity { NONE, INVESTIGATE, SEARCH, RETURN }

signal state_changed(state: State)

## Dénivelé (m) au-delà duquel une cible est hors d'atteinte au corps à corps.
const MELEE_MAX_HEIGHT := 0.8

@export var stats: EnemyStats
## Chemin de patrouille (points de la courbe), parcouru en boucle.
@export var patrol_path: Path3D
## Porte une arme et tire en alerte. Sans arme, il se contente de regarder.
@export var armed: bool = true
## Ne se déplace jamais, même en alerte (sentinelle, cible d'entraînement).
@export var stationary: bool = false
## Ne voit rien (mannequin d'entraînement) : il ne passe jamais en alerte de
## lui-même, et son cône n'est pas affiché.
@export var blind: bool = false
## Porte un lance-roquettes : il tire en priorité sur un convertible en vol à
## portée (`LAUNCHER_RANGE`), même s'il voit des opérateurs ; roquettes en
## nombre limité (`rockets`).
@export var launcher: bool = false
## Officier : porte une sacoche de documents. Un opérateur la récupère sur son
## corps (mort ou assommé) ; documents ou corps à rapporter à bord du
## convertible (`Tiltrotor.documents_objective`).
@export var documents: bool = false
@export var rockets: int = 2

## Évitement : en dessous de cette part de la vitesse voulue, l'unité est
## considérée comme bloquée et fait un pas de côté.
const BLOCKED_RATIO := 0.4
const SIDESTEP_RATIO := 0.7
## Couche physique d'un ennemi actif (« Ennemis ») et d'un ennemi assommé
## (« Interactables ») : assommé, il ne bloque plus le passage mais reste ciblable.
const LAYER_ACTIVE := 0b1000
const LAYER_DOWN := 0b10000
## Au-delà de cet angle (degrés) entre son regard et la direction d'une
## position, celle-ci est considérée comme dans son dos.
const BEHIND_ANGLE := 110.0
## Distance (m) en deçà de laquelle un ennemi en alerte lève sa garde face
## à sa cible (bras levés, arme en travers) : seuls un contre ou une prise
## par derrière passent alors.
const GUARD_RANGE := 2.2
## Durée (s) pendant laquelle un ennemi qui vient de passer en alerte est
## pris de court : il se laisse désarmer, même de face.
const SURPRISE_TIME := 1.5
## Arme arrachée : posée au sol à cette distance (m) de l'ennemi, côté
## assaillant.
const DROP_DISTANCE := 0.6
## Un otage à moins de cette distance (m) de la ligne de tir la couvre :
## l'ennemi retient son tir.
const HOSTAGE_COVER_RADIUS := 0.45
## Appel à l'aide d'un ennemi saisi : premier cri après `HELP_DELAY`
## secondes, puis toutes les `HELP_INTERVAL` secondes. Tenu en otage, il
## crie à pleine voix (`HELP_RADIUS`) ; étranglé, son cri est étouffé
## (`HELP_RADIUS_MUFFLED`).
const HELP_DELAY := 1.2
const HELP_INTERVAL := 2.5
const HELP_RADIUS := 12.0
const HELP_RADIUS_MUFFLED := 4.0
## Bruit de diversion : il va voir, puis regarde autour de lui ce temps (s).
const INVESTIGATE_LOOK_TIME := 3.0
## Fouille : points visités (le dernier point connu, puis d'autres au
## hasard dans ce rayon, en m), regard autour de chacun (s), allure
## (multiple de celle de la ronde).
const SEARCH_POINTS := 3
const SEARCH_RADIUS := 7.0
const SEARCH_LOOK_TIME := 2.5
const SEARCH_SPEED := 1.4
## Après une fouille, vigilance accrue pendant ce temps (s) : la jauge de
## détection monte `WARY_GAIN` fois plus vite.
const WARY_TIME := 90.0
const WARY_GAIN := 1.5
## Tous les ennemis, vivants ou non (corps à découvrir).
const ALL_GROUP := &"all_enemies"
## Ennemis qui portent des documents (`documents`).
const DOCUMENTS_GROUP := &"documents"
## Intervalle (s) entre deux recherches de corps dans le champ de vision.
const BODY_CHECK_INTERVAL := 0.3
## Rayon (m) du cri d'un ennemi qui découvre un corps.
const BODY_ALARM_RADIUS := 12.0
## Corps à corps à plusieurs : un second assaillant se place sur le flanc
## de la cible, à cet angle (degrés) du premier.
const FLANK_ANGLE := 100.0
const GAUGE_HEIGHT := 2.3
const GAUGE_HEIGHT_DOWN := 1.0
## Riposte contre un convertible en l'air (`Tiltrotor.is_in_air`) : portée
## (part de `fire_range`), intervalle de recherche (s), bonus de précision
## (grande cible).
const AIR_RANGE_SHARE := 1.5
const AIR_CHECK_INTERVAL := 0.25
const AIR_HIT_BONUS := 0.15
## Lance-roquettes : portée contre un appareil en vol (m), temps de visée,
## rechargement (s), écart au point visé (m).
const LAUNCHER_RANGE := 60.0
const LAUNCHER_AIM := 2.2
const LAUNCHER_RELOAD := 6.0
const LAUNCHER_SPREAD := 3.0

var state: State = State.PATROL
var is_dead: bool = false
## Jauge de détection, de 0 (rien vu) à 1 (repéré).
var detection: float = 0.0
## Balles arrêtées par un bouclier.
var shots_blocked: int = 0
## Cris d'appel à l'aide poussés.
var cries: int = 0
var _help_left: float = 0.0
## Activité en cours (`Activity`).
var activity: Activity = Activity.NONE
## Va voir d'où vient un bruit (`_last_seen`), méfiant.
var investigating: bool:
	get:
		return activity == Activity.INVESTIGATE
## Dernier bruit entendu (type), pour la mise au point et les tests.
var last_heard: StringName = &""
## Enquête sur un bruit faible : il se tourne vers lui sans y aller.
var _look_only: bool = false
## Vigilance accrue restante (s), après une fouille.
var wary_left: float = 0.0
## Points de la fouille en cours et point visé.
var _search_points: Array[Vector3] = []
var _search_index: int = 0
## Poste d'origine (place et cap), où rentre un garde sans ronde.
var _home := Vector3.ZERO
var _home_yaw: float = 0.0
## Opérateur qui porte ce corps (mort ou assommé), ou null.
var carrier: Commando
## Véhicule sur le plateau duquel il est couché (corps, ou otage ligoté), ou
## null : caché sous la bâche, il ne se réveille pas.
var on_vehicle: Node3D
## Corps déjà découvert par un ennemi (l'alarme a été donnée une fois).
var discovered: bool = false
## Bassin et axe bassin-tête du corps (son repère), relevés quand on le
## soulève : sa pose étendue ne change plus.
var carried_hips := Vector3.ZERO
var carried_axis := Vector3.BACK
var _body_check_left: float = 0.0
var _look_left: float = 0.0
## Tirs retenus parce qu'un otage couvrait la cible.
var hesitations: int = 0
## Cartouches restantes (négatif : sans limite).
var ammo: int = -1
## Désarmé : mains en l'air, inoffensif.
var disarmed: bool = false
## Temps (s) écoulé depuis son passage en alerte.
var alert_age: float = 0.0
## Arme qu'on lui a arrachée, au sol.
var dropped_weapon: Node3D
## Opérateur qui le tient en bouclier humain.
var captor: Commando
## Opérateur qui l'a désarmé (il le regarde).
var _disarmer: Node3D

var _waypoints: Array[Vector3] = []
var _waypoint_index: int = 0
var _pause_left: float = 0.0
var _target: Unit
var _last_seen: Vector3
var _memory_left: float = 0.0
var _chase_arrived: bool = false
var _fire_cooldown: float = 0.0
var _stun_left: float = 0.0
var _shove_left: float = 0.0
var _shove_target: Commando
## Coup au corps à corps en cours (temps restant, cible, impact joué).
var _attack_left: float = 0.0
var _attack_target: Unit
var _attack_landed: bool = false
var _melee_cooldown: float = 0.0
var _off_balance_left: float = 0.0
var _vertical_velocity: float = 0.0
var _wants_to_move: bool = false
var _desired_velocity: Vector3
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
## Suivi de chemin sur terrain inégal (points bloqués, marches basses).
var _walker := PathWalker.new()
## Franchissement d'échelle ou de muret en cours.
var _traversal: LinkTraversal
## Convertible en l'air pris pour cible (aucun opérateur en vue), ou null.
var _aircraft: Tiltrotor
var _aircraft_check_left: float = 0.0
## Lance-roquettes : visée en cours (s) et rechargement restant (s).
var _launch_aim: float = 0.0
var _launch_reload: float = 0.0

@onready var _agent: NavigationAgent3D = $NavigationAgent3D
@onready var _model: SoldierModel = $SoldierModel
@onready var _vision: VisionComponent = $VisionComponent
@onready var _hearing: HearingComponent = get_node_or_null(^"HearingComponent")
@onready var _gauge: Node3D = $Gauge
@onready var _gauge_back: MeshInstance3D = $Gauge/Back
@onready var _gauge_fill: MeshInstance3D = $Gauge/Fill
@onready var _mark: Label3D = $Gauge/Mark
@onready var health: HealthComponent = $HealthComponent


func _enter_tree() -> void:
	add_to_group(QuickSave.GROUP)


func _ready() -> void:
	add_to_group(ALL_GROUP)
	health.reset(stats.max_health)
	ammo = stats.ammo
	health.died.connect(_on_died)
	if _hearing == null:
		_hearing = HearingComponent.new()
		_hearing.name = "HearingComponent"
		add_child(_hearing)
	_hearing.heard.connect(_on_heard)
	_model.set_armed(armed)
	_model.set_launcher(launcher)
	if documents:
		add_to_group(DOCUMENTS_GROUP)
		_model.set_documents(true)
	_agent.velocity_computed.connect(_apply_velocity)
	_traversal = LinkTraversal.new(self, _model)
	_agent.link_reached.connect(_on_link_reached)
	# Les ennemis ont les clés : ils passent aussi les portes verrouillées.
	_agent.navigation_layers = Door.NAV_EVERYONE | Door.NAV_ENEMIES
	# La nuit, on voit moins loin (la zone proche ne change pas).
	if LevelRoot.is_night(self) and _vision.config:
		var dark := _vision.config.duplicate() as VisionConfig
		dark.far_range = maxf(dark.near_range, dark.far_range * LevelRoot.NIGHT_SIGHT)
		_vision.config = dark
	if patrol_path and patrol_path.curve:
		for i in patrol_path.curve.point_count:
			_waypoints.append(patrol_path.to_global(patrol_path.curve.get_point_position(i)))
	if not _waypoints.is_empty():
		_agent.target_position = _waypoints[0]
	_home = global_position
	_home_yaw = rotation.y
	_update_feedback()
	if blind:
		_vision.visible = false
		_vision.set_physics_process(false)
		# Mannequin : sourd aussi.
		_hearing.deaf = true


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if state == State.STUNNED:
		# Ligoté sur un plateau : il ne se réveille pas.
		if on_vehicle == null:
			_stun_left -= delta
		if _stun_left <= 0.0:
			_wake_up()
		return
	if state == State.GRABBED:
		velocity = Vector3.ZERO
		_help_left -= delta
		if _help_left <= 0.0:
			_help_left = HELP_INTERVAL
			_cry_for_help()
		return
	if disarmed:
		# Mains en l'air, il ne quitte pas des yeux celui qui l'a désarmé.
		_model.aiming = false
		_model.guard_up = false
		if is_instance_valid(_disarmer):
			_face(_disarmer.global_position - global_position, delta)
			_model.look_target = _disarmer.global_position + Vector3.UP * 1.4
		_apply_velocity(Vector3.ZERO)
		return
	alert_age += delta
	wary_left = maxf(wary_left - delta, 0.0)
	_update_detection(delta)
	_look_for_bodies(delta)
	_update_state()
	if _traversal.update(delta):
		_model.aiming = false
		return
	var guarding := is_guarding()
	_update_aircraft_target(delta)
	_model.aiming = can_fire() and ((state == State.ALERT and _target != null and not guarding) or _aircraft != null)
	# En alerte : en garde entre deux coups sans arme, ou face à une cible
	# toute proche.
	_model.guard_up = state == State.ALERT and (not armed or guarding)
	# Il suit des yeux sa cible, ou regarde vers ce qui l'a intrigué.
	if _aircraft:
		_model.look_target = _aircraft.aim_point()
	elif is_instance_valid(_target):
		_model.look_target = _target.global_position + Vector3.UP * 1.4
	elif state != State.PATROL:
		_model.look_target = _last_seen + Vector3.UP * 1.4
	else:
		_model.look_target = Vector3.INF

	var horizontal := Vector3.ZERO
	_melee_cooldown -= delta
	_off_balance_left = maxf(_off_balance_left - delta, 0.0)
	_model.staggered = _off_balance_left > 0.0
	if _shove_left > 0.0:
		_update_shove(delta)
	elif _attack_left > 0.0:
		_update_attack(delta)
	elif _off_balance_left > 0.0:
		pass
	elif _aircraft:
		_engage_aircraft(delta)
	else:
		match state:
			State.PATROL:
				horizontal = _return(delta) if activity == Activity.RETURN else _patrol(delta)
			State.SUSPICIOUS:
				horizontal = _suspicious(delta)
			State.ALERT:
				horizontal = _alert(delta)
	if stationary:
		horizontal = Vector3.ZERO

	_vertical_velocity = 0.0 if is_on_floor() else velocity.y - _gravity * delta
	_wants_to_move = horizontal != Vector3.ZERO
	_desired_velocity = horizontal
	# Une unité à l'arrêt est prioritaire : ce sont les autres qui la contournent.
	_agent.avoidance_priority = 0.5 if _wants_to_move else 1.0
	if _agent.avoidance_enabled:
		# L'évitement renvoie une vitesse corrigée via `velocity_computed`.
		_agent.velocity = horizontal
	else:
		_apply_velocity(horizontal)


## Entrée d'un lien de navigation : échelle ou muret à franchir.
func _on_link_reached(details: Dictionary) -> void:
	var link := details.get("owner") as TraversalLink
	if link and not is_dead:
		_traversal.begin(link, details["link_entry_position"], details["link_exit_position"])


## Vrai pendant le franchissement d'une échelle ou d'un muret.
func is_traversing() -> bool:
	return _traversal != null and _traversal.active


## Applique la vitesse horizontale (éventuellement corrigée par l'évitement).
func _apply_velocity(horizontal: Vector3) -> void:
	if is_dead or is_traversing():
		return
	# Une unité à l'arrêt ne se laisse pas pousser par l'évitement.
	if not _wants_to_move:
		horizontal = Vector3.ZERO
	elif horizontal.length() < BLOCKED_RATIO * _desired_velocity.length():
		# Freiné presque à l'arrêt par une unité pile en face : pas de côté.
		horizontal += _desired_velocity.cross(Vector3.UP) * SIDESTEP_RATIO
	velocity = Vector3(horizontal.x, _vertical_velocity, horizontal.z)
	var before := global_position
	move_and_slide()
	# Bloqué net (moins de la moitié du pas voulu) : peut-être une marche basse.
	var wanted := horizontal * get_physics_process_delta_time()
	var moved := global_position - before
	var climbed := 0.0
	if Vector2(moved.x, moved.z).length() < 0.5 * Vector2(wanted.x, wanted.z).length():
		climbed = PathWalker.step_up(self, wanted)
	PathWalker.smooth_model(_model, climbed, get_physics_process_delta_time())
	var speed := Vector2(velocity.x, velocity.z).length()
	_model.move_ratio = 2.0 * speed / stats.chase_speed if state == State.ALERT else 0.6 * speed / stats.patrol_speed
	_update_feedback()


## Encaisse un tir venant de `from` : dégâts, puis alerte vers le tireur.
func take_hit(amount: float, from: Vector3) -> void:
	if is_dead:
		return
	health.take_damage(amount)
	Sfx.play_at(&"hit", global_position + Vector3.UP, -4.0)
	if not is_dead:
		_model.play_hit(from)
	# Un soldat inconscient ne réagit pas.
	if is_dead or state == State.STUNNED:
		return
	detection = 1.0
	if _target == null:
		_last_seen = from
		_memory_left = stats.alert_memory
		_chase_arrived = false


## Vrai si l'ennemi est assommé.
func is_stunned() -> bool:
	return state == State.STUNNED


## Vrai si `world_position` est dans son dos.
func is_behind(world_position: Vector3) -> bool:
	var to := world_position - global_position
	to.y = 0.0
	if to.length_squared() < 0.0001:
		return false
	return rad_to_deg((-global_basis.z).angle_to(to)) > BEHIND_ANGLE


## Vrai s'il peut tirer : armé, avec des cartouches.
func can_fire() -> bool:
	return armed and ammo != 0


## Vrai s'il est armé mais à sec.
func is_out_of_ammo() -> bool:
	return armed and ammo == 0


## Vrai s'il a la garde levée : en alerte, sa cible à moins de
## `GUARD_RANGE` devant lui, et libre de ses mouvements (ni coup en cours, ni
## déséquilibre).
func is_guarding() -> bool:
	if is_dead or disarmed or state != State.ALERT or not is_instance_valid(_target) or _target.is_dead:
		return false
	if _attack_left > 0.0 or _shove_left > 0.0 or _off_balance_left > 0.0:
		return false
	var to := _target.global_position - global_position
	to.y = 0.0
	return to.length() <= GUARD_RANGE and rad_to_deg((-global_basis.z).angle_to(to)) < stats.resist_angle


## Vrai s'il repousse un assaillant venant de `from` : en alerte, il le voit
## arriver de face et le coup échoue.
func resists(from: Vector3) -> bool:
	if is_dead or disarmed or state != State.ALERT or _off_balance_left > 0.0:
		return false
	var to := from - global_position
	to.y = 0.0
	if to.length_squared() < 0.0001:
		return true
	return rad_to_deg((-global_basis.z).angle_to(to)) < stats.resist_angle


## Otage (ennemi tenu en bouclier humain) qui couvre la ligne de tir
## `from` → `to`, ou null.
static func hostage_in_the_way(tree: SceneTree, from: Vector3, to: Vector3) -> Enemy:
	for node in tree.get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.captor == null or enemy.is_dead:
			continue
		var chest := enemy.global_position + Vector3.UP * 1.2
		var closest := Geometry3D.get_closest_point_to_segment(chest, from, to)
		if Vector2(closest.x - chest.x, closest.z - chest.z).length() < HOSTAGE_COVER_RADIUS:
			return enemy
	return null


## Vrai s'il est pris de court : pas encore en alerte, en alerte depuis
## moins de `SURPRISE_TIME`, ou déséquilibré.
func is_surprised() -> bool:
	return state != State.ALERT or alert_age < SURPRISE_TIME or _off_balance_left > 0.0


## Vrai s'il porte une arme qu'on peut lui arracher.
func can_be_disarmed() -> bool:
	return armed and not disarmed and not is_dead and state != State.STUNNED


## Arme arrachée par `by` : elle tombe à ses pieds, côté assaillant, et il
## lève les mains. `drop` : poser l'arme au sol.
func disarm(by: Node3D, drop: bool = true) -> void:
	if is_dead or disarmed:
		return
	_traversal.cancel()
	_cancel_melee()
	if drop:
		_drop_weapon(by.global_position if is_instance_valid(by) else global_position)
	armed = false
	disarmed = true
	_disarmer = by
	_model.set_armed(false)
	_model.hands_up = true
	_model.aiming = false
	_model.guard_up = false
	_hide_senses()
	velocity = Vector3.ZERO
	state_changed.emit(state)
	GameState.refresh_alert()


## Désarmé, il ne guette plus : ni cône de vision, ni jauge.
func _hide_senses() -> void:
	_vision.visible = false
	_vision.set_physics_process(false)
	_gauge.visible = false


## Laisse l'arme tenue au sol, entre lui et `toward`.
func _drop_weapon(toward: Vector3) -> void:
	var weapon := _model.weapon_copy(get_parent())
	if weapon == null:
		return
	var side := toward - global_position
	side.y = 0.0
	side = side.normalized() if side.length_squared() > 0.0001 else -global_basis.z
	var spot := global_position + side * DROP_DISTANCE
	# À plat sur le sol, le canon en travers.
	weapon.global_transform = Transform3D(Basis(Vector3.UP, atan2(side.x, side.z)) * Basis(Vector3.FORWARD, PI * 0.5), spot + Vector3.UP * 0.04)
	dropped_weapon = weapon


## Repousse `attacker` (animation de poussée), puis reprend le combat.
func shove(attacker: Commando) -> void:
	if is_dead or disarmed or state == State.STUNNED or state == State.GRABBED:
		return
	_shove_left = stats.shove_time
	_shove_target = attacker
	detection = 1.0
	_last_seen = attacker.global_position
	_memory_left = stats.alert_memory
	_fire_cooldown = maxf(_fire_cooldown, stats.shove_time + 0.2)


func _update_shove(delta: float) -> void:
	_shove_left = maxf(_shove_left - delta, 0.0)
	_model.shove_progress = 1.0 - _shove_left / stats.shove_time
	if is_instance_valid(_shove_target):
		_face(_shove_target.global_position - global_position, delta)
	if _shove_left <= 0.0:
		_model.shove_progress = -1.0
		_shove_target = null


## Vrai pendant qu'il porte un coup au corps à corps.
func is_attacking() -> bool:
	return _attack_left > 0.0


## Autre ennemi déjà au contact de la même cible, ou null.
func _other_attacker() -> Enemy:
	if not is_instance_valid(_target):
		return null
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var other := node as Enemy
		if other == null or other == self or other.is_dead or other.state != State.ALERT or other._target != _target:
			continue
		var gap := other.global_position - _target.global_position
		gap.y = 0.0
		if gap.length() <= other.stats.melee_range + 0.3:
			return other
	return null


## Corps à corps à plusieurs : point où se placer pour frapper la cible de
## flanc, un camarade étant déjà au contact ; `Vector3.INF` sinon (pas de
## cible, cible hors d'atteinte, ou il frappe lui-même déjà de face).
func flank_point() -> Vector3:
	if can_fire() or not is_instance_valid(_target):
		return Vector3.INF
	var other := _other_attacker()
	if other == null:
		return Vector3.INF
	var from_other := other.global_position - _target.global_position
	from_other.y = 0.0
	if from_other.length_squared() < 0.0001:
		return Vector3.INF
	var mine := global_position - _target.global_position
	mine.y = 0.0
	# Du côté où il se trouve déjà.
	var side := 1.0 if from_other.cross(mine).y >= 0.0 else -1.0
	var direction := from_other.normalized().rotated(Vector3.UP, deg_to_rad(FLANK_ANGLE) * side)
	return _target.global_position + direction * stats.melee_range * 0.8


## Vrai pendant le déséquilibre qui suit un coup paré ou esquivé.
func is_off_balance() -> bool:
	return _off_balance_left > 0.0


func _try_melee(to_target: Vector3) -> void:
	# Cible occupée à parer ou esquiver un autre : il en profite aussitôt.
	var opening := _target is Commando and (_target as Commando).is_defending()
	if (_melee_cooldown > 0.0 and not opening) or (-global_basis.z).angle_to(to_target) > 0.5:
		return
	_attack_left = stats.melee_time
	_attack_target = _target
	_attack_landed = false
	_melee_cooldown = stats.melee_time + stats.melee_interval
	_model.strike_with_knife = false
	_model.strike_move = SoldierModel.StrikeMove.BUTT_STRIKE if armed else SoldierModel.StrikeMove.UPPERCUT
	_model.strike_progress = 0.0


func _update_attack(delta: float) -> void:
	_attack_left = maxf(_attack_left - delta, 0.0)
	var progress := 1.0 - _attack_left / stats.melee_time
	_model.strike_progress = progress
	var valid := is_instance_valid(_attack_target) and not _attack_target.is_dead
	if valid:
		_face(_attack_target.global_position - global_position, delta)
	if not _attack_landed and progress >= Commando.STRIKE_HIT_TIME:
		_attack_landed = true
		if valid:
			var offset := _attack_target.global_position - global_position
			offset.y = 0.0
			if offset.length() <= stats.melee_range + Commando.STRIKE_REACH_MARGIN and _attack_target.defend_against(self):
				# Paré ou esquivé : emporté par son élan, il perd l'équilibre.
				_off_balance_left = stats.off_balance_time
	if _attack_left <= 0.0:
		_model.strike_progress = -1.0
		_attack_target = null


## Interrompt une action de corps à corps en cours (poussée, coup, déséquilibre).
func _cancel_melee() -> void:
	_shove_left = 0.0
	_shove_target = null
	_model.shove_progress = -1.0
	_attack_left = 0.0
	_attack_target = null
	_model.strike_progress = -1.0
	_off_balance_left = 0.0
	_model.staggered = false


## Appel à l'aide : les ennemis qui l'entendent accourent.
func _cry_for_help() -> void:
	cries += 1
	var muffled := captor == null
	Sfx.play_at(&"cry", global_position + Vector3.UP * 1.6, -10.0 if muffled else 0.0)
	EventBus.noise_emitted.emit(global_position, HELP_RADIUS_MUFFLED if muffled else HELP_RADIUS, &"help")


## Force en dessous de laquelle un bruit qui intrigue (pas un appât) le
## fait seulement se tourner vers lui.
const FAINT_NOISE := 0.3


## Ouïe (`HearingComponent`) : bruit entendu en `at`. Un bruit d'alerte
## (cri, appel à l'aide, tir, explosion) le fait courir à la source, en
## alerte ; un bruit qui intrigue (pas, lame, coup, appât) le rend méfiant
## et l'envoie voir. Déjà en alerte, il ne répond qu'aux appels à l'aide,
## et seulement s'il n'a pas de cible en vue.
func _on_heard(at: Vector3, type: StringName, reaction: HearingComponent.Reaction, loudness: float) -> void:
	if is_dead or disarmed or state == State.STUNNED or state == State.GRABBED:
		return
	if global_position.distance_to(at) < 0.3:
		return
	last_heard = type
	if state == State.ALERT:
		if type == &"help" and _target == null:
			hear_alarm(at)
		return
	if reaction == HearingComponent.Reaction.ALARM:
		hear_alarm(at)
	else:
		investigate(at, type != &"distraction" and loudness < FAINT_NOISE)


## Bruit suspect en `at` (caillou, pas, lame) : méfiant, il va voir
## (`look_only` : il se tourne seulement vers le bruit), regarde autour de
## lui, puis reprend sa ronde. En alerte, il n'en tient pas compte.
func investigate(at: Vector3, look_only: bool = false) -> void:
	if state == State.ALERT:
		return
	# En pleine fouille, un bruit net la déplace là où il vient.
	if activity == Activity.SEARCH:
		if not look_only:
			_begin_search(at)
		return
	detection = maxf(detection, stats.suspicion_threshold + 0.15)
	_last_seen = at
	# Un bruit faible n'annule pas une enquête déjà en route.
	if not (look_only and activity == Activity.INVESTIGATE and not _look_only):
		_look_only = look_only
	activity = Activity.INVESTIGATE
	_look_left = INVESTIGATE_LOOK_TIME
	if not _look_only:
		_agent.target_position = at
	_update_state()
	_update_feedback()


## Méfiant : il regarde vers ce qui l'a intrigué ; s'il enquête sur un
## bruit, il s'y rend d'abord au pas.
func _suspicious(delta: float) -> Vector3:
	if activity == Activity.SEARCH:
		return _search(delta)
	if activity != Activity.INVESTIGATE:
		_face(_last_seen - global_position, delta)
		return Vector3.ZERO
	if _agent.target_position.distance_to(_last_seen) > 0.3:
		_agent.target_position = _last_seen
	if not stationary and not _look_only and not _agent.is_navigation_finished():
		var to_next := _walker.next_point(_agent, self, get_physics_process_delta_time()) - global_position
		to_next.y = 0.0
		if to_next.length_squared() > 0.0001:
			_face(to_next, delta)
			return to_next.normalized() * stats.patrol_speed
	# Poste fixe, ou bruit faible : il ne s'en va pas, mais se tourne vers le
	# bruit et le surveille.
	if stationary or _look_only:
		_face(_last_seen - global_position, delta)
		_look_left -= delta
		if _look_left <= 0.0:
			activity = Activity.NONE
		return Vector3.ZERO
	# Sur place : il balaie les alentours du regard, puis rentre.
	_look_left -= delta
	rotation.y += delta * 0.9 * sin(_look_left * 1.6)
	if _look_left <= 0.0:
		_begin_return()
	return Vector3.ZERO


## Alerte donnée par un bruit en `at` : il y court.
func hear_alarm(at: Vector3) -> void:
	_last_seen = at
	_memory_left = stats.alert_memory
	_chase_arrived = false
	detection = 1.0
	_update_state()
	_update_feedback()


## Saisi par derrière : immobile, aveugle, il se débat (animation).
func grab() -> void:
	_traversal.cancel()
	if is_dead or state == State.STUNNED or state == State.GRABBED:
		return
	_cancel_melee()
	_help_left = HELP_DELAY
	state = State.GRABBED
	_target = null
	velocity = Vector3.ZERO
	_agent.avoidance_enabled = false
	_model.grabbed = true
	_model.move_ratio = 0.0
	_vision.visible = false
	_vision.set_physics_process(false)
	_gauge.visible = false
	state_changed.emit(state)
	GameState.refresh_alert()


## Relâché avant d'être neutralisé (l'opérateur a été tué) : il donne l'alerte.
func release() -> void:
	if is_dead or state != State.GRABBED:
		return
	_model.grabbed = false
	_agent.avoidance_enabled = true
	_vision.visible = not blind
	_vision.set_physics_process(true)
	state = State.PATROL
	detection = 1.0
	_last_seen = global_position
	_memory_left = stats.alert_memory
	_update_state()
	_update_feedback()
	if disarmed:
		_hide_senses()


## Élimination silencieuse (couteau) : mort immédiate, sans alerte.
## `fall_forward` : il s'effondre vers l'avant (attaqué par derrière).
func kill_silently(fall_forward: bool = false) -> void:
	if is_dead:
		return
	_model.grabbed = false
	_model.death_forward = fall_forward
	health.take_damage(health.health)


## Assomme l'ennemi : il tombe et reste inconscient `duration` secondes
## (`stun_duration` par défaut). Assommer un ennemi déjà inconscient
## prolonge sa perte de connaissance.
func knock_out(fall_forward: bool = false, duration: float = -1.0) -> void:
	_traversal.cancel()
	if is_dead:
		return
	_stun_left = maxf(_stun_left if state == State.STUNNED else 0.0, stats.stun_duration if duration < 0.0 else duration)
	if state == State.STUNNED:
		return
	_model.grabbed = false
	_model.death_forward = fall_forward
	_cancel_melee()
	Sfx.play_at(&"fall", global_position, -2.0)
	state = State.STUNNED
	detection = 0.0
	_target = null
	velocity = Vector3.ZERO
	collision_layer = LAYER_DOWN
	_agent.avoidance_enabled = false
	_model.is_dead = true
	_model.move_ratio = 0.0
	_vision.visible = false
	_vision.set_physics_process(false)
	_update_feedback()
	state_changed.emit(state)
	GameState.refresh_alert()


## Fin de la perte de connaissance : il se relève et donne l'alerte sur place.
func _wake_up() -> void:
	if carrier:
		carrier.drop_body()
	_model.position.y = 0.0
	collision_layer = LAYER_ACTIVE
	_agent.avoidance_enabled = true
	_model.is_dead = false
	_vision.visible = not blind
	_vision.set_physics_process(true)
	state = State.PATROL
	detection = 1.0
	_last_seen = global_position
	_memory_left = stats.alert_memory
	_update_state()
	_update_feedback()
	if disarmed:
		_hide_senses()


func _on_died() -> void:
	is_dead = true
	activity = Activity.NONE
	_traversal.cancel()
	Sfx.play_at(&"fall", global_position, -2.0)
	_cancel_melee()
	state = State.PATROL
	detection = 0.0
	velocity = Vector3.ZERO
	remove_from_group(&"enemies")
	collision_layer = 0
	_agent.avoidance_enabled = false
	_model.is_dead = true
	_model.move_ratio = 0.0
	_vision.visible = false
	_vision.set_physics_process(false)
	_gauge.visible = false
	EventBus.enemy_killed.emit(self)
	GameState.refresh_alert()


func _update_detection(delta: float) -> void:
	if blind:
		_target = null
		return
	var best_zone := VisionComponent.Zone.NONE
	var best_distance := INF
	_target = null
	for unit in Unit.targets(get_tree()):
		var zone := _vision.check(unit, state == State.ALERT)
		# Passager du Sabre (opérateur ou VIP), la nuit : phares éteints ou
		# allumés.
		var ride := unit.get(&"riding") as Sabre
		if ride:
			zone = ride.sight_zone(zone, _vision)
		if zone == VisionComponent.Zone.NONE:
			continue
		var distance := global_position.distance_to(unit.global_position)
		if distance < best_distance:
			best_distance = distance
			best_zone = zone
			_target = unit

	if _target:
		_last_seen = _target.global_position
		_memory_left = stats.alert_memory
		# Opérateur fondu dans la foule (tenue civile) : repéré plus lentement,
		# même de près ; dans la tenue de l'occasion et à distance, il
		# n'attire pas l'attention (pas même la méfiance). Une fois l'alerte
		# donnée, plus de faux-semblant.
		var blend := 1.0
		if state != State.ALERT and _target.has_method(&"blend_factor"):
			blend = _target.blend_factor()
		if best_zone == VisionComponent.Zone.NEAR and blend >= 1.0:
			detection = 1.0
		else:
			var config := _vision.config
			# Au-delà de la portée (phares d'un véhicule, la nuit) : au plus lent.
			var closeness := 1.0 if best_zone == VisionComponent.Zone.NEAR else clampf(1.0 - inverse_lerp(config.near_range, config.far_range, best_distance), 0.0, 1.0)
			var gain := delta / stats.detection_time * lerpf(0.6, 1.6, closeness) * blend
			if wary_left > 0.0:
				gain *= WARY_GAIN
			if blend <= Commando.BLEND_MATCH and best_zone != VisionComponent.Zone.NEAR:
				detection = maxf(detection, minf(detection + gain, stats.suspicion_threshold * 0.8))
			else:
				detection += gain
	elif state == State.ALERT:
		# Le compte à rebours ne démarre qu'une fois le dernier point connu atteint.
		if _chase_arrived:
			_memory_left -= delta
			if _memory_left <= 0.0:
				# Cible perdue pour de bon : il fouille les environs.
				_begin_search(_last_seen)
	else:
		detection -= delta / stats.forget_time
		# Tant qu'il enquête ou fouille, il reste méfiant.
		if activity == Activity.INVESTIGATE or activity == Activity.SEARCH:
			detection = maxf(detection, stats.suspicion_threshold)
	detection = clampf(detection, 0.0, 1.0)


func _update_state() -> void:
	var new_state := State.PATROL
	if detection >= 1.0:
		new_state = State.ALERT
	elif state == State.ALERT and detection > 0.0 and activity != Activity.SEARCH:
		new_state = State.ALERT
	elif activity == Activity.SEARCH or detection >= stats.suspicion_threshold or (state == State.SUSPICIOUS and detection > 0.0):
		new_state = State.SUSPICIOUS
	if new_state == state:
		return
	var previous := state
	state = new_state
	# Signal sonore : alerte, ou méfiance naissante.
	if state == State.ALERT:
		Sfx.play_at(&"alert", global_position + Vector3.UP * 2.0)
	elif state == State.SUSPICIOUS and previous == State.PATROL:
		Sfx.play_at(&"suspicious", global_position + Vector3.UP * 2.0, -4.0)
	# L'alerte interrompt tout ; le calme revenu, seul le retour continue.
	if state == State.ALERT or (state == State.PATROL and activity != Activity.RETURN):
		activity = Activity.NONE
	if state == State.ALERT:
		alert_age = 0.0
		_fire_cooldown = stats.aim_time
		_chase_arrived = false
		if _target:
			EventBus.unit_spotted.emit(_target, self)
	elif state == State.PATROL and activity == Activity.RETURN:
		_agent.target_position = _return_goal()
	elif state == State.PATROL and not _waypoints.is_empty():
		_agent.target_position = _waypoints[_waypoint_index]
	state_changed.emit(state)
	GameState.refresh_alert()


## Vrai pour un corps : mort, ou assommé au sol.
func is_body() -> bool:
	return is_dead or state == State.STUNNED


## Vrai si ce corps échappe aux regards : porté, dans une cachette (buisson,
## eau, abri) ou sous un toit.
func is_hidden_body() -> bool:
	if carrier != null or on_vehicle != null:
		return true
	if HidingSpot.at(get_tree(), body_center()) != null:
		return true
	for roof in get_tree().get_nodes_in_group(&"roofs"):
		if roof is Roof and (roof as Roof).covers(global_position + Vector3.UP * 0.3):
			return true
	if Tiltrotor.cabin_at(get_tree(), global_position + Vector3.UP * 0.3) != null:
		return true
	return Building.at(get_tree(), global_position + Vector3.UP * 0.3) != null \
		or Tower.at(get_tree(), global_position + Vector3.UP * 0.3) != null


## Milieu du corps couché : son bassin, au sol.
func body_center() -> Vector3:
	var hips := _model.hips_node().global_position
	return Vector3(hips.x, global_position.y, hips.z)


## Bassin du corps étendu dans son propre repère.
func body_hips_local() -> Vector3:
	return to_local(_model.hips_node().global_position)


## Direction horizontale (repère du corps) du bassin vers la tête.
func body_axis_local() -> Vector3:
	var axis := to_local(_model.head_node().global_position) - body_hips_local()
	axis.y = 0.0
	return axis.normalized() if axis.length() > 0.01 else Vector3.BACK


## Cherche dans son champ de vision un corps visible pas encore découvert : il
## donne l'alarme (`discover_body`).
func _look_for_bodies(delta: float) -> void:
	if blind:
		return
	_body_check_left -= delta
	if _body_check_left > 0.0:
		return
	_body_check_left = BODY_CHECK_INTERVAL
	for node in get_tree().get_nodes_in_group(ALL_GROUP):
		var body := node as Enemy
		if body == null or body == self or body.discovered or not body.is_body() or body.is_hidden_body():
			continue
		if _vision.sees_point(body.body_center() + Vector3.UP * 0.25):
			discover_body(body)
			return


## Corps découvert : il crie (les ennemis proches accourent) et va voir.
func discover_body(body: Enemy) -> void:
	body.discovered = true
	EventBus.body_discovered.emit(body, self)
	EventBus.noise_emitted.emit(global_position, BODY_ALARM_RADIUS, &"help")
	hear_alarm(body.body_center())


## Pris sur l'épaule de `by` : plus de collision, il suit le porteur. Sa
## pose étendue est relevée (`measure`), sauf au chargement d'une sauvegarde.
func carry(by: Commando, measure: bool = true) -> void:
	if measure:
		carried_hips = body_hips_local()
		carried_axis = body_axis_local()
	carrier = by
	_traversal.cancel()
	velocity = Vector3.ZERO
	collision_layer = 0


## Déposé au sol, le bassin en `hips_at`, la tête vers `head_dir` ; dans
## l'eau, il s'y enfonce.
func put_down(hips_at: Vector3, head_dir: Vector3, hips: Vector3, axis: Vector3) -> void:
	carrier = null
	var yaw := atan2(head_dir.x, head_dir.z) - atan2(axis.x, axis.z)
	var basis := Basis(Vector3.UP, yaw)
	var origin := hips_at - basis * Vector3(hips.x, 0.0, hips.z)
	origin.y = hips_at.y
	global_transform = Transform3D(basis, origin)
	collision_layer = LAYER_DOWN if state == State.STUNNED and not is_dead else 0
	var spot := HidingSpot.at(get_tree(), body_center())
	_model.position.y = -HidingSpot.WATER_SINK if spot and spot.kind == HidingSpot.Kind.WATER else 0.0


## Donne une ronde (points parcourus en boucle) à un ennemi déjà en place,
## par exemple une sentinelle des cartes UFO:AI : il cesse d'être fixe.
func set_patrol(points: Array[Vector3]) -> void:
	_waypoints = points.duplicate()
	_waypoint_index = 0
	_pause_left = 0.0
	stationary = false
	if not _waypoints.is_empty() and state == State.PATROL:
		_agent.target_position = _waypoints[0]


## Points de la ronde (vide pour un ennemi fixe).
func patrol_points() -> Array[Vector3]:
	return _waypoints


## Cible perdue (ou bruit entendu en pleine fouille) : il fouille autour de
## `center`, méfiant : d'abord `center`, puis d'autres points au hasard,
## en regardant autour de chacun. Il sera plus vigilant ensuite.
func _begin_search(center: Vector3) -> void:
	activity = Activity.SEARCH
	wary_left = WARY_TIME
	_last_seen = center
	_search_points = search_points(center)
	_search_index = 0
	_look_left = SEARCH_LOOK_TIME
	_chase_arrived = false
	detection = stats.suspicion_threshold + 0.1
	if not stationary:
		_agent.target_position = _search_points[0]
	_update_state()
	_update_feedback()


## Points d'une fouille autour de `center`, sur le maillage de navigation.
func search_points(center: Vector3) -> Array[Vector3]:
	var points: Array[Vector3] = [center]
	var map := _agent.get_navigation_map()
	var nav_ready := map.is_valid() and NavigationServer3D.map_get_iteration_id(map) > 0
	for i in SEARCH_POINTS - 1:
		# Directions réparties autour du centre, distances au hasard.
		var angle := TAU * (float(i) + randf() * 0.6) / float(SEARCH_POINTS - 1)
		var spot := center + Vector3(sin(angle), 0.0, cos(angle)) * randf_range(SEARCH_RADIUS * 0.4, SEARCH_RADIUS)
		if nav_ready:
			spot = NavigationServer3D.map_get_closest_point(map, spot)
		points.append(spot)
	return points


## Fouille : il va (d'un bon pas) à chaque point et y regarde autour de lui,
## puis rentre. Un garde fixe fouille du regard, sur place.
func _search(delta: float) -> Vector3:
	if _search_index >= _search_points.size():
		_begin_return()
		return Vector3.ZERO
	var spot := _search_points[_search_index]
	if not stationary and not _agent.is_navigation_finished() \
			and Vector2(spot.x - global_position.x, spot.z - global_position.z).length() > 0.6:
		var to_next := _walker.next_point(_agent, self, get_physics_process_delta_time()) - global_position
		to_next.y = 0.0
		if to_next.length_squared() > 0.0001:
			_face(to_next, delta)
			return to_next.normalized() * stats.patrol_speed * SEARCH_SPEED
	# Sur place : regard qui balaie les alentours, puis point suivant.
	if stationary:
		_face(spot - global_position, delta)
	else:
		rotation.y += delta * 1.1 * sin(_look_left * 2.2)
	_look_left -= delta
	if _look_left <= 0.0:
		_search_index += 1
		_look_left = SEARCH_LOOK_TIME
		if _search_index < _search_points.size() and not stationary:
			_agent.target_position = _search_points[_search_index]
	return Vector3.ZERO


## Fouille finie : il rentre, au calme (mais vigilant).
func _begin_return() -> void:
	activity = Activity.RETURN
	_search_points.clear()
	detection = 0.0
	_update_state()
	_agent.target_position = _return_goal()
	_update_feedback()


## Où il rentre : le point de sa ronde le plus proche (il la reprend de
## là), ou son poste.
func _return_goal() -> Vector3:
	if _waypoints.is_empty():
		return _home
	var best := 0
	for i in _waypoints.size():
		if _waypoints[i].distance_squared_to(global_position) < _waypoints[best].distance_squared_to(global_position):
			best = i
	_waypoint_index = best
	return _waypoints[best]


## Retour : il marche jusqu'à sa ronde (qu'il reprend) ou à son poste (où
## il reprend son cap).
func _return(delta: float) -> Vector3:
	if stationary:
		_face(Vector3(-sin(_home_yaw), 0.0, -cos(_home_yaw)), delta)
		if absf(angle_difference(rotation.y, _home_yaw)) < 0.05:
			activity = Activity.NONE
		return Vector3.ZERO
	if not _agent.is_navigation_finished():
		var to_next := _walker.next_point(_agent, self, get_physics_process_delta_time()) - global_position
		to_next.y = 0.0
		if to_next.length_squared() > 0.0001:
			_face(to_next, delta)
			return to_next.normalized() * stats.patrol_speed
	if _waypoints.is_empty():
		# À son poste : il reprend son cap.
		_face(Vector3(-sin(_home_yaw), 0.0, -cos(_home_yaw)), delta)
		if absf(angle_difference(rotation.y, _home_yaw)) < 0.05:
			activity = Activity.NONE
		return Vector3.ZERO
	activity = Activity.NONE
	_pause_left = 0.0
	_agent.target_position = _waypoints[_waypoint_index]
	return Vector3.ZERO


func _patrol(delta: float) -> Vector3:
	if _waypoints.is_empty():
		return Vector3.ZERO
	if _pause_left > 0.0:
		_pause_left -= delta
		if _pause_left <= 0.0:
			_waypoint_index = (_waypoint_index + 1) % _waypoints.size()
			_agent.target_position = _waypoints[_waypoint_index]
		return Vector3.ZERO
	if _agent.is_navigation_finished():
		_pause_left = maxf(stats.patrol_pause, 0.01)
		return Vector3.ZERO
	var to_next := _walker.next_point(_agent, self, get_physics_process_delta_time()) - global_position
	to_next.y = 0.0
	if to_next.length_squared() < 0.0001:
		return Vector3.ZERO
	_face(to_next, delta)
	return to_next.normalized() * stats.patrol_speed


## Comportement en alerte : tirer si la cible est visible, sinon la traquer.
func _alert(delta: float) -> Vector3:
	var to_target := _last_seen - global_position
	to_target.y = 0.0
	if _target:
		_chase_arrived = false
		_face(to_target, delta)
		# Cible perchée (caisse, mur, toit) : hors d'atteinte des coups.
		var perched := absf(_last_seen.y - global_position.y) > MELEE_MAX_HEIGHT
		if to_target.length() <= stats.melee_range and not perched:
			# Au contact : il frappe au lieu de tirer.
			_try_melee(to_target)
			return Vector3.ZERO
		# Garde levée, il ne tire pas : il avance pour frapper.
		var guarding := is_guarding() and not perched
		if not guarding:
			_try_fire(delta, to_target)
		# Sans arme (ou en garde), il vient au contact. Armé, face à une cible
		# perchée, il tire d'où il est plutôt que de chercher à passer dessous.
		var hold := stats.hold_range if can_fire() and not guarding else stats.melee_range * 0.8
		if can_fire() and perched:
			hold = maxf(hold, stats.fire_range * 0.9)
		if to_target.length() <= hold:
			return Vector3.ZERO
	var goal := _last_seen
	var flank := flank_point()
	if flank != Vector3.INF:
		goal = flank
	if _agent.target_position.distance_to(goal) > 0.5:
		_agent.target_position = goal
	if _agent.is_navigation_finished():
		_chase_arrived = _target == null
		return Vector3.ZERO
	var to_next := _walker.next_point(_agent, self, get_physics_process_delta_time()) - global_position
	to_next.y = 0.0
	if to_next.length_squared() < 0.0001:
		return Vector3.ZERO
	if _target == null:
		_face(to_next, delta)
	return to_next.normalized() * stats.chase_speed


func _try_fire(delta: float, to_target: Vector3) -> void:
	if not can_fire():
		return
	_fire_cooldown -= delta
	var distance := to_target.length()
	if _fire_cooldown > 0.0 or distance > stats.fire_range:
		return
	# Ne tire que s'il est à peu près dans l'axe.
	var forward := -global_basis.z
	if distance > 0.01 and forward.angle_to(to_target) > 0.3:
		return
	_fire_cooldown = stats.fire_interval
	if ammo > 0:
		ammo -= 1
		if ammo == 0:
			# À sec : déclic à vide, puis il charge au corps à corps.
			get_tree().create_timer(stats.fire_interval * 0.5, false).timeout.connect(func() -> void:
				if is_instance_valid(self) and not is_dead:
					Sfx.play_at(&"clink", global_position + Vector3.UP * 1.3, -6.0))

	var chance := lerpf(stats.hit_chance_near, stats.hit_chance_far, clampf(distance / stats.fire_range, 0.0, 1.0))
	match _target.posture:
		SoldierModel.Posture.CROUCHED:
			chance *= 0.8
		SoldierModel.Posture.PRONE:
			chance *= 0.6
	var muzzle := global_position + Vector3.UP * 1.3 + forward * 0.7
	var aim := _target.global_position + Vector3.UP * (0.3 if _target.posture == SoldierModel.Posture.PRONE else 1.0)
	if hostage_in_the_way(get_tree(), muzzle, aim) != null:
		# Un camarade en bouclier humain : il ne tire pas.
		hesitations += 1
		return
	var hit := randf() < chance
	var scene := get_tree().current_scene as Node3D
	if not hit:
		var side := global_basis.x * (0.5 + randf() * 0.5) * (1.0 if randf() < 0.5 else -1.0)
		aim = ShotImpact.land(scene, muzzle, aim + side, [get_rid(), _target.get_rid()] as Array[RID])
	# Un bouclier levé sur la trajectoire arrête la balle.
	var stop := Commando.shield_in_the_way(get_tree(), muzzle, aim)
	Tracer.spawn(scene, muzzle, aim if stop == Vector3.INF else stop)
	_model.play_shot()
	Sfx.play_at(&"shot", muzzle)
	EventBus.noise_emitted.emit(global_position, stats.gunshot_noise_radius, &"gunshot")
	if stop != Vector3.INF:
		Sfx.play_at(&"ricochet", stop, -2.0)
		ShotImpact.spark(scene, stop, muzzle)
		shots_blocked += 1
	elif hit and _target.get(&"riding") == null \
			and Sabre.blocks_shot(get_tree(), muzzle, aim, stats.fire_damage) != null:
		# Abrité derrière un Sabre : la caisse prend la balle.
		Sfx.play_at(&"ricochet", aim, -2.0)
		ShotImpact.spark(scene, aim, muzzle)
		shots_blocked += 1
	elif hit and _target.get(&"riding") != null \
			and (_target.get(&"riding") as Sabre).shields_rider(stats.fire_damage, muzzle):
		# Passager du Sabre : la carrosserie a pris la balle.
		Sfx.play_at(&"ricochet", aim, -2.0)
		ShotImpact.spark(scene, aim, muzzle)
		shots_blocked += 1
	elif hit:
		ShotImpact.hit(scene, _target, aim, muzzle, stats.fire_damage, true)
		_target.health.take_damage(stats.fire_damage)


## Cherche un convertible en l'air à abattre : seulement armé, sans
## opérateur en vue, à portée et en vue directe.
func _update_aircraft_target(delta: float) -> void:
	if _aircraft and (not is_instance_valid(_aircraft) or not _aircraft.is_in_air() or _aircraft.is_disabled):
		_aircraft = null
	_aircraft_check_left -= delta
	if _aircraft_check_left > 0.0:
		return
	_aircraft_check_left = AIR_CHECK_INTERVAL
	var previous := _aircraft
	_aircraft = null
	var anti_air := has_rockets()
	if not anti_air and (not can_fire() or _target != null):
		_launch_aim = 0.0
		return
	var eye := global_position + Vector3.UP * 1.5
	var reach := LAUNCHER_RANGE if anti_air else stats.fire_range * AIR_RANGE_SHARE
	for node in get_tree().get_nodes_in_group(Tiltrotor.GROUP):
		var aircraft := node as Tiltrotor
		if aircraft and aircraft.is_in_air() and not aircraft.is_disabled and aircraft.exposed_to(eye, reach):
			_aircraft = aircraft
			if aircraft != previous:
				_launch_aim = 0.0
			return
	_launch_aim = 0.0


## Donne ou retire les documents (sacoche visible).
func set_documents(carried: bool) -> void:
	documents = carried
	_model.set_documents(carried)
	if carried:
		add_to_group(DOCUMENTS_GROUP)
	elif is_in_group(DOCUMENTS_GROUP):
		remove_from_group(DOCUMENTS_GROUP)


## Vrai s'il porte un lance-roquettes chargé et peut s'en servir.
func has_rockets() -> bool:
	return launcher and rockets > 0 and armed and not disarmed and not is_dead


## Tire sur le convertible pris pour cible, sur place.
func _engage_aircraft(delta: float) -> void:
	var target := _aircraft.aim_point()
	var to_target := target - global_position
	to_target.y = 0.0
	_face(to_target, delta)
	if has_rockets():
		_launch_rocket(delta, target, to_target)
		return
	_fire_cooldown -= delta
	if _fire_cooldown > 0.0 or not can_fire():
		return
	var forward := -global_basis.z
	if to_target.length() > 0.5 and forward.angle_to(to_target) > 0.3:
		return
	_fire_cooldown = stats.fire_interval
	if ammo > 0:
		ammo -= 1
	var muzzle := global_position + Vector3.UP * 1.3 + forward * 0.7
	var reach := stats.fire_range * AIR_RANGE_SHARE
	var chance := lerpf(stats.hit_chance_near, stats.hit_chance_far, clampf(muzzle.distance_to(target) / reach, 0.0, 1.0)) + AIR_HIT_BONUS
	var scene := get_tree().current_scene as Node3D
	if scene == null:
		scene = get_parent() as Node3D
	var spread := Vector3(randf_range(-1.2, 1.2), randf_range(-0.6, 0.8), randf_range(-1.2, 1.2))
	if randf() < chance:
		var query := PhysicsRayQueryParameters3D.create(muzzle, target + spread, Tiltrotor.LAYER_OCCLUDERS, [get_rid()])
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		var at: Vector3 = hit.get("position", target)
		Tracer.spawn(scene, muzzle, at)
		_aircraft.take_hit(stats.fire_damage, at, muzzle)
	else:
		# Balle qui passe à côté, vers le ciel.
		var miss := target + spread * 3.0 + Vector3.UP * 2.0
		Tracer.spawn(scene, muzzle, muzzle + (miss - muzzle) * 1.6)
	_model.play_shot()
	Sfx.play_at(&"shot", muzzle)
	EventBus.noise_emitted.emit(global_position, stats.gunshot_noise_radius, &"gunshot")


## Lance-roquettes : visée (`LAUNCHER_AIM`), puis une roquette vers
## l'appareil, avec un écart ; rechargement entre deux.
func _launch_rocket(delta: float, target: Vector3, to_target: Vector3) -> void:
	_launch_reload = maxf(_launch_reload - delta, 0.0)
	var forward := -global_basis.z
	if to_target.length() > 0.5 and forward.angle_to(to_target) > 0.3:
		return
	_launch_aim += delta
	if _launch_aim < LAUNCHER_AIM or _launch_reload > 0.0:
		return
	_launch_aim = 0.0
	_launch_reload = LAUNCHER_RELOAD
	rockets -= 1
	var muzzle := global_position + Vector3.UP * 1.55 + forward * 0.5
	var scatter := Vector3(randf_range(-1.0, 1.0), randf_range(-0.5, 0.5), randf_range(-1.0, 1.0)) * LAUNCHER_SPREAD
	var scene := get_tree().current_scene as Node3D
	if scene == null:
		scene = get_parent() as Node3D
	Rocket.launch(scene, muzzle, target + scatter, [get_rid()])
	EventBus.noise_emitted.emit(global_position, stats.gunshot_noise_radius * 1.5, &"gunshot")
	if rockets <= 0:
		_model.set_launcher(false)


func _face(direction: Vector3, delta: float) -> void:
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return
	var target_yaw := atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-stats.turn_speed * delta))


func _update_feedback() -> void:
	if state == State.STUNNED:
		_gauge.visible = true
		_gauge.position.y = GAUGE_HEIGHT_DOWN
		_gauge_back.visible = false
		_gauge_fill.visible = false
		_mark.text = "z z"
		_mark.modulate = Color(0.6, 0.8, 1.0)
		return
	_gauge.position.y = GAUGE_HEIGHT
	_gauge_back.visible = true
	_gauge_fill.visible = true
	var color := _vision.calm_color
	if state == State.ALERT:
		color = _vision.alert_color
	elif state == State.SUSPICIOUS:
		color = _vision.suspicious_color
	_vision.set_cone_color(color)
	_gauge.visible = detection > 0.0
	_gauge_fill.scale.x = maxf(detection, 0.001)
	var material := _gauge_fill.material_override as StandardMaterial3D
	material.albedo_color = _vision.suspicious_color.lerp(_vision.alert_color, detection)
	_mark.text = "!" if state == State.ALERT else "?"
	_mark.modulate = color


## Sauvegarde rapide (`QuickSave`) : place, état (patrouille, alerte,
## inconscient…), détection, mémoire de la cible et vie.
func save_state() -> Dictionary:
	return {
		"position": global_position, "rotation": rotation.y, "state": state,
		"detection": detection, "waypoint": _waypoint_index, "stun_left": _stun_left, "ammo": ammo,
		"disarmed": disarmed,
		"last_seen": _last_seen, "memory_left": _memory_left, "health": health.save_state(),
		"discovered": discovered, "carried_hips": carried_hips, "carried_axis": carried_axis,
		"rockets": rockets, "documents": documents,
		"activity": activity, "look_only": _look_only, "look_left": _look_left,
		"wary_left": wary_left, "search_points": _search_points.duplicate(), "search_index": _search_index,
	}


## Rend l'état `data` : l'ennemi est replacé immobile, sans action en cours.
func load_state(data: Dictionary) -> void:
	_traversal.cancel()
	rockets = data.get("rockets", rockets)
	set_documents(data.get("documents", documents))
	_model.set_launcher(launcher and rockets > 0)
	_cancel_melee()
	velocity = Vector3.ZERO
	# Porté ou non : c'est le porteur qui le reprend (`Commando.load_state`).
	carrier = null
	_model.position.y = 0.0
	discovered = data.get("discovered", false)
	carried_hips = data.get("carried_hips", carried_hips)
	carried_axis = data.get("carried_axis", carried_axis)
	global_position = data.get("position", global_position)
	rotation = Vector3(0.0, data.get("rotation", rotation.y), 0.0)
	health.load_state(data.get("health", {}))
	if is_dead:
		return
	_waypoint_index = clampi(data.get("waypoint", _waypoint_index), 0, maxi(_waypoints.size() - 1, 0))
	ammo = data.get("ammo", ammo)
	_load_disarmed(data.get("disarmed", false))
	captor = null
	var saved: State = data.get("state", state)
	if saved == State.STUNNED:
		knock_out()
		_stun_left = data.get("stun_left", _stun_left)
		return
	if saved == State.GRABBED:
		saved = State.ALERT
	if state == State.STUNNED:
		_wake_up()
	state = saved
	_target = null
	detection = data.get("detection", detection)
	_last_seen = data.get("last_seen", _last_seen)
	_memory_left = data.get("memory_left", _memory_left)
	activity = data.get("activity", Activity.NONE)
	_look_only = data.get("look_only", false)
	_look_left = data.get("look_left", 0.0)
	wary_left = data.get("wary_left", 0.0)
	_search_points.assign(data.get("search_points", []))
	_search_index = data.get("search_index", 0)
	if activity == Activity.INVESTIGATE and not _look_only:
		_agent.target_position = _last_seen
	elif activity == Activity.SEARCH and _search_index < _search_points.size():
		_agent.target_position = _search_points[_search_index]
	elif activity == Activity.RETURN:
		_agent.target_position = _return_goal()
	_update_feedback()
	state_changed.emit(state)


## Rend l'état désarmé d'une sauvegarde : l'arme au sol disparaît si elle
## n'avait pas encore été arrachée.
func _load_disarmed(value: bool) -> void:
	if value == disarmed:
		return
	if value:
		disarm(null)
		return
	if is_instance_valid(dropped_weapon):
		dropped_weapon.queue_free()
	dropped_weapon = null
	disarmed = false
	armed = true
	_disarmer = null
	_model.hands_up = false
	_model.set_armed(true)
	_vision.visible = not blind
	_vision.set_physics_process(true)
