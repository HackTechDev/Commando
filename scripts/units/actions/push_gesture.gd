class_name PushGesture
extends CommandoAction
## Déplacement subi (repoussé par un ennemi, pas de côté d'une esquive) :
## `offset` parcouru en `duration` secondes après `delay` secondes, avec
## réaction au choc venu de `hit_from` (`Vector3.INF` : aucun).

const HIT_STRENGTH := 1.8

var offset: Vector3
var duration: float
var delay: float
var hit_from: Vector3
var _left: float


func _init(owner: Commando, move: Vector3, time: float, wait: float, from: Vector3 = Vector3.INF) -> void:
	super(owner)
	gesture = true
	interruptible = false
	offset = move
	duration = time
	delay = wait
	hit_from = from
	_left = time


func update(delta: float) -> Vector3:
	if delay > 0.0:
		delay -= delta
		if delay <= 0.0 and hit_from != Vector3.INF:
			unit._model.play_hit(hit_from, HIT_STRENGTH)
			Sfx.play_at(&"punch", unit.global_position + Vector3.UP * 1.2, -6.0)
		return Vector3.ZERO
	_left = maxf(_left - delta, 0.0)
	if _left <= 0.0:
		finish()
	# Vitesse décroissante : départ brusque, arrêt en douceur.
	return offset / duration * 2.0 * (_left / duration)
