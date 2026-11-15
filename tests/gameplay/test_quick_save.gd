extends LevelTest
## Sauvegarde rapide (préparation) : l'état capturé puis rendu à un niveau
## rechargé est le même.

const ESCORT := "res://scenes/levels/escort/escort.tscn"
const FILE := "user://test_quick_save.sav"


func after_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FILE))
	super()


func test_operators_enemies_and_crates_are_restored() -> void:
	await load_level()
	var alpha: Commando = node("Units/Alpha")
	var bravo: Commando = node("Units/Bravo")
	var soldier: Enemy = node("Enemies/Soldier1")
	var dummy: Enemy = node("Enemies/TrainingDummy")
	var crate: Climbable = node("NavigationRegion3D/Crate1")
	park(soldier)
	alpha.global_position = Vector3(3.0, 0.0, 6.0)
	alpha.rotation.y = 1.2
	alpha.ammo_in_magazine = 4
	alpha.ammo_reserve = 7
	alpha.grenades = 0
	alpha.toggle_posture(SoldierModel.Posture.CROUCHED)
	alpha.health.take_damage(30.0)
	bravo.health.take_damage(1000.0)
	dummy.knock_out()
	soldier.detection = 0.4
	crate.global_position += Vector3(1.0, 0.0, 0.0)
	await frames(5)
	var saved := QuickSave.capture(level)
	assert_true(QuickSave.write(FILE, saved), "fichier écrit")
	var expected_alpha := alpha.global_position
	var expected_soldier := soldier.global_position
	var expected_crate := crate.global_position

	await load_level()
	var data := QuickSave.read(FILE)
	assert_gt(QuickSave.restore(level, data), 5, "nœuds restaurés")
	alpha = node("Units/Alpha")
	bravo = node("Units/Bravo")
	soldier = node("Enemies/Soldier1")
	dummy = node("Enemies/TrainingDummy")
	crate = node("NavigationRegion3D/Crate1")
	assert_lt(alpha.global_position.distance_to(expected_alpha), 0.05, "place d'Alpha")
	assert_almost_eq(alpha.rotation.y, 1.2, 0.01)
	assert_eq(alpha.posture, SoldierModel.Posture.CROUCHED)
	assert_eq(alpha.health.health, alpha.health.max_health - 30.0)
	assert_eq(Vector2i(alpha.ammo_in_magazine, alpha.ammo_reserve), Vector2i(4, 7))
	assert_eq(alpha.grenades, 0)
	assert_true(bravo.is_dead, "Bravo reste mort")
	assert_eq(dummy.state, Enemy.State.STUNNED, "mannequin inconscient")
	assert_lt(soldier.global_position.distance_to(expected_soldier), 0.05)
	assert_almost_eq(soldier.detection, 0.4, 0.001)
	assert_lt(crate.global_position.distance_to(expected_crate), 0.01, "caisse déplacée")


func test_vip_leader_and_alert_are_restored() -> void:
	await load_level(ESCORT)
	var vip: Vip = node("Units/Vip")
	var alpha: Commando = node("Units/Alpha")
	assert_true(vip.follow(alpha))
	GameState.alert_level = GameState.AlertLevel.CALM
	var saved := QuickSave.capture(level)
	assert_eq(saved["nodes"]["Units/Vip"]["leader"], String(alpha.get_path()))

	await load_level(ESCORT)
	vip = node("Units/Vip")
	assert_null(vip.leader, "au départ, le VIP attend")
	QuickSave.restore(level, saved)
	assert_eq(vip.leader, node("Units/Alpha"), "il suit de nouveau Alpha")


func test_a_save_from_another_version_is_ignored() -> void:
	await load_level()
	var saved := QuickSave.capture(level)
	saved["version"] = QuickSave.VERSION + 1
	assert_eq(QuickSave.restore(level, saved), 0)
