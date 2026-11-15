class_name HealGesture
extends CommandoAction
## Soins de `patient` (l'opérateur lui-même ou un blessé à portée) avec une
## trousse. Abandonnés si le blessé s'éloigne ou meurt, ou sur nouvel ordre.

var patient: Commando
var left: float = 0.0


func _init(owner: Commando, wounded: Commando) -> void:
	super(owner)
	gesture = true
	patient = wounded


func start() -> void:
	left = unit.stats.heal_time
	Sfx.play_at(&"bandage", unit.global_position + Vector3.UP, -6.0)


func hands_free() -> bool:
	return true


func update(delta: float) -> Vector3:
	if not is_instance_valid(patient) or patient.is_dead or patient.global_position.distance_to(unit.global_position) > unit.stats.heal_range + 0.5:
		finish()
		return Vector3.ZERO
	if patient != unit:
		unit._face(patient.global_position - unit.global_position, delta)
	left -= delta
	if left > 0.0:
		return Vector3.ZERO
	finish()
	unit.medkits -= 1
	patient.health.heal(unit.stats.heal_amount)
	EventBus.unit_ammo_changed.emit(unit)
	return Vector3.ZERO
