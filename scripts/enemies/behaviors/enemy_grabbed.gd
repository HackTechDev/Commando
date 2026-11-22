class_name EnemyGrabbed
extends EnemyBehavior
## Saisi par derrière (étranglé, égorgé, ou tenu en otage) : immobile et
## aveugle, il appelle à l'aide ; les ennemis qui l'entendent accourent.

## Premier cri après `HELP_DELAY` secondes, puis toutes les `HELP_INTERVAL`
## secondes. Tenu en otage, il crie à pleine voix (`HELP_RADIUS`) ;
## étranglé, son cri est étouffé (`HELP_RADIUS_MUFFLED`).
const HELP_DELAY := 1.2
const HELP_INTERVAL := 2.5
const HELP_RADIUS := 12.0
const HELP_RADIUS_MUFFLED := 4.0

var help_left: float = 0.0


func takes_over() -> bool:
	return true


func enter() -> void:
	help_left = HELP_DELAY


func update(delta: float) -> Vector3:
	enemy.velocity = Vector3.ZERO
	help_left -= delta
	if help_left <= 0.0:
		help_left = HELP_INTERVAL
		_cry_for_help()
	return Vector3.ZERO


func _cry_for_help() -> void:
	enemy.cries += 1
	var muffled := enemy.captor == null
	var at := enemy.global_position
	Sfx.play_at(&"cry", at + Vector3.UP * 1.6, -10.0 if muffled else 0.0)
	EventBus.noise_emitted.emit(at, HELP_RADIUS_MUFFLED if muffled else HELP_RADIUS, &"help")
