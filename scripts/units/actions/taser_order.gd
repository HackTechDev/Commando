class_name TaserOrder
extends CommandoAction
## Taser : s'approcher de `enemy` jusqu'à portée (`Commando.TASER_RANGE`),
## avec une ligne de tir dégagée, viser un instant, puis tirer les deux
## dards (`Commando._fire_taser`) : touché, le garde s'effondre, inconscient
## un long moment, et peut être ligoté.

var enemy: Enemy
var run: bool
var _aim_left: float = Commando.TASER_AIM_TIME


func _init(owner: Commando, target: Enemy, running: bool) -> void:
	super(owner)
	enemy = target
	run = running


func start() -> void:
	unit._running = run


func look_point() -> Vector3:
	return enemy_point(enemy)


func is_aiming() -> bool:
	return is_instance_valid(enemy) and unit._can_tase(enemy)


func update(delta: float) -> Vector3:
	if not is_instance_valid(enemy) or enemy.is_dead or enemy.state == Enemy.State.STUNNED or unit.tasers <= 0:
		finish()
		return Vector3.ZERO
	var to_enemy := enemy.global_position - unit.global_position
	to_enemy.y = 0.0
	if unit._can_tase(enemy):
		unit._face(to_enemy, delta)
		_aim_left -= delta
		if _aim_left <= 0.0 and not unit._model.is_changing_posture() and (-unit.global_basis.z).angle_to(to_enemy) < 0.2:
			unit._fire_taser(enemy)
			finish()
		return Vector3.ZERO
	_aim_left = Commando.TASER_AIM_TIME
	unit.report_hint(Commando.Hint.OUT_OF_RANGE if to_enemy.length() > Commando.TASER_RANGE else Commando.Hint.OBSTACLE)
	if unit.airborne_in or unit.riding:
		return Vector3.ZERO
	if unit._agent.target_position.distance_to(enemy.global_position) > 0.3:
		unit._agent.target_position = enemy.global_position
	if unit._agent.is_navigation_finished():
		return Vector3.ZERO
	return unit._follow_path(delta)
