class_name Guest
extends StaticBody3D
## Invité d'une réception (décor) : un civil en costume, debout, qui bavarde
## avec ses voisins. Il ne voit rien et ne réagit à rien : la foule n'est
## qu'un décor, l'effet « se fondre dans la foule » passe par la tenue de
## l'opérateur et la tenue de rigueur de la mission (`LevelRoot.dress_code`).
## Il barre le passage (couche 1 : la navigation le contourne) sans cacher la
## vue ni arrêter les balles.

## Graine de l'apparence (corps, visage, couleurs du costume).
@export var look_seed: int = 0
## Tenue (`GearCatalog.CLOTHING`, civile).
@export var dress: StringName = &"suit"

## Couleurs de costume tirées au sort.
const SUIT_COLORS: Array[Color] = [
	Color(0.12, 0.15, 0.24), Color(0.08, 0.08, 0.09), Color(0.25, 0.26, 0.27), Color(0.16, 0.17, 0.14),
	Color(0.45, 0.46, 0.47), Color(0.36, 0.28, 0.2),
]

var model: SoldierModel


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.3
	cylinder.height = 1.7
	shape.shape = cylinder
	shape.position.y = 0.85
	add_child(shape)
	var rng := RandomNumberGenerator.new()
	rng.seed = look_seed
	var look := OperatorProfile.new()
	look.body = &"female" if rng.randf() < 0.45 else &"male"
	look.set_clothing(dress)
	look.balaclava = false
	look.skin = rng.randi() % GearCatalog.SKINS.size()
	look.hair_color = rng.randi() % GearCatalog.HAIR_COLORS.size()
	look.hair_style = ([&"long", &"bun", &"ponytail"] if look.body == &"female" else [&"short", &"short", &"shaved"])[rng.randi() % 3]
	look.beard = [&"none", &"none", &"stubble", &"full"][rng.randi() % 4] if look.body == &"male" else &"none"
	var color := SUIT_COLORS[rng.randi() % SUIT_COLORS.size()]
	look.top_color = color
	look.pants_color = color
	look.secondary = &"none"
	look.throwing_knives = 0
	look.sunglasses = rng.randf() < 0.15
	model = SoldierModel.new()
	model.civilian = dress == &"suit"
	model.silent = true
	model.outfit = look
	add_child(model)
	model.set_armed(false)
