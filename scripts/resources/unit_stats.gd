class_name UnitStats
extends Resource
## Statistiques d'équilibrage d'une unité.

@export var max_health: float = 100.0
@export var walk_speed: float = 3.0
@export var run_speed: float = 6.0
@export var crouch_speed: float = 1.8
@export var crawl_speed: float = 0.9
@export var turn_speed: float = 12.0
## Durée pour grimper sur un obstacle bas ou en redescendre, en secondes.
@export var climb_time: float = 0.7

@export_group("Arme")
## Portée de tir maximale.
@export var fire_range: float = 16.0
## Délai de visée avant le premier tir, en secondes.
@export var aim_time: float = 0.4
## Intervalle entre deux tirs, en secondes.
@export var fire_interval: float = 0.5
@export var fire_damage: float = 34.0
## Probabilité de toucher à bout portant et à portée maximale.
@export_range(0.0, 1.0) var hit_chance_near: float = 0.95
@export_range(0.0, 1.0) var hit_chance_far: float = 0.6
## Cartouches par chargeur.
@export var magazine_size: int = 10
## Cartouches en réserve au début de la mission (hors chargeur engagé).
@export var reserve_ammo: int = 20
## Durée d'un rechargement, en secondes.
@export var reload_time: float = 2.0
## Rayon du bruit d'un tir (arme équipée d'un silencieux).
@export var gunshot_noise_radius: float = 8.0
