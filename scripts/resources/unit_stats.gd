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
## Durée d'un saut du haut d'un mur (accroupi, vol, amorti), en secondes.
@export var jump_time: float = 1.7
## Rayon du bruit de la réception d'un saut.
@export var jump_noise_radius: float = 4.0
## Vitesses pour pousser et tirer une caisse, en m/s.
@export var crate_push_speed: float = 1.0
@export var crate_pull_speed: float = 0.8
## Rayon du bruit d'une caisse qui frotte au sol.
@export var crate_noise_radius: float = 3.0

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
## Couteaux de lancer emportés (à ramasser après chaque lancer).
@export var throwing_knives: int = 1
## Portée maximale du lancer, et distance jusqu'à laquelle il porte toujours.
@export var throw_range: float = 7.0
@export var throw_sure_range: float = 4.0
## Chance de toucher à portée maximale.
@export_range(0.0, 1.0) var throw_hit_chance_far: float = 0.7
## Durée du geste de lancer, en secondes.
@export var throw_time: float = 0.8
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
## Dégâts à portée maximale (plombs dispersés) ; négatif : les mêmes qu'à bout
## portant. Entre les deux, ils baissent avec la distance (`damage_at`).
@export var fire_damage_far: float = -1.0
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
## Arme équipée d'un silencieux (son du tir).
@export var suppressed: bool = true

@export_group("Équipement")
## Grenades, charges explosives et trousses de soins emportées.
@export var grenades: int = 0
@export var smoke_grenades: int = 0
@export var hatchets: int = 0
@export var explosives: int = 0
@export var medkits: int = 0
## Bouclier balistique (0 ou 1).
@export var shields: int = 0
## Grappin (0 ou 1) : lancé vers un point en hauteur, sa corde permet d'y monter.
@export var grapnels: int = 0
## Portée du lancer de grenade (m), délai entre l'impact et l'explosion (s).
@export var grenade_range: float = 12.0
@export var grenade_fuse: float = 1.0
## Dégâts au centre et rayon de l'explosion d'une grenade (décroissance linéaire).
@export var grenade_damage: float = 150.0
@export var grenade_radius: float = 4.0
## Dégâts, rayon et durée de pose d'une charge explosive.
@export var explosive_damage: float = 300.0
@export var explosive_radius: float = 5.0
@export var plant_time: float = 1.6
## Rayon du bruit d'une explosion.
@export var explosion_noise_radius: float = 30.0
## Soins d'une trousse, durée et distance jusqu'au blessé.
@export var heal_amount: float = 50.0
@export var heal_time: float = 2.0
@export var heal_range: float = 2.2
## Bruit des pas en course, debout (rayon, 0 : aucun ; type `run`), et
## intervalle entre deux bruits. Marcher, accroupi ou couché, est silencieux.
@export var run_noise_radius: float = 2.5
@export var run_noise_interval: float = 0.5
## Bruit de l'équipement qui s'entrechoque en courant (rayon, 0 : aucun) et
## intervalle entre deux bruits (charge lourde).
@export var gear_noise_radius: float = 0.0
@export var gear_noise_interval: float = 0.6


## Dégâts d'un tir qui touche à `distance` mètres.
func damage_at(distance: float) -> float:
	if fire_damage_far < 0.0:
		return fire_damage
	return lerpf(fire_damage, fire_damage_far, clampf(distance / fire_range, 0.0, 1.0))
