class_name LauncherOrder
extends CommandoAction
## Tir au lance-grenades M320 (sous le canon) sur un point : s'approcher à
## portée (`Commando.LAUNCHER_RANGE`), épauler, puis tirer un obus de 40 mm
## qui éclate à l'impact (`Grenade.launch`). Un point trop proche
## (`Commando.LAUNCHER_MIN_RANGE`) est refusé : l'obus ne s'arme pas si
## près.

var point: Vector3
var run: bool
var _fired: bool = false


func _init(owner: Commando, target: Vector3, running: bool) -> void:
	super(owner)
	point = target
	run = running


func start() -> void:
	unit._running = run
	unit._fire_cooldown = Commando.LAUNCHER_AIM_TIME


func look_point() -> Vector3:
	return point


func is_aiming() -> bool:
	return not _fired


func update(delta: float) -> Vector3:
	if _fired or unit.launcher_grenades <= 0:
		finish()
		return Vector3.ZERO
	if unit.using_secondary:
		if not unit.switch_weapon():
			finish()
		return Vector3.ZERO
	var to_target := point - unit.global_position
	to_target.y = 0.0
	var distance := to_target.length()
	if distance <= Commando.LAUNCHER_RANGE:
		if distance > 0.01:
			unit._face(to_target, delta)
		unit._fire_cooldown -= delta
		if not unit.is_reloading() and unit._model.is_weapon_ready() and not unit._model.is_changing_posture() \
				and unit._fire_cooldown <= 0.0 and (-unit.global_basis.z).angle_to(to_target) < 0.2:
			unit._fire_launcher(point)
			_fired = true
		return Vector3.ZERO
	unit.report_hint(Commando.Hint.OUT_OF_RANGE)
	unit._fire_cooldown = Commando.LAUNCHER_AIM_TIME
	if unit.airborne_in or unit.riding:
		return Vector3.ZERO
	if unit.perched_on:
		unit._descend(point, func() -> void: pass)
		return Vector3.ZERO
	if unit._agent.target_position.distance_to(point) > 0.5:
		unit._agent.target_position = point
	if unit._agent.is_navigation_finished():
		finish()
		return Vector3.ZERO
	return unit._follow_path(delta)
