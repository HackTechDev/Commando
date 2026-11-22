@tool
class_name HidingSpot
extends Node3D
## Cachette pour un corps : buisson épais, eau (mare, fossé) ou abri sans toit
## (recoin d'un bâtiment). Un corps déposé dedans échappe aux ennemis
## (`Enemy.is_hidden_body`) ; un corps sous un toit est aussi caché.
## Le buisson et l'eau sont dessinés ; l'abri est invisible (zone posée dans
## un décor existant). Aucune collision : on y entre en marchant.

enum Kind { BUSH, WATER, SHELTER }

const GROUP := &"hiding_spots"
const BUSH_COLOR := Color(0.2, 0.33, 0.14)
const WATER_COLOR := Color(0.16, 0.26, 0.3, 0.85)
## Profondeur (m) à laquelle un corps s'enfonce dans l'eau (le sol cache ce qui
## passe dessous).
const WATER_SINK := 0.4

@export var kind: Kind = Kind.BUSH
## Taille au sol (x, z) de la cachette.
@export var size := Vector2(2.4, 2.0)


## Cachette qui contient `point` (au sol), ou null.
static func at(tree: SceneTree, point: Vector3) -> HidingSpot:
	for node in tree.get_nodes_in_group(GROUP):
		var spot := node as HidingSpot
		if spot and spot.contains(point):
			return spot
	return null


## Vrai si `point` est dans l'emprise de la cachette (à hauteur d'homme).
func contains(point: Vector3) -> bool:
	var local := to_local(point)
	return absf(local.x) <= size.x * 0.5 and absf(local.z) <= size.y * 0.5 and local.y > -0.5 and local.y < 2.0


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group(GROUP)


func _ready() -> void:
	match kind:
		Kind.BUSH:
			_build_bush()
		Kind.WATER:
			_build_water()


## Touffes de feuillage serrées, plus hautes au centre.
func _build_bush() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = BUSH_COLOR
	material.roughness = 1.0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(global_position) if is_inside_tree() else 7
	var count := int(size.x * size.y * 3.0) + 4
	for i in count:
		var tuft := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		var radius := rng.randf_range(0.35, 0.6)
		sphere.radius = radius
		sphere.height = radius * 1.6
		sphere.radial_segments = 10
		sphere.rings = 6
		tuft.mesh = sphere
		var x := rng.randf_range(-0.5, 0.5) * (size.x - radius)
		var z := rng.randf_range(-0.5, 0.5) * (size.y - radius)
		var center := 1.0 - Vector2(x / size.x, z / size.y).length()
		tuft.position = Vector3(x, radius * 0.6 + 0.35 * center + rng.randf_range(0.0, 0.25), z)
		var tint := material.duplicate() as StandardMaterial3D
		tint.albedo_color = BUSH_COLOR.lightened(rng.randf_range(-0.1, 0.15))
		tuft.material_override = tint
		add_child(tuft)


## Nappe d'eau sombre au ras du sol, bord de terre.
func _build_water() -> void:
	var bank := MeshInstance3D.new()
	var bank_mesh := PlaneMesh.new()
	bank_mesh.size = size + Vector2(0.5, 0.5)
	bank.mesh = bank_mesh
	var mud := StandardMaterial3D.new()
	mud.albedo_color = Color(0.3, 0.24, 0.16)
	bank.material_override = mud
	bank.position.y = 0.01
	add_child(bank)
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = size
	water.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = WATER_COLOR
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.05
	material.metallic = 0.3
	water.material_override = material
	water.position.y = 0.03
	add_child(water)
