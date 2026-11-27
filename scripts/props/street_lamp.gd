class_name StreetLamp
extends StaticBody3D
## Lampadaire ou projecteur qu'on éteint. Posé par `adopt_all` sur chaque
## lampe de la carte : un nœud qui porte une lumière « Light »
## (`OmniLight3D` ou `SpotLight3D`) et une ampoule « Bulb ». Le corps
## entoure l'ampoule : une balle (tir libre) la brise.
##
## La nuit, une lampe allumée éclaire un disque (`lit_at`) où les gardes
## voient aussi loin que de jour (`Enemy`, vue de nuit). Une lampe éteinte —
## ampoule brisée, ou groupe électrogène détruit (`SabotageTarget.lights`) —
## plonge son disque dans le noir. Un garde au calme, à moins de
## `CALL_RADIUS` m, vient alors voir (`Enemy.send_on_errand`) : il change
## l'ampoule brisée en `REPAIR_TIME` s (la lampe se rallume) ; privée de
## courant, il ne peut que constater.

const GROUP := &"street_lamps"
## Couche des obstacles (tir libre, visée), sans arrêter la marche.
const LAYER := 0b10
const BULB_RADIUS := 0.3
## Part de la portée de la lumière où l'on voit comme de jour.
const REACH_SHARE := 0.8
## Écart de hauteur (m) au-delà duquel une lampe n'éclaire plus un point.
const REACH_HEIGHT := 6.0
const CALL_RADIUS := 35.0
## Délai (s) avant qu'un garde vienne voir, et temps de réparation (s).
const CALL_DELAY := 3.0
const REPAIR_TIME := 6.0
const BREAK_NOISE := 10.0

var lamp: Node3D
var light: Light3D
var bulb: MeshInstance3D
## Ampoule brisée (balle) : éteinte jusqu'à réparation.
var broken: bool = false
var _call_left: float = -1.0
var _repairer: Enemy


## Pose un `StreetLamp` sur chaque lampe de `root` qui n'en a pas.
static func adopt_all(root: Node) -> int:
	var count := 0
	for found in root.find_children("Light", "Light3D", true, false):
		var holder := found.get_parent() as Node3D
		if holder == null or holder.get_node_or_null(^"Bulb") == null or holder.get_node_or_null(^"StreetLamp"):
			continue
		var controller := StreetLamp.new()
		controller.name = "StreetLamp"
		holder.add_child(controller)
		count += 1
	return count


## Vrai si une lampe allumée éclaire `point`.
static func lit_at(tree: SceneTree, point: Vector3) -> bool:
	for node in tree.get_nodes_in_group(GROUP):
		var item := node as StreetLamp
		if item and item.is_lit() and item.lights(point):
			return true
	return false


func _ready() -> void:
	lamp = get_parent() as Node3D
	light = lamp.get_node(^"Light") as Light3D
	bulb = lamp.get_node(^"Bulb") as MeshInstance3D
	add_to_group(GROUP)
	add_to_group(QuickSave.GROUP)
	collision_layer = LAYER
	collision_mask = 0
	position = bulb.position
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = BULB_RADIUS
	shape.shape = sphere
	add_child(shape)
	set_physics_process(false)
	light.set_meta(&"energy", light.light_energy)


## Allumée : ampoule intacte et courant.
func is_lit() -> bool:
	return not broken and light.is_visible_in_tree()


## Vrai si `point` est dans le disque éclairé (lampe allumée ou non).
func lights(point: Vector3) -> bool:
	var at := light.global_position
	var reach := _range() * REACH_SHARE
	var flat := Vector2(point.x - at.x, point.z - at.z)
	return flat.length() <= reach and absf(point.y - at.y) <= REACH_HEIGHT


func _range() -> float:
	if light is OmniLight3D:
		return (light as OmniLight3D).omni_range
	if light is SpotLight3D:
		return (light as SpotLight3D).spot_range * 0.6
	return 8.0


## Une balle frappe l'ampoule : elle se brise.
func take_shot(_damage: float, at: Vector3, _from: Vector3) -> void:
	if broken:
		return
	set_broken(true)
	Sfx.play_at(&"glass", at, -2.0)
	EventBus.noise_emitted.emit(at, BREAK_NOISE, &"impact")
	_ask_for_help()


func set_broken(value: bool) -> void:
	broken = value
	# La lumière garde sa visibilité (courant du groupe électrogène) : on la
	# coupe par son énergie.
	light.light_energy = 0.0 if value else float(light.get_meta(&"energy", 1.0))
	bulb.visible = not value and light.is_visible_in_tree()


## Un garde au calme vient voir, après `CALL_DELAY` s. (Courant coupé :
## c'est le groupe électrogène qui appelle, `SabotageTarget`.)
func _ask_for_help() -> void:
	_call_left = CALL_DELAY
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if _call_left < 0.0:
		set_physics_process(false)
		return
	_call_left -= delta
	if _call_left > 0.0:
		return
	_call_left = -1.0
	if is_instance_valid(_repairer) and _repairer.is_on_errand():
		return
	_repairer = nearest_guard(get_tree(), lamp.global_position, CALL_RADIUS)
	if _repairer == null:
		return
	var foot := lamp.global_position + (_repairer.global_position - lamp.global_position).normalized() * 0.9
	foot.y = lamp.global_position.y
	_repairer.send_on_errand(foot, light.global_position, REPAIR_TIME, _repaired)


## Garde le plus proche de `at`, à moins de `radius` m, libre de partir en
## mission (`Enemy.can_take_errand`), ou null.
static func nearest_guard(tree: SceneTree, at: Vector3, radius: float) -> Enemy:
	var best: Enemy = null
	var best_distance := radius
	for node in tree.get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		if enemy == null or not enemy.can_take_errand():
			continue
		var distance := enemy.global_position.distance_to(at)
		if distance < best_distance:
			best_distance = distance
			best = enemy
	return best


## Le garde a fini : ampoule changée (rien à faire sans courant).
func _repaired() -> void:
	if broken:
		set_broken(false)
		Sfx.play_at(&"clink", light.global_position, -6.0)


func save_state() -> Dictionary:
	return {"broken": broken}


func load_state(data: Dictionary) -> void:
	var value: bool = data.get("broken", false)
	if value != broken:
		set_broken(value)
