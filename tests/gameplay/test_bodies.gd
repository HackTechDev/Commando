extends LevelTest
## Corps : porter et déposer un ennemi mort ou assommé, le cacher (buisson,
## eau, toit) ; un corps visible découvert par un ennemi donne l'alarme.

var alpha: Commando
var soldier: Enemy
var dummy: Enemy


func before_each() -> void:
	super()
	await load_level()
	alpha = node("Units/Alpha")
	soldier = node("Enemies/Soldier1")
	dummy = node("Enemies/TrainingDummy")
	hide_from_enemies(alpha)
	park(soldier, Vector3(25, 0, 25))


## Tue le mannequin en `at` et attend la fin de sa chute.
func _body_at(at: Vector3) -> Enemy:
	dummy.global_position = at
	dummy.kill_silently()
	await frames(90)
	return dummy


## Fait prendre `body` par Alpha et attend qu'il soit sur ses épaules.
func _lift(body: Enemy) -> void:
	assert_true(alpha.carry_body(body), "ordre accepté")
	assert_gt(await frames_until(func() -> bool: return alpha.carried_body == body, 400), -1, "corps chargé")


func test_carry_then_drop_a_body() -> void:
	var body := await _body_at(alpha.global_position + Vector3(0, 0, -4))
	assert_true(body.is_body())
	await _lift(body)
	assert_eq(body.carrier, alpha)
	assert_true(body.is_hidden_body(), "porté : hors de vue")
	assert_almost_eq(alpha._current_speed(), alpha.stats.walk_speed * Commando.CARRY_SPEED, 0.001, "marche lente")
	await frames(30)
	assert_gt(body.global_position.y, alpha.global_position.y + 0.8, "sur les épaules")
	assert_lt(flat_distance(body.body_center(), alpha.global_position), 0.3, "bassin sur l'épaule")
	# Il l'emporte en marchant.
	alpha.move_to(alpha.global_position + Vector3(4, 0, 0), false)
	await frames(60)
	assert_lt(flat_distance(body.body_center(), alpha.global_position), 0.3, "le corps suit")
	assert_true(alpha.drop_body())
	assert_null(alpha.carried_body)
	assert_null(body.carrier)
	assert_almost_eq(body.global_position.y, alpha.global_position.y, 0.01, "au sol")
	assert_between(flat_distance(body.body_center(), alpha.global_position), 0.5, 1.3, "à ses pieds")
	assert_false(alpha.drop_body(), "plus rien à déposer")


func test_carrier_has_his_hands_busy() -> void:
	var body := await _body_at(alpha.global_position + Vector3(0, 0, -3))
	await _lift(body)
	assert_false(alpha.fire_at(alpha.global_position + Vector3(0, 0, -8)), "pas de tir")
	assert_false(alpha.throw_grenade(alpha.global_position + Vector3(0, 0, -8)), "pas de grenade")
	assert_false(alpha.carry_body(body), "déjà chargé")
	alpha.toggle_posture(SoldierModel.Posture.PRONE)
	assert_eq(alpha.posture, SoldierModel.Posture.STANDING, "reste debout")
	await frames(2)
	assert_true(alpha._model.weapon_slung, "arme à la bretelle")
	assert_true(alpha._model.carrying)


func test_only_bodies_can_be_carried() -> void:
	dummy.global_position = alpha.global_position + Vector3(0, 0, -3)
	assert_false(alpha.carry_body(dummy), "debout : non")
	dummy.knock_out()
	await frames(60)
	assert_true(dummy.is_body(), "assommé : oui")
	await _lift(dummy)


func test_stunned_body_wakes_up_and_is_dropped() -> void:
	dummy.global_position = alpha.global_position + Vector3(0, 0, -3)
	dummy.knock_out(false, 3.0)
	await frames(60)
	await _lift(dummy)
	assert_gt(await frames_until(func() -> bool: return dummy.state != Enemy.State.STUNNED, 400), -1, "réveillé")
	assert_null(alpha.carried_body, "lâché")
	assert_null(dummy.carrier)


func test_body_in_bush_or_water_is_hidden() -> void:
	var bush: HidingSpot = node("Decor/Bush")
	var pond: HidingSpot = node("Decor/Pond")
	var body := await _body_at(bush.global_position + Vector3(4, 0, 0))
	assert_false(body.is_hidden_body(), "à découvert")
	await _lift(body)
	# Déposé dans le buisson (le bassin tombe 0,9 m sur sa droite).
	alpha.global_position = bush.global_position - alpha.global_basis.x * 0.9
	await frames(2)
	alpha.drop_body()
	assert_eq(HidingSpot.at(get_tree(), body.body_center()), bush)
	assert_true(body.is_hidden_body(), "dans le buisson")
	await _lift(body)
	alpha.global_position = pond.global_position - alpha.global_basis.x * 0.9
	await frames(2)
	alpha.drop_body()
	assert_true(body.is_hidden_body(), "dans l'eau")
	assert_almost_eq(body._model.position.y, -HidingSpot.WATER_SINK, 0.001, "enfoncé")


func test_visible_body_raises_the_alarm() -> void:
	soldier.set_physics_process(true)
	soldier.stationary = true
	soldier.global_position = Vector3(10, 0, -10)
	soldier.rotation.y = 0.0
	await frames(5)
	watch_signals(EventBus)
	await _body_at(soldier.global_position - soldier.global_basis.z * 6.0)
	assert_gt(await frames_until(func() -> bool: return dummy.discovered, 120), -1, "corps découvert")
	assert_signal_emitted(EventBus, "body_discovered")
	assert_eq(soldier.state, Enemy.State.ALERT, "alerte")


func test_hidden_body_is_not_discovered() -> void:
	var bush: HidingSpot = node("Decor/Bush")
	soldier.set_physics_process(true)
	soldier.stationary = true
	soldier.global_position = bush.global_position + Vector3(0, 0, 6)
	soldier.rotation.y = 0.0
	await frames(5)
	# Corps porté devant lui puis déposé dans le buisson.
	var body := await _body_at(alpha.global_position + Vector3(0, 0, -3))
	await _lift(body)
	alpha.global_position = bush.global_position - alpha.global_basis.x * 0.9
	await frames(2)
	alpha.drop_body()
	await frames(60)
	assert_true(body.is_hidden_body())
	assert_false(body.discovered, "pas vu")
	assert_ne(soldier.state, Enemy.State.ALERT)


func test_carried_body_is_saved() -> void:
	var body := await _body_at(alpha.global_position + Vector3(0, 0, -3))
	await _lift(body)
	var saved := QuickSave.capture(level)
	alpha.drop_body()
	alpha.global_position += Vector3(3, 0, 0)
	QuickSave.restore(level, saved)
	await frames(3)
	assert_eq(alpha.carried_body, body, "toujours porté")
	assert_eq(body.carrier, alpha)
	assert_lt(flat_distance(body.body_center(), alpha.global_position), 0.3)
