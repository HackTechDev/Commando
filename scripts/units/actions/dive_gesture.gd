class_name DiveGesture
extends CommandoAction
## Roulade : l'opérateur plonge vers `toward` sur `DISTANCE` mètres (moins
## si un obstacle l'arrête), se reçoit sur les mains et finit couché. Le
## plongeon le fait sortir d'un cône de vision ou d'une ligne de tir ; couché
## dès l'envol, il est plus difficile à toucher.

const DISTANCE := 2.5
## Part du geste pendant laquelle il avance (le reste : il se pose).
const TRAVEL_END := 0.75

var direction: Vector3
var left: float = SoldierModel.DIVE_TIME


func _init(owner: Commando, toward: Vector3) -> void:
	super(owner)
	gesture = true
	interruptible = false
	direction = toward - owner.global_position
	direction.y = 0.0
	direction = direction.normalized() if direction.length_squared() > 0.0001 else -owner.global_basis.z


func start() -> void:
	unit.rotation.y = atan2(-direction.x, -direction.z)
	unit.posture = SoldierModel.Posture.PRONE
	unit._model.dive()
	Sfx.play_at(&"whoosh", unit.global_position + Vector3.UP, -10.0)


func update(delta: float) -> Vector3:
	var before := 1.0 - left / SoldierModel.DIVE_TIME
	left = maxf(left - delta, 0.0)
	var progress := 1.0 - left / SoldierModel.DIVE_TIME
	# Élan qui retombe : vitesse décroissante jusqu'à la réception.
	var covered := _travel(progress) - _travel(before)
	if covered > 0.0 and delta > 0.0:
		var vertical := unit.velocity.y
		unit.velocity = direction * covered / delta + Vector3.UP * vertical
		unit.move_and_slide()
		unit.velocity = Vector3.ZERO
	if left <= 0.0:
		Sfx.play_at(&"fall", unit.global_position, -8.0)
		finish()
	return Vector3.ZERO


## Distance parcourue à l'instant `t` (0 à 1) du geste.
static func _travel(t: float) -> float:
	var x := clampf(t / TRAVEL_END, 0.0, 1.0)
	return DISTANCE * (1.0 - (1.0 - x) * (1.0 - x))
