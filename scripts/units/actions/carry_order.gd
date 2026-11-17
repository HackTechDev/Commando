class_name CarryOrder
extends CommandoAction
## Rejoindre un corps (ennemi mort ou assommé), se baisser et le prendre sur
## les épaules (`Commando._lift_body`).

const REACH := 1.3

var body: Enemy
var run: bool
var _lift_left: float = -1.0


func _init(owner: Commando, target: Enemy, running: bool) -> void:
	super(owner)
	body = target
	run = running


func start() -> void:
	unit._running = run
	unit._agent.target_position = body.body_center()


func hands_free() -> bool:
	return true


func look_point() -> Vector3:
	return body.body_center() if is_instance_valid(body) else Vector3.INF


func update(delta: float) -> Vector3:
	if not is_instance_valid(body) or not body.is_body() or body.carrier != null:
		finish()
		return Vector3.ZERO
	if _lift_left >= 0.0:
		# Accroupi sur le corps : il le charge à mi-geste.
		var before := _lift_left
		_lift_left -= delta
		if before > SoldierModel.PICKUP_DURATION * 0.5 and _lift_left <= SoldierModel.PICKUP_DURATION * 0.5:
			unit._lift_body(body)
		if _lift_left <= 0.0:
			finish()
		return Vector3.ZERO
	var offset := body.body_center() - unit.global_position
	offset.y = 0.0
	if offset.length() <= REACH:
		_lift_left = SoldierModel.PICKUP_DURATION
		unit._model.play_pickup()
		return Vector3.ZERO
	if unit._agent.is_navigation_finished() and offset.length() > REACH + 1.0:
		finish()
		return Vector3.ZERO
	return unit._follow_path(delta)
