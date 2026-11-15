class_name MoveOrder
extends CommandoAction
## Se déplacer vers `target` par la navigation. L'ordre est abandonné si la
## destination est occupée : près du but et sans s'en rapprocher, on
## considère qu'on est arrivé.

const STUCK_PROGRESS := 0.05
const STUCK_DELAY := 0.6
const STUCK_GOAL_DISTANCE := 2.0

var target: Vector3
var run: bool
var _stuck_time: float = 0.0
var _best_goal_distance: float = INF


func _init(owner: Commando, to: Vector3, running: bool) -> void:
	super(owner)
	target = to
	run = running


func start() -> void:
	unit._running = run
	unit._agent.target_position = target


func update(delta: float) -> Vector3:
	if unit._agent.is_navigation_finished():
		finish()
		return Vector3.ZERO
	var horizontal := unit._follow_path(delta)
	_check_stuck(delta, Vector3.ZERO if unit._model.is_changing_posture() else horizontal)
	return horizontal


func _check_stuck(delta: float, desired: Vector3) -> void:
	if desired == Vector3.ZERO:
		_stuck_time = 0.0
		_best_goal_distance = INF
		return
	var goal_distance := unit.global_position.distance_to(unit._agent.target_position)
	if goal_distance < _best_goal_distance - STUCK_PROGRESS:
		_best_goal_distance = goal_distance
		_stuck_time = 0.0
	elif goal_distance < STUCK_GOAL_DISTANCE:
		_stuck_time += delta
		if _stuck_time > STUCK_DELAY:
			finish()
