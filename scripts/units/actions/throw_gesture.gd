class_name ThrowGesture
extends CommandoAction
## Lancer d'un couteau sur `enemy`, ou d'un objet (`object` : grenade,
## fumigène, caillou ; grappin avec `release`) vers `point` (si `enemy` est
## null). Le geste (`SoldierModel.ThrowStyle`) dépend de l'objet et de la
## distance : grenade lancée loin par-dessus l'épaule ou lobée à la cuillère
## près, petit lancer du poignet pour un caillou. L'objet part à l'instant
## `SoldierModel.throw_release` du geste.

var enemy: Enemy
var point: Vector3
var grenade: bool
var object: SoldierModel.ThrowObject
var style: SoldierModel.ThrowStyle
var duration: float = 1.0
## Si valide, appelé à l'instant du lancer à la place de la grenade (grappin).
var release: Callable
var left: float = 0.0
var _released: bool = false


func _init(owner: Commando, target: Enemy, at: Vector3, thrown: SoldierModel.ThrowObject = SoldierModel.ThrowObject.GRENADE) -> void:
	super(owner)
	gesture = true
	interruptible = false
	enemy = target
	point = at
	grenade = target == null
	object = thrown if grenade else SoldierModel.ThrowObject.KNIFE
	style = style_for(object, owner.global_position.distance_to(at) if grenade else 0.0)


## Geste d'un lancer de `object` à `distance` (m).
static func style_for(thrown: SoldierModel.ThrowObject, distance: float) -> SoldierModel.ThrowStyle:
	match thrown:
		SoldierModel.ThrowObject.KNIFE:
			return SoldierModel.ThrowStyle.KNIFE
		SoldierModel.ThrowObject.PEBBLE:
			return SoldierModel.ThrowStyle.FLICK
		SoldierModel.ThrowObject.NONE:
			return SoldierModel.ThrowStyle.OVERHAND
	return SoldierModel.ThrowStyle.LOB if distance < SoldierModel.LOB_DISTANCE else SoldierModel.ThrowStyle.OVERHAND


func start() -> void:
	duration = unit.stats.throw_time * SoldierModel.throw_duration(style)
	left = duration
	unit._model.throw_style = style
	unit._model.throw_object = object
	unit._model.throw_progress = 0.0


func hands_free() -> bool:
	return true


func look_point() -> Vector3:
	return point if grenade else enemy_point(enemy)


func cancel() -> void:
	unit._model.throw_progress = -1.0


func update(delta: float) -> Vector3:
	left = maxf(left - delta, 0.0)
	var progress := 1.0 - left / duration
	unit._model.throw_progress = progress
	var valid := grenade or (is_instance_valid(enemy) and not enemy.is_dead)
	var aim := point if grenade else (enemy.global_position if valid else unit.global_position)
	var to_target := aim - unit.global_position
	to_target.y = 0.0
	if to_target.length() > 0.05:
		unit._face(to_target, delta)
	if not _released and progress >= SoldierModel.throw_release(style):
		_released = true
		if release.is_valid():
			release.call()
		elif grenade:
			unit._release_throwable(object, point)
		elif valid and unit.throwing_knives > 0:
			unit._release_knife(enemy)
	if left <= 0.0:
		cancel()
		finish()
	return Vector3.ZERO
