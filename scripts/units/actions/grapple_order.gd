class_name GrappleOrder
extends CommandoAction
## Grappin : rejoindre le pied de la paroi (`route["foot"]`, voir
## `GrapnelRope.plan`), se tourner vers le point visé, lancer le grappin
## (`ThrowGesture`), puis, une fois accroché, monter jusqu'au point visé par
## la corde.

const REACH := 0.5

var route: Dictionary
var run: bool


func _init(owner: Commando, plan: Dictionary, running: bool) -> void:
	super(owner)
	route = plan
	run = running


func start() -> void:
	unit._running = run
	unit._agent.target_position = route["foot"]


func hands_free() -> bool:
	return true


func look_point() -> Vector3:
	return route["anchor"]


func update(delta: float) -> Vector3:
	if unit.grapnels <= 0:
		finish()
		return Vector3.ZERO
	var foot: Vector3 = route["foot"]
	var to_foot := foot - unit.global_position
	to_foot.y = 0.0
	if to_foot.length() < REACH or (unit._agent.is_navigation_finished() and to_foot.length() < REACH * 2.0):
		var to_anchor: Vector3 = route["anchor"] - unit.global_position
		to_anchor.y = 0.0
		if to_anchor.length() > 0.05:
			unit._face(to_anchor, delta)
		if unit.posture != SoldierModel.Posture.STANDING:
			unit.posture = SoldierModel.Posture.STANDING
		if unit._model.is_weapon_slung() and not unit._model.is_changing_posture() \
				and (-unit.global_basis.z).angle_to(to_anchor) < 0.2:
			var gesture := ThrowGesture.new(unit, null, route["anchor"])
			gesture.release = unit._release_grapnel.bind(route)
			finish(gesture)
		return Vector3.ZERO
	if unit._agent.is_navigation_finished():
		finish()
		return Vector3.ZERO
	return unit._follow_path(delta)
