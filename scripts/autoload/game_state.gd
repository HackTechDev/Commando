extends Node
## État global de la partie : mission courante et niveau d'alerte.

enum AlertLevel { CALM, SUSPICION, ALARM }

signal alert_level_changed(level: AlertLevel)

var alert_level: AlertLevel = AlertLevel.CALM:
	set(value):
		if value != alert_level:
			alert_level = value
			alert_level_changed.emit(alert_level)


## Recalcule le niveau d'alerte global d'après l'état des ennemis.
func refresh_alert() -> void:
	var level := AlertLevel.CALM
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		if enemy == null:
			continue
		if enemy.state == Enemy.State.ALERT:
			level = AlertLevel.ALARM
		elif enemy.state == Enemy.State.SUSPICIOUS and level == AlertLevel.CALM:
			level = AlertLevel.SUSPICION
	alert_level = level
