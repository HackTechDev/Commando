class_name ThrowGesture
extends CommandoAction
## Lancer d'un couteau sur `enemy`, ou d'une grenade (ou d'un grappin,
## `release`) vers `point` (si `enemy` est null). L'objet part à l'instant `SoldierModel.THROW_RELEASE`.

var enemy: Enemy
var point: Vector3
var grenade: bool
## Si valide, appelé à l'instant du lancer à la place de la grenade (grappin).
var release: Callable
var left: float = 0.0
var _released: bool = false


func _init(owner: Commando, target: Enemy, at: Vector3) -> void:
	super(owner)
	gesture = true
	interruptible = false
	enemy = target
	point = at
	grenade = target == null


func start() -> void:
	left = unit.stats.throw_time
	unit._model.throw_grenade = grenade
	unit._model.throw_progress = 0.0


func hands_free() -> bool:
	return true


func look_point() -> Vector3:
	return point if grenade else enemy_point(enemy)


func cancel() -> void:
	unit._model.throw_progress = -1.0
	unit._model.throw_grenade = false


func update(delta: float) -> Vector3:
	left = maxf(left - delta, 0.0)
	var progress := 1.0 - left / unit.stats.throw_time
	unit._model.throw_progress = progress
	var valid := grenade or (is_instance_valid(enemy) and not enemy.is_dead)
	var aim := point if grenade else (enemy.global_position if valid else unit.global_position)
	var to_target := aim - unit.global_position
	to_target.y = 0.0
	if to_target.length() > 0.05:
		unit._face(to_target, delta)
	if not _released and progress >= SoldierModel.THROW_RELEASE:
		_released = true
		if release.is_valid():
			release.call()
		elif grenade:
			unit._release_grenade(point)
		elif valid and unit.throwing_knives > 0:
			unit._release_knife(enemy)
	if left <= 0.0:
		cancel()
		finish()
	return Vector3.ZERO
