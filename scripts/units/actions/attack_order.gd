class_name AttackOrder
extends CommandoAction
## Attaquer `enemy` à distance, depuis sa place : l'opérateur le garde en
## joue et tire (rechargements compris) tant qu'il est à portée et en ligne
## de tir, jusqu'à ce qu'il soit neutralisé. Il ne s'approche pas : hors de
## portée ou derrière un obstacle, il le signale et attend ; c'est au joueur
## de le déplacer.

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
	if not is_aiming():
		finish()
		return Vector3.ZERO
	if not unit._ready_to_fire():
		unit.flash_hint(Commando.Hint.NO_AMMO)
		finish()
		return Vector3.ZERO
	var to_target := enemy.global_position - unit.global_position
	to_target.y = 0.0
	var distance := to_target.length()
	if distance <= unit.fire_range() and unit._has_line_of_fire(enemy):
		if distance > 0.01:
			unit._face(to_target, delta)
		unit._fire_cooldown -= delta
		if unit.ammo_in_magazine <= 0:
			unit.reload()
		elif not unit.is_reloading() and unit._model.is_weapon_ready() and not unit._model.is_changing_posture() \
				and unit._fire_cooldown <= 0.0 and (-unit.global_basis.z).angle_to(to_target) < 0.25:
			unit._fire(enemy, distance)
		return Vector3.ZERO
	# Hors de portée ou derrière un obstacle : il le signale et attend, en
	# joue, que le joueur le déplace ou que la cible passe à portée.
	unit.report_hint(Commando.Hint.OUT_OF_RANGE if distance > unit.fire_range() else Commando.Hint.OBSTACLE)
	unit._fire_cooldown = unit.stats.aim_time
	# À pied, il reste tourné vers elle.
	if distance > 0.01 and not unit.airborne_in and not unit.riding:
		unit._face(to_target, delta)
	return Vector3.ZERO
