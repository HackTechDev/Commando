extends LevelTest
## Radio des gardes (`GuardRadio`) sur « Centre mobile 07 » : poste muet
## signalé et visité, opérateur déguisé qui répond à la place du garde.

const MAP := "res://scenes/levels/mobile_command/mobile_command.tscn"

var radio: GuardRadio
var lookout: Enemy
var deck: Enemy


func before_each() -> void:
	super()
	await load_level(MAP)
	radio = node("GuardRadio")
	lookout = node("Enemies/LookoutSentry")
	deck = node("Enemies/DeckSentry")


func _lines() -> Array[String]:
	return (level.get_tree().root.find_child("RadioLog", true, false) as RadioLog).lines()


func test_silent_post_sends_a_patrol() -> void:
	lookout.knock_out()
	lookout.global_position += Vector3(0, 0, 30)
	radio.time_left = 0.05
	await wait_seconds(0.5)
	assert_true(radio.silent.has(lookout))
	assert_true(_lines().any(func(line: String) -> bool: return line.contains("promontoire")))
	var busy := level.get_tree().get_nodes_in_group(&"enemies").filter(func(e: Enemy) -> bool: return e.is_on_errand())
	assert_eq(busy.size(), 1, "une patrouille va voir")


func test_disguised_operator_answers() -> void:
	deck.knock_out()
	var unit := level.get_tree().get_nodes_in_group(&"commandos")[0] as Commando
	unit.wear_disguise({"uniform": Color.TAN, "gear": Color.BROWN, "headwear": &"cap", "headwear_color": Color.DARK_RED})
	unit.global_position = radio.post_of(deck) + Vector3(3, 0, 0)
	radio.time_left = 0.05
	await wait_seconds(GuardRadio.STAGGER + 0.5)
	assert_false(radio.silent.has(deck))
	assert_true(_lines().any(func(line: String) -> bool: return line.contains("à la place")))


func test_all_answer_when_nothing_happened() -> void:
	radio.time_left = 0.05
	await wait_seconds(GuardRadio.STAGGER * radio.guards.size() + 0.5)
	assert_true(radio.silent.is_empty())
