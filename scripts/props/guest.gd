@tool
class_name Guest
extends StaticBody3D
## Invité d'une réception ou passant (décor) : un civil en costume ou en
## tenue décontractée, debout, qui bavarde avec ses voisins. Il ne voit rien et ne réagit à rien : la foule n'est
## qu'un décor, l'effet « se fondre dans la foule » passe par la tenue de
## l'opérateur et la tenue de rigueur de la mission (`LevelRoot.dress_code`).
## Il barre le passage (couche 1 : la navigation le contourne) sans cacher la
## vue ni arrêter les balles.

## Graine de l'apparence (corps, visage, couleurs du costume).
@export var look_seed: int = 0
## Tenue (`GearCatalog.CLOTHING`, civile).
@export var dress: StringName = &"suit"

## Couleurs de blouson et de jean (tenue décontractée) tirées au sort.
const JACKET_COLORS: Array[Color] = [
	Color(0.36, 0.28, 0.2), Color(0.16, 0.17, 0.14), Color(0.4, 0.17, 0.14), Color(0.3, 0.33, 0.24),
	Color(0.55, 0.52, 0.38), Color(0.08, 0.08, 0.09),
]
const JEANS_COLORS: Array[Color] = [Color(0.2, 0.27, 0.38), Color(0.12, 0.15, 0.24), Color(0.25, 0.26, 0.27), Color(0.68, 0.6, 0.45)]
## Couleurs de costume tirées au sort.
const SUIT_COLORS: Array[Color] = [
	Color(0.12, 0.15, 0.24), Color(0.08, 0.08, 0.09), Color(0.25, 0.26, 0.27), Color(0.16, 0.17, 0.14),
	Color(0.45, 0.46, 0.47), Color(0.36, 0.28, 0.2),
]

var model: SoldierModel


func _ready() -> void:
	# Couches réglées en jeu seulement : dans l'éditeur, elles seraient
	# enregistrées dans la scène.
	if not Engine.is_editor_hint():
		collision_layer = 1
		collision_mask = 0
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.3
	cylinder.height = 1.7
	shape.shape = cylinder
	shape.position.y = 0.85
	add_child(shape)
	var look := random_look(look_seed, dress)
	model = CrowdModel.new()
	model.civilian = dress == &"suit"
	model.silent = true
	model.outfit = look
	add_child(model)
	model.set_armed(false)


## Apparence d'un civil tirée de la graine `seed` (corps, visage, coupe,
## couleurs de la tenue `dress`, parfois des lunettes de soleil), sans arme
## ni équipement. Partagée avec les passants (`Passerby`).
static func random_look(seed: int, dress: StringName) -> OperatorProfile:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var look := OperatorProfile.new()
	look.body = &"female" if rng.randf() < 0.45 else &"male"
	look.set_clothing(dress)
	look.balaclava = false
	look.skin = rng.randi() % GearCatalog.SKINS.size()
	look.hair_color = rng.randi() % GearCatalog.HAIR_COLORS.size()
	look.hair_style = ([&"long", &"bun", &"ponytail"] if look.body == &"female" else [&"short", &"short", &"shaved"])[rng.randi() % 3]
	look.beard = [&"none", &"none", &"stubble", &"full"][rng.randi() % 4] if look.body == &"male" else &"none"
	if dress == &"casual":
		look.top_color = JACKET_COLORS[rng.randi() % JACKET_COLORS.size()]
		look.pants_color = JEANS_COLORS[rng.randi() % JEANS_COLORS.size()]
	else:
		var color := SUIT_COLORS[rng.randi() % SUIT_COLORS.size()]
		look.top_color = color
		look.pants_color = color
	look.secondary = &"none"
	look.throwing_knives = 0
	look.sunglasses = rng.randf() < 0.15
	return look
