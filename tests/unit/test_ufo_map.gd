extends GutTest
## Lecture des cartes UFO:AI (`UfoMap`) et reconstruction des brushes
## (`UfoMapLevel`).

## Un cube de 64 unités (de 0 à 64 sur chaque axe), dessus texturé, autres
## faces techniques ; un point de départ.
const CUBE_MAP := """// entity 0
{
"classname" "worldspawn"
// brush 0
{
( 0 0 64 ) ( 0 64 64 ) ( 64 0 64 ) tex_misc/box001 8 16 0 0.125 0.25 65280 1024 0
( 0 0 0 ) ( 64 0 0 ) ( 0 64 0 ) tex_common/nodraw 0 0 0 0.125 0.125 65280 0 0
( 0 0 0 ) ( 0 64 0 ) ( 0 0 64 ) tex_common/nodraw 0 0 0 0.125 0.125 65280 0 0
( 64 0 0 ) ( 64 0 64 ) ( 64 64 0 ) tex_common/nodraw 0 0 0 0.125 0.125 65280 0 0
( 0 0 0 ) ( 0 0 64 ) ( 64 0 0 ) tex_common/nodraw 0 0 0 0.125 0.125 65280 0 0
( 0 64 0 ) ( 64 64 0 ) ( 0 64 64 ) tex_common/nodraw 0 0 0 0.125 0.125 65280 0 0
}
}
// entity 1
{
"classname" "info_player_start"
"origin" "32 32 88"
"angle" "-90"
}
"""


func test_parse_entities_and_properties() -> void:
	var map := UfoMap.new()
	assert_true(map.parse(CUBE_MAP))
	assert_eq(map.entities.size(), 2)
	assert_eq(map.entities[0].classname(), "worldspawn")
	assert_eq(map.entities[0].brushes.size(), 1)
	var start := map.find_entities("info_player_start")[0]
	assert_eq(start.origin(), Vector3(32, 32, 88))
	assert_eq(start.angle(), -90.0)


func test_parse_face_fields() -> void:
	var map := UfoMap.new()
	map.parse(CUBE_MAP)
	var top: UfoMap.Face = map.entities[0].brushes[0].faces[0]
	assert_eq(top.texture, "tex_misc/box001")
	assert_almost_eq(top.plane.normal, Vector3(0, 0, 1), Vector3.ONE * 0.0001, "normale sortante vers le haut")
	assert_almost_eq(top.plane.d, 64.0, 0.0001)
	assert_eq(top.shift, Vector2(8, 16))
	assert_eq(top.scale, Vector2(0.125, 0.25))
	assert_eq(top.contents, 65280)
	assert_eq(top.surface, UfoMap.SURF_PHONG)


func test_every_face_points_outward() -> void:
	var map := UfoMap.new()
	map.parse(CUBE_MAP)
	var center := Vector3(32, 32, 32)
	for face in map.entities[0].brushes[0].faces:
		assert_lt(face.plane.distance_to(center), 0.0, "le centre est à l'intérieur")


func test_rejects_malformed_text() -> void:
	assert_false(UfoMap.new().parse("{\n\"classname\" \"worldspawn\"\n"), "accolade non fermée")
	assert_false(UfoMap.new().parse("{\n{\n( 0 0 ) ( 1 1 1 ) tex 0 0 0 1 1\n}\n}\n"), "face incomplète")


func test_cube_brush_becomes_six_quads() -> void:
	var map := UfoMap.new()
	map.parse(CUBE_MAP)
	var builder: UfoMapLevel = autofree(UfoMapLevel.new())
	var polygons := builder._brush_polygons(map.entities[0].brushes[0])
	assert_eq(polygons.size(), 6)
	for polygon in polygons:
		var points: PackedVector3Array = polygon["points"]
		assert_eq(points.size(), 4, "un carré par face")
		var face: UfoMap.Face = polygon["face"]
		var winding := (points[1] - points[0]).cross(points[2] - points[0])
		assert_gt(winding.dot(face.plane.normal), 0.0, "sens trigonométrique autour de la normale")
		for point in points:
			for axis in 3:
				assert_true(is_equal_approx(point[axis], 0.0) or is_equal_approx(point[axis], 64.0), "sommet du cube : %s" % point)


func test_world_conversion() -> void:
	var builder: UfoMapLevel = autofree(UfoMapLevel.new())
	builder.units_per_meter = 25.0
	# Z vers le haut → Y vers le haut, Y d'UFO:AI → -Z de Godot.
	assert_almost_eq(builder.to_world(Vector3(25, 50, 75)), Vector3(1, 3, -2), Vector3.ONE * 0.0001)
	# Lacet 90° (vers +Y d'UFO:AI) → regard vers -Z de Godot (rotation nulle).
	assert_almost_eq(UfoMapLevel.yaw_to_world(90.0), 0.0, 0.0001)
	assert_almost_eq(UfoMapLevel.yaw_to_world(-90.0), -PI, 0.0001)
