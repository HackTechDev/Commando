class_name EnemyStats
extends Resource
## Statistiques d'équilibrage d'un type d'ennemi.

@export var patrol_speed: float = 1.6
@export var turn_speed: float = 6.0
## Pause à chaque point de patrouille, en secondes.
@export var patrol_pause: float = 2.0
## Temps pour remplir la jauge de détection en zone lointaine (à mi-distance).
@export var detection_time: float = 1.6
## Temps pour vider la jauge quand plus rien n'est visible.
@export var forget_time: float = 3.0
## Seuil de jauge à partir duquel l'ennemi devient suspicieux.
@export_range(0.0, 1.0) var suspicion_threshold: float = 0.2
## Durée pendant laquelle l'alerte persiste après la perte de vue.
@export var alert_memory: float = 4.0
