extends LevelTest
## Équipement en mission : arme secondaire, grenades, charges explosives,
## trousse de soins, charge portée et spécialités.

var _noises: Array[StringName] = []


func before_each() -> void:
	super()
	_noises.clear()


func after_each() -> void:
	super.after_each()
	if EventBus.noise_emitted.is_connected(_on_noise):
		EventBus.noise_emitted.disconnect(_on_noise)
	OperatorRoster.use(OperatorRoster.new())


func _on_noise(_at: Vector3, _radius: float, type: StringName) -> void:
	_noises.append(type)


## Charge le terrain d'essai avec l'équipe `roster`, la sentinelle à l'écart.
func _load(roster: OperatorRoster) -> void:
	OperatorRoster.use(roster)
	await load_level()
	park(node("Enemies/Soldier1"))
	EventBus.noise_emitted.connect(_on_noise)


func test_secondary_weapon_takes_over_when_primary_is_dry() -> void:
	await _load(OperatorRoster.new())
	var alpha: Commando = node("Units/Alpha")
	var dummy: Enemy = node("Enemies/TrainingDummy")
	assert_true(alpha.has_secondary(), "pistolet par défaut")
	alpha.global_position = dummy.global_position + dummy.global_basis.z * 6.0
	alpha.ammo_in_magazine = 0
	alpha.ammo_reserve = 0
	await frames(3)
	alpha.attack(dummy, false)
	assert_true(alpha.using_secondary, "pistolet dégainé, l'arme principale à sec")
	assert_eq(alpha.stats.magazine_size, 8, "réglages du pistolet")
	assert_eq(alpha.ammo_in_magazine, 8)
	assert_gt(await frames_until(func() -> bool: return alpha.ammo_in_magazine < 8, 300), -1, "tire au pistolet")
	assert_not_null(alpha.find_child("SlungPrimary", true, false), "carabine pendue à la bretelle")
	alpha.stop()
	assert_true(alpha.switch_weapon(), "retour à l'arme principale")
	assert_false(alpha.using_secondary)
	assert_eq(alpha.ammo_in_magazine, 0, "l'arme principale est toujours vide")
	assert_eq(alpha.stats.magazine_size, 10)
	assert_gt(await frames_until(func() -> bool: return alpha.find_child("SlungPrimary", true, false) == null, 120), -1, "pistolet rengainé, carabine reprise")


func test_grenade_kills_and_is_heard() -> void:
	var roster := OperatorRoster.new()
	roster.operators[0].grenades = 2
	await _load(roster)
	var alpha: Commando = node("Units/Alpha")
	var dummy: Enemy = node("Enemies/TrainingDummy")
	alpha.global_position = dummy.global_position + dummy.global_basis.z * 16.0
	await frames(3)
	assert_eq(alpha.grenades, 2)
	assert_true(alpha.throw_grenade(dummy.global_position), "ordre accepté")
	assert_gt(await frames_until(func() -> bool: return dummy.is_dead, 600), -1, "cible tuée par l'explosion")
	assert_eq(alpha.grenades, 1, "une grenade lancée")
	assert_lt(flat_distance(alpha.global_position, dummy.global_position), alpha.stats.grenade_range + 0.5, "lancée à portée")
	assert_has(_noises, &"explosion", "explosion entendue")
	assert_false(alpha.is_dead, "le lanceur est hors du souffle")
	assert_eq(alpha.health.health, alpha.health.max_health)


func test_explosive_charge_is_planted_then_detonated() -> void:
	var roster := OperatorRoster.new()
	roster.operators[0].explosives = 1
	await _load(roster)
	var alpha: Commando = node("Units/Alpha")
	var dummy: Enemy = node("Enemies/TrainingDummy")
	alpha.global_position = dummy.global_position + dummy.global_basis.z * 1.5
	await frames(3)
	assert_true(alpha.plant_explosive(), "pose acceptée")
	assert_true(alpha.is_planting())
	assert_eq(alpha.posture, SoldierModel.Posture.CROUCHED, "accroupi pour poser")
	assert_gt(await frames_until(func() -> bool: return alpha.explosives == 0, 300), -1, "charge posée")
	assert_eq(ExplosiveCharge.planted_by(get_tree(), alpha).size(), 1)
	assert_false(alpha.plant_explosive(), "plus de charge")
	alpha.global_position = dummy.global_position + dummy.global_basis.z * 12.0
	await frames(3)
	assert_eq(alpha.detonate_explosives(), 1, "mise à feu")
	await frames(2)
	assert_true(dummy.is_dead, "la cible saute avec la charge")
	assert_eq(ExplosiveCharge.planted_by(get_tree(), alpha).size(), 0)
	assert_has(_noises, &"explosion")


func test_medkit_heals_the_most_wounded_teammate() -> void:
	var roster := OperatorRoster.new()
	roster.operators[0].medkit = 1
	await _load(roster)
	var alpha: Commando = node("Units/Alpha")
	var bravo: Commando = node("Units/Bravo")
	bravo.global_position = alpha.global_position + Vector3(1.2, 0.0, 0.0)
	await frames(3)
	assert_false(alpha.use_medkit(), "personne n'est blessé")
	alpha.health.take_damage(10.0)
	bravo.health.take_damage(60.0)
	assert_true(alpha.use_medkit(), "soins acceptés")
	assert_true(alpha.is_healing())
	assert_gt(await frames_until(func() -> bool: return alpha.medkits == 0, 300), -1, "trousse utilisée")
	assert_eq(bravo.health.health, 90.0, "le plus blessé est soigné")
	assert_eq(alpha.health.health, 90.0, "pas l'infirmier, moins blessé")


func test_heavy_load_slows_and_rattles() -> void:
	var roster := OperatorRoster.new()
	var heavy := roster.operators[0]
	heavy.primary = &"dmr"
	heavy.grenades = 4
	heavy.explosives = 2
	heavy.medkit = 1
	assert_gt(GearCatalog.load_of(heavy), 23.0, "charge lourde")
	assert_lt(GearCatalog.load_of(roster.operators[1]), 18.0, "tenue par défaut légère")
	await _load(roster)
	var alpha: Commando = node("Units/Alpha")
	var bravo: Commando = node("Units/Bravo")
	assert_almost_eq(alpha.stats.walk_speed, bravo.stats.walk_speed * 0.82, 0.001, "plus lent")
	assert_eq(bravo.stats.walk_speed, 3.0, "tenue par défaut : vitesse normale")
	alpha.move_to(alpha.global_position + Vector3(8.0, 0.0, 0.0), true)
	assert_gt(await frames_until(func() -> bool: return _noises.has(&"gear"), 120), -1, "l'équipement s'entrechoque en courant")


func test_specialties_give_their_bonus() -> void:
	var roster := OperatorRoster.new()
	roster.operators[1].specialty = &"marksman"
	roster.operators[2].specialty = &"scout"
	await _load(roster)
	var bravo: Commando = node("Units/Bravo")
	var charlie: Commando = node("Units/Charlie")
	assert_almost_eq(bravo.stats.fire_range, 16.0 * 1.15, 0.001, "tireur d'élite : portée")
	assert_almost_eq(bravo.stats.hit_chance_far, 0.7, 0.001, "tireur d'élite : précision")
	assert_almost_eq(charlie.stats.walk_speed, 3.3, 0.001, "éclaireur : vitesse")
	assert_eq((node("Units/Alpha") as Commando).stats.fire_range, 16.0, "polyvalent : sans bonus")
