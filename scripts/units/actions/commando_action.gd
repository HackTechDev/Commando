class_name CommandoAction
extends RefCounted
## Action d'un opérateur (`Commando`). Il y en a deux sortes :
## - les ordres (se déplacer, attaquer, s'approcher pour grimper, frapper ou
##   lancer, tenir une caisse) : un nouvel ordre remplace le précédent ;
## - les gestes (frappe, lancer, pose de charge, soins, ramassage, parade,
##   recul) : ils passent avant l'ordre, qui reprend ensuite. Un geste
##   `interruptible` est annulé par un nouvel ordre ; les autres vont à leur
##   terme.
## Une action se termine en passant `done` à vrai ; elle peut alors confier
## la suite à `next` (une approche qui débouche sur une frappe, par exemple).

var unit: Commando
## Vrai pour un geste, faux pour un ordre.
var gesture: bool = false
var interruptible: bool = true
var done: bool = false
## Action qui prend le relais une fois celle-ci terminée (null : aucune).
var next: CommandoAction


func _init(owner: Commando) -> void:
	unit = owner


## Appelée quand l'action devient l'action en cours.
func start() -> void:
	pass


## Avance l'action d'une image ; renvoie la vitesse horizontale voulue.
func update(_delta: float) -> Vector3:
	return Vector3.ZERO


## Nettoyage quand l'action est abandonnée avant la fin (nouvel ordre, mort).
func cancel() -> void:
	pass


## Vrai si l'action demande les mains libres (arme à la bretelle).
func hands_free() -> bool:
	return false


## Point regardé pendant l'action (`Vector3.INF` : aucun).
func look_point() -> Vector3:
	return Vector3.INF


## Termine l'action, avec éventuellement une suite.
func finish(then: CommandoAction = null) -> void:
	done = true
	next = then


## Point de visée sur un ennemi encore debout, sinon `Vector3.INF`.
static func enemy_point(enemy: Enemy) -> Vector3:
	if is_instance_valid(enemy) and not enemy.is_dead:
		return enemy.global_position + Vector3.UP * 1.5
	return Vector3.INF
