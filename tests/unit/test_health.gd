extends GutTest
## `HealthComponent` : dégâts, mort, remise à neuf.

var health: HealthComponent


func before_each() -> void:
	health = HealthComponent.new()
	health.max_health = 100.0
	add_child_autofree(health)
	watch_signals(health)


func test_starts_full() -> void:
	assert_eq(health.health, 100.0)
	assert_true(health.is_alive())


func test_damage_and_death_emitted_once() -> void:
	health.take_damage(30.0)
	assert_eq(health.health, 70.0)
	assert_signal_emitted(health, "health_changed")
	health.take_damage(500.0)
	assert_eq(health.health, 0.0, "jamais négatif")
	assert_false(health.is_alive())
	health.take_damage(10.0)
	assert_signal_emit_count(health, "died", 1)


func test_ignores_zero_or_negative_damage() -> void:
	health.take_damage(0.0)
	health.take_damage(-20.0)
	assert_eq(health.health, 100.0)
	assert_signal_not_emitted(health, "health_changed")


func test_reset() -> void:
	health.take_damage(80.0)
	health.reset(250.0)
	assert_eq(health.max_health, 250.0)
	assert_eq(health.health, 250.0)
