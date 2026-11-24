class_name StunBurst
extends Node3D
## Détonation d'une grenade assourdissante : éclair aveuglant et détonation
## très forte, sans éclats. Les ennemis à moins de `RADIUS` qui ont la
## détonation en vue directe (les murs protègent) sont assourdis
## (`Enemy.daze`) d'autant plus longtemps qu'ils sont proches ; la
## détonation donne l'alerte comme une explosion. Les opérateurs ne sont pas
## touchés (ils s'y attendent : yeux fermés, oreilles protégées).

## Rayon (m) d'effet, et durées d'assourdissement au plus près et au bord.
const RADIUS := 8.0
const DAZE_NEAR := 7.0
const DAZE_FAR := 3.0
## Murs et obstacles qui protègent de l'éclair.
const MASK_OCCLUDERS := 0b10
## Éclair : durée (s), portée et intensité de la lumière.
const FLASH_TIME := 0.35
const FLASH_RANGE := 16.0
const FLASH_ENERGY := 14.0

var _light: OmniLight3D
var _ball: MeshInstance3D
var _time: float = 0.0


## Fait détonner une grenade assourdissante en `at` ; `noise` : rayon de
## l'alerte. Renvoie les ennemis assourdis.
static func detonate(parent: Node, at: Vector3, noise: float) -> Array[Enemy]:
	var burst := StunBurst.new()
	parent.add_child(burst)
	burst.global_position = at
	Sfx.play_at(&"bang", at, 4.0)
	var dazed := affected(parent.get_tree(), (parent as Node3D).get_world_3d() if parent is Node3D else burst.get_world_3d(), at)
	for enemy in dazed:
		var distance := enemy.global_position.distance_to(at)
		enemy.daze(lerpf(DAZE_NEAR, DAZE_FAR, clampf(distance / RADIUS, 0.0, 1.0)), at)
	EventBus.noise_emitted.emit(at, noise, &"explosion")
	return dazed


## Ennemis debout à moins de `RADIUS` de `at`, en vue directe.
static func affected(tree: SceneTree, world: World3D, at: Vector3) -> Array[Enemy]:
	var result: Array[Enemy] = []
	var space := world.direct_space_state
	var from := at + Vector3.UP * 0.3
	for node in tree.get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead or enemy.is_stunned():
			continue
		var head := enemy.global_position + Vector3.UP * 1.6
		if head.distance_to(from) > RADIUS:
			continue
		var query := PhysicsRayQueryParameters3D.create(from, head, MASK_OCCLUDERS)
		if space.intersect_ray(query).is_empty():
			result.append(enemy)
	return result


func _ready() -> void:
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.97, 0.9)
	_light.omni_range = FLASH_RANGE
	_light.light_energy = FLASH_ENERGY
	_light.position.y = 0.6
	add_child(_light)
	_ball = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.6
	sphere.height = 1.2
	_ball.mesh = sphere
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.albedo_color = Color(1, 1, 0.95, 0.9)
	_ball.material_override = glow
	_ball.position.y = 0.4
	add_child(_ball)


func _process(delta: float) -> void:
	_time += delta
	var t := clampf(_time / FLASH_TIME, 0.0, 1.0)
	_light.light_energy = FLASH_ENERGY * (1.0 - t)
	_ball.scale = Vector3.ONE * lerpf(0.4, 2.2, t)
	(_ball.material_override as StandardMaterial3D).albedo_color.a = 0.9 * (1.0 - t)
	if _time >= FLASH_TIME:
		queue_free()
