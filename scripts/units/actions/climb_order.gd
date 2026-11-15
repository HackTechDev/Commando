class_name ClimbOrder
extends CommandoAction
## Rejoindre le point d'accès d'un obstacle, puis y grimper ; `then` est
## appelé une fois monté (suite d'une escalade en deux temps).

const START_DISTANCE := 0.4
const REACH := 1.2

var target: Climbable
var point: Vector3
var then: Callable
var run: bool


func _init(owner: Commando, obstacle: Climbable, access_point: Vector3, after: Callable, running: bool) -> void:
	super(owner)
	target = obstacle
	point = access_point
	then = after
	run = running


func start() -> void:
	unit._running = run
	unit._agent.target_position = point


func hands_free() -> bool:
	return true


func update(delta: float) -> Vector3:
	if target.occupant != null and target.occupant != unit:
		finish()
		return Vector3.ZERO
	var offset := point - unit.global_position
	offset.y = 0.0
	var distance := offset.length()
	var arrived := unit._agent.is_navigation_finished()
	if distance < START_DISTANCE or (arrived and distance < REACH):
		finish()
		target.occupant = unit
		var obstacle := target
		var after := then
		unit._hop(obstacle.get_top_position(), func() -> void:
			unit.perched_on = obstacle
			if after.is_valid():
				after.call())
		return Vector3.ZERO
	if arrived:
		finish()
		return Vector3.ZERO
	var to_next := unit._walker.next_point(unit._agent, unit, unit.get_physics_process_delta_time()) - unit.global_position
	to_next.y = 0.0
	if to_next.length_squared() < 0.0001:
		return Vector3.ZERO
	unit._face(to_next, delta)
	return to_next.normalized() * unit._current_speed()
