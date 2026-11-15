extends LevelTest
## La personnalisation des opérateurs s'applique en mission.


func after_each() -> void:
	super.after_each()
	OperatorRoster.use(OperatorRoster.new())


func test_profile_applies_in_mission() -> void:
	var roster := OperatorRoster.new()
	var alpha_profile := roster.operators[0]
	alpha_profile.callsign = "Faucon"
	alpha_profile.primary = &"dmr"
	alpha_profile.headwear = &"none"
	alpha_profile.balaclava = false
	alpha_profile.throwing_knives = 2
	OperatorRoster.use(roster)
	await load_level()
	var alpha: Commando = node("Units/Alpha")
	assert_eq(alpha.display_name, "Faucon", "indicatif")
	assert_eq(alpha.stats.fire_range, 24.0, "réglages du fusil de précision")
	assert_eq(alpha.ammo_in_magazine, 5, "chargeur du fusil de précision")
	assert_eq(alpha.throwing_knives, 2, "couteaux de lancer")
	assert_null(alpha.find_child("Helmet", true, false), "sans casque")
	assert_not_null(alpha.find_child("Face", true, false), "visage découvert")
	var bravo: Commando = node("Units/Bravo")
	assert_eq(bravo.display_name, "Bravo")
	assert_eq(bravo.stats.fire_range, 16.0, "les autres gardent la carabine")
	var names := level.find_children("*", "UnitPortrait", true, false).map(func(p: UnitPortrait) -> String: return (p.find_child("Name", true, false) as Label).text)
	assert_has(names, "Faucon", "portrait du HUD")
