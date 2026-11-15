extends LevelTest
## Désarmement : arracher l'arme d'un ennemi pris de court. Il lève les mains
## et ne fait plus rien, sans être neutralisé.


func before_each() -> void:
	super()
	await load_level()
	park(node("Enemies/TrainingDummy"), Vector3(25, 0, 25))


## Soldat en alerte face à Alpha, à 2 m (garde levée).
func _face_off() -> Array:
	var alpha: Commando = node("Units/Alpha")
	alpha.health.reset(10000.0)
	own_stats(alpha).parry_chance = 0.0
	alpha.stats.dodge_chance = 0.0
	var soldier: Enemy = node("Enemies/Soldier1")
	soldier.stationary = true
	alpha.global_position = soldier.global_position - soldier.global_basis.z * 2.0
	await frames(5)
	soldier.detection = 1.0
	await frames(5)
	assert_eq(soldier.state, Enemy.State.ALERT)
	return [alpha, soldier]


func test_a_surprised_enemy_is_disarmed_and_surrenders() -> void:
	var pair := await _face_off()
	var alpha: Commando = pair[0]
	var soldier: Enemy = pair[1]
	assert_true(soldier.is_surprised(), "tout juste en alerte : pris de court")
	assert_true(soldier.resists(alpha.global_position), "de face, il résisterait à un coup")
	var options := PlayerController.melee_options(soldier)
	var disarm: Array = options.filter(func(o: Dictionary) -> bool: return o.id == &"disarm")
	assert_eq(disarm.size(), 1, "option du menu")
	assert_true(disarm[0].get("enabled", true), "proposée sur un ennemi armé")
	assert_true(alpha.melee(soldier, Commando.MeleeKind.DISARM))
	assert_gt(await frames_until(func() -> bool: return soldier.disarmed, 200), -1, "arme arrachée")
	assert_eq(alpha._model.strike_move, SoldierModel.StrikeMove.DISARM, "geste de désarmement")
	assert_false(soldier.armed)
	assert_false(soldier.can_fire())
	var model: SoldierModel = soldier.get_node("SoldierModel")
	assert_true(model.hands_up, "mains en l'air")
	assert_true(is_instance_valid(soldier.dropped_weapon), "l'arme est au sol")
	assert_lt(soldier.dropped_weapon.global_position.y, 0.3)
	assert_false(soldier.is_stunned(), "toujours conscient")
	assert_false(soldier.is_dead)
	assert_eq(GameState.alert_level, GameState.AlertLevel.CALM, "inoffensif : plus d'alarme")
	# Il ne frappe ni ne tire plus, même au contact.
	var hp := alpha.health.health
	alpha.global_position = soldier.global_position - soldier.global_basis.z * 0.8
	await frames(120)
	assert_false(soldier.is_attacking())
	assert_eq(alpha.health.health, hp, "pas un coup")
	assert_false(PlayerController.melee_options(soldier).filter(func(o: Dictionary) -> bool: return o.id == &"disarm")[0].enabled, "plus rien à arracher")
	assert_false(alpha.melee(soldier, Commando.MeleeKind.DISARM))
	# On peut encore l'assommer.
	assert_true(alpha.melee(soldier, Commando.MeleeKind.KNOCKOUT))
	assert_gt(await frames_until(soldier.is_stunned, 300), -1, "assommé sans résistance")


func test_an_enemy_on_his_guard_shoves_back_the_disarm() -> void:
	var pair := await _face_off()
	var alpha: Commando = pair[0]
	var soldier: Enemy = pair[1]
	soldier.alert_age = Enemy.SURPRISE_TIME + 1.0
	assert_false(soldier.is_surprised())
	assert_true(alpha.melee(soldier, Commando.MeleeKind.DISARM))
	var model: SoldierModel = soldier.get_node("SoldierModel")
	assert_gt(await frames_until(func() -> bool: return model.shove_progress >= 0.0, 150), -1, "il repousse l'opérateur")
	await frames(30)
	assert_false(soldier.disarmed, "il garde son arme")
	assert_true(soldier.armed)


func test_disarmed_state_is_saved() -> void:
	var soldier: Enemy = node("Enemies/Soldier1")
	var alpha: Commando = node("Units/Alpha")
	var before := soldier.save_state()
	soldier.disarm(alpha)
	var after := soldier.save_state()
	soldier.load_state(before)
	assert_false(soldier.disarmed, "rechargé avant le désarmement : armé")
	assert_true(soldier.armed)
	assert_false(soldier.get_node("SoldierModel").hands_up)
	await frames(2)
	assert_false(is_instance_valid(soldier.dropped_weapon), "l'arme au sol disparaît")
	soldier.load_state(after)
	assert_true(soldier.disarmed)
	assert_false(soldier.armed)
	assert_true(is_instance_valid(soldier.dropped_weapon))
