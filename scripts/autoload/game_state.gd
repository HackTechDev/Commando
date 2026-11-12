extends Node
## État global de la partie : mission courante et niveau d'alerte.

enum AlertLevel { CALM, SUSPICION, ALARM }

signal alert_level_changed(level: AlertLevel)

var alert_level: AlertLevel = AlertLevel.CALM:
	set(value):
		if value != alert_level:
			alert_level = value
			alert_level_changed.emit(alert_level)
