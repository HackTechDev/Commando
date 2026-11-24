class_name PlantGesture
extends CommandoAction
## Pose d'une charge explosive aux pieds de l'opérateur, accroupi le temps de
## l'armer. Un nouvel ordre l'annule. Avec un retard (`delay` > 0), la charge
## sautera d'elle-même.

var left: float = 0.0
var delay: float = -1.0


func _init(owner: Commando, fuse: float = -1.0) -> void:
	super(owner)
	gesture = true
	delay = fuse


func start() -> void:
	if unit.posture == SoldierModel.Posture.STANDING:
		unit.posture = SoldierModel.Posture.CROUCHED
	left = unit.stats.plant_time


func hands_free() -> bool:
	return true


func update(delta: float) -> Vector3:
	left -= delta
	if left > 0.0:
		return Vector3.ZERO
	finish()
	unit.explosives -= 1
	var at := unit.global_position - unit.global_basis.z * 0.45
	ExplosiveCharge.plant(unit.get_tree().current_scene, at, unit, delay)
	Sfx.play_at(&"clink", at, -10.0)
	EventBus.unit_ammo_changed.emit(unit)
	return Vector3.ZERO
