extends LevelTest
## Blessures et fatigue : le blessé boite et rampe moins vite jusqu'aux
## soins ; la blessure est gardée dans le profil ; la course et le port
## d'un corps épuisent l'endurance.

var alpha: Commando


func before_each() -> void:
	super()
	await load_level(SANDBOX)
	alpha = level.get_tree().get_nodes_in_group(&"commandos")[0]
	hide_from_enemies(alpha)


func after_each() -> void:
	for operator in OperatorRoster.current().operators:
		operator.wound = 0.0
	super()


func test_wounded_limps_until_healed() -> void:
	var walk := alpha._current_speed()
	alpha.health.take_damage(alpha.health.max_health * 0.4)
	assert_true(alpha.is_limping())
	assert_almost_eq(alpha._current_speed(), walk * Commando.WOUNDED_SPEED, 0.01)
	alpha.posture = SoldierModel.Posture.PRONE
	assert_almost_eq(alpha._current_speed(), alpha.stats.crawl_speed * Commando.WOUNDED_CRAWL, 0.01)
	alpha.health.heal(alpha.health.max_health)
	assert_false(alpha.is_limping())
	assert_almost_eq(alpha._current_speed(), alpha.stats.crawl_speed, 0.01)


func test_wound_is_kept_after_a_successful_mission() -> void:
	alpha.health.take_damage(30.0)
	EventBus.mission_ended.emit(true, "test")
	assert_almost_eq(OperatorRoster.current().profile(alpha.unit_index).wound, 30.0, 0.01)


func test_wound_is_not_kept_after_a_failure() -> void:
	alpha.health.take_damage(30.0)
	EventBus.mission_ended.emit(false, "test")
	assert_eq(OperatorRoster.current().profile(alpha.unit_index).wound, 0.0)


func test_running_wears_out_and_rest_recovers() -> void:
	alpha.stamina = 0.02
	alpha.move_to(alpha.global_position + Vector3(10, 0, 0), true)
	await wait_seconds(1.5)
	assert_true(alpha.winded, "à bout de souffle")
	assert_almost_eq(alpha._current_speed(), alpha.stats.walk_speed, 0.01, "il marche")
	alpha.stop()
	await wait_seconds(Commando.STAMINA_RESUME * Commando.STAMINA_RECOVER_TIME + 0.5)
	assert_false(alpha.winded)
