class_name GuardRelief
extends Node
## Relève de la garde : toutes les `interval` s (la première à `first_at`
## s), le remplaçant (`relief`) quitte son repos et marche jusqu'au poste
## de la sentinelle (`post`). Il s'arrête devant elle, `HANDOVER_TIME` s,
## puis les deux échangent leur place : le remplaçant prend le poste et son
## cap, la sentinelle relevée va au repos. Les rôles s'inversent pour la
## relève suivante.
##
## Poste vide à son arrivée (sentinelle tuée, assommée, saisie, emportée ou
## partie à plus de `ABSENT_RANGE` m) : le remplaçant devient méfiant et
## fouille les alentours du poste, puis le garde. Plus de relève ensuite.
##
## La radio ennemie, interceptée, annonce la relève `WARNING_TIME` s avant
## (`announce`, `EventBus.radio_message`). Une relève qui ne peut partir
## (remplaçant pas au calme, sentinelle méfiante) est remise de `RETRY_TIME`
## s.

const HANDOVER_TIME := 2.5
const ABSENT_RANGE := 6.0
const WARNING_TIME := 20.0
const RETRY_TIME := 10.0
## Distance (m) devant la sentinelle où le remplaçant s'arrête.
const FRONT_DISTANCE := 1.3

## Sentinelle de service.
@export var post: Enemy
## Remplaçant, au repos.
@export var relief: Enemy
## Intervalle (s de jeu) entre deux relèves.
@export_range(10.0, 1200.0, 5.0) var interval: float = 120.0
## Première relève (s de jeu depuis le début).
@export_range(0.0, 1200.0, 5.0) var first_at: float = 60.0
## Nom du poste dans les annonces (vide : celui de la sentinelle).
@export var post_name: String = ""
## Annonce interceptée avant chaque relève.
@export var announce: bool = true

## Temps (s) avant la prochaine relève ; négatif : plus de relève.
var time_left: float = 0.0
## Relève en cours : le remplaçant marche vers le poste.
var underway: bool = false
var _warned: bool = false
var _post_spot := Vector3.ZERO
var _post_yaw: float = 0.0
## Repos du remplaçant (son poste avant de partir).
var _rest_spot := Vector3.ZERO
var _rest_yaw: float = 0.0
var _rest_stationary: bool = true


func _ready() -> void:
	add_to_group(QuickSave.GROUP)
	time_left = first_at
	# Après les ennemis (leur `_ready` fixe leur poste).
	_capture_post.call_deferred()


func _capture_post() -> void:
	if is_instance_valid(post):
		_post_spot = post.home_position()
		_post_yaw = post._home_yaw


func _physics_process(delta: float) -> void:
	if underway or time_left < 0.0:
		return
	time_left -= delta
	if announce and not _warned and time_left <= WARNING_TIME:
		_warned = true
		EventBus.radio_message.emit("(ennemie) relève du poste %s dans %d secondes." % [_name(), int(WARNING_TIME)])
	if time_left > 0.0:
		return
	_start()


func _name() -> String:
	if not post_name.is_empty():
		return post_name
	return String(post.name) if is_instance_valid(post) else "?"


## Le remplaçant part vers le poste ; impossible, la relève est remise.
func _start() -> void:
	if not is_instance_valid(relief) or relief.is_dead or relief.behavior.takes_over():
		time_left = -1.0
		return
	if not relief.can_take_errand():
		time_left = RETRY_TIME
		return
	_rest_spot = relief.home_position()
	_rest_yaw = relief._home_yaw
	_rest_stationary = relief.stationary
	var forward := Vector3(-sin(_post_yaw), 0.0, -cos(_post_yaw))
	var spot := _post_spot + forward * FRONT_DISTANCE
	if relief.send_on_errand(spot, _post_spot + Vector3.UP * 1.5, HANDOVER_TIME, _on_arrived, true):
		underway = true
	else:
		time_left = RETRY_TIME


## Sentinelle hors de combat ou absente de son poste.
func _post_missing() -> bool:
	if not is_instance_valid(post) or post.is_dead or post.carrier != null:
		return true
	if post.state == Enemy.State.STUNNED or post.state == Enemy.State.GRABBED:
		return true
	var flat := Vector2(post.global_position.x - _post_spot.x, post.global_position.z - _post_spot.z)
	return flat.length() > ABSENT_RANGE and not post.is_on_errand()


## Le remplaçant est arrivé devant le poste.
func _on_arrived() -> void:
	underway = false
	_warned = false
	if not is_instance_valid(relief) or relief.is_dead:
		time_left = -1.0
		return
	if _post_missing():
		# Poste vide : il fouille, puis garde le poste à son tour.
		relief.set_post(_post_spot, _post_yaw)
		relief.stationary = true
		relief._begin_search(_post_spot)
		post = relief
		relief = null
		time_left = -1.0
		return
	if post.state != Enemy.State.PATROL or not post.can_take_errand():
		# Sentinelle occupée (méfiante) : il rentre, on réessaiera.
		relief.stationary = _rest_stationary
		_send_home(relief, _rest_spot, _rest_yaw)
		time_left = RETRY_TIME
		return
	relief.stationary = true
	_send_home(relief, _post_spot, _post_yaw)
	post.stationary = _rest_stationary
	_send_home(post, _rest_spot, _rest_yaw)
	var previous := post
	post = relief
	relief = previous
	time_left = interval


## `guard` gagne à pied le poste (`at`, `yaw`) et y reste.
static func _send_home(guard: Enemy, at: Vector3, yaw: float) -> void:
	guard.set_post(at, yaw)
	guard.walking_home = true
	guard._begin_return()


func save_state() -> Dictionary:
	return {
		"left": time_left, "warned": _warned, "underway": underway,
		"post": get_path_to(post) if is_instance_valid(post) else NodePath(),
		"relief": get_path_to(relief) if is_instance_valid(relief) else NodePath(),
	}


func load_state(data: Dictionary) -> void:
	time_left = data.get("left", time_left)
	_warned = data.get("warned", false)
	var saved_post: NodePath = data.get("post", NodePath())
	var saved_relief: NodePath = data.get("relief", NodePath())
	post = get_node_or_null(saved_post) as Enemy if not saved_post.is_empty() else null
	relief = get_node_or_null(saved_relief) as Enemy if not saved_relief.is_empty() else null
	# Relève en cours : le remplaçant rentre (sa mission n'est pas
	# reprise), elle repart bientôt.
	underway = false
	if data.get("underway", false):
		time_left = RETRY_TIME
