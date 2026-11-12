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
## Durée d'attente au dernier point connu de la cible avant de reprendre la patrouille.
@export var alert_memory: float = 4.0
@export var chase_speed: float = 4.2
## Portée de tir maximale.
@export var fire_range: float = 14.0
## Distance à laquelle l'ennemi cesse d'avancer pour tirer.
@export var hold_range: float = 8.0
## Délai de visée avant le premier tir, en secondes.
@export var aim_time: float = 0.6
## Intervalle entre deux tirs, en secondes.
@export var fire_interval: float = 0.7
@export var fire_damage: float = 25.0
## Probabilité de toucher à bout portant et à portée maximale.
@export_range(0.0, 1.0) var hit_chance_near: float = 0.85
@export_range(0.0, 1.0) var hit_chance_far: float = 0.35
## Rayon du bruit d'un coup de feu.
@export var gunshot_noise_radius: float = 30.0
