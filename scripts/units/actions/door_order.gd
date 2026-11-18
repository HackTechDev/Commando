class_name DoorOrder
extends CommandoAction
## Rejoindre une porte, du côté le plus proche, puis l'ouvrir ou la fermer.
## Verrouillée, l'opérateur la crochète d'abord, accroupi (`LOCKPICK_TIME`).

## Distance au point d'arrivée (côté de la porte) où l'on agit.
const REACH := 0.35
## Durée d'un crochetage, et de la main sur la poignée.
const LOCKPICK_TIME := 4.0
const HANDLE_TIME := 0.4

var door: Door
var run: bool
var spot: Vector3
## Temps restant du geste en cours (crochetage ou poignée), -1 : en route.
var left: float = -1.0
var picking: bool = false


func _init(owner: Commando, target: Door, running: bool) -> void:
	super(owner)
	door = target
	run = running


func start() -> void:
	unit._running = run
	spot = door.near_side(unit.global_position)
	unit._agent.target_position = spot


func look_point() -> Vector3:
	return door.global_position + Vector3.UP if is_instance_valid(door) else Vector3.INF


## Vrai pendant le crochetage (barre de progression, tests).
func progress() -> float:
	return 1.0 - left / LOCKPICK_TIME if picking and left >= 0.0 else -1.0


func update(delta: float) -> Vector3:
	if not is_instance_valid(door) or door.is_broken:
		finish()
		return Vector3.ZERO
	if left >= 0.0:
		left -= delta
		if left > 0.0:
			return Vector3.ZERO
		if picking:
			door.open_from(unit.global_position)
		else:
			door.toggle_from(unit.global_position)
		finish()
		return Vector3.ZERO
	var offset := spot - unit.global_position
	offset.y = 0.0
	if offset.length() <= REACH:
		var to_door := door.global_position - unit.global_position
		to_door.y = 0.0
		unit.rotation.y = atan2(-to_door.x, -to_door.z)
		if not door.is_open and door.is_locked:
			picking = true
			left = LOCKPICK_TIME
			if unit.posture == SoldierModel.Posture.STANDING:
				unit.posture = SoldierModel.Posture.CROUCHED
			Sfx.play_at(&"clink", door.global_position + Vector3.UP, -14.0)
		else:
			left = HANDLE_TIME
		return Vector3.ZERO
	if unit._agent.is_navigation_finished():
		# Arrivé aussi près que possible : agir si la porte est à portée.
		if offset.length() <= 1.0:
			spot = unit.global_position
			return Vector3.ZERO
		finish()
		return Vector3.ZERO
	return unit._follow_path(delta)
