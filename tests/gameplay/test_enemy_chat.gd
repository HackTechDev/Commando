extends LevelTest
## Gardes qui discutent (`EnemyChat`) sur « Centre mobile 07 » : le
## chauffeur et le mécanicien bavardent, distraits ; chacun remarque la
## disparition de l'autre.

const MAP := "res://scenes/levels/mobile_command/mobile_command.tscn"

var driver: Enemy
var mechanic: Enemy


func before_each() -> void:
	super()
	await load_level(MAP)
	driver = node("Enemies/Driver")
	mechanic = node("Enemies/Mechanic")


func test_pair_is_linked_and_chatting() -> void:
	await wait_seconds(0.5)
	assert_eq(driver.chat.partner, mechanic)
	assert_eq(mechanic.chat.partner, driver)
	assert_true(driver.chat.active)
	assert_true(mechanic.chat.active)
	assert_ne(driver.chat.speaking, mechanic.chat.speaking, "un seul parle à la fois")
	assert_eq(driver.chat.gain(), EnemyChat.GAIN)


func test_partner_taken_away_is_noticed() -> void:
	await wait_seconds(0.5)
	# Assommé et emporté hors de vue.
	mechanic.knock_out()
	mechanic.global_position += Vector3(0, 0, -30)
	await wait_seconds(EnemyChat.MISS_DELAY + 0.5)
	assert_true(driver.chat.noticed)
	assert_false(driver.chat.active)
	assert_ne(driver.state, Enemy.State.PATROL, "il va voir")


func test_errand_is_not_a_disappearance() -> void:
	await wait_seconds(0.5)
	mechanic.send_on_errand(mechanic.global_position + Vector3(0, 0, -20), Vector3.INF, 10.0)
	await wait_seconds(EnemyChat.MISS_DELAY + 2.0)
	assert_false(driver.chat.noticed)
	assert_eq(driver.state, Enemy.State.PATROL)
