class_name DefendGesture
extends CommandoAction
## Parade ou esquive (pas de côté) face au coup de `enemy`. Si l'ordre en
## cours est de neutraliser cet ennemi au corps à corps et qu'il est
## déséquilibré à la fin du geste, l'opérateur contre aussitôt.

const DODGE_DISTANCE := 0.5
const DODGE_TIME := 0.3
## Obstacles qui empêchent un pas de côté : murs, opérateurs, ennemis,
## caisses et autres objets.
const DODGE_MASK := 0b11110
## Rayon du corps testé sur le trajet de l'esquive, et hauteur du test.
const DODGE_BODY_RADIUS := 0.3
const DODGE_TEST_HEIGHT := 0.9

var enemy: Enemy
var dodge: bool
var _left: float
var _step: PushGesture


func _init(owner: Commando, attacker: Enemy, dodging: bool) -> void:
	super(owner)
	gesture = true
	interruptible = false
	enemy = attacker
	dodge = dodging


func start() -> void:
	_left = unit.stats.defend_time
	var to_enemy := enemy.global_position - unit.global_position
	to_enemy.y = 0.0
	var side := 0.0
	if dodge:
		# Pas de côté, perpendiculaire à l'axe du coup, du côté libre ; sans
		# place d'aucun côté, il pare.
		side = free_side(unit, enemy, to_enemy.normalized().cross(Vector3.UP))
		dodge = side != 0.0
	if dodge:
		unit._model.defend_move = SoldierModel.DefendMove.DODGE
		unit._model.defend_side = side
		Sfx.play_at(&"whoosh", unit.global_position + Vector3.UP * 1.4, -4.0)
		_step = PushGesture.new(unit, to_enemy.normalized().cross(Vector3.UP) * side * DODGE_DISTANCE, DODGE_TIME, 0.0)
	else:
		unit._model.defend_move = SoldierModel.DefendMove.PARRY
		Sfx.play_at(&"block", unit.global_position + Vector3.UP * 1.5)
	unit._model.defend_progress = 0.0


## Côté (1 : `right`, -1 : à l'opposé) où un pas de côté de `DODGE_DISTANCE`
## est libre ; au hasard si les deux le sont, 0 si aucun.
static func free_side(unit: Commando, attacker: Node3D, right: Vector3) -> float:
	var sides: Array[float] = [1.0, -1.0]
	if randf() < 0.5:
		sides.reverse()
	for side in sides:
		if _is_clear(unit, attacker, right * side):
			return side
	return 0.0


## Vrai si rien ne gêne le corps de `unit` sur `DODGE_DISTANCE` dans la
## direction `toward`.
static func _is_clear(unit: Commando, attacker: Node3D, toward: Vector3) -> bool:
	var shape := SphereShape3D.new()
	shape.radius = DODGE_BODY_RADIUS
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = DODGE_MASK
	query.transform = Transform3D(Basis.IDENTITY, unit.global_position + Vector3.UP * DODGE_TEST_HEIGHT)
	query.motion = toward * DODGE_DISTANCE
	var excluded: Array[RID] = [unit.get_rid()]
	if attacker is CollisionObject3D:
		excluded.append((attacker as CollisionObject3D).get_rid())
	query.exclude = excluded
	var result := unit.get_world_3d().direct_space_state.cast_motion(query)
	return result.is_empty() or result[0] >= 1.0


func look_point() -> Vector3:
	return enemy_point(enemy)


func cancel() -> void:
	unit._model.defend_progress = -1.0


func update(delta: float) -> Vector3:
	_left = maxf(_left - delta, 0.0)
	unit._model.defend_progress = 1.0 - _left / unit.stats.defend_time
	var horizontal := Vector3.ZERO
	if _step and not _step.done:
		horizontal = _step.update(delta)
	if is_instance_valid(enemy):
		unit._face(enemy.global_position - unit.global_position, delta)
	if _left <= 0.0:
		unit._model.defend_progress = -1.0
		finish(_counter())
	return horizontal


## Contre : l'ordre de corps à corps en attente sur l'assaillant déséquilibré
## part aussitôt, s'il est à portée.
func _counter() -> CommandoAction:
	var order := unit._order as MeleeOrder
	if order == null or order.enemy != enemy or not is_instance_valid(enemy) or enemy.is_dead or not enemy.is_off_balance():
		return null
	var offset := enemy.global_position - unit.global_position
	offset.y = 0.0
	if offset.length() > Commando.MELEE_RANGE + Commando.STRIKE_REACH_MARGIN:
		return null
	unit._set_order(null)
	# Contre au contact : coude ou genou.
	return StrikeGesture.new(unit, enemy, order.kind, true)
