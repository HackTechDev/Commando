class_name GuardRadio
extends Node
## Radio des gardes : toutes les `interval` s (la première à `first_at` s),
## chaque poste de `guards` se signale, l'un après l'autre (`STAGGER` s
## d'écart ; un grésillement près du garde).
##
## Un garde hors de combat (tué, assommé, saisi, emporté) ne répond pas :
## la radio ennemie, interceptée, le signale (`EventBus.radio_message`), et
## le garde au calme le plus proche (`SEARCH_RADIUS` m) part voir à son
## poste, puis fouille les alentours. Une seule fois par poste.
##
## Un opérateur déguisé (`Commando.passes_as_guard`) à moins de
## `ANSWER_RANGE` m du poste répond à sa place : rien ne se passe.

const STAGGER := 2.0
const ANSWER_RANGE := 8.0
const SEARCH_RADIUS := 80.0
## Temps (s) passé à regarder au poste avant de fouiller.
const LOOK_TIME := 2.0

## Postes qui se signalent.
@export var guards: Array[Enemy] = []
## Nom de chaque poste dans les annonces (« du promontoire » ; manquant :
## celui du garde).
@export var post_names: Array[String] = []
## Intervalle (s de jeu) entre deux appels.
@export_range(10.0, 1200.0, 5.0) var interval: float = 90.0
## Premier appel (s de jeu depuis le début).
@export_range(0.0, 1200.0, 5.0) var first_at: float = 60.0

## Temps (s) avant le prochain appel.
var time_left: float = 0.0
## Postes déjà signalés muets (on ne les appelle plus).
var silent: Array[Enemy] = []
## Rang du prochain poste qui se signale dans l'appel en cours (-1 : aucun
## appel en cours).
var _turn: int = -1
var _turn_left: float = 0.0
## Poste de chaque garde au départ (instance id -> Vector3).
var _posts: Dictionary = {}


func _ready() -> void:
	add_to_group(QuickSave.GROUP)
	time_left = first_at
	_capture_posts.call_deferred()


func _capture_posts() -> void:
	for guard in guards:
		if is_instance_valid(guard):
			_posts[guard.get_instance_id()] = guard.home_position()


func post_of(guard: Enemy) -> Vector3:
	return _posts.get(guard.get_instance_id(), guard.home_position())


func _physics_process(delta: float) -> void:
	if _turn >= 0:
		_turn_left -= delta
		if _turn_left <= 0.0:
			_turn_left = STAGGER
			_check_in(_turn)
			_turn += 1
			if _turn >= guards.size():
				_turn = -1
		return
	time_left -= delta
	if time_left <= 0.0:
		time_left = interval
		_turn = 0
		_turn_left = 0.0


## Le poste de rang `index` se signale.
func _check_in(index: int) -> void:
	var guard := guards[index]
	if not is_instance_valid(guard) or silent.has(guard):
		return
	var post := post_of(guard)
	if not is_out(guard):
		Sfx.play_at(&"radio", guard.global_position + Vector3.UP * 1.5, -8.0)
		return
	var stand_in := _stand_in(post)
	if stand_in:
		Sfx.play_at(&"radio", stand_in.global_position + Vector3.UP * 1.5, -8.0)
		EventBus.radio_message.emit("%s répond à la place du poste %s." % [stand_in.display_name, post_name(index)])
		return
	silent.append(guard)
	EventBus.radio_message.emit("(ennemie) le poste %s ne répond pas : une patrouille va voir." % post_name(index))
	var scout := StreetLamp.nearest_guard(get_tree(), post, SEARCH_RADIUS)
	if scout:
		scout.send_on_errand(post, Vector3.INF, LOOK_TIME, _search.bind(scout, post))


func post_name(index: int) -> String:
	if index < post_names.size() and not post_names[index].is_empty():
		return post_names[index]
	return String(guards[index].name) if is_instance_valid(guards[index]) else "?"


## Hors de combat : il ne peut pas répondre.
static func is_out(guard: Enemy) -> bool:
	return guard.is_dead or guard.state == Enemy.State.STUNNED or guard.state == Enemy.State.GRABBED \
			or guard.carrier != null


## Opérateur déguisé près du poste, qui passe pour un garde, ou null.
func _stand_in(post: Vector3) -> Commando:
	for node in get_tree().get_nodes_in_group(&"commandos"):
		var unit := node as Commando
		if unit and unit.passes_as_guard() and unit.global_position.distance_to(post) <= ANSWER_RANGE:
			return unit
	return null


## Arrivé au poste muet : il fouille les alentours.
static func _search(scout: Enemy, post: Vector3) -> void:
	if is_instance_valid(scout) and not scout.is_dead and scout.state == Enemy.State.PATROL:
		scout._begin_search(post)


func save_state() -> Dictionary:
	var paths: Array[String] = []
	for guard in silent:
		if is_instance_valid(guard):
			paths.append(String(get_path_to(guard)))
	return {"left": time_left, "silent": paths, "turn": _turn, "turn_left": _turn_left}


func load_state(data: Dictionary) -> void:
	time_left = data.get("left", time_left)
	_turn = data.get("turn", -1)
	_turn_left = data.get("turn_left", 0.0)
	silent.clear()
	for path: String in data.get("silent", []):
		var guard := get_node_or_null(path) as Enemy
		if guard:
			silent.append(guard)
