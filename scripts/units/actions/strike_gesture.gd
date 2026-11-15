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
## Balayage : la cible tombe, sonnée cette part seulement de `stun_duration`.
const SWEEP_STUN_RATIO := 0.3
## Projection : la cible, saisie, passe par-dessus la hanche entre ces
## instants (0 à 1) pour retomber à `THROW_DISTANCE` devant l'opérateur,
## sonnée `THROW_STUN` secondes, le temps qu'il la frappe au sol.
const THROW_LIFT := 0.2
const THROW_LAND := 0.5
const THROW_DISTANCE := 1.1
const THROW_HEIGHT := 0.5
const THROW_STUN := 4.0
## Frappe au sol : à cette distance, sur le côté de la poitrine, elle-même à
## `CHEST_OFFSET` des pieds.
const GROUND_DISTANCE := 0.55
const CHEST_OFFSET := 0.75
const MOVE_DURATIONS := {
	SoldierModel.StrikeMove.SWEEP: 1.3,
	SoldierModel.StrikeMove.HIP_THROW: 2.0,
	SoldierModel.StrikeMove.GROUND_PUNCH: 1.2,
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
## Projection : trajet de la cible, et frappe au sol qui suit.
var _throw_from: Vector3
var _throw_to: Vector3
var _follow_up: CommandoAction
var _thrown: bool = false
## Point regardé pendant la frappe au sol (poitrine de l'homme à terre).
var _aim_point: Vector3 = Vector3.INF


## `close_quarters` : contre sur un assaillant déséquilibré, au contact.
func _init(owner: Commando, target: Enemy, how: Commando.MeleeKind, close_quarters: bool = false) -> void:
	super(owner)
	gesture = true
	interruptible = false
	enemy = target
	kind = how
	_close = close_quarters


func hands_free() -> bool:
	return kind != Commando.MeleeKind.KNOCKOUT or grapple or unit._model.strike_move == SoldierModel.StrikeMove.GROUND_PUNCH


func look_point() -> Vector3:
	return _aim_point if _aim_point != Vector3.INF else enemy_point(enemy)


func start() -> void:
	var model := unit._model
	model.strike_with_knife = kind == Commando.MeleeKind.KNIFE
	# Un ennemi déjà au sol s'achève sans prise ; le balayage n'en est pas une.
	grapple = kind in [Commando.MeleeKind.KNIFE, Commando.MeleeKind.KNOCKOUT] and not enemy.is_stunned() and enemy.is_behind(unit.global_position)
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
		if kind == Commando.MeleeKind.SWEEP:
			# Coup de pied bas, accroupi en pivotant : debout pour s'élancer.
			unit.posture = SoldierModel.Posture.STANDING
			forced_move = SoldierModel.StrikeMove.SWEEP
		elif kind == Commando.MeleeKind.THROW:
			# Saisie de face : la cible ne se débat plus, elle va passer
			# par-dessus la hanche de l'opérateur.
			unit.posture = SoldierModel.Posture.STANDING
			forced_move = SoldierModel.StrikeMove.HIP_THROW
			enemy.grab()
			unit.add_collision_exception_with(enemy)
			_throw_from = enemy.global_position
			_throw_to = unit.global_position + offset.normalized() * THROW_DISTANCE
			_throw_to.y = enemy.global_position.y
		elif forced_move == SoldierModel.StrikeMove.GROUND_PUNCH:
			# Accroupi à côté de la poitrine (le corps est couché sur le dos,
			# tête vers son +Z), frappe vers le sol.
			unit.posture = SoldierModel.Posture.STANDING
			_close = true
			var chest := enemy.global_position + enemy.global_basis.z * CHEST_OFFSET
			var side := enemy.global_basis.x
			if side.dot(unit.global_position - chest) < 0.0:
				side = -side
			_aim_point = chest
			_step_from = unit.global_position
			_step_to = chest + side * GROUND_DISTANCE
			_step_to.y = unit.global_position.y
		if kind != Commando.MeleeKind.KNIFE:
			model.strike_move = _pick_move() if forced_move < 0 else forced_move as SoldierModel.StrikeMove
			_duration *= MOVE_DURATIONS.get(model.strike_move, 1.0)
			_hit_time = SoldierModel.MOVE_HIT_TIMES.get(model.strike_move, _hit_time)
			_first_hit_time = SoldierModel.MOVE_FIRST_HIT.get(model.strike_move, -1.0)
			if model.strike_move == SoldierModel.StrikeMove.GROUND_PUNCH:
				pass
			elif model.strike_move in [SoldierModel.StrikeMove.ELBOW, SoldierModel.StrikeMove.KNEE]:
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
	elif kind == Commando.MeleeKind.THROW and is_instance_valid(enemy) and not landed:
		if not _thrown and progress >= THROW_LIFT:
			# Elle bascule dès qu'elle quitte le sol : face à l'opérateur, elle
			# retombe sur le dos, tête loin de lui.
			_thrown = true
			var away := _throw_to - unit.global_position
			away.y = 0.0
			if away.length_squared() > 0.0001:
				enemy.rotation.y = atan2(away.x, away.z)
			enemy.knock_out(false, THROW_STUN)
		# La cible, soulevée, passe par-dessus la hanche.
		var flight := clampf((progress - THROW_LIFT) / (THROW_LAND - THROW_LIFT), 0.0, 1.0)
		var arc := Vector3.UP * THROW_HEIGHT * sin(PI * flight)
		enemy.global_position = _throw_from.lerp(_throw_to, smoothstep(0.0, 1.0, flight)) + arc
		enemy.velocity = Vector3.ZERO
		unit._face(_throw_from - unit.global_position, delta)
	elif is_instance_valid(enemy):
		if _close:
			# Pas en avant, au contact de la cible.
			var step := smoothstep(0.0, 1.0, minf(progress / CLOSE_STEP, 1.0))
			unit.global_position = _step_from.lerp(_step_to, step)
			unit.velocity = Vector3.ZERO
		var facing := _aim_point if _aim_point != Vector3.INF else enemy.global_position
		unit._face(facing - unit.global_position, delta)
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
		finish(_follow_up)
	return Vector3.ZERO


## Fin du geste (ou abandon, si l'opérateur est tué) : la victime d'une prise
## n'est plus tenue ; si elle n'a pas été neutralisée, elle se dégage.
func cancel() -> void:
	unit._model.strike_progress = -1.0
	if kind == Commando.MeleeKind.THROW and is_instance_valid(enemy):
		unit.remove_collision_exception_with(enemy)
		if not landed:
			enemy.release()
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
	if kind == Commando.MeleeKind.THROW:
		# Au sol ; il le frappe aussitôt.
		enemy.global_position = _throw_to
		Sfx.play_at(&"fall", enemy.global_position, 0.0)
		EventBus.noise_emitted.emit(unit.global_position, stats.melee_noise_radius * 1.5, &"melee")
		var punch := StrikeGesture.new(unit, enemy, Commando.MeleeKind.KNOCKOUT)
		punch.forced_move = SoldierModel.StrikeMove.GROUND_PUNCH
		_follow_up = punch
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
		Commando.MeleeKind.SWEEP:
			# Jambes fauchées : il tombe à la renverse, sonné peu de temps.
			enemy.knock_out(false, enemy.stats.stun_duration * SWEEP_STUN_RATIO)
			Sfx.play_at(&"punch", enemy.global_position + Vector3.UP * 0.3, -4.0)
			EventBus.noise_emitted.emit(unit.global_position, stats.melee_noise_radius, &"melee")
