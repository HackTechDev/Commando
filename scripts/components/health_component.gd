class_name HealthComponent
extends Node
## Points de vie d'une unité.

signal health_changed(current: float, maximum: float)
signal died

@export var max_health: float = 100.0

var health: float


func _ready() -> void:
	health = max_health


## Vrai tant que l'unité a des points de vie.
func is_alive() -> bool:
	return health > 0.0


## Réinitialise les points de vie à un nouveau maximum.
func reset(new_max: float) -> void:
	max_health = new_max
	health = new_max
	health_changed.emit(health, max_health)


## Inflige des dégâts ; émet `died` quand la vie tombe à zéro.
func take_damage(amount: float) -> void:
	if not is_alive() or amount <= 0.0:
		return
	health = maxf(health - amount, 0.0)
	health_changed.emit(health, max_health)
	if health <= 0.0:
		died.emit()
