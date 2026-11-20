class_name FireAtOrder
extends CommandoAction
## Tir libre sur un point (mur, objet, sol) : s'approcher à portée, épauler,
## puis tirer une rafale de `shots` coups (rechargement compris). Les balles
## s'arrêtent sur le premier obstacle ; un objet destructible (mur fragile,
## caisse, bidon) encaisse les dégâts (`Commando._fire_at_point`).

## Coups d'une rafale.
const BURST := 5

var point: Vector3
var run: bool
var shots_left: int = BURST


func _init(owner: Commando, target: Vector3, running: bool) -> void:
	super(owner)
	point = target
	run = running


func start() -> void:
	unit._running = run
	unit._fire_cooldown = unit.stats.aim_time


func look_point() -> Vector3:
	return point


## L'opérateur épaule pendant toute la rafale.
func is_aiming() -> bool:
	return shots_left > 0


func update(delta: float) -> Vector3:
	if shots_left <= 0:
		finish()
		return Vector3.ZERO
	if not unit._ready_to_fire():
		unit.flash_hint(Commando.Hint.NO_AMMO)
		finish()
		return Vector3.ZERO
	var to_target := point - unit.global_position
	to_target.y = 0.0
	var distance := to_target.length()
	if distance <= unit.stats.fire_range:
		if distance > 0.01:
			unit._face(to_target, delta)
		unit._fire_cooldown -= delta
		if unit.ammo_in_magazine <= 0:
			unit.reload()
		elif not unit.is_reloading() and unit._model.is_weapon_ready() and not unit._model.is_changing_posture() \
				and unit._fire_cooldown <= 0.0 and (distance < 0.5 or (-unit.global_basis.z).angle_to(to_target) < 0.25):
			unit._fire_at_point(point)
			shots_left -= 1
		return Vector3.ZERO
	unit.report_hint(Commando.Hint.OUT_OF_RANGE)
	unit._fire_cooldown = unit.stats.aim_time
	# En vol ou à bord d'un véhicule, on ne s'approche pas : on attend que la
	# cible passe à portée.
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
