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
## Très courte portée (m) : en deçà, ou pour un contre, l'opérateur frappe du
## coude ou du genou (saisie par la nuque) en s'avançant à `CLOSE_DISTANCE`
## de la cible pendant le premier quart du geste.
const CLOSE_RANGE := 0.95
const CLOSE_DISTANCE := 0.7
const CLOSE_STEP := 0.25
## Durée de chaque coup, rapportée à `melee_time`.
const MOVE_DURATIONS := {
	SoldierModel.StrikeMove.ELBOW: 0.9,
	SoldierModel.StrikeMove.KNEE: 1.1,
	SoldierModel.StrikeMove.JAB_HOOK: 1.6,
}

var enemy: Enemy
var kind: Commando.MeleeKind
## Prise par derrière (étranglement, égorgement).
var grapple: bool = false
var left: float = 0.0
var landed: bool = false
## Premier coup d'un enchaînement (direct) porté.
var _first_landed: bool = false
var _first_hit_time: float = -1.0
var _duration: float = 1.0
var _hit_time: float = Commando.STRIKE_HIT_TIME
var _grab_from: Vector3
var _grab_to: Vector3
## Coup imposé (`SoldierModel.StrikeMove`) au lieu du tirage ; -1 : tirage.
var forced_move: int = -1
## Coup à très courte portée (coude, genou) : l'opérateur s'avance d'abord.
var _close: bool = false
var _step_from: Vector3
var _step_to: Vector3


## `close_quarters` : contre sur un assaillant déséquilibré, au contact.
func _init(owner: Commando, target: Enemy, how: Commando.MeleeKind, close_quarters: bool = false) -> void:
	super(owner)
	gesture = true
	interruptible = false
	enemy = target
	kind = how
	_close = close_quarters


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
		var offset := enemy.global_position - unit.global_position
		offset.y = 0.0
		_close = _close or offset.length() < CLOSE_RANGE
		if kind == Commando.MeleeKind.KNOCKOUT:
			model.strike_move = _pick_move() if forced_move < 0 else forced_move as SoldierModel.StrikeMove
			_duration *= MOVE_DURATIONS.get(model.strike_move, 1.0)
			_hit_time = SoldierModel.MOVE_HIT_TIMES.get(model.strike_move, _hit_time)
			_first_hit_time = SoldierModel.MOVE_FIRST_HIT.get(model.strike_move, -1.0)
			if model.strike_move in [SoldierModel.StrikeMove.ELBOW, SoldierModel.StrikeMove.KNEE]:
				_step_from = unit.global_position
				_step_to = enemy.global_position - offset.normalized() * minf(CLOSE_DISTANCE, offset.length())
				_step_to.y = unit.global_position.y
			else:
				_close = false
		else:
			# Au couteau : pas de pas en avant.
			_close = false
			if model.strike_move == SoldierModel.StrikeMove.CHOKE or model.strike_move == SoldierModel.StrikeMove.THROAT_CUT:
				model.strike_move = SoldierModel.StrikeMove.UPPERCUT
	left = _duration
	model.strike_progress = 0.0


## Coup pour assommer : coup de crosse arme en main ; à mains nues (arme à
## la bretelle), tiré au hasard, jamais deux fois de suite le même :
## coude ou genou à très courte portée, sinon uppercut, enchaînement
## direct + crochet ou coup de pied ; uppercut
## seulement hors de la position debout.
func _pick_move() -> SoldierModel.StrikeMove:
	if not unit.weapon_slung:
		return SoldierModel.StrikeMove.BUTT_STRIKE
	if unit.posture != SoldierModel.Posture.STANDING:
		return SoldierModel.StrikeMove.UPPERCUT
	var moves: Array = [SoldierModel.StrikeMove.UPPERCUT, SoldierModel.StrikeMove.FRONT_KICK,
			SoldierModel.StrikeMove.ROUNDHOUSE, SoldierModel.StrikeMove.SIDE_KICK, SoldierModel.StrikeMove.JAB_HOOK]
	if _close:
		moves = [SoldierModel.StrikeMove.ELBOW, SoldierModel.StrikeMove.KNEE]
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
		if _close:
			# Pas en avant, au contact de la cible.
			var step := smoothstep(0.0, 1.0, minf(progress / CLOSE_STEP, 1.0))
			unit.global_position = _step_from.lerp(_step_to, step)
			unit.velocity = Vector3.ZERO
		unit._face(enemy.global_position - unit.global_position, delta)
	if not _first_landed and _first_hit_time >= 0.0 and progress >= _first_hit_time:
		# Direct : il touche, la cible encaisse, mais tient debout.
		_first_landed = true
		if is_instance_valid(enemy) and not enemy.is_dead:
			Sfx.play_at(&"punch", enemy.global_position + Vector3.UP * 1.5, -6.0)
			enemy._model.play_hit(unit.global_position, 0.6)
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
