extends LevelTest
## Sons joués par les actions (le signal `Sfx.played` les compte).

var _played: Dictionary = {}


func before_each() -> void:
	super()
	_played.clear()
	await load_level()
	Sfx.played.connect(_on_played)


func after_each() -> void:
	Sfx.played.disconnect(_on_played)
	super()


func _on_played(sound: StringName, _at: Vector3) -> void:
	_played[sound] = _played.get(sound, 0) + 1


func _count(sound: StringName) -> int:
	return _played.get(sound, 0)


func test_steps_crawl_and_reload() -> void:
	park(node("Enemies/Soldier1"))
	var alpha: Commando = node("Units/Alpha")
	alpha.move_to(alpha.global_position + Vector3(4, 0, 0), false)
	await frames(120)
	assert_gt(_count(&"step"), 1, "pas en marchant")

	alpha.toggle_posture(SoldierModel.Posture.PRONE)
	await frames(80)
	_played.clear()
	alpha.move_to(alpha.global_position + Vector3(2, 0, 0), false)
	await frames(120)
	assert_gt(_count(&"crawl"), 1, "bruissement en rampant")
	assert_eq(_count(&"step"), 0, "pas de bruit de pas couché")

	_played.clear()
	alpha.ammo_in_magazine = 5
	alpha.reload()
	await frames(30)
	assert_eq(_count(&"reload"), 1)


func test_throat_cut_sounds() -> void:
	park(node("Enemies/Soldier1"))
	var alpha: Commando = node("Units/Alpha")
	var dummy: Enemy = node("Enemies/TrainingDummy")
	alpha.global_position = dummy.global_position + dummy.global_basis.z * 3.0
	await frames(5)
	_played.clear()
	alpha.melee(dummy, Commando.MeleeKind.KNIFE)
	await frames(200)
	assert_eq(_count(&"knife"), 1, "lame")
	assert_eq(_count(&"fall"), 1, "chute du corps")


func test_firefight_sounds() -> void:
	park(node("Enemies/TrainingDummy"), Vector3(25, 0, 25))
	var alpha: Commando = node("Units/Alpha")
	alpha.health.reset(10000.0)
	var soldier: Enemy = node("Enemies/Soldier1")
	alpha.global_position = soldier.global_position - soldier.global_basis.z * 8.0
	await frames(120)
	alpha.attack(soldier, false)
	await frames_until(func() -> bool: return soldier.is_dead, 400)
	await frames(30)
	assert_gt(_count(&"alert"), 0, "bips d'alerte")
	assert_gt(_count(&"shot"), 0, "tirs ennemis")
	assert_gt(_count(&"shot_suppressed"), 0, "tirs à silencieux des opérateurs")
	assert_gt(_count(&"hit"), 0, "impacts")
	assert_eq(_count(&"fall"), 1, "chute du soldat")


func test_crate_scrapes() -> void:
	park(node("Enemies/Soldier1"), Vector3(25, 0, 25))
	park(node("Enemies/TrainingDummy"))
	var alpha: Commando = node("Units/Alpha")
	var crate: Climbable = node("NavigationRegion3D/Crate4")
	alpha.handle_crate(crate, crate.global_position + Vector3.LEFT)
	await frames_until(alpha.is_handling_crate, 300)
	_played.clear()
	alpha.move_to(crate.global_position + Vector3.RIGHT * 1.5, false)
	await frames(120)
	assert_gt(_count(&"scrape"), 1, "frottement de la caisse")
	assert_gt(_count(&"step"), 0, "pas de l'opérateur")
