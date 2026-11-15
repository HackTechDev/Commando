class_name GrenadeOrder
extends CommandoAction
## S'approcher à portée de `target` (un point au sol), puis lancer une
## grenade (`ThrowGesture`) une fois les mains libres et face au point.

var target: Vector3
var run: bool


func _init(owner: Commando, point: Vector3, running: bool) -> void:
	super(owner)
	target = point
	run = running


func start() -> void:
	unit._running = run


func hands_free() -> bool:
	return true


func look_point() -> Vector3:
	return target


func update(delta: float) -> Vector3:
	if unit.grenades <= 0:
		finish()
		return Vector3.ZERO
	var to_target := target - unit.global_position
	to_target.y = 0.0
	if unit._in_grenade_range(target):
		if to_target.length() > 0.05:
			unit._face(to_target, delta)
		if unit.posture == SoldierModel.Posture.PRONE:
			unit.posture = SoldierModel.Posture.CROUCHED
		if unit._model.is_weapon_slung() and not unit._model.is_changing_posture() \
				and (to_target.length() < 0.05 or (-unit.global_basis.z).angle_to(to_target) < 0.2):
			finish(ThrowGesture.new(unit, null, target))
		return Vector3.ZERO
	unit.report_hint(Commando.Hint.OUT_OF_RANGE)
	if unit._agent.target_position.distance_to(target) > 0.3:
		unit._agent.target_position = target
	if unit._agent.is_navigation_finished():
		finish()
		return Vector3.ZERO
	return unit._follow_path(delta)
