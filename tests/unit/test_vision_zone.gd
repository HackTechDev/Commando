extends GutTest
## `VisionComponent.zone_for` : logique pure du cône de vision.

const Zone := VisionComponent.Zone
const STANDING := SoldierModel.Posture.STANDING
const CROUCHED := SoldierModel.Posture.CROUCHED
const PRONE := SoldierModel.Posture.PRONE

var config: VisionConfig


func before_each() -> void:
	config = VisionConfig.new()
	config.fov_degrees = 70.0
	config.near_range = 5.0
	config.far_range = 12.0


## Point à `distance` m, à `angle` degrés de l'axe du regard (-Z).
func _at(distance: float, angle: float) -> Vector3:
	var a := deg_to_rad(angle)
	return Vector3(sin(a), 0.0, -cos(a)) * distance


func test_near_zone_sees_every_posture() -> void:
	for posture in [STANDING, CROUCHED, PRONE]:
		assert_eq(VisionComponent.zone_for(_at(3.0, 0.0), posture, config), Zone.NEAR)


func test_far_zone_sees_only_standing_targets() -> void:
	assert_eq(VisionComponent.zone_for(_at(10.0, 0.0), STANDING, config), Zone.FAR)
	assert_eq(VisionComponent.zone_for(_at(10.0, 0.0), CROUCHED, config), Zone.NONE)
	assert_eq(VisionComponent.zone_for(_at(10.0, 0.0), PRONE, config), Zone.NONE)


func test_out_of_range_or_angle() -> void:
	assert_eq(VisionComponent.zone_for(_at(12.5, 0.0), STANDING, config), Zone.NONE, "trop loin")
	assert_eq(VisionComponent.zone_for(_at(3.0, 34.0), STANDING, config), Zone.NEAR, "juste dans le cône")
	assert_eq(VisionComponent.zone_for(_at(3.0, 36.0), STANDING, config), Zone.NONE, "juste hors du cône")
	assert_eq(VisionComponent.zone_for(_at(3.0, 180.0), STANDING, config), Zone.NONE, "dans le dos")


func test_target_on_the_eye_is_seen() -> void:
	assert_eq(VisionComponent.zone_for(Vector3.ZERO, PRONE, config), Zone.NEAR)
