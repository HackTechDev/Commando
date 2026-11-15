class_name PickupGesture
extends CommandoAction
## Se baisser pour ramasser un objet : l'opérateur s'arrête le temps du
## geste (`SoldierModel.play_pickup`), puis son ordre reprend.

var left: float = SoldierModel.PICKUP_DURATION


func _init(owner: Commando) -> void:
	super(owner)
	gesture = true
	interruptible = false


func start() -> void:
	unit._model.play_pickup()


func update(delta: float) -> Vector3:
	left -= delta
	if left <= 0.0:
		finish()
	return Vector3.ZERO
