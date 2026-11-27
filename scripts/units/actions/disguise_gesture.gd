class_name DisguiseGesture
extends CommandoAction
## Revêt l'uniforme d'un ennemi assommé (`Enemy.strip_uniform`) : accroupi
## près de lui le temps d'échanger les tenues, puis l'opérateur passe pour
## un garde (`Commando.wear_disguise`). Abandonné si le corps est emporté,
## s'il se réveille, ou sur nouvel ordre.

## Durée de l'échange (s), et distance maximale au corps (m).
const TIME := 5.0
const REACH := 1.8

var enemy: Enemy
var left: float = 0.0


func _init(owner: Commando, target: Enemy) -> void:
	super(owner)
	gesture = true
	enemy = target


func start() -> void:
	if unit.posture == SoldierModel.Posture.STANDING:
		unit.posture = SoldierModel.Posture.CROUCHED
	left = TIME
	Sfx.play_at(&"bandage", unit.global_position + Vector3.UP * 0.5, -8.0)


func hands_free() -> bool:
	return true


func look_point() -> Vector3:
	return enemy.global_position if is_instance_valid(enemy) else unit.global_position


func update(delta: float) -> Vector3:
	if not Enemy.can_be_stripped(enemy) or enemy.global_position.distance_to(unit.global_position) > REACH:
		finish()
		return Vector3.ZERO
	unit._face(enemy.global_position - unit.global_position, delta)
	left -= delta
	if left > 0.0:
		return Vector3.ZERO
	finish()
	unit.wear_disguise(enemy.strip_uniform())
	unit.posture = SoldierModel.Posture.STANDING
	unit.flash_message("En uniforme ennemi : au pas, debout ; l'officier et le chien ne s'y trompent pas")
	return Vector3.ZERO
