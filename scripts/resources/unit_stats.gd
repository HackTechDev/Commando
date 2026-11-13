class_name UnitStats
extends Resource
## Statistiques d'équilibrage d'une unité.

@export var max_health: float = 100.0
@export var walk_speed: float = 3.0
@export var run_speed: float = 6.0
@export var crouch_speed: float = 1.8
@export var crawl_speed: float = 0.9
@export var turn_speed: float = 12.0
## Durée pour grimper sur un obstacle bas, en secondes.
@export var climb_time: float = 1.4
## Durée pour en redescendre, en secondes.
@export var descend_time: float = 1.0

@export_group("Corps à corps")
## Durée d'une attaque au couteau ou d'un coup pour assommer, en secondes.
@export var melee_time: float = 0.6
## Rayon du bruit d'une élimination au corps à corps.
@export var melee_noise_radius: float = 1.5
## Rayon du bruit d'un coup de couteau porté de face (la victime crie).
@export var knife_front_noise_radius: float = 6.0
## Durée d'un étranglement par derrière, en secondes.
@export var choke_time: float = 2.5
## Durée d'un égorgement par derrière, en secondes.
@export var throat_cut_time: float = 1.0
## Chances de parer et d'esquiver un coup ennemi (sinon il encaisse).
@export_range(0.0, 1.0) var parry_chance: float = 0.45
@export_range(0.0, 1.0) var dodge_chance: float = 0.35
## Durée d'une parade ou d'une esquive, en secondes.
@export var defend_time: float = 0.5

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
