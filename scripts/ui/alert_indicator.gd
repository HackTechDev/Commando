extends Label
## Indicateur d'alerte global du HUD.


func _ready() -> void:
	GameState.alert_level_changed.connect(_on_alert_level_changed)
	_on_alert_level_changed(GameState.alert_level)
	EventBus.unit_died.connect(_on_unit_died)


var _failed: bool = false


func _on_unit_died(_unit: Node3D) -> void:
	_failed = true
	text = "ÉCHEC — opérateur tué"
	modulate = Color(1.0, 0.25, 0.2)


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
