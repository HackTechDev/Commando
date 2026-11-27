extends LevelTest
## Relève de la garde (`GuardRelief`) sur « Centre mobile 07 » : annonce
## interceptée, échange des postes, poste vide remarqué.

const MAP := "res://scenes/levels/mobile_command/mobile_command.tscn"

var relief: GuardRelief
var stair: Enemy
var off_duty: Enemy


func before_each() -> void:
	super()
	await load_level(MAP)
	relief = node("StairRelief")
	stair = node("Enemies/StairGuard")
	off_duty = node("Enemies/OffDutyGuard")


func _wait_arrival() -> void:
	relief.time_left = 0.05
	await wait_physics_frames(3)
	assert_true(relief.underway, "le remplaçant part")
	await frames_until(func() -> bool: return not relief.underway, 60 * 40)


func test_announce_before_relief() -> void:
	relief.time_left = GuardRelief.WARNING_TIME + 0.2
	await wait_seconds(0.5)
	var radio := level.get_tree().root.find_child("RadioLog", true, false) as RadioLog
	assert_true(radio.lines().any(func(line: String) -> bool: return line.contains("relève")))


func test_guards_swap_posts() -> void:
	var post := stair.home_position()
	var rest := off_duty.home_position()
	await _wait_arrival()
	assert_eq(relief.post, off_duty)
	assert_eq(relief.relief, stair)
	assert_eq(off_duty.home_position(), post)
	assert_eq(stair.home_position(), rest)
	await wait_seconds(25.0)
	assert_lt(off_duty.global_position.distance_to(post), 1.0, "le remplaçant tient le poste")
	assert_lt(stair.global_position.distance_to(rest), 1.0, "la sentinelle relevée est au repos")


func test_empty_post_is_searched() -> void:
	# Sentinelle assommée et emportée loin du poste.
	stair.knock_out()
	stair.global_position += Vector3(30, 0, 30)
	await _wait_arrival()
	assert_eq(off_duty.state, Enemy.State.SUSPICIOUS)
	assert_eq(off_duty.activity, Enemy.Activity.SEARCH)
	assert_lt(relief.time_left, 0.0, "plus de relève")
