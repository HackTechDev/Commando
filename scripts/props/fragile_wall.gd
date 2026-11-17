class_name FragileWall
extends StaticBody3D
## Pan de mur fragile (briques fissurées, cloison) : arrête les balles et la
## vue comme un mur, mais une explosion proche (grenade, charge) le fait
## tomber en morceaux et ouvre un passage. La navigation est alors recalculée.

const GROUP := &"fragile_walls"
const LAYER_OCCLUDERS := 0b10
## Couleur des briques fissurées et des éclats.
const COLOR := Color(0.55, 0.42, 0.34)

## Taille du pan (largeur, hauteur, épaisseur).
@export var size := Vector3(3.0, 3.0, 0.4)
## Une explosion casse le mur si son centre est à moins de cette part de son
## rayon d'effet (mesurée jusqu'au point le plus proche du mur).
@export var break_ratio: float = 0.8
## Points de résistance aux balles (tir libre) : à zéro, le mur tombe.
@export var toughness: float = 300.0

var is_broken: bool = false
var damage_taken: float = 0.0
var _shape: CollisionShape3D
var _mesh: MeshInstance3D


func _enter_tree() -> void:
	add_to_group(GROUP)
	add_to_group(QuickSave.GROUP)


func _ready() -> void:
	collision_layer = LAYER_OCCLUDERS
	collision_mask = 0
	_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	_shape.shape = box
	_shape.position.y = size.y * 0.5
	add_child(_shape)
	_mesh = MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = size
	_mesh.mesh = cube
	var material := StandardMaterial3D.new()
	material.albedo_color = COLOR
	material.roughness = 0.95
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.set_meta(&"albedo_source", "tex_ctp1/bricks_g_1.jpg")
	_mesh.material_override = material
	_mesh.position.y = size.y * 0.5
	add_child(_mesh)
	# Fissures : traits sombres sur les deux faces.
	var crack_material := StandardMaterial3D.new()
	crack_material.albedo_color = Color(0.12, 0.1, 0.09)
	for face: float in [-1.0, 1.0]:
		for i in 3:
			var crack := MeshInstance3D.new()
			var line := BoxMesh.new()
			line.size = Vector3(size.x * (0.25 + 0.1 * i), 0.03, 0.01)
			crack.mesh = line
			crack.material_override = crack_material
			crack.position = Vector3((i - 1) * size.x * 0.22, size.y * (0.3 + 0.2 * i), face * (size.z * 0.5 + 0.004))
			crack.rotation.z = 0.5 - 0.45 * i
			_mesh.add_child(crack)
			crack.position -= _mesh.position


## Vrai si une explosion de rayon `radius` au point `at` casse ce mur.
func is_breached_by(at: Vector3, radius: float) -> bool:
	if is_broken:
		return false
	var local := to_local(at)
	var half := size * 0.5
	var nearest := Vector3(clampf(local.x, -half.x, half.x), clampf(local.y, 0.0, size.y), clampf(local.z, -half.z, half.z))
	return local.distance_to(nearest) <= radius * break_ratio


## Balle tirée depuis `from` qui frappe le mur en `at` : il s'effrite, et
## tombe une fois `toughness` atteint.
func take_shot(damage: float, at: Vector3, from: Vector3) -> void:
	if is_broken:
		return
	damage_taken += damage
	if damage_taken >= toughness:
		break_apart(at + (at - from).normalized() * -0.5)


## Le mur tombe en morceaux (éclats projetés loin de `from`).
func break_apart(from: Vector3) -> void:
	if is_broken:
		return
	_set_broken(true)
	var box := global_transform * AABB(-Vector3(size.x * 0.5, 0.0, size.z * 0.5), size)
	Debris.burst(get_parent(), box, from, COLOR, 24)
	Sfx.play_at(&"fall", global_position + Vector3.UP, 2.0)


## Sauvegarde rapide (`QuickSave`) : mur debout ou effondré.
func save_state() -> Dictionary:
	return {"broken": is_broken, "damage": damage_taken}


func load_state(data: Dictionary) -> void:
	_set_broken(data.get("broken", is_broken))
	damage_taken = data.get("damage", 0.0)


func _set_broken(broken: bool) -> void:
	if broken == is_broken:
		return
	is_broken = broken
	_shape.set_deferred(&"disabled", broken)
	# Hors des couches lues par la navigation (une forme désactivée y compte).
	collision_layer = 0 if broken else LAYER_OCCLUDERS
	_mesh.visible = not broken
	EventBus.navigation_obstacle_moved.emit()
