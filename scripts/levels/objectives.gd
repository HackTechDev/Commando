class_name Objectives
extends Node
## Objectifs de la mission en cours (`LevelCatalog.objectives_of`) et leur
## état, pour le journal (5.7) et la fin de mission :
## - `vip_extracted` : signalé par la zone d'extraction ;
## - `all_enemies_down` : plus aucun ennemi debout (morts ou inconscients) ;
## - conditions `vip_alive`, `no_operator_lost` : remplies à la réussite,
##   manquées à la mort d'un VIP ou d'un opérateur ;
## - condition bonus `no_alert` : manquée dès que l'alerte est donnée ;
## - bonus `before_dawn` : manqué quand le jour se lève (`DayCycle`).
## Tous les objectifs remplis : réussite ; une condition manquée : échec
## (`EventBus.mission_ended`, sauf si une autre source l'a déjà émis).

enum Status { PENDING, DONE, FAILED }

const GROUP := &"objectives"
## Objectifs qui ne se remplissent qu'à la réussite des autres.
const CONDITIONS: Array[String] = ["vip_alive", "no_operator_lost", "no_alert"]
## Objectifs bonus : leur échec s'affiche mais ne bloque ni l'extraction ni
## la réussite (repartir avant l'arrivée des renforts, `Reinforcements` ;
## ne jamais donner l'alerte).
const OPTIONAL: Array[String] = ["raid_in_time", "no_alert", "before_dawn"]
## Intervalle de vérification des ennemis restants.
const CHECK_INTERVAL := 0.5

signal changed

## [{"id": String, "text": String, "status": Status}]
var entries: Array[Dictionary] = []
var is_over: bool = false
var _check_left: float = 0.0
## Au moins un ennemi vu : une carte encore en construction n'en a aucun.
var _enemies_seen: bool = false


func setup(objectives: Array[Dictionary]) -> void:
	entries.clear()
	for objective in objectives:
		entries.append({"id": String(objective.get("id", "")), "text": objective["text"], "status": Status.PENDING})
	changed.emit()


func _ready() -> void:
	name = "Objectives"
	add_to_group(GROUP)
	# Pas pendant le chargement ni les pauses (le HUD, lui, tourne toujours).
	process_mode = Node.PROCESS_MODE_PAUSABLE
	EventBus.mission_ended.connect(_on_mission_ended)
	# Celui qui signale l'objectif annonce lui-même la fin (zone
	# d'extraction : « VIP évacué »).
	EventBus.objective_completed.connect(func(id: StringName) -> void: complete(String(id), ""))
	EventBus.unit_died.connect(_on_unit_died)
	EventBus.enemy_killed.connect(func(_enemy: Node3D) -> void: _enemies_seen = true)
	GameState.alert_level_changed.connect(func(level: GameState.AlertLevel) -> void:
		if level == GameState.AlertLevel.ALARM and not is_over:
			fail("no_alert"))
	for node in get_tree().get_nodes_in_group(&"vips"):
		var vip := node as Vip
		if vip:
			vip.killed.connect(func() -> void: fail("vip_alive"))


## État de l'objectif `id` (PENDING s'il n'y est pas).
func status_of(id: String) -> Status:
	for entry in entries:
		if entry["id"] == id:
			return entry["status"]
	return Status.PENDING


## Vrai si tous les objectifs autres que `id` (hors conditions) sont
## remplis, et aucun manqué : l'extraction peut partir.
func done_except(id: String) -> bool:
	for entry in entries:
		if OPTIONAL.has(entry["id"]):
			continue
		if entry["status"] == Status.FAILED:
			return false
		if entry["id"] != id and entry["status"] == Status.PENDING and not CONDITIONS.has(entry["id"]):
			return false
	return true


func has_objective(id: String) -> bool:
	return entries.any(func(entry: Dictionary) -> bool: return entry["id"] == id)


## Remplit l'objectif `id` ; si c'était le dernier, la mission est réussie
## avec le message `announce` (vide : la fin est annoncée ailleurs).
func complete(id: String, announce: String = "RÉUSSITE — objectifs remplis") -> void:
	_set_status(id, Status.DONE)
	_evaluate(announce)


func fail(id: String) -> void:
	_set_status(id, Status.FAILED)


func _set_status(id: String, status: Status) -> void:
	for entry in entries:
		if entry["id"] == id and entry["status"] == Status.PENDING:
			entry["status"] = status
			changed.emit()


func _process(delta: float) -> void:
	if is_over or not has_objective("all_enemies_down"):
		return
	_check_left -= delta
	if _check_left > 0.0:
		return
	_check_left = CHECK_INTERVAL
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		if enemy == null:
			continue
		_enemies_seen = true
		if not enemy.is_dead and enemy.state != Enemy.State.STUNNED:
			return
	if _enemies_seen:
		complete("all_enemies_down", "RÉUSSITE — sentinelles neutralisées")


func _on_unit_died(unit: Node3D) -> void:
	var commando := unit as Commando
	if commando == null or is_over:
		return
	fail("no_operator_lost")
	if not is_over:
		EventBus.mission_ended.emit(false, "ÉCHEC — %s tué" % commando.display_name)


## Réussite quand tous les objectifs (hors conditions) sont remplis.
func _evaluate(announce: String) -> void:
	if is_over or entries.is_empty():
		return
	for entry in entries:
		if OPTIONAL.has(entry["id"]):
			continue
		if entry["status"] == Status.FAILED:
			return
		if entry["status"] == Status.PENDING and not CONDITIONS.has(entry["id"]):
			return
	if announce.is_empty():
		return
	EventBus.mission_ended.emit(true, announce)


func _on_mission_ended(success: bool, _message: String) -> void:
	if is_over:
		return
	is_over = true
	if success:
		for entry in entries:
			if entry["status"] == Status.PENDING:
				entry["status"] = Status.DONE
	changed.emit()
