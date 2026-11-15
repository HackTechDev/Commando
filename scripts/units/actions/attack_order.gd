class_name AttackOrder
extends CommandoAction
## Attaquer `enemy` à distance : s'approcher jusqu'à avoir une ligne de tir,
## puis tirer (rechargements compris) jusqu'à ce qu'il soit neutralisé.

var enemy: Enemy
var run: bool


func _init(owner: Commando, target: Enemy, running: bool) -> void:
	super(owner)
	enemy = target
	run = running


func start() -> void:
	unit._running = run
	unit._fire_cooldown = unit.stats.aim_time


func look_point() -> Vector3:
	return enemy_point(enemy)


## Vrai tant que la cible est debout (l'opérateur épaule).
func is_aiming() -> bool:
	return is_instance_valid(enemy) and not enemy.is_dead


func update(delta: float) -> Vector3:
	if not is_aiming() or not unit._ready_to_fire():
		finish()
		return Vector3.ZERO
	var to_target := enemy.global_position - unit.global_position
	to_target.y = 0.0
	var distance := to_target.length()
	if distance <= unit.stats.fire_range and unit._has_line_of_fire(enemy):
		if distance > 0.01:
			unit._face(to_target, delta)
		unit._fire_cooldown -= delta
		if unit.ammo_in_magazine <= 0:
			unit.reload()
		elif not unit.is_reloading() and unit._model.is_weapon_ready() and not unit._model.is_changing_posture() \
				and unit._fire_cooldown <= 0.0 and (-unit.global_basis.z).angle_to(to_target) < 0.25:
			unit._fire(enemy, distance)
		return Vector3.ZERO
	# Pas de ligne de tir : s'approcher, puis viser de nouveau.
	unit._fire_cooldown = unit.stats.aim_time
	if unit.perched_on:
		unit._descend(enemy.global_position, func() -> void: pass)
		return Vector3.ZERO
	if unit._agent.target_position.distance_to(enemy.global_position) > 0.5:
		unit._agent.target_position = enemy.global_position
	if unit._agent.is_navigation_finished():
		return Vector3.ZERO
	return unit._follow_path(delta)
