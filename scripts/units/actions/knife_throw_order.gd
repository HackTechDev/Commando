class_name KnifeThrowOrder
extends CommandoAction
## S'approcher de `enemy` jusqu'à portée de lancer, avec une ligne de vue
## dégagée, puis lancer un couteau (`ThrowGesture`) une fois les mains
## libres et la cible dans l'axe.

var enemy: Enemy
var run: bool


func _init(owner: Commando, target: Enemy, running: bool) -> void:
	super(owner)
	enemy = target
	run = running


func start() -> void:
	unit._running = run


func hands_free() -> bool:
	return true


func look_point() -> Vector3:
	return enemy_point(enemy)


func update(delta: float) -> Vector3:
	if not is_instance_valid(enemy) or enemy.is_dead or unit.throwing_knives <= 0:
		finish()
		return Vector3.ZERO
	var to_enemy := enemy.global_position - unit.global_position
	to_enemy.y = 0.0
	if unit._can_throw_at(enemy):
		unit._face(to_enemy, delta)
		# On ne lance pas couché : l'opérateur se met à genoux.
		if unit.posture == SoldierModel.Posture.PRONE:
			unit.posture = SoldierModel.Posture.CROUCHED
		if unit._model.is_weapon_slung() and not unit._model.is_changing_posture() and (-unit.global_basis.z).angle_to(to_enemy) < 0.2:
			finish(ThrowGesture.new(unit, enemy, Vector3.INF))
		return Vector3.ZERO
	if unit._agent.target_position.distance_to(enemy.global_position) > 0.3:
		unit._agent.target_position = enemy.global_position
	if unit._agent.is_navigation_finished():
		return Vector3.ZERO
	return unit._follow_path(delta)
