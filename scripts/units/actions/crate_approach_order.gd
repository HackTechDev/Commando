class_name CrateApproachOrder
extends CommandoAction
## Rejoindre le côté `side` d'une caisse (direction du centre vers
## l'opérateur) ; tout près, se glisser au point de prise, face à la caisse,
## et la saisir une fois l'arme à la bretelle (`CrateHoldOrder`).

const GRIP_REACH := 0.75

var crate: Climbable
var side: Vector3


func _init(owner: Commando, target: Climbable, toward: Vector3) -> void:
	super(owner)
	crate = target
	side = toward


func start() -> void:
	unit._agent.target_position = crate.get_access_point(side)


func hands_free() -> bool:
	return true


func update(delta: float) -> Vector3:
	if not is_instance_valid(crate) or crate.occupant != null or not crate.can_take(unit):
		finish()
		return Vector3.ZERO
	var to_grip := CrateHoldOrder.grip_point(crate, side, unit.global_position.y) - unit.global_position
	to_grip.y = 0.0
	if to_grip.length() > GRIP_REACH:
		if unit._agent.is_navigation_finished():
			finish()
			return Vector3.ZERO
		return unit._follow_path(delta)
	unit.posture = SoldierModel.Posture.STANDING
	if to_grip.length() > 0.04:
		unit._face(to_grip, delta)
		return to_grip.normalized() * minf(unit.stats.walk_speed * 0.5, to_grip.length() / delta)
	unit._face(-side, delta)
	if unit._model.is_weapon_slung() and not unit._model.is_changing_posture() and (-unit.global_basis.z).angle_to(-side) < 0.15:
		finish(CrateHoldOrder.new(unit, crate, side))
	return Vector3.ZERO
