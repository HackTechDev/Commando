class_name StrikeGesture
extends CommandoAction
## Coup porté à `enemy` au corps à corps. Par derrière (ennemi debout),
## c'est une prise : l'opérateur se glisse contre la victime, qui est
## immobilisée, puis l'étrangle ou l'égorge. De face, c'est un coup de
## couteau, de crosse, de poing ou de pied.

## Instants (0 à 1) où l'étranglement et l'égorgement neutralisent la victime.
const CHOKE_HIT_TIME := 0.85
const THROAT_CUT_HIT_TIME := 0.6
## Durée (s) du glissement de l'opérateur contre la victime d'une prise.
const GRAB_SLIDE_TIME := 0.15

var enemy: Enemy
var kind: Commando.MeleeKind
## Prise par derrière (étranglement, égorgement).
var grapple: bool = false
var left: float = 0.0
var landed: bool = false
var _duration: float = 1.0
var _hit_time: float = Commando.STRIKE_HIT_TIME
var _grab_from: Vector3
var _grab_to: Vector3


func _init(owner: Commando, target: Enemy, how: Commando.MeleeKind) -> void:
	super(owner)
	gesture = true
	interruptible = false
	enemy = target
	kind = how


func hands_free() -> bool:
	return kind == Commando.MeleeKind.KNIFE or grapple


func look_point() -> Vector3:
	return enemy_point(enemy)


func start() -> void:
	var model := unit._model
	model.strike_with_knife = kind == Commando.MeleeKind.KNIFE
	# Un ennemi déjà au sol s'achève sans prise.
	grapple = not enemy.is_stunned() and enemy.is_behind(unit.global_position)
	if grapple:
		unit.posture = SoldierModel.Posture.STANDING
		enemy.grab()
		unit.add_collision_exception_with(enemy)
		_grab_from = unit.global_position
		_grab_to = enemy.global_position + enemy.global_basis.z * SoldierModel.GRAB_DISTANCE
		_grab_to.y = unit.global_position.y
		unit.rotation.y = enemy.rotation.y
		if kind == Commando.MeleeKind.KNIFE:
			model.strike_move = SoldierModel.StrikeMove.THROAT_CUT
			_duration = unit.stats.throat_cut_time
			_hit_time = THROAT_CUT_HIT_TIME
		else:
			model.strike_move = SoldierModel.StrikeMove.CHOKE
			_duration = unit.stats.choke_time
			_hit_time = CHOKE_HIT_TIME
	else:
		_duration = unit.stats.melee_time
		# On ne frappe pas allongé : l'opérateur se met à genoux.
		if unit.posture == SoldierModel.Posture.PRONE:
			unit.posture = SoldierModel.Posture.CROUCHED
		if kind == Commando.MeleeKind.KNOCKOUT:
			model.strike_move = _pick_move()
		elif model.strike_move == SoldierModel.StrikeMove.CHOKE or model.strike_move == SoldierModel.StrikeMove.THROAT_CUT:
			model.strike_move = SoldierModel.StrikeMove.UPPERCUT
	left = _duration
	model.strike_progress = 0.0


## Coup pour assommer : coup de crosse arme en main ; à mains nues (arme à
## la bretelle), tiré au hasard, jamais deux fois de suite le même, et
## uppercut seulement hors de la position debout.
func _pick_move() -> SoldierModel.StrikeMove:
	if not unit.weapon_slung:
		return SoldierModel.StrikeMove.BUTT_STRIKE
	if unit.posture != SoldierModel.Posture.STANDING:
		return SoldierModel.StrikeMove.UPPERCUT
	var moves: Array = [SoldierModel.StrikeMove.UPPERCUT, SoldierModel.StrikeMove.FRONT_KICK,
			SoldierModel.StrikeMove.ROUNDHOUSE, SoldierModel.StrikeMove.SIDE_KICK]
	moves.erase(unit._model.strike_move)
	return moves.pick_random()


func update(delta: float) -> Vector3:
	left = maxf(left - delta, 0.0)
	var progress := 1.0 - left / _duration
	unit._model.strike_progress = progress
	if grapple:
		var slide := smoothstep(0.0, 1.0, minf(progress * _duration / GRAB_SLIDE_TIME, 1.0))
		unit.global_position = _grab_from.lerp(_grab_to, slide)
		unit.velocity = Vector3.ZERO
	elif is_instance_valid(enemy):
		unit._face(enemy.global_position - unit.global_position, delta)
	if not landed and progress >= _hit_time:
		landed = true
		_land()
	if left <= 0.0:
		cancel()
		finish()
	return Vector3.ZERO


## Fin du geste (ou abandon, si l'opérateur est tué) : la victime d'une prise
## n'est plus tenue ; si elle n'a pas été neutralisée, elle se dégage.
func cancel() -> void:
	unit._model.strike_progress = -1.0
	if not grapple:
		return
	grapple = false
	if is_instance_valid(enemy):
		unit.remove_collision_exception_with(enemy)
		if not landed:
			enemy.release()


func _land() -> void:
	if not is_instance_valid(enemy) or enemy.is_dead:
		return
	var stats := unit.stats
	if grapple:
		# Par derrière : sans un bruit, la victime s'effondre vers l'avant.
		match kind:
			Commando.MeleeKind.KNIFE:
				enemy.kill_silently(true)
				Sfx.play_at(&"knife", enemy.global_position + Vector3.UP * 1.4, -12.0)
			Commando.MeleeKind.KNOCKOUT:
				enemy.knock_out(true)
		return
	var offset := enemy.global_position - unit.global_position
	offset.y = 0.0
	if offset.length() > Commando.MELEE_RANGE + Commando.STRIKE_REACH_MARGIN:
		return
	match kind:
		Commando.MeleeKind.KNIFE:
			# De face, la victime a le temps de crier.
			enemy.kill_silently()
			EventBus.noise_emitted.emit(unit.global_position, stats.knife_front_noise_radius, &"scream")
			Sfx.play_at(&"knife", enemy.global_position + Vector3.UP * 1.2, -2.0)
		Commando.MeleeKind.KNOCKOUT:
			enemy.knock_out()
			Sfx.play_at(&"punch", enemy.global_position + Vector3.UP * 1.4)
			EventBus.noise_emitted.emit(unit.global_position, stats.melee_noise_radius, &"melee")
