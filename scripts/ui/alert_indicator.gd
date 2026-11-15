extends Label
## Indicateur d'alerte global du HUD.


func _ready() -> void:
	GameState.alert_level_changed.connect(_on_alert_level_changed)
	_on_alert_level_changed(GameState.alert_level)
	EventBus.unit_died.connect(_on_unit_died)
	EventBus.mission_ended.connect(_on_mission_ended)


var _failed: bool = false


func _on_unit_died(unit: Node3D) -> void:
	if _failed:
		return
	_failed = true
	text = "ÉCHEC — %s tué" % (unit as Commando).display_name if unit is Commando else "ÉCHEC — opérateur tué"
	modulate = Color(1.0, 0.25, 0.2)


## Fin de mission (VIP évacué ou tué) : le message reste affiché.
func _on_mission_ended(success: bool, message: String) -> void:
	if _failed:
		return
	_failed = true
	text = message
	modulate = Color(0.4, 0.9, 0.45) if success else Color(1.0, 0.25, 0.2)


func _on_alert_level_changed(level: GameState.AlertLevel) -> void:
	if _failed:
		return
	match level:
		GameState.AlertLevel.CALM:
			text = "CALME"
			modulate = Color(0.4, 0.9, 0.45)
		GameState.AlertLevel.SUSPICION:
			text = "SUSPICION"
			modulate = Color(1.0, 0.8, 0.15)
		GameState.AlertLevel.ALARM:
			text = "REPÉRÉ !"
			modulate = Color(1.0, 0.25, 0.2)
