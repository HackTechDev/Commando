class_name Enemy
extends CharacterBody3D
## Soldat ennemi : perception (vue, ouïe, jauge de détection) et machine à
## états de comportement.
##
## Deux niveaux :
## - la vigilance (`State`) : PATROL (calme), SUSPICIOUS (méfiant), ALERT
##   (cible repérée), STUNNED (assommé), GRABBED (saisi). La jauge de
##   détection la fait monter et descendre (`_update_state`) ;
## - le comportement (`behavior`, un `EnemyBehavior` par état, dans
##   `scripts/enemies/behaviors/`) : ce qu'il fait. La vigilance le choisit
##   (`_sync_behavior`), sauf une activité en cours qui se poursuit
##   (enquête, fouille, retour : `Activity`) :
##   - `EnemyPatrol` (calme) : ronde avec pauses et haltes, ou poste fixe ;
##   - `EnemyWatch` (méfiant) : il s'arrête et regarde vers ce qui l'intrigue ;
##   - `EnemyInvestigate` (méfiant) : il va voir d'où vient un bruit ;
##   - `EnemySearch` (méfiant) : cible perdue, il fouille autour du dernier
##     point connu, puis devient plus vigilant `WARY_TIME` secondes ;
##   - `EnemyReturn` (calme) : il rentre à sa ronde ou à son poste ;
##   - `EnemyChase` (alerte) : il tire, frappe au contact, ou traque la cible ;
##   - `EnemyStunned`, `EnemyGrabbed`, `EnemyDisarmed` : neutralisé (au sol,
##     saisi et appelant à l'aide, ou mains en l'air).
##
## Le tir (`gunner`, `EnemyGunner`), le corps à corps (`brawler`,
## `EnemyBrawler` : coup, poussée, déséquilibre) et le regard (`gaze`,
## `EnemyGaze`) sont des composants communs aux états.

enum State { PATROL, SUSPICIOUS, ALERT, STUNNED, GRABBED }
## Ce qu'il fait, en plus de son état de vigilance (`State`) :
## - INVESTIGATE : il va voir d'où vient un bruit (méfiant) et regarde autour ;
## - SEARCH : cible perdue, il fouille autour du dernier point connu (méfiant) ;
## - RETURN : fouille finie, il rentre à sa ronde ou à son poste (calme).
enum Activity { NONE, INVESTIGATE, SEARCH, RETURN, ERRAND }
## Type d'ennemi : soldat ; officier (en alerte, il rallie les gardes
## voisins ; près de lui, ils repèrent plus vite) ; chien de garde (flaire
## les opérateurs tout autour de lui, aboie en alerte, court et mord).
enum Kind { SOLDIER, OFFICER, DOG }

signal state_changed(state: State)

## Dénivelé (m) au-delà duquel une cible est hors d'atteinte au corps à corps.
const MELEE_MAX_HEIGHT := 0.8

@export var stats: EnemyStats
## Soldat, officier ou chien (`Kind`).
@export var kind: Kind = Kind.SOLDIER
## Chemin de patrouille (points de la courbe), parcouru en boucle.
@export var patrol_path: Path3D
## Porte une arme et tire en alerte. Sans arme, il se contente de regarder.
@export var armed: bool = true
## Ne se déplace jamais, même en alerte (sentinelle, cible d'entraînement).
@export var stationary: bool = false
## Sentinelle : au calme, elle balaie sans cesse du regard de gauche à
## droite (`EnemyGaze`), au lieu de simples coups d'œil.
@export var sweeping: bool = false
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
## Garde avec qui il bavarde (`EnemyChat`, lien posé des deux côtés) : moins
## attentifs tous les deux, mais chacun remarque la disparition de l'autre.
@export var talk_partner: Enemy

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
## Intervalle (s) entre deux regards sur les traces dans la neige.
const TRACK_CHECK_INTERVAL := 0.5
## Intervalle (s) entre deux regards sur les caisses déplacées.
const CRATE_CHECK_INTERVAL := 0.7
## Rayon (m) du cri d'un ennemi qui découvre un corps.
const BODY_ALARM_RADIUS := 12.0
## Chien : flair (m), tout autour de lui, même dans le dos ou au sol ;
## portée de l'aboiement.
const DOG_SCENT := 4.5
const DOG_BARK_RADIUS := 20.0
## Officier : rayon (m) dans lequel il rallie les gardes en alerte, et dans
## lequel sa présence rend les gardes plus vifs (`OFFICER_GAIN`).
const OFFICER_RALLY_RADIUS := 20.0
const OFFICER_PRESENCE := 12.0
const OFFICER_GAIN := 1.25
const GAUGE_HEIGHT := 2.3
const GAUGE_HEIGHT_DOWN := 1.0

var state: State = State.PATROL
var is_dead: bool = false
## Jauge de détection, de 0 (rien vu) à 1 (repéré).
var detection: float = 0.0
## Balles arrêtées par un bouclier.
var shots_blocked: int = 0
## Cris d'appel à l'aide poussés.
var cries: int = 0

## Machine à états : un comportement par état (créés avec l'ennemi), et
## celui en cours.
var patrol_behavior := EnemyPatrol.new(self)
var watch_behavior := EnemyWatch.new(self)
var investigate_behavior := EnemyInvestigate.new(self)
var search_behavior := EnemySearch.new(self)
var return_behavior := EnemyReturn.new(self)
var chase_behavior := EnemyChase.new(self)
var stunned_behavior := EnemyStunned.new(self)
var grabbed_behavior := EnemyGrabbed.new(self)
var disarmed_behavior := EnemyDisarmed.new(self)
var dazed_behavior := EnemyDazed.new(self)
var errand_behavior := EnemyErrand.new(self)
var behavior: EnemyBehavior = patrol_behavior
## Composants : tir, corps à corps, regard.
var gunner := EnemyGunner.new(self)
var brawler := EnemyBrawler.new(self)
var gaze := EnemyGaze.new(self)
var chat := EnemyChat.new(self)
## Garde fixe qui regagne son poste à pied (après une mission, une relève) :
## il marche, malgré `stationary`, jusqu'à y être.
var walking_home: bool = false
## Uniforme pris par un opérateur (`strip_uniform`).
var stripped: bool = false

## Activité en cours (`Activity`), selon le comportement.
var activity: Activity:
	get:
		return behavior.activity()
## Va voir d'où vient un bruit (`_last_seen`), méfiant.
var investigating: bool:
	get:
		return behavior == investigate_behavior
## Dernier bruit entendu (type), pour la mise au point et les tests.
var last_heard: StringName = &""
## Vigilance accrue restante (s), après une fouille.
var wary_left: float = 0.0
## Couverture de sa cible au dernier tir (mise au point, tests).
var last_cover: Cover
## Chargeurs laissés à sa mort (armé, avec des cartouches) : -1 tant qu'il
## n'est pas mort ; ensuite, ce qu'il en reste au sol (0 : tout ramassé).
const DROP_MAGAZINES := 1
var _ammo_drop: SupplyPickup
var _drop_left: int = -1
## Lacet du regard par rapport au corps (rad) : le cône de vision le suit.
var gaze_yaw: float:
	get:
		return gaze.yaw
	set(value):
		gaze.yaw = value
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
var _track_check_left: float = 0.0
var _crate_check_left: float = 0.0
## Heure (`SnowTracks.now`) de la dernière empreinte suivie : il ne réagit
## qu'aux plus récentes.
var _followed_track: float = -1.0
## Tirs retenus parce qu'un otage couvrait la cible.
var hesitations: int = 0
## Cartouches restantes (négatif : sans limite).
var ammo: int = -1
## Désarmé : mains en l'air, inoffensif.
var disarmed: bool = false
## Ligoté (assommé, poignets et chevilles liés) : il ne se réveille plus.
var tied: bool = false
## Assourdi (grenade assourdissante) : temps restant (s), voir `EnemyDazed`.
var dazed_left: float = 0.0
## Temps (s) écoulé depuis son passage en alerte.
var alert_age: float = 0.0
## Arme qu'on lui a arrachée, au sol.
var dropped_weapon: Node3D
## Opérateur qui le tient en bouclier humain.
var captor: Commando
## Opérateur qui l'a désarmé (il le regarde).
var _disarmer: Node3D

## Points de la ronde et point visé.
var _waypoints: Array[Vector3] = []
var _waypoint_index: int = 0
## Cible en vue (la plus proche), dernière position connue, et temps (s)
## avant de l'oublier une fois arrivé là.
var _target: Unit
var _last_seen: Vector3
var _memory_left: float = 0.0
var _vertical_velocity: float = 0.0
var _wants_to_move: bool = false
var _desired_velocity: Vector3
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
## Suivi de chemin sur terrain inégal (points bloqués, marches basses).
var _walker := PathWalker.new()
## Franchissement d'échelle ou de muret en cours.
var _traversal: LinkTraversal
## Vue de jour (réglages d'origine) ; `_vision.config` est réduite la nuit
## et par mauvais temps (`_refresh_sight`).
var _day_vision: VisionConfig
var _sight_factor: float = 1.0
var _sight_check_left: float = 0.0
## Intervalle (s) entre deux mises à jour de la portée (heure qui avance).
const SIGHT_CHECK_INTERVAL := 2.0

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
	if kind == Kind.DOG:
		_become_dog()
	elif kind == Kind.OFFICER:
		_dress_officer()
	health.reset(stats.max_health)
	ammo = stats.ammo
	gunner.setup()
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
	_day_vision = _vision.config
	_refresh_sight()
	if patrol_path and patrol_path.curve:
		for i in patrol_path.curve.point_count:
			_waypoints.append(patrol_path.to_global(patrol_path.curve.get_point_position(i)))
	if not _waypoints.is_empty():
		_agent.target_position = _waypoints[0]
	_home = global_position
	_home_yaw = rotation.y
	gaze.start()
	patrol_behavior.start()
	if talk_partner:
		chat.setup(talk_partner)
	_update_feedback()
	if blind:
		_vision.visible = false
		_vision.set_physics_process(false)
		# Mannequin : sourd aussi.
		_hearing.deaf = true


## Portée de la vue selon l'obscurité (`LevelRoot.darkness_of`) et le
## temps (pluie, neige) : la zone lointaine raccourcit, la proche ne change
## pas.
func _refresh_sight() -> void:
	if _day_vision == null:
		return
	var factor := lerpf(1.0, LevelRoot.NIGHT_SIGHT, LevelRoot.darkness_of(self)) * WeatherParticles.sight_factor_of(get_tree())
	if absf(factor - _sight_factor) < 0.01 and _vision.config != null:
		return
	_sight_factor = factor
	if factor >= 0.999:
		_vision.config = _day_vision
	else:
		var dark := _day_vision.duplicate() as VisionConfig
		dark.far_range = maxf(dark.near_range, dark.far_range * factor)
		_vision.config = dark
	_vision.invalidate()


## Zone où `unit` est vu : de nuit, une lampe allumée (`StreetLamp`) le
## montre d'aussi loin que de jour.
func _sight_zone(unit: Unit) -> VisionComponent.Zone:
	var ignore_posture := state == State.ALERT
	var dark := _vision.config
	if dark == _day_vision or not StreetLamp.lit_at(get_tree(), unit.global_position + Vector3.UP):
		return _vision.check(unit, ignore_posture)
	_vision.config = _day_vision
	var zone := _vision.check(unit, ignore_posture)
	_vision.config = dark
	return zone


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
		chase_behavior.arrived = false


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
	if brawler.is_busy():
		return false
	var to := _target.global_position - global_position
	to.y = 0.0
	return to.length() <= GUARD_RANGE and rad_to_deg((-global_basis.z).angle_to(to)) < stats.resist_angle


## Vrai s'il repousse un assaillant venant de `from` : en alerte, il le voit
## arriver de face et le coup échoue.
func resists(from: Vector3) -> bool:
	if is_dead or disarmed or state != State.ALERT or brawler.off_balance_left > 0.0 or is_dazed():
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
	return state != State.ALERT or alert_age < SURPRISE_TIME or brawler.off_balance_left > 0.0 or is_dazed()


## Vrai s'il est assourdi (grenade assourdissante).
func is_dazed() -> bool:
	return dazed_left > 0.0 and not is_dead


## Assourdi `seconds` secondes par une grenade assourdissante qui a détonné
## en `at` : aveugle, sans tir ni défense (`EnemyDazed`) ; ensuite en alerte
## vers `at`. Sans effet sur un ennemi au sol ou saisi.
func daze(seconds: float, at: Vector3) -> void:
	if is_dead or state == State.STUNNED or state == State.GRABBED:
		return
	_traversal.cancel()
	brawler.cancel()
	gunner.cancel_reload()
	dazed_left = maxf(dazed_left, seconds)
	_last_seen = at
	_target = null
	velocity = Vector3.ZERO
	_sync_behavior()
	_update_feedback()


## Fin de l'assourdissement : en alerte vers la détonation.
func _recover_from_daze() -> void:
	dazed_left = 0.0
	detection = 1.0
	_memory_left = stats.alert_memory
	chase_behavior.arrived = false
	_update_state()
	_sync_behavior()
	_update_feedback()


## Vrai s'il porte une arme qu'on peut lui arracher.
func can_be_disarmed() -> bool:
	return armed and not disarmed and not is_dead and state != State.STUNNED


## Arme arrachée par `by` : elle tombe à ses pieds, côté assaillant, et il
## lève les mains. `drop` : poser l'arme au sol.
func disarm(by: Node3D, drop: bool = true) -> void:
	if is_dead or disarmed:
		return
	_traversal.cancel()
	brawler.cancel()
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
	_sync_behavior()
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


## Alerte donnée par un bruit en `at` : il y court.
func hear_alarm(at: Vector3) -> void:
	_last_seen = at
	_memory_left = stats.alert_memory
	chase_behavior.arrived = false
	detection = 1.0
	_update_state()
	_update_feedback()


## Élimination silencieuse (couteau) : mort immédiate, sans alerte.
## `fall_forward` : il s'effondre vers l'avant (attaqué par derrière).
func kill_silently(fall_forward: bool = false) -> void:
	if is_dead:
		return
	_model.grabbed = false
	_model.death_forward = fall_forward
	health.take_damage(health.health)


func _on_died() -> void:
	is_dead = true
	_drop_ammo()
	_traversal.cancel()
	Sfx.play_at(&"fall", global_position, -2.0)
	brawler.cancel()
	state = State.PATROL
	_set_behavior(patrol_behavior)
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
		var zone := _sight_zone(unit)
		# Passager du Sabre (opérateur ou VIP), la nuit : phares éteints ou
		# allumés.
		var ride := unit.get(&"riding") as Sabre
		if ride:
			zone = ride.sight_zone(zone, _vision)
		# Opérateur à lampe allumée, la nuit : la lumière se voit de loin.
		if zone == VisionComponent.Zone.NONE and unit is Commando:
			zone = (unit as Commando).lamp_sight_zone(_vision)
		# Chien : il flaire ce qui est tout près, de dos ou au sol.
		if zone == VisionComponent.Zone.NONE and kind == Kind.DOG and ride == null \
				and global_position.distance_to(unit.global_position) <= DOG_SCENT \
				and absf(unit.global_position.y - global_position.y) < 1.5:
			zone = VisionComponent.Zone.FAR
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
			# Uniforme volé : l'officier connaît ses hommes, le chien les flaire.
			if kind != Kind.SOLDIER and _target.get(&"disguised") == true:
				blend = 1.0
		if best_zone == VisionComponent.Zone.NEAR and blend >= 1.0:
			detection = 1.0
		else:
			var config := _vision.config
			# Au-delà de la portée (phares d'un véhicule, la nuit) : au plus lent.
			var closeness := 1.0 if best_zone == VisionComponent.Zone.NEAR else clampf(1.0 - inverse_lerp(config.near_range, config.far_range, best_distance), 0.0, 1.0)
			var gain := delta / stats.detection_time * lerpf(0.6, 1.6, closeness) * blend
			if wary_left > 0.0:
				gain *= WARY_GAIN
			if kind != Kind.OFFICER and _officer_near():
				gain *= OFFICER_GAIN
			# En pleine discussion : distrait.
			gain *= chat.gain()
			if blend <= Commando.BLEND_MATCH and best_zone != VisionComponent.Zone.NEAR:
				detection = maxf(detection, minf(detection + gain, stats.suspicion_threshold * 0.8))
			else:
				detection += gain
	elif state == State.ALERT:
		# Le compte à rebours ne démarre qu'une fois le dernier point connu atteint.
		if chase_behavior.arrived:
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


## Vrai pour un corps : mort, ou assommé au sol.
func is_body() -> bool:
	return is_dead or state == State.STUNNED


## Vrai si ce corps échappe aux regards : porté, dans une cachette (buisson,
## eau, abri) ou sous un toit.
func is_hidden_body() -> bool:
	if carrier != null or on_vehicle != null:
		return true
	if HidingSpot.at(get_tree(), body_center()) != null or is_under_crate():
		return true
	for roof in get_tree().get_nodes_in_group(&"roofs"):
		if roof is Roof and (roof as Roof).covers(global_position + Vector3.UP * 0.3):
			return true
	if Tiltrotor.cabin_at(get_tree(), global_position + Vector3.UP * 0.3) != null:
		return true
	return Building.at(get_tree(), global_position + Vector3.UP * 0.3) != null \
		or Tower.at(get_tree(), global_position + Vector3.UP * 0.3) != null \
		or Mantis.at(get_tree(), global_position + Vector3.UP * 0.3) != null


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
	# Un camarade saisi (bouclier humain, prise) sous ses yeux : alerte vers
	# l'assaillant.
	if state == State.ALERT:
		return
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var mate := node as Enemy
		if mate == null or mate == self or mate.is_dead or mate.state != State.GRABBED:
			continue
		if _vision.sees_point(mate.global_position + Vector3.UP * 1.2):
			see_comrade_grabbed(mate)
			return


## Traces de pas fraîches dans la neige (`SnowTracks`) : au calme ou
## méfiant, il va voir la plus récente qu'il voit, et suit ainsi la piste.
func _look_for_tracks(delta: float) -> void:
	if blind or state == State.ALERT:
		return
	_track_check_left -= delta
	if _track_check_left > 0.0:
		return
	_track_check_left = TRACK_CHECK_INTERVAL
	var tracks := SnowTracks.of(get_tree())
	if tracks == null:
		return
	var found := tracks.freshest_seen_by(self, _followed_track)
	if found.is_empty():
		return
	_followed_track = found["time"]
	last_heard = &"tracks"
	investigate(found["at"])


## Vrai si une caisse est posée sur lui (corps glissé dessous, ennemi
## assommé coincé) : on ne le voit pas, il ne se relève pas.
func is_pinned() -> bool:
	return is_inside_tree() and (is_dead or is_stunned()) and Climbable.covering(get_tree(), body_center() + Vector3.UP * 0.2) != null


## Vrai si une caisse couvre le corps entier (bassin et tête) : glissé
## dessous, il échappe aux regards.
func is_under_crate() -> bool:
	if not is_pinned():
		return false
	var head := _model.head_node().global_position
	return Climbable.covering(get_tree(), Vector3(head.x, global_position.y + 0.2, head.z)) != null


## Vrai pour un chien de garde.
func is_dog() -> bool:
	return kind == Kind.DOG


## Chien : soldat caché (il garde ses états), modèle de chien à la place,
## sans arme, plus rapide, plus fragile, le nez au ras du sol.
func _become_dog() -> void:
	armed = false
	launcher = false
	documents = false
	var dog := stats.duplicate() as EnemyStats
	dog.max_health = 45.0
	dog.patrol_speed = 1.8
	dog.chase_speed = 6.4
	dog.melee_range = 1.3
	dog.melee_time = 0.35
	dog.melee_interval = 1.1
	dog.melee_damage = 18.0
	dog.detection_time = 1.2
	dog.ammo = 0
	stats = dog
	_model.visible = false
	add_child(DogModel.new(self))
	if _vision.config:
		var nose := _vision.config.duplicate() as VisionConfig
		nose.eye_height = 0.6
		nose.cone_ray_height = 0.5
		_vision.config = nose


## Officier : bande rouge sur le casque, épaulettes.
func _dress_officer() -> void:
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.62, 0.08, 0.06)
	red.roughness = 0.6
	var band := MeshInstance3D.new()
	band.name = "OfficerBand"
	var ring := CylinderMesh.new()
	ring.top_radius = 0.147
	ring.bottom_radius = 0.152
	ring.height = 0.03
	band.mesh = ring
	band.material_override = red
	band.position = Vector3(0, 0.205, 0)
	_model.head_node().add_child(band)


## Aboiement : tous les gardes à portée accourent.
func bark() -> void:
	Sfx.play_at(&"bark", global_position + Vector3.UP * 0.6)
	EventBus.noise_emitted.emit(global_position, DOG_BARK_RADIUS, &"help")


## Officier en alerte : il donne ses ordres, les gardes à portée passent en
## alerte vers ce qu'il a repéré.
func _rally() -> void:
	Sfx.play_at(&"cry", global_position + Vector3.UP * 1.6, -3.0)
	for node in get_tree().get_nodes_in_group(ALL_GROUP):
		var mate := node as Enemy
		if mate == null or mate == self or mate.is_dead or mate.is_stunned() or mate.state == State.ALERT or mate.tied:
			continue
		if mate.global_position.distance_to(global_position) <= OFFICER_RALLY_RADIUS:
			mate.hear_alarm(_last_seen)


## Un officier vivant et debout est tout près : il est plus vif.
func _officer_near() -> bool:
	for node in get_tree().get_nodes_in_group(ALL_GROUP):
		var officer := node as Enemy
		if officer and officer.kind == Kind.OFFICER and not officer.is_dead and not officer.is_stunned() \
				and officer.global_position.distance_to(global_position) <= OFFICER_PRESENCE:
			return true
	return false


## Il voit `mate` se faire saisir : alerte vers l'assaillant (ou vers le
## camarade, sans assaillant connu), et il crie.
func see_comrade_grabbed(mate: Enemy) -> void:
	var attacker: Node3D = mate.captor
	if attacker == null:
		for node in get_tree().get_nodes_in_group(&"commandos"):
			var unit := node as Commando
			if unit and not unit.is_dead and unit.global_position.distance_to(mate.global_position) < 1.5:
				attacker = unit
				break
	hear_alarm(attacker.global_position if attacker else mate.global_position)
	cries += 1
	Sfx.play_at(&"cry", global_position + Vector3.UP * 1.6, -2.0)
	EventBus.noise_emitted.emit(global_position, BODY_ALARM_RADIUS, &"help")


## Caisse qui n'est plus à sa place (`Climbable.looks_moved`), sous ses
## yeux : au calme ou méfiant, il va voir. Les gardes la savent désormais là.
func _look_for_moved_crates(delta: float) -> void:
	if blind or state == State.ALERT or kind == Kind.DOG:
		return
	_crate_check_left -= delta
	if _crate_check_left > 0.0:
		return
	_crate_check_left = CRATE_CHECK_INTERVAL
	for node in get_tree().get_nodes_in_group(&"climbables"):
		var crate := node as Climbable
		if crate == null or not crate.looks_moved():
			continue
		if _vision.sees_point(crate.global_position + Vector3.UP * (crate.top_height + 0.05)):
			crate.known_transform = crate.global_transform
			last_heard = &"moved_crate"
			investigate(crate.global_position)
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


## Points de la ronde (vide pour un ennemi fixe).
func patrol_points() -> Array[Vector3]:
	return _waypoints


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
		_mark.text = "ligoté" if tied else ("coincé" if is_pinned() else "z z")
		_mark.modulate = Color(0.85, 0.7, 0.45) if tied else Color(0.6, 0.8, 1.0)
		return
	if is_dazed():
		_gauge.visible = true
		_gauge.position.y = GAUGE_HEIGHT
		_gauge_back.visible = false
		_gauge_fill.visible = false
		_mark.text = "sonné"
		_mark.modulate = Color(1.0, 1.0, 0.7)
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
	if state == State.ALERT and gunner.is_reloading():
		# Fenêtre d'action : il recharge, il ne tire pas.
		_mark.text = "recharge"
		_mark.modulate = Color(1.0, 0.85, 0.4)


## Mort, armé et avec des cartouches : il laisse un chargeur à ramasser
## (ou ce qu'il en restait dans la partie sauvegardée).
func _drop_ammo() -> void:
	if _drop_left < 0:
		_drop_left = DROP_MAGAZINES if armed and not disarmed and ammo != 0 else 0
	if _drop_left <= 0 or not is_inside_tree():
		return
	var parent := get_tree().current_scene
	if parent == null:
		return
	var at := global_position + global_basis.x * 0.6
	_ammo_drop = SupplyPickup.drop(parent, at, SupplyPickup.Kind.AMMO, _drop_left)
	_ammo_drop.tree_exited.connect(_on_drop_gone)


func _on_drop_gone() -> void:
	_drop_left = 0


func _saved_drop() -> int:
	if is_instance_valid(_ammo_drop) and _ammo_drop.is_inside_tree():
		return _ammo_drop.amount
	return _drop_left



# --- Machine à états ---------------------------------------------------------

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	# Neutralisé (assommé, saisi, désarmé) : l'état prend toute l'image.
	if behavior.takes_over():
		if gunner.is_reloading():
			gunner.cancel_reload()
		behavior.update(delta)
		return
	gunner.update_reload(delta)
	alert_age += delta
	wary_left = maxf(wary_left - delta, 0.0)
	_sight_check_left -= delta
	if _sight_check_left <= 0.0:
		_sight_check_left = SIGHT_CHECK_INTERVAL
		_refresh_sight()
	_update_detection(delta)
	_look_for_bodies(delta)
	_look_for_tracks(delta)
	_look_for_moved_crates(delta)
	_update_state()
	if _traversal.update(delta):
		_model.aiming = false
		return
	var guarding := is_guarding()
	gunner.update_aircraft_target(delta)
	var aircraft := gunner.aircraft
	_model.aiming = can_fire() and ((state == State.ALERT and _target != null and not guarding) or aircraft != null)
	# En alerte : en garde entre deux coups sans arme, ou face à une cible
	# toute proche.
	_model.guard_up = state == State.ALERT and (not armed or guarding)
	# Il suit des yeux sa cible, ou regarde vers ce qui l'a intrigué.
	if aircraft:
		_model.look_target = aircraft.aim_point()
	elif is_instance_valid(_target):
		_model.look_target = _target.global_position + Vector3.UP * 1.4
	elif state != State.PATROL:
		_model.look_target = _last_seen + Vector3.UP * 1.4
	elif absf(gaze.yaw) > 0.05:
		_model.look_target = global_position + Vector3.UP * 1.6 + global_basis * Vector3(-sin(gaze.yaw), 0.0, -cos(gaze.yaw)) * 6.0
	else:
		_model.look_target = Vector3.INF

	# Corps à corps en cours (poussée, coup, déséquilibre), riposte contre
	# un convertible, sinon le comportement de l'état.
	var horizontal := Vector3.ZERO
	if brawler.update(delta):
		pass
	elif aircraft:
		gunner.engage_aircraft(delta)
	else:
		horizontal = behavior.update(delta)
	# Un garde fixe ne bouge pas, sauf en mission (relève, réparation) et
	# pour regagner son poste ensuite.
	if stationary and behavior != errand_behavior and not (walking_home and behavior == return_behavior):
		horizontal = Vector3.ZERO
	gaze.update(delta, horizontal != Vector3.ZERO)
	chat.update(delta, horizontal != Vector3.ZERO)

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


## Passe au comportement `next` : `exit` de l'ancien, puis `enter`.
func _set_behavior(next: EnemyBehavior) -> void:
	if next == behavior:
		return
	var previous := behavior
	behavior = next
	previous.exit()
	next.enter()


## Comportement propre à la vigilance (`state`), sans activité.
func _base_behavior() -> EnemyBehavior:
	match state:
		State.STUNNED:
			return stunned_behavior
		State.GRABBED:
			return grabbed_behavior
	if dazed_left > 0.0:
		return dazed_behavior
	if disarmed:
		return disarmed_behavior
	match state:
		State.ALERT:
			return chase_behavior
		State.SUSPICIOUS:
			return watch_behavior
	return patrol_behavior


## Comportement voulu par la vigilance. Une activité en cours se poursuit :
## enquête et fouille tant qu'il est méfiant, retour tant qu'il n'est pas en
## alerte (méfiant en route, il s'arrête pour regarder).
func _sync_behavior() -> void:
	var next := _base_behavior()
	if next == watch_behavior and behavior.activity() != Activity.NONE:
		next = behavior
	elif next == patrol_behavior and (behavior == return_behavior or behavior == errand_behavior):
		next = behavior
	_set_behavior(next)


## Activité finie (enquête sur place, retour) : comportement de sa vigilance.
func _end_activity() -> void:
	_set_behavior(_base_behavior())


## Vigilance selon la jauge de détection ; à chaque changement : signal
## sonore, comportement (`_sync_behavior`) et alerte générale.
func _update_state() -> void:
	var searching := behavior == search_behavior
	var new_state := State.PATROL
	if detection >= 1.0:
		new_state = State.ALERT
	elif state == State.ALERT and detection > 0.0 and not searching:
		new_state = State.ALERT
	elif searching or detection >= stats.suspicion_threshold or (state == State.SUSPICIOUS and detection > 0.0):
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
	if state == State.ALERT:
		alert_age = 0.0
		if kind == Kind.DOG:
			bark()
		elif kind == Kind.OFFICER:
			_rally()
	_sync_behavior()
	if state == State.ALERT:
		if _target:
			EventBus.unit_spotted.emit(_target, self)
	elif state == State.PATROL and behavior == return_behavior:
		_agent.target_position = return_behavior.goal()
	elif state == State.PATROL and not _waypoints.is_empty():
		_agent.target_position = _waypoints[_waypoint_index]
	state_changed.emit(state)
	GameState.refresh_alert()


## Pas suivant sur le chemin de navigation : direction horizontale
## (normalisée), vers laquelle il se tourne si `face` ; nulle s'il n'y a
## plus de chemin.
func _path_direction(delta: float, face: bool = true) -> Vector3:
	var to_next := _walker.next_point(_agent, self, get_physics_process_delta_time()) - global_position
	to_next.y = 0.0
	if to_next.length_squared() < 0.0001:
		return Vector3.ZERO
	if face:
		_face(to_next, delta)
	return to_next.normalized()


# --- Transitions -------------------------------------------------------------

## Bruit suspect en `at` (caillou, pas, lame) : méfiant, il va voir
## (`look_only` : il se tourne seulement vers le bruit), regarde autour de
## lui, puis reprend sa ronde. En alerte, il n'en tient pas compte ; en
## pleine fouille, un bruit net la déplace là où il vient.
func investigate(at: Vector3, look_only: bool = false) -> void:
	if state == State.ALERT:
		return
	if behavior == search_behavior:
		if not look_only:
			_begin_search(at)
		return
	detection = maxf(detection, stats.suspicion_threshold + 0.15)
	_last_seen = at
	investigate_behavior.begin(at, look_only, behavior == investigate_behavior)
	_set_behavior(investigate_behavior)
	_update_state()
	_update_feedback()


## Cible perdue (ou bruit entendu en pleine fouille) : il fouille autour de
## `center`, méfiant (`EnemySearch`). Il sera plus vigilant ensuite.
func _begin_search(center: Vector3) -> void:
	wary_left = WARY_TIME
	_last_seen = center
	search_behavior.begin(center)
	_set_behavior(search_behavior)
	chase_behavior.arrived = false
	detection = stats.suspicion_threshold + 0.1
	_update_state()
	_update_feedback()


## Points d'une fouille autour de `center`, sur le maillage de navigation.
func search_points(center: Vector3) -> Array[Vector3]:
	return search_behavior.plan(center)


## Fouille ou enquête finie : il rentre, au calme (mais vigilant).
func _begin_return() -> void:
	_set_behavior(return_behavior)
	detection = 0.0
	_update_state()
	_agent.target_position = return_behavior.goal()
	_update_feedback()


## Mission au calme (`EnemyErrand`) : aller en `at` (même posté), y
## travailler `seconds` s en regardant `look`, puis appeler `done` et
## rentrer, ou rester là (`stay`, nouveau poste). Refusée s'il n'est pas
## calme et libre (alerte, méfiance, neutralisé, autre mission). Renvoie
## vrai si elle est acceptée.
func send_on_errand(at: Vector3, look: Vector3, seconds: float, done: Callable = Callable(), stay: bool = false) -> bool:
	if not can_take_errand():
		return false
	errand_behavior.begin(at, look, seconds, stay, done)
	_set_behavior(errand_behavior)
	_update_feedback()
	return true


## Vrai s'il peut partir en mission : vivant, calme, libre, pas un chien.
func can_take_errand() -> bool:
	return not is_dead and not disarmed and kind != Kind.DOG and state == State.PATROL \
			and behavior != errand_behavior and not behavior.takes_over() and carrier == null and on_vehicle == null


## Vrai s'il est en mission (`send_on_errand`).
func is_on_errand() -> bool:
	return behavior == errand_behavior


## Poste (point et cap) où il revient au calme, sans ronde.
func set_post(at: Vector3, yaw: float) -> void:
	_home = at
	_home_yaw = yaw


func home_position() -> Vector3:
	return _home


## Donne une ronde (points parcourus en boucle) à un ennemi déjà en place,
## par exemple une sentinelle des cartes UFO:AI : il cesse d'être fixe.
func set_patrol(points: Array[Vector3]) -> void:
	_waypoints = points.duplicate()
	_waypoint_index = 0
	patrol_behavior.pause_left = 0.0
	stationary = false
	if not _waypoints.is_empty() and state == State.PATROL:
		_agent.target_position = _waypoints[0]


## Repousse `attacker` (animation de poussée), puis reprend le combat.
func shove(attacker: Commando) -> void:
	if is_dead or disarmed or state == State.STUNNED or state == State.GRABBED:
		return
	brawler.shove(attacker)
	detection = 1.0
	_last_seen = attacker.global_position
	_memory_left = stats.alert_memory
	gunner.cooldown = maxf(gunner.cooldown, stats.shove_time + 0.2)


## Vrai pendant qu'il porte un coup au corps à corps.
func is_attacking() -> bool:
	return brawler.attack_left > 0.0


## Corps à corps à plusieurs : point où se placer pour frapper la cible de
## flanc (`EnemyBrawler.flank_point`), ou `Vector3.INF`.
func flank_point() -> Vector3:
	return brawler.flank_point()


## Vrai pendant le déséquilibre qui suit un coup paré ou esquivé.
func is_off_balance() -> bool:
	return brawler.off_balance_left > 0.0


## Saisi par derrière : immobile, aveugle, il se débat (animation) et
## appelle à l'aide (`EnemyGrabbed`).
func grab() -> void:
	_traversal.cancel()
	if is_dead or state == State.STUNNED or state == State.GRABBED:
		return
	brawler.cancel()
	state = State.GRABBED
	_sync_behavior()
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
	_sync_behavior()
	detection = 1.0
	_last_seen = global_position
	_memory_left = stats.alert_memory
	_update_state()
	_update_feedback()
	if disarmed:
		_hide_senses()


## Assomme l'ennemi : il tombe et reste inconscient `duration` secondes
## (`stun_duration` par défaut, `EnemyStunned`). Assommer un ennemi déjà
## inconscient prolonge sa perte de connaissance.
func knock_out(fall_forward: bool = false, duration: float = -1.0) -> void:
	_traversal.cancel()
	if is_dead:
		return
	var stunned := state == State.STUNNED
	stunned_behavior.left = maxf(stunned_behavior.left if stunned else 0.0, stats.stun_duration if duration < 0.0 else duration)
	if stunned:
		return
	_model.grabbed = false
	_model.death_forward = fall_forward
	brawler.cancel()
	Sfx.play_at(&"fall", global_position, -2.0)
	state = State.STUNNED
	_sync_behavior()
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


## Vrai si `enemy` peut être ligoté : assommé, vivant, pas encore ligoté,
## ni porté.
## Vrai si un opérateur peut lui prendre son uniforme : soldat ou officier
## assommé, pas encore dévêtu, à terre.
static func can_be_stripped(enemy: Enemy) -> bool:
	return is_instance_valid(enemy) and not enemy.is_dead and enemy.is_stunned() and not enemy.stripped \
			and enemy.carrier == null and not enemy.is_dog()


## Lui prend son uniforme (`DisguiseGesture`) : il reste en maillot clair.
## Renvoie les couleurs et le couvre-chef (`Commando.wear_disguise`), vide
## si c'est impossible.
func strip_uniform() -> Dictionary:
	if not can_be_stripped(self):
		return {}
	var look := _model.guard_uniform()
	stripped = true
	_model.strip_uniform()
	return look


static func can_be_tied(enemy: Enemy) -> bool:
	return is_instance_valid(enemy) and not enemy.is_dead and enemy.is_stunned() and not enemy.tied and enemy.carrier == null and not enemy.is_dog()


## Le ligote (`TieGesture`) : il reste inconscient jusqu'à la fin de la
## mission. Renvoie faux si c'est impossible.
func tie_up() -> bool:
	if not can_be_tied(self):
		return false
	tied = true
	Sfx.play_at(&"clink", global_position, -12.0)
	_update_feedback()
	return true


## Fin de la perte de connaissance : il se relève et donne l'alerte sur place.
func _wake_up() -> void:
	if tied:
		return
	if carrier:
		carrier.drop_body()
	_model.position.y = 0.0
	collision_layer = LAYER_ACTIVE
	_agent.avoidance_enabled = true
	_model.is_dead = false
	_vision.visible = not blind
	_vision.set_physics_process(true)
	state = State.PATROL
	_sync_behavior()
	detection = 1.0
	_last_seen = global_position
	_memory_left = stats.alert_memory
	_update_state()
	_update_feedback()
	if disarmed:
		_hide_senses()


# --- Sauvegarde --------------------------------------------------------------

## Sauvegarde rapide (`QuickSave`) : place, état (patrouille, alerte,
## inconscient…), activité, détection, mémoire de la cible et vie.
func save_state() -> Dictionary:
	return {
		"position": global_position, "rotation": rotation.y, "state": state,
		"detection": detection, "waypoint": _waypoint_index, "stun_left": stunned_behavior.left, "ammo": ammo,
		"magazine": gunner.magazine, "reload_left": gunner.reload_left,
		"disarmed": disarmed, "tied": tied, "dazed_left": dazed_left,
		"last_seen": _last_seen, "memory_left": _memory_left, "health": health.save_state(),
		"discovered": discovered, "carried_hips": carried_hips, "carried_axis": carried_axis,
		"rockets": rockets, "documents": documents,
		"rng": GameRng.save(self), "activity": activity, "look_only": investigate_behavior.look_only,
		"look_left": search_behavior.look_left if behavior == search_behavior else investigate_behavior.look_left,
		"drop_left": _saved_drop(), "wary_left": wary_left,
		"search_points": search_behavior.points.duplicate(), "search_index": search_behavior.index,
		"home": _home, "home_yaw": _home_yaw, "stationary": stationary,
		"chat": chat.save_state(), "stripped": stripped,
	}


## Rend l'état `data` : l'ennemi est replacé immobile, sans action en cours.
func load_state(data: Dictionary) -> void:
	_traversal.cancel()
	rockets = data.get("rockets", rockets)
	set_documents(data.get("documents", documents))
	_model.set_launcher(launcher and rockets > 0)
	brawler.cancel()
	velocity = Vector3.ZERO
	# Porté ou non : c'est le porteur qui le reprend (`Commando.load_state`).
	carrier = null
	_model.position.y = 0.0
	discovered = data.get("discovered", false)
	carried_hips = data.get("carried_hips", carried_hips)
	carried_axis = data.get("carried_axis", carried_axis)
	global_position = data.get("position", global_position)
	rotation = Vector3(0.0, data.get("rotation", rotation.y), 0.0)
	_drop_left = data.get("drop_left", _drop_left)
	_home = data.get("home", _home)
	_home_yaw = data.get("home_yaw", _home_yaw)
	stationary = data.get("stationary", stationary)
	chat.load_state(data.get("chat", {}))
	if data.get("stripped", false) and not stripped:
		stripped = true
		_model.strip_uniform()
	health.load_state(data.get("health", {}))
	if is_dead:
		return
	_waypoint_index = clampi(data.get("waypoint", _waypoint_index), 0, maxi(_waypoints.size() - 1, 0))
	ammo = data.get("ammo", ammo)
	gunner.setup()
	gunner.magazine = data.get("magazine", gunner.magazine)
	gunner.reload_left = data.get("reload_left", 0.0)
	_load_disarmed(data.get("disarmed", false))
	captor = null
	var saved: State = data.get("state", state)
	if saved == State.STUNNED:
		knock_out()
		stunned_behavior.left = data.get("stun_left", stunned_behavior.left)
		tied = data.get("tied", false)
		_update_feedback()
		return
	tied = false
	dazed_left = data.get("dazed_left", 0.0)
	if saved == State.GRABBED:
		saved = State.ALERT
	if state == State.STUNNED:
		_wake_up()
	state = saved
	_set_behavior(_base_behavior())
	_target = null
	detection = data.get("detection", detection)
	_last_seen = data.get("last_seen", _last_seen)
	_memory_left = data.get("memory_left", _memory_left)
	GameRng.load(self, data.get("rng"))
	wary_left = data.get("wary_left", 0.0)
	# Activité en cours : ses données, puis le comportement.
	var look_left: float = data.get("look_left", 0.0)
	investigate_behavior.look_only = data.get("look_only", false)
	investigate_behavior.look_left = look_left
	search_behavior.points.assign(data.get("search_points", []))
	search_behavior.index = data.get("search_index", 0)
	search_behavior.look_left = look_left
	if not disarmed:
		match data.get("activity", Activity.NONE):
			Activity.INVESTIGATE:
				_set_behavior(investigate_behavior)
				if not investigate_behavior.look_only:
					_agent.target_position = _last_seen
			Activity.SEARCH:
				_set_behavior(search_behavior)
				if search_behavior.index < search_behavior.points.size():
					_agent.target_position = search_behavior.points[search_behavior.index]
			Activity.RETURN, Activity.ERRAND:
				# Une mission en cours n'est pas reprise : il rentre.
				_set_behavior(return_behavior)
				_agent.target_position = return_behavior.goal()
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
	_sync_behavior()
