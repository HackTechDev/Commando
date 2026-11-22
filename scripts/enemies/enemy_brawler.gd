class_name EnemyBrawler
extends RefCounted
## Corps à corps d'un ennemi en alerte : coup au contact (crosse, ou poing
## sans arme), poussée d'un assaillant, déséquilibre après un coup paré ou
## esquivé ; à plusieurs sur une même cible, il la prend de flanc.

## Un second assaillant se place sur le flanc de la cible, à cet angle
## (degrés) du premier.
const FLANK_ANGLE := 100.0

var enemy: Enemy
## Délai (s) avant de pouvoir frapper de nouveau.
var cooldown: float = 0.0
## Coup en cours : temps restant, cible, impact joué.
var attack_left: float = 0.0
var attack_target: Unit
var _attack_landed: bool = false
## Déséquilibre restant (s).
var off_balance_left: float = 0.0
## Poussée en cours : temps restant, assaillant repoussé.
var shove_left: float = 0.0
var _shove_target: Commando


func _init(owner: Enemy) -> void:
	enemy = owner


## Une image : vrai s'il est occupé (poussée, coup ou déséquilibre) et ne
## fait rien d'autre.
func update(delta: float) -> bool:
	cooldown -= delta
	off_balance_left = maxf(off_balance_left - delta, 0.0)
	enemy._model.staggered = off_balance_left > 0.0
	if shove_left > 0.0:
		_update_shove(delta)
		return true
	if attack_left > 0.0:
		_update_attack(delta)
		return true
	return off_balance_left > 0.0


## Vrai pendant une poussée, un coup ou un déséquilibre.
func is_busy() -> bool:
	return attack_left > 0.0 or shove_left > 0.0 or off_balance_left > 0.0


## Repousse `attacker` (animation de poussée).
func shove(attacker: Commando) -> void:
	shove_left = enemy.stats.shove_time
	_shove_target = attacker


func _update_shove(delta: float) -> void:
	shove_left = maxf(shove_left - delta, 0.0)
	enemy._model.shove_progress = 1.0 - shove_left / enemy.stats.shove_time
	if is_instance_valid(_shove_target):
		enemy._face(_shove_target.global_position - enemy.global_position, delta)
	if shove_left <= 0.0:
		enemy._model.shove_progress = -1.0
		_shove_target = null


## Au contact de sa cible (`to_target` : vers elle) : il frappe, s'il est
## face à elle et que le délai est passé.
func try_strike(to_target: Vector3) -> void:
	var target := enemy._target
	# Cible occupée à parer ou esquiver un autre : il en profite aussitôt.
	var opening := target is Commando and (target as Commando).is_defending()
	if (cooldown > 0.0 and not opening) or (-enemy.global_basis.z).angle_to(to_target) > 0.5:
		return
	var stats := enemy.stats
	attack_left = stats.melee_time
	attack_target = target
	_attack_landed = false
	cooldown = stats.melee_time + stats.melee_interval
	var model := enemy._model
	model.strike_with_knife = false
	model.strike_move = SoldierModel.StrikeMove.BUTT_STRIKE if enemy.armed else SoldierModel.StrikeMove.UPPERCUT
	model.strike_progress = 0.0


func _update_attack(delta: float) -> void:
	var stats := enemy.stats
	attack_left = maxf(attack_left - delta, 0.0)
	var progress := 1.0 - attack_left / stats.melee_time
	enemy._model.strike_progress = progress
	var valid := is_instance_valid(attack_target) and not attack_target.is_dead
	if valid:
		enemy._face(attack_target.global_position - enemy.global_position, delta)
	if not _attack_landed and progress >= Commando.STRIKE_HIT_TIME:
		_attack_landed = true
		if valid:
			var offset := attack_target.global_position - enemy.global_position
			offset.y = 0.0
			if offset.length() <= stats.melee_range + Commando.STRIKE_REACH_MARGIN and attack_target.defend_against(enemy):
				# Paré ou esquivé : emporté par son élan, il perd l'équilibre.
				off_balance_left = stats.off_balance_time
	if attack_left <= 0.0:
		enemy._model.strike_progress = -1.0
		attack_target = null


## Interrompt poussée, coup et déséquilibre.
func cancel() -> void:
	shove_left = 0.0
	_shove_target = null
	enemy._model.shove_progress = -1.0
	attack_left = 0.0
	attack_target = null
	enemy._model.strike_progress = -1.0
	off_balance_left = 0.0
	enemy._model.staggered = false


## Autre ennemi déjà au contact de la même cible, ou null.
func _other_attacker() -> Enemy:
	var target := enemy._target
	if not is_instance_valid(target):
		return null
	for node in enemy.get_tree().get_nodes_in_group(&"enemies"):
		var other := node as Enemy
		if other == null or other == enemy or other.is_dead or other.state != Enemy.State.ALERT or other._target != target:
			continue
		var gap := other.global_position - target.global_position
		gap.y = 0.0
		if gap.length() <= other.stats.melee_range + 0.3:
			return other
	return null


## Point où se placer pour frapper la cible de flanc, un camarade étant
## déjà au contact ; `Vector3.INF` sinon (armé, pas de cible, ou il frappe
## lui-même déjà de face).
func flank_point() -> Vector3:
	var target := enemy._target
	if enemy.can_fire() or not is_instance_valid(target):
		return Vector3.INF
	var other := _other_attacker()
	if other == null:
		return Vector3.INF
	var from_other := other.global_position - target.global_position
	from_other.y = 0.0
	if from_other.length_squared() < 0.0001:
		return Vector3.INF
	var mine := enemy.global_position - target.global_position
	mine.y = 0.0
	# Du côté où il se trouve déjà.
	var side := 1.0 if from_other.cross(mine).y >= 0.0 else -1.0
	var direction := from_other.normalized().rotated(Vector3.UP, deg_to_rad(FLANK_ANGLE) * side)
	return target.global_position + direction * enemy.stats.melee_range * 0.8
