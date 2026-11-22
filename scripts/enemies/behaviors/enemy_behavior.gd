class_name EnemyBehavior
extends RefCounted
## Un état de la machine à états d'un ennemi (`Enemy.behavior`) : ce qu'il
## fait en ce moment (ronde, méfiance, enquête, fouille, retour, poursuite,
## ou neutralisé). `Enemy` choisit l'état selon sa vigilance (`Enemy.State`)
## et l'activité en cours (`_sync_behavior`), appelle `exit` puis `enter` à
## chaque transition, et `update` à chaque image physique.
##
## Les données propres à un état (minuteurs, points à visiter) vivent dans
## l'état ; la perception (vue, ouïe, jauge), le tir (`EnemyGunner`) et le
## corps à corps (`EnemyBrawler`) restent communs.

var enemy: Enemy


func _init(owner: Enemy) -> void:
	enemy = owner


## Activité sauvegardée et affichée (`Enemy.Activity`).
func activity() -> Enemy.Activity:
	return Enemy.Activity.NONE


## Vrai si l'état prend toute l'image (neutralisé) : ni sens, ni tir, ni
## corps à corps ; seul `update` tourne.
func takes_over() -> bool:
	return false


func enter() -> void:
	pass


func exit() -> void:
	pass


## Une image physique : vitesse horizontale voulue.
func update(_delta: float) -> Vector3:
	return Vector3.ZERO
