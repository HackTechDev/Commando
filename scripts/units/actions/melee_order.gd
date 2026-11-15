class_name MeleeOrder
extends CommandoAction
## S'approcher de `enemy` pour le neutraliser au corps à corps, puis frapper
## (`StrikeGesture`). Un ennemi en alerte qui le voit venir le repousse
## (`PushGesture`) ; un ennemi qui frappe le premier est attendu de pied
## ferme (parade, puis contre : voir `DefendGesture`).

const REPEL_DISTANCE := 1.0
const REPEL_TIME := 0.35

var enemy: Enemy
var kind: Commando.MeleeKind
var run: bool


func _init(owner: Commando, target: Enemy, how: Commando.MeleeKind, running: bool) -> void:
	super(owner)
	enemy = target
	kind = how
	run = running


func start() -> void:
	unit._running = run


func hands_free() -> bool:
	return kind == Commando.MeleeKind.KNIFE


func look_point() -> Vector3:
	return enemy_point(enemy)


func update(delta: float) -> Vector3:
	if not is_instance_valid(enemy) or enemy.is_dead or (kind == Commando.MeleeKind.KNOCKOUT and enemy.is_stunned()):
		finish()
		return Vector3.ZERO
	var to_enemy := enemy.global_position - unit.global_position
	to_enemy.y = 0.0
	if to_enemy.length() <= Commando.MELEE_RANGE:
		if enemy.is_attacking():
			# Il frappe le premier : on attend l'issue (parade, puis contre).
			unit._face(to_enemy, delta)
			return Vector3.ZERO
		if enemy.resists(unit.global_position):
			# Il l'a vu venir, garde levée : il le repousse, le coup échoue.
			unit.flash_message("En garde : parer son coup pour contrer, ou le prendre à revers")
			enemy.shove(unit)
			finish(PushGesture.new(unit, -to_enemy.normalized() * REPEL_DISTANCE, REPEL_TIME, enemy.stats.shove_time * 0.5, enemy.global_position))
			return Vector3.ZERO
		finish(StrikeGesture.new(unit, enemy, kind))
		return Vector3.ZERO
	if unit._agent.target_position.distance_to(enemy.global_position) > 0.3:
		unit._agent.target_position = enemy.global_position
	if unit._agent.is_navigation_finished():
		return Vector3.ZERO
	return unit._follow_path(delta)
